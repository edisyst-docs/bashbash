#!/usr/bin/env bash
# scenari.sh - gli scenari guidati di 09-scenari.md (area 12): un guasto vero nello stack di osservabilità.
#   scenari.sh guasta N      riporta tutto in salute, poi rompe come lo scenario N e stampa il "ticket"
#   scenari.sh controlla [N] dice se il sintomo è sparito (senza rivelare la causa); N è lo scenario in corso se omesso
#   scenari.sh ripristina    toglie ogni guasto
# NON si legge prima di aver provato: qui dentro ci sono i guasti. Gira come root sul server del laboratorio 12.
# (Non è lo scenari.sh di 05-alerting, che serve a un'altra cosa: provocare un alert.)
set -uo pipefail
cmd=${1:-}
n=${2:-}
NSCENARI=8
DIR=${LAB_SCENARI:-$HOME/lab/09-scenari}
W=$DIR/lavoro
STATO=/run/scenario-in-corso
SRC=${LAB:-/kb/12-osservabilita/lab}/config
MON=/etc/monitoring
PROM=http://prometheus:9090
AM=http://alertmanager:9093
GF=http://grafana:3000/api
MAILPIT=http://mailpit:8025/api/v1

[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 12: ./lab.sh 12)" >&2; exit 2; }
[[ -d $MON/prometheus ]] && getent hosts prometheus > /dev/null || { echo "serve il server del laboratorio 12 (non vede 'prometheus' e /etc/monitoring)" >&2; exit 2; }

ricarica() { curl -s -X POST "$PROM/-/reload" > /dev/null; curl -s -X POST "$AM/-/reload" > /dev/null; }
# aspetta (fino a $1 secondi) che il comando riesca
attendi() { local t=$1 i; shift; for ((i = 0; i < t; i++)); do "$@" > /dev/null 2>&1 && return 0; sleep 1; done; return 1; }

# ---------------------------------------------------------------- tutto in salute
salute() {
    cp -r "$SRC/prometheus/." "$MON/prometheus/"
    rm -f "$MON"/prometheus/regole/zz-*.yml
    cp "$SRC/alertmanager/alertmanager.yml" "$MON/alertmanager/alertmanager.yml"
    rm -f /etc/nginx/conf.d/zz-scenario.conf /dati/riempi.bin /var/lib/node_exporter/textfile/ordini.prom
    nginx -s reload 2> /dev/null
    curl -s -u admin:laboratorio "$GF/datasources/uid/prometheus-prod" -X DELETE > /dev/null
    curl -s -X DELETE "$MAILPIT/messages" > /dev/null
    ricarica
    mkdir -p "$W"; find "$W" -mindepth 1 -delete
    attendi 40 prom_su
    rm -f "$STATO"
}
prom_su() { [[ $(curl -s "$PROM/api/v1/query" --data-urlencode 'query=up{job="node"}' | jq -r '.data.result[0].value[1]') == 1 ]]; }
prom_giu() { [[ $(curl -s "$PROM/api/v1/query" --data-urlencode 'query=up{job="node"}' | jq -r '.data.result[0].value[1]') == 0 ]]; }

# ---------------------------------------------------------------- i guasti e i loro sintomi
guasta() {
    case $1 in
        1) sed -i 's/server:9100/server:9101/' "$MON/prometheus/prometheus.yml"; ricarica; attendi 30 prom_giu
           echo "In Prometheus il target del job node risulta DOWN (up vale 0) e i grafici di CPU e memoria della dashboard Server sono fermi." ;;
        2) cat > "$MON/prometheus/regole/zz-dati.yml" << 'EOF'
groups:
  - name: dati
    rules:
      - alert: DatiQuasiPieno
        expr: node_filesystem_avail_byte{mountpoint="/dati"} / node_filesystem_size_bytes{mountpoint="/dati"} < 0.3
        for: 0s
        labels:
          severity: warning
        annotations:
          summary: "/dati ha meno del 30% libero"
EOF
           dd if=/dev/zero of=/dati/riempi.bin bs=1M count=50 2> /dev/null; ricarica
           echo "/dati è pieno quasi all'80% (df lo conferma), ma l'alert DatiQuasiPieno non scatta mai." ;;
        3) cat > "$W/richieste.sh" << 'EOF'
#!/usr/bin/env bash
# stampa le richieste AL SECONDO che nginx sta ricevendo (dall'exporter, via Prometheus)
curl -s http://prometheus:9090/api/v1/query --data-urlencode 'query=nginx_http_requests_total' | jq -r '.data.result[0].value[1]'
EOF
           local i; for i in $(seq 1 60); do curl -s -o /dev/null http://localhost/; done; sleep 12
           echo "lavoro/richieste.sh dovrebbe stampare le richieste al secondo di nginx, ma stampa un numero grande che non fa che salire." ;;
        4) sed -i 's/severity="critical"/severity="critico"/' "$MON/alertmanager/alertmanager.yml"; ricarica
           echo "Un alert con severity=critical è arrivato a squadra@lab.local invece che al reperibile (reperibile@lab.local)." ;;
        5) sed -i 's/to: squadra@lab.local/to: nuova-squadra@lab.local/; s/send_resolved: true  /send_resolved true  /' "$MON/alertmanager/alertmanager.yml"; ricarica
           echo "Ho cambiato l'indirizzo di squadra in nuova-squadra@lab.local in alertmanager.yml e ricaricato Alertmanager, ma le email degli alert warning vanno ancora a squadra@lab.local." ;;
        6) printf 'access_log off;\n' > /etc/nginx/conf.d/zz-scenario.conf; nginx -s reload 2> /dev/null; sleep 2    # il reload è asincrono: i vecchi processi scrivono ancora per un attimo
           echo "Le richieste a nginx non compaiono più in Loki ({job=\"nginx\"}): il grafico dei log si è fermato, ma il sito risponde." ;;
        7) curl -s -u admin:laboratorio "$GF/datasources" -X POST -H 'content-type: application/json' \
               -d '{"name":"Prometheus (prod)","uid":"prometheus-prod","type":"prometheus","access":"proxy","url":"http://prometheus:9091"}' > /dev/null
           echo "In Grafana la data source \"Prometheus (prod)\" (uid prometheus-prod) non funziona: i pannelli che la usano mostrano errori." ;;
        8) cat > "$W/scrivi-metrica.sh" << 'EOF'
#!/usr/bin/env bash
# scrive nel textfile collector di node_exporter la metrica degli ordini
f=/var/lib/node_exporter/textfile/ordini.prom
echo '# TYPE ordini_totale counter' > "$f"
echo 'ordini_totale{stato=pagato} 42' >> "$f"
EOF
           echo "lavoro/scrivi-metrica.sh scrive la metrica ordini_totale per node_exporter, ma in Prometheus la metrica non compare." ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    chmod +x "$W"/*.sh 2> /dev/null
    return 0
}

# ---------------------------------------------------------------- i controlli: il sintomo è sparito?
ESITO=0
prova() {
    local d=$1; shift
    if "$@" > /dev/null 2>&1; then echo "  OK        $d"; else echo "  ANCORA NO $d"; ESITO=1; fi
}
c1() { attendi 25 prom_su; }
c2_alert() { attendi 30 bash -c "curl -s $PROM/api/v1/alerts | jq -e '.data.alerts[] | select(.labels.alertname == \"DatiQuasiPieno\" and .state == \"firing\")'"; }
c2_pieno() { (( $(df --output=pcent /dati | tail -1 | tr -dc 0-9) >= 70 )); }
c3() {
    local v tot; v=$(cd "$W" && timeout 30 bash richieste.sh 2> /dev/null)
    tot=$(curl -s "$PROM/api/v1/query" --data-urlencode 'query=nginx_http_requests_total' | jq -r '.data.result[0].value[1]')
    [[ $v =~ ^[0-9]+(\.[0-9]+)?(e-?[0-9]+)?$ ]] && awk -v v="$v" -v t="$tot" 'BEGIN { exit !(t > 50 && v < t / 4) }'
}
# manda un alert di prova ad Alertmanager e dice se arriva un messaggio a $2 (severity $1)
mail_a() {
    local sev=$1 dest=$2 nome="ProvaScenario$RANDOM" fine
    fine=$(date -u -d '+90 sec' +%Y-%m-%dT%H:%M:%SZ)
    curl -s -X DELETE "$MAILPIT/messages" > /dev/null
    curl -s -X POST "$AM/api/v2/alerts" -H 'content-type: application/json' \
        -d "[{\"labels\":{\"alertname\":\"$nome\",\"severity\":\"$sev\",\"host\":\"server\"},\"endsAt\":\"$fine\"}]" > /dev/null
    attendi 20 bash -c "curl -s $MAILPIT/messages | jq -e '.messages[] | select(.Subject | contains(\"$nome\")) | .To[] | select(.Address == \"$dest\")'"
}
c4() { mail_a critical reperibile@lab.local; }
c5() { mail_a warning nuova-squadra@lab.local; }
c6() {
    sleep 2      # dopo un reload i vecchi processi di nginx servono ancora per un attimo
    local ua="controlla-$RANDOM"; curl -s -o /dev/null -A "$ua" http://localhost/
    attendi 25 bash -c "curl -s -G http://loki:3100/loki/api/v1/query_range --data-urlencode 'query={job=\"nginx\"} |= \"$ua\"' --data-urlencode \"start=\$(date -d '-5 min' +%s)000000000\" --data-urlencode limit=5 | jq -e '.data.result | length > 0'"
}
c7() { attendi 12 bash -c "curl -s -u admin:laboratorio http://grafana:3000/api/datasources/uid/prometheus-prod/health | jq -e '.status == \"OK\"'"; }
c8() {
    (cd "$W" && timeout 30 bash scrivi-metrica.sh) || return 1
    curl -s localhost:9100/metrics | grep -q '^ordini_totale{stato="pagato"} 42$' && curl -s localhost:9100/metrics | grep -q '^node_textfile_scrape_error 0$'
}
controlla() {
    case $1 in
        1) prova "up{job=\"node\"} vale 1 (il target risponde)" c1 ;;
        2) prova "l'alert DatiQuasiPieno scatta (firing) con /dati pieno" c2_alert
           prova "/dati è ancora pieno: il disco non è stato liberato per far tacere l'alert" c2_pieno ;;
        3) prova "richieste.sh stampa un valore al secondo, non il totale" c3 ;;
        4) prova "un alert critical arriva a reperibile@lab.local" c4 ;;
        5) prova "un alert warning arriva a nuova-squadra@lab.local" c5 ;;
        6) prova "una richiesta a nginx compare in Loki entro pochi secondi" c6 ;;
        7) prova "la data source prometheus-prod risponde (health OK)" c7 ;;
        8) prova "scrivi-metrica.sh produce ordini_totale in node_exporter, senza errori del textfile" c8 ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    if (( ESITO == 0 )); then echo "RISOLTO"; else echo "non ancora"; fi
    return $ESITO
}

case $cmd in
    guasta)
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 guasta N   (N da 1 a $NSCENARI)" >&2; exit 2; }
        salute; guasta "$n"; echo "$n" > "$STATO" ;;
    controlla)
        [[ -n $n ]] || n=$(cat "$STATO" 2> /dev/null) || { echo "nessuno scenario in corso: ./scenari.sh guasta N" >&2; exit 2; }
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 controlla [N]" >&2; exit 2; }
        controlla "$n" ;;
    ripristina) salute; echo "tutto in salute" ;;
    *) echo "uso: $0 guasta N | controlla [N] | ripristina" >&2; exit 2 ;;
esac
