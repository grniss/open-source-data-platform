SHELL := /usr/bin/env bash
ENV   ?= local

CLUSTER_NAME := data-platform
KIND_CONFIG  := kind/cluster.yaml

.PHONY: help check-tools cluster-up cluster-down namespaces \
        repos diff sync apply destroy status pre-sync \
        port-forward-grafana port-forward-superset port-forward-keycloak \
        polaris-mount-catalog rbac-publish-configmap trino-apply-password-secret

help:
	@echo "Targets:"
	@echo "  check-tools          Verify required CLIs are installed"
	@echo "  cluster-up           Create local kind cluster"
	@echo "  cluster-down         Delete local kind cluster"
	@echo "  namespaces           Apply namespace manifests"
	@echo "  repos                Add/update Helm repositories"
	@echo "  diff   ENV=local     Show diff vs cluster (helmfile diff)"
	@echo "  sync   ENV=local     Deploy / update all releases"
	@echo "  apply  ENV=local     Same as sync (idempotent)"
	@echo "  destroy ENV=local    Uninstall all releases"
	@echo "  status               List installed releases per namespace"
	@echo "  pre-sync             Apply Polaris secrets + build/load custom images (auto-run by sync)"
	@echo ""
	@echo "Polaris ops (run AFTER sync):"
	@echo "  polaris-mount-catalog        Bootstrap realm + apply desired-state catalog YAMLs"
	@echo "  rbac-publish-configmap       Publish rbac.yaml as a ConfigMap"
	@echo "  trino-apply-password-secret  Create/update trino-password-db Secret from files/password.db"

check-tools:
	@command -v kind     >/dev/null || { echo "kind not found";     exit 1; }
	@command -v kubectl  >/dev/null || { echo "kubectl not found";  exit 1; }
	@command -v helm     >/dev/null || { echo "helm not found";     exit 1; }
	@command -v helmfile >/dev/null || { echo "helmfile not found"; exit 1; }
	@echo "All tools present."

cluster-up: check-tools
	kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

cluster-down:
	kind delete cluster --name $(CLUSTER_NAME)

namespaces:
	kubectl apply -f namespaces.yaml

repos:
	helmfile -e $(ENV) repos

diff: namespaces repos
	helmfile -e $(ENV) diff

pre-sync:
	./scripts/pre-sync.sh

sync apply: namespaces repos pre-sync
	helmfile -e $(ENV) sync

destroy:
	helmfile -e $(ENV) destroy

status:
	@for ns in data-catalog query-engines spark-jobs storage bi observability; do \
	  echo "== $$ns =="; helm list -n $$ns; \
	done

# -------- Polaris catalog mount --------
polaris-mount-catalog:
	./scripts/polaris-mount-catalog.sh
