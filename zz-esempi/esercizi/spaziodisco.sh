#!/bin/bash

# Data un nome di directory come argomento dello script, stampare sullo standard output la lista ordinata in modo decrescente (in base alla size) dei file/directory contenuti nella directory passata allo script, il tipo del file (F per file e D per directory) e la size in formato human readable.
# Es: ./spaziodisco.sh /home

if [[ $# != 1 ]]; then
    echo "usa:" 1>&2
    echo "  `basename $0` directory" 1>&2
    exit 1
fi

if [ ! -d $1 ]; then
    echo "ERROR: $1 non è una directory" 1>&2
    exit 2
fi
if [ ! -r $1 ]; then
    echo "ERROR: la directory $1 non è leggibile" 1>&2
    exit 3
fi

# togliamo lo slash finale se c'e' (canonizzare)
# from http://tldp.org/LDP/abs/html/parameter-substitution.html
# ${var%Pattern}
# Remove from $var the shortest part of $Pattern that matches the back end of $var.
startdir=${1%/}

# creo una lista contenente l'output del comando du + sort
# sort -h ordina aspettandosi numeri in formato human readable 10K, 2G.....
data=( $(du -sh $startdir/* 2> /dev/null | sort -hr) )
# prendo il numero totale di elementi dalla lista
ndata=${#data[@]}

#scorro la lista prendendo le coppie <size, /startdir/dir>
for((i=0;i<((ndata-1));i+=2)); do
    # suppongo che per default sia un file
    type=F
    # e' una directory ?
    if [ -d ${data[i+1]} ]; then
	type=D
    fi
    # prendo solo il nome
    name=`basename ${data[i+1]}`
    # faccio la stampa formattata usando printf (C-style)
    printf "%-30s\t%2s\t%-10s\n" $name $type ${data[i]}
done