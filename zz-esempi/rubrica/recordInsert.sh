#!/bin/bash
#  recordInsert.sh
#  Riceve 4 argomenti sulla linea di comando: nome, cognome, telefono, e-mail
#  e li inserisce in un nuovo record della rubrica
RUBRICA=~/rubrica/.rubrica
nome=$1
cognome=$2
telefono=$3
email=$4
echo "$nome|$cognome|$telefono|$email" >> $RUBRICA
echo "Inserito record n. $(wc -l $RUBRICA | cut -c 1-8)"