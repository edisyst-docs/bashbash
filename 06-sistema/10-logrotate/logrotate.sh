#!/bin/bash
#  logrotate.sh
#
#  Esempio banale. Rinomina tutti i log della directory $LOGDIR il cui nome corrisponde con $LOGNAME:
#  viene eliminato il file piu' vecchio (ultimo della coda) creando un nuovo file vuoto all'inizio della coda.
#
#  Nell'esempio esiste un log in /tmp/mylog e logrotate.sh sposta ogni volta
#  il log “mylog” nel file “mylog.0.gz” e crea un nuovo file vuoto “mylog”.
#  La volta dopo sposta “mylog.0.gz” in “mylog.1.gz”, poi “mylog” in “mylog.0.gz” e crea un nuovo file vuoto “mylog”

#
#  Variabili di configurazione dello script
#
LOGDIR='/tmp'
LOGNAME='mylog'
LOGRETENTION=7       # saranno conservati fino a 8 archivi: da 0 a 7
GZIP='/usr/bin/gzip' # utility usata per comprimere i log "vecchi"
#
#  Verifica che LOGDIR sia una directory e che io abbia il permesso write su di essa
#
if [[ ! -d "$LOGDIR" ]] ; then
  echo "$0: ERRORE: la directory $LOGDIR non esiste."
  exit 1
fi
if [[ ! -w "$LOGDIR" ]] ; then
  echo "$0: ERRORE: non puoi modificare il contenuto della \
    directory $LOGDIR."
  exit 1
fi
#
#  Eliminazione del log piu' vecchio e spostamento dei log file
#  piu' recenti
#
for (( i=LOGRETENTION ; i>0; i-- )); do
  ((j=i-1))
  if [[ -e $LOGDIR/$LOGNAME.$j.gz ]] ; then
    if [[ -w $LOGDIR/$LOGNAME.$j.gz && \
      (-w $LOGDIR/$LOGNAME.$i.gz || ! -e $LOGDIR/$LOGNAME.$i.gz) ]]
    then
      mv $LOGDIR/$LOGNAME.$j.gz $LOGDIR/$LOGNAME.$i.gz
    else
      echo "$0: ERRORE: non e' possibile ruotare \
        $LOGDIR/$LOGNAME.$j.gz in $LOGDIR/$LOGNAME.$i.gz"
      exit 1
    fi
  fi
done
#
#  Spostamento e compressione del log piu' recente e creazione di un
#  nuovo log file vuoto
#
mv $LOGDIR/$LOGNAME $LOGDIR/$LOGNAME.0
touch $LOGDIR/$LOGNAME
$GZIP $LOGDIR/$LOGNAME.0
