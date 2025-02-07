#!/bin/bash
#   patternSelect.sh
#   Riceve una stringa e visualizza in output i record che contengono
#   la stringa (selezione "case insensitive")
RUBRICA=~/rubrica/.rubrica
LABEL=('    Nome' ' Cognome' 'Telefono' '  E-mail')
filtro=$1
echo "Record selezionati: $(grep -i $filtro $RUBRICA | wc -l)"
echo " "
IFS=$'\n'
# ordinamento sul valore del secondo campo (“-k 2”) e il carattere che separa i campi di ogni riga è il pipe (“-t \|”).
# Il backslash serve affinchè pipe non venga interpretato come concatenazione di comandi
for record in $(grep -i $filtro $RUBRICA | sort -t \| -k 2); do
  IFS='|'
  i=0
  for campo in $record; do
    echo "${LABEL[$i]}: $campo"
    ((i++))
  done
  echo " "
done