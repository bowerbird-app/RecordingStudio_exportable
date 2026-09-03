#!/usr/bin/env bash
set -euo pipefail

sudo pg_ctlcluster 16 main start 2>/dev/null || true

for _ in $(seq 1 30); do
  if pg_isready -h localhost -U postgres >/dev/null 2>&1; then
    echo "PostgreSQL ready"
    exit 0
  fi
  sleep 1
done

echo "PostgreSQL did not become ready in time" >&2
exit 1
