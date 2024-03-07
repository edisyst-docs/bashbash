#!/usr/bin/bash

# commento purchè non stia nella prima riga

# array classici (indicizzati da numeri) - POSSO NON dichiararli
#declare -a nome_arr2=(19 "pippo" "cane" 23)

#nome_arr1=(19 "pippo" "cane" 23)
#echo ${nome_arr1[0]}
#echo ${nome_arr1[1]}
#echo ${nome_arr1[2]}
#echo ${nome_arr1[3]}
#echo ${nome_arr1[199]}
#
#nome_arr1[2]="altro"
#echo ${nome_arr1[2]}
#
#nome_arr1[199]="posizione strana"
#echo ${nome_arr1[199]}

# array associativi (indicizzati da stringhe) - DEVO dichiararli
declare -A arr_ass1=( ["key1"]="value1" ["key2"]=19 ["key3"]="cane" )
echo ${arr_ass1["key2"]}



