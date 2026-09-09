COMPOSE ?= docker compose

.DEFAULT_GOAL := help

.PHONY: help setup up up-tls down restart logs ps pull backup psql shell tunnel

help: ## Mostra questo aiuto
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}'

setup: ## Crea .env con password casuali
	@./scripts/setup.sh

up: ## Avvia Kestra + Postgres
	$(COMPOSE) up -d
	@echo "Kestra sta partendo: 'make logs' per seguire l'avvio (30-60s al primo giro)."

up-tls: ## Avvia anche Caddy (HTTPS su KESTRA_DOMAIN)
	@grep -qE '^KESTRA_DOMAIN=.+' .env || { echo "Imposta KESTRA_DOMAIN (e ACME_EMAIL) in .env prima di usare il profilo tls."; exit 1; }
	$(COMPOSE) --profile tls up -d

down: ## Ferma tutto (i dati nei volumi restano)
	$(COMPOSE) --profile tls down

restart: ## Riavvia il servizio Kestra
	$(COMPOSE) restart kestra

logs: ## Segue i log di Kestra
	$(COMPOSE) logs -f kestra

ps: ## Stato dei container
	$(COMPOSE) ps

pull: ## Aggiorna le immagini alla versione indicata in .env
	$(COMPOSE) pull

backup: ## Dump di database + storage in ./backups
	@./scripts/backup.sh

psql: ## Apre una shell psql sul database
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

shell: ## Apre una shell nel container Kestra
	$(COMPOSE) exec kestra bash

tunnel: ## Stampa il comando per il tunnel SSH da usare sul tuo portatile
	@echo "ssh -N -L 8080:127.0.0.1:8080 UTENTE@IP_DEL_SERVER   # poi apri http://localhost:8080"
