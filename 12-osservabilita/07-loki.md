# Loki: log centralizzati

> **Laboratorio**: `./lab.sh 12`, poi `cd 07-loki`. Cosa contiene: [lab/](lab/).

Loki raccoglie log da più macchine e li rende interrogabili da un punto solo — Grafana o il terminale.
Stessa logica di Prometheus per le metriche, ma applicata ai log: indicizza solo le **etichette** (job, host,
filename), non il testo delle righe. Questo lo rende molto più leggero di Elasticsearch/ELK, ma meno potente
per la ricerca full-text su volumi enormi.
Porta **3100**. Versione del laboratorio: 3.5 (2026). Documentazione: https://grafana.com/docs/loki/latest/

## Architettura

```
 server ──nginx log──┐      ┌──────────────────────────────────────────────────────┐
 server ──journal────┤      │                      Loki :3100                      │
                  Promtail   │  distributor → ingester → compactor → storage        │
 altro  ──Alloy──────┤      │                         (filesystem / S3 / GCS)      │
                     └push──┤  querier ← query-frontend ← Grafana / logcli        │
                            └──────────────────────────────────────────────────────┘
```

- **Promtail** (o Grafana Alloy): agente che legge file e journal, aggiunge etichette, manda a Loki
- **Loki**: riceve, indicizza le etichette, comprime il testo, lo salva; risponde alle query in **LogQL**
- **Grafana** o **logcli**: interrogano Loki

A differenza di Prometheus (che fa *pull*), il flusso dei log è **push**: è l'agente che manda.

## Installazione

### Binario e unit systemd (Ubuntu/Debian)
```bash
V=3.5.0
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
    grafana/loki:3.5.0 -config.file=/etc/loki/loki.yml
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

## Promtail: raccogliere i log

Promtail è l'agente ufficiale che legge file di log e journal di systemd e li manda a Loki. È un singolo binario.

### Installazione
```bash
V=3.5.0
curl -fsSLO https://github.com/grafana/loki/releases/download/v$V/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip && sudo install -m 755 promtail-linux-amd64 /usr/local/bin/promtail
```
`/etc/systemd/system/promtail.service`:
```ini
[Unit]
Description=Promtail
After=network-online.target

[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### promtail.yml
Quello del laboratorio, commentato: [lab/config/promtail/promtail.yml](lab/config/promtail/promtail.yml).
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml                      # dove è arrivata la lettura di ogni file

clients:
  - url: http://loki:3100/loki/api/v1/push          # dove mandare i log

scrape_configs:
  # journal di systemd: tutti i servizi della macchina
  - job_name: journal
    journal:
      path: /var/log/journal                         # il default è /run/log/journal (solo volatile)
      labels:
        job: journal
        host: server
    relabel_configs:                                 # etichette dal journal: la unit e la priorità
      - source_labels: [__journal__systemd_unit]
        target_label: unit
      - source_labels: [__journal_priority_keyword]
        target_label: priority

  # access log di nginx
  - job_name: nginx-access
    static_configs:
      - targets: [localhost]
        labels:
          job: nginx
          host: server
          tipo: access
          __path__: /var/log/nginx/access.log        # il file da leggere
    pipeline_stages:                                 # vedi sotto
      - regex:
          expression: '^(?P<ip>\S+) - \S+ \[(?P<ts>[^\]]+)\] "(?P<metodo>\S+) (?P<percorso>\S+) \S+" (?P<stato>\d{3}) (?P<bytes>\d+)'
      - labels:
          metodo:                                    # diventa etichetta, indicizzata
          stato:
      - timestamp:
          source: ts
          format: "02/Jan/2006:15:04:05 -0700"       # formato Go: il reference time è Mon Jan 2 15:04:05 MST 2006
```

### Pipeline stages
Le pipeline trasformano ogni riga di log prima di mandarla a Loki. Le più usate:

| Stage | Cosa fa | Esempio |
|---|---|---|
| `regex` | estrae campi con una regex (gruppi con nome) | `(?P<stato>\d{3})` |
| `json` | estrae campi da una riga JSON | `{campo: "livello"}` |
| `logfmt` | estrae campi da una riga `key=value` | nessuna configurazione |
| `labels` | promuove un campo estratto a etichetta Loki | `stato:` |
| `timestamp` | usa un campo estratto come orario della riga | `format: "2006-01-02T15:04:05Z"` |
| `output` | usa un campo estratto come testo della riga | `source: messaggio` |
| `drop` | scarta la riga se un campo corrisponde | `expression: "healthcheck"` |
| `replace` | sostituisce testo nella riga | `expression: "password=.*"` |
| `template` | genera un campo con Go template | `template: '{{ ToUpper .livello }}'` |

Attenzione alla **cardinalità**: le etichette prodotte dalla pipeline devono avere pochi valori
(metodo HTTP: 5-6; status code: una dozzina). Mai `ip`, `url` con parametri, `user_id` come etichetta:
si usa il filtro nel testo della riga (`|= "192.168.1.100"`).

```yaml
    pipeline_stages:
      - json:                                        # riga JSON: {"level":"error","msg":"disco pieno","ts":"..."}
          expressions:
            livello: level
            messaggio: msg
      - labels:
          livello:
      - output:
          source: messaggio                          # in Loki finisce solo "disco pieno", non il JSON intero
      - drop:
          source: livello
          value: debug                               # scarta le righe di debug
```

## Grafana Alloy

Grafana Alloy è il successore ufficiale di Promtail (e di Grafana Agent). Un agente unico per metriche,
log e tracce; la sintassi è in stile HCL (blocchi con argomenti), non YAML. Nel laboratorio si usa Promtail
perché la configurazione YAML è più semplice da leggere per chi inizia.

```hcl
// esempio Alloy equivalente al Promtail sopra
local.file_match "nginx" {
  path_targets = [{"__path__" = "/var/log/nginx/access.log", "job" = "nginx", "host" = "server"}]
}
loki.source.file "nginx" {
  targets    = local.file_match.nginx.targets
  forward_to = [loki.write.default.receiver]
}
loki.write "default" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}
```

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
V=3.5.0
curl -fsSLO https://github.com/grafana/loki/releases/download/v$V/logcli-linux-amd64.zip
unzip logcli-linux-amd64.zip && sudo install -m 755 logcli-linux-amd64 /usr/local/bin/logcli
export LOKI_ADDR=http://localhost:3100               # nel lab è già impostato
```
```bash
logcli query '{job="nginx"}'                         # ultimi log nginx
logcli query '{job="nginx"} |= "404"' --limit 50    # con filtro e limite
logcli query '{job="nginx"}' --since 1h              # ultima ora
logcli query '{job="nginx"}' --from "2026-10-01T00:00:00Z" --to "2026-10-01T06:00:00Z"
logcli query '{job="journal", unit="nginx.service"}'                     # solo log di nginx da journal
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

# push: mandare un log senza Promtail (utile per test e script)
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
| Grafana Alloy | agente unico per metriche, log, tracce (sostituisce Promtail e Grafana Agent) |
| Fluentd / Fluent Bit | collector di log molto diffusi; Fluent Bit è più leggero, può mandare a Loki |
| Vector | collector ad alte prestazioni (Rust), alternativa a Fluent Bit |
| Elasticsearch + Kibana (ELK) | ricerca full-text, dashboard Kibana; più pesante, più potente su grandi volumi |
| OpenSearch | fork open source di Elasticsearch |
| Graylog | gestione log con interfaccia web, GELF, alert, basato su MongoDB + OpenSearch |

Vedi anche: [01-concetti.md](01-concetti.md) per il confronto metriche / log / tracce, [06-grafana.md](06-grafana.md) per le dashboard.
