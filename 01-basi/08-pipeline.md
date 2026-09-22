# Pipeline di comandi

La pipe `|` collega lo standard output di un comando allo standard input del successivo.

```bash
cd cartella ; ls        # due distinti comandi: prima va nella cartella, poi esegue ls
ls | tr "AEIOU" "12345" # pipeline: l'output di ls diventa l'input di tr
echo "6+9" | bc         # svolge l'operazione e stampa il risultato
```

## Esempi di filtraggio
```bash
ls | grep "log"                        # filtra i file di log, che si chiamano log_qualcosa
find /cartella -type f | grep "config" # cerca i file nella directory "cartella" e filtra quelli che contengono "config" nel percorso

cd .. ; ls divina_commedia.txt | sort -f | uniq # esempio di sequenza + pipeline
```

## Passare anche lo standard error
```bash
ls  |& tr "AEIOU" "12345"  # ls(output+error) collegato con tr(input)
lss |  tr "AEIOU" "12345"  # dà errore: l'errore non passa nella pipe
lss |& tr "AEIOU" "12345"  # traduce anche l'errore
```
Per il dettaglio sui file descriptor vedi [../02-file-e-permessi/05-redirezioni.md](../02-file-e-permessi/05-redirezioni.md).

## cat: concatenare e scrivere
```bash
cat -n SCRIPT.md           # numera tutte le righe mostrate
cat -b SCRIPT.md           # numera solo le righe non vuote
cat file1 file2 > new_file # concatena la visualizzazione di più file e scrive tutto in new_file
cat file2 >> file1         # appende il contenuto di file2 a file1. Risultato = file1+file2
cat > nuovo_file           # crea nuovo_file e dentro ci scrive ciò che l'utente digita dopo
```

## xargs: trasformare lo stdin in argomenti
`xargs` prende i suoi parametri dallo standard input e li passa come argomenti a un altro comando.
Serve quando il comando di destinazione non legge da stdin (es. `cp`, `rm`, `tar`).
```bash
echo {1..9} | xargs -n4  # processa i parametri 4 alla volta e ne fa un echo

find /etc/ -iname '*.conf' | xargs tar -czvf configs.tar.gz  # scrive tutto in un archivio compresso tar
tar -tf configs.tar.gz | wc -l                               # conto quante righe sono, cioè quanti file
```
