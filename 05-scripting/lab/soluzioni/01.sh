#!/usr/bin/env bash
# 01 - saluta.sh NOME: stampa "Ciao NOME!"; senza argomenti un messaggio su stderr ed exit 1
[[ $# -ge 1 ]] || { echo "uso: $0 nome" >&2; exit 1; }
echo "Ciao $1!"
