# IAMロールとポリシー

# EKSクラスタ用IAMロール
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-eks-cluster-role"
    Project = var.project_name
  }
}

# EKSクラスタロールにAmazonEKSClusterPolicyをアタッチ
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}
# EKSノードグループ用IAMロール
resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-eks-node-group-role"
    Project = var.project_name
  }
}

# ノードグループロールにAmazonEKSWorkerNodePolicyをアタッチ
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

# ノードグループロールにAmazonEKS_CNI_Policyをアタッチ
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

# ノードグループロールにAmazonEC2ContainerRegistryReadOnlyをアタッチ
resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# OIDC Provider for EKS (IRSA用)
# EKSクラスタのOIDC Providerを有効化
# Note: EKSクラスタ作成後に実行される
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name    = "${var.project_name}-eks-oidc-provider"
    Project = var.project_name
  }

  depends_on = [aws_eks_cluster.main]
}

# kyverno-notation-aws用IAMポリシー - AWS Signer検証用
resource "aws_iam_policy" "kyverno_notation_aws" {
  name        = "${var.project_name}-kyverno-notation-aws-policy"
  description = "Policy for kyverno-notation-aws to verify AWS Signer signatures"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "signer:GetSigningProfile",
          "signer:DescribeSigningJob",
          "signer:ListSigningJobs",
          "signer:GetRevocationStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-kyverno-notation-aws-policy"
    Project = var.project_name
  }
}

# AWS Signer署名実行用IAMポリシー
resource "aws_iam_policy" "container_signing" {
  name        = "${var.project_name}-container-signing-policy"
  description = "Policy for signing container images with AWS Signer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "signer:PutSigningProfile",
          "signer:GetSigningProfile",
          "signer:SignPayload",
          "signer:GetRevocationStatus"
        ]
        Resource = "arn:aws:signer:${var.aws_region}:*:/signing-profiles/*"
      },
      {
        Effect = "Allow"
        Action = [
          "signer:ListSigningProfiles"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-container-signing-policy"
    Project = var.project_name
  }
}

# AWS Signer署名実行用IAMロール（EC2インスタンスまたはローカル実行用）
resource "aws_iam_role" "container_signing" {
  name        = "${var.project_name}-container-signing-role"
  description = "Role for signing container images with AWS Signer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-container-signing-role"
    Project = var.project_name
  }
}

# 署名ロールにAWS Signerポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "container_signing_signer" {
  policy_arn = aws_iam_policy.container_signing.arn
  role       = aws_iam_role.container_signing.name
}

# 署名ロールにECRアクセスポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "container_signing_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.container_signing.name
}
