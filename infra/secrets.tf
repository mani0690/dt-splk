resource "aws_secretsmanager_secret" "splunk_uf_password" {
  name = "${var.project_name}/splunk-uf-password"
}

resource "aws_secretsmanager_secret_version" "splunk_uf_password" {
  secret_id     = aws_secretsmanager_secret.splunk_uf_password.id
  secret_string = var.splunk_uf_password
}
