#!/bin/bash

#Dato un numero intero in base 10 come input stampa a video il numero in base 2.

# es.  >$ base2.sh 11
#         11 --> 1011
#

r=$(echo "obase=2; $1" | bc)
echo "$1 --> $r"