#!/bin/bash
#   patternDelete.sh
#   Riceve una stringa ed elimina dall'archivio tutti i record che la contengono
RUBRICA=~/rubrica/.rubrica
filtro=$1
if [ $filtro ]; then
  n=$(grep $filtro $RUBRICA|wc -l)
  # grep inverso: salvo su $RUBRICA.new tutte le righe che non contengono $filtro
  grep -v $filtro $RUBRICA > $RUBRICA.new
  mv $RUBRICA $RUBRICA.old
  mv $RUBRICA.new $RUBRICA
  echo "Record eliminati: $n"
else
  echo "$0: ERRORE: non e' stato specificato nessun filtro"
  exit 1
fi