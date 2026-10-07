#!/usr/bin/env bash
# scenari.sh - gli scenari guidati di 11-scenari.md (area 10): un guasto vero sul container "host", da diagnosticare e riparare.
#   scenari.sh guasta N      porta il sistema in perfetta salute, poi lo rompe come descrive lo scenario N e stampa il "ticket"
#   scenari.sh controlla [N] dice se il sintomo è sparito (senza rivelare la causa); N è lo scenario in corso se omesso
#   scenari.sh ripristina    toglie ogni guasto: il sistema torna in salute
# NON si legge prima di aver provato: qui dentro ci sono i guasti. Gira come root sul container "host" del laboratorio 10.
set -uo pipefail
cmd=${1:-}
n=${2:-}
STATO=/run/scenario-in-corso
SITO=/var/www/azienda
NSCENARI=8

[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 10: ./lab.sh 10)" >&2; exit 2; }
getent hosts router > /dev/null && [[ $(hostname) == host ]] || { echo "serve il container host del laboratorio 10" >&2; exit 2; }

# ---------------------------------------------------------------- il sistema in salute
# il riavvio ripetuto di un servizio fa scattare il limite di systemd ("start request repeated too quickly"): lo si azzera
riavvia_nginx() { systemctl reset-failed nginx 2> /dev/null; systemctl restart nginx 2> /dev/null; }
nginx_riparte() {
    riavvia_nginx
    for _ in $(seq 1 20); do curl -s -o /dev/null --max-time 1 http://localhost:8090/ && return 0; sleep 0.25; done
    return 1
}
salute() {
    iptables -F OUTPUT 2> /dev/null
    ip route replace 10.10.2.0/24 via 10.10.1.254
    local t; t=$(mktemp); grep -vE '[[:space:]]web$' /etc/hosts > "$t"; echo "10.10.2.10 web" >> "$t"; cat "$t" > /etc/hosts; rm -f "$t"
    mkdir -p "$SITO"; echo "benvenuti in azienda" > "$SITO/index.html"
    chown -R root:root "$SITO"; chmod 755 "$SITO"; chmod 644 "$SITO/index.html"
    printf 'server {\n    listen 8090;\n    root %s;\n}\n' "$SITO" > /etc/nginx/conf.d/azienda.conf
    printf 'server {\n    listen 8091;\n    location / {\n        proxy_pass http://web/;\n    }\n}\n' > /etc/nginx/conf.d/proxy.conf
    nginx_riparte                                     # prima nginx (libera la 8080 se un tentativo l'aveva presa), poi apache
    systemctl start apache2 2> /dev/null
    rm -f "$STATO"
}

# ---------------------------------------------------------------- i guasti e i loro sintomi
guasta() {
    case $1 in
        1) printf 'server {\n    listen 8090;\n    root %s\n}\n' "$SITO" > /etc/nginx/conf.d/azienda.conf
           riavvia_nginx
           echo "Il sito aziendale (http://localhost:8090/) non risponde più dopo l'ultima modifica alla sua configurazione." ;;
        2) sed -i 's/listen 8090;/listen 8080;/' /etc/nginx/conf.d/azienda.conf
           riavvia_nginx
           echo "Il sito aziendale (http://localhost:8090/) non risponde. Qualcuno ha spostato il sito e riavviato nginx." ;;
        3) ip route del 10.10.2.0/24
           echo "Da questo computer 'curl http://web/' resta appeso: il server web, che prima rispondeva, sembra sparito." ;;
        4) ip route replace 10.10.2.0/24 via 10.10.1.99
           echo "Da questo computer 'curl http://web/' non arriva: il server web, che prima rispondeva, non è più raggiungibile." ;;
        5) local t; t=$(mktemp); grep -vE '[[:space:]]web$' /etc/hosts > "$t"; echo "10.10.2.99 web" >> "$t"; cat "$t" > /etc/hosts; rm -f "$t"
           echo "'curl http://web/' non risponde più. Ma il collega giura che il server web è acceso e che la rete funziona." ;;
        6) sed -i 's#proxy_pass http://web/;#proxy_pass http://web:81/;#' /etc/nginx/conf.d/proxy.conf
           riavvia_nginx
           echo "Il sito sulla 8091 (http://localhost:8091/) è un inoltro verso il server web, e ora risponde con un errore invece della pagina." ;;
        7) iptables -A OUTPUT -d 10.10.2.10 -p tcp --dport 80 -j DROP
           echo "'curl http://web/' resta appeso. Il collega dice: \"ma se faccio ping va tutto!\"" ;;
        8) chmod 700 "$SITO"; chown nobody:nogroup "$SITO"
           echo "Il sito aziendale (http://localhost:8090/) risponde, ma con un errore invece della home page." ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
}

# ---------------------------------------------------------------- i controlli: il sintomo è sparito?
ESITO=0
prova() {       # prova "descrizione" comando...   (stampa OK / ANCORA NO)
    local d=$1; shift
    if "$@" > /dev/null 2>&1; then echo "  OK        $d"; else echo "  ANCORA NO $d"; ESITO=1; fi
}
sito_ok()   { [[ $(curl -s --max-time 3 http://localhost:8090/) == "benvenuti in azienda" ]]; }
apache_ok() { curl -sI --max-time 3 http://localhost:8080/ | grep -qi '^server: apache'; }
web_ok()    { [[ $(curl -s --max-time 3 http://web/) == "risposta da web" ]]; }
proxy_ok()  { [[ $(curl -s --max-time 3 http://localhost:8091/) == "risposta da web" ]]; }
via_router() { ip route get 10.10.2.10 | grep -q 'via 10.10.1.254'; }
nome_ok()   { [[ $(getent hosts web | awk '{print $1}') == 10.10.2.10 ]]; }
nginx_ok()  { systemctl is-active --quiet nginx && nginx -t; }
controlla() {
    case $1 in
        1) prova "nginx è attivo e la sua configurazione è valida" nginx_ok
           prova "il sito risponde sulla 8090 con la sua pagina" sito_ok ;;
        2) prova "nginx è attivo" systemctl is-active --quiet nginx
           prova "il sito risponde sulla 8090 con la sua pagina" sito_ok
           prova "apache2 risponde ancora sulla 8080" apache_ok ;;
        3|4) prova "il traffico verso 10.10.2.10 passa dal router (10.10.1.254)" via_router
           prova "curl http://web/ dà la pagina del server" web_ok ;;
        5) prova "il nome web si risolve nell'indirizzo del server (10.10.2.10)" nome_ok
           prova "curl http://web/ dà la pagina del server" web_ok ;;
        6) prova "nginx è attivo e la sua configurazione è valida" nginx_ok
           prova "http://localhost:8091/ dà la pagina del server web" proxy_ok
           prova "il sito sulla 8090 risponde ancora" sito_ok ;;
        7) prova "curl http://web/ dà la pagina del server" web_ok ;;
        8) prova "il sito risponde sulla 8090 con la sua pagina" sito_ok
           prova "nginx è attivo" systemctl is-active --quiet nginx ;;
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
    ripristina) salute; echo "sistema in salute" ;;
    *) echo "uso: $0 guasta N | controlla [N] | ripristina" >&2; exit 2 ;;
esac
