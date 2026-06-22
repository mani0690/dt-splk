# transaction-service: reachable from the internet, since you need
# something to actually curl from outside the VPC.
resource "aws_security_group" "public_app" {
  name        = "${var.project_name}-public-app"
  description = "Inbound 8080 from anywhere - transaction-service only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-public-app" }
}

# debit-service and credit-service: only reachable from transaction-service's
# security group, not from the internet, even though they have public IPs
# (required for internet egress in a default VPC with no NAT gateway).
resource "aws_security_group" "internal" {
  name        = "${var.project_name}-internal"
  description = "Inbound 8080 only from transaction-service - debit/credit"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-internal" }
}

resource "aws_security_group_rule" "internal_from_public_app" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.internal.id
  source_security_group_id = aws_security_group.public_app.id
}
