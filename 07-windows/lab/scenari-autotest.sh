#!/usr/bin/env bash
# scenari-autotest.sh - prova gli scenari di 10-scenari.md: per ognuno rompe il sistema e controlla che "controlla" dica NON RISOLTO,
# prova le scorciatoie sbagliate (non devono bastare), applica la riparazione di riferimento e controlla che dica RISOLTO.
# Si lancia nel laboratorio 07 (pc01). Se fallisce è rotto lo scenario, non lo studente.
set -uo pipefail
LAB=${LAB:-/kb/07-windows/lab}
S="bash $LAB/scenari.sh"
SOL="bash $LAB/scenari-soluzioni.sh"
SBAGLIATE="1 2 3 4 5 6 7 8"        # gli scenari che hanno una scorciatoia sbagliata
fallite=0
atteso() {      # atteso "descrizione" si|no   (esito di "controlla" sullo scenario in corso)
    if $S controlla > /dev/null 2>&1; then r=si; else r=no; fi
    if [[ $r == "$2" ]]; then printf '    ok   %s\n' "$1"; else printf '    ERRORE %s (controlla dice %s)\n' "$1" "$r"; fallite=$((fallite + 1)); fi
}
for n in 1 2 3 4 5 6 7 8; do
    echo "scenario $n"
    $S guasta "$n" > /dev/null
    atteso "dopo il guasto non è risolto" no
    if [[ " $SBAGLIATE " == *" $n "* ]]; then
        $SOL sbagliata "$n" > /dev/null 2>&1
        atteso "la scorciatoia sbagliata non basta" no
        $S guasta "$n" > /dev/null          # si riparte da capo
    fi
    $SOL risolvi "$n" > /dev/null 2>&1
    atteso "dopo la riparazione è risolto" si
done
$S ripristina > /dev/null
echo
if (( fallite )); then echo "$fallite controlli falliti"; exit 1; fi
echo "scenari: tutti i controlli ok"
