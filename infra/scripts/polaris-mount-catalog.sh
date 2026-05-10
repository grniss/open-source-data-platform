#!/usr/bin/env bash
# Bootstrap Polaris realm and create all catalogs declared under
# helm/polaris/files/desired-state/catalogs/*.yaml.
# Idempotent: safe to re-run at any time.
set -euo pipefail

NS=data-catalog
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
CATALOGS_DIR="$ROOT/helm/polaris/files/desired-state/catalogs"

# 1. Apply credential Secrets.
kubectl apply -f "$HERE/manifests/secrets.yaml"

# 2. Bootstrap realm + root principal if not already done.
ROOT_ID=$(kubectl -n "$NS" get secret polaris-root-creds -o jsonpath='{.data.clientId}' | base64 -d)
ROOT_SECRET=$(kubectl -n "$NS" get secret polaris-root-creds -o jsonpath='{.data.clientSecret}' | base64 -d)

if kubectl -n "$NS" exec deploy/polaris -- sh -c "
     curl -sf -o /dev/null -X POST http://localhost:8181/api/catalog/v1/oauth/tokens \
          -d 'grant_type=client_credentials' \
          -d 'client_id=$ROOT_ID' \
          -d 'client_secret=$ROOT_SECRET' \
          -d 'scope=PRINCIPAL_ROLE:ALL'
   " 2>/dev/null; then
  echo "-> polaris already bootstrapped, skipping"
else
  echo "-> bootstrapping polaris realm"
  kubectl -n "$NS" delete job polaris-bootstrap --ignore-not-found
  kubectl apply -f "$HERE/manifests/bootstrap-job.yaml"
  kubectl -n "$NS" wait --for=condition=complete --timeout=180s job/polaris-bootstrap
  kubectl -n "$NS" rollout restart deploy/polaris
  kubectl -n "$NS" rollout status deploy/polaris --timeout=120s
fi

# 3. Obtain OAuth token.
TOKEN=$(kubectl -n "$NS" exec deploy/polaris -- \
  curl -sS -X POST http://localhost:8181/api/catalog/v1/oauth/tokens \
       -d "grant_type=client_credentials" \
       -d "client_id=$ROOT_ID" \
       -d "client_secret=$ROOT_SECRET" \
       -d "scope=PRINCIPAL_ROLE:ALL" \
  | jq -r '.access_token')

# 4. Create each catalog declared in desired-state if it doesn't exist yet.
# 5. Ensure catalog_admin role exists, has CATALOG_MANAGE_CONTENT, and is
#    assigned to the service_admin principal-role (idempotent).
for f in "$CATALOGS_DIR"/*.yaml; do
  NAME=$(grep     '^name:'                    "$f" | awk '{print $2}')
  BASE=$(grep     'default-base-location:'   "$f" | awk '{print $2}')
  ENDPOINT=$(grep 'endpoint:'                "$f" | awk '{print $2}')
  REGION=$(grep 'region:'                "$f" | awk '{print $2}')
  ALLOWED=$(grep -E '^\s+-\s+' "$f" | awk '{print $2}' | jq -R -s '[split("\n") | .[] | select(. != "")]')

  STATUS=$(kubectl -n "$NS" exec deploy/polaris -- \
    curl -sS -o /dev/null -w "%{http_code}" \
         -H "Authorization: Bearer $TOKEN" \
         http://localhost:8181/api/management/v1/catalogs/"$NAME")

  if [ "$STATUS" = "200" ]; then
    echo "-> catalog '$NAME' already exists, skipping"
  else
    echo "-> creating catalog '$NAME'"
    kubectl -n "$NS" exec deploy/polaris -- \
      curl -sSf -X POST http://localhost:8181/api/management/v1/catalogs \
           -H "Authorization: Bearer $TOKEN" \
           -H "Content-Type: application/json" \
           -d "{
                 \"catalog\": {
                   \"name\": \"$NAME\",
                   \"type\": \"INTERNAL\",
                   \"properties\": {\"default-base-location\": \"$BASE\"},
                   \"storageConfigInfo\": {
                     \"storageType\": \"S3\",
                     \"allowedLocations\": $ALLOWED,
                     \"endpoint\": \"$ENDPOINT\",
                     \"stsEndpoint\": \"$ENDPOINT\",
                     \"region\": \"$REGION\",
                     \"pathStyleAccess\": \"true\"
                   }
                 }
               }"
    echo
    echo "-> catalog '$NAME' created"
  fi

  # Ensure catalog_admin role exists on the catalog.
  ROLE_STATUS=$(kubectl -n "$NS" exec deploy/polaris -- \
    curl -sS -o /dev/null -w "%{http_code}" \
         -H "Authorization: Bearer $TOKEN" \
         http://localhost:8181/api/management/v1/catalogs/"$NAME"/catalog-roles/catalog_admin)

  if [ "$ROLE_STATUS" = "404" ]; then
    echo "-> creating catalog_admin role on '$NAME'"
    kubectl -n "$NS" exec deploy/polaris -- \
      curl -sSf -X POST \
           http://localhost:8181/api/management/v1/catalogs/"$NAME"/catalog-roles \
           -H "Authorization: Bearer $TOKEN" \
           -H "Content-Type: application/json" \
           -d '{"catalogRole":{"name":"catalog_admin"}}'
    echo
  else
    echo "-> catalog_admin role already exists on '$NAME', skipping"
  fi

  # Grant CATALOG_MANAGE_CONTENT to catalog_admin (PUT is idempotent — re-adding an
  # existing grant returns 200, so no pre-check needed).
  echo "-> granting CATALOG_MANAGE_CONTENT to catalog_admin on '$NAME'"
  kubectl -n "$NS" exec deploy/polaris -- \
    curl -sS -o /dev/null \
         -X PUT \
         http://localhost:8181/api/management/v1/catalogs/"$NAME"/catalog-roles/catalog_admin/grants \
         -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" \
         -d '{"grant":{"type":"catalog","privilege":"CATALOG_MANAGE_CONTENT"}}'

  # Assign catalog_admin catalog-role to the service_admin principal-role
  # (PUT is idempotent — safe to call even when already assigned).
  echo "-> assigning catalog_admin on '$NAME' to service_admin"
  kubectl -n "$NS" exec deploy/polaris -- \
    curl -sS -o /dev/null \
         -X PUT \
         http://localhost:8181/api/management/v1/principal-roles/service_admin/catalog-roles/"$NAME" \
         -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" \
         -d '{"catalogRole":{"name":"catalog_admin"}}'

  echo "-> RBAC configured for '$NAME'"
done

echo
echo "done"
