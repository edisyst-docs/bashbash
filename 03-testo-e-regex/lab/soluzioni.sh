#!/usr/bin/env bash
# soluzioni.sh N - la soluzione di riferimento dell'esercizio N di 06-esercizi.md: stampa il risultato atteso.
# La usa verifica.sh per confrontarlo con quello delle risposte in risposte/NN.sh. Si lancia dalla cartella ~/lab/06-esercizi.
set -euo pipefail
case ${1:?uso: $0 N} in
    1)  grep -c '" 404 ' access.log ;;
    2)  awk '{print $1}' access.log | sort -u | wc -l ;;
    3)  awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -2 | awk '{print $2, $1}' ;;
    4)  awk '$9 == 200 {s += $10} END {print s}' access.log ;;
    5)  awk '{print $7}' access.log | sort -u ;;
    6)  awk '{c[substr($4, 14, 5)]++} END {for (m in c) print m, c[m]}' access.log | sort ;;
    7)  awk -F, 'NR > 1 {s += $4 * $5} END {printf "%.2f\n", s}' vendite.csv ;;
    8)  awk -F, 'NR > 1 {s[$2] += $4 * $5} END {for (n in s) printf "%s %.2f\n", n, s[n]}' vendite.csv | sort ;;
    9)  awk -F, 'NR > 1 {q[$3] += $4} END {for (p in q) print q[p], p}' vendite.csv | sort -rn | head -1 | cut -d' ' -f2 ;;
    10) sed -e '/^[;#]/d' -e '/^$/d' app.ini ;;
    11) sed '/^\[app\]/,/^\[/ s/^debug = true/debug = false/' app.ini ;;
    12) grep -Eo '[A-Za-z0-9._-]+@[A-Za-z0-9-]+(\.[A-Za-z]+)+' contatti.txt ;;
    13) sed -n 's/.*tel: //p' contatti.txt | tr -d ' -' | grep '^3' ;;
    14) awk -F: '$7 == "/bin/bash" {print $1 ":" $6}' passwd.txt | sort ;;
    15) awk -F: '$3 >= 1000 && $3 < 60000 {print $3, $1}' passwd.txt | sort -n | tail -1 | cut -d' ' -f2 ;;
    16) sed -n '/START/,/END/{//!p}' note.txt ;;
    17) awk '$9 == 500 || $9 == 503 {print $1}' access.log | sort -u ;;
    18) awk '$10 > 49000 {print $7, $10}' access.log | head -3 ;;
    *)  echo "esercizi da 1 a 18" >&2; exit 2 ;;
esac
