# The output names are the old CloudFormation output keys, so the Makefile and the frontend
# build keep reading the same names (make reports_output / cognito_output / ai_output).

output "UserPoolId" {
  value = aws_cognito_user_pool.main.id
}

output "UserPoolClientId" {
  value = aws_cognito_user_pool_client.web.id
}

output "Region" {
  value = var.region
}

output "Issuer" {
  value = local.issuer
}

output "HostedUiDomain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}

output "GoogleEnabled" {
  value = "true"
}

output "BucketName" {
  value = aws_s3_bucket.reports.bucket
}

output "QueueUrl" {
  value = aws_sqs_queue.requests.url
}

output "DlqUrl" {
  value = aws_sqs_queue.dlq.url
}

output "BuilderFunctionName" {
  value = aws_lambda_function.builder.function_name
}

output "MailerFunctionName" {
  value = aws_lambda_function.mailer.function_name
}

# DNS records to add for SES (CNAME name -> value).
output "DkimRecords" {
  value = [
    for token in aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens : {
      name  = "${token}._domainkey.${var.ses_domain}"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}

output "ParserUrl" {
  value = aws_lambda_function_url.parser.function_url
}

output "ParserFunctionName" {
  value = aws_lambda_function.parser.function_name
}

output "ParserLogGroupName" {
  value = aws_cloudwatch_log_group.parser.name
}
