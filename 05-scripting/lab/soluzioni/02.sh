#!/usr/bin/env bash
# 02 - pari.sh N: "N è pari" o "N è dispari"; se N non è un intero (anche negativo) un messaggio su stderr ed exit 2
[[ ${1:-} =~ ^-?[0-9]+$ ]] || { echo "non è un intero" >&2; exit 2; }
if (( $1 % 2 == 0 )); then echo "$1 è pari"; else echo "$1 è dispari"; fi
