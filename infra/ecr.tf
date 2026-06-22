resource "aws_ecr_repository" "transaction" {
  name = "${var.project_name}/transaction-service"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "debit" {
  name = "${var.project_name}/debit-service"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "credit" {
  name = "${var.project_name}/credit-service"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "splunk_uf_sidecar" {
  name = "${var.project_name}/splunk-uf-sidecar"
  image_scanning_configuration {
    scan_on_push = true
  }
}
