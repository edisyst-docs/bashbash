#!/usr/bin/env bash
# 14 - riprova.sh N COMANDO...: esegue il comando fino a N volte finché riesce. Stampa "tentativo K" a ogni giro; se riesce "riuscito" ed exit 0, se finisce i tentativi "fallito" ed exit 1
max=$1
shift
for ((t = 1; t <= max; t++)); do
    echo "tentativo $t"
    if "$@"; then echo "riuscito"; exit 0; fi
done
echo "fallito"
exit 1
