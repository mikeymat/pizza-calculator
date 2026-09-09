#!/usr/bin/env bash
# Genera un file .env pronto all'uso, con password casuali valide per Kestra.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
	echo ".env esiste gia': non lo sovrascrivo. Cancellalo se vuoi rigenerarlo." >&2
	exit 1
fi

# Solo caratteri alfanumerici: niente escaping da gestire nella URL JDBC o nel YAML.
random_alnum() {
	local raw
	raw="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')"
	printf '%s' "${raw:0:$1}"
}

pg_pass="$(random_alnum 32)"
# Password admin: >= 8 caratteri con maiuscola, minuscola e numero (requisito di Kestra).
admin_pass="$(random_alnum 20)Aa1"

email="${KESTRA_ADMIN_EMAIL:-admin@example.com}"
bind="${KESTRA_BIND:-127.0.0.1}"
url="${KESTRA_URL:-http://localhost:8080/}"

sed \
	-e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${pg_pass}|" \
	-e "s|^KESTRA_ADMIN_PASSWORD=.*|KESTRA_ADMIN_PASSWORD=${admin_pass}|" \
	-e "s|^KESTRA_ADMIN_EMAIL=.*|KESTRA_ADMIN_EMAIL=${email}|" \
	-e "s|^KESTRA_BIND=.*|KESTRA_BIND=${bind}|" \
	-e "s|^KESTRA_URL=.*|KESTRA_URL=${url}|" \
	.env.example > .env
chmod 600 .env

cat <<MSG

.env creato (permessi 600). Credenziali di accesso:

  utente:   ${email}
  password: ${admin_pass}

Salvale ora: la password non viene mostrata altrove.
Poi avvia con:  make up

MSG
