#!/usr/bin/env bash
# Pre-sync prerequisites: apply Polaris secrets and build/load the custom Superset image.
# Called automatically by `make sync` / `make apply`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-data-platform}"
SUPERSET_IMAGE="lakehouse/superset:6.0.0"

echo "==> Applying Polaris prerequisite secrets..."
kubectl apply -f "$SCRIPT_DIR/manifests/secrets.yaml"

echo "==> Building Superset custom image..."
docker build -t "$SUPERSET_IMAGE" "$SCRIPT_DIR/../images/superset/"

echo "==> Loading Superset image into kind cluster '$CLUSTER_NAME'..."
kind load docker-image "$SUPERSET_IMAGE" --name "$CLUSTER_NAME"

echo "==> Pre-sync complete."
