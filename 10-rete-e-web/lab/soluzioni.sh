#!/usr/bin/env bash
# soluzioni.sh FASE N - le soluzioni di riferimento e l'ambiente degli esercizi di 10-esercizi.md (area 10).
#   soluzioni.sh prepara N    porta il sistema nello stato di partenza dell'esercizio N
#   soluzioni.sh risolvi N    la soluzione di riferimento
#   soluzioni.sh controllo N  stampa lo stato che il controllo guarda (vuoto se basta l'output)
#   soluzioni.sh pulisci N    riporta il sistema com'era (indirizzi, rotte, namespace, nginx... toccati dall'esercizio)
# La usa verifica.sh. Gira come root sul container "host" del laboratorio 10: tocca la rete vera del container.
set -uo pipefail
fase=${1:?uso: $0 prepara|risolvi|controllo|pulisci N}
n=${2:?uso: $0 FASE N}

# toglie da nginx ogni file che parla della porta $1 (qualunque nome e cartella abbia scelto lo studente)
togli_nginx() {
    grep -RlE "listen[[:space:]]+(\[::\]:)?$1\b" /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/nginx/sites-available 2> /dev/null | xargs -r rm -f
    # un collegamento in sites-enabled che punta a un file appena tolto resterebbe appeso e farebbe fallire il reload (con la vecchia porta ancora aperta)
    find /etc/nginx/sites-enabled -xtype l -delete 2> /dev/null
    nginx -s reload 2> /dev/null; sleep 0.5      # il segnale, non "systemctl reload": due reload ravvicinati verrebbero fusi e il secondo non partirebbe
}
# /etc/hosts nel container è un file montato da Docker: sed -i non può sostituirlo, si riscrive il contenuto sul posto
togli_da_hosts() {
    local t; t=$(mktemp); grep -v "$1" /etc/hosts > "$t"; cat "$t" > /etc/hosts; rm -f "$t"
}

prepara() { return 0; }
pulisci() {
    case $n in
        4)  ip addr del 10.10.1.50/24 dev eth0 2> /dev/null ;;
        5)  ip link set eth0 mtu 1500 ;;
        6)  ip route del 10.8.0.0/24 2> /dev/null ;;
        7)  ip netns del prova 2> /dev/null; ip link del v0 2> /dev/null ;;
        8)  togli_da_hosts sito.lab ;;
        15) togli_nginx 8081; rm -rf /var/www/miosito ;;
        16) togli_nginx 8082 ;;
    esac
    return 0
}
controllo() {
    case $n in
        4)  ip -4 -o addr show dev eth0 | awk '{print $4}' | sort ;;
        5)  cat /sys/class/net/eth0/mtu ;;
        6)  ip route show 10.8.0.0/24 ;;
        7)  ip netns list | awk '{print $1}'; ip netns exec prova ping -c1 -W1 10.99.0.1 > /dev/null 2>&1 && echo raggiungibile ;;
        8)  getent hosts sito.lab ;;
        15) sleep 1; curl -s --max-time 3 http://localhost:8081/ ;;
        16) sleep 1; curl -s --max-time 3 http://localhost:8082/ ;;
    esac
    return 0
}
risolvi() {
    case $n in
        1)  ipcalc 192.168.37.130/26 | awk '/^Network:/ {split($2, a, "/"); print a[1]} /^Broadcast:/ {print $2}' ;;
        2)  echo $(( 2 ** (32 - 27) - 2 )) ;;
        3)  ipcalc 10.0.0.0/22 | awk '/^Netmask:/ {print $2}' ;;
        4)  ip addr add 10.10.1.50/24 dev eth0 ;;
        5)  ip link set eth0 mtu 1400 ;;
        6)  ip route add 10.8.0.0/24 via 10.10.1.254 ;;
        7)  ip netns add prova
            ip link add v0 type veth peer name v1
            ip link set v1 netns prova
            ip addr add 10.99.0.1/24 dev v0; ip link set v0 up
            ip netns exec prova ip addr add 10.99.0.2/24 dev v1; ip netns exec prova ip link set v1 up ;;
        8)  echo "10.10.2.10 sito.lab" >> /etc/hosts ;;
        9)  traceroute -n web | awk 'NR == 2 {print $2}' ;;
        10) nc -zv -w1 web 20-25 2>&1 | grep succeeded | awk '{print $5}' ;;
        11) curl -s http://web/ ;;
        12) curl -s -o /dev/null -w '%{http_code}\n' http://web/nonesiste ;;
        13) nmap -sn 10.10.1.10-12 | sed -n 's/.*(\([0-9]*\) hosts\? up).*/\1/p' ;;
        14) ip route show default | awk '{print $3}' ;;
        15) mkdir -p /var/www/miosito; echo "ciao dal sito" > /var/www/miosito/index.html
            printf 'server {\n    listen 8081;\n    root /var/www/miosito;\n}\n' > /etc/nginx/conf.d/miosito.conf
            nginx -t 2> /dev/null && systemctl reload nginx ;;
        16) printf 'server {\n    listen 8082;\n    location / {\n        proxy_pass http://web/;\n    }\n}\n' > /etc/nginx/conf.d/proxy.conf
            nginx -t 2> /dev/null && systemctl reload nginx ;;
        *)  echo "esercizi da 1 a 16" >&2; exit 2 ;;
    esac
}
case $fase in
    prepara|risolvi|controllo|pulisci) "$fase" ;;
    *) echo "fasi: prepara, risolvi, controllo, pulisci" >&2; exit 2 ;;
esac
