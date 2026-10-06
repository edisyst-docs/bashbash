#!/usr/bin/env bash
# 09 - estensioni.sh DIR: per ogni estensione dei file di DIR (non delle sottocartelle, non nascosti) ".ext CONTEGGIO", in ordine alfabetico; senza estensione "(nessuna)"
declare -A c
for f in "$1"/*; do
    [[ -f $f ]] || continue
    b=${f##*/}
    if [[ $b == *.* ]]; then e=.${b##*.}; else e="(nessuna)"; fi
    c[$e]=$(( ${c[$e]:-0} + 1 ))
done
for e in "${!c[@]}"; do echo "$e ${c[$e]}"; done | sort
