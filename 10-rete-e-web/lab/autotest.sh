#!/usr/bin/env bash
# autotest.sh - prova il verificatore: come risposta a ogni esercizio mette la sua soluzione di riferimento, poi lancia verifica.sh,
# che deve dire OK a tutti. Si lancia da ~/lab/10-esercizi, nel laboratorio 10. Se fallisce è rotto il verificatore, non lo studente.
set -euo pipefail
LAB=${LAB:-/kb/10-rete-e-web/lab}
[[ -d risposte ]] || { echo "lancialo da ~/lab/10-esercizi" >&2; exit 2; }
for i in $(seq 1 16); do
    nn=$(printf '%02d' "$i")
    echo "bash $LAB/soluzioni.sh risolvi $i" > "risposte/$nn.sh"
done
./verifica.sh
