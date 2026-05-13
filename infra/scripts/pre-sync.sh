#!/usr/bin/env bash
# Pre-sync prerequisites: apply Polaris secrets and build/load the custom Superset image.
# Called automatically by `make sync` / `make apply`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-data-platform}"
SUPERSET_IMAGE="lakehouse/superset:6.0.0"
DBT_SPARK_IMAGE="lakehouse/dbt-spark:latest"

echo "==> Applying Polaris prerequisite secrets..."
kubectl apply -f "$SCRIPT_DIR/manifests/secrets.yaml"

echo "==> Building Superset custom image..."
docker build -t "$SUPERSET_IMAGE" "$SCRIPT_DIR/../images/superset/"

echo "==> Loading Superset image into kind cluster '$CLUSTER_NAME'..."
kind load docker-image "$SUPERSET_IMAGE" --name "$CLUSTER_NAME"

echo "==> Building dbt-spark image..."
docker build -t "$DBT_SPARK_IMAGE" "$REPO_ROOT/application/dbt/"

echo "==> Loading dbt-spark image into kind cluster '$CLUSTER_NAME'..."
kind load docker-image "$DBT_SPARK_IMAGE" --name "$CLUSTER_NAME"

echo "==> Pre-sync complete."
