## FILE
```bash
file -i CRONTAB.md   # mostra il MIME type del file
file file1.txt       # mi dice il tipo di file (ASCII text)

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

sort file.txt    # riordina in ordine alfabetico le righe dei file.txt
sort -r file.txt # riordina in ordine alfabetico inverso

find ./ -name "long.txt" # cerca un file chiamato long.txt nella cartella corrente
find ./ -type f -name "*.py" ./get_keys.py ./github_automation.py ./binarysearch.py # cerca i file con estensione .py 
find . -maxdepth 3 -type d # cerca nella cartella corrente solo le directory, scendendo fino a 3 sottolivelli
find /lib/modules/$(uname -r)/ -iname "*xt*.ko*"
# cerca in /modules/cartella_sistema_operativo tutti i file che contengono "xt" nel nome e sono di estensione .koqualcosa
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

head -n 10 divina_commedia.txt # mostra le prime 10 righe (default=10)
tail -n 10 divina_commedia.txt # mostra le ultime 10 righe

nl divina_commedia.txt | tail -n 15 # mostra e numera le ultime 15 righe
nl divina_commedia.txt | head -n 15 # mostra e numera le prime 15 righe
```

## Scrittura su file
```bash
tr "1234" "abcd" # provo a digitare 1261681185 e lui mi scrive ab6a68aa85
tr "1234" "abcd" < t.txt # legge nel file e stampa sovrascrivendo quei caratteri

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
