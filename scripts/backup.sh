#!/usr/bin/env bash
# Dump del database e dello storage interno di Kestra in ./backups/.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; [[ -f .env ]] && source .env; set +a

stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups

echo "Dump del database..."
docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-kestra}" -d "${POSTGRES_DB:-kestra}" \
	| gzip > "backups/kestra-db-${stamp}.sql.gz"

echo "Archivio dello storage interno (/app/storage)..."
docker compose exec -T kestra tar -C /app -cf - storage \
	| gzip > "backups/kestra-storage-${stamp}.tar.gz"

echo "Fatto:"
ls -lh "backups/kestra-db-${stamp}.sql.gz" "backups/kestra-storage-${stamp}.tar.gz"
