https://www.youtube.com/watch?v=aghQ6P3Qu3Y

# Esempi

`ps` elenco processi

`nano .bashrc`

`alias x="echo ciao;ls;ls;echo hello" `=> N comandi inline x eseguirli in sequenza

`(ps;ps)` per vedere che ci son 2 PID annidati

`{ ps;ps; }` così c'è un solo PID, un'unica sequenza di processi
- Con le {} bisogna mettere uno spazio all'inizio, uno alla fine che termina con ;

`history`

`CTRL+R` attiva reverse-search, x cercare i comandi

    cmd1 && cmd2
    cmd1 || cmd2

`ls && echo ciao && ls`

`ls && echi ciao && ls`  si và avanti stampando gli errori di ogni comando

`lss || echo ciao || ls`  si và avanti finchè un comando non ha successo


`which ls` dice dove si trova il comando ls, in quale folder

`echo $?`  stampa l'exit status dell'ultimo processo eseguito

    { ls || echo ciao; } && echo finito
    { lss || echo ciao; } && echo finito

`CMD n< file` => LETTURA - aprire il file in lettura; default n=0 

`tr "1234" "abcd"`
`17451235`
`tr "1234" "abcd" < t.txt`

`ls > tt.txt` => SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive completamente

`ls >> tt.txt` => SCRITTURA - stessa cosa ma opera in APPEND

    $ cd /dev/fd
    $ ls -l

# REDIREZIONI
`exec > ~/t.txt`  serve per la redirezione permanente

`exec > /dev/pts/0`  serve per la redirezione permanente

`exec 5>~/t.txt`  creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file

`exec 5<>~/t.txt`  così lo creo sia per LETTURA che SCRITTURA

`exec 5>&-`  chiudo il file descriptor "custom" 5 in SCRITTURA

# PIPELINE
`ls | tr "AEIOU" "12345"`  pipeline di comandi ls(output) è diventato tr(input)

`ls |& tr "AEIOU" "12345"`   ls(output+error) collegato con tr(input)

`lss | tr "AEIOU" "12345"`  dà errore

`lss |& tr "AEIOU" "12345"`   traduce l'errore

# SCRIPTING
Così facendo eseguo il file `s1.sh` e accedo al suo codice, altrimenti $a='' di default

    . s1.sh
    echo $a

./s1.sh => col percorso assoluto ho bisogno dei permessi di esecuzione (es: `chmod 744 s1.sh`)

`. s1.sh` oppure `source s1.sh` si esegue dalla shell bash corrente
 
# VARIABILI
`variabile="valore"` senza nessuno spazio
`declare -i numero=13` se non è stringa lo devo dichiarare: integer
`declare -r costante="ciao"` costante: se le asegno un altro valore ho un errore
`declare -x variabileglobale="globale"` costante: se le asegno un altro valore ho un errore
`export -n variabileglobale` la setta NON PIU' GLOBALE
`declare -a array=[]`
`declare -A arrayassociativo=[]`

`$nomevar`  prendo il valore della variabile
`${nomevar}`  stessa cosa ma è più leggibile in caso di concatenazioni strane
`unset` per settare a NULL una variabile

`export`  mi elenca le variabili globali 

# ALTRO INTERPRETE
`which python` mi dice il percorso di python
`./s4.sh` esegue del python perchè gli ho detto sopra qual è l'interprete da interpellare

# ARRAY
- array classici (indicizzati da numeri) - POSSO NON dichiararli
- array associativi (indicizzati da stringhe) - DEVO dichiararli

# CONDIZIONI
La condizione in 3 modi: `[condizione]` - `[[condizione]]` - `test condizione`
```bash
if condizione
then
    cmd1
    cmd2
fi
```

```
ln -s s.sh link1
ln -s cartella link2
ls -l
```
