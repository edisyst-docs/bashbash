#!/usr/bin/bash

# commento purchè non stia nella prima riga

# array classici (indicizzati da numeri) - POSSO NON dichiararli
#declare -a nome_arr2=(19 "pippo" "cane" 23)

nome_arr1=(19 "pippo" "cane" 23)

echo ${nome_arr1[0]}
echo ${nome_arr1[1]}
echo ${nome_arr1[2]}
echo ${nome_arr1[3]}
echo ${nome_arr1[19]}


# array associativi (indicizzati da stringhe) - DEVO dichiararli


