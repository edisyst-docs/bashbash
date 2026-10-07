#!/usr/bin/env bash
# scenari-soluzioni.sh FASE N - le riparazioni di riferimento degli scenari di 11-scenari.md (area 10), e alcune "scorciatoie"
# che sembrano ripararli ma non lo fanno (servono a provare che scenari.sh controlla non si lascia ingannare).
#   scenari-soluzioni.sh risolvi N     la riparazione giusta
#   scenari-soluzioni.sh sbagliata N   un tentativo che non basta (non esiste per tutti gli scenari)
# La usa scenari-autotest.sh. Gira come root sul container "host" del laboratorio 10.
set -uo pipefail
fase=${1:?uso: $0 risolvi|sbagliata N}
n=${2:?uso: $0 FASE N}

risolvi() {
    case $n in
        1) sed -i 's#^    root /var/www/azienda$#    root /var/www/azienda;#' /etc/nginx/conf.d/azienda.conf
           systemctl reset-failed nginx; systemctl restart nginx ;;
        2) sed -i 's/listen 8080;/listen 8090;/' /etc/nginx/conf.d/azienda.conf
           systemctl reset-failed nginx; systemctl restart nginx ;;
        3) ip route add 10.10.2.0/24 via 10.10.1.254 ;;
        4) ip route replace 10.10.2.0/24 via 10.10.1.254 ;;
        5) t=$(mktemp); sed 's/^10\.10\.2\.99\([[:space:]]\+web\)$/10.10.2.10\1/' /etc/hosts > "$t"; cat "$t" > /etc/hosts; rm -f "$t" ;;   # /etc/hosts è montato da Docker: sed -i non può sostituirlo
        6) sed -i 's#proxy_pass http://web:81/;#proxy_pass http://web/;#' /etc/nginx/conf.d/proxy.conf
           nginx -s reload; sleep 1 ;;
        7) iptables -D OUTPUT -d 10.10.2.10 -p tcp --dport 80 -j DROP ;;
        8) chown root:root /var/www/azienda; chmod 755 /var/www/azienda ;;
        *) echo "scenari da 1 a 8" >&2; exit 2 ;;
    esac
}
sbagliata() {
    case $n in
        1) rm -f /etc/nginx/conf.d/azienda.conf; systemctl reset-failed nginx; systemctl restart nginx ;;                    # nginx riparte, ma il sito non c'è più
        2) systemctl stop apache2; systemctl reset-failed nginx; systemctl restart nginx ;;                                  # nginx riparte sulla 8080, ma la 8090 resta chiusa e apache è spento
        3) ip route add 10.10.2.0/24 via 10.10.1.1 ;;                                          # la rotta c'è, ma passa dal gateway sbagliato
        5) echo "10.10.2.10 web" >> /etc/hosts ;;                                              # la riga giusta in fondo: vince la prima, quella sbagliata
        6) sed -i 's#proxy_pass http://web:81/;#proxy_pass http://127.0.0.1:8090/;#' /etc/nginx/conf.d/proxy.conf
           nginx -s reload; sleep 1 ;;                                                         # risponde, ma è la pagina di un altro sito (il sito aziendale), non quella del server web
        7) iptables -A OUTPUT -d 10.10.2.10 -p tcp --dport 80 -j ACCEPT ;;                     # l'ACCEPT in fondo non serve: il DROP viene prima
        8) chmod 644 /var/www/azienda/index.html ;;                                            # il file era già leggibile: è la cartella che blocca
        *) echo "nessun tentativo sbagliato per lo scenario $n" >&2; exit 2 ;;
    esac
}
case $fase in
    risolvi|sbagliata) "$fase" ;;
    *) echo "fasi: risolvi, sbagliata" >&2; exit 2 ;;
esac
