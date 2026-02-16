# 要件定義書

## はじめに

本システムは、AWS Signerを使用したコンテナイメージの署名検証環境を、Kubernetes（EKS）上でKyvernoを用いて構築するための検証環境です。コスト効率を重視し、最小限のリソース構成で実用的な検証が可能な環境を提供します。

## 用語集

- **System**: AWS Signer検証環境全体
- **Terraform_Module**: インフラストラクチャをコードとして定義・管理するモジュール
- **VPC**: Virtual Private Cloud - AWS上の仮想ネットワーク
- **EKS_Cluster**: Elastic Kubernetes Service - AWSマネージドKubernetesクラスタ
- **AWS_Signer**: AWSのコード署名サービス
- **Kyverno**: Kubernetes用のポリシーエンジン
- **Signing_Profile**: AWS Signerで使用する署名プロファイル
- **Container_Image**: コンテナ化されたアプリケーションイメージ
- **README**: 環境構築と運用の手順書

## 要件

### 要件1: ネットワークインフラストラクチャの構築

**ユーザーストーリー:** インフラ担当者として、EKSクラスタを動作させるための基盤となるネットワーク環境を構築したい。これにより、セキュアで分離されたネットワーク上でKubernetesを実行できる。

#### 受入基準

1. THE Terraform_Module SHALL VPCを作成する
2. THE Terraform_Module SHALL パブリックサブネットを最低2つのアベイラビリティゾーンに作成する
3. THE Terraform_Module SHALL プライベートサブネットを最低2つのアベイラビリティゾーンに作成する
4. THE Terraform_Module SHALL インターネットゲートウェイを作成する
5. THE Terraform_Module SHALL NATゲートウェイを作成する
6. THE Terraform_Module SHALL 適切なルートテーブルを設定する

### 要件2: EKSクラスタの構築

**ユーザーストーリー:** インフラ担当者として、コスト効率的なEKSクラスタを構築したい。これにより、最小限のコストで検証環境を運用できる。

#### 受入基準

1. THE Terraform_Module SHALL EKSクラスタを作成する
2. THE Terraform_Module SHALL ノードグループを最小構成（1-2ノード）で作成する
3. THE Terraform_Module SHALL 小型インスタンスタイプ（t3.small以下）を使用する
4. THE Terraform_Module SHALL 必要なIAMロールとポリシーを作成する
5. THE Terraform_Module SHALL クラスタのセキュリティグループを適切に設定する
6. THE Terraform_Module SHALL ECRリポジトリを作成する

### 要件3: Terraformコードの品質

**ユーザーストーリー:** 開発者として、保守性の高いTerraformコードを使用したい。これにより、環境の変更や拡張が容易になる。

#### 受入基準

1. THE Terraform_Module SHALL 変数を使用して設定可能なパラメータを定義する
2. THE Terraform_Module SHALL 出力値を定義してクラスタ接続情報を提供する
3. THE Terraform_Module SHALL 適切なリソース命名規則を使用する
4. THE Terraform_Module SHALL リソースにタグを付与する

### 要件4: AWS Signer準備手順のドキュメント化

**ユーザーストーリー:** 運用担当者として、AWS Signerの設定手順を理解したい。これにより、コンテナイメージの署名環境を正しく準備できる。

#### 受入基準

1. THE README SHALL AWSマネジメントコンソールを使用したAWS Signerの署名プロファイル作成手順を記載する
2. THE README SHALL AWSマネジメントコンソールを使用した必要なIAMポリシーとロールの設定手順を記載する
3. THE README SHALL コンテナイメージへの署名手順を記載する
4. THE README SHALL 署名済みイメージのECRへのプッシュ手順を記載する
5. THE README SHALL 各GUI操作のスクリーンショットまたは詳細な手順説明を含める

### 要件5: Kyverno + kyverno-notation-aws設定手順のドキュメント化

**ユーザーストーリー:** 運用担当者として、Kyvernoとkyverno-notation-awsによる署名検証の設定方法を理解したい。これにより、署名されていないイメージのデプロイを防止できる。

#### 受入基準

1. THE README SHALL cert-managerのインストール手順を記載する
2. THE README SHALL Kyvernoのインストール手順を記載する
3. THE README SHALL kyverno-notation-awsアプリケーションのインストール手順を記載する
4. THE README SHALL TrustPolicyとTrustStoreカスタムリソースの適用手順を記載する
5. THE README SHALL IRSA（IAM Roles for Service Accounts）の設定手順を記載する
6. THE README SHALL Kyvernoポリシーの作成と適用手順を記載する
7. THE README SHALL ポリシーの動作確認方法を記載する

### 要件6: Nginxデプロイ手順のドキュメント化

**ユーザーストーリー:** 運用担当者として、署名検証を経由したアプリケーションのデプロイ方法を理解したい。これにより、実際の運用フローを検証できる。

#### 受入基準

1. THE README SHALL Nginxイメージの署名手順を記載する
2. THE README SHALL 署名済みNginxイメージを使用したKubernetesマニフェストの例を提供する
3. THE README SHALL デプロイコマンドを記載する
4. THE README SHALL デプロイ成功の確認方法を記載する
5. THE README SHALL 署名されていないイメージでのデプロイ失敗の確認方法を記載する

### 要件7: コスト最適化の実装

**ユーザーストーリー:** 予算管理者として、検証環境のコストを最小限に抑えたい。これにより、限られた予算内で効果的な検証が可能になる。

#### 受入基準

1. THE Terraform_Module SHALL 最小限のノード数（1-2ノード）を使用する
2. THE Terraform_Module SHALL 小型インスタンスタイプを使用する
3. THE Terraform_Module SHALL 単一のNATゲートウェイを使用する
4. THE README SHALL リソースの削除手順を記載する
5. THE README SHALL コスト見積もり情報を提供する

### 要件8: 環境構築の自動化

**ユーザーストーリー:** 開発者として、簡単なコマンドで環境を構築・破棄したい。これにより、迅速に検証環境を立ち上げられる。

#### 受入基準

1. THE README SHALL Terraform初期化コマンドを記載する
2. THE README SHALL 環境構築コマンド（terraform apply）を記載する
3. THE README SHALL 環境破棄コマンド（terraform destroy）を記載する
4. THE README SHALL kubectlの設定手順を記載する
5. WHEN Terraform_Module が実行される THEN THE System SHALL 必要な全てのリソースを自動的に作成する
