# Was infra/reports.yaml (Lab 5).
# The VPC, subnets, security group and database stay in CloudFormation (infra/backend.yaml).

locals {
  reports_bucket = "${var.project_name}-reports-${data.aws_caller_identity.current.account_id}"
  lambda_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

data "aws_cloudformation_stack" "backend" {
  name = var.backend_stack_name
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_cloudformation_stack.backend.outputs["DbSecretArn"]
}

# ===================== Storage =====================
resource "aws_s3_bucket" "reports" {
  bucket = local.reports_bucket
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "expire-reports"
    status = "Enabled"

    filter {
      prefix = "reports/"
    }

    expiration {
      days = 90
    }
  }
}

# In CloudFormation this needed an explicit bucket name to avoid a circular dependency.
# Here the bucket, the Lambda permission and the notification are three separate resources.
resource "aws_s3_bucket_notification" "reports" {
  bucket = aws_s3_bucket.reports.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.mailer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.mailer_s3]
}

# ===================== S3 route for the builder (no NAT, no internet) =====================
# The backend subnets use the VPC's main route table. This one adds the S3 route; without it
# the builder's PutObject hangs until the timeout.
resource "aws_route_table" "reports" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-reports-private"
  }
}

resource "aws_route_table_association" "reports" {
  count          = 2
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.reports.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.reports.id]
}

# ===================== Queue + dead-letter queue =====================
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-report-requests-dlq"
  message_retention_seconds = 1209600
  max_message_size          = 1048576 # AWS default since 2025; Terraform's own default is 256 KiB
}

# visibility timeout = 6 x the builder's timeout (60 s). If it were shorter, a message could
# become visible again while the first attempt still runs.
resource "aws_sqs_queue" "requests" {
  name                       = "${var.project_name}-report-requests"
  visibility_timeout_seconds = 360
  max_message_size           = 1048576

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# ===================== Builder (in the VPC) =====================
resource "aws_iam_role" "builder" {
  name               = var.builder_role_name
  assume_role_policy = local.lambda_assume_role
}

resource "aws_iam_role_policy_attachment" "builder_vpc" {
  role       = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "builder_sqs" {
  role       = aws_iam_role.builder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "builder" {
  name = "write-reports"
  role = aws_iam_role.builder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::${local.reports_bucket}/reports/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "builder" {
  name              = "/aws/lambda/${var.project_name}-report-builder"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "builder" {
  function_name = "${var.project_name}-report-builder"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = [var.architecture]
  memory_size   = 512
  timeout       = 60 # Aurora may need ~15 s to resume
  role          = aws_iam_role.builder.arn

  image_config {
    command = ["app.reports.lambda_handler.handler"]
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.builder.name
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.backend_security_group_id]
  }

  environment {
    variables = {
      DB_HOST        = data.aws_cloudformation_stack.backend.outputs["DbEndpoint"]
      DB_PORT        = "5432"
      DB_NAME        = "meetings"
      DB_USER        = "meetings"
      DB_PASSWORD    = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)["password"]
      DB_NULL_POOL   = "true"
      REPORTS_BUCKET = local.reports_bucket
      FAIL_WEEK      = var.fail_week
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.builder_vpc,
    aws_iam_role_policy_attachment.builder_sqs,
  ]

  lifecycle {
    # New images are rolled out by make aws-functions-image (or the pipeline), not by Terraform.
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_event_source_mapping" "builder_queue" {
  event_source_arn = aws_sqs_queue.requests.arn
  function_name    = aws_lambda_function.builder.arn
  batch_size       = 1
}

# ===================== Schedule =====================
resource "aws_iam_role" "scheduler" {
  name = var.scheduler_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "start-report"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.builder.arn
      },
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.requests.arn
      },
    ]
  })
}

resource "aws_scheduler_schedule" "weekly" {
  name                         = "${var.project_name}-weekly-report"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "Europe/Kyiv" # without it the cron runs in UTC
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.schedule_mode == "direct" ? aws_lambda_function.builder.arn : aws_sqs_queue.requests.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{\"week\": null, \"source\": \"schedule\"}"
  }
}

# ===================== Mailer (outside the VPC) =====================
resource "aws_iam_role" "mailer" {
  name               = var.mailer_role_name
  assume_role_policy = local.lambda_assume_role
}

resource "aws_iam_role_policy_attachment" "mailer_basic" {
  role       = aws_iam_role.mailer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "mailer" {
  name = "read-reports-send-mail"
  role = aws_iam_role.mailer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${local.reports_bucket}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "mailer" {
  name              = "/aws/lambda/${var.project_name}-report-mailer"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "mailer" {
  function_name = "${var.project_name}-report-mailer"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = [var.architecture]
  memory_size   = 256
  timeout       = 30
  role          = aws_iam_role.mailer.arn

  image_config {
    command = ["app.reports.mailer.handler"]
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.mailer.name
  }

  environment {
    variables = {
      SENDER     = "reports@${var.ses_domain}"
      RECIPIENTS = var.recipient_email
    }
  }

  depends_on = [aws_iam_role_policy_attachment.mailer_basic]

  lifecycle {
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_permission" "mailer_s3" {
  statement_id   = "AllowS3Invoke"
  function_name  = aws_lambda_function.mailer.function_name
  action         = "lambda:InvokeFunction"
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.reports.arn
  source_account = data.aws_caller_identity.current.account_id
}

# ===================== SES =====================
resource "aws_sesv2_email_identity" "domain" {
  email_identity = var.ses_domain
}

resource "aws_sesv2_email_identity" "recipient" {
  email_identity = var.recipient_email
}
