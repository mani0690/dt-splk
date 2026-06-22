# These hold ONLY the install-oneagent sidecar's wget/unzip output, so you
# can debug the agent injection step without needing Splunk for it. The
# actual application logs go to Splunk via the splunk log driver instead.

resource "aws_cloudwatch_log_group" "transaction_oneagent" {
  name              = "/ecs/${var.project_name}/transaction-service/oneagent-init"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "debit_oneagent" {
  name              = "/ecs/${var.project_name}/debit-service/oneagent-init"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "credit_oneagent" {
  name              = "/ecs/${var.project_name}/credit-service/oneagent-init"
  retention_in_days = 7
}

# App containers' own console output (separate from the Splunk path, which
# now goes through the file -> splunk-uf sidecar instead of stdout).
resource "aws_cloudwatch_log_group" "transaction_app" {
  name              = "/ecs/${var.project_name}/transaction-service/app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "debit_app" {
  name              = "/ecs/${var.project_name}/debit-service/app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "credit_app" {
  name              = "/ecs/${var.project_name}/credit-service/app"
  retention_in_days = 7
}

# These hold the splunk-uf entrypoint script's own echo output (waiting for
# splunkd, credentials install result, add monitor result) - check here
# first if logs aren't showing up in Splunk, before assuming Splunk-side
# config is wrong.
resource "aws_cloudwatch_log_group" "transaction_uf" {
  name              = "/ecs/${var.project_name}/transaction-service/splunk-uf"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "debit_uf" {
  name              = "/ecs/${var.project_name}/debit-service/splunk-uf"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "credit_uf" {
  name              = "/ecs/${var.project_name}/credit-service/splunk-uf"
  retention_in_days = 7
}
