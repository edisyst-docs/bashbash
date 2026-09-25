# Parametri speciali

```bash
$0 # nome dello script eseguito
$1 # primo argomento dello script. A seguire $2, $3, ecc.
$# # numero degli argomenti passati allo script
$* # tutti gli argomenti come una singola stringa: "$*" equivale a "$1 $2 $3"
$@ # SIMILE, ma ogni argomento resta una stringa separata: "$@" equivale a "$1" "$2" "$3"

$$ # PID dello script in esecuzione
$! # PID dell'ultimo comando eseguito in background. Es: dopo "sleep 10 &", $! è il PID di sleep
$? # exit status dell'ultimo comando eseguito: 0 vuol dire SUCCESS
```

> **NOTA**: la differenza tra `"$*"` e `"$@"` conta solo quando sono fra doppi apici.
> Con `"$@"` un argomento che contiene spazi resta un argomento solo; con `"$*"` viene
> tutto appiattito in un'unica stringa.

Esempio pratico in [07-read2.sh](07-read2.sh).

## Esempi pratici
```bash
echo "${@: -1}"      # ULTIMO argomento (lo spazio prima del - è obbligatorio)
echo "${@:2}"        # tutti gli argomenti dal secondo in poi
shift                # scarta $1: $2 diventa $1, $3 diventa $2, ecc. ($# cala di 1)
shift 2              # scarta i primi 2
set -- a b c         # sostituisce i parametri posizionali: ora $1=a, $2=b, $3=c (utile per i test)
```

### Parsing di opzioni con un ciclo
Gestisce opzioni corte e lunghe, con e senza valore, in qualunque ordine.
```bash
#!/usr/bin/env bash
AMBIENTE="staging"
DRY_RUN=0
VERBOSO=0

uso() {
    echo "uso: $(basename "$0") [-e|--env AMBIENTE] [-n|--dry-run] [-v] FILE..."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)     AMBIENTE="$2"; shift 2 ;;   # opzione con valore: consumo 2 argomenti
        --env=*)      AMBIENTE="${1#*=}"; shift ;; # forma --env=prod: tolgo tutto fino all'uguale
        -n|--dry-run) DRY_RUN=1; shift ;;
        -v)           VERBOSO=1; shift ;;
        -h|--help)    uso; exit 0 ;;
        --)           shift; break ;;             # "--" = fine delle opzioni, il resto sono file
        -*)           echo "opzione sconosciuta: $1" >&2; uso >&2; exit 2 ;;
        *)            break ;;                    # primo argomento non-opzione: stop
    esac
done

[[ $# -ge 1 ]] || { uso >&2; exit 2; }
echo "ambiente=$AMBIENTE dry_run=$DRY_RUN verboso=$VERBOSO file=$*"
```

### Stessa cosa con getopts (solo opzioni corte)
`getopts` è un builtin: gestisce da solo le opzioni raggruppate come `-nv`.
```bash
while getopts ":e:nvh" opt; do   # ":" iniziale = gestisco io gli errori; "e:" = -e vuole un valore
    case "$opt" in
        e) AMBIENTE="$OPTARG" ;;  # il valore dell'opzione è in OPTARG
        n) DRY_RUN=1 ;;
        v) VERBOSO=1 ;;
        h) uso; exit 0 ;;
        :) echo "-$OPTARG richiede un valore" >&2; exit 2 ;;
        ?) echo "opzione sconosciuta: -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))            # tolgo le opzioni già lette: in "$@" restano solo gli argomenti
```
