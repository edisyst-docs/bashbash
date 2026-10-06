#!/bin/bash
#   patternDelete.sh
#   Riceve una stringa ed elimina dall'archivio tutti i record che la contengono
#   (in un campo qualunque, anche come parte di una parola)
RUBRICA=~/rubrica/.rubrica
filtro=$1
if [ -n "$filtro" ]; then
  # grep -F: la stringa e' testo semplice, non un'espressione regolare; "--" evita che "-x" sia preso per un'opzione
  n=$(grep -cF -- "$filtro" "$RUBRICA")
  # grep inverso: salvo su $RUBRICA.new tutte le righe che non contengono $filtro
  grep -vF -- "$filtro" "$RUBRICA" > "$RUBRICA.new"
  mv "$RUBRICA" "$RUBRICA.old"
  mv "$RUBRICA.new" "$RUBRICA"
  echo "Record eliminati: $n"
else
  echo "$0: ERRORE: non e' stato specificato nessun filtro"
  exit 1
fi
