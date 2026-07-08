# NOTE: an OIDC provider for token.actions.githubusercontent.com is a single
# resource per AWS account - if your account already has one (from another
# repo's setup), this resource block will fail with EntityAlreadyExists.
# In that case, either delete this resource block and reference the existing
# provider via a data source, or `terraform import` it instead.

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Restricts this role to workflows running on main in YOUR repo only.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${var.project_name}-deploy-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:PutImageScanningConfiguration"
        ]
        Resource = "*"
      },
      {
        # ECS: full management of the cluster/services/task definitions this
        # project owns. Not scoped to specific ARNs - ECS task def ARNs
        # change on every revision, so practical scoping is by action only.
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:CreatePrivateDnsNamespace",
          "servicediscovery:DeleteNamespace",
          "servicediscovery:GetNamespace",
          "servicediscovery:ListNamespaces",
          "servicediscovery:CreateService",
          "servicediscovery:DeleteService",
          "servicediscovery:GetService",
          "servicediscovery:GetOperation",
          "servicediscovery:TagResource"
        ]
        Resource = "*"
      },
      {
        # Needed to create/manage the ECS task EXECUTION role (separate from
        # this deploy role) and to pass it to ECS when registering tasks.
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:TagRole",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
      },
      {
        # State bucket + lock table access - fill in your own bucket/table
        # names to scope this tightly instead of leaving it broad.
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "*"
      },
      {
        # Additional read permissions required by AWS Terraform provider v5.100+
        # during state refresh - these weren't needed in earlier provider versions.
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcAttribute",
          "ecr:ListTagsForResource",
          "logs:ListTagsForResource",
          "logs:ListTagsLogGroup",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:GetOpenIDConnectProvider",
          "secretsmanager:GetResourcePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
