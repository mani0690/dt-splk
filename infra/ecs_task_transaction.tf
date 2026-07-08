resource "aws_ecs_task_definition" "transaction" {
  family                   = "${var.project_name}-transaction-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  volume {
    name = "oneagent"
  }

  volume {
    name = "applogs"
  }

  container_definitions = jsonencode([
    {
      name        = "install-oneagent"
      image       = "alpine:3"
      essential   = false
      entryPoint  = ["/bin/sh", "-c"]
      command     = [local.oneagent_install_command]
      environment = local.oneagent_environment
      mountPoints = [
        { sourceVolume = "oneagent", containerPath = "/opt/dynatrace/oneagent" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.transaction_oneagent.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "install-oneagent"
        }
      }
    },
    {
      name      = "transaction-service"
      image     = "${aws_ecr_repository.transaction.repository_url}:${var.ecr_image_tag}"
      essential = true
      dependsOn = [
        { containerName = "install-oneagent", condition = "COMPLETE" }
      ]
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "LD_PRELOAD", value = "/opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so" },
        { name = "DEBIT_SERVICE_URL", value = "http://debit-service.internal.local:8080" },
        { name = "CREDIT_SERVICE_URL", value = "http://credit-service.internal.local:8080" },
        { name = "MANAGEMENT_CLOUDWATCH2_METRICS_EXPORT_NAMESPACE", value = "fintrace/transaction-service" },
        { name = "MANAGEMENT_CLOUDWATCH2_METRICS_EXPORT_ENABLED", value = "true" },
        { name = "MANAGEMENT_CLOUDWATCH2_METRICS_EXPORT_STEP", value = "30s" },
        { name = "AWS_REGION", value = var.aws_region }

      ]
      mountPoints = [
        { sourceVolume = "oneagent", containerPath = "/opt/dynatrace/oneagent" },
        { sourceVolume = "applogs", containerPath = "/var/log" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.transaction_app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "transaction-service"
        }
      }
    },
    {
      name      = "splunk-uf"
      image     = "${aws_ecr_repository.splunk_uf_sidecar.repository_url}:latest"
      essential = true
      environment = [
        { name = "MONITOR_PATH", value = "/var/log/test.log" },
        { name = "SPLUNK_SOURCETYPE", value = "transaction-service" },
        { name = "SPLUNK_INDEX", value = var.splunk_index }
      ]
      secrets = [
        { name = "SPLUNK_PASSWORD", valueFrom = aws_secretsmanager_secret.splunk_uf_password.arn }
      ]
      mountPoints = [
        { sourceVolume = "applogs", containerPath = "/var/log", readOnly = true }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.transaction_uf.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "splunk-uf"
        }
      }
    }
  ])
}
