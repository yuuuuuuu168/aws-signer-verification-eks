variable "project_name" {
  type        = string
  description = "プロジェクト名（リソース命名に使用）"
  default     = "aws-signer-verification"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  type        = string
  description = "VPCのCIDRブロック"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "使用するアベイラビリティゾーン"
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "eks_version" {
  type        = string
  description = "EKSクラスタのKubernetesバージョン"
  default     = "1.35"
}

variable "node_instance_type" {
  type        = string
  description = "EKSノードのインスタンスタイプ"
  default     = "t3.small"
}

variable "node_desired_size" {
  type        = number
  description = "ノードグループの希望ノード数"
  default     = 1
}

variable "node_min_size" {
  type        = number
  description = "ノードグループの最小ノード数"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "ノードグループの最大ノード数"
  default     = 2
}

variable "ecr_repository_name" {
  type        = string
  description = "ECRリポジトリ名"
  default     = "nginx-signed"
}
