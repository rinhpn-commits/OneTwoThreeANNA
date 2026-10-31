# Was infra/ai.yml (Lab 6). A Lambda outside the VPC turns pasted text into a structured
# agenda with an LLM. It needs no database and never writes anything.

resource "aws_cloudwatch_log_group" "parser" {
  name              = "/aws/lambda/${var.project_name}-agenda-parser"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "parser" {
  name               = var.parser_role_name
  assume_role_policy = local.lambda_assume_role
}

resource "aws_iam_role_policy_attachment" "parser_basic" {
  role       = aws_iam_role.parser.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# The only AWS permission the parser needs: reading one parameter. No database.
resource "aws_iam_role_policy" "parser" {
  name = "read-openai-key"
  role = aws_iam_role.parser.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.openai_key_param}"
    }]
  })
}

resource "aws_lambda_function" "parser" {
  function_name = "${var.project_name}-agenda-parser"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = [var.architecture]
  memory_size   = 512
  timeout       = 60
  role          = aws_iam_role.parser.arn

  image_config {
    command = ["app.ai.agenda_lambda.handler"]
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.parser.name
  }

  environment {
    variables = {
      PARSER_BACKEND       = var.parser_backend
      PARSER_MODEL         = var.parser_model
      PARSER_EFFORT        = var.parser_effort
      OPENAI_API_KEY_PARAM = var.openai_key_param
      MAX_TEXT_CHARS       = tostring(var.parser_max_text_chars)
      COGNITO_REGION       = var.region
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.web.id
      COGNITO_JWKS         = trimspace(data.http.jwks.response_body)
    }
  }

  depends_on = [aws_iam_role_policy_attachment.parser_basic]

  lifecycle {
    ignore_changes = [image_uri]
  }
}

# No VPC config: the parser needs no database. It reaches the internet without a NAT gateway.
resource "aws_lambda_function_url" "parser" {
  function_name      = aws_lambda_function.parser.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = var.allowed_origins
    allow_methods = ["POST"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 3600
  }
}

# A public function URL needs both permissions.
resource "aws_lambda_permission" "parser_url" {
  statement_id           = "AllowPublicUrl"
  function_name          = aws_lambda_function.parser.function_name
  action                 = "lambda:InvokeFunctionUrl"
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "parser_invoke" {
  statement_id             = "AllowPublicInvoke"
  function_name            = aws_lambda_function.parser.function_name
  action                   = "lambda:InvokeFunction"
  principal                = "*"
  invoked_via_function_url = true
}
