# Lets transaction-service call "http://debit-service.internal.local:8080"
# instead of hardcoding IPs. ECS auto-registers/deregisters task IPs here as
# the service scales or replaces tasks.

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "internal.local"
  vpc  = data.aws_vpc.default.id
}

resource "aws_service_discovery_service" "debit" {
  name = "debit-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "credit" {
  name = "credit-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}
