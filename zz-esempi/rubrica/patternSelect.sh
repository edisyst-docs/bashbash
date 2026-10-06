#!/bin/bash
#   patternSelect.sh
#   Riceve una stringa e visualizza in output i record che contengono
#   la stringa (selezione "case insensitive"). Con la stringa vuota li mostra tutti.
RUBRICA=~/rubrica/.rubrica
LABEL=('    Nome' ' Cognome' 'Telefono' '  E-mail')
filtro=$1
# grep -F: la stringa e' testo semplice, non un'espressione regolare; "--" evita che "-x" sia preso per un'opzione
echo "Record selezionati: $(grep -ciF -- "$filtro" "$RUBRICA")"
echo " "
IFS=$'\n'
# ordinamento sul valore del secondo campo (“-k 2”) e il carattere che separa i campi di ogni riga è il pipe (“-t \|”).
# Il backslash serve affinché pipe non venga interpretato come concatenazione di comandi
for record in $(grep -iF -- "$filtro" "$RUBRICA" | sort -t \| -k 2); do
  IFS='|'
  i=0
  for campo in $record; do
    echo "${LABEL[$i]}: $campo"
    ((i++))
  done
  echo " "
done
