# EKSクラスタ
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # クラスタのログ記録を有効化（オプション、コスト考慮）
  enabled_cluster_log_types = ["api", "audit"]

  tags = {
    Name    = "${var.project_name}-eks"
    Project = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# EKSクラスタ用セキュリティグループ
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  # クラスタとノード間の通信を許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-eks-cluster-sg"
    Project = var.project_name
  }
}

# ノードグループからクラスタへのアクセスを許可
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow nodes to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# EKSノードグループ用セキュリティグループ
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # ノード間の通信を許可
  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # クラスタからノードへの通信を許可
  ingress {
    description     = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # 全てのアウトバウンドトラフィックを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                            = "${var.project_name}-eks-nodes-sg"
    Project                                         = var.project_name
    "kubernetes.io/cluster/${var.project_name}-eks" = "owned"
  }
}

# クラスタからノードへのHTTPS通信を許可
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

# EKSノードグループ
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  # コスト効率的な構成
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # 小型インスタンスタイプ
  instance_types = [var.node_instance_type]

  # ディスク容量（最小限）
  disk_size = 20

  # 更新設定
  update_config {
    max_unavailable = 1
  }

  tags = {
    Name    = "${var.project_name}-node-group"
    Project = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy
  ]
}
