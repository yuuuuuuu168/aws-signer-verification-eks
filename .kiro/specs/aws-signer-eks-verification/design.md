# 設計書

## 概要

本システムは、AWS Signerを使用したコンテナイメージの署名検証環境を、TerraformでプロビジョニングされたEKSクラスタ上に構築します。Kyvernoポリシーエンジンを使用して、署名されたイメージのみがデプロイ可能な環境を実現します。

コスト効率を最優先とし、検証に必要な最小限のリソース構成を採用します。

## アーキテクチャ

### システム構成図

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                   │ │
│  │                                                        │ │
│  │  ┌──────────────────┐      ┌──────────────────┐      │ │
│  │  │  Public Subnet   │      │  Public Subnet   │      │ │
│  │  │   (AZ-a)         │      │   (AZ-b)         │      │ │
│  │  │  10.0.1.0/24     │      │  10.0.2.0/24     │      │ │
│  │  │                  │      │                  │      │ │
│  │  │  [NAT Gateway]   │      │                  │      │ │
│  │  └──────────────────┘      └──────────────────┘      │ │
│  │           │                         │                 │ │
│  │  ┌──────────────────┐      ┌──────────────────┐      │ │
│  │  │ Private Subnet   │      │ Private Subnet   │      │ │
│  │  │   (AZ-a)         │      │   (AZ-b)         │      │ │
│  │  │  10.0.11.0/24    │      │  10.0.12.0/24    │      │ │
│  │  │                  │      │                  │      │ │
│  │  │  [EKS Nodes]     │      │  [EKS Nodes]     │      │ │
│  │  └──────────────────┘      └──────────────────┘      │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    EKS Cluster                         │ │
│  │                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │   Kyverno    │  │    Nginx     │  │   Other     │ │ │
│  │  │   (Policy    │  │  (Signed)    │  │   Workloads │ │ │
│  │  │   Engine)    │  │              │  │             │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    AWS Signer                          │ │
│  │              (Signing Profile)                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                       ECR                              │ │
│  │              (Signed Container Images)                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### コンポーネント間の関係

1. **Terraform** → AWS APIを通じて全てのインフラリソースを作成
2. **EKS Cluster** → VPCのプライベートサブネット内で動作
3. **Kyverno** → EKSクラスタ内でPodとして動作し、イメージ検証を実施
4. **AWS Signer** → コンテナイメージに署名を付与
5. **ECR** → 署名済みイメージを保管
6. **Nginx** → 署名検証を通過してデプロイされるサンプルアプリケーション

## コンポーネントとインターフェース

### 1. Terraformモジュール構造

```
terraform/
├── main.tf              # メインの構成定義
├── variables.tf         # 入力変数定義
├── outputs.tf           # 出力値定義
├── versions.tf          # プロバイダーバージョン指定
├── vpc.tf               # VPC関連リソース
├── eks.tf               # EKSクラスタ関連リソース
├── ecr.tf               # ECRリポジトリ定義
├── iam.tf               # IAMロール・ポリシー定義
└── terraform.tfvars     # 変数値の設定（例）
```

### 2. VPCモジュール

**責務**: ネットワーク基盤の構築

**リソース**:
- VPC (CIDR: 10.0.0.0/16)
- パブリックサブネット × 2 (10.0.1.0/24, 10.0.2.0/24)
- プライベートサブネット × 2 (10.0.11.0/24, 10.0.12.0/24)
- インターネットゲートウェイ × 1
- NATゲートウェイ × 1 (コスト削減のため単一)
- ルートテーブル (パブリック用、プライベート用)

**インターフェース**:
- 入力: CIDR範囲、アベイラビリティゾーン
- 出力: VPC ID、サブネットID、セキュリティグループID

### 3. EKSモジュール

**責務**: Kubernetesクラスタの構築

**リソース**:
- EKSクラスタ (Kubernetes 1.28以上)
- ノードグループ (最小構成: 1-2ノード、t3.small)
- EKS用IAMロール
- ノードグループ用IAMロール
- セキュリティグループ

**インターフェース**:
- 入力: VPC ID、サブネットID、ノード数、インスタンスタイプ
- 出力: クラスタエンドポイント、クラスタ名、kubeconfig情報

### 4. IAMモジュール

**責務**: 権限管理

**リソース**:
- EKSクラスタロール
- EKSノードロール
- Kyverno用サービスアカウントロール (IRSA)
- AWS Signer検証用ポリシー

**インターフェース**:
- 入力: クラスタ名、OIDC Provider ARN
- 出力: ロールARN

### 5. ECRモジュール

**責務**: コンテナイメージレジストリの管理

**リソース**:
- ECRリポジトリ（nginx用）
- イメージスキャン設定（有効化）
- ライフサイクルポリシー（古いイメージの自動削除）

**インターフェース**:
- 入力: リポジトリ名
- 出力: リポジトリURL、リポジトリARN

### 6. Kyvernoポリシー

**責務**: コンテナイメージの署名検証

**構成要素**:
- ClusterPolicy: イメージ検証ルール
- ConfigMap: AWS Signer公開鍵情報
- ServiceAccount: AWS API呼び出し用

**検証フロー**:
```
Pod作成リクエスト
    ↓
Kyverno Admission Webhook
    ↓
イメージ署名の検証
    ↓
AWS Signer APIで署名確認
    ↓
検証成功 → Pod作成許可
検証失敗 → Pod作成拒否
```

## データモデル

### Terraform変数

```hcl
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
  default     = "1.28"
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
```

### Terraform出力

```hcl
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

output "kyverno_role_arn" {
  description = "Kyverno用IAMロールARN"
  value       = aws_iam_role.kyverno.arn
}

output "ecr_repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_arn" {
  description = "ECRリポジトリARN"
  value       = aws_ecr_repository.main.arn
}
```

### Kyvernoポリシー構造

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-aws-signer
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      # AWS Signer公開鍵
```

## 正確性プロパティ

*プロパティとは、システムの全ての有効な実行において真であるべき特性や振る舞いのことです。これは人間が読める仕様と機械で検証可能な正確性保証の橋渡しとなります。*


### インフラストラクチャプロパティ

**Property 1: VPC作成の完全性**
*任意の* Terraform実行に対して、VPCが作成され、有効な状態で存在すること
**検証: 要件 1.1**

**Property 2: マルチAZパブリックサブネット**
*任意の* Terraform実行に対して、最低2つの異なるアベイラビリティゾーンにパブリックサブネットが作成されること
**検証: 要件 1.2**

**Property 3: マルチAZプライベートサブネット**
*任意の* Terraform実行に対して、最低2つの異なるアベイラビリティゾーンにプライベートサブネットが作成されること
**検証: 要件 1.3**

**Property 4: インターネットゲートウェイのアタッチメント**
*任意の* Terraform実行に対して、インターネットゲートウェイが作成され、VPCにアタッチされていること
**検証: 要件 1.4**

**Property 5: NATゲートウェイの存在**
*任意の* Terraform実行に対して、NATゲートウェイが作成され、パブリックサブネットに配置されていること
**検証: 要件 1.5**

**Property 6: ルーティング設定の正確性**
*任意の* Terraform実行に対して、パブリックサブネットのルートテーブルがIGWへのデフォルトルートを持ち、プライベートサブネットのルートテーブルがNATゲートウェイへのデフォルトルートを持つこと
**検証: 要件 1.6**

**Property 7: EKSクラスタの作成**
*任意の* Terraform実行に対して、EKSクラスタが作成され、ACTIVE状態であること
**検証: 要件 2.1**

**Property 8: コスト効率的なノード構成**
*任意の* Terraform実行に対して、ノードグループのdesired/min/maxサイズが1-2の範囲内であり、インスタンスタイプがt3.small以下であること
**検証: 要件 2.2, 2.3, 7.1, 7.2**

**Property 9: IAMロールの完全性**
*任意の* Terraform実行に対して、EKSクラスタロールとノードグループロールが作成され、必要なAWSマネージドポリシーがアタッチされていること
**検証: 要件 2.4**

**Property 10: ECRリポジトリの作成**
*任意の* Terraform実行に対して、ECRリポジトリが作成され、イメージスキャンが有効化されていること
**検証: 要件 2.6**

**Property 11: 単一NATゲートウェイ構成**
*任意の* Terraform実行に対して、作成されるNATゲートウェイの数が正確に1つであること
**検証: 要件 7.3**

### Terraformコード品質プロパティ

**Property 12: 変数定義の完全性**
*任意の* Terraformモジュールに対して、variables.tfファイルが存在し、リージョン、インスタンスタイプ、ノード数などの主要パラメータが変数として定義されていること
**検証: 要件 3.1**

**Property 13: 出力値の提供**
*任意の* Terraformモジュールに対して、outputs.tfファイルが存在し、クラスタエンドポイント、クラスタ名、リージョン、ECRリポジトリURLが出力として定義されていること
**検証: 要件 3.2**

**Property 14: リソースタグの付与**
*任意の* Terraform実行に対して、VPC、EKSクラスタ、サブネットなどの主要リソースにタグが設定されていること
**検証: 要件 3.4**

### ドキュメントプロパティ

**Property 15: AWS Signer手順の記載**
*任意の* READMEファイルに対して、「AWS Signer」「署名プロファイル」「マネジメントコンソール」「IAM」「ECR」のキーワードを含むセクションが存在すること
**検証: 要件 4.1, 4.2, 4.3, 4.4**

**Property 16: GUI操作説明の提供**
*任意の* READMEファイルに対して、AWS Signerの設定に関する詳細な手順説明またはスクリーンショットへの参照が含まれること
**検証: 要件 4.5**

**Property 17: Kyverno設定手順の記載**
*任意の* READMEファイルに対して、「Kyverno」「インストール」「ClusterPolicy」「verifyImages」のキーワードを含むセクションが存在すること
**検証: 要件 5.1, 5.3**

**Property 18: IRSA設定の記載**
*任意の* READMEファイルに対して、「IRSA」または「ServiceAccount」に関する設定手順が含まれること
**検証: 要件 5.2**

**Property 19: 検証手順の記載**
*任意の* READMEファイルに対して、ポリシーの動作確認方法とデプロイ成功/失敗の確認方法が記載されていること
**検証: 要件 5.4, 6.4, 6.5**

**Property 20: Nginxデプロイ例の提供**
*任意の* ドキュメントセットに対して、署名済みNginxイメージを使用したKubernetesマニフェストの例が含まれること
**検証: 要件 6.2**

**Property 21: Terraformコマンドの記載**
*任意の* READMEファイルに対して、「terraform init」「terraform apply」「terraform destroy」のコマンドが記載されていること
**検証: 要件 7.4, 8.1, 8.2, 8.3**

**Property 22: kubectl設定手順の記載**
*任意の* READMEファイルに対して、「kubectl」または「kubeconfig」に関する設定手順が含まれること
**検証: 要件 8.4**

**Property 23: コスト情報の提供**
*任意の* READMEファイルに対して、想定コストまたはコスト削減に関する情報が含まれること
**検証: 要件 7.5**

## エラーハンドリング

### Terraform実行時のエラー

1. **AWS認証エラー**
   - 検出: AWS CLIの認証情報が未設定または無効
   - 対応: READMEにAWS認証情報の設定手順を記載
   - メッセージ例: "Error: error configuring Terraform AWS Provider"

2. **リソース制限エラー**
   - 検出: AWSアカウントのサービスクォータ超過
   - 対応: READMEに必要なクォータ情報を記載
   - メッセージ例: "Error: VpcLimitExceeded"

3. **リージョン可用性エラー**
   - 検出: 指定したインスタンスタイプが選択リージョンで利用不可
   - 対応: 変数で代替インスタンスタイプを指定可能にする
   - メッセージ例: "Error: Unsupported instance type"

### Kyverno検証エラー

1. **署名検証失敗**
   - 検出: イメージに有効な署名が存在しない
   - 対応: Podの作成を拒否し、明確なエラーメッセージを返す
   - メッセージ例: "image verification failed: signature not found"

2. **AWS Signer API呼び出しエラー**
   - 検出: IAMロールの権限不足またはAPI障害
   - 対応: READMEに必要なIAM権限を明記
   - メッセージ例: "failed to verify signature: AccessDenied"

3. **タイムアウトエラー**
   - 検出: 署名検証に時間がかかりすぎる
   - 対応: webhookTimeoutSecondsを適切に設定（30秒推奨）
   - メッセージ例: "admission webhook timeout"

### kubectl操作エラー

1. **クラスタ接続エラー**
   - 検出: kubeconfigが正しく設定されていない
   - 対応: READMEにkubeconfigの更新コマンドを記載
   - メッセージ例: "Unable to connect to the server"

2. **権限エラー**
   - 検出: IAMユーザー/ロールがEKSクラスタにアクセスできない
   - 対応: READMEにaws-authConfigMapの設定方法を記載
   - メッセージ例: "Unauthorized"

## テスト戦略

### デュアルテストアプローチ

本プロジェクトでは、以下の2つの補完的なテスト手法を採用します：

1. **ユニットテスト**: 特定の例、エッジケース、エラー条件を検証
2. **プロパティベーステスト**: 全ての入力に対する普遍的なプロパティを検証

両方のテストが必要であり、相互に補完し合います。

### インフラストラクチャテスト

**ツール**: Terratest (Go) または pytest + boto3 (Python)

**ユニットテスト**:
- 特定のリージョン（ap-northeast-1）での正常なデプロイ
- デフォルト変数値での正常なデプロイ
- terraform destroyによる完全なクリーンアップ

**プロパティベーステスト**:
- 各プロパティ（Property 1-13）を個別にテスト
- 最低100回の反復実行（ランダムな変数値を使用）
- テストタグ形式: `Feature: aws-signer-eks-verification, Property X: [プロパティテキスト]`

**テスト例**:
```go
// Property 8のテスト例
func TestProperty8_CostEfficientNodeConfiguration(t *testing.T) {
    // Feature: aws-signer-eks-verification, Property 8: コスト効率的なノード構成
    for i := 0; i < 100; i++ {
        // ランダムな変数値を生成
        terraformOptions := generateRandomTerraformOptions()
        
        // Terraform apply
        terraform.InitAndApply(t, terraformOptions)
        
        // ノード構成を検証
        nodeGroup := aws.GetEksNodeGroup(t, ...)
        assert.LessOrEqual(t, nodeGroup.DesiredSize, 2)
        assert.LessOrEqual(t, nodeGroup.MinSize, 1)
        assert.LessOrEqual(t, nodeGroup.MaxSize, 2)
        assert.Contains(t, []string{"t3.micro", "t3.small"}, nodeGroup.InstanceType)
        
        // クリーンアップ
        terraform.Destroy(t, terraformOptions)
    }
}
```

### ドキュメントテスト

**ツール**: Python + 正規表現 または Go + regexp

**ユニットテスト**:
- READMEファイルの存在確認
- 必須セクションの存在確認
- リンク切れチェック

**プロパティベーステスト**:
- 各ドキュメントプロパティ（Property 14-22）を個別にテスト
- 最低100回の反復実行（異なるREADMEバリエーションに対して）
- テストタグ形式: `Feature: aws-signer-eks-verification, Property X: [プロパティテキスト]`

**テスト例**:
```python
# Property 20のテスト例
def test_property_20_terraform_commands():
    """Feature: aws-signer-eks-verification, Property 20: Terraformコマンドの記載"""
    for _ in range(100):
        readme_content = read_readme_file()
        
        # 必須コマンドの存在を確認
        assert "terraform init" in readme_content
        assert "terraform apply" in readme_content
        assert "terraform destroy" in readme_content
```

### 統合テスト

**目的**: エンドツーエンドのワークフロー検証

**テストシナリオ**:
1. Terraformで環境を構築
2. kubectlでクラスタに接続
3. Kyvernoをインストール
4. 署名検証ポリシーを適用
5. 署名済みNginxイメージをデプロイ（成功を確認）
6. 署名なしイメージをデプロイ（失敗を確認）
7. 環境を破棄

**実行頻度**: プルリクエストごと、またはマニュアル実行

### テスト実行環境

- CI/CD: GitHub Actions または GitLab CI
- AWSアカウント: テスト専用の分離されたアカウント
- クリーンアップ: 各テスト後に必ずリソースを削除
- コスト管理: テスト実行時間を最小化（並列実行を避ける）

## 実装の考慮事項

### コスト最適化の詳細

1. **NATゲートウェイ**: 単一のNATゲートウェイを使用（月額約$32）
2. **EKSコントロールプレーン**: 1クラスタあたり月額$73
3. **EC2ノード**: t3.small × 1ノード、月額約$15
4. **合計想定コスト**: 月額約$120（検証環境として妥当）

### セキュリティ考慮事項

1. **最小権限の原則**: IAMロールは必要最小限の権限のみ付与
2. **プライベートサブネット**: EKSノードはプライベートサブネットに配置
3. **セキュリティグループ**: 必要なポートのみ開放
4. **署名検証**: Kyvernoポリシーで未署名イメージを拒否

### スケーラビリティ

本設計は検証環境向けであり、本番環境では以下の変更が必要：
- マルチAZ構成のNATゲートウェイ
- ノード数の増加
- より大きなインスタンスタイプ
- モニタリングとロギングの追加
