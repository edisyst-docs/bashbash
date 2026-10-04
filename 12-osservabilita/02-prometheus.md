# Prometheus

> **Laboratorio**: `./lab.sh 12`, poi `cd 02-prometheus`. Cosa contiene: [lab/](lab/).

Un solo binario scritto in Go: raccoglie le metriche, le salva sul suo disco, risponde alle query e valuta le regole.
Interfaccia web e API sulla porta **9090**. Versione del laboratorio: 3.15 (settembre 2026).
Documentazione: https://prometheus.io/docs/

## Installazione

### Binario e unit systemd (Ubuntu/Debian)
Il pacchetto `prometheus` di apt esiste, ma è indietro di molte versioni: sui server si usa il binario ufficiale.
```bash
V=3.15.0
curl -fsSLO https://github.com/prometheus/prometheus/releases/download/v$V/prometheus-$V.linux-amd64.tar.gz
tar xzf prometheus-$V.linux-amd64.tar.gz
sudo install -m 755 prometheus-$V.linux-amd64/{prometheus,promtool} /usr/local/bin/
sudo useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
sudo install -d -o prometheus -g prometheus /etc/prometheus /var/lib/prometheus
sudo cp prometheus.yml /etc/prometheus/        # la configurazione, vedi sotto
```
`/etc/systemd/system/prometheus.service`:
```ini
[Unit]
Description=Prometheus
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --storage.tsdb.retention.time=30d \
    --web.enable-lifecycle
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
curl -s localhost:9090/-/ready                 # Prometheus Server is Ready.
```

### Docker
```bash
docker run -d --name prometheus -p 9090:9090 \
    -v ./prometheus.yml:/etc/prometheus/prometheus.yml:ro \
    -v prometheus:/prometheus \
    prom/prometheus:v3.15.0
```
Nel container gira come utente `nobody` (65534): i file montati devono essere leggibili da tutti. Con compose: vedi
[lab/compose.yaml](lab/compose.yaml).

### Opzioni da riga di comando che contano
| Opzione | Default | A cosa serve |
|---|---|---|
| `--config.file` | `prometheus.yml` | la configurazione |
| `--storage.tsdb.path` | `data/` | dove stanno i dati |
| `--storage.tsdb.retention.time` | `15d` | quanto tenere i dati |
| `--storage.tsdb.retention.size` | nessuno | tetto in spazio (`50GB`): si cancellano i blocchi più vecchi |
| `--web.enable-lifecycle` | spento | abilita `POST /-/reload` e `/-/quit` |
| `--web.enable-admin-api` | spento | snapshot e cancellazione di serie |
| `--web.external-url` | | l'URL pubblico, se sta dietro un reverse proxy con un percorso (`/prometheus`) |
| `--web.listen-address` | `:9090` | indirizzo e porta |

Spazio su disco, a occhio: 1-2 byte per campione. 1000 serie ogni 15 s per 30 giorni ≈ 170 milioni di campioni ≈ 300 MB.

## prometheus.yml
Quello del laboratorio, commentato: [lab/config/prometheus/prometheus.yml](lab/config/prometheus/prometheus.yml).
```yaml
global:
  scrape_interval: 15s                    # ogni quanto si leggono i bersagli
  evaluation_interval: 15s                # ogni quanto si calcolano le regole
  scrape_timeout: 10s
  external_labels:                        # aggiunte a ciò che esce verso Alertmanager, remote_write, federazione
    datacenter: milano

rule_files:
  - regole/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: [localhost:9093]

scrape_configs:
  - job_name: node                        # diventa l'etichetta job="node"
    static_configs:
      - targets: [web1:9100, web2:9100]   # diventano instance="web1:9100" ...
        labels:
          ruolo: web                      # etichette in più per tutte le serie di questi bersagli
      - targets: [db1:9100]
        labels:
          ruolo: database

  - job_name: app
    metrics_path: /internal/metrics       # default /metrics
    scheme: https
    scrape_interval: 30s                  # sovrascrive quello globale
    basic_auth:
      username: prometheus
      password_file: /etc/prometheus/app.pass
    static_configs:
      - targets: [app.example.com:443]
```
Prometheus aggiunge a ogni serie `job` e `instance`, e per ogni bersaglio crea serie sue: `up` (1 se lo scrape è
riuscito), `scrape_duration_seconds`, `scrape_samples_scraped`.

### Ricaricare la configurazione
```bash
promtool check config /etc/prometheus/prometheus.yml   # controlla anche i file delle regole
curl -X POST http://localhost:9090/-/reload            # con --web.enable-lifecycle
sudo systemctl reload prometheus                       # UGUALE: manda SIGHUP (ExecReload)
```
Se la nuova configurazione ha un errore, Prometheus tiene la vecchia e lo scrive nel log:
`prometheus_config_last_reload_successful` vale 0.

Nel laboratorio la configurazione sta in `/etc/monitoring` (link `config` nella cartella `02-prometheus`):
```bash
vim config/prometheus/prometheus.yml           # es. scrape_interval: 5s
promtool check config config/prometheus/prometheus.yml
curl -X POST http://prometheus:9090/-/reload
./api.sh prometheus_config_last_reload_successful
```

## Service discovery: bersagli che cambiano
Elencare i server a mano va bene finché sono pochi e fissi. Altrimenti Prometheus li scopre:
```yaml
scrape_configs:
  # file: un JSON o YAML che scrive qualcun altro (Ansible, uno script, il CMDB). Riletto da solo quando cambia
  - job_name: node
    file_sd_configs:
      - files: [/etc/prometheus/bersagli/*.yml]

  # i container Docker della macchina, con le loro etichette
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_label_prometheus_scrape]
        regex: "true"
        action: keep                      # solo i container con l'etichetta prometheus.scrape=true

  # Kubernetes: pod, service, nodi (di solito lo configura l'operatore o il chart kube-prometheus-stack)
  - job_name: pod
    kubernetes_sd_configs:
      - role: pod
```
`/etc/prometheus/bersagli/web.yml`:
```yaml
- targets: [web1:9100, web2:9100, web3:9100]
  labels:
    ruolo: web
```
Esistono anche `ec2_sd_configs`, `azure_sd_configs`, `gce_sd_configs`, `consul_sd_configs`, `dns_sd_configs`
(record SRV), `http_sd_configs`.

## Relabeling
Regole che trasformano le etichette **prima** dello scrape (`relabel_configs`: decidono chi e come interrogare) o
**dopo** (`metric_relabel_configs`: scartano o rinominano serie). Le etichette che iniziano con `__` sono interne e
spariscono dopo il relabeling: `__address__` (dove collegarsi), `__metrics_path__`, `__scheme__`, `__param_<nome>`
(parametri della query string), `__meta_*` (quelle della service discovery).
```yaml
relabel_configs:
  - source_labels: [__address__]          # instance senza porta: "web1" invece di "web1:9100"
    regex: '([^:]+):\d+'
    target_label: instance
  - source_labels: [__meta_ec2_tag_Name]  # il tag Name dell'istanza EC2 come etichetta
    target_label: nome
  - source_labels: [__meta_ec2_tag_Env]
    regex: test
    action: drop                          # le macchine di test non si monitorano

metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'go_gc_.*|go_memstats_.*'
    action: drop                          # serie che non servono: meno disco e meno RAM
```
Azioni: `replace` (default), `keep`, `drop`, `labelmap`, `labeldrop`, `labelkeep`, `hashmod`, `lowercase`, `uppercase`.
Il relabeling più comune è quello del blackbox exporter ([03-exporter.md](03-exporter.md)), e nel laboratorio si vede
in *Status > Targets*: colonna *Labels* prima e dopo (passando il mouse).

## L'interfaccia web
http://localhost:9090
- **Query**: PromQL, risultato in tabella (*Table*) o grafico (*Graph*). Il pulsante con il globo (*Explore metrics*)
  elenca tutte le metriche
- **Alerts**: le regole di alert e il loro stato (inactive, pending, firing)
- **Status > Target health**: ogni bersaglio, se è su o giù, l'ultimo errore (`connection refused`, `context deadline
  exceeded`, `server returned HTTP status 401`)
- **Status > Configuration**, **Rules**, **Service discovery**, **TSDB status** (le metriche con più serie: dove guardare
  quando la RAM cresce)

## API HTTP
Tutto quello che fa l'interfaccia si fa con curl: script, controlli, report. Risposte in JSON.
```bash
P=http://localhost:9090
curl -s $P/api/v1/query --data-urlencode 'query=up' | jq '.data.result[] | {job: .metric.job, v: .value[1]}'
curl -s $P/api/v1/query_range --data-urlencode 'query=node_load1' \
     -d start=$(date -d '-1 hour' +%s) -d end=$(date +%s) -d step=60   # una serie di valori nel tempo
curl -s $P/api/v1/targets | jq -r '.data.activeTargets[] | "\(.health)\t\(.scrapeUrl)\t\(.lastError)"'
curl -s $P/api/v1/alerts | jq '.data.alerts[] | {nome: .labels.alertname, stato: .state}'
curl -s $P/api/v1/rules | jq -r '.data.groups[].rules[] | "\(.health)\t\(.name)"'
curl -s $P/api/v1/label/job/values | jq                # i valori di un'etichetta
curl -s $P/api/v1/series --data-urlencode 'match[]=up' | jq
curl -s $P/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[:10]'   # le 10 metriche con più serie
curl -s $P/-/healthy; curl -s $P/-/ready
```
Nel laboratorio `./api.sh 'QUERY'` fa la prima riga e stampa una serie per riga:
```bash
./api.sh up
./api.sh 'count by (job) (up)'
./api.sh 'nonesiste('                          # ERRORE: invalid parameter "query": 1:11: parse error: unclosed left parenthesis
```

## promtool
```bash
promtool check config prometheus.yml           # sintassi della configurazione e delle regole collegate
promtool check rules regole/*.yml              # solo le regole
promtool test rules test-regole.yml            # unit test delle regole: vedi 05-alerting.md
promtool query instant http://prometheus:9090 'up{job="node"}'
promtool query range --start=$(date -d -1hour +%s) --end=$(date +%s) --step=1m http://prometheus:9090 node_load1
curl -s server:9100/metrics | promtool check metrics   # problemi nei nomi delle metriche esposte
promtool tsdb analyze /var/lib/prometheus      # cardinalità sul disco (a Prometheus fermo, o su uno snapshot)
```

## Backup
Il database si copia in modo coerente solo con uno snapshot (serve `--web.enable-admin-api`):
```bash
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot   # {"data":{"name":"20261002T120000Z-6d7c..."}}
sudo tar czf prometheus-$(date +%F).tgz -C /var/lib/prometheus/snapshots .
```
Spesso non si fa backup delle metriche: si salvano configurazione e regole (in git) e si accetta di perdere lo storico.

## Più di un Prometheus
- **alta disponibilità**: due Prometheus identici che leggono gli stessi bersagli e mandano alert allo stesso
  Alertmanager (che toglie i doppioni). Nessuna replica dei dati fra loro
- **federazione**: un Prometheus centrale legge da altri `/federate?match[]=...`, di solito solo le recording rule
- **remote_write**: manda ogni campione a un archivio esterno (Thanos, Mimir, VictoriaMetrics, Grafana Cloud)
  ```yaml
  remote_write:
    - url: https://mimir.example.com/api/v1/push
      basic_auth: {username: prometheus, password_file: /etc/prometheus/mimir.pass}
  ```
- **agent mode** (`--agent`): Prometheus senza query né regole, solo raccolta e `remote_write`; poco disco e RAM
