#!/usr/bin/env bash
# autotest.sh - prova il verificatore: come risposta a ogni esercizio mette la sua soluzione di riferimento, poi lancia verifica.sh,
# che deve dire OK a tutti. Si lancia da ~/lab/06-esercizi. Se fallisce è rotto il verificatore (o lo scenario), non lo studente.
set -euo pipefail
LAB=${LAB:-/kb/04-processi/lab}
[[ -d risposte ]] || { echo "lancialo da ~/lab/06-esercizi" >&2; exit 2; }
for i in $(seq 1 16); do
    nn=$(printf '%02d' "$i")
    if (( i == 13 )); then
        bash "$LAB/soluzioni.sh" 13 script > "risposte/$nn.sh"      # è uno script che si avvia da solo
    else
        printf 'bash %s %d\n' "$LAB/soluzioni.sh" "$i" > "risposte/$nn.sh"
    fi
done
./verifica.sh
