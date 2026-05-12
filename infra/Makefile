SHELL := /usr/bin/env bash
ENV   ?= local

CLUSTER_NAME := data-platform
KIND_CONFIG  := kind/cluster.yaml

.PHONY: help check-tools cluster-up cluster-down namespaces \
        repos diff sync apply destroy status \
        port-forward-grafana port-forward-superset port-forward-airflow \
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
	@echo "  port-forward-*       Convenience port-forwards (Grafana, Superset, Airflow)"
	@echo ""
	@echo "Polaris ops (run AFTER sync):"
	@echo "  polaris-mount-catalog        Bootstrap realm + apply desired-state catalog YAMLs"
	@echo "  rbac-publish-configmap       Publish rbac.yaml as a ConfigMap for the rbac_sync DAG"
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

sync apply: namespaces repos
	helmfile -e $(ENV) sync

destroy:
	helmfile -e $(ENV) destroy

status:
	@for ns in data-catalog query-engines spark-jobs orchestration storage bi observability; do \
	  echo "== $$ns =="; helm list -n $$ns; \
	done

port-forward-grafana:
	kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80

port-forward-superset:
	kubectl -n bi port-forward svc/superset 8088:8088

port-forward-airflow:
	kubectl -n orchestration port-forward svc/airflow-webserver 8081:8080

# -------- Polaris catalog mount --------
polaris-mount-catalog:
	./scripts/polaris-mount-catalog.sh

# -------- RBAC ConfigMap --------
# Publishes rbac.yaml so the Airflow rbac_sync DAG can read it in-cluster.
# Re-run whenever rbac.yaml changes.
rbac-publish-configmap:
	kubectl -n data-catalog create configmap polaris-rbac-desired-state \
	  --from-file=rbac.yaml=helm/polaris/files/desired-state/rbac.yaml \
	  --dry-run=client -o yaml | kubectl apply -f -

# -------- Trino password Secret --------
# Creates or replaces the trino-password-db Secret from helm/trino/files/password.db.
# Run AFTER `make sync ENV=local`.
trino-apply-password-secret:
	kubectl -n query-engines create secret generic trino-password-db \
	  --from-file=password.db=helm/trino/files/password.db \
	  --dry-run=client -o yaml | kubectl apply -f -

