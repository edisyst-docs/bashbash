## FILE
```bash
file -i CRONTAB.md   # mi dice il MIME type del file
file file1.txt       # mi dice il tipo di file (ASCII text)
file *               # mi dice il tipo di file di tutti quelli in cartella

touch pippo_{1,2,3}  # crea pippo_1, pippo_2, pippo_3 
touch pippo_{01..12} # crea pippo_01, pippo_02, ..., pippo_12

cp origine destinazione
cp -i origine destinazione             # chiede conferma in caso di overwriting
cp file1.txt file2.txt                 # fa una copia file1 e la chiama file2
cp file1.txt /percorso/directory/      # copia file1 dentro la cartella /directory/
cp -r directory1 /percorso/directory2/ # copia la directory1 dentro la cartella directory2

mkdir dir1 dir2 dir3
mkdir -p progetti/2024/giugno   # per crearle già annidate
mkdir -m 700 dir_privata        # specifico i permessi in creazione
rmdir directory_vuota           # la directory dev'essere vuota per poterla eliminare
rmdir -p genitore/figlio/nipote # ricorsivo, ma devono essere tutte vuote
rm        directory_vuota       # rimuove singoli file
rm -r directory_non_vuota       # rimuove directory NON VUOTE, anche ricorsivamente
rm -i directory_non_vuota       # chiede conferma prima di rimuovere ogni file

shred pippo_01    # sovrascrive in modo illeggibile il file. Meglio che eliminarlo, perchè si potrebbe ripristinare
shred -u pippo_01 # sovrascrive in modo illeggibile il file e lo elimina pure

tar -cvf archivio.tar file1 file2                 # c:crea un file archivio.tar contenente file1, file2
tar -xvf archivio.tar /destinazione               # x:estrae (in una cartella specifica) il contenuto di archivio.tar
tar -cvf archivio.tar file1 file2 directory1      # crea archivio contenente sia file che directory
tar -cvzf compresso.tar.gz file1 file2 directory1 # comprime l'archivio utilizzando gzip (-z), bzip2 (-j), o xz (-J):
tar -xvzf compresso.tar.gz                        # estrae un archivio compresso di tipo tar.gz 

sort file.txt     # riordina in ordine alfabetico le righe dei file.txt
sort -r file.txt  # riordina in ordine alfabetico inverso
sort -R file.txt  # ordine alfabetico RANDOMICO

sort phonebook                  # ordina alfabeticamente le righe del file phonebook (in base al nome)
sort phonebook -k 2             # ordina alfabeticamente ma in base al secondo campo (in base al cognome)
du -s /home/edoardo/* | sort -n # ordina le righe per NUMERO

find ./ -name "long.txt" # cerca un file chiamato long.txt nella cartella corrente
find ./ -type f -name "*.py" ./get_keys.py ./github_automation.py ./binarysearch.py # cerca i file con estensione .py 
find . -maxdepth 3 -type d # cerca nella cartella corrente solo le directory, scendendo fino a 3 sottolivelli
find /lib/modules/$(uname -r)/ -iname "*xt*.ko*"
# cerca in /modules/cartella_sistema_operativo tutti i file che contengono "xt" nel nome e sono di estensione .koqualcosa
```

# Splittare file
```bash
for l in $(seq 5000) ; do
> echo "riga numero $l" >> file_5000.txt
> done

wc  -l file_5000.txt # ha effettivamente 5000 righe/linee
wc  -l *             # fa la stessa cosa su tutti i file della cartella in cui mi trovo
split file_5000.txt  # di default spezza ogni 1000 righe
cat xa* > nuovo_file # ESCAMOTAGE PER VERIFICARE

split file_5000.txt -l 500 text_splitted_ # ora spezza ogni 500 righe e i chunk si chiameranno text_splitted_aa,ab,ac

split -b 5m video.mp4 # splitta un file grosso in blocchi BINARI da 5 Mega
# Potrei far lo stesso per i file di testo, ma per quelli è più comodo splittarli in N file che rimangano leggibili
```


# Tagliare file
```bash
echo "il comando cut serve a ritagliare l'output dai programmi
il termine cut signigica proprio tagliare
da non confondere con cat!
il comando cat serve inceve a concatenare più file" > cut-example.txt

cut -c12  cut-example.txt   # stampa il carattere nella colonna 12 di ogni riga del file
cut -c12-15 cut-example.txt # ritaglia tutte le righe del file e stampa le colonne 12-13-14-15
cut -c12- cut-example.txt   # ritaglia tutte le righe del file e stampa le colonne dalla 12 fino alla fine
cut -c-12 cut-example.txt   # ritaglia tutte le righe del file e stampa le colonne dall'inizio alla 12

cut -d':' -f1 /etc/passwd       # usa : come delimitatore e stampa il 1° campo individuato col delimitatore
cat /etc/passwd | cut -d':' -f1 # COME SOPRA 
cat /etc/passwd | cut -d':' -f1 | sort # così li ordino anche alfabeticamente 

cut -d':' -f7 /etc/passwd       # stessa cosa ma stampa il 7° campo separato dal :
cut -d':' -f1,7 /etc/passwd     # stessa cosa ma stampa il 1° e il 7° campo separato dal :
cut -d':' -s -f1 /etc/passwd    # stessa cosa ma stampa il 1° campo separato dal : solo per le righe dove trova il separatore

cut -d':' -f7 --complement /etc/passwd       # stampa tutti i campi tranne il 7° campo separato dal :

cut -d':' -f1,7 --output-delimiter='#' /etc/passwd   # stampa f1 ed f7 ma li delimita usando il # al posto del :
cut -d':' -f1,7 --output-delimiter=$'\n' /etc/passwd # stampa f1 ed f7 e li delimita andando a capo
```


lsof [opzioni] [nome_file|PID|utente|comando]  
Elenca i file aperti da tutti i processi in esecuzione
```bash
lsof -u utente       # file aperti da un utente specifico
lsof -p 1234         # file aperti dal solo processo con PID=1234
lsof /var/log/syslog # processi che hanno aperto il file /var/log/syslog
lsof -c nome_comando # file aperti dai processi corrispondenti a un comando specifico
lsof -i              # tutte le connessioni di rete aperte
lsof -i :80          # connessioni di rete per una porta specifica                
```

# REDIREZIONI

## Lettura e scrittura
```bash
exec > ~/t.txt    # serve per la redirezione permanente
exec > /dev/pts/0 # serve per la redirezione permanente
exec 5>~/t.txtv   # creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file
exec 5<>~/t.txt   # così lo creo sia per LETTURA che SCRITTURA
exec 5>&-         # chiudo il file descriptor "custom" 5 in SCRITTURA
```

## Lettura su file
```bash
CMD n< file # LETTURA - aprire il file in lettura; default n=0

head -n 5 divina_commedia.txt # mostra le prime  5 righe (default=10)
tail -n 5 divina_commedia.txt # mostra le ultime 5 righe
tail -f divina_commedia.txt   # mostra la coda ma non esce dal file: se viene modificato, lo vedo in tempo reale (utile per i log)

tail ciao addio               # funziona anche multiplo
tail -f ciao addio            # funziona anche multiplo

nl divina_commedia.txt | tail -n 15 # mostra e numera le ultime 15 righe
nl divina_commedia.txt | head -n 15 # mostra e numera le prime 15 righe
nl divina_commedia.txt              # è come un cat, ma aggiunge gli indici riga
```

## Scrittura su file
```bash
tr "1234" "abcd"   # provo a digitare 1261681185 e lui mi scrive ab6a68aa85
tr 'r' 'R' < t.txt # legge nel file e stampa sovrascrivendo quel carattere
tr -d 'ar'         # legge nel file e stampa eliminando quei caratteri
tr -dc 'ar'        # complementare a sopra, quindi elimina tutto tranne quei caratteri

cat t.txt | tr [:lower:] [:upper:]             # rende tutto il testo da lowercase a uppercase
cat t.txt | tr [:lower:] [:upper:] > UPPER.txt # lo scrivo dentro un file nuovo

ls > tt.txt  # SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt # SCRITTURA - stessa cosa ma opera in APPEND
echo "prima riga" >> file.txt # scrivo "prima riga" dentro file.txt (creandolo se non esiste)

cd /dev/fd
ls -l

sed 's/unix/linux/' geekfile.txt # sostituisce ogni occorrenza di "unix" con "linux" nel file geekfile.txt

dd if=/path/to/sourcefile of=/path/to/destinationfile # copia file, ma funziona anche per folder e volumi

ldd /bin/pwd /sbin/pwck # mostra le dipendenze di questi eseguibili, quali librerie gli servono per funzionare
ldconfig -p # per ogni libreria stampa il path sul file system: i comandi son tutti dei link simbolici
```

## Differenze tra file
```bash
diff read/simile1.sh read/simile2.sh    # mostra le differenze tra i file
diff -y read/simile1.sh read/simile2.sh # mostra riga per riga evidenziando le differenze
diff -i file1 file2                     # ignora le differenze di maiuscole/minuscole
diff -w file1 file2                     # ignora gli spazi bianchi nelle differenze
diff -u file1 file2                     # output più leggibile per i sistemi di controllo versione

comm read/simile1.sh read/simile2.sh    # 3 colonne: nella terza ci son le righe in comune tra i due file
```

## RSYNC
Per sincronizzare e trasferire file/folder. Trasferisce solo le differenze tra origine e destinazione
```bash
rsync -azvP origine/ destinazione/  # ricorsivo, comprime x risparmiar banda, verboso, progress bar
rsync --delete origine destinazione # in "destinazione" elimina ciò che è stato eliminato da "origine"
rsync --exclude "*.mp3"             # non synca gli mp3
rsync --delete -azv -e ssh /percorso/origine utente@host_remoto:/percorso/destinazione # -e indica il comando da usare, come SSH
rsync -avz -e ssh utente@host_remoto:/percorso/sorgente/ /percorso/destinazione/       # posso fare anche il contrario
```
