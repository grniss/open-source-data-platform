# Lakehouse Superset image
# Bakes in psycopg2 (Postgres metadata DB driver) and the Trino SQLAlchemy
# driver so the runtime image is self-contained — no pip installs at pod start.
#
# Build:
#   docker build -t lakehouse/superset:5.0.0 infra/images/superset/
# Load into kind:
#   kind load docker-image lakehouse/superset:5.0.0 --name data-platform
FROM apache/superset:5.0.0

# Superset 5.x's image uses a uv-managed venv at /app/.venv that ships without
# pip. We install directly into the venv's site-packages via the system pip's
# --target option so Superset imports them at runtime.
USER root
RUN pip install --no-cache-dir \
      --target=/app/.venv/lib/python3.10/site-packages \
      psycopg2-binary==2.9.10 \
      "trino[sqlalchemy]"==0.330.0 \
      authlib==1.3.0
USER superset
