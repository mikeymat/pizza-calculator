#!/usr/bin/env bash
# Ristampa URL e credenziali di accesso all'apertura del terminale.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || exit 0

# shellcheck disable=SC1091
set -a; source .env; set +a

cat <<MSG

  Kestra:   ${KESTRA_URL:-http://localhost:8080/}
  utente:   ${KESTRA_ADMIN_EMAIL}
  password: ${KESTRA_ADMIN_PASSWORD}

  Apri l'URL dal pannello "Ports" di VS Code (porta 8080).
  La porta e' privata: visibile solo a te, dopo il login su GitHub.
  Per aprirla a chi ha il link (serve per i webhook da servizi esterni):
    gh codespace ports visibility 8080:public -c "\$CODESPACE_NAME"

MSG
