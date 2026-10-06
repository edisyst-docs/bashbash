#!/usr/bin/env bash
# autotest.sh - prova il verificatore: come risposta a ogni esercizio mette la sua soluzione di riferimento, poi lancia verifica.sh,
# che deve dire OK a tutti. Si lancia da ~/lab/13-esercizi. Se fallisce è rotto il verificatore (o la palestra), non lo studente.
set -euo pipefail
SOL=${SOLUZIONI:-/kb/05-scripting/lab/soluzioni}
[[ -d risposte ]] || { echo "lancialo da ~/lab/13-esercizi" >&2; exit 2; }
for f in "$SOL"/*.sh; do
    n=$(basename "$f")
    printf 'bash %s "$@"\n' "$f" > "risposte/$n"
done
./verifica.sh
