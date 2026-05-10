# Infra — Kubernetes + Helmfile

Declarative deployment of the lakehouse platform on Kubernetes. All releases
are defined in [`helmfile.yaml`](helmfile.yaml); per-component values live
under [`helm/<component>/values.yaml`](helm/).

## Layout

```
infra/
├── Makefile               # bootstrap + lifecycle commands
├── helmfile.yaml          # all releases + repo sources + ordering (needs:)
├── namespaces.yaml        # one namespace per tier
├── envs/
│   ├── local.yaml         # kind cluster overrides
│   └── prod.yaml          # production overrides
├── kind/
│   └── cluster.yaml       # local kind cluster (3 nodes, port mappings)
└── helm/
    ├── polaris/                  # Iceberg REST catalog + RBAC
    ├── trino/                    # interactive engine
    ├── spark-operator/           # batch + ingestion engine controller
    ├── airflow/                  # orchestration (maintenance, dbt, spark ingestion)
    ├── minio/                    # local S3 (dev only — disabled in prod)
    ├── superset/                 # BI / dashboards
    ├── kube-prometheus-stack/    # Prometheus + Grafana + Alertmanager
    ├── loki/                     # log aggregation
    └── opencost/                 # k8s cost attribution
```

## Prerequisites

- `kind` ≥ 0.24
- `kubectl` ≥ 1.30
- `helm` ≥ 3.15
- `helmfile` ≥ 0.168

`make check-tools` verifies the above.

## Bootstrap (local)

```bash
make cluster-up           # create kind cluster
make sync ENV=local       # apply namespaces + deploy all charts
make status               # list installed releases
```

Stand-up takes ~10–15 minutes on first run (image pulls + Postgres init).

## Deploying to a real cluster

```bash
kubectl config use-context <your-cluster>
make sync ENV=prod
```

Override values per environment in [`envs/prod.yaml`](envs/prod.yaml).

## Common workflows

| Task | Command |
|------|---------|
| Preview changes | `make diff ENV=local` |
| Deploy / update | `make sync ENV=local` |
| List releases | `make status` |
| Tear down releases | `make destroy ENV=local` |
| Tear down cluster | `make cluster-down` |
| Open Grafana (3000) | `make port-forward-grafana` |
| Open Superset (8088) | `make port-forward-superset` |
| Open Airflow (8081) | `make port-forward-airflow` |

## Namespace map

| Namespace | Holds |
|-----------|-------|
| `data-catalog` | Polaris |
| `query-engines` | Trino |
| `spark-jobs` | Spark Operator + on-demand Spark applications (ingestion + batch) |
| `orchestration` | Airflow |
| `storage` | MinIO (local-only S3, disabled in `prod`) |
| `bi` | Superset |
| `observability` | Prometheus, Grafana, Loki, OpenCost |

## Release order (encoded via `needs:` in helmfile.yaml)

```
polaris           ─┐
                   ├─▶ trino ─┐
spark-operator ────┘          ├─▶ airflow
                              ├─▶ superset
kube-prometheus-stack ──┬─▶ loki
                        └─▶ opencost
minio   (local only — `condition: minio.enabled`, off in prod)
```

## Notes

- The Polaris chart reference (`oci://ghcr.io/apache/polaris/helm/polaris`)
  may need to be updated as the project graduates from incubation.
  If unavailable, fall back to building from `apache/polaris` source and
  publishing to your own OCI registry.
- **Local S3:** the `minio` release runs only when `minio.enabled=true`
  (set in `envs/local.yaml`). In `envs/prod.yaml` it's `false` and Iceberg
  points at real S3 instead.
- **Ingestion** is performed by Spark jobs submitted to the Spark Operator
  (no Airbyte). Each source has a small Spark job + Airflow DAG under
  `application/`.
- All charts expose `serviceMonitor` so kube-prometheus-stack scrapes them
  automatically — no extra wiring needed.
