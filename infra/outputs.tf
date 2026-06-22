output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecr_repository_urls" {
  value = {
    transaction = aws_ecr_repository.transaction.repository_url
    debit       = aws_ecr_repository.debit.repository_url
    credit      = aws_ecr_repository.credit.repository_url
  }
}

output "github_actions_role_arn" {
  description = "Put this in your GitHub repo secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions_deploy.arn
}
