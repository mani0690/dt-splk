terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Bucket/key/region/dynamodb_table are deliberately NOT hardcoded here -
  # they're supplied via -backend-config flags at `terraform init` time
  # (see README). The bucket name has to be globally unique and is something
  # you choose, and a backend block can't use variables.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
