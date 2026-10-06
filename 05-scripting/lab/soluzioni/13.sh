#!/usr/bin/env bash
# 13 - temp.sh [errore]: crea una cartella temporanea con mktemp -d, ci scrive un file e stampa "fatto". Con l'argomento "errore" un comando
# fallisce a metà (set -e). Qualunque sia l'esito, la cartella temporanea deve sparire.
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
echo dati > "$d/dati"
if [[ ${1:-} == errore ]]; then false; fi
echo fatto
