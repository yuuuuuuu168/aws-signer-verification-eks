# Kubernetesマニフェストファイル

このディレクトリには、AWS Signer + Kyverno検証環境で使用するKubernetesマニフェストファイルが含まれています。

## ファイル一覧

### 1. kyverno-policy.yaml

Kyvernoの署名検証ポリシーを定義するClusterPolicyです。

**機能:**
- AWS Signerで署名されたコンテナイメージのみをデプロイ可能にする
- 署名されていないイメージのデプロイを拒否
- ECRリポジトリのイメージを検証対象とする
- システムネームスペース（kube-system等）は除外

**適用方法:**
```bash
kubectl apply -f kyverno-policy.yaml
```

**確認方法:**
```bash
kubectl get clusterpolicy verify-image-signature
kubectl describe clusterpolicy verify-image-signature
```

**注意事項:**
- Kyverno 1.10以上が必要
- Kyverno ServiceAccountにIRSA設定が必要
- `validationFailureAction: Enforce`により、検証失敗時はPod作成が拒否されます

### 2. nginx-signed.yaml

署名済みNginxイメージを使用したPodとServiceのマニフェストです。

**構成:**
- **Pod**: 署名済みECRイメージを使用
- **Service**: ClusterIP型、ポート80で公開

**使用前の準備:**
1. `<ECR_REPOSITORY_URL>`を実際のECRリポジトリURLに置き換える
   ```bash
   export ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
   sed -i "s|<ECR_REPOSITORY_URL>|$ECR_REPO|g" nginx-signed.yaml
   ```

2. イメージに署名を付与（AWS Signerセクション参照）

**デプロイ方法:**
```bash
kubectl apply -f nginx-signed.yaml
```

**確認方法:**
```bash
kubectl get pods nginx-signed
kubectl get svc nginx-signed-service
kubectl describe pod nginx-signed
```

**アクセス方法:**
```bash
# ポートフォワーディング
kubectl port-forward pod/nginx-signed 8080:80

# 別のターミナルで
curl http://localhost:8080
```

**期待される動作:**
- Podが正常に作成される（`Running`状態）
- Kyvernoが署名を検証し、検証成功
- Nginxのウェルカムページにアクセス可能

### 3. nginx-unsigned.yaml

署名されていないNginxイメージを使用したPodのマニフェストです（検証用）。

**目的:**
- Kyvernoポリシーが正しく動作することを確認
- 署名なしイメージのデプロイが拒否されることを検証

**使用方法:**
```bash
kubectl apply -f nginx-unsigned.yaml
```

**期待される動作:**
- Pod作成が拒否される
- エラーメッセージに`image verification failed`が含まれる
- Kyvernoログに検証失敗が記録される

**エラーメッセージ例:**
```
Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request: 
policy Pod/default/nginx-unsigned for resource violation:
verify-image-signature:
  verify-aws-signer: 'image verification failed for nginx:latest: signature not found'
```

## 使用フロー

### 初回セットアップ

1. **Kyvernoのインストール**
   ```bash
   helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace
   ```

2. **IRSA設定**
   ```bash
   export KYVERNO_ROLE_ARN=$(cd terraform && terraform output -raw kyverno_role_arn)
   kubectl annotate serviceaccount kyverno -n kyverno eks.amazonaws.com/role-arn=$KYVERNO_ROLE_ARN
   kubectl rollout restart deployment kyverno-admission-controller -n kyverno
   ```

3. **ポリシーの適用**
   ```bash
   kubectl apply -f kyverno-policy.yaml
   ```

### 署名済みイメージのデプロイ

1. **イメージURLの設定**
   ```bash
   export ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
   sed -i "s|<ECR_REPOSITORY_URL>|$ECR_REPO|g" nginx-signed.yaml
   ```

2. **デプロイ**
   ```bash
   kubectl apply -f nginx-signed.yaml
   ```

3. **確認**
   ```bash
   kubectl get pods nginx-signed
   kubectl logs nginx-signed
   ```

### 署名なしイメージの検証

1. **デプロイ試行**
   ```bash
   kubectl apply -f nginx-unsigned.yaml
   ```

2. **エラー確認**
   - コマンド出力でエラーメッセージを確認
   - Kyvernoログで詳細を確認

### クリーンアップ

```bash
# Podとサービスの削除
kubectl delete -f nginx-signed.yaml

# ポリシーの削除（オプション）
kubectl delete -f kyverno-policy.yaml
```

## トラブルシューティング

### ポリシーが適用されない

**確認項目:**
```bash
# ポリシーの状態
kubectl get clusterpolicy

# Webhookの登録
kubectl get validatingwebhookconfigurations | grep kyverno

# Kyvernoのログ
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller
```

### 署名済みイメージがデプロイできない

**確認項目:**
```bash
# イメージの署名確認
notation inspect $ECR_REPO:latest

# ServiceAccountのアノテーション確認
kubectl describe serviceaccount kyverno -n kyverno

# IAMロールの権限確認
aws iam get-role-policy --role-name aws-signer-verification-kyverno-role --policy-name KyvernoSignerPolicy
```

### ImagePullBackOff エラー

**確認項目:**
```bash
# ECRリポジトリの存在確認
aws ecr describe-repositories --repository-names nginx-signed

# イメージの存在確認
aws ecr list-images --repository-name nginx-signed

# ノードのIAMロール確認
kubectl describe node | grep "ProviderID"
```

## 参考情報

- [Kyverno公式ドキュメント](https://kyverno.io/docs/)
- [Kyverno Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)
- [AWS Signer](https://docs.aws.amazon.com/signer/)
- [Notation Project](https://notaryproject.dev/)

## 注意事項

- 本マニフェストは検証環境向けです
- 本番環境では、リソース制限、ヘルスチェック、レプリカ数などを適切に設定してください
- ポリシーの`validationFailureAction`を`Audit`に変更すると、警告のみでデプロイを許可します（テスト用）
