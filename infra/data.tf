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

locals {
  # This account's default VPC has two subnets explicitly routed through a
  # NAT Gateway via a custom "banking-private-rt" route table, not the
  # Internet Gateway. Tasks placed there get a public IP that's not actually
  # reachable from outside. Excluding by ID since AWS metadata flags don't
  # reflect custom route table assignments made after subnet creation.
  private_subnet_ids = [
    "subnet-019a912488befa642", # banking-private-1a
    "subnet-0aeed8f2313a71595", # banking-private-1b
  ]

  public_subnet_ids = setsubtract(data.aws_subnets.default.ids, local.private_subnet_ids)
}