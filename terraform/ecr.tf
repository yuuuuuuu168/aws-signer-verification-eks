# ECRリポジトリ
resource "aws_ecr_repository" "main" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  # イメージスキャンを有効化
  image_scanning_configuration {
    scan_on_push = true
  }

  # 暗号化設定
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "${var.project_name}-ecr"
    Project = var.project_name
  }
}

# ライフサイクルポリシー（古いイメージの自動削除）
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
