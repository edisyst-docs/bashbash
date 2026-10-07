#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 12: osservabilità
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gira sul container "server", quello monitorato. Prometheus, Alertmanager, Grafana e gli exporter li avvia
# compose.yaml; qui si preparano gli script per interrogare l'API, scrivere metriche, provocare gli alert.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md

# ---------------------------------------------------------------- 01-concetti, 06-grafana
# si lavora dal browser e con curl: le cartelle ci sono per coerenza con le altre aree
for s in 01-concetti 06-grafana; do sezione "$s"; done

# ---------------------------------------------------------------- 02-prometheus
sezione 02-prometheus
ln -s /etc/monitoring config                      # prometheus.yml, regole e alertmanager.yml, modificabili
cat > api.sh << 'EOF'
#!/usr/bin/env bash
# api.sh - una query PromQL all'API HTTP di Prometheus, una serie per riga: valore e etichette.
# Uso: ./api.sh 'up'      ./api.sh 'rate(node_cpu_seconds_total{mode="idle"}[1m])'
set -euo pipefail
PROMETHEUS=${PROMETHEUS:-http://prometheus:9090}
curl -sS "$PROMETHEUS/api/v1/query" --data-urlencode "query=${1:?uso: $0 QUERY}" | jq -r '
    if .status != "success" then "ERRORE: \(.error)\n" | halt_error(1)
    elif .data.resultType == "vector" then
        .data.result[] | "\(.value[1])\t\(.metric | to_entries | map("\(.key)=\(.value)") | join(" "))"
    else .data.result[1] end'
EOF
chmod +x api.sh

# ---------------------------------------------------------------- 03-exporter
sezione 03-exporter
cat > backup.sh << 'EOF'
#!/usr/bin/env bash
# backup.sh - un backup finto che lascia le sue metriche al textfile collector di node_exporter.
# Uso: ./backup.sh [ARCHIVIO]      (default: www, cioè /var/www; con "rotto" fallisce e non aggiorna il timestamp di successo)
set -euo pipefail
ARCHIVIO=${1:-www}
case $ARCHIVIO in
    www)   SORGENTE=/var/www ;;
    rotto) SORGENTE=/non/esiste ;;
    *)     SORGENTE=/$ARCHIVIO ;;                 # es. etc: da tester fallisce, /etc/shadow non è leggibile
esac
TEXTFILE=/var/lib/node_exporter/textfile
mkdir -p /dati/backup
inizio=$(date +%s.%N)
esito=0
tar czf "/dati/backup/$ARCHIVIO.tgz" "$SORGENTE" 2>/dev/null || esito=$?
fine=$(date +%s.%N)

# scrittura atomica: node_exporter non deve mai leggere un file a metà, quindi file temporaneo e mv
f="$TEXTFILE/backup_$ARCHIVIO.prom"
{
    echo "# HELP backup_ultimo_esito Codice di uscita dell'ultimo backup (0 = riuscito)."
    echo "# TYPE backup_ultimo_esito gauge"
    echo "backup_ultimo_esito{archivio=\"$ARCHIVIO\"} $esito"
    echo "# HELP backup_durata_secondi Durata dell'ultimo backup."
    echo "# TYPE backup_durata_secondi gauge"
    echo "backup_durata_secondi{archivio=\"$ARCHIVIO\"} $(echo "$fine - $inizio" | bc | xargs printf '%.3f')"
    if (( esito == 0 )); then
        echo "# HELP backup_ultimo_successo_timestamp_seconds Quando è finito l'ultimo backup riuscito (Unix time)."
        echo "# TYPE backup_ultimo_successo_timestamp_seconds gauge"
        echo "backup_ultimo_successo_timestamp_seconds{archivio=\"$ARCHIVIO\"} ${fine%.*}"
        echo "# TYPE backup_dimensione_bytes gauge"
        echo "backup_dimensione_bytes{archivio=\"$ARCHIVIO\"} $(stat -c %s "/dati/backup/$ARCHIVIO.tgz")"
    elif [[ -f $f ]]; then
        grep -E '^backup_(ultimo_successo_timestamp_seconds|dimensione_bytes)' "$f" || true   # tiene l'ultimo successo
    fi
} > "$f.$$"
mv "$f.$$" "$f"
echo "backup $ARCHIVIO: esito $esito, metriche in $f"
exit "$esito"
EOF
chmod +x backup.sh

# ---------------------------------------------------------------- 04-promql
sezione 04-promql
cp "$DEST/02-prometheus/api.sh" .
cat > query.txt << 'EOF'
# Query da provare con ./api.sh 'QUERY' o in Prometheus (http://localhost:9090, scheda Query). Una per riga.
up
up == 0
node_cpu_seconds_total{mode="idle"}
rate(node_cpu_seconds_total{mode="idle"}[1m])
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m]))
sum by (mode) (rate(node_cpu_seconds_total[1m]))
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
node_filesystem_avail_bytes{mountpoint="/dati"} / 1024 / 1024
predict_linear(node_filesystem_avail_bytes{mountpoint="/dati"}[5m], 3600)
rate(node_network_receive_bytes_total{device!="lo"}[1m])
increase(nginx_http_requests_total[5m])
topk(3, rate(prometheus_http_requests_total[5m]))
histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
node_systemd_unit_state{state="failed"} == 1
time() - backup_ultimo_successo_timestamp_seconds
absent(backup_ultimo_successo_timestamp_seconds{archivio="db"})
probe_success
probe_duration_seconds offset 5m
count by (job) (up)
ALERTS
EOF
cat > traffico.sh << 'EOF'
#!/usr/bin/env bash
# traffico.sh - richieste a nginx per avere qualcosa nei grafici. Uso: ./traffico.sh [SECONDI] [RICHIESTE_AL_SECONDO]
set -euo pipefail
durata=${1:-60} rps=${2:-20}
fine=$(( SECONDS + durata ))
while (( SECONDS < fine )); do
    for (( i = 0; i < rps; i++ )); do curl -s -o /dev/null http://localhost/ & done
    wait
    sleep 1
done
echo "fatto: circa $(( durata * rps )) richieste"
EOF
chmod +x traffico.sh

# ---------------------------------------------------------------- 05-alerting
sezione 05-alerting
cp "$DEST/03-exporter/backup.sh" .
cat > scenari.sh << 'EOF'
#!/usr/bin/env bash
# scenari.sh - provoca un guasto per far scattare un alert, poi "pulisci" rimette tutto a posto.
# Uso: ./scenari.sh cpu|disco|riempi|nginx|exporter|unit|backup|pulisci
set -euo pipefail
(( EUID == 0 )) || exec sudo "$0" "$@"            # servono systemctl e /dati: da tester passa per sudo

case "${1:-}" in
    cpu)      echo "CpuAlta dopo 1 minuto sopra l'80% (il container vede la CPU del PC: il carico è vero)"
              setsid -f stress-ng --cpu 0 --cpu-load 95 --timeout 150s --quiet ;;
    disco)    echo "DiscoQuasiPieno: /dati all'88% (tmpfs da 64 MB)"
              fallocate -l 56M /dati/zavorra ;;
    riempi)   echo "DiscoSiRiempira: /dati cresce di 1 MB ogni 3 secondi per 2 minuti (predict_linear)"
              setsid -f bash -c 'for i in $(seq 40); do dd if=/dev/zero of=/dati/crescita.$i bs=1M count=1 status=none; sleep 3; done' ;;
    nginx)    echo "SitoNonRaggiungibile e NginxGiu: in Alertmanager arriva solo il primo (inhibit_rules)"
              systemctl stop nginx ;;
    exporter) echo "IstanzaGiu per job=node: Prometheus non legge più server:9100"
              systemctl stop node_exporter ;;
    unit)     echo "UnitFallita: un servizio che esce con codice 3"
              systemd-run --unit=lavoro-notturno --quiet sh -c 'echo "lavoro notturno: errore"; exit 3' ;;
    backup)   echo "BackupVecchio: backup riuscito ora, l'alert scatta quando ha più di 2 minuti"
              "$(dirname "$0")/backup.sh" ;;
    pulisci)  pkill stress-ng || true
              pkill -f 'crescita\.' || true
              rm -f /dati/zavorra /dati/crescita.*
              rm -f /var/lib/node_exporter/textfile/backup_*.prom
              systemctl start nginx node_exporter
              systemctl reset-failed
              echo "tutto a posto: gli alert si risolvono entro un minuto (Alertmanager manda il messaggio di risolto)" ;;
    *)        sed -n '3s/^# //p' "$0" >&2; exit 2 ;;
esac
EOF
chmod +x scenari.sh
cat > test-regole.yml << 'EOF'
# Unit test delle regole: promtool test rules test-regole.yml
# Serie inventate con i loro valori nel tempo, e cosa ci si aspetta a un certo istante.
rule_files:
  - /etc/monitoring/prometheus/regole/registrazione.yml
  - /etc/monitoring/prometheus/regole/server.yml
evaluation_interval: 10s

tests:
  - interval: 10s                                 # un valore ogni 10 secondi
    input_series:
      - series: 'up{job="node", instance="server:9100", host="server"}'
        values: '1 1 1 0 0 0 0 0 0 0'               # giù dal secondo 30
      - series: 'backup_ultimo_successo_timestamp_seconds{archivio="etc", host="server"}'
        values: '0x20'                            # backup fatto all'istante 0, valore costante per 20 passi
    alert_rule_test:
      - eval_time: 40s                            # giù da 10s: l'alert è pending, non ancora firing
        alertname: IstanzaGiu
        exp_alerts: []
      - eval_time: 70s                            # giù da 40s, più dei 30s di "for"
        alertname: IstanzaGiu
        exp_alerts:
          - exp_labels: {severity: critical, job: node, instance: "server:9100", host: server}
            exp_annotations:
              summary: "node su server:9100 non risponde"
              description: "Prometheus non riesce a leggere le metriche da server:9100 da almeno 30 secondi."
      - eval_time: 1m                             # time() vale 60: backup di un minuto fa, va bene
        alertname: BackupVecchio
        exp_alerts: []
      - eval_time: 3m
        alertname: BackupVecchio
        exp_alerts:
          - exp_labels: {severity: warning, archivio: etc, host: server}
            exp_annotations:
              summary: "ultimo backup di etc su server riuscito 3m 0s fa"
EOF

# ---------------------------------------------------------------- 07-loki
sezione 07-loki
ln -s /etc/monitoring config
cat > query.sh << 'EOF'
#!/usr/bin/env bash
# query.sh - una query LogQL a Loki via logcli, con output breve.
# Uso: ./query.sh '{job="nginx"}'                                      ultimi 10 log
#      ./query.sh '{job="nginx"} |= "404"' --limit 50                  con filtro e limite
#      ./query.sh '{job="nginx"} | json | status >= 500' --since 5m    errori degli ultimi 5 minuti
set -euo pipefail
QUERY=${1:?uso: $0 'QUERY_LOGQL' [opzioni logcli]}
shift
logcli query "$QUERY" --quiet "$@"
EOF
chmod +x query.sh
cat > push.sh << 'EOF'
#!/usr/bin/env bash
# push.sh - manda una riga di log a Loki via API push: per provare senza agente.
# Uso: ./push.sh "messaggio di prova"       (job=test, host=server)
set -euo pipefail
MSG=${1:?uso: $0 "messaggio"}
TS=$(date +%s)000000000
curl -s -X POST http://loki:3100/loki/api/v1/push \
    -H 'Content-Type: application/json' \
    -d "{\"streams\":[{\"stream\":{\"job\":\"test\",\"host\":\"server\"},\"values\":[[\"$TS\",\"$MSG\"]]}]}"
echo "inviato a Loki: $MSG"
EOF
chmod +x push.sh

# ---------------------------------------------------------------- 08-tracing
sezione 08-tracing
cat > traccia.sh << 'EOF2'
#!/usr/bin/env bash
# traccia.sh - manda ad Alloy (OTLP/HTTP) una traccia finta di tre servizi: frontend -> api -> database.
# Uso: ./traccia.sh [ok|lenta|errore] [ENDPOINT]        (default: ok, http://alloy:4318)
#   ok      una richiesta di circa 140 ms
#   lenta   la stessa richiesta, ma la query al database dura 2 secondi
#   errore  la query al database fallisce: lo span è in errore e la richiesta risponde 500
# Stampa l'ID della traccia: serve a Tempo (curl http://tempo:3200/api/traces/ID) e a Jaeger.
set -euo pipefail
ESITO=${1:-ok}
OTLP=${2:-http://alloy:4318}

id() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }       # N byte casuali in esadecimale
TRACCIA=$(id 16); FE=$(id 8); API=$(id 8); DB=$(id 8); PAG=$(id 8)

DB_MS=60; STATO_DB='{}'; HTTP=200; MSG_ERRORE=''
case $ESITO in
    ok) ;;
    lenta) DB_MS=2000 ;;
    errore) DB_MS=30; HTTP=500; STATO_DB='{"code":2,"message":"deadlock detected"}' ;;
    *) echo "uso: $0 [ok|lenta|errore]" >&2; exit 2 ;;
esac
# durate in millisecondi, offset dall'inizio della richiesta
API_FINE=$(( 10 + DB_MS + 40 + 20 ))
TOTALE=$(( API_FINE + 10 ))
INIZIO=$(( $(date +%s%N) - TOTALE * 1000000 ))
t() { echo $(( INIZIO + $1 * 1000000 )); }                              # offset in ms -> timestamp in ns

curl -s -o /dev/null -w "OTLP: HTTP %{http_code}\n" -X POST "$OTLP/v1/traces" -H 'Content-Type: application/json' -d "{
 \"resourceSpans\": [
  {\"resource\": {\"attributes\": [{\"key\":\"service.name\",\"value\":{\"stringValue\":\"frontend\"}}]},
   \"scopeSpans\": [{\"scope\":{\"name\":\"traccia.sh\"},\"spans\": [
     {\"traceId\":\"$TRACCIA\",\"spanId\":\"$FE\",\"name\":\"GET /ordini/42\",\"kind\":2,
      \"startTimeUnixNano\":\"$(t 0)\",\"endTimeUnixNano\":\"$(t $TOTALE)\",
      \"attributes\":[{\"key\":\"http.request.method\",\"value\":{\"stringValue\":\"GET\"}},
                      {\"key\":\"http.response.status_code\",\"value\":{\"intValue\":\"$HTTP\"}}],
      \"status\": $( [[ $HTTP == 500 ]] && echo '{"code":2}' || echo '{}' )}]}]},
  {\"resource\": {\"attributes\": [{\"key\":\"service.name\",\"value\":{\"stringValue\":\"api\"}}]},
   \"scopeSpans\": [{\"scope\":{\"name\":\"traccia.sh\"},\"spans\": [
     {\"traceId\":\"$TRACCIA\",\"spanId\":\"$API\",\"parentSpanId\":\"$FE\",\"name\":\"GET /ordini/{id}\",\"kind\":2,
      \"startTimeUnixNano\":\"$(t 5)\",\"endTimeUnixNano\":\"$(t $API_FINE)\",
      \"attributes\":[{\"key\":\"http.route\",\"value\":{\"stringValue\":\"/ordini/{id}\"}}]},
     {\"traceId\":\"$TRACCIA\",\"spanId\":\"$DB\",\"parentSpanId\":\"$API\",\"name\":\"SELECT ordini\",\"kind\":3,
      \"startTimeUnixNano\":\"$(t 10)\",\"endTimeUnixNano\":\"$(t $((10 + DB_MS)))\",
      \"attributes\":[{\"key\":\"db.system\",\"value\":{\"stringValue\":\"postgresql\"}},
                      {\"key\":\"db.statement\",\"value\":{\"stringValue\":\"SELECT * FROM ordini WHERE id = \$1\"}}],
      \"status\": $STATO_DB},
     {\"traceId\":\"$TRACCIA\",\"spanId\":\"$PAG\",\"parentSpanId\":\"$API\",\"name\":\"POST /pagamenti/verifica\",\"kind\":3,
      \"startTimeUnixNano\":\"$(t $((10 + DB_MS + 5)))\",\"endTimeUnixNano\":\"$(t $((10 + DB_MS + 45)))\"}]}]}
 ]}"
echo "traccia: $TRACCIA ($ESITO, $TOTALE ms)"
EOF2
chmod +x traccia.sh
cat > app.py << 'EOF2'
"""app.py - una piccola applicazione strumentata con OpenTelemetry: due "servizi", ordini e magazzino."""
import random
import time

from opentelemetry import propagate, trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def crea_tracer(servizio):
    """Un TracerProvider per servizio: il nome (service.name) finisce su ogni span."""
    provider = TracerProvider(resource=Resource.create({"service.name": servizio}))
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint="http://alloy:4318/v1/traces")))
    return provider, provider.get_tracer(servizio)


prov_ordini, tracer_ordini = crea_tracer("ordini")
prov_magazzino, tracer_magazzino = crea_tracer("magazzino")


def magazzino(intestazioni, sku):
    """Il secondo servizio: continua la traccia ricevuta nell'header traceparent."""
    ctx = propagate.extract(intestazioni)
    with tracer_magazzino.start_as_current_span("verifica giacenza", context=ctx, kind=trace.SpanKind.SERVER) as span:
        span.set_attribute("sku", sku)
        time.sleep(random.uniform(0.02, 0.05))
        if sku == "ZZ9":
            span.set_status(trace.Status(trace.StatusCode.ERROR, "esaurito"))
            raise RuntimeError(f"{sku} esaurito")


def crea_ordine(sku):
    with tracer_ordini.start_as_current_span("POST /ordini", kind=trace.SpanKind.SERVER) as span:
        span.set_attribute("sku", sku)
        with tracer_ordini.start_as_current_span("valida", kind=trace.SpanKind.INTERNAL):
            time.sleep(0.01)
        with tracer_ordini.start_as_current_span("chiama magazzino", kind=trace.SpanKind.CLIENT):
            intestazioni = {}
            propagate.inject(intestazioni)          # aggiunge traceparent: "00-<id traccia>-<id span>-01"
            print("header inviato:", intestazioni)
            magazzino(intestazioni, sku)            # nella realtà: requests.get(url, headers=intestazioni)
        span.add_event("ordine creato")             # un evento con il suo orario dentro lo span
        return trace.format_trace_id(span.get_span_context().trace_id)


for sku in ("A1", "ZZ9"):
    try:
        print(sku, "traccia", crea_ordine(sku))
    except RuntimeError as errore:
        print(sku, "errore:", errore)

prov_ordini.shutdown()                              # svuota il lotto in sospeso prima di uscire
prov_magazzino.shutdown()
EOF2

# ---------------------------------------------------------------- 09-scenari
sezione 09-scenari
cat > scenari.sh << EOF
#!/usr/bin/env bash
# i guasti stanno in $LAB_SRC/scenari.sh: non aprirlo prima di aver provato
exec bash $LAB_SRC/scenari.sh "\$@"
EOF
chmod +x scenari.sh

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 12 pronto in $DEST: una cartella per ogni .md"
    echo "Questo è il server monitorato (node_exporter :9100, nginx :80). Dal PC: Prometheus http://localhost:9090,"
    echo "Alertmanager http://localhost:9093, Grafana http://localhost:3000 (admin / laboratorio),"
    echo "Loki http://localhost:3100, Alloy http://localhost:12345, Tempo http://localhost:3200, Jaeger http://localhost:16686, posta http://localhost:8025"
    echo "Prova: cd 05-alerting && ./scenari.sh nginx"
    echo "Per ripartire da zero con i file: bash $LAB_SRC/prepara.sh"
fi
