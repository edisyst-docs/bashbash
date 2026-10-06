#!/usr/bin/env bash
# 07 - rovescia.sh ARG...: stampa gli argomenti, uno per riga, in ordine inverso
a=("$@")
for ((i = ${#a[@]} - 1; i >= 0; i--)); do echo "${a[i]}"; done
