#!/bin/bash
#   rubrica.sh
#   Rubrica telefonica interattiva.
#
#   Variabili di configurazione globali
#
RUBRICA=~/rubrica/.rubrica
LABEL=('    Nome' ' Cognome' 'Telefono' '  E-mail')
#
#   Funzione: recordInsert
#   Riceve come argomento nome, cognome, telefono e e-mail
#   e li inserisce in un nuovo record della rubrica
#
function recordInsert {
  nome=$1
  cognome=$2
  telefono=$3
  email=$4
  echo "$nome|$cognome|$telefono|$email" >> $RUBRICA
  echo "Inserito record n. $(wc -l $RUBRICA | cut -c 1-8)"
}
#
#   Funzione: patternDelete
#   Riceve una stringa ed elimina dalla rubrica tutti i record
#   che contengono esattamente quella stringa
#
function patternDelete {
  filtro=$1
  if [ $filtro ]; then
    n=$(grep $filtro $RUBRICA|wc -l)
    grep -v $filtro $RUBRICA > $RUBRICA.new
    mv $RUBRICA $RUBRICA.old
    mv $RUBRICA.new $RUBRICA
    echo "Record eliminati: $n"
  else
    echo "$0: ERRORE: non e' stato specificato nessun filtro"
    exit 1
  fi
}
#
#   Funzione: patternSelect
#   Riceve una stringa e visualizza in output i record che contengono
#   la stringa (selezione "case insensitive")
#
function patternSelect {
  filtro=$1
  echo "Record selezionati: $(grep -i $filtro $RUBRICA | wc -l)"
  echo " "
  IFS=$'\n'
  for record in $(grep -i $filtro $RUBRICA | sort -t \| -k 2); do
    IFS='|'
    i=0
    for campo in $record; do
      echo "${LABEL[$i]}: $campo"
      ((i++))
    done
    echo " "
  done
}
#
#   Procedura principale
#
opt=$1
#   Se viene passata un'opzione sulla riga di comando
#   opera in modalita' batch
if [ $opt ]; then
  case $opt in
    -h)
      echo "Rubrica degli indirizzi"
      echo " "
      echo "Sintassi di utilizzo: $0 [-h|-i|-d|-f] [params]"
      echo " "
      echo "       -h : help"
      echo "       -i : insert ('$0 -i nome cognome telefono e-mail')"
      echo "       -d : delete ('$0 -d pattern')"
      echo "       -f : find ('$0 -f pattern')"
      echo " ";;
    -i)
      recordInsert $2 $3 $4 $5;;
    -d)
      patternDelete $2;;
    -f)
      patternSelect $2;;
    *)
      echo "ERRORE: opzione non prevista";;
  esac
#   Altrimenti visualizza un menu' interattivo
else
  PS3='--> '
  clear
  echo "RUBRICA INDIRIZZI"
  select s in 'Inserimento record' 'Eliminazione record' \
    'Ricerca record' 'Quit'; do
    case $REPLY in
      (1)
        echo " "
        echo "Inserimento nuovo record"
        for (( i=0; i<4; i++)); do
          echo -n "${LABEL[$i]}: "
          read a[$i]
        done
        recordInsert "${a[0]}" "${a[1]}" "${a[2]}" "${a[3]}";;
      (2)
        echo " "
        echo "Eliminazione record"
        echo -n "Inserisci una stringa: "
        read s
        patternDelete $s;;
      (3)
        echo " "
        echo "Ricerca record"
        echo -n "Inserisci una stringa: "
        read s
        patternSelect $s;;
      (4)
        clear
        exit 0;;
      (*)
        echo "Opzione errata";;
    esac
  done
fi

