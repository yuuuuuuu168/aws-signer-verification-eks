# CodeBuild用のIAMロール
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-codebuild-role"
    Project = var.project_name
  }
}

# CodeBuild用のIAMポリシー
resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "signer:SignPayload",
          "signer:GetSigningProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuildプロジェクト
resource "aws_codebuild_project" "nginx_build" {
  name          = "${var.project_name}-nginx-build"
  description   = "Build and sign nginx image for EKS"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.ecr_repository_name
    }

    environment_variable {
      name  = "SIGNING_PROFILE_NAME"
      value = "container_signing_profile"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/../buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-nginx-build"
      stream_name = "build"
    }
  }

  tags = {
    Name    = "${var.project_name}-nginx-build"
    Project = var.project_name
  }
}

# CloudWatch Logs グループ
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.project_name}-nginx-build"
  retention_in_days = 7

  tags = {
    Name    = "${var.project_name}-codebuild-logs"
    Project = var.project_name
  }
}
