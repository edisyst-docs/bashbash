#!/bin/bash

#Data una lista di file testuali in input come argomenti dello script, rimuovere da ogni file le linee vuote.

# se non ci sono argomenti stampo il messaggio di usage
if [ $#  -eq 0 ]; then
    echo "ERRORE: usa: `basename $0` lista-di-file" 1>&2
    exit -1
fi
# per ogni argomento
for file in $@; do
    # controllo che sia un file regolare
    if [ ! -f $file ]; then
	echo "ERRORE, il file $file non esiste o non è un file regolare" 1>&2
	exit 1
    fi
    # controllo che sia scrivibile
    if [ ! -w $file ]; then
	echo "ERRORE, il file $file non e' scrivibile" 1>&2
	exit 2
    fi

    # rimuovo le linee bianche
    # ^ rappresenta l'inizio della linea
    # $ rappresenta la fine della linea
    $(sed -i '/^$/d' $file)

    if [ $? -ne 0 ]; then
	echo "ERRORE nella rimozione delle linee vuote nel file $file" 1>&2
	exit 3
    fi
done