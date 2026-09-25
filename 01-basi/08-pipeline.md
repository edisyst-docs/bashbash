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

### xargs avanzato
```bash
find . -name '*.log' -print0 | xargs -0 -r gzip # -print0/-0 separano con il carattere NUL: gestisce nomi con spazi e a capo
                                                # -r non esegue gzip se find non trova niente
echo a b c | xargs -I{} echo "file: {}.txt"     # -I{} sceglie il placeholder: il comando viene lanciato una volta per elemento
cat urls.txt | xargs -n1 -P8 curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' # 8 curl in parallelo (-P8): status HTTP di una lista di URL
```

## Exit status di una pipeline
Di default l'exit status di una pipeline è quello dell'**ultimo** comando: gli errori a metà si perdono.
```bash
false | true ; echo $?          # 0: il fallimento di false viene nascosto
set -o pipefail                 # da ora la pipeline fallisce se fallisce UN QUALSIASI comando
false | true ; echo $?          # 1
ls /nonesiste | wc -l ; echo "${PIPESTATUS[@]}" # PIPESTATUS contiene l'exit status di ogni comando della pipeline: "2 0"
```

## Esempi pratici
```bash
ps aux --sort=-%mem | head -6                              # i 5 processi che occupano più memoria (+ intestazione)
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn        # quante utenze usano ciascuna shell
ls -1 | sed 's/.*\.//' | sort | uniq -c | sort -rn         # quanti file per estensione nella cartella corrente
tail -f /var/log/nginx/access.log | grep --line-buffered ' 500 ' | tee errori500.log # segue il log in diretta, filtra i 500 e li salva
                                                                                     # --line-buffered: senza, grep bufferizza e tee riceve le righe in ritardo
```
