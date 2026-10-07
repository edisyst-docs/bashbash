#!/usr/bin/env bash
# scenari-soluzioni.sh FASE N - le riparazioni di riferimento degli scenari di 09-scenari.md (area 12), e alcune "scorciatoie"
# che sembrano ripararli ma non lo fanno (servono a provare che scenari.sh controlla non si lascia ingannare).
#   scenari-soluzioni.sh risolvi N     la riparazione giusta
#   scenari-soluzioni.sh sbagliata N   un tentativo che non basta (non esiste per tutti gli scenari)
# La usa scenari-autotest.sh. Gira come root sul server del laboratorio 12.
set -uo pipefail
fase=${1:?uso: $0 risolvi|sbagliata N}
n=${2:?uso: $0 FASE N}
W=${LAB_SCENARI:-$HOME/lab/09-scenari}/lavoro
MON=/etc/monitoring
ricarica() { curl -s -X POST http://prometheus:9090/-/reload > /dev/null; curl -s -X POST http://alertmanager:9093/-/reload > /dev/null; }

risolvi() {
    case $n in
        1) sed -i 's/server:9101/server:9100/' "$MON/prometheus/prometheus.yml"; ricarica ;;
        2) sed -i 's/node_filesystem_avail_byte{/node_filesystem_avail_bytes{/' "$MON/prometheus/regole/zz-dati.yml"; ricarica ;;
        3) sed -i 's/query=nginx_http_requests_total/query=rate(nginx_http_requests_total[1m])/' "$W/richieste.sh" ;;
        4) sed -i 's/severity="critico"/severity="critical"/' "$MON/alertmanager/alertmanager.yml"; ricarica ;;
        5) sed -i 's/send_resolved true  /send_resolved: true  /' "$MON/alertmanager/alertmanager.yml"; ricarica ;;
        6) rm -f /etc/nginx/conf.d/zz-scenario.conf; nginx -s reload 2> /dev/null; sleep 2 ;;
        7) curl -s -u admin:laboratorio -X PUT -H 'content-type: application/json' \
               -d '{"name":"Prometheus (prod)","uid":"prometheus-prod","type":"prometheus","access":"proxy","url":"http://prometheus:9090"}' \
               http://grafana:3000/api/datasources/uid/prometheus-prod > /dev/null ;;
        8) sed -i 's/{stato=pagato}/{stato="pagato"}/' "$W/scrivi-metrica.sh" ;;
        *) echo "scenari da 1 a 8" >&2; exit 2 ;;
    esac
}
sbagliata() {
    case $n in
        1) ricarica ;;                                                                                       # ricaricare non corregge la porta
        2) rm -f /dati/riempi.bin ;;                                                                         # il disco si libera, ma la regola resta sbagliata (e ora non c'è nulla da segnalare)
        3) sed -i 's/query=nginx_http_requests_total/query=increase(nginx_http_requests_total[5m])/' "$W/richieste.sh" ;;   # le richieste in 5 minuti, non al secondo
        4) ricarica ;;                                                                                       # ricaricare non corregge il matcher
        5) ricarica ;;                                                                                       # ricaricare un file con un errore: Alertmanager tiene la configurazione di prima
        6) systemctl restart nginx ;;                                                                        # la riga che spegne il log è ancora lì
        7) curl -s -u admin:laboratorio -X DELETE http://grafana:3000/api/datasources/uid/prometheus-prod > /dev/null ;;   # senza data source non c'è niente che risponda
        8) sed -i 's/ 42/ 43/' "$W/scrivi-metrica.sh" ;;                                                     # il valore non c'entra: è l'etichetta senza virgolette
        *) echo "nessun tentativo sbagliato per lo scenario $n" >&2; exit 2 ;;
    esac
}
case $fase in
    risolvi|sbagliata) "$fase" ;;
    *) echo "fasi: risolvi, sbagliata" >&2; exit 2 ;;
esac
