variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "meetings"
}

variable "architecture" {
  type        = string
  default     = "arm64"
  description = "Lambda architecture of the backend image: arm64 or x86_64."
}

variable "image_uri" {
  type        = string
  description = "Backend image the three functions started from. Terraform ignores later changes: new images are rolled out by make aws-functions-image."
}

# ---------------- Cognito ----------------
variable "callback_urls" {
  type        = list(string)
  description = "Where the Hosted UI may send users back after sign-in."
}

variable "logout_urls" {
  type        = list(string)
  description = "Where the Hosted UI may send users after sign-out."
}

variable "google_client_id" {
  type        = string
  description = "OAuth client ID from Google Cloud (not a secret)."
}

variable "google_client_secret" {
  type        = string
  sensitive   = true
  description = "OAuth client secret from Google Cloud. Set it in the HCP Terraform workspace, never in a file."
}

# ---------------- Network and database (stay in CloudFormation: infra/backend.yaml) ----------------
variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "backend_security_group_id" {
  type = string
}

variable "backend_stack_name" {
  type    = string
  default = "meetings-backend"
}

# ---------------- Weekly report ----------------
variable "ses_domain" {
  type        = string
  description = "Domain whose DNS you control; reports are sent from reports@<domain>."
}

variable "recipient_email" {
  type        = string
  description = "Inbox that receives the report (SES sandbox: must be verified)."
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 7 ? * MON *)"
}

variable "schedule_mode" {
  type    = string
  default = "queue"

  validation {
    condition     = contains(["direct", "queue"], var.schedule_mode)
    error_message = "schedule_mode must be direct or queue."
  }
}

variable "fail_week" {
  type        = string
  default     = ""
  description = "Test hook: the builder fails on purpose for this week (DLQ test)."
}

variable "log_retention_days" {
  type    = number
  default = 7
}

# ---------------- Agenda parser ----------------
variable "parser_backend" {
  type    = string
  default = "openai"
}

variable "parser_model" {
  type    = string
  default = "gpt-5.4-mini"
}

variable "parser_effort" {
  type    = string
  default = ""
}

variable "openai_key_param" {
  type    = string
  default = "/meetings/openai-api-key"
}

variable "allowed_origins" {
  type        = list(string)
  description = "Browser origins allowed to call the parser (the site and localhost)."
}

variable "parser_max_text_chars" {
  type    = number
  default = 10000
}

# ---------------- IAM role names ----------------
# CloudFormation generated these names. Keeping them lets Terraform adopt the roles
# instead of replacing them (a role name cannot be changed in place).
variable "builder_role_name" {
  type = string
}

variable "mailer_role_name" {
  type = string
}

variable "scheduler_role_name" {
  type = string
}

variable "parser_role_name" {
  type = string
}
