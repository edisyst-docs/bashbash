#!/usr/bin/env bash
# 06 - numera.sh: legge lo stdin e stampa ogni riga numerata e in maiuscolo ("1: CIAO"), senza perdere spazi né backslash
n=0
while IFS= read -r riga; do
    n=$((n + 1))
    echo "$n: ${riga^^}"
done
