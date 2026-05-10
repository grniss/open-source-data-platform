# Application

User-space code that runs **on** the platform deployed by [`../infra`](../infra).
Empty for now — populated in subsequent steps.

## Planned layout

```
application/
├── airflow/
│   └── dags/
│       ├── iceberg_maintenance.py     # compact / expire / orphan / manifest
│       ├── dbt_build.py               # runs `dbt build` against Trino + Spark
│       ├── spark_ingestion.py         # submits Spark ingestion jobs per source
│       ├── manifest_to_polaris.py     # dbt tags → Polaris policy YAMLs
│       └── lib/
│           └── iceberg_procedures.py  # shared Spark-submit helpers
├── spark/
│   └── ingestion/                     # one PySpark job per external source
│       ├── postgres_orders.py
│       └── ...
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml                   # trino + spark targets
│   ├── packages.yml                   # elementary-data/elementary
│   ├── models/
│   │   ├── raw/                       # sources.yml only
│   │   ├── silver/
│   │   └── gold/
│   └── tests/
├── polaris/
│   └── policies/                      # generated RBAC YAMLs (gitignored if dynamic)
└── trino/
    └── etc/
        └── event-listener.properties  # ships query events to Postgres
```

## Relationship to infra

The infra layer provides Kubernetes services (Airflow, Trino, Polaris,
Spark Operator, etc.). This application layer provides the **content** those
services run: DAGs, dbt models, Spark ingestion jobs, RBAC policies,
configuration files.

Airflow loads DAGs from this folder via gitSync (configured in
[`../infra/helm/airflow/values.yaml`](../infra/helm/airflow/values.yaml)).
