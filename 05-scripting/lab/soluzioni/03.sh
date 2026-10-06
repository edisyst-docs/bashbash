#!/usr/bin/env bash
# 03 - somma.sh N...: stampa la somma degli argomenti (0 se non ce ne sono)
s=0
for n in "$@"; do s=$((s + n)); done
echo "$s"
