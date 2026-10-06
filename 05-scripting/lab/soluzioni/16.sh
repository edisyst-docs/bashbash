#!/usr/bin/env bash
# 16 - args.sh ARG...: stampa "N argomenti:" e poi ogni argomento fra parentesi quadre, uno per riga, anche se contiene spazi o è vuoto
echo "$# argomenti:"
for a in "$@"; do echo "[$a]"; done
