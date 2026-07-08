resource "aws_ecs_service" "debit" {
  name            = "debit-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.debit.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnet_ids
    security_groups  = [aws_security_group.internal.id]
    assign_public_ip = true # needed for internet egress in default VPC; SG keeps it private from inbound
  }

  service_registries {
    registry_arn = aws_service_discovery_service.debit.arn
  }
}

resource "aws_ecs_service" "credit" {
  name            = "credit-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.credit.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnet_ids
    security_groups  = [aws_security_group.internal.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.credit.arn
  }
}

resource "aws_ecs_service" "transaction" {
  name            = "transaction-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.transaction.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnet_ids
    security_groups  = [aws_security_group.public_app.id]
    assign_public_ip = true
  }

  # No service_registries here - nothing needs to discover transaction-service
  # by internal DNS, it's the entry point.
}
