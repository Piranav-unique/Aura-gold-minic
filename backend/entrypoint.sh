#!/bin/sh
set -e

echo "=== AGS Gold API startup ==="
echo "PORT=${PORT:-8000}"
echo "ENVIRONMENT=${ENVIRONMENT:-not set}"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL is not set."
  echo "In Railway: add PostgreSQL, then Variables -> DATABASE_URL -> reference Postgres."
  exit 1
fi

echo "Running database migrations..."
alembic upgrade head || echo "Database migrations skipped or failed"

echo "Starting API server on port ${PORT:-8000}..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
