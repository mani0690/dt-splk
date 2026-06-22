# Using the account's default VPC deliberately. It has no NAT gateway, which
# is why every task below gets a public IP (see security_groups.tf for how
# inbound access is still locked down). A "real" setup would use private
# subnets + a NAT gateway instead.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
