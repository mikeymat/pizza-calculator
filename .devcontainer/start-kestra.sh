#!/usr/bin/env bash
# Eseguito da Codespaces alla creazione: prepara .env e avvia lo stack.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
	# Dentro un codespace la porta non e' esposta su internet: la raggiungi solo
	# attraverso il port forwarding autenticato di GitHub. Il bind su 0.0.0.0
	# serve perche' il forwarder veda la porta pubblicata da Docker.
	export KESTRA_BIND=0.0.0.0
	export KESTRA_ADMIN_EMAIL="${GITHUB_USER:-admin}@users.noreply.github.com"
	if [[ -n "${CODESPACE_NAME:-}" ]]; then
		export KESTRA_URL="https://${CODESPACE_NAME}-8080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}/"
	fi
	./scripts/setup.sh
fi

echo "Scarico le immagini (la prima volta ~3 GB, qualche minuto)..."
docker compose pull --quiet
docker compose up -d

echo "Attendo che Kestra risponda..."
for _ in $(seq 1 120); do
	if curl -sf -o /dev/null http://127.0.0.1:8080/ping; then
		echo "Kestra e' pronto."
		exit 0
	fi
	sleep 5
done

echo "Kestra non ha risposto entro 10 minuti: controlla 'docker compose logs kestra'." >&2
exit 1
