#!/usr/bin/env bash
# 15 - esiste.sh PERCORSO: un file regolare stampa "file" (exit 0), una cartella "directory" (exit 1), altrimenti un messaggio su stderr ed exit 2
p=${1:-}
if [[ -f $p ]]; then
    echo file
elif [[ -d $p ]]; then
    echo directory
    exit 1
else
    echo "non esiste: $p" >&2
    exit 2
fi
