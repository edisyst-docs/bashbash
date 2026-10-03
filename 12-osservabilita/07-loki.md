# Loki: log centralizzati

> **Laboratorio**: `./lab.sh 12`, poi `cd 07-loki`. Cosa contiene: [lab/](lab/).

Loki raccoglie log da più macchine e li rende interrogabili da un punto solo — Grafana o il terminale.
Stessa logica di Prometheus per le metriche, ma applicata ai log: indicizza solo le **etichette** (job, host,
filename), non il testo delle righe. Questo lo rende molto più leggero di Elasticsearch/ELK, ma meno potente
per la ricerca full-text su volumi enormi.
Porta **3100**. Versione del laboratorio: 3.7 (2026). Documentazione: https://grafana.com/docs/loki/latest/

## Architettura

```
                                    ┌──────────────────────────────────────────────────────┐
 log di nginx ──┐                   │                      Loki :3100                      │
 journal ───────┼──> Alloy ──push──>│  distributor → ingester → compactor → storage        │
 container ─────┘                   │                         (filesystem / S3 / GCS)      │
                                    │  querier ← query-frontend ← Grafana / logcli         │
                                    └──────────────────────────────────────────────────────┘
```

- **Grafana Alloy**: agente che legge file, journal e log dei container, aggiunge etichette, manda a Loki
- **Loki**: riceve, indicizza le etichette, comprime il testo, lo salva; risponde alle query in **LogQL**
- **Grafana** o **logcli**: interrogano Loki

A differenza di Prometheus (che fa *pull*), il flusso dei log è **push**: è l'agente che manda.

## Installazione

### Binario e unit systemd (Ubuntu/Debian)
```bash
V=3.7.8
curl -fsSLO https://github.com/grafana/loki/releases/download/v$V/loki-linux-amd64.zip
unzip loki-linux-amd64.zip && sudo install -m 755 loki-linux-amd64 /usr/local/bin/loki
sudo useradd --system --no-create-home --shell /usr/sbin/nologin loki
sudo install -d -o loki -g loki /etc/loki /var/lib/loki
sudo cp loki.yml /etc/loki/                          # la configurazione, vedi sotto
```
`/etc/systemd/system/loki.service`:
```ini
[Unit]
Description=Grafana Loki
After=network-online.target

[Service]
User=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now loki
curl -s localhost:3100/ready                         # ready
```

### Docker
```bash
docker run -d --name loki -p 3100:3100 \
    -v ./loki.yml:/etc/loki/loki.yml:ro \
    -v loki:/loki \
    grafana/loki:3.7.8 -config.file=/etc/loki/loki.yml
```

## loki.yml

Quello del laboratorio, commentato: [lab/config/loki/loki.yml](lab/config/loki/loki.yml).
```yaml
auth_enabled: false                                  # in produzione multi-tenant si abilita

server:
  http_listen_port: 3100
  log_level: warn

common:
  path_prefix: /loki
  replication_factor: 1                              # singola istanza, in produzione ≥ 3
  ring:
    kvstore:
      store: inmemory                                # in cluster: consul o memberlist

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb                                    # database per gli indici
      object_store: filesystem                       # dove stanno i dati (o s3, gcs)
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /loki/chunks                          # in produzione: un bucket S3 o GCS

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true                            # senza, i log restano per sempre
  retention_delete_delay: 2h

limits_config:
  retention_period: 48h                              # nel laboratorio, come Prometheus (2d)
  ingestion_rate_mb: 10                              # MB/s per tenant
  ingestion_burst_size_mb: 20
```

### Opzioni da riga di comando
| Opzione | A cosa serve |
|---|---|
| `-config.file` | percorso del file di configurazione |
| `-log.level` | `debug`, `info`, `warn`, `error` |
| `-target` | componente da avviare: `all` (default), `read`, `write`, `backend` (per la modalità microservizi) |

Spazio su disco: Loki comprime bene (5-10× rispetto al testo originale). 1 GB di log al giorno ≈ 100-200 MB
su disco, più gli indici.

## Grafana Alloy: raccogliere i log

Alloy è l'agente di Grafana che legge file di log e journal di systemd, li etichetta e li manda a Loki. Lo stesso
binario raccoglie anche metriche e tracce OpenTelemetry: qui si usa solo per i log. Ha preso il posto di
**Promtail**, a fine vita dal 2 marzo 2026 (vedi [Da Promtail ad Alloy](#da-promtail-ad-alloy)).
Versione del laboratorio: 1.20. Documentazione: https://grafana.com/docs/alloy/latest/

### Installazione (Ubuntu/Debian)
```bash
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install alloy
sudo usermod -aG systemd-journal alloy               # per leggere il journal (nel gruppo adm c'è già: /var/log/*)
sudo systemctl enable --now alloy
```
Il pacchetto crea l'utente `alloy`, la unit systemd e due file:

| File | Contenuto |
|---|---|
| `/etc/alloy/config.alloy` | la configurazione (all'inizio un esempio) |
| `/etc/default/alloy` | opzioni di avvio: `CONFIG_FILE`, e in `CUSTOM_ARGS` gli argomenti in più, es. `--server.http.listen-addr=0.0.0.0:12345` |

```bash
alloy --version                                      # alloy, version v1.20.1
alloy fmt /etc/alloy/config.alloy                    # controlla la sintassi e stampa il file formattato
sudo systemctl reload alloy                          # rilegge la configurazione senza perdere la posizione nei file
curl -s localhost:12345/-/ready                      # Alloy is ready.
```

In Docker:
```bash
docker run -d --name alloy -p 12345:12345 \
    -v ./config.alloy:/etc/alloy/config.alloy:ro \
    -v /var/log:/var/log:ro \
    grafana/alloy:v1.20.1 run --server.http.listen-addr=0.0.0.0:12345 \
    --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy
```

### config.alloy
La sintassi non è YAML: è fatta di **componenti** `tipo "nome" { argomenti }`, collegati fra loro con
`forward_to`. Ogni componente espone dei valori (`loki.write.default.receiver`, `discovery.relabel.journal.rules`)
che gli altri usano come argomenti, e Alloy ricava da lì il grafo. Commenti con `//`; stringhe fra `"..."` o fra
backtick, senza escape: comodo per le regex.

Quella del laboratorio, commentata: [lab/config/alloy/config.alloy](lab/config/alloy/config.alloy).
```
 loki.source.journal "journal" ──────────────────────────────────────┐
 loki.source.file "nginx_access" ──> loki.process "nginx_access" ────┼──> loki.write "default" ──> Loki
 loki.source.file "nginx_error"  ──> loki.process "nginx_error"  ────┘
```
```hcl
// journal di systemd: tutti i servizi della macchina
discovery.relabel "journal" {                        // regole: dalle etichette interne del journal a etichette vere
	targets = []
	rule {
		source_labels = ["__journal__systemd_unit"]
		target_label  = "unit"                          // ssh.service, cron.service, ...
	}
	rule {
		source_labels = ["__journal_priority_keyword"]
		target_label  = "priority"                      // err, warning, info, ...
	}
}

loki.source.journal "journal" {
	path          = "/var/log/journal"                 // il default è /run/log/journal (solo volatile)
	relabel_rules = discovery.relabel.journal.rules
	labels        = {job = "journal", host = "server"}
	forward_to    = [loki.write.default.receiver]
}

// access log di nginx: le righe passano da loki.process prima di arrivare a Loki
loki.source.file "nginx_access" {
	targets = [{
		__path__ = "/var/log/nginx/access.log",        // il file da leggere
		job      = "nginx",
		host     = "server",
		tipo     = "access",
	}]
	forward_to = [loki.process.nginx_access.receiver]
}

loki.process "nginx_access" {
	stage.regex {                                      // vedi la tabella degli stage
		expression = `^(?P<ip>\S+) - \S+ \[(?P<ts>[^\]]+)\] "(?P<metodo>\S+) (?P<percorso>\S+) \S+" (?P<stato>\d{3}) (?P<bytes>\d+)`
	}
	stage.labels {
		values = {metodo = "", stato = ""}              // diventano etichette, indicizzate
	}
	stage.timestamp {
		source = "ts"
		format = "02/Jan/2006:15:04:05 -0700"          // formato Go: il reference time è Mon Jan 2 15:04:05 MST 2006
	}
	forward_to = [loki.write.default.receiver]
}

loki.write "default" {                               // dove mandare i log
	endpoint {
		url = "http://loki:3100/loki/api/v1/push"
	}
}
```
La posizione di lettura di ogni file Alloy la tiene in `--storage.path` (col pacchetto `/var/lib/alloy/data`):
dopo un riavvio riparte da lì, senza rimandare righe già inviate né perderne.

### Componenti per i log
| Componente | Cosa fa |
|---|---|
| `loki.source.file` | legge file di log, come `tail -F`: segue rotazioni e troncamenti |
| `loki.source.journal` | legge il journal di systemd |
| `loki.source.docker` | legge i log dei container dal demone Docker (con `discovery.docker`) |
| `loki.source.kubernetes` | legge i log dei Pod dall'API di Kubernetes (con `discovery.kubernetes`) |
| `loki.source.syslog` | riceve syslog via TCP/UDP da router, firewall, rsyslog |
| `local.file_match` | trova i file con un glob (`/var/log/nginx/*.log`) e produce i target per `loki.source.file` |
| `discovery.relabel` | regole di relabeling, come quelle di Prometheus |
| `loki.process` | trasforma ogni riga con una sequenza di `stage.*` |
| `loki.write` | manda a Loki; più `endpoint` = più destinazioni |

### Stage di loki.process
Gli stage trasformano ogni riga di log prima di mandarla a Loki, nell'ordine in cui sono scritti. I più usati:

| Stage | Cosa fa | Esempio |
|---|---|---|
| `stage.regex` | estrae campi con una regex (gruppi con nome) | `(?P<stato>\d{3})` |
| `stage.json` | estrae campi da una riga JSON | `expressions = {livello = "level"}` |
| `stage.logfmt` | estrae campi da una riga `key=value` | `mapping = {livello = "level"}` |
| `stage.labels` | promuove un campo estratto a etichetta Loki | `values = {stato = ""}` (`""`: stesso nome) |
| `stage.timestamp` | usa un campo estratto come orario della riga | `format = "RFC3339"` |
| `stage.output` | usa un campo estratto come testo della riga | `source = "messaggio"` |
| `stage.drop` | scarta la riga se corrisponde | `expression = ".*healthcheck.*"` |
| `stage.replace` | sostituisce testo nella riga | `password=(\S+)` → `replace = "***"` |
| `stage.template` | genera un campo con Go template | `template = "{{ ToUpper .Value }}"` |

Attenzione alla **cardinalità**: le etichette prodotte dalla pipeline devono avere pochi valori
(metodo HTTP: 5-6; status code: una dozzina). Mai `ip`, `url` con parametri, `user_id` come etichetta:
si usa il filtro nel testo della riga (`|= "192.168.1.100"`).

```hcl
loki.process "app" {
	stage.json {                                       // riga JSON: {"level":"error","msg":"disco pieno","ts":"..."}
		expressions = {livello = "level", messaggio = "msg"}
	}
	stage.labels {
		values = {livello = ""}
	}
	stage.output {
		source = "messaggio"                            // in Loki finisce solo "disco pieno", non il JSON intero
	}
	stage.drop {
		source = "livello"
		value  = "debug"                                // scarta le righe di debug
	}
	stage.replace {
		expression = `password=(\S+)`                   // il gruppo catturato viene sostituito
		replace    = "***"
	}
	forward_to = [loki.write.default.receiver]
}
```
Con tre righe nel file (`error` "disco pieno", `debug` "dettaglio inutile", `info` "backup ok password=segreta"),
in Loki arrivano:
```
$ logcli query '{job="app"}'
2026-10-03T14:29:27Z {livello="info"}  backup ok password=***
2026-10-03T14:29:27Z {livello="error"} disco pieno
```
L'orario è quello di lettura: per usare il `ts` della riga serve anche uno `stage.timestamp`.

### Interfaccia web
Su `--server.http.listen-addr` (di default `127.0.0.1:12345`; nel laboratorio http://localhost:12345) Alloy mostra
il grafo dei componenti, lo stato di ognuno (*healthy*, oppure *unhealthy* con il messaggio d'errore) e gli
argomenti effettivi. È il primo posto dove guardare quando i log non arrivano. Lo stesso dall'API:
```bash
curl -s localhost:12345/api/v0/web/components | jq -r '.[] | "\(.localID) \(.health.state)"'
```
```
loki.write.default healthy
loki.process.nginx_access healthy
loki.source.file.nginx_access healthy
loki.process.nginx_error healthy
loki.source.file.nginx_error healthy
discovery.relabel.journal healthy
loki.source.journal.journal healthy
```

### Da Promtail ad Alloy
Promtail, l'agente storico di Loki, è a fine vita dal **2 marzo 2026**: niente più aggiornamenti né correzioni
di sicurezza (l'ultima immagine è `grafana/promtail:3.6.11`). Si trova ancora su molti server, con una
configurazione YAML come questa:
```yaml
# /etc/promtail/promtail.yml
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml                      # dove è arrivata la lettura di ogni file
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs:
  - job_name: nginx-access
    static_configs:
      - targets: [localhost]
        labels:
          job: nginx
          host: server
          tipo: access
          __path__: /var/log/nginx/access.log
    pipeline_stages:                                 # gli stessi stage di Alloy, senza il prefisso stage.
      - regex:
          expression: '^(?P<ip>\S+) - \S+ \[(?P<ts>[^\]]+)\] "(?P<metodo>\S+) (?P<percorso>\S+)'
      - labels:
          metodo:
```
Alloy la converte da solo:
```bash
alloy convert --source-format=promtail --output=config.alloy promtail.yml
```
Con il file Promtail che usava prima questo laboratorio, l'uscita è (estratto):
```hcl
loki.source.file "nginx_access" {
	targets = [{
		__address__ = "localhost",
		__path__    = "/var/log/nginx/access.log",
		host        = "server",
		job         = "nginx",
		tipo        = "access",
	}]
	forward_to = [loki.process.nginx_access.receiver]

	file_match {
		enabled = true
	}
	legacy_positions_file = "/tmp/positions.yaml"
}
```
- ogni `job_name` diventa una coppia `loki.source.*` + `loki.process`; i `clients` diventano `loki.write`
- `legacy_positions_file` legge le posizioni di Promtail: al primo avvio Alloy riparte dal punto in cui Promtail
  si era fermato, senza rimandare tutto il file a Loki. Dopo la migrazione si può togliere
- `--source-format` accetta anche `prometheus`, `static` (Grafana Agent) e `otelcol`; con `--report=report.txt`
  scrive cosa non è riuscito a convertire

Cambia solo l'agente. Loki, etichette, query LogQL e dashboard restano uguali.

## LogQL: il linguaggio di query

Come PromQL è per le metriche, LogQL è per i log. Due tipi di query:
- **log query**: restituiscono righe di log
- **metric query**: restituiscono numeri calcolati sui log (per grafici e alert)

### Log query

Una query parte sempre da un **selettore di stream** (le etichette, come in PromQL):
```logql
{job="nginx"}                                        # tutti i log con job=nginx
{job="nginx", host="server"}                         # con due etichette
{job=~"nginx|journal"}                               # regex: nginx o journal
{job="nginx", tipo!="error"}                         # esclusione
```

Dopo il selettore, i **filtri di riga** (`|` pipe, come in bash):
```logql
{job="nginx"} |= "404"                              # righe che contengono "404"
{job="nginx"} != "healthcheck"                       # righe che NON contengono "healthcheck"
{job="nginx"} |~ "5\\d{2}"                           # regex: status 5xx
{job="nginx"} !~ "\\.(css|js|png)"                   # esclude richieste di file statici
```

I **parser** estraggono campi dalla riga, usabili come etichette nei filtri successivi:
```logql
{job="nginx"} | pattern `<ip> - - [<_>] "<metodo> <percorso> <_>" <stato> <bytes>`
{job="nginx"} | pattern `<_> <stato> <_>` | stato >= 500                  # solo errori 5xx
{job="app"}   | json                                 # riga JSON: ogni campo diventa etichetta
{job="app"}   | json | livello="error"               # filtra sul campo estratto
{job="app"}   | logfmt                               # riga key=value: level=error msg="disco pieno"
{job="app"}   | logfmt | level="error"
```

**Label filter**: dopo un parser, si filtra sui campi estratti con `=`, `!=`, `=~`, `!~`, `>`, `>=`, `<`, `<=`:
```logql
{job="nginx"} | pattern `<_> "<_> <_> <_>" <stato> <bytes>` | bytes > 10000   # risposte > 10 KB
```

**Line format**: riscrive la riga mostrata (Go template):
```logql
{job="nginx"} | pattern `<ip> - - [<ts>] "<metodo> <percorso> <_>" <stato> <bytes>`
              | line_format "{{.stato}} {{.metodo}} {{.percorso}}"
```

### Metric query

Calcolano un numero a partire dai log — servono per grafici e alert:
```logql
count_over_time({job="nginx"} |= "404" [5m])                     # righe 404 negli ultimi 5 min
rate({job="nginx"} [1m])                                          # righe al secondo
rate({job="nginx"} |= "500" [5m])                                 # errori 500 al secondo
sum by (stato) (count_over_time({job="nginx"} | pattern `<_> "<_> <_> <_>" <stato> <_>` [5m]))
bytes_over_time({job="nginx"} [1h])                               # byte di log nell'ultima ora
bytes_rate({job="nginx"} [5m])                                    # byte di log al secondo
```
Si usano in Grafana per i pannelli *Time series* e nelle regole di alert.

### LogQL e grep a confronto

| Con grep | Con LogQL |
|---|---|
| `grep "404" /var/log/nginx/access.log` | `{job="nginx"} \|= "404"` |
| `grep -c "500" access.log` | `count_over_time({job="nginx"} \|= "500" [24h])` |
| `grep -v healthcheck access.log` | `{job="nginx"} != "healthcheck"` |
| `grep -E "5[0-9]{2}" access.log` | `{job="nginx"} \|~ "5\\d{2}"` |
| `tail -f /var/log/syslog` | `{job="journal"} ` (in Grafana con Live tail) |

La differenza: grep lavora su un file di una macchina, LogQL interroga tutti i log di tutte le macchine
che mandano a Loki, con le stesse etichette.

## logcli: query dal terminale

Un client da riga di comando per Loki, come `promtool query` per Prometheus.
```bash
V=3.7.8
curl -fsSLO https://github.com/grafana/loki/releases/download/v$V/logcli-linux-amd64.zip
unzip logcli-linux-amd64.zip && sudo install -m 755 logcli-linux-amd64 /usr/local/bin/logcli
export LOKI_ADDR=http://localhost:3100               # nel lab è già impostato
```
```bash
logcli query '{job="nginx"}'                         # ultimi log nginx
logcli query '{job="nginx"} |= "404"' --limit 50    # con filtro e limite
logcli query '{job="nginx"}' --since 1h              # ultima ora
logcli query '{job="nginx"}' --from "2026-10-01T00:00:00Z" --to "2026-10-01T06:00:00Z"
logcli query '{job="journal", unit="ssh.service"}'                       # i log di sshd dal journal
logcli query '{job="journal", unit="init.scope"} |= "nginx.service"'     # avvii e arresti di nginx: li scrive systemd
logcli query '{job="nginx"}' --tail                  # come tail -f: le righe arrivano in tempo reale
logcli labels                                        # tutte le etichette
logcli labels job                                    # i valori dell'etichetta "job"
logcli series '{job="nginx"}'                        # gli stream (combinazioni di etichette)
logcli instant-query 'count_over_time({job="nginx"} |= "500" [1h])'     # una metric query
```
Opzioni utili: `--quiet` (niente timestamp e etichette, solo il testo), `--output jsonl` (una riga JSON per log),
`--forward` (ordine cronologico, default dal più recente).

Nel laboratorio c'è `./query.sh` che lo usa:
```bash
cd 07-loki
./query.sh '{job="nginx"}'
./query.sh '{job="nginx"} |= "404"' --limit 50
./query.sh '{job="journal", unit="sshd.service"}'
```

## Grafana + Loki

### Data source
*Connections > Data sources > Add data source > Loki*, URL `http://loki:3100`, *Save & test*.
Nel laboratorio è già configurata dal provisioning ([lab/config/grafana/provisioning/datasources/loki.yml](lab/config/grafana/provisioning/datasources/loki.yml)).

### Explore
La bussola: scegli Loki come data source, scrivi una query LogQL, i log appaiono in basso con le etichette
a colori. Cliccando su un'etichetta si aggiunge al filtro; cliccando su una riga si espandono i campi estratti.
*Live tail* (il bottone in alto a destra) è `tail -f` su tutti i log.

### Dashboard
Il pannello *Logs* mostra le righe di log: quello nella dashboard *Server* del laboratorio filtra per
`{job="nginx", host=~"$host"}`. Per una *Time series* su dati Loki si usa una metric query:
`rate({job="nginx"} |= "500" [$__auto])`.

### Correlazione metriche ↔ log
In un grafico Prometheus si seleziona un intervallo di tempo e si apre la vista *Split* con Loki:
si vedono metriche e log dello stesso momento fianco a fianco. Nella data source Loki si possono configurare
*Derived fields* per creare link tra un campo del log (un trace ID, un request ID) e un'altra data source.

## API HTTP

Tutto quello che fa Grafana si fa con curl. Risposte in JSON.
```bash
L=http://loki:3100

# query (come logcli ma via HTTP)
curl -sG $L/loki/api/v1/query_range \
    --data-urlencode 'query={job="nginx"}' \
    -d limit=10 -d direction=backward | jq '.data.result[].values[][1]'

# etichette e valori
curl -s $L/loki/api/v1/labels | jq                  # tutte le etichette
curl -s $L/loki/api/v1/label/job/values | jq         # i valori di "job"

# serie (stream)
curl -sG $L/loki/api/v1/series --data-urlencode 'match={job="nginx"}' | jq

# push: mandare un log senza agente (utile per test e script)
curl -X POST $L/loki/api/v1/push -H 'Content-Type: application/json' \
    -d '{"streams":[{"stream":{"job":"test","host":"server"},"values":[["'"$(date +%s)"'000000000","messaggio di prova"]]}]}'

# pronto?
curl -s $L/ready                                     # ready
curl -s $L/metrics                                   # metriche di Loki stesso (in formato Prometheus)
```

Nel laboratorio c'è `./push.sh` che manda una riga di log:
```bash
cd 07-loki
./push.sh "il server si è riavviato"
./query.sh '{job="test"}'                            # la riga appena mandata
```

## Alert sui log

Loki ha un **ruler** integrato che valuta regole LogQL a intervalli regolari — stessa sintassi delle regole
di alert di Prometheus:
```yaml
# /etc/loki/rules/lab/regole.yml
groups:
  - name: log
    rules:
      - alert: TroppiErroriNginx
        expr: sum(rate({job="nginx"} |= "\" 5" [5m])) > 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "più di 1 errore 5xx al secondo negli ultimi 5 minuti"
```
Le regole del ruler di Loki mandano gli alert allo stesso Alertmanager usato da Prometheus. Per abilitare
il ruler nella configurazione di Loki:
```yaml
ruler:
  storage:
    type: local
    local:
      directory: /etc/loki/rules
  alertmanager_url: http://alertmanager:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
```

Alternativa: le regole di alert di Grafana con data source Loki (*Alerting > Alert rules*), utili quando
non si vuole toccare la configurazione di Loki.

## Retention e storage

### Filesystem (laboratorio, server singolo)
```yaml
storage_config:
  filesystem:
    directory: /loki/chunks
```
Va bene per un server singolo, sviluppo e laboratori. I dati stanno su disco locale; se il disco si rompe
si perdono.

### Object storage (produzione)
In produzione si usa un bucket S3, GCS o MinIO: i dati sono replicati, durevoli, e Loki può scalare in
più istanze senza condividere un disco.
```yaml
storage_config:
  aws:
    bucketnames: loki-lab
    endpoint: s3.eu-west-1.amazonaws.com
    region: eu-west-1
    access_key_id: ${AWS_ACCESS_KEY_ID}
    secret_access_key: ${AWS_SECRET_ACCESS_KEY}
    s3forcepathstyle: false
```

### Retention
Senza retention abilitata, i log restano per sempre. Con il compactor:
```yaml
compactor:
  retention_enabled: true
  retention_delete_delay: 2h                         # aspetta 2 ore prima di cancellare davvero
limits_config:
  retention_period: 720h                             # 30 giorni
```
Si può avere retention diversa per stream con `retention_stream`:
```yaml
limits_config:
  retention_period: 720h
  retention_stream:
    - selector: '{job="debug"}'
      priority: 1
      period: 24h                                    # i log di debug solo 1 giorno
    - selector: '{job="audit"}'
      priority: 2
      period: 8760h                                  # i log di audit 1 anno
```

## Confronto Loki ed Elasticsearch (ELK)

| | Loki | Elasticsearch (ELK) |
|---|---|---|
| **indicizzazione** | solo etichette | full-text su tutto il contenuto |
| **risorse** | poche: 1-2 GB di RAM bastano | tante: cluster con decine di GB di RAM |
| **query** | LogQL, simile a PromQL | Lucene / KQL / DSL |
| **ricerca nel testo** | filtri sequenziali (`\|= "errore"`) | indice invertito, molto veloce |
| **integrazione Grafana** | nativa (stesso produttore) | plugin, funziona bene |
| **costo storage** | basso (compressione, solo etichette indicizzate) | alto (indice invertito grande) |
| **quando scegliere** | piccoli-medi volumi, già si usa Grafana/Prometheus | grandi volumi, ricerca full-text critica, team dedicato |

## Altri strumenti che si incontrano

| | Cosa è |
|---|---|
| Promtail | il vecchio agente di Loki, a fine vita da marzo 2026: si migra ad Alloy con `alloy convert` |
| Fluentd / Fluent Bit | collector di log molto diffusi; Fluent Bit è più leggero, può mandare a Loki |
| Vector | collector ad alte prestazioni (Rust), alternativa a Fluent Bit |
| Elasticsearch + Kibana (ELK) | ricerca full-text, dashboard Kibana; più pesante, più potente su grandi volumi |
| OpenSearch | fork open source di Elasticsearch |
| Graylog | gestione log con interfaccia web, GELF, alert, basato su MongoDB + OpenSearch |

Vedi anche: [01-concetti.md](01-concetti.md) per il confronto metriche / log / tracce, [06-grafana.md](06-grafana.md) per le dashboard.
