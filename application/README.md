# Application

User-space code that runs **on** the platform deployed by [`../infra`](../infra).
Empty for now — populated in subsequent steps.

## Planned layout

```
application/
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

The infra layer provides Kubernetes services (Trino, Polaris, Spark Operator,
Superset, etc.). This application layer provides the **content** those
services run: dbt models, Spark ingestion jobs, RBAC policies, configuration files.
