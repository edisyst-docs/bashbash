#!/usr/bin/env bash
# 10 - somma-colonna.sh FILE COLONNA: somma (intera) la COLONNA (da 1) di un CSV con intestazione; file mancante: messaggio su stderr ed exit 1
[[ -f ${1:-} ]] || { echo "file mancante" >&2; exit 1; }
s=0
{
    read -r _
    while IFS=, read -r -a c; do
        s=$(( s + c[$2 - 1] ))
    done
} < "$1"
echo "$s"
