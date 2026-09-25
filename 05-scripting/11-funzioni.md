# Funzioni

Un blocco di comandi con un nome, richiamabile come un comando qualsiasi.
Riceve argomenti come uno script (`$1`, `$#`, `"$@"`) e restituisce un exit status.

## Definire e chiamare
```bash
saluta() {                  # forma POSIX: funziona anche in sh
    echo "Ciao $1"
}
function saluta {           # UGUALE, forma solo bash
    echo "Ciao $1"
}

saluta Mario                # si chiama senza parentesi, come un comando
type saluta                 # mostra il corpo della funzione
declare -F                  # elenca i nomi delle funzioni definite
unset -f saluta             # elimina la funzione
```
> **NOTA**: la funzione deve essere definita PRIMA della riga che la chiama.

## Argomenti
```bash
info() {
    echo "nome funzione: ${FUNCNAME[0]}"   # $0 resta il nome dello SCRIPT, non della funzione
    echo "numero argomenti: $#"
    echo "primo: $1, tutti: $*"
}
info uno "due tre"                        # 2 argomenti: "uno" e "due tre"
```

## Restituire valori
`return` restituisce solo un exit status (0-255), non un dato. Per i dati si usa l'output.
```bash
e_pari() {
    (( $1 % 2 == 0 ))       # l'exit status dell'ultimo comando è il valore di ritorno della funzione
}
if e_pari 4; then echo "pari"; fi

somma() {
    echo $(( $1 + $2 ))     # il "valore" è ciò che la funzione stampa
}
risultato=$(somma 3 4)      # e lo catturo con la command substitution

trova_config() {
    local f
    for f in ./app.conf /etc/app.conf; do
        [[ -f $f ]] && { echo "$f"; return 0; }  # return interrompe la funzione subito
    done
    return 1                                     # nessun file trovato: fallisco
}
conf=$(trova_config) || { echo "config non trovata" >&2; exit 1; }
```

Restituire in una variabile del chiamante senza sottoshell (più veloce, utile nei cicli):
```bash
maiuscolo() {
    local -n _out=$1        # nameref (bash >= 4.3): _out è un alias della variabile il cui nome è in $1
    _out=${2^^}
}
maiuscolo nome "mario"
echo "$nome"                # MARIO
```

## Scope delle variabili
```bash
contatore=0
incrementa() {
    contatore=$((contatore + 1)) # SENZA local: modifica la variabile globale
    local tmp="solo qui"         # CON local: esiste solo dentro la funzione (e nelle funzioni che chiama)
}
incrementa; incrementa
echo "$contatore"                # 2
echo "${tmp:-non definita}"      # non definita
```
> **ATTENZIONE**: `local x=$(comando)` restituisce sempre 0, perché l'exit status è quello di `local`.
> Se serve controllare il comando: `local x; x=$(comando) || return 1`.

## Esempi pratici

### Libreria di funzioni riutilizzabile
File `lib.sh`, da includere in altri script con `source`:
```bash
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
```
Uso:
```bash
#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

richiedi rsync ssh
conferma "Deploy in produzione?" || exit 0
riprova 3 rsync -az ./ deploy@server:/var/www/app/ || die "rsync fallito dopo 3 tentativi"
log "deploy completato"
```

### Funzione ricorsiva: albero di cartelle
```bash
albero() {
    local dir=$1 indent=${2:-}
    local f
    for f in "$dir"/*; do
        [[ -e $f ]] || continue
        echo "${indent}${f##*/}"
        [[ -d $f ]] && albero "$f" "$indent  "   # richiama se stessa con due spazi in più
    done
}
albero ../zz-sandbox/zz_esempi
```

### Funzioni esportate per xargs e find
`xargs` e `find -exec` lanciano processi nuovi, che non vedono le funzioni della shell. Con `export -f` sì:
```bash
ottimizza() {
    echo "elaboro $1"
    # ... es. jpegoptim "$1"
}
export -f ottimizza
find . -name '*.jpg' -print0 | xargs -0 -P4 -I{} bash -c 'ottimizza "$1"' _ {}
```

Vedi anche: [12-trap-e-debug.md](12-trap-e-debug.md) per gestire errori e uscite dentro le funzioni.
