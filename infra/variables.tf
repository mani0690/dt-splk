variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for naming AWS resources"
  type        = string
  default     = "fintrace-demo"
}

variable "dynatrace_env_id" {
  description = "Dynatrace SaaS environment ID, e.g. abc12345 (from https://abc12345.live.dynatrace.com)"
  type        = string
}

variable "dynatrace_paas_token" {
  description = "Dynatrace PaaS token with 'PaaS integration - Installer download' scope"
  type        = string
  sensitive   = true
}

variable "splunk_uf_password" {
  description = "Admin password for the Splunk UF sidecar - used only for the local 'splunk install app' / 'splunk add monitor' CLI calls inside the container, not for logging in anywhere"
  type        = string
  sensitive   = true
}

variable "splunk_index" {
  description = "Splunk index to send logs to"
  type        = string
  default     = "main"
}

variable "ecr_image_tag" {
  description = "Image tag the task definitions should pull"
  type        = string
  default     = "latest"
}

variable "github_org" {
  description = "GitHub org or username that owns this repo (for OIDC trust policy)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (for OIDC trust policy)"
  type        = string
}
