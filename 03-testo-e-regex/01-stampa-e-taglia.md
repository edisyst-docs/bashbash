# Stampare, ordinare, tagliare e splittare file

## Visualizzare porzioni di file
```bash
head file       # mostra le prime  10 righe del file
head -n 3 file  # mostra le prime  3  righe del file
tail file       # mostra le ultime 10 righe del file
tail -n 3 file  # mostra le ultime 3  righe del file

tail -f file_5000                # mostra la coda ma non esce: se il file viene modificato lo vedo in tempo reale (utile per i log)
tail -f file_5000 | grep 'error' # UGUALE, ma greppato

tail ciao addio    # funziona anche su più file insieme
tail -f ciao addio # funziona anche su più file insieme

nl divina_commedia.txt # UGUALE a cat, ma aggiunge gli indici di riga
pr file_5000           # stampa con la paginazione, pronto per la stampa

less divina  # dentro posso fare /non e mi evidenzia tutte le stringhe "non"
more divina  # UGUALE ma ha meno funzionalità di less
```

## sort: ordinare
```bash
sort    file # ordina alfabeticamente le righe del file
sort -r file # ordine alfabetico INVERSO
sort -R file # ordine RANDOM
sort -n file # ordine numerico (1,2,3,10,20,23 - altrimenti sarebbe stato 1,10,2,20,23)

sort -u file        # ordine alfabetico + elimina i doppioni
sort    file | uniq # UGUALE. NOTA: uniq da solo elimina i doppioni SOLO SE CONSECUTIVI
```

```bash
sort phonebook           # ordina alfabeticamente in base al primo campo (il nome)
sort phonebook | uniq    # UGUALE, ma elimina dall'output le righe duplicate
sort phonebook | uniq -d # ESATTAMENTE OPPOSTO: ora uniq stampa solo le righe duplicate
sort phonebook -k 2      # ordina in base al secondo campo (il cognome)

sort -t ":" -k 2 file       # ordina in base al secondo campo, separando i campi di ogni riga coi :
du -s /cartella/* | sort -n # ordina le righe per NUMERO
ls -l | sort -k9 -r         # ordine inverso per l'output di "ls -l"
```

## paste: affiancare righe e colonne
```bash
paste ciao        # uguale a cat
paste ciao -s     # scrive tutte le righe in 1 unica riga, separandole con un TAB
paste ciao -s -d, # scrive tutte le righe in 1 unica riga, separandole con la virgola

cat file_5000 | paste - -              # stampa su 2 colonne
cat file_5000 | paste - - -d,          # UGUALE ma separa con le virgole
cat file_5000 | paste - - -            # stampa su 3 colonne
head -n 50 file_5000 | paste - - - -d,: # stampa su 3 colonne e ogni riga è A,B:C
```

## awk: estrarre colonne
```bash
awk -F: '{ print $1 }' /etc/passwd  # stampa la prima colonna di un file coi campi separati dai :
awk -F ';' '{print $1}' file.csv    # stampa la prima colonna di un file CSV (non funziona con XLSX)
awk -F\;   '{print $1}' file.csv    # UGUALE, si può scrivere anche così
```

## tr: tradurre ed eliminare caratteri
```bash
tr  a-z A-Z        # se digito "cane" mi scrive "CANE"
tr 'r' 'R' < t.txt # legge dal file e stampa a video sostituendo quel carattere
tr -d 'ar'         # legge dallo stdin e stampa eliminando quei caratteri
tr -dc 'ar'        # complementare al precedente: elimina tutto tranne quei caratteri

cat t.txt | tr [:lower:] [:upper:]             # rende tutto il testo da lowercase a uppercase
cat t.txt | tr [:lower:] [:upper:] > UPPER.txt # lo scrivo dentro un file nuovo
```

## cut: tagliare colonne
```bash
echo "il comando cut serve a ritagliare l'output dai programmi
il termine cut significa proprio tagliare
da non confondere con cat!
il comando cat serve invece a concatenare più file" > cut-example.txt

cut -c12    cut-example.txt # stampa il carattere nella colonna 12 di ogni riga del file
cut -c12-15 cut-example.txt # ritaglia tutte le righe e stampa le colonne 12-13-14-15
cut -c12-   cut-example.txt # ritaglia tutte le righe e stampa le colonne dalla 12 fino alla fine
cut -c-12   cut-example.txt # ritaglia tutte le righe e stampa le colonne dall'inizio alla 12
```

### Tagliare per campo, con un delimitatore
```bash
cut -d ':' -f 1 /etc/passwd            # usa i : come delimitatore e stampa il 1° campo (field)
cat /etc/passwd | cut -d':' -f1        # UGUALE
cut -d ':' -f 1,7 /etc/passwd          # UGUALE, ma stampa i campi 1 e 7
cut -d ':' -f 2-5 /etc/passwd          # UGUALE, ma stampa i campi dal 2 al 5
cat /etc/passwd | cut -d':' -f1 | sort # UGUALE, ma li ordina anche alfabeticamente

cut -d':' -s -f1 /etc/passwd           # stampa il 1° campo solo per le righe dove trova il separatore
cut -d':' -f7 --complement /etc/passwd # stampa tutti i campi TRANNE il 7°

cut -d':' -f1,7 --output-delimiter='#'  /etc/passwd # stampa f1 ed f7 delimitandoli col # al posto del :
cut -d':' -f1,7 --output-delimiter=$'\n' /etc/passwd # stampa f1 ed f7 e li delimita andando a capo
```

## split: spezzare un file in più parti
```bash
for l in $(seq 5000) ; do
  echo "riga numero $l" >> file_5000
done

wc -l file_5000      # ha effettivamente 5000 righe
wc -l *              # fa la stessa cosa su tutti i file della cartella corrente

split file_5000      # di default spezza ogni 1000 righe
cat xa* > nuovo_file # ESCAMOTAGE PER VERIFICARE

split file_5000 -l 500 text_splitted_ # ora spezza ogni 500 righe e i chunk si chiameranno text_splitted_aa, _ab, _ac

split -b 5m video.mp4  # splitta un file BINARIO in blocchi da 5 Mega
cat video* > unito.mp4 # ESCAMOTAGE PER VERIFICARE
```
> **NOTA**: lo stesso si potrebbe fare sui file di testo, ma per quelli è più comodo splittarli
> in N file che restino leggibili, cioè per numero di righe.

Vedi anche: [02-grep.md](02-grep.md) per filtrare, [04-sed.md](04-sed.md) per trasformare.
