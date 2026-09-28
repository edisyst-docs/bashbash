#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 05: scripting
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Per ogni .md dell'area crea una sottocartella con lo stesso nome, con dentro gli script
# di esempio dell'area e i file che i comandi di quel .md si aspettano di trovare.
# Rilanciarlo riporta tutto allo stato iniziale.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
AREA="$(dirname "$LAB_SRC")"                               # la cartella dell'area, con gli script NN-*.sh
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md
script()  { cp "$AREA/$1" . && chmod +x "$1"; }      # copia uno script di esempio dell'area, eseguibile

# alberatura di cartelle e file vuoti per select, find e la funzione ricorsiva "albero"
esempi() {
    mkdir -p esempi/cart1 esempi/cart2 esempi/cart3/sotto
    touch esempi/cart1/test-{a,b,c,d,e} esempi/cart2/test-{a,b} esempi/cart3/sotto/profondo
    touch esempi/file esempi/prova-{0,1,2}
}

# ---------------------------------------------------------------- 01-basi-scripting
sezione 01-basi-scripting
cat > s.sh << 'EOF'
echo ciao
ls
lss
echo ciao sono il file s.sh
ls -a
EOF
cat > s1.sh << 'EOF'
a="ciao"            # dopo ". s1.sh" questa variabile resta nella shell corrente
variabile="valore"

var=s.sh            # gli faccio stampare il contenuto del file s.sh
cat $var
EOF
printf 'a="ciao"\nps\n' > s2.sh
printf 'echo ${1}\necho ${2}\necho ${3}\necho ${4}\n' > s3.sh
chmod 644 s.sh s1.sh s2.sh s3.sh                     # NON eseguibili: il .md mostra perché serve chmod
cat > scheletro.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="/tmp/$(basename "$0" .sh).log"

log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
muori() { log "ERRORE: $*"; exit 1; }

TMPDIR_LAVORO=$(mktemp -d)
pulizia() { rm -rf "$TMPDIR_LAVORO"; }
trap pulizia EXIT
trap 'muori "comando fallito alla riga $LINENO"' ERR

[[ $# -ge 1 ]] || muori "uso: $(basename "$0") <cartella>"
[[ -d "$1" ]]  || muori "'$1' non è una cartella"

log "inizio elaborazione di $1 (script in $SCRIPT_DIR)"
ls "$1" > "$TMPDIR_LAVORO/elenco"
log "$(wc -l < "$TMPDIR_LAVORO/elenco") elementi in $1"
log "fine"
EOF
chmod +x scheletro.sh
mkdir -p cartella && touch cartella/uno cartella/due

# ---------------------------------------------------------------- 02-variabili
sezione 02-variabili
script 02-variabili.sh
printf 'DB_HOST=10.0.0.9\nDB_PORT=3307\nDB_PASSWORD=segreta\n' > .env
cat > backup.sh << 'EOF'
#!/usr/bin/env bash
: "${DB_HOST:=127.0.0.1}"
echo "backup del database su $DB_HOST"
EOF
chmod +x backup.sh

# ---------------------------------------------------------------- 03-parametri
sezione 03-parametri
cat > opzioni.sh << 'EOF'
#!/usr/bin/env bash
AMBIENTE="staging"
DRY_RUN=0
VERBOSO=0

uso() {
    echo "uso: $(basename "$0") [-e|--env AMBIENTE] [-n|--dry-run] [-v] FILE..."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)     AMBIENTE="$2"; shift 2 ;;
        --env=*)      AMBIENTE="${1#*=}"; shift ;;
        -n|--dry-run) DRY_RUN=1; shift ;;
        -v)           VERBOSO=1; shift ;;
        -h|--help)    uso; exit 0 ;;
        --)           shift; break ;;
        -*)           echo "opzione sconosciuta: $1" >&2; uso >&2; exit 2 ;;
        *)            break ;;
    esac
done

[[ $# -ge 1 ]] || { uso >&2; exit 2; }
echo "ambiente=$AMBIENTE dry_run=$DRY_RUN verboso=$VERBOSO file=$*"
EOF
cat > opzioni-getopts.sh << 'EOF'
#!/usr/bin/env bash
AMBIENTE="staging"
DRY_RUN=0
VERBOSO=0
uso() { echo "uso: $(basename "$0") [-e AMBIENTE] [-n] [-v] FILE..."; }

while getopts ":e:nvh" opt; do
    case "$opt" in
        e) AMBIENTE="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        v) VERBOSO=1 ;;
        h) uso; exit 0 ;;
        :) echo "-$OPTARG richiede un valore" >&2; exit 2 ;;
        ?) echo "opzione sconosciuta: -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
echo "ambiente=$AMBIENTE dry_run=$DRY_RUN verboso=$VERBOSO file=$*"
EOF
chmod +x opzioni.sh opzioni-getopts.sh
touch a.txt b.txt "con spazio.txt"

# ---------------------------------------------------------------- 04-condizioni
sezione 04-condizioni
script 04-condizioni1.sh
script 04-condizioni2.sh
mkdir cartellau
echo 'echo sono s.sh' > s.sh
ln -s s.sh link1
touch vuoto.txt
touch -d '2026-01-01' vecchio.txt
touch nuovo.txt
touch backup_2026-09-25.tar.gz

# ---------------------------------------------------------------- 05-cicli
sezione 05-cicli
script 05-cicli1.sh
script 05-select.sh
esempi
printf 'prima riga\n  seconda, con spazi davanti\nterza con \\ backslash\n' > elenco.txt
mkdir -p foto log src
touch "foto/vacanze al mare.JPG" foto/montagna.JPG foto/gatto.jpg
echo "log a" > log/app.log
echo "log b" > "log/errori di rete.log"
touch src/index.php src/utenti.php src/ordini.php

# ---------------------------------------------------------------- 06-array
sezione 06-array
script 06-array.sh
printf 'mela\npera\nbanana\n' > elenco.txt
printf '%s - - [25/Sep/2026:10:00:00 +0200] "GET / HTTP/1.1" 200 512\n' \
    10.0.0.5 10.0.0.5 192.168.1.20 10.0.0.5 172.16.0.8 192.168.1.20 > access.log
mkdir -p src && touch src/index.php src/utenti.php

# ---------------------------------------------------------------- 07-input-read
sezione 07-input-read
script 07-read1.sh
script 07-read2.sh
printf 'nome,email,ruolo\nmario,mario@example.com,admin\nanna,anna@example.com,editor\n' > utenti.csv

# ---------------------------------------------------------------- 08-espansioni
sezione 08-espansioni
touch "foto delle vacanze.jpg" "report finale.txt" "nota 1.txt" senza_spazi.txt
mkdir -p dir1 dir2
touch dir1/{a,b,c}.txt dir2/{a,c,d}.txt

# ---------------------------------------------------------------- 09-altro-interprete
sezione 09-altro-interprete
script 09-altro_interprete.sh                        # shebang di Git Bash per Windows: qui fallisce, apposta
printf '#!/usr/bin/env python3\nprint("Questo è python")\n' > s4.sh
chmod +x s4.sh

# ---------------------------------------------------------------- 10-quoting
sezione 10-quoting
touch uno.txt due.txt
printf '# titolo\ntesto\n' > leggimi.md
printf '# note\nprima\nseconda\nterza\n' > note.md
mkdir -p "src/cache dir" dst
echo "da copiare" > src/dati.txt
echo "da escludere" > "src/cache dir/tmp.bin"

# ---------------------------------------------------------------- 11-funzioni
sezione 11-funzioni
esempi
cat > lib.sh << 'EOF'
#!/usr/bin/env bash
# lib.sh - funzioni comuni. Uso: source "$(dirname "$0")/lib.sh"

log()  { printf '[%(%F %T)T] %s\n' -1 "$*"; }
warn() { log "WARN: $*" >&2; }
die()  { log "ERRORE: $*" >&2; exit 1; }

richiedi() {                          # verifica che i comandi necessari esistano
    local c mancanti=()
    for c in "$@"; do
        command -v "$c" >/dev/null || mancanti+=("$c")
    done
    (( ${#mancanti[@]} == 0 )) || die "comandi mancanti: ${mancanti[*]}"
}

riprova() {                           # riprova <tentativi> <comando...>: ripete un comando che può fallire
    local max=$1 n=1; shift
    until "$@"; do
        (( n >= max )) && return 1
        warn "tentativo $n/$max fallito: $*"
        sleep $(( n * 2 ))
        (( n++ ))
    done
}

conferma() {                          # conferma "domanda": 0 se l'utente risponde s/si
    local r
    read -r -p "${1:-Continuare?} [s/N] " r
    [[ ${r,,} =~ ^(s|si)$ ]]
}
EOF
echo "porta=8080" > app.conf
mkdir -p img && touch img/a.jpg img/b.jpg img/c.jpg

# ---------------------------------------------------------------- 12-trap-e-debug
sezione 12-trap-e-debug
cat > script.sh << 'EOF'
#!/usr/bin/env bash
# script con qualche difetto voluto: provalo con bash -n, bash -x e shellcheck
deploy() {
    local destinazione=$1
    echo "copio in $destinazione"
    for f in $(ls *.csv); do          # SC2045: non ciclare sull'output di ls
        echo "file: $f"
    done
    cd $destinazione                  # SC2086 e SC2164: niente virgolette e niente controllo su cd
}
deploy /tmp
EOF
cat > trap-err.sh << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERRORE: exit $? alla riga $LINENO: $BASH_COMMAND" >&2' ERR

cp /nonesiste /tmp/
EOF
cat > lock.sh << 'EOF'
#!/usr/bin/env bash
exec 9> /tmp/mio_script.lock
flock -n 9 || { echo "già in esecuzione" >&2; exit 1; }
echo "sono l'unica istanza, lavoro per 10 secondi..."
sleep 10
EOF
cat > interrompi.sh << 'EOF'
#!/usr/bin/env bash
importa() { echo "importo $1..."; sleep 2; }  # finto import lento: premi CTRL+C durante il ciclo

fermati=0
trap 'fermati=1' INT TERM

for f in *.csv; do
    (( fermati )) && { echo "interrotto, ultimo file completato: ${ultimo:-nessuno}"; break; }
    importa "$f"
    ultimo=$f
done
EOF
chmod +x script.sh trap-err.sh lock.sh interrompi.sh
for n in 1 2 3 4 5; do echo "id,valore" > "dati$n.csv"; done

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 05 pronto in $DEST: una cartella per ogni .md"
    ls "$DEST" | sed 's/^/  /'
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
