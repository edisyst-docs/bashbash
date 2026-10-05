#!/usr/bin/env bash
# saluta.sh - saluta qualcuno. Lo script di esempio per make, shellcheck e bats.
# Uso: saluta.sh [-m|--maiuscolo] [NOME]       (senza NOME: "mondo")
set -euo pipefail

# una funzione per ogni cosa da testare: con "source saluta.sh" i test la chiamano direttamente
saluto() {
    local nome=${1:-mondo}
    printf 'ciao %s\n' "$nome"
}

main() {
    local maiuscolo=0
    while [[ ${1:-} == -* ]]; do
        case $1 in
            -m|--maiuscolo) maiuscolo=1 ;;
            *) echo "opzione sconosciuta: $1" >&2; return 2 ;;
        esac
        shift
    done
    if (( maiuscolo )); then
        saluto "${1:-}" | tr '[:lower:]' '[:upper:]'
    else
        saluto "${1:-}"
    fi
}

# main parte solo se lo script è eseguito, non se è incluso con "source"
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
