#!/usr/bin/env bash
# lab.sh - apre una shell usa-e-getta con il laboratorio di un'area della KB
#
# Uso: ./lab.sh AREA [--tester] [--build] [-- COMANDO]
#   AREA        numero dell'area (es. 02) o nome della cartella (es. 02-file-e-permessi)
#   --tester    entra come utente tester (password: tester) invece che come root
#   --build     ricostruisce le immagini (bashbash e, dove serve, bashbash-systemd)
#   -- COMANDO  esegue COMANDO dentro il laboratorio ed esce, senza shell interattiva
#
# Il container parte da zero ogni volta: la KB è montata in /kb in SOLA LETTURA, i file
# del laboratorio vengono generati in ~/lab e spariscono all'uscita. Se l'area ha anche un
# lab/compose.yaml (database, API, server con systemd...), i servizi partono con la shell
# e all'uscita vengono eliminati con i loro volumi.
set -euo pipefail

KB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMMAGINE=bashbash

uso() { sed -n '4,8s/^# \{0,1\}//p' "$KB/lab.sh"; }
muori() { echo "ERRORE: $*" >&2; exit 1; }

AREA="" UTENTE=root BUILD=0 COMANDO=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tester)  UTENTE=tester; shift ;;
        --build)   BUILD=1; shift ;;
        -h|--help) uso; exit 0 ;;
        --)        shift; COMANDO="$*"; break ;;
        -*)        uso >&2; muori "opzione sconosciuta: $1" ;;
        *)         AREA="$1"; shift ;;
    esac
done
[[ -n $AREA ]] || { uso >&2; exit 2; }

# 2 => 02 => 02-file-e-permessi
[[ $AREA =~ ^[0-9]+$ ]] && AREA=$(printf '%02d' "$((10#$AREA))")
CARTELLA=$(cd "$KB" && for d in "$AREA" "$AREA"-*; do [[ -d $d ]] && { echo "$d"; break; }; done)
if [[ -z $CARTELLA || ! -f $KB/$CARTELLA/lab/prepara.sh ]]; then
    echo "Aree con un laboratorio:" >&2
    (cd "$KB" && ls -d */lab/prepara.sh | cut -d/ -f1 | sed 's/^/  /') >&2
    muori "nessun laboratorio per '$AREA'"
fi

docker info > /dev/null 2>&1 || muori "Docker non risponde: avvia Docker Desktop (o il demone)"
if (( BUILD )) || ! docker image inspect "$IMMAGINE" > /dev/null 2>&1; then
    docker build -t "$IMMAGINE" "$KB"
fi

# Git Bash su Windows: docker vuole il percorso in formato Windows e MSYS non deve
# convertire i percorsi Linux passati al container (/kb, /root/lab, ...)
MONTAGGIO="$KB"
if command -v cygpath > /dev/null; then
    MONTAGGIO=$(cygpath -w "$KB")
    export MSYS_NO_PATHCONV=1
fi

TTY=(-i)
[[ -t 0 && -t 1 ]] && TTY=(-it)

PREPARA="/kb/$CARTELLA/lab/prepara.sh"
if [[ -n $COMANDO ]]; then
    AVVIO='bash "$LAB_PREPARA" -q "$HOME/lab" && cd "$HOME/lab" && eval "$LAB_COMANDO"'
else
    AVVIO='bash "$LAB_PREPARA" "$HOME/lab" && cd "$HOME/lab" && exec bash'
fi

# Aree con servizi: lab/compose.yaml. Due modi, li sceglie il compose.yaml stesso:
#   - un servizio "shell": compose run lo avvia insieme alle sue dipendenze (area 09)
#   - una riga "x-lab-entra: NOME": tutti i servizi partono con compose up e si entra in NOME con
#     compose exec, perché la shell deve stare nel container dove gira systemd (aree 06, 08, 10)
# All'uscita down -v elimina container, rete e volumi.
COMPOSE="$KB/$CARTELLA/lab/compose.yaml"
if [[ -f $COMPOSE ]]; then
    ENTRA=$(sed -n 's/^x-lab-entra: *\([A-Za-z0-9_-]*\).*/\1/p' "$COMPOSE")
    command -v cygpath > /dev/null && COMPOSE=$(cygpath -w "$COMPOSE")
    compose() { docker compose --progress quiet -f "$COMPOSE" "$@"; }
    trap 'echo "Spengo i servizi del laboratorio..." >&2; compose down -v --remove-orphans > /dev/null 2>&1' EXIT
    [[ ${TTY[0]} == -it ]] && TTY_COMPOSE=() || TTY_COMPOSE=(-T)
    BUILD_COMPOSE=()
    (( BUILD )) && BUILD_COMPOSE=(--build)
    AMBIENTE=(-u "$UTENTE" -e LAB_PREPARA="$PREPARA" -e LAB_COMANDO="$COMANDO" -e TERM="${TERM:-xterm}")
    stato=0
    if [[ -n $ENTRA ]]; then
        echo "Avvio i servizi del laboratorio (la prima volta costruisce le immagini)..." >&2
        compose up -d --wait "${BUILD_COMPOSE[@]}" || muori "i servizi non sono partiti: docker compose -f \"$COMPOSE\" logs"
        compose exec "${TTY_COMPOSE[@]}" "${AMBIENTE[@]}" "$ENTRA" bash -c "$AVVIO" || stato=$?
    else
        compose run --rm "${BUILD_COMPOSE[@]}" "${TTY_COMPOSE[@]}" "${AMBIENTE[@]}" shell bash -c "$AVVIO" || stato=$?
    fi
    exit "$stato"
fi

exec docker run --rm "${TTY[@]}" \
    --hostname "lab-${CARTELLA%%-*}" \
    -u "$UTENTE" \
    -v "$MONTAGGIO:/kb:ro" \
    -e LAB_PREPARA="$PREPARA" \
    -e LAB_COMANDO="$COMANDO" \
    -e TERM="${TERM:-xterm}" \
    "$IMMAGINE" bash -c "$AVVIO"
