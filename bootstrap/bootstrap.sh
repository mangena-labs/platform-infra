#!/usr/bin/env bash
# bootstrap/bootstrap.sh
# Run ONCE by a platform admin (Owner on all three subscriptions, can create Entra groups).
# Re-running is safe: every step checks whether its thing already exists.
set -euo pipefail

# ---------- 1. Fill these in ----------
TENANT_ID="b524872f-613e-4d34-9ee8-e8483f16e156"
SHARED_SUB="f8527497-4ad7-4f18-bce9-718323915256"     # learning profile: your Visual Studio Enterprise subscription id
NONPROD_SUB="f8527497-4ad7-4f18-bce9-718323915256"   # learning profile: the SAME id as SHARED_SUB
PROD_SUB=""   # learning profile: leave empty (dev + staging only). Full design: the Mangena-Prod subscription id
GH_APP_ID="5564127"
GH_APP_INSTALLATION_ID="177433798"
GH_APP_KEY_FILE="$HOME/src/mangena/mangena-terraform.private-key.pem"

GH_ORG="mangena-labs"
INFRA_REPO="platform-infra"
APP_REPO="orders-api"
LOCATION="southafricanorth"
STATE_RG="rg-tfstate"
STATE_SA="stmangenatfstate01"
ID_RG="rg-identities"
GH_ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"
ENVS=(dev staging)
declare -A ENV_SUB=( [dev]="$NONPROD_SUB" [staging]="$NONPROD_SUB" )
if [[ -n "$PROD_SUB" ]]; then ENVS+=(prod); ENV_SUB[prod]="$PROD_SUB"; fi    # prod appears once its subscription exists
mapfile -t ENV_SUBS < <(printf '%s\n' "${ENV_SUB[@]}" | sort -u)                 # each environment subscription, once
mapfile -t ALL_SUBS < <(printf '%s\n' "$SHARED_SUB" "${ENV_SUB[@]}" | sort -u)   # every subscription, once
ENABLE_DEFENDER="${ENABLE_DEFENDER:-false}"   # Defender for Containers is billed per vCore: true in the full design
PRIVATE_NETWORKING="${PRIVATE_NETWORKING:-false}"   # true = private-network runners (paid GitHub Team plan): full design
INFRA="repo:$GH_ORG/$INFRA_REPO"
APP="repo:$GH_ORG/$APP_REPO"

# ---------- helpers ----------
mi_create()    { az identity create -g "$ID_RG" -n "$1" -l "$LOCATION" --subscription "$SHARED_SUB" -o none; }
mi_principal() { az identity show -g "$ID_RG" -n "$1" --subscription "$SHARED_SUB" --query principalId -o tsv; }
mi_client()    { az identity show -g "$ID_RG" -n "$1" --subscription "$SHARED_SUB" --query clientId -o tsv; }
fed() {  # identity, credential name, subject
  az identity federated-credential show --identity-name "$1" -g "$ID_RG" --subscription "$SHARED_SUB" -n "$2" >/dev/null 2>&1 ||
  az identity federated-credential create --identity-name "$1" -g "$ID_RG" --subscription "$SHARED_SUB" \
    -n "$2" --issuer "$GH_ISSUER" --subject "$3" --audiences "$AUDIENCE" -o none
}
grant() {  # principal id, role, scope
  az role assignment create --assignee-object-id "$1" --assignee-principal-type ServicePrincipal \
    --role "$2" --scope "$3" -o none
}

# ---------- 2. Register Azure resource providers ----------
for SUB in "${ALL_SUBS[@]}"; do
  for RP in Microsoft.ContainerService Microsoft.Network Microsoft.Cdn Microsoft.KeyVault Microsoft.Sql \
            Microsoft.ContainerRegistry Microsoft.OperationalInsights Microsoft.Insights \
            Microsoft.ManagedIdentity Microsoft.Security Microsoft.PolicyInsights Microsoft.AlertsManagement; do
    az provider register --namespace "$RP" --subscription "$SUB" -o none
  done
done
az provider register --namespace GitHub.Network --subscription "$SHARED_SUB" -o none

# ---------- 3. Terraform state storage ----------
az group create -n "$STATE_RG" -l "$LOCATION" --subscription "$SHARED_SUB" -o none
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" --subscription "$SHARED_SUB" \
  --sku Standard_ZRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false -o none
az storage account blob-service-properties update -n "$STATE_SA" -g "$STATE_RG" --subscription "$SHARED_SUB" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 -o none
STATE_ID=$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --subscription "$SHARED_SUB" --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Owner" --scope "$STATE_ID" -o none
sleep 60   # new role assignments take a minute to take effect
az storage container create -n tfstate --account-name "$STATE_SA" --auth-mode login -o none
az lock create -n do-not-delete -g "$STATE_RG" --subscription "$SHARED_SUB" --lock-type CanNotDelete -o none

# ---------- 4. Pipeline identities and their OIDC trust ----------
az group create -n "$ID_RG" -l "$LOCATION" --subscription "$SHARED_SUB" -o none

mi_create id-gh-shared-plan;     fed id-gh-shared-plan pr   "$INFRA:pull_request"
                                 fed id-gh-shared-plan main "$INFRA:ref:refs/heads/main"
mi_create id-gh-shared-apply;    fed id-gh-shared-apply env "$INFRA:environment:shared"
mi_create id-gh-github-settings; fed id-gh-github-settings env "$INFRA:environment:github-settings"
                                 fed id-gh-github-settings pr  "$INFRA:pull_request"
                                 fed id-gh-github-settings main "$INFRA:ref:refs/heads/main"
mi_create id-gh-acr-push;        fed id-gh-acr-push main "$APP:ref:refs/heads/main"
for ENV in "${ENVS[@]}"; do
  mi_create "id-gh-infra-plan-$ENV";  fed "id-gh-infra-plan-$ENV" pr   "$INFRA:pull_request"
                                      fed "id-gh-infra-plan-$ENV" main "$INFRA:ref:refs/heads/main"
  mi_create "id-gh-infra-apply-$ENV"; fed "id-gh-infra-apply-$ENV" env "$INFRA:environment:$ENV"
  mi_create "id-gh-deploy-$ENV";      fed "id-gh-deploy-$ENV" env "$APP:environment:$ENV"
done
sleep 30   # let the new identities replicate in Entra ID

# ---------- 5. Starting permissions ----------
SHARED_SCOPE="/subscriptions/$SHARED_SUB"
ID_SCOPE="$SHARED_SCOPE/resourceGroups/$ID_RG"

P=$(mi_principal id-gh-shared-plan)
grant "$P" "Reader" "$SHARED_SCOPE";  grant "$P" "Storage Blob Data Contributor" "$STATE_ID"
P=$(mi_principal id-gh-shared-apply)
grant "$P" "Contributor" "$SHARED_SCOPE"
grant "$P" "Role Based Access Control Administrator" "$SHARED_SCOPE"
grant "$P" "Storage Blob Data Contributor" "$STATE_ID"
P=$(mi_principal id-gh-github-settings)
grant "$P" "Reader" "$ID_SCOPE";     grant "$P" "Storage Blob Data Contributor" "$STATE_ID"   # writes its own github.tfstate

for ENV in "${ENVS[@]}"; do
  ENV_SCOPE="/subscriptions/${ENV_SUB[$ENV]}"
  P=$(mi_principal "id-gh-infra-plan-$ENV")
  grant "$P" "Reader" "$ENV_SCOPE";  grant "$P" "Reader" "$SHARED_SCOPE"
  grant "$P" "Storage Blob Data Contributor" "$STATE_ID"
  P=$(mi_principal "id-gh-infra-apply-$ENV")
  grant "$P" "Contributor" "$ENV_SCOPE"
  grant "$P" "Role Based Access Control Administrator" "$ENV_SCOPE"
  grant "$P" "Resource Policy Contributor" "$ENV_SCOPE"   # Contributor can't create policy assignments
  grant "$P" "Reader" "$SHARED_SCOPE"
  grant "$P" "Storage Blob Data Contributor" "$STATE_ID"
done

# ---------- 6. SQL admin groups (one per environment) ----------
for ENV in "${ENVS[@]}"; do
  G="sg-sql-admins-$ENV"
  GID=$(az ad group show -g "$G" --query id -o tsv 2>/dev/null || \
        az ad group create --display-name "$G" --mail-nickname "$G" --query id -o tsv)
  MEMBER=$(mi_principal "id-gh-infra-apply-$ENV")
  [[ $(az ad group member check -g "$GID" --member-id "$MEMBER" --query value -o tsv) == "true" ]] || \
    az ad group member add -g "$GID" --member-id "$MEMBER"
  echo "sql_admin_group_object_id for $ENV = $GID   <- put this in environments/$ENV/platform.tfvars"
done

# ---------- 6b. Subscription guardrails (once per subscription) ----------
# Defender for Containers: scans images in ACR and watches running containers for attacks.
for SUB in "${ALL_SUBS[@]}"; do
  if [[ "$ENABLE_DEFENDER" == "true" ]]; then
    az security pricing create -n Containers --tier standard --subscription "$SUB" -o none
  fi
done
# Custom least-privilege role for app deploy identities: can manage only the Kubernetes
# objects an app's Helm chart contains, and is assigned on ONE namespace (Stage 2).
for SUB in "${ENV_SUBS[@]}"; do
  az role definition list --name "AKS App Deployer" --scope "/subscriptions/$SUB" --query "[0].id" -o tsv | grep -q . ||
  az role definition create --role-definition "{
    \"Name\": \"AKS App Deployer\",
    \"Description\": \"Deploy one app's Helm release into a single namespace.\",
    \"Actions\": [],
    \"DataActions\": [
      \"Microsoft.ContainerService/managedClusters/configmaps/*\",
      \"Microsoft.ContainerService/managedClusters/secrets/*\",
      \"Microsoft.ContainerService/managedClusters/services/*\",
      \"Microsoft.ContainerService/managedClusters/serviceaccounts/*\",
      \"Microsoft.ContainerService/managedClusters/pods/read\",
      \"Microsoft.ContainerService/managedClusters/pods/log/read\",
      \"Microsoft.ContainerService/managedClusters/events/read\",
      \"Microsoft.ContainerService/managedClusters/apps/deployments/*\",
      \"Microsoft.ContainerService/managedClusters/apps/replicasets/read\",
      \"Microsoft.ContainerService/managedClusters/batch/jobs/*\",
      \"Microsoft.ContainerService/managedClusters/autoscaling/horizontalpodautoscalers/*\",
      \"Microsoft.ContainerService/managedClusters/policy/poddisruptionbudgets/*\",
      \"Microsoft.ContainerService/managedClusters/networking.k8s.io/networkpolicies/*\",
      \"Microsoft.ContainerService/managedClusters/gateway.networking.k8s.io/httproutes/*\"
    ],
    \"NotDataActions\": [],
    \"AssignableScopes\": [\"/subscriptions/$SUB\"]
  }" -o none
done

# ---------- 7. GitHub variables and the one secret ----------
R="$GH_ORG/$INFRA_REPO"
gh variable set AZURE_TENANT_ID           -R "$R" -b "$TENANT_ID"
gh variable set SHARED_SUBSCRIPTION_ID    -R "$R" -b "$SHARED_SUB"
gh variable set NONPROD_SUBSCRIPTION_ID   -R "$R" -b "$NONPROD_SUB"
[[ -z "$PROD_SUB" ]] || gh variable set PROD_SUBSCRIPTION_ID -R "$R" -b "$PROD_SUB"   # absent = prod jobs skip
gh variable set SHARED_PLAN_CLIENT_ID     -R "$R" -b "$(mi_client id-gh-shared-plan)"
gh variable set SHARED_APPLY_CLIENT_ID    -R "$R" -b "$(mi_client id-gh-shared-apply)"
gh variable set GH_SETTINGS_CLIENT_ID     -R "$R" -b "$(mi_client id-gh-github-settings)"
gh variable set PUBLISH_APP_VARIABLES     -R "$R" -b "false"   # switched to true once the environments exist (Build checklist step 18)
gh variable set PRIVATE_RUNNERS           -R "$R" -b "$PRIVATE_NETWORKING"
gh variable set GH_APP_ID                 -R "$R" -b "$GH_APP_ID"
gh variable set GH_APP_INSTALLATION_ID    -R "$R" -b "$GH_APP_INSTALLATION_ID"
gh secret   set GH_APP_PRIVATE_KEY        -R "$R" < "$GH_APP_KEY_FILE"
for ENV in "${ENVS[@]}"; do
  gh variable set "${ENV^^}_PLAN_CLIENT_ID"  -R "$R" -b "$(mi_client "id-gh-infra-plan-$ENV")"
  gh variable set "${ENV^^}_APPLY_CLIENT_ID" -R "$R" -b "$(mi_client "id-gh-infra-apply-$ENV")"
done

R="$GH_ORG/$APP_REPO"
gh variable set AZURE_TENANT_ID        -R "$R" -b "$TENANT_ID"
gh variable set SHARED_SUBSCRIPTION_ID -R "$R" -b "$SHARED_SUB"
gh variable set ACR_PUSH_CLIENT_ID     -R "$R" -b "$(mi_client id-gh-acr-push)"
gh variable set PROD_ENABLED           -R "$R" -b "$([[ -n "$PROD_SUB" ]] && echo true || echo false)"
gh variable set PRIVATE_RUNNERS        -R "$R" -b "$PRIVATE_NETWORKING"
gh variable set ACR_NAME               -R "$R" -b "acrmangenashared"

echo "Bootstrap complete. Keep the .pem only until the GitHub settings stack's first run (Build checklist step 12), then delete it."
