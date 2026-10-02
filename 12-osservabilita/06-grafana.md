# Grafana

> **Laboratorio**: `./lab.sh 12`, poi dal PC http://localhost:3000 (`admin` / `laboratorio`; senza login si guarda
> soltanto). Cosa contiene: [lab/](lab/).

Dashboard e grafici sopra una o più sorgenti di dati (*data source*): Prometheus, Loki, MySQL, PostgreSQL,
Elasticsearch, CloudWatch. Non conserva le metriche: a ogni aggiornamento interroga la sorgente.
Porta **3000**. Versione del laboratorio: 13.2 (settembre 2026). Documentazione: https://grafana.com/docs/grafana/latest/

## Installazione
```bash
# Ubuntu/Debian: repository ufficiale
sudo apt install -y apt-transport-https gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install grafana
sudo systemctl enable --now grafana-server
# configurazione /etc/grafana/grafana.ini, dati (SQLite) in /var/lib/grafana, log in /var/log/grafana

# Docker
docker run -d --name grafana -p 3000:3000 -v grafana:/var/lib/grafana grafana/grafana:13.2.3
```
Primo accesso `admin` / `admin`, poi chiede di cambiarla. Ogni opzione di `grafana.ini` si può dare come variabile
d'ambiente `GF_<SEZIONE>_<CHIAVE>`: `[security] admin_password` → `GF_SECURITY_ADMIN_PASSWORD`. Nel laboratorio:
[lab/compose.yaml](lab/compose.yaml).

Dietro nginx con un percorso (`https://example.com/grafana/`): `GF_SERVER_ROOT_URL=https://example.com/grafana/` e
`GF_SERVER_SERVE_FROM_SUB_PATH=true`. Per un database condiviso (più istanze di Grafana) `[database]` verso MySQL o PostgreSQL.

## Data source
*Connections > Data sources > Add data source > Prometheus*, URL `http://prometheus:9090`, *Save & test*.
In produzione si configurano da file (provisioning, sotto).

## Dashboard
*Dashboards > New > New dashboard > Add visualization*, scelta la data source si scrive la query PromQL.
- **visualizzazioni**: *Time series* (andamento), *Stat* (un numero grande, colorato con le soglie), *Gauge*,
  *Bar gauge*, *Table*, *State timeline* (su/giù nel tempo), *Heatmap* (per gli istogrammi), *Logs*
- **Legend**: `{{instance}}` usa le etichette della serie come nome della linea
- **Standard options > Unit**: `percent (0.0-1.0)`, `bytes(IEC)`, `seconds`, `requests/sec`: Grafana formatta da sola
- **Thresholds**: verde/arancio/rosso a partire da certi valori
- **Overrides**: cambiano colore, unità o asse solo per alcune serie
- **Transformations**: unire, rinominare, nascondere colonne di una tabella
- il **time picker** in alto (ultimi 15 minuti, ultime 24 ore) e l'aggiornamento automatico; trascinando su un
  grafico si fa zoom su quell'intervallo
- **Explore** (la bussola): query al volo senza creare una dashboard, utile in un'emergenza

### Variabili
Rendono una dashboard riusabile: *Dashboard settings > Variables > New variable*, tipo *Query*:
```promql
label_values(node_uname_info, instance)        # tutti i valori di instance: diventa un menu a tendina
label_values(node_filesystem_size_bytes{instance="$instance"}, mountpoint)   # dipende dalla variabile sopra
```
e nelle query `node_load1{instance="$instance"}`. Con *Multi-value* si scelgono più valori: `{instance=~"$instance"}`.
Variabili già pronte: `$__rate_interval` (la finestra giusta per `rate()`, da usare sempre al posto di `[5m]`),
`$__interval`, `$__range`.

Nella dashboard *Server* del laboratorio la variabile è `$host`; il pannello *Alert attivi* è una tabella sulla serie
`ALERTS` di Prometheus.

### Dashboard già fatte
https://grafana.com/grafana/dashboards/ ha migliaia di dashboard: *Dashboards > New > Import*, numero, data source.
| ID | Dashboard |
|---|---|
| 1860 | Node Exporter Full: tutto node_exporter, la più usata |
| 7587 | Prometheus Blackbox Exporter |
| 12708 | NGINX exporter |
| 14057 | MySQL |
| 9628 | PostgreSQL |
| 3662 | Prometheus 2.0 Overview: come sta Prometheus stesso |
| 9578 | Alertmanager |

Una dashboard importata è un punto di partenza: si toglie quello che non serve.

## Provisioning: Grafana da codice
Data source e dashboard descritte in file, caricate all'avvio: un Grafana nuovo è identico al vecchio, e le modifiche
passano da git. È come è configurato il laboratorio:
```
lab/config/grafana/
├── provisioning/
│   ├── datasources/prometheus.yml     → /etc/grafana/provisioning/datasources/
│   └── dashboards/kb.yml              → /etc/grafana/provisioning/dashboards/  (dove cercare i JSON)
└── dashboard/server.json              → /var/lib/grafana/dashboards/
```
[datasources/prometheus.yml](lab/config/grafana/provisioning/datasources/prometheus.yml):
```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus                       # uid fisso: le dashboard JSON lo citano
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
```
[dashboards/kb.yml](lab/config/grafana/provisioning/dashboards/kb.yml):
```yaml
apiVersion: 1
providers:
  - name: kb
    folder: Laboratorio
    type: file
    allowUiUpdates: true                  # false: la dashboard si cambia solo dal file
    options:
      path: /var/lib/grafana/dashboards
```
Il JSON di una dashboard si ottiene da *Edit > Export > Export as JSON* (opzione *Export for sharing externally* per
togliere gli uid delle data source). Dopo una modifica al file la dashboard si aggiorna da sola entro
`updateIntervalSeconds` (default 10 s).
Esiste anche il provisioning degli alert di Grafana (`provisioning/alerting/`), dei plugin e delle notifiche.
Con Terraform: provider `grafana/grafana` (vedi [../11-container-e-automazione/09-terraform/](../11-container-e-automazione/09-terraform/)).

## API
Per script e backup. Si autentica con un *service account* (*Administration > Users and access > Service accounts >
Add service account*, ruolo Editor o Admin, poi *Add service account token*), non con la password di admin.
```bash
G=http://localhost:3000
T=glsa_xxxxxxxx                                 # il token del service account
curl -s -H "Authorization: Bearer $T" $G/api/search | jq -r '.[] | "\(.type)\t\(.uid)\t\(.title)"'
curl -s -H "Authorization: Bearer $T" $G/api/dashboards/uid/server | jq .dashboard > server.json   # backup
curl -s -H "Authorization: Bearer $T" -H 'Content-Type: application/json' -X POST $G/api/dashboards/db \
     -d "$(jq '{dashboard: (. | del(.id)), overwrite: true}' server.json)"                       # ripristino
curl -s $G/api/health                           # {"database": "ok", "version": "13.2.3", ...}
```
Backup di tutte le dashboard:
```bash
mkdir -p backup-grafana
curl -s -H "Authorization: Bearer $T" "$G/api/search?type=dash-db" | jq -r '.[].uid' | while read -r uid; do
    curl -s -H "Authorization: Bearer $T" "$G/api/dashboards/uid/$uid" | jq .dashboard > "backup-grafana/$uid.json"
done
```
Nel laboratorio, dal server, con utente e password: `curl -s -u admin:laboratorio http://grafana:3000/api/search`.

## Alert di Grafana
Grafana ha un suo motore di alert (*Alerting > Alert rules*), con notifiche verso email, Slack, Teams e un suo
Alertmanager interno. Comodo quando la sorgente non è Prometheus (una query SQL, CloudWatch). Con Prometheus conviene
tenere le regole in Prometheus e Alertmanager ([05-alerting.md](05-alerting.md)): stanno in file versionati,
si provano con `promtool` e continuano a funzionare se Grafana è giù.
