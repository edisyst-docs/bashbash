#!/usr/bin/env bash
# stato.sh URL - stampa "su" se curl riceve 200 dall'indirizzo, altrimenti "giù (CODICE)" ed esce con 1
# Lo script di esempio per i test con un finto curl (stato.bats)
set -u
codice=$(curl -s -o /dev/null -w '%{http_code}' "$1")
if [[ $codice == 200 ]]; then
    echo su
else
    echo "giù ($codice)"
    exit 1
fi
