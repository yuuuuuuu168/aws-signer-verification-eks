# AWS Signer EKS検証環境
# このファイルは、各リソースモジュールを統合するメインファイルです

# データソース: 現在のAWSアカウント情報
data "aws_caller_identity" "current" {}

# 各リソースは以下のファイルで定義されています:
# - vpc.tf: VPC、サブネット、ルーティング
# - iam.tf: IAMロール、ポリシー、OIDC Provider
# - eks.tf: EKSクラスタ、ノードグループ、セキュリティグループ
# - ecr.tf: ECRリポジトリ、ライフサイクルポリシー
