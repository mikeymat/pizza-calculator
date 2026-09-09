# Kestra — istanza accessibile da remoto

Stack Docker Compose pronto all'uso per far girare [Kestra](https://kestra.io)
su un server e raggiungerlo da remoto: Kestra + PostgreSQL, autenticazione
attiva di default e un profilo opzionale con HTTPS automatico.

- **Kestra** `v2.0.0` (ultima LTS) in modalita' `server standalone`
- **PostgreSQL** come repository e coda (i dati sopravvivono ai riavvii)
- **Basic auth** obbligatoria: senza credenziali l'API risponde `401`
- **Profilo `tls`**: [Caddy](https://caddyserver.com) davanti a Kestra, con
  certificato Let's Encrypt e redirect HTTP → HTTPS
- **Flow di esempio** in `flows/`, caricati automaticamente all'avvio

## Provarlo subito su GitHub Codespaces

[![Apri in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/mikeymat/kestra)

Se non hai (ancora) un server, il repo e' pronto per Codespaces: `.devcontainer/`
crea la macchina con Docker, genera `.env` e avvia lo stack da solo. Al termine
trovi Kestra nel pannello **Ports** di VS Code, sulla porta 8080, a un indirizzo
tipo `https://<nome-codespace>-8080.app.github.dev`. URL e credenziali vengono
ristampati a ogni apertura del terminale.

La prima creazione richiede qualche minuto: scarica ~3 GB di immagini.

Due cose da sapere:

- **La porta e' privata**: la vedi solo tu, dopo il login su GitHub. Se ti serve
  che un servizio esterno chiami un webhook, rendila raggiungibile con
  `gh codespace ports visibility 8080:public -c "$CODESPACE_NAME"`.
- **Non e' un'istanza h24**: il codespace si ferma da solo dopo un po' di
  inattivita' e consuma le ore incluse nel piano. I dati restano nei volumi e
  tornano al riavvio, ma per qualcosa di stabile usa un server tuo, come
  descritto sotto.

## Prerequisiti

Una macchina raggiungibile in rete (VPS, server in ufficio, il tuo portatile)
con Docker Engine e il plugin Compose. Servono ~4 GB di RAM e ~10 GB di disco:
l'immagine completa di Kestra pesa circa 7 GB una volta estratta.

## Avvio

```bash
git clone <questo-repo> kestra && cd kestra
make setup     # genera .env con password casuali e stampa le credenziali
make up        # avvia Kestra + Postgres
make logs      # segui l'avvio: il primo giro richiede 30-60 secondi
```

Poi apri `http://localhost:8080`: Kestra mostra la sua pagina di login, dove
inserisci l'email e la password stampate da `make setup`. Se le hai perse sono
sempre in chiaro nel `.env`:

```bash
grep KESTRA_ADMIN .env
```

Per cambiare password modifica `KESTRA_ADMIN_PASSWORD` in `.env` e fai
`make restart`. Per chiamare l'API si usano le stesse credenziali in basic auth
(`curl -u email:password ...`).

Di default Kestra ascolta **solo su 127.0.0.1**: la sezione seguente spiega come
aprirlo verso l'esterno.

## Come collegarti da remoto

Tre modi, dal piu' sicuro al piu' comodo. Si configurano tutti in `.env`.

### A. Tunnel SSH — nessuna porta aperta su internet

Lascia `KESTRA_BIND=127.0.0.1` e dal tuo computer:

```bash
ssh -N -L 8080:127.0.0.1:8080 utente@ip-del-server
# poi apri http://localhost:8080
```

E' l'opzione da preferire se hai gia' accesso SSH al server: Kestra non e'
esposto su internet e il traffico viaggia dentro SSH. (`make tunnel` ristampa
il comando.)

### B. Porta esposta sulla rete

```dotenv
KESTRA_BIND=0.0.0.0
KESTRA_URL=http://IP_DEL_SERVER:8080/
```

`make up` e Kestra risponde su `http://IP_DEL_SERVER:8080`. La basic auth
protegge l'accesso, ma **il traffico e' in chiaro**: usalo su una rete di cui ti
fidi (LAN, VPN, Tailscale), non su internet aperto. Ricordati di aprire la porta
sul firewall, per esempio `sudo ufw allow 8080/tcp`.

### C. Dominio con HTTPS automatico (consigliato su internet)

Serve un dominio con record A/AAAA che punta al server e le porte 80/443 libere.

```dotenv
KESTRA_BIND=127.0.0.1          # Kestra resta interno, lo espone solo Caddy
KESTRA_DOMAIN=kestra.tuodominio.it
ACME_EMAIL=tu@tuodominio.it    # facoltativa: avvisi sui certificati
KESTRA_URL=https://kestra.tuodominio.it/
```

```bash
make up-tls
```

Caddy richiede il certificato a Let's Encrypt al primo avvio, rinnova da solo,
reindirizza HTTP su HTTPS e aggiunge l'header HSTS.

> `KESTRA_URL` deve sempre combaciare con l'URL che usi davvero: Kestra lo mette
> nei link della UI e negli URL dei webhook.

## Sicurezza

- Le credenziali stanno solo in `.env`, che e' in `.gitignore` con permessi 600.
  Non committarlo.
- La password admin deve avere almeno 8 caratteri con maiuscola, minuscola e
  numero, e l'utente deve essere un indirizzo email valido: sono requisiti di
  Kestra. Per cambiarla modifica `.env` e fai `make restart`.
- Postgres non e' pubblicato sull'host: e' raggiungibile solo da Kestra sulla
  rete interna di Compose.
- La porta di management `8081` non e' esposta: non e' autenticata.
- Gli URL dei webhook (`/api/v1/main/executions/webhook/...`) restano **fuori**
  dalla basic auth per design: la chiave nel flow e' l'unico segreto, quindi
  generane una casuale (`openssl rand -hex 24`).
- Kestra gira come `root` e monta il socket Docker per eseguire i task in
  container: significa accesso privilegiato all'host. Se non ti serve, togli
  `user: "root"` e il mount di `/var/run/docker.sock` da `docker-compose.yml`.

## Flow inclusi

Vengono caricati all'avvio da `flows/` (montata in sola lettura) nel namespace
`demo.setup`. Modificali dalla UI per provare, ma ricorda che la cartella e' la
fonte di verita' al riavvio: le modifiche da tenere vanno committate qui.

| File | Namespace | Cosa mostra |
| --- | --- | --- |
| `01_hello_world.yml` | `demo.setup` | flow minimo con input, per verificare l'istanza |
| `02_schedule_http_check.yml` | `demo.setup` | trigger `Schedule` (disabilitato) + chiamata HTTP |
| `03_webhook.yml` | `demo.setup` | ingresso da sistemi esterni via webhook |
| `04_python_in_docker.yml` | `demo.setup` | task Python eseguito in un container separato |
| `05_eventhub_to_kafka.yml` | `demo.integrazioni` | Azure Event Hub → Kafka a micro-batch |
| `06_eventhub_to_kafka_realtime.yml` | `demo.integrazioni` | la stessa cosa, un'esecuzione per evento |

### Event Hub → Kafka

I flow 05 e 06 fanno la stessa cosa con due compromessi diversi: il **05** apre
una finestra di consumo a ogni esecuzione schedulata e produce in blocco (una
esecuzione per batch: e' quello da usare con volumi seri); il **06** tiene il
trigger collegato all'Event Hub e fa partire un'esecuzione per ogni evento
(latenza minima, adatto a volumi contenuti).

Le credenziali non stanno nei file: entrambi leggono dal **KV Store** del
namespace (UI: Namespaces → `demo.integrazioni` → KV Store). Vanno create prima
di abilitare i trigger:

| Chiave | Valore |
| --- | --- |
| `EVENTHUB_NAMESPACE` | il namespace, senza `.servicebus.windows.net` |
| `EVENTHUB_NAME` | nome dell'Event Hub |
| `EVENTHUB_CONNECTION_STRING` | connection string con diritti di *Listen* |
| `EVENTHUB_CHECKPOINT_CONTAINER` | container Blob per i checkpoint |
| `AZURE_STORAGE_CONNECTION_STRING` | connection string dello Storage Account |
| `KAFKA_BOOTSTRAP_SERVERS` | es. `broker1:9093,broker2:9093` |

Il checkpoint store su Azure Blob e' obbligatorio: e' li' che Event Hubs segna
fin dove hai letto, ed e' quello che fa ripartire ogni esecuzione da dove si era
fermata la precedente. Per un broker gestito (Confluent Cloud, MSK, Event Hubs
in modalita' Kafka) ci sono le righe SASL gia' pronte da decommentare nel flow.

I trigger sono **disabilitati**: abilitali dalla UI dopo aver creato le KV e
provato il flow a mano.

Esempio di esecuzione via API:

```bash
curl -u "$KESTRA_ADMIN_EMAIL:$KESTRA_ADMIN_PASSWORD" \
  -X POST "$KESTRA_URL/api/v1/main/executions/demo.setup/01_hello_world?wait=true" \
  -F name=Michele
```

## Comandi

`make` senza argomenti elenca tutto:

| Comando | Azione |
| --- | --- |
| `make setup` | crea `.env` con password casuali |
| `make up` / `make up-tls` | avvia senza / con HTTPS |
| `make down` | ferma tutto (i volumi restano) |
| `make logs` / `make ps` | log di Kestra / stato dei container |
| `make backup` | dump di database e storage in `backups/` |
| `make psql` / `make shell` | shell su Postgres / dentro Kestra |
| `make pull` | scarica le immagini della versione in `.env` |

## Aggiornamento

Cambia `KESTRA_VERSION` in `.env`, poi:

```bash
make backup && make pull && make up
```

## Ripristino da backup

```bash
gunzip -c backups/kestra-db-AAAAMMGG-HHMMSS.sql.gz \
  | docker compose exec -T postgres psql -U kestra -d kestra
gunzip -c backups/kestra-storage-AAAAMMGG-HHMMSS.tar.gz \
  | docker compose exec -T kestra tar -C /app -xf -
make restart
```

## Struttura

```
docker-compose.yml   Kestra + Postgres, e Caddy nel profilo "tls"
.devcontainer/       avvio automatico su GitHub Codespaces
.env.example         tutte le variabili, commentate
Makefile             comandi di uso quotidiano
caddy/Caddyfile      reverse proxy e TLS
flows/               flow versionati, caricati all'avvio
scripts/setup.sh     genera .env con password casuali
scripts/backup.sh    dump di database e storage
```

## Se qualcosa non va

- **Il container riparte in loop**: `make logs`. Un errore di configurazione
  compare nei primi secondi di log.
- **`401` su tutte le chiamate**: la basic auth vuole email + password di
  `.env`; l'endpoint `/ping` invece e' sempre aperto ed e' utile per capire se
  il server e' su.
- **La UI si apre ma i dati non arrivano**: quasi sempre `KESTRA_URL` non
  combacia con l'URL da cui stai navigando.
- **Il certificato non viene emesso**: il dominio deve risolvere su questo
  server e le porte 80 e 443 devono essere raggiungibili da internet;
  `docker compose logs caddy` dice il motivo esatto.
- **`FATAL: password authentication failed`**: hai rigenerato `.env` su un
  volume Postgres che esisteva gia'. O rimetti la vecchia `POSTGRES_PASSWORD`,
  o riparti pulito con `docker compose down -v` (cancella i dati).
- **I task Docker falliscono**: serve il mount di `/var/run/docker.sock` e la
  stessa path `/tmp/kestra-wd` dentro e fuori dal container (gia' configurati).
