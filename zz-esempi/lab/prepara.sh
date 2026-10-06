#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio di zz-esempi: gli esercizi di scripting e la rubrica
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gli script stanno in /kb/zz-esempi (sola lettura): qui si preparano i file su cui provarli e verifica.sh, che li prova.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
KB_ESEMPI="$(dirname "$LAB_SRC")"                          # zz-esempi/
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

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella

# ---------------------------------------------------------------- esercizi
sezione esercizi
mkdir -p include vuote disco/sub "disco/nome con spazio" rubrica
# include.sh: un sorgente C con include locali e globali, e un commento da non contare
printf '#include <stdio.h>\n#include "prova.h"\n  #  include   <stdlib.h>  \nint main(void) { return 0; }\n// #include <ignorato.h>\n' > include/prova.c
printf '#ifndef PROVA_H\n#define PROVA_H\n#include "altro.h"\n#endif\n' > include/prova.h
echo "niente include" > include/a.txt
echo "int x;" > include/prova.cpp                    # contiene ".c" ma non finisce per .c
# removeblanklines.sh: file con righe vuote (e uno con il nome con uno spazio)
printf 'a\n\nb\n\n\nc\n' > vuote/uno.txt
printf 'x\n\ny\n' > "vuote/con spazio.txt"
# spaziodisco.sh: file e cartelle di dimensioni diverse, anche con uno spazio nel nome
head -c 3000000 /dev/zero > disco/grande
head -c 800000 /dev/zero > "disco/nome con spazio/f"
head -c 200000 /dev/zero > disco/sub/medio
head -c 50000 /dev/zero > disco/piccolo.txt
# la rubrica di partenza, per i test (verifica.sh la copia in una home usa-e-getta)
cp "$KB_ESEMPI/rubrica/.rubrica" rubrica/.rubrica
cp "$LAB_SRC/verifica.sh" .
chmod +x verifica.sh
# collegamenti agli script, per lanciarli da qui: ./base2.sh 11
for f in base2 toupper removeblanklines include spaziodisco; do ln -s "$KB_ESEMPI/esercizi/$f.sh" "$f.sh"; done

# ---------------------------------------------------------------- rubrica
sezione rubrica
ln -s "$KB_ESEMPI/rubrica/rubrica.sh" rubrica.sh
# rubrica.sh cerca i dati in ~/rubrica/.rubrica: la rubrica vera del laboratorio (si può modificare)
mkdir -p "$HOME/rubrica"
cp "$KB_ESEMPI/rubrica/.rubrica" "$HOME/rubrica/.rubrica"

if (( ! SILENZIOSO )); then
    echo "Laboratorio di zz-esempi pronto in $DEST:"
    echo "  esercizi/   dati per i cinque esercizi e verifica.sh (./verifica.sh prova tutto)"
    echo "  rubrica/    ./rubrica.sh per il menu; la rubrica vera è ~/rubrica/.rubrica"
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
