#!/bin/bash

#Dato un numero intero in base 10 come input stampa a video il numero in base 2.

# es.  >$ base2.sh 11
#         11 --> 1011
#

# senza questo controllo "base2.sh abc" stamperebbe "abc --> 0" (per bc una parola e' una variabile vuota, cioe' 0)
if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
    echo "ERRORE: usa: $(basename "$0") intero" 1>&2
    exit 1
fi

r=$(echo "obase=2; $1" | bc)
echo "$1 --> $r"
