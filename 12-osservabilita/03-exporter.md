# Exporter: da dove arrivano le metriche

> **Laboratorio**: `./lab.sh 12`, poi `cd 03-exporter`. Cosa contiene: [lab/](lab/).

Un exporter è un piccolo server HTTP che, a ogni richiesta di Prometheus, legge lo stato di qualcosa e lo restituisce
nel formato testo. Elenco ufficiale e di terze parti: https://prometheus.io/docs/instrumenting/exporters/

| Exporter | Porta | Cosa misura |
|---|---|---|
| node_exporter | 9100 | il sistema Linux: CPU, memoria, dischi, filesystem, rete, systemd, textfile |
| blackbox_exporter | 9115 | dall'esterno: HTTP, HTTPS e certificato, TCP, ICMP, DNS |
| nginx-prometheus-exporter | 9113 | nginx tramite `stub_status` |
| mysqld_exporter | 9104 | MySQL e MariaDB |
| postgres_exporter | 9187 | PostgreSQL |
| redis_exporter | 9121 | Redis |
| cAdvisor | 8080 | i container: CPU, memoria, rete per container |
| windows_exporter | 9182 | Windows |
| php-fpm_exporter | 9253 | i pool di PHP-FPM |

## node_exporter
```bash
V=1.12.1
curl -fsSL https://github.com/prometheus/node_exporter/releases/download/v$V/node_exporter-$V.linux-amd64.tar.gz | tar xz
sudo install -m 755 node_exporter-$V.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
sudo install -d -o node_exporter -g node_exporter -m 775 /var/lib/node_exporter/textfile
```
`/etc/systemd/system/node_exporter.service`:
```ini
[Unit]
Description=Prometheus node_exporter
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.textfile.directory=/var/lib/node_exporter/textfile
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload && sudo systemctl enable --now node_exporter
curl -s localhost:9100/metrics | grep -c '^node_'          # quante serie: un migliaio su un server normale
```
UGUALE con apt (versione più vecchia, configurazione in `/etc/default/prometheus-node-exporter`, textfile in
`/var/lib/prometheus/node-exporter`): `sudo apt install prometheus-node-exporter`. Nel laboratorio è installato
come sopra, vedi lo stadio `osservabilita` del [Dockerfile](../Dockerfile).

La porta 9100 non va lasciata aperta su internet (espone dettagli del sistema): firewall che la apre solo al server
Prometheus (`ufw allow from 10.0.0.5 to any port 9100 proto tcp`), oppure `--web.listen-address=10.0.0.12:9100`
sull'interfaccia privata, oppure TLS e autenticazione con `--web.config.file`.

### Collector
Ogni gruppo di metriche lo produce un *collector*. Quasi tutti sono attivi per default; si attivano con
`--collector.NOME` e si spengono con `--no-collector.NOME`.
```bash
node_exporter --help | grep -E 'collector\.[a-z]+ '    # tutti, con "default: enabled/disabled"
```
| Collector | Metriche principali |
|---|---|
| cpu | `node_cpu_seconds_total{cpu, mode}`: secondi passati in ogni modo (idle, user, system, iowait, steal) |
| loadavg | `node_load1`, `node_load5`, `node_load15` |
| meminfo | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes`, `node_memory_SwapFree_bytes`... (da `/proc/meminfo`) |
| filesystem | `node_filesystem_size_bytes`, `_avail_bytes`, `_files_free` (inode), `_readonly` |
| diskstats | `node_disk_read_bytes_total`, `node_disk_io_time_seconds_total` (quanto il disco è occupato) |
| netdev | `node_network_receive_bytes_total`, `_transmit_bytes_total`, `_errs_total`, `_drop_total` |
| pressure | `node_pressure_cpu_waiting_seconds_total`, `node_pressure_memory_stalled_seconds_total` (PSI, kernel ≥ 4.20) |
| systemd (spento) | `node_systemd_unit_state{name, state}`: 1 per lo stato attuale di ogni unit |
| processes (spento) | `node_processes_state`, `node_processes_threads` |
| textfile | le metriche scritte da noi in file `.prom` |
| uname, os | `node_uname_info`, `node_os_info`: valore sempre 1, l'informazione sta nelle etichette |

Nel laboratorio, dal server:
```bash
curl -s localhost:9100/metrics | grep -E '^node_(load|memory_MemAvailable)'
curl -s localhost:9100/metrics | grep 'node_systemd_unit_state{name="nginx.service"'
curl -s localhost:9100/metrics | grep 'mountpoint="/dati"'
```
In un container node_exporter vede la CPU e la memoria della macchina (o della VM di Docker Desktop), non del solo
container: il carico prodotto con `stress-ng` nel laboratorio è carico vero del PC.

### Textfile collector: metriche dagli script
Il modo più semplice di portare in Prometheus qualcosa che solo uno script sa: l'esito di un backup, i pacchetti da
aggiornare, i giorni alla scadenza di un certificato, un conteggio da una query SQL. Lo script scrive un file `.prom`
nella cartella del textfile; node_exporter lo legge a ogni scrape.
```bash
#!/usr/bin/env bash
# aggiornamenti.sh - pacchetti da aggiornare, per il textfile collector (da cron ogni ora, come root)
set -euo pipefail
DIR=/var/lib/node_exporter/textfile
tot=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
sic=$(apt list --upgradable 2>/dev/null | grep -c -- '-security' || true)
cat > "$DIR/apt.prom.$$" << EOF
# HELP apt_aggiornamenti_in_attesa Pacchetti con un aggiornamento disponibile.
# TYPE apt_aggiornamenti_in_attesa gauge
apt_aggiornamenti_in_attesa{tipo="tutti"} $tot
apt_aggiornamenti_in_attesa{tipo="sicurezza"} $sic
# HELP riavvio_richiesto 1 se esiste /var/run/reboot-required.
# TYPE riavvio_richiesto gauge
riavvio_richiesto $([[ -f /var/run/reboot-required ]] && echo 1 || echo 0)
EOF
mv "$DIR/apt.prom.$$" "$DIR/apt.prom"      # mv è atomico: node_exporter non legge mai un file a metà
```
Regole:
- scrivere in un file temporaneo **nella stessa cartella** e poi `mv` (atomico solo nello stesso filesystem)
- l'estensione deve essere `.prom`: il temporaneo `apt.prom.1234` viene ignorato
- per i backup si espone **quando** è riuscito l'ultimo (timestamp), non "riuscito sì/no": l'alert diventa
  `time() - backup_ultimo_successo_timestamp_seconds > 26*3600`, e scatta anche se il cron non è proprio partito
- un file con un errore di formato blocca tutto il textfile: `node_textfile_scrape_error` vale 1, e nel log di
  node_exporter c'è il motivo

Nel laboratorio:
```bash
./backup.sh                                    # tar di /var/www in /dati/backup, metriche in backup_www.prom
cat /var/lib/node_exporter/textfile/backup_www.prom
curl -s localhost:9100/metrics | grep ^backup_
./backup.sh rotto                              # fallisce: backup_ultimo_esito 2, nessun timestamp di successo
echo 'questa riga è sbagliata' > /var/lib/node_exporter/textfile/rotto.prom
curl -s localhost:9100/metrics | grep textfile_scrape_error         # 1
journalctl -u node_exporter -n 3 --no-pager    # il motivo
rm /var/lib/node_exporter/textfile/rotto.prom
```
Con cron, ogni notte (`crontab -e` di root): `30 2 * * * /opt/script/backup.sh` (vedi
[../06-sistema/09-crontab.md](../06-sistema/09-crontab.md)).

## blackbox_exporter: controlli dall'esterno
Non si installa sul server da controllare: sonda indirizzi come farebbe un utente. Risponde alla domanda "il sito
funziona?" invece di "il server sta bene?". Configurazione: [lab/config/blackbox/blackbox.yml](lab/config/blackbox/blackbox.yml).
```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: []              # vuoto = 2xx
      fail_if_body_not_matches_regexp: ['Benvenuto']   # la pagina deve contenere questo testo
      fail_if_not_ssl: true
  tcp_connect:
    prober: tcp
  icmp:
    prober: icmp                          # serve CAP_NET_RAW
```
Si interroga passando modulo e bersaglio, ed è comodo anche a mano:
```bash
curl -s 'blackbox:9115/probe?module=http_2xx&target=http://server/' | grep -E '^probe_(success|duration|http_status)'
curl -s 'blackbox:9115/probe?module=http_2xx&target=http://server/&debug=true'   # il log della sonda
curl -s 'blackbox:9115/probe?module=tcp_connect&target=server:22' | grep probe_success
```
Metriche utili: `probe_success`, `probe_duration_seconds`, `probe_http_status_code`,
`probe_ssl_earliest_cert_expiry` (scadenza del certificato, Unix time).
In Prometheus serve il relabeling che sposta l'indirizzo nel parametro `target` (vedi
[lab/config/prometheus/prometheus.yml](lab/config/prometheus/prometheus.yml), job `blackbox-http`).

## nginx e Apache
nginx espone pochi contatori con il modulo `stub_status`:
```nginx
server {
    listen 127.0.0.1:8000;                    # solo in locale (o sulla rete interna)
    location = /stub_status { stub_status; }
}
```
```bash
curl -s localhost:8000/stub_status
# Active connections: 1
# server accepts handled requests
#  15 15 27
# Reading: 0 Writing: 1 Waiting: 0
docker run -d -p 9113:9113 nginx/nginx-prometheus-exporter:1.5.3 --nginx.scrape-uri=http://10.0.0.12:8000/stub_status
```
Ne escono `nginx_up`, `nginx_connections_active`, `nginx_http_requests_total`. Per avere codici di stato e tempi di
risposta per URL servono i log (Loki, `mtail`, `grok_exporter`) o NGINX Plus. Apache: `mod_status` e `apache_exporter`.

## Database
```bash
# MySQL: un utente con i soli permessi che servono
mysql -e "CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'segreto' WITH MAX_USER_CONNECTIONS 3;
          GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';"
printf '[client]\nuser=exporter\npassword=segreto\n' > /etc/mysqld_exporter.cnf && chmod 600 /etc/mysqld_exporter.cnf
mysqld_exporter --config.my-cnf=/etc/mysqld_exporter.cnf          # porta 9104; metriche mysql_*

# PostgreSQL: la stringa di connessione in una variabile d'ambiente
DATA_SOURCE_NAME='postgresql://exporter:segreto@localhost:5432/postgres?sslmode=disable' postgres_exporter   # porta 9187
```
Metriche da guardare: `mysql_up`, `mysql_global_status_threads_connected` contro `mysql_global_variables_max_connections`,
`mysql_global_status_slow_queries`, `mysql_slave_status_seconds_behind_master`; `pg_up`, `pg_stat_activity_count`,
`pg_database_size_bytes`.

## Container: cAdvisor
```bash
docker run -d --name cadvisor -p 8080:8080 \
    -v /:/rootfs:ro -v /var/run:/var/run:ro -v /sys:/sys:ro -v /var/lib/docker/:/var/lib/docker:ro \
    --device /dev/kmsg --privileged \
    gcr.io/cadvisor/cadvisor
```
Metriche `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `container_network_*`, con
l'etichetta `name` del container. In Kubernetes cAdvisor è già dentro il kubelet; il chart `kube-prometheus-stack`
porta Prometheus, Alertmanager, Grafana, node_exporter e kube-state-metrics con dashboard e alert pronti.

## Le applicazioni: /metrics scritto da noi
Si usa la libreria client del linguaggio; l'applicazione espone `/metrics` e Prometheus la legge come un exporter.
```python
# pip install prometheus-client
from prometheus_client import Counter, Histogram, start_http_server
import random, time

RICHIESTE = Counter("app_richieste_total", "Richieste gestite", ["metodo", "esito"])
DURATA = Histogram("app_richiesta_durata_seconds", "Durata delle richieste",
                   buckets=[0.05, 0.1, 0.25, 0.5, 1, 2.5])

start_http_server(8000)                    # /metrics sulla porta 8000
while True:
    with DURATA.time():                    # misura il blocco e lo mette nel bucket giusto
        time.sleep(random.random() / 2)
    RICHIESTE.labels(metodo="GET", esito="200").inc()
```
PHP: `promphp/prometheus_client_php` (i contatori stanno in Redis o APCu, perché ogni richiesta PHP è un processo a sé);
per Laravel il pacchetto `spatie/laravel-prometheus`. Per le code di Laravel conviene esporre la lunghezza delle code
(`Queue::size('default')`) e i job falliti (`failed_jobs`) come gauge.

### Pushgateway: job che durano poco
Un job di 10 secondi finisce prima che Prometheus passi a leggerlo. Può spingere le sue metriche al Pushgateway, che
le tiene finché qualcuno non le sovrascrive e le espone a Prometheus:
```bash
cat << EOF | curl --data-binary @- http://pushgateway:9091/metrics/job/backup_db/istanza/db1
backup_ultimo_successo_timestamp_seconds $(date +%s)
backup_dimensione_bytes $(stat -c %s /backup/db.sql.gz)
EOF
```
Sullo stesso server di un node_exporter il textfile collector è più semplice e non ha un servizio in più da tenere su.
