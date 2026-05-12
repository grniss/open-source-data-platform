package trino

import future.keywords.in

default allow = false

# Helpers — data document is pushed by Airflow rbac_sync DAG to /v1/data/trino/rbac.
user_roles(user) := data.trino.rbac.users[user].roles

role_catalog_access(role, catalog) := data.trino.rbac.roles[role].trino[catalog]

# Table-level operations: allow if any role grants sufficient access for the catalog.
allow {
    user    := input.context.identity.user
    catalog := input.resource.table.catalogName
    some role in user_roles(user)
    access  := role_catalog_access(role, catalog)
    operation_allowed(access, input.action.operation)
}

# Schema-level operations (SHOW SCHEMAS, etc.).
allow {
    user    := input.context.identity.user
    catalog := input.resource.schema.catalogName
    some role in user_roles(user)
    access  := role_catalog_access(role, catalog)
    access in ["read-only", "all"]
}

# read-only covers SELECT and metadata queries only.
operation_allowed("read-only", op) {
    op in [
        "SELECT_FROM_TABLE",
        "SELECT_FROM_VIEW",
        "SHOW_TABLES",
        "SHOW_SCHEMAS",
        "SHOW_COLUMNS",
        "SHOW_CREATE_TABLE",
    ]
}

# all covers every operation.
operation_allowed("all", _)
