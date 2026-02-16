output "cluster_endpoint" {
  description = "EKSクラスタのエンドポイント"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKSクラスタ名"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "クラスタセキュリティグループID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "region" {
  description = "AWSリージョン"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "kyverno_notation_aws_policy_arn" {
  description = "kyverno-notation-aws用IAMポリシーARN"
  value       = aws_iam_policy.kyverno_notation_aws.arn
}

output "ecr_repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_arn" {
  description = "ECRリポジトリARN"
  value       = aws_ecr_repository.main.arn
}

output "container_signing_role_arn" {
  description = "コンテナ署名用IAMロールARN"
  value       = aws_iam_role.container_signing.arn
}

output "container_signing_policy_arn" {
  description = "コンテナ署名用IAMポリシーARN"
  value       = aws_iam_policy.container_signing.arn
}

output "codebuild_project_name" {
  description = "CodeBuildプロジェクト名"
  value       = aws_codebuild_project.nginx_build.name
}

output "codebuild_project_arn" {
  description = "CodeBuildプロジェクトARN"
  value       = aws_codebuild_project.nginx_build.arn
}
