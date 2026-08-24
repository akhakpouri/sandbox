#!/usr/bin/env bash
# Vault-side setup for LocalStack's secret delivery chain.
# Needed after every infra-vault restart: dev mode is in-memory storage
# (see infra/vault/CLAUDE.md), so auth methods/policies/roles/secrets
# configured here don't survive a pod restart even though the K8s-side
# RBAC (ServiceAccount, Role, ClusterRoleBinding) does.
set -euo pipefail

NAMESPACE=infra
POLICY_NAME=localstack-read
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE doesn't exist:" >&2
    exit 1
fi

# 2. Parse and export .env variables safely (ignores comments and empty lines)
while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    # Remove surrounding quotes from values if present and export
    key=$(echo "$line" | cut -d'=' -f1)
    value=$(echo "$line" | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    export "$key"="$value"
done < "$ENV_FILE"

# 3. Verify mandatory Vault variables are set
if [ -z "$AUTH_TOKEN" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_POD" ] || [ -z "$SECRET_PATH" ]; then
    echo "Error: Missing required Vault variables in $ENV_FILE" >&2
    exit 1
fi

echo "Connecting to Vault VAULT_ADDR in $VAULT_POD"

vault_exec() {
  kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault $*"
}

echo "==> Enabling kubernetes auth method"
if kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault auth list -format=json" | grep -q '"kubernetes/"'; then
  echo "    already enabled"
else
  vault_exec auth enable kubernetes
fi

echo "==> Configuring kubernetes auth (in-cluster host, Vault's own SA for TokenReview)"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- sh -c \
  "VAULT_TOKEN=$VAULT_TOKEN vault write auth/kubernetes/config kubernetes_host=\"https://\${KUBERNETES_SERVICE_HOST}:\${KUBERNETES_SERVICE_PORT}\""

echo "==> Writing policy '$POLICY_NAME' from policy.hcl"
kubectl exec -i -n "$NAMESPACE" "$VAULT_POD" -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault policy write $POLICY_NAME -" < "$SCRIPT_DIR/policy.hcl"

echo "==> Binding role 'localstack' to localstack-sa in $NAMESPACE"
vault_exec write auth/kubernetes/role/localstack \
  bound_service_account_names=localstack-sa \
  bound_service_account_namespaces="$NAMESPACE" \
  policies="$POLICY_NAME" \
  ttl=24h

if [ -z "${AUTH_TOKEN:-}" ]; then
  read -rsp "LocalStack auth token (app.localstack.cloud Hobby-plan token): " AUTH_TOKEN
  echo
fi

echo "==> Writing secret/localstack"
printf '%s' "$AUTH_TOKEN" | kubectl exec -i -n "$NAMESPACE" "$VAULT_POD" -- sh -c \
  "VAULT_TOKEN=$VAULT_TOKEN vault kv put $SECRET_PATH auth-token=-"

echo "==> Restarting localstack pod to pick up the secret"
kubectl delete pod -n "$NAMESPACE" -l app=localstack-app --ignore-not-found

echo "Done. Watch: kubectl get pods -n $NAMESPACE -l app=localstack-app -w"
