#!/usr/bin/env bash
# 08 - frequenze.sh FILE: "CONTEGGIO PAROLA" per ogni parola (minuscolo, senza punteggiatura), dalla più frequente; a parità, in ordine alfabetico
declare -A c
while read -r p; do
    c[${p,,}]=$(( ${c[${p,,}]:-0} + 1 ))
done < <(tr -s '[:space:][:punct:]' '\n' < "$1" | grep .)
for p in "${!c[@]}"; do echo "${c[$p]} $p"; done | sort -k1,1nr -k2
