#!/usr/bin/env bash
# autotest.sh - prova il verificatore: come risposta a ogni esercizio mette la sua soluzione di riferimento, poi lancia verifica.sh,
# che deve dire OK a tutti. Si lancia da ~/lab/06-esercizi, nel laboratorio 08. Se fallisce è rotto il verificatore, non lo studente.
set -euo pipefail
LAB=${LAB:-/kb/08-remoto-e-sicurezza/lab}
[[ -d risposte ]] || { echo "lancialo da ~/lab/06-esercizi" >&2; exit 2; }
for i in $(seq 1 22); do
    nn=$(printf "%02d" "$i")
    echo "bash $LAB/soluzioni.sh risolvi $i" > "risposte/$nn.sh"
done
./verifica.sh
