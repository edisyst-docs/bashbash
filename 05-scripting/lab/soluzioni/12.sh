#!/usr/bin/env bash
# 12 - fattoriale.sh N: stampa N! con una funzione ricorsiva; se N non è un intero >= 0, messaggio su stderr ed exit 1
fatt() {
    local n=$1
    (( n <= 1 )) && { echo 1; return; }
    echo $(( n * $(fatt $((n - 1))) ))
}
[[ ${1:-} =~ ^[0-9]+$ ]] || { echo "serve un intero >= 0" >&2; exit 1; }
fatt "$1"
