#!/bin/bash

# Realizzare uno script bash che preso come argomento un nome di file (il file può avere solo estensione “.c”o “.h”) verifica se il file contiene include C “locali” (cioè della forma #include “name.h”) e/o include C “globali” (cioe' della forma #include <name.h>).

# es.  >$ include.sh prova.c
#         Il file "prova.c" contiene l'include globale: stdio.h
#         Il file "prova.h" contiene l'include locale:  prova.h

# se non ci sono argomenti stampo il messaggio di usage
if [ $# -eq 0 ]; then
    echo "ERRORE: usa: `basename $0` 'file'" 1>&2
    exit -1
fi
# controllo se il file in ingresso e' un file regolare
if [ ! -f $1 ]; then
    echo "ERRORE: il file $1 non esiste o non è un file regolare" 1>&2
    exit 1
fi

# controllo l'estensione del file (modo 1: utilizzando grep)
r=$(echo $1 | grep "\.[ch]")
if [ "$r" != "$1" ]; then
    echo "ERRORE: il file $1 non ha estensione .c o .h" 1>&2
    exit 2
fi
# controllo l'estensione del file (modo 2: utilizzando le espressioni regolari bash)
if [[ ! $1 =~ .*\.[ch] ]]; then
    echo "ERRORE: il file $1 non ha estensione .c o .h" 1>&2
    exit 2
fi

# per ogni linea verifico se c'e' un match con una espressione regolare bash
while read line; do
    if  [[ $line =~ \ *#\ *include\ *\"(.*)\"\ * ]]; then
	echo "Il file \"$1\" contiene l'include locale:  ${BASH_REMATCH[1]}"
    else
	if [[ $line =~ \ *#\ *include\ *\<(.*)\>\ * ]]; then
	    echo "Il file \"$1\" contiene l'include globale: ${BASH_REMATCH[1]}"
	fi
    fi
done < $1