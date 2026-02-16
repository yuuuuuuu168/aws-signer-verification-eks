# AWS Signer EKS検証環境

## 概要

AWS Signerを使用したコンテナイメージの署名検証環境を、Kubernetes（EKS）上でKyvernoを用いて構築するための検証環境です。

### 主な特徴

- **コンテナイメージ署名**: AWS Signerによる信頼性の高い署名機能
- **自動検証**: Kyvernoポリシーエンジンによる署名の自動検証
- **コスト最適化**: 月額約$120の最小構成（検証環境向け）
- **Infrastructure as Code**: Terraformによる完全自動化されたインフラ構築

## 想定コスト

本構成の月額想定コスト（東京リージョン: ap-northeast-1）:

| リソース | 構成 | 月額概算 |
|---------|------|---------|
| EKSコントロールプレーン | 1クラスタ | $73 |
| EC2インスタンス | t3.small × 1ノード | $15 |
| NATゲートウェイ | 1台 | $32 |
| その他 | ECR、データ転送等 | $1-5 |
| **合計** | | **約$120-125** |

> **重要**: 使用後は必ず`terraform destroy`でリソースを削除してください。

## 前提条件

### 必要なツール

- **Terraform**: v1.0以上
- **AWS CLI**: v2.0以上
- **kubectl**: v1.28以上
- **Helm**: v3.0以上

### AWSアカウント要件

- 有効なAWSアカウント
- AWS CLIで設定済みの認証情報
- 以下のサービスへのアクセス権限: VPC、EKS、ECR、AWS Signer、IAM、EC2

---

## セットアップ手順

### 1. AWS認証情報の設定

```bash
aws configure
```

以下の情報を入力:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name: `ap-northeast-1`
- Default output format: `json`

### 2. Terraformでインフラ構築

```bash
cd terraform
terraform init
terraform apply
```

確認プロンプトで `yes` と入力します。実行時間は約10-15分です。

### 3. kubectlの設定

```bash
aws eks update-kubeconfig --region ap-northeast-1 --name aws-signer-verification-eks
```

ノードの確認:
```bash
kubectl get nodes
```

### 4. AWS Signer署名プロファイルの作成

AWSマネジメントコンソールで以下を実行:

1. AWS Signerサービスを開く
2. 「署名プロファイルの作成」をクリック
3. 以下を設定:
   - プロファイル名: `container_signing_profile`
   - プラットフォーム: **Notation - OCI Artifacts**
   - 署名の有効期間: `135 months`（デフォルト）
4. 作成完了

### 5. CodeBuildでイメージビルドと署名

```bash
# ビルドを開始
aws codebuild start-build \
  --project-name aws-signer-verification-nginx-build \
  --region ap-northeast-1
```

ビルドステータスの確認:
```bash
aws codebuild batch-get-builds \
  --ids <BUILD_ID> \
  --region ap-northeast-1 \
  --query 'builds[0].buildStatus' \
  --output text
```

`SUCCEEDED`が表示されれば成功です。

### 6. cert-managerのインストール

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 7. Kyvernoのインストール

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1
```

### 8. kyverno-notation-awsのインストール

```bash
kubectl apply -f install.yaml
```

CRDの適用:
```bash
kubectl apply -f https://raw.githubusercontent.com/nirmata/kyverno-notation-aws/main/config/crds/notation.nirmata.io_trustpolicies.yaml
kubectl apply -f https://raw.githubusercontent.com/nirmata/kyverno-notation-aws/main/config/crds/notation.nirmata.io_truststores.yaml
```

### 9. TrustStoreとTrustPolicyの設定

```bash
kubectl apply -f kubernetes/truststore.yaml
kubectl apply -f kubernetes/trustpolicy.yaml
```

### 10. IRSAの設定

```bash
eksctl create iamserviceaccount \
  --name kyverno-notation-aws \
  --namespace kyverno-notation-aws \
  --cluster aws-signer-verification-eks \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
  --attach-policy-arn <KYVERNO_POLICY_ARN> \
  --approve \
  --override-existing-serviceaccounts
```

Podを再起動:
```bash
kubectl rollout restart deployment kyverno-notation-aws -n kyverno-notation-aws
```

### 11. Kyvernoポリシーの適用

```bash
kubectl apply -f kubernetes/kyverno-policy-final.yaml
```

---

## 動作確認

### 署名済みイメージのデプロイ（成功）

```bash
kubectl apply -f kubernetes/nginx-signed.yaml
```

**期待される結果:**
```
pod/nginx-signed created
```

Podの状態確認:
```bash
kubectl get pod nginx-signed
```

**期待される出力:**
```
NAME           READY   STATUS    RESTARTS   AGE
nginx-signed   1/1     Running   0          30s
```

✅ Podが`Running`状態になれば、署名検証が成功しています。

### 署名なしイメージのデプロイ（拒否）

```bash
kubectl apply -f kubernetes/nginx-unsigned.yaml
```

**期待される結果（エラー）:**
```
Error from server: error when creating "kubernetes/nginx-unsigned.yaml": admission webhook "validate.kyverno.svc-fail" denied the request: 

resource Pod/default/nginx-unsigned was blocked due to the following policies 

check-images:
  call-aws-signer-extension: |
    failed to verify image ...
```

✅ このエラーが表示されれば、Kyvernoポリシーが正しく動作し、署名なしイメージを拒否しています。

### 検証結果のまとめ

| シナリオ | イメージ | 期待される結果 | 実際の結果 |
|---------|---------|--------------|-----------|
| 署名済みイメージ | ECR nginx-signed:latest | Pod作成成功、Running状態 | ✅ 成功 |
| 署名なしイメージ | Docker Hub nginx:latest | デプロイ拒否 | ✅ 拒否された |

---

## クリーンアップ

> **重要**: 以下の手順を実行して、すべてのリソースを削除し、課金を停止してください。

### 1. Kubernetesリソースの削除

```bash
# ポリシーを一時的にAuditモードに変更
kubectl patch clusterpolicy check-images --type=merge -p '{"spec":{"validationFailureAction":"Audit"}}'

# Podを削除
kubectl delete pod nginx-signed --ignore-not-found=true

# 各ネームスペースのリソースを削除
kubectl delete all --all -n default
kubectl delete all --all -n kyverno
kubectl delete all --all -n kyverno-notation-aws

# ClusterPolicyを削除
kubectl delete clusterpolicy check-images --ignore-not-found=true

# ネームスペースを削除
kubectl delete namespace cert-manager --ignore-not-found=true
kubectl delete namespace kyverno --ignore-not-found=true
kubectl delete namespace kyverno-notation-aws --ignore-not-found=true
```

### 2. IRSAの削除

```bash
# CloudFormationスタックを確認
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `eksctl-aws-signer-verification-eks`)].StackName' \
  --output text

# スタックが存在する場合は削除
aws cloudformation delete-stack \
  --stack-name eksctl-aws-signer-verification-eks-addon-iamserviceaccount-kyverno-notation-aws-kyverno-notation-aws
```

### 3. AWS Signerプロファイルの削除

```bash
# 署名プロファイルを削除
aws signer cancel-signing-profile \
  --profile-name container_signing_profile \
  --region ap-northeast-1
```

### 4. ECRイメージの削除（Terraform destroyの前に実行）

```bash
# ECRリポジトリ名を取得
REPO_NAME=$(aws ecr describe-repositories \
  --query 'repositories[?contains(repositoryName, `nginx-signed`)].repositoryName' \
  --output text \
  --region ap-northeast-1)

# イメージが存在する場合は削除
if [ ! -z "$REPO_NAME" ]; then
  aws ecr batch-delete-image \
    --repository-name $REPO_NAME \
    --image-ids "$(aws ecr list-images --repository-name $REPO_NAME --query 'imageIds[*]' --output json --region ap-northeast-1)" \
    --region ap-northeast-1
fi
```

### 5. Terraformでインフラを削除

```bash
cd terraform
terraform destroy
```

確認プロンプトで `yes` と入力します。実行時間は約10-15分です。

### 6. 残存リソースの確認

```bash
# EKSクラスタの確認
aws eks list-clusters --region ap-northeast-1

# ECRリポジトリの確認
aws ecr describe-repositories --region ap-northeast-1

# CloudWatch Logsの確認
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/aws-signer-verification-eks \
  --region ap-northeast-1

# IAMロールの確認（eksctlで作成されたもの）
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `eksctl-aws-signer-verification-eks`)].RoleName' \
  --output table
```

すべて空の結果が返れば、クリーンアップ完了です。

---

## 参考リンク

- [AWS Signer公式ドキュメント](https://docs.aws.amazon.com/signer/)
- [Kyverno公式ドキュメント](https://kyverno.io/)
- [kyverno-notation-aws GitHub](https://github.com/nirmata/kyverno-notation-aws)
- [AWS公式ブログ: Container Image Signing with AWS Signer and Amazon EKS](https://aws.amazon.com/blogs/containers/announcing-container-image-signing-with-aws-signer-and-amazon-eks/)
