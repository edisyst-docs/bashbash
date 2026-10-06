# Pipeline di comandi

> **Laboratorio**: `./lab.sh 01`, poi `cd 08-pipeline`. File pronti: `logs/` (con un nome che contiene uno spazio), `vecchio.bak`, `copia.bak`, `log_a`, `log_b`, `lista_file.txt`, `SCRIPT.md`.

La pipe `|` collega lo standard output di un comando allo standard input del successivo.

```bash
cd cartella ; ls        # due distinti comandi: prima va nella cartella, poi esegue ls
ls | tr "AEIOU" "12345" # pipeline: l'output di ls diventa l'input di tr
echo "6+9" | bc         # svolge l'operazione e stampa il risultato
# 15
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
Con `AEIOU` però **non si vede la differenza**: il messaggio `lss: command not found` è tutto minuscolo, e `tr` non ha niente da cambiare. Per vedere se l'errore passa davvero dalla pipe serve una
traduzione che lo tocchi:
```bash
lss |  tr a-z A-Z
# bash: line 1: lss: command not found       <- l'errore va dritto al terminale, la pipe non lo vede (e tr non stampa nulla)
lss |& tr a-z A-Z
# BASH: LINE 1: LSS: COMMAND NOT FOUND       <- passato dalla pipe, e tradotto
```
`|&` è la forma breve di `2>&1 |`. Per il dettaglio sui file descriptor vedi [../02-file-e-permessi/05-redirezioni.md](../02-file-e-permessi/05-redirezioni.md).

## cat: concatenare e scrivere
```bash
cat -n SCRIPT.md           # numera tutte le righe mostrate
#      1	riga uno
#      2	
#      3	riga tre
cat -b SCRIPT.md           # numera solo le righe non vuote
#      1	riga uno
#
#      2	riga tre
cat file1 file2 > new_file # concatena la visualizzazione di più file e scrive tutto in new_file
cat file2 >> file1         # appende il contenuto di file2 a file1. Risultato = file1+file2
cat > nuovo_file           # crea nuovo_file e dentro ci scrive ciò che l'utente digita dopo (CTRL+D per finire)
```

## xargs: trasformare lo stdin in argomenti
`xargs` prende i suoi parametri dallo standard input e li passa come argomenti a un altro comando.
Serve quando il comando di destinazione non legge da stdin (es. `cp`, `rm`, `tar`).
```bash
find /var/log -name '*.log' | xargs wc -l          # conta le righe di tutti i file di log trovati
find . -name '*.bak' | xargs rm                    # elimina tutti i file .bak trovati da find
cat lista_file.txt | xargs cp -t /backup/          # copia in /backup/ tutti i file elencati nel file di testo
```
Con i file di `08-pipeline`, la prima forma **si rompe sul nome con lo spazio**, perché `xargs` separa gli argomenti sugli spazi:
```bash
find logs -name '*.log' | xargs wc -l
# wc: logs/errori: No such file or directory
# wc: vecchi.log: No such file or directory
#  2 logs/app.log
#  2 total
```

### xargs avanzato
```bash
find . -name '*.log' -print0 | xargs -0 -r gzip   # -print0/-0 separano con NUL: gestisce nomi con spazi
                                                   # -r non esegue gzip se find non trova niente

find . -name '*.php' -print0 | xargs -0 grep -l 'eval('  # trova i file PHP che contengono eval(): cerca su tutti i file senza aprire una shell per ognuno

cat server.txt | xargs -I{} ssh {} 'df -h /'       # -I{} lancia il comando una volta per host: spazio disco su ogni server in lista

cat urls.txt | xargs -n1 -P8 curl -s -o /dev/null -w '%{http_code} %{url_effective}\n'  # 8 curl in parallelo (-P8): status HTTP di una lista di URL
```
Lo stesso `wc` con `-print0` / `-0`:
```bash
find logs -name '*.log' -print0 | xargs -0 -r wc -l
#  1 logs/errori vecchi.log
#  2 logs/app.log
#  3 total
```
(`ssh` e `curl` verso host esterni non sono stati provati nel laboratorio.)

## Exit status di una pipeline
Di default l'exit status di una pipeline è quello dell'**ultimo** comando: gli errori a metà si perdono.
```bash
false | true ; echo $?          # 0: il fallimento di false viene nascosto
set -o pipefail                 # da ora la pipeline fallisce se fallisce UN QUALSIASI comando
false | true ; echo $?          # 1
ls /nonesiste | wc -l ; echo "${PIPESTATUS[@]}" # PIPESTATUS contiene l'exit status di ogni comando della pipeline: "2 0"
```
(`PIPESTATUS` va letto **subito**, nel comando dopo: ogni comando lo sovrascrive. `set +o pipefail` lo spegne.)

## Esempi pratici
```bash
ps aux --sort=-%mem | head -6                              # i 5 processi che occupano più memoria (+ intestazione)
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn        # quante utenze usano ciascuna shell
# 21 /usr/sbin/nologin
#  3 /bin/bash
#  1 /bin/sync
ls -1 | sed 's/.*\.//' | sort | uniq -c | sort -rn         # quanti file per estensione nella cartella corrente
tail -f /var/log/nginx/access.log | grep --line-buffered ' 500 ' | tee errori500.log # segue il log in diretta, filtra i 500 e li salva
                                                                                     # --line-buffered: senza, grep bufferizza e tee riceve le righe in ritardo
```
Nel `ls -1 | sed ...` un file **senza** estensione non ha nessun punto da togliere: `sed` lascia tutto il nome, e il file finisce nel conteggio come se il nome fosse l'estensione.
