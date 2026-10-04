#!/bin/bash

# Stampa a video i nomi passati come argomento allo script contenenti lettere minuscole in nomi con tutte le lettere maiuscole.

# es.  >$ toupper pippo Pluto MINNI
#         pippo --> PIPPO
#         Pluto --> PLUTO

# per ogni argomento  ($@ si può omettere)
for f in $@; do
    # considero solo il nome e non eventuali path che lo precedono
    bname=`basename $f`
    # utilizzo tr per trasformare tutti i caratteri minuscoli in maiuscoli
    name=$(echo $bname| tr a-z A-Z)
    # se il nome originale non era tutto maiuscolo lo stampo sullo stdout
    if [ "$name" != "$bname" ]; then
	echo "$bname --> $name"
    fi
done