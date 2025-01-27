https://www.aquilante.net/bash/cap6_esempi.shtml
https://kinsta.com/it/blog/comandi-linux/
https://didawiki.cli.di.unipi.it/doku.php/informatica/sol/laboratorio15/esercitazionia/bashscriptexamples
https://docs.oracle.com/cd/E19620-01/802-7642/6ib8ghclk/index.html
https://vim.rtorr.com/lang/it
https://supporthost.com/it/comandi-linux/#:~:text=Tieni%20presente%20che%20Ctrl%2BS,interrompendo%20l'esecuzione%20del%20comando.
https://www.tecmint.com/linux-commands-cheat-sheet/


## Crea, copia, elimina file
```bash
file -i CRONTAB.md   # mi dice il MIME type del file
file file1.txt       # mi dice il tipo di file (ASCII text)
file *               # mi dice il tipo di file di tutti quelli in cartella

touch pippo_{1,2,3}  # crea pippo_1, pippo_2, pippo_3 
touch pippo_{01..12} # crea pippo_01, pippo_02, ..., pippo_12

ls /etc/*.conf                  # mostra tutti i file .conf che sono dentro /etc
cp /etc/*.conf destinazione     # copia tutti i file .conf che sono dentro /etc dentro destinazione
cp -i origine destinazione      # UGUALE ma chiede conferma in caso di overwriting
cp file1 file2                  # fa una copia file1 e la chiama file2
cp file1 /percorso/directory/   # copia file1 dentro la cartella /percorso/directory/
cp -r dir_1 /percorso/dir_2/    # copia la dir_1 dentro la cartella /percorso/dir_2

mkdir dir{1,2,3}                # UGUALE a mkdir dir1 dir2 dir3
mkdir -p progetti/2024/giugno   # le crea tutte, già annidate, altrimenti dovrei crearle una x volta
mkdir -m 700 dir_privata        # specifico i permessi in creazione

rmdir directory_vuota           # la directory dev'essere vuota per poterla eliminare
rmdir -p genitore/figlio/nipote # ricorsivo, ma devono essere tutte vuote

rm -r  directory_non_vuota      # rimuove directory NON VUOTE, eliminando ricorsivamente i file all'interno
rm -ri directory_non_vuota      # chiede conferma prima di rimuovere ogni file

shred pippo_01    # sovrascrive in modo illeggibile il file. Meglio che eliminarlo, perchè si potrebbe ripristinare
shred -u pippo_01 # sovrascrive in modo illeggibile il file e lo elimina pure

wc file    # numero di righe, parole, caratteri presenti in file
wc -l file # numero di righe presenti in file
wc -w file # numero di parole presenti in file
wc -c file # numero di caratteri presenti in file.txt
```


## Archiviazione (file unico che contiene N file e cartelle) e Compressione (riduzione spazio)
```bash
cat /var/log/apt/history.log                      # leggo un file di testo
zcat /var/log/apt/history.log.1.gz                # leggo un file compresso .gz (senza scompattarlo per forza)
bzcat, xzcat                                      # analoghi per file compressi .bz e .xz

gzip file1 file2                                  # SOSTITUISCE file1 e file2 con file1.gz e file2.gz compressi
zcat file1.gz e file2.gz                          # non li posso leggere con cat ma con zcat
gzip -l file1.gz                                  # ci dice quanto occupa da compresso e da scompattato
gunzip file1.gz e file2.gz                        # SOSTITUISCE file1.gz e file2.gz compressi con file1 e file2 (INVERSO di gzip)

xz file1                                          # SOSTITUISCE file1 con file1.xz compresso (comprime di più di gzip)
xz -l file1.xz                                    # ci dice quanto occupa da compresso e da scompattato
xz -d file1.xz                                    # SOSTITUISCE file1.gz compresso con file1 (INVERSO di xz)

tar -cvf  archivio.tar file1 file2                # c:CREA il file archivio.tar NON COMPRESSO contenente file1, file2
tar -xvf  archivio.tar /destinazione              # x:ESTRAE (in una cartella specifica) il contenuto di archivio.tar
tar -cvf  archivio.tar file1 file2 directory1     # CREA archivio contenente sia file che directory
tar -cvfz compresso.tar.gz file1 file2 directory1 # COMPRIME l'archivio con gzip (-z), bzip2 (-j), o xz (-J):
tar -xvfz compresso.tar.gz                        # ESTRAE un archivio compresso di tipo tar.gz 
tar -tvf  compresso.tar.gz                        # è come fare "ls -l" ma dentro un archivio compresso

du -sh compresso.tar.gz file1 file2 directory1    # con questo comando posso confrontare quanto occupano tutti quegli elementi
```


## find: cerca file e cartelle
SINTASSI: find [percorso] [criteri] [azione]
```bash
find . -name "long.txt"            # cerca un file chiamato "long.txt" nella cartella corrente
find / -name config                # cerca file/folder chiamati esattamente "config" in tutto il disco (avrò errori di Permesso Negato)
find / -iname config               # UGUALE ma è case insensitive
find / -name config 2>/dev/null    # redirige l'output 2 (std_error) su dev/null (perchè ho errori di Permesso Negato)
find / -iname '*.conf' 2>/dev/null # cerca tutti i file .conf dentro il disco

find . -type f -size +500M         # cerca tutti i file più grandi di 500 MB
find . -type f -perm 644           # cerca tutti i file con permessi 644.

find /home/ -iname config -exec ls -ldh {} \;          # cerca file/cartelle chiamate config e fa un ls SU CIASCUBO DI ESSI
find /home/ -iname config -type f -exec ls -ldh {} \;  # cerca solo file;
find /home/ -iname config -type d -exec ls -ldh {} \;  # cerca solo le directory

find /etc/ -iname '*.conf' | wc -l               # cerca dentro tutta la ramificazione di /etc/
find /etc/ -maxdepth 2 -iname '*.conf' | wc -l   # cerca solo fino al livello 2
find /etc/ -maxdepth 1 -iname '*.conf' | wc -l   # cerca solo al 1° livello, cioè dentro la sola /etc/

find . -type f ! -name "*.txt" | wc -l           # cerca solo file, ma escludendo tutti i .txt

find /lib/modules/$(uname -r)/ -iname "*xt*.ko*" # cerca in /modules/cartella_sistema_operativo tutti i file che contengono "xt" nel nome e sono di estensione .koqualcosa

find /cartella -type f | grep "config"           # cerca i file dentro /cartella e filtra quelli che contengono "config" nel percorso

ls -lht /etc/                                                   # raggruppo i file per data
find /etc/ -iname '*' -mtime +365 -exec ls -lhdt {} \;          # questi sono tutti i file più vecchi di un anno
find /etc/ -iname '*' -mtime +365 -exec ls -lhdt {} \; | wc -l  # così li conto
find /etc/ -iname '*' -mtime -30  -exec ls -lhdt {} \;          # questi sono tutti i file modificati nell'ultimo mese

find /etc/ -iname '*' -size +4k  # file più grandi  di 4 KB
find /etc/ -iname '*' -size -1k  # file più piccoli di 1 KB

locate ".log" # locate è PIU' VELOCE di find: usa un DB indicizzato del file system, ma può restituire risultati obsoleti se il DB non è aggiornato (aggiorna con updatedb)
```


## -exec: esegue un comando su ogni risultato trovato da find
Sintassi: find [percorso] [criteri] -exec [comando] {} \;
- [criteri]: Condizioni per selezionare i file (es. -name, -size, -type, ecc.).
- {} è il placeholder per il risultato di find
- \; è il terminatore del comando
```bash
find /etc/ -iname '*.conf' -exec cp {} /tmp/ \;     # copia tutti i file .conf dentro /tmp/
find /etc/ -iname '*.conf' -exec cp {} /tmp/ \;     # UGUALE ma chiede conferma in caso di overwriting
find /etc/ -iname '*.conf' -exec cp {} /tmp/ +      # UGUALE ma copia tutti i file in un'unica istanza di cp
find /etc/ -iname '*.conf' | xargs cp -t /tmp/      # UGUALE ma con xargs (serve l'opzione cp -t in questo caso)

find /etc/ -iname '*.conf' -exec mv {} /tmp/ \;     # sposta tutti i file .conf dentro /tmp/

find /etc/ -iname '*.conf' -exec rm {} \;           # elimina tutti i file .conf
find /etc/ -iname '*.conf' -exec rm {} +            # UGUALE ma elimina tutti i file in un'unica istanza di rm

find . -name "*.jpg" -exec cp {} /backup/images/ \;  # copia tutti i file .jpg dentro /backup/images/
find /var -type f -name "*.conf" -exec ls -lh {} \;  # lista tutti i file .conf dentro /var/

find /tmp -name "*.tmp" -exec rm -i {} \;            # elimina INTERATTIVAMENTE tutti i file .tmp dentro /tmp/ 
find . -name "*.log" -exec rm {} +                   # elimina tutti i file .log IN UN COLPO SOLO (+ efficiente che eseguirlo file per file)
find /home -name "*.tmp" | xargs rm                  # UGUALE ma con xargs

find /cart -type f -mtime +7 -exec mv {} /cart/bkp/ \;     # sposta i file più vecchi di 7gg in una cartella di backup
find . -maxdepth 1 -iname "*.txt" -exec cp {} ./backup/ \; # copia i file .txt in una cartella di backup
find /var/www -type f -perm 644 -exec chmod 600 {} \;      # cerca i file con permessi 644 e modificali in 600

```


## Stampa file e modifica stampa file
```bash
sort file.txt     # riordina in ordine alfabetico le righe dei file.txt
sort -r file.txt  # riordina in ordine alfabetico inverso
sort -R file.txt  # ordine alfabetico RANDOMICO

sort phonebook                  # ordina alfabeticamente le righe del file in base al primo campo (in base al nome)
sort phonebook | uniq           # UGUALE, ma elimina dall'output le righe duplicate
sort phonebook | uniq -d        # ESATTAMENTE OPPOSTO, ora uniq stampa solo le righe duplicate
sort phonebook -k 2             # ordina alfabeticamente ma in base al secondo campo (in base al cognome)
du -s /home/edoardo/* | sort -n # ordina le righe per NUMERO

ls -l | sort -k9 -r             # ordine inverso per i file di "ls -l" (che di default son già  stampati in ordine alfabetico)
```


```bash
$ for l in $(seq 5000) ; do
> echo "riga-numero---$l" >> file_5000
> done
```
```bash
paste ciao        # uguale a cat
paste ciao -s     # scrive tutte le righe in 1 unica riga, separandole con un TAB
paste ciao -s -d, # scrive tutte le righe in 1 unica riga, separandole con la ,


md5sum file.txt      # calcola l'hash del file, utile per verificare se un file è stato trasferito con successo
sha256sum, sha512sum # alternative più sicure (hash con più bit)
```


# Splittare file
```bash
for l in $(seq 5000) ; do
> echo "riga numero $l" >> file_5000
> done

wc  -l file_5000      # ha effettivamente 5000 righe/linee
wc  -l *              # fa la stessa cosa su tutti i file della cartella in cui mi trovo
split file_5000       # di default spezza ogni 1000 righe
cat xa* > nuovo_file  # ESCAMOTAGE PER VERIFICARE

split file_5000 -l 500 text_splitted_ # ora spezza ogni 500 righe e i chunk si chiameranno text_splitted_aa,ab,ac

split -b 5m video.mp4  # splitta un file BINARIO in blocchi BINARI da 5Mega
# Potrei far lo stesso per i file di testo, ma per quelli è più comodo splittarli in N file che rimangano leggibili
cat video* > unito.mp4 # ESCAMOTAGE PER VERIFICARE
```


# Tagliare file
```bash
echo "il comando cut serve a ritagliare l'output dai programmi
il termine cut signigica proprio tagliare
da non confondere con cat!
il comando cat serve invece a concatenare più file" > cut-example.txt

cut -c12  cut-example.txt   # stampa il carattere nella colonna 12 di ogni riga del file
cut -c12-15 cut-example.txt # ritaglia tutte le righe del file e stampa le colonne 12-13-14-15
cut -c12- cut-example.txt   # ritaglia tutte le righe del file e stampa le colonne dalla 12 fino alla fine
cut -c-12 cut-example.txt   # ritaglia tutte le righe del file e stampa le colonne dall'inizio alla 12

cut -d ':' -f 1 /etc/passwd            # usa i : come delimitatore e stampa il 1° campo (field) individuato col delimitatore
cat /etc/passwd | cut -d':' -f1        # UGUALE 
cut -d ':' -f 1,7 /etc/passwd          # UGUALE, ma stampa i campi 1 e 7 
cat /etc/passwd | cut -d':' -f1 | sort # UGUALE, ma li ordina anche alfabeticamente 

cut -d':' -f7 /etc/passwd       # stessa cosa ma stampa il 7° campo separato dal :
cut -d':' -f1,7 /etc/passwd     # stessa cosa ma stampa il 1° e il 7° campo separato dal :
cut -d':' -s -f1 /etc/passwd    # stessa cosa ma stampa il 1° campo separato dal : solo per le righe dove trova il separatore

cut -d':' -f7 --complement /etc/passwd       # stampa tutti i campi tranne il 7° campo separato dal :

cut -d':' -f1,7 --output-delimiter='#' /etc/passwd   # stampa f1 ed f7 ma li delimita usando il # al posto del :
cut -d':' -f1,7 --output-delimiter=$'\n' /etc/passwd # stampa f1 ed f7 e li delimita andando a capo
```


## sed = Stream EDitor
Individua dei pattern di testo che gli definisco e poi trasforma il testo in base all'azione che gli dico
CCCCCCCCCCCCCCERCA ccccccccccccccirca a meta' sed (stream editor) è un comando per manipolare e trasformare il testo in file o input standard. La sua sintassi di base è:
```bash
sed [OPZIONI] 'ESPRESSIONE' [FILE]                 # SINTASSI BASE
sed 'comando/<ricerca>/<sostituisci>/(parametri)'  # SINTASSI PER 'ESPRESSIONE'
sed 'comando:<ricerca>:<sostituisci>:(parametri)'  # ALTERNATIVA: in verità posso usare ogni carattere speciale non contenuto nel testo

# Comandi che modificano l'output di file, ma non modificano il file stesso
cat /etc/xattr.conf > config         # contiene alcune righe commentate, iniziano per #
sed -n '1,5 p' config                # printa le righe 1,2,3,4,5
sed    '1,5 p' config                # printa tutto il file MA DUPLICA le righe 1,2,3,4,5
sed -n '5,$ p' config                #  printa le righe dalla 5 alla fine del file
sed -n '/pattern/p' config           # printa le righe che contengono "pattern"
sed -n '/^#/p' config                # printa le righe che iniziano per #
sed -n '/Inizio/,/Fine/p' config     # printa tutto il contenuto tra "Inizio" e "Fine"

sed '2a testo aggiunto' config       # aggiunge "testo aggiunto" DOPO la riga 2
sed '2i testo aggiunto' config       # aggiunge "testo aggiunto" PRIMA della riga 2
sed '2c testo aggiunto' config       # SOSTITUISCE la riga 2 con "testo aggiunto" 

sed '/ciao/a\riga dopo' file.txt     # aggiunge una nuova riga DOPO ogni riga dove trova la parola "ciao"
sed '/ciao/i\riga prima' file.txt    # aggiunge una nuova riga PRIMA di ogni riga dove trova la parola "giorno"

sed    '2,4 d' config                # elimina le righe 2,3,4
sed  '/pattern/d' config             # elimina le righe che contengono "pattern"
sed '2,4s/prima/dopo/g' config       # sostituisce "prima" con "dopo" nelle righe 2,3,4
sed 's/^/#/'            config       # aggiunge # all'inizio di ogni riga

sed '/ciao/r altrofile.txt' config   # inserisce il contenuto altrofile.txt dentro config DOPO OGNI RIGA che contiene "ciao"

# Comandi che modificano direttamente il file stesso
sed -i             '/^#/d;' config   # cerca nel file config le linee che iniziano per # e le ELIMINA DAL FILE (non stampa)
sed -i.$(date +%F) '/^#/d;' config   # UGUALE ma crea anche un backup che chiamo con la data di oggi

# Altri comandi utili per modificare l'output
echo "ciao mamma" | sed 's/mamma/babbo/'    # "ciao babbo"
echo "ciao mamma" | sed 's/[a-z]*/(&)/g'    # "(ciao) (mamma)"
echo "123 abc"    | sed 's/[0-9]*/& &/'     # sostituisce le stringhe numeriche con se stesse due volte: "123 123 abc"
echo "abc-123"    | sed 's/^[a-z]*//'       # elimina le stringhe di sole lettere all'inizio

echo "123abc" | sed -r 's/([0-9]+)([a-z]+)/& &/'   # con -r supporta le REGEX estese, il + e le () senza escape 
echo "123abc" | sed -r 's/([0-9]+)([a-z]+)/& &/'   # sed può matchare fino a 9 distinti pattern (qui gliene dò 2 e li trova entrambi) 
echo "123abc" | sed -r 's/([0-9]+)([a-z]+)/\2\1/'  # stampa stringa2 che matcha pattern2 seguita da stringa1 che matcha pattern1 
echo "123abc" | sed 's/\([0-9]*\)\([a-z]*\)/\2\1/' # UGUALE ma senza -r quindi non posso usare le REGEX estese
echo "abc123" | sed 's/\([a-z]*\).*/\1/'           # identifica le stringhe di sole lettere e stampa solo quelle

echo "Mario Rossi" | sed 's/\([A-Za-z]*\) \([A-Za-z]*\)/\2 \1/' # Esempio pratico: stampa "Rossi Mario"

echo "buon giorno giorno" | sed 's/giorno/notte/'   # "buon notte giorno" perchè SED opera 1 volta per riga
echo "buon giorno giorno" | sed 's/giorno/notte/g'  # "buon notte notte"  perchè gli dico di operare GLOBALMENTE
sed 's/pattern/nuovo/I' file.txt                    # sostituisce ignorando maiuscole/minuscole   

echo "ciao ciao" | sed 's/\([a-z][a-z]*\) \1/\1/'   # identifica i duplicati e li elimina

sed -e 's/uno/UNO/g' -e '/tre/d' config         # sostituisce "uno" con "UNO" e elimina le righe che contengono "tre"
sed -e 's/uno/UNO/g' -e '/tre/d' *.txt          # UGUALE ma esegue i comandi su tutti i file che gli passo

sed = config | sed 'N;s/\n/ /'                  # aggiunge all'output la numerazione delle righe

sed 's/unix/linux/g' geek.txt       # sostituisce ogni occorrenza di "unix" con "linux" nel testo del file geek.txt MA NON SOVRASCRIVE IL FILE
sed 's/unix/linux/g' geek.txt > aaa # ora l'output non lo stampa ma lo scrive in aaa
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
touch file{1,2,4,5}                       # creo 5 file
ls -lh file1 file0                        # ho errore per file0 e output per file1. Default: stdout (/dev/tty0), stderr (/dev/tty1) 

ls -lh file1 file0  > risultati           # redirigo nel file solo std_output (1), std_error (2) è stampato a video (terminale /dev/tty0)
ls -lh file1 file0 1> risultati           # UGUALE 

ls -lh file1 file0 2> errori              # redirigo nel file solo std_error (2), std_output (1) è stampato a video
ls -lh file1 file0  > risultati 2> errori # posso fare ENTRAMBE LE COSE INSIEME
ls -lh file1 file0 &> tutto               # UGUALE ma redirigo entrambi (output ed error) dentro un unico file "tutto"
ls -lh file1 file0  > tutti 2>&1          # UGUALE (output dentro "tutti", error dove reindirizzo l'output, cioè sempre "tutti")

ls -lh file1 file0  2>&1 > risultati      # Equivale a > risultati. Perchè std_error è reindirizzato nel default di std_output (/dev/tty0) 

echo messaggio | tee file                 # stampa "messaggio" a video e lo scrive dentro "file". Equivale a echo messaggio && messaggio > file
                                          # legge dallo std_input e invia il testo sia allo std_output (schermo), sia in uno o più file.
echo "altra riga" | tee -a file           # uguale ma fa l'APPEND nel file
                                          
exec > ~/t.txt    # serve per la redirezione permanente
exec > /dev/pts/0 # serve per la redirezione permanente
exec 5>~/t.txtv   # creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file
exec 5<>~/t.txt   # così lo creo sia per LETTURA che SCRITTURA
exec 5>&-         # chiudo il file descriptor "custom" 5 in SCRITTURA
```



## << (Here-Document) e <<< (Here-String)
- Operatore << (Here-Document): usato per fornire input multi-linea a un comando, con un DELIMITATORE definito dall'utente.
```bash 
cat << EOF > file.txt             # ciò che digito dopo lo scrive in file.txt finchè non digito EOF
> Questa è la prima riga.         # cat riceve come input le righe scritte fino al delimitatore EOF
> Questa è la seconda riga.       # utile per passare input multi-linea a un comando
> EOF                             # EOF è un delimitatore, posso chiamarlo come voglio
```
```bash
tr 'aeiou' 'AEIOU' << FINE
> ciao questa è una frase lunga
> divisa in più righe
> e finisco qua
> FINE
```

- Operatore <<< (Here-String): usato per fornire una stringa singola come input a un comando.
```bash
grep "parola" <<< "Frase contenente parola." # la stringa è passata come input a grep, come se fosse letta da un file o da uno stdin.
python <<< 'print("Ciao Mondo")'             # Usato per fornire una stringa singola come input.
```



## Lettura su file
```bash
cat elenco | sort > ordinato  # legge "elenco", lo ordina, e scrive dentro "ordinato" in ordine
sort < elenco > ordinato      # UGUALE ma sfrutto la redirezione dell'input invece che dell'output

echo "testo1 testo2 testo3" | xargs -n1   # stampa il testo andando a capo a ogni parola
xargs -n1 <<< "testo1 testo2 testo3"      # UGUALE ma più elegante perchè uso l'operatore <<<

CMD n< file # LETTURA - aprire il file in lettura; default n=0

cat file_5000 | paste - -     # stampa su 2 colonne
cat file_5000 | paste - - -d, # UGUALE ma separa con le virgole
cat file_5000 | paste - - -   # stampa su 3 colonne

nl divina_commedia.txt        # UGUALE A cat, ma aggiunge gli indici riga

head -n 50 file_5000 | paste - - - -d,:   # stampa su 3 colonne e ogni riga è A,B:C
head -n 5 divina_commedia.txt # mostra le prime  5 righe (default=10)

tail -n 5 file_5000                # mostra le ultime 5 righe (default=10)
tail -f file_5000                  # mostra la coda ma non esce dal file: se viene modificato, lo vedo in tempo reale (utile per i log)
tail -f file_5000 | grep 'error'   # UGUALE, ma greppato

tail ciao addio               # funziona anche multiplo
tail -f ciao addio            # funziona anche multiplo

pr file_5000    # me lo stampa con la paginazione, pronto per la stampa

less divina     # dentro posso fare /non e mi evidenzia tutte le stringhe "non"
more divina     # UGUALE ma ha meno funzionalità di less

awk -F ';' '{print $1}' file.csv    # stampa la prima colonna di un file CSV (non funge con XLSX)

ldd /bin/pwd /sbin/pwck # mostra le dipendenze di questi eseguibili, quali librerie gli servono per funzionare
ldconfig -p # per ogni libreria stampa il path sul file system: i comandi son tutti dei link simbolici
```

## Scrittura su file
```bash
tr 'aeiou' 'AEIOU' # provo a digitare "cane nero" e lui mi scrive "cAnE nErO"
tr 'r' 'R' < t.txt # legge nel file e stampa a video sovrascrivendo quel carattere
tr -d 'ar'         # legge nel file e stampa eliminando quei caratteri
tr -dc 'ar'        # complementare a sopra, quindi elimina tutto tranne quei caratteri

cat t.txt | tr [:lower:] [:upper:]             # rende tutto il testo da lowercase a uppercase
cat t.txt | tr [:lower:] [:upper:] > UPPER.txt # lo scrivo dentro un file nuovo

ls > tt.txt  # SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt # SCRITTURA - stessa cosa ma opera in APPEND
echo "prima riga" >> file.txt # scrivo "prima riga" dentro file.txt (creandolo se non esiste)

cd /dev/fd
ls -l
```


## Comando dd (copia e scrittura file)
```bash
dd if=/path/to/source of=/path/to/destination # copia (bit a bit) file, cartelle, interi volumi (es. CD-ROM)
echo "ciao ciao mamma guarda" > testo         # creo un file di testo
dd if=testo of=TESTO conv=ucase               # creo un file di testo mettendo tutto in MAIUSCOLO

dd if=/dev/zero of=zero.dat                  # crea un file gigante all'infinito finchè non premo CTRL+C
dd if=/dev/zero of=zero.dat bs=1024          # crea un file gigante all'infinito finchè non premo CTRL+C
dd if=/dev/zero of=zero.dat bs=1024 count=10 # crea un file da 10 KB
ls -lh zero.dat                              # verifico che occupi effettivamente 10KB, cioè 10240 byte
dd if=/dev/zero of=zero.dat bs=1M   count=10 # crea un file da 10 MB

ls -lh testo                                 # vedo che occupa 25 Byte
dd if=/dev/urandom of=testo bs=25 count=1    # modo sicuro per eliminare (sovrascrivendo) un file di 25 Byte
cat testo                                    # ora è illeggibile, posso eliminarlo (rm elimina l'indice, non il contenuto)
```


## Differenze tra file
```bash
diff read/simile1.sh read/simile2.sh    # mostra le differenze tra i file
diff -y read/simile1.sh read/simile2.sh # mostra riga per riga evidenziando le differenze
diff -i file1 file2                     # ignora le differenze di maiuscole/minuscole
diff -w file1 file2                     # ignora gli spazi bianchi nelle differenze
diff -u file1 file2                     # output più leggibile per i sistemi di controllo versione

cmp file1.bin file2.bin                 # confronta file byte per byte

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
