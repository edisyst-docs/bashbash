# Esempi
- http://didawiki.cli.di.unipi.it/doku.php/informatica/sol/laboratorio15/esercitazionia/bashscriptexamples
- https://kinsta.com/it/blog/comandi-linux/
- https://www.html.it/pag/53628/redirezione-dellio/
- https://www.aquilante.net/bash/cap6_esempi.shtml
- https://www.youtube.com/watch?v=aghQ6P3Qu3Y


# Shortcuts
```bash
CTRL+L # pulisce la shell, shortcut del comando clear

CTRL+C # interrompe l'esecuzione di un comando
CTRL+Z # metto in pausa un processo lasciandolo in background. Es: esco da VIM col file non salvato

CTRL+D # esco dalla shell (sottoshell se stò impersonando un altro utente). Equivale a digitare "exit"

CTRL+SHIFT+C  # copia 
CTRL+SHIFT+V  # incolla

CTRL+R # reverse-search, x cercare i comandi nella history (lo premo anche più volte)

CTRL+P # history: indietro di un comando
CTRL+N # history: avanti   di un comando

CTRL+S # sospende la visualizzazione dell’output che sta scorrendo sullo schermo senza interrompere il comando
CTRL+Q # riprende la visualizzazione dell’output che sta scorrendo sullo schermo

CTRL+U # taglia la parte sinistra di ciò che scritto sulla shell
CTRL+K # taglia la parte destra di ciò che scritto sulla shell
CTRL+Y # reincolla la stringa eliminata coi comandi precedenti

CTRL+A # vado all'inizio di ciò che ho scritto sulla shell
CTRL+E # vado alla fine  di ciò che ho scritto sulla shell
```


# Helpers
```bash
apropos copy # cerca in tutti gli helper la parola "copy" per aiutarmi a trovare il comando che mi serve
whatis ls    # dice solo cosa fa il comando ls
which ls     # dice dove si trova l'eseguibile di ls, in quale folder
whereis  ls  # dice dove si trova  l'eseguibile e il manuale di ls

echo $PATH        # dice dove tutto cerca gli eseguibili per which e whereis
PATH=$PATH:/opt/  # aggiungo /opt/ ai percorsi di $PATH 

ls --help    # helper del comando
man ls       # helper più dettagliato
info ls      # helper più dettagliato ancora
```


# Shell varie
```bash
echo $SHELL              # /bin/bash è la shell di default
grep edoardo /etc/passwd # tra le varie info mi dice anche la shell di default di edoardo
sh                       # apre al volo la shell sh (esiste anche ksh)
cat /etc/shells          # elenco shell
chsh -l                  # elenco shell, mi permette anche di cambiare shell
chsh -s /bin/sh morro    # modifico la shell all'utente morro

exec ping 8.8.8.8 -c 4   # esegue il comando e poi fa exit/logout dalla shell

echo $(date)             # date è un comando: lo esegue e stampa il suo output
echo `date`              # stessa cosa, ma è una sintassi vecchia
```


# Comandi base
```bash
ls -R cartella      # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color          # colora i file in base al tipo
ls -s               # mostra anche le dimensioni dei file 
ls [a,e]*           # mostra i file che cominciano per "a" o per "e"
ls -l doc*.rar      # mostra i file che si chiamano docXXXXX.rar
ls -l doc?.rar      # mostra i file che si chiamano docX.rar (un solo carattere)
ls -l | grep ^d     # mostra solo le directory: è un trucco perchè con ls -l le directory iniziano per "d"

mv testo{,.old}     # mv testo testo.old 
mv testo.{old,new}  # mv testo.old testo.new
mv testo{.old,}     # mv testo.old testo

pwd                 # stampa la directory corrente
ps                  # elenco processi attivi (in esecuzione ce ne sono tanti altri, anche in altre shell)
ps -u edoardo       # elenco processi del solo utente "edoardo"
ps -f               # qualche info in più
ps -lf              # qualche info in più
ps -e               # elenco di tutti i processi in esecuzione
ps aux              # indica anche l'uso di CPU e memoria
ps aux --sort=-%cpu # UGUALE ma ordinati per uso di CPU
pgrep snap          # cerca i processi facendo un grep sul nome
ps -ef | grep snap  # UGUALE

(ps;ps)             # per vedere che ci son 2 PID annidati
{ ps;ps; }          # così c'è un solo PID, un'unica sequenza di processi

kill -l            # lista dei segnali che posso mandare
kill -1 1234       # forza il reload del processo 1234
kill -9 1234       # termina forzatamente il processo 1234
kill    1234       # di default manda il segnale 15 (chiede al processo 1234 di terminarsi)
pkill calc         # termina tutti i processi facendo un grep sul nome
killall calc       # SIMILE: termina tutti i processi con quel nome esatto

echo ciao ho $[2024-1981] anni # il carattere $ esegue l'operazione tra le quadre
echo ciao ci sono $(ls | wc) righe, parole e lettere nei files qui dentro # wc = words count
echo ciao ci sono $(ls | wc -w) parole nei files qui dentro # wc = words count
```


# Alias
```bash
type pwd   # mi dice se è un comando, un alias o un percorso
type apt   # mi dice il suo percorso eseguibile
type ls    # mi dice il suo alias, perchè ha un alias

ls         # è come lanciare "ls --color=auto"
\ls        # è come lanciare "ls", non esegue gli eventuali alias

alias                                # mostra tutti gli alias della sessione
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza

unalias ls # rimuove l'alias per questa sessione di terminale
```
- Con le {} bisogna mettere uno spazio all'inizio e uno alla fine, e bisogna terminare con ;


# Variabili d'ambiente
```bash
echo $? # stampa 13 (valore di ritorno) di uno script che finisce con exit 13
echo $? # stampa l'exit status dell'ultimo script eseguito # stampa 13 se lo script finisce con exit 13

echo $RANDOM   # stampa un numero casuale tra 0 e 32767. Può ritornare utile

echo $ [TAB]   # mostra l'elenco di tutte le var d'ambiente disponibili
env            # mostra i valori di molte variabili d'ambiente
```


# VARIABILI
```bash
mount /dev/sda /mnt -o offset=$((512*811006))  # esempio: prima esegue la moltiplicazione e il risultato lo usa nel comando

variabile="valore" # senza nessuno spazio
declare -i numero=13 # se non è stringa lo devo dichiarare: integer
declare -r costante="ciao" # costante: se le assegno un altro valore ho un errore
declare -x variabileglobale="globale" # costante: se le asegno un altro valore ho un errore
export -n variabileglobale # setta la variabile come NON PIU' GLOBALE

set +o           # elenca le opzioni di bash. Il + significa che è disattivata (è fuorviante)
echo $SHELLOPTS  # mostra velocemente solo quelle attive
set -o allexport # da questo momento in poi ogni variabile sarà automaticamente esportata

declare -a array=[] # array numerico
declare -A arrayassociativo=[] # array associativo

merenda=torta         # variabile valorizzata
echo $merenda         # stampa torta
export merenda        # la esporta così posso usarla anche nelle shell figlie
export merenda=torta  # fa entrambe le operazioni in un colpo solo
unset merenda         # setta a NULL la variabile

sudo su -     # è un esempio per scendere in profondità coi processi figli
bash          # vado giù ancora di un livello
ps --forest   # vedo la gerarchia dei vari processi

$nomevar   #  prendo il valore della variabile
${nomevar} #  stessa cosa ma è più leggibile in caso di concatenazioni strane
unset      # per settare a NULL una variabile. Dà errore se applicato a una costante
export     #  mi elenca le variabili globali 

./s3.sh par1 par2 par3 # lo eseguo dandogli anche dei parametri
```


# Concatenazioni di comandi
In `AND` continuo l'esecuzione finchè un comando non riesce, in `OR` mi fermo alla prima esecuzione riuscita
```bash
cmd1 && cmd2
cmd1 || cmd2

ls && echo ciao && ls
ls && echi ciao && ls # si và avanti stampando gli errori di ogni comando
lss || echo ciao || ls # si và avanti finchè un comando non ha successo

{ ls || echo ciao; } && echo finito
{ lss || echo ciao; } && echo finito
```


# Comando GREP
Cercare specifiche stringhe di testo o regex all'interno di file, cartelle o output di altri comandi
```bash
grep stringa file             # SINTASSI BASE
cat file | grep stringa       # ALTERNATIVA

grep "errore" logfile.txt     # cerca la parola "errore" e restituisce le righe dove la trova
grep -i "errore" logfile.txt  # UGUALE ma non distingue maiuscole/minuscole, quindi trova anche ERRORE, Errore, ecc.
grep -c "errore" logfile.txt  # restituisce solo il conteggio delle righe trovate
grep -r "errore" /var/log/    # cerca ricorsivamente "errore" in tutti i file dentro la cartella /var/log/
grep -E '[0-9]{3}' logfile    # -E per accettare anche le regex estese; cerca tutte le sequenze di 3 numeri
egrep '[0-9]{3}' logfile      # UGUALE
fgrep [circa] logfile         # cerca esattamente [circa], le [] e i simboli non li interpreta come regex 

grep '^b' logfile.txt         # cerca tutte le righe del file che iniziano per "b"
grep 'fine$' logfile.txt      # cerca tutte le righe del file che finiscono con la parola "fine"
grep errore *                 # cerca la parola "errore" in tutti i file dentro la cartella corrente
grep 'de.' logfile.txt        # filtra le righe contenenti "dei", "del", "degli", "delle"  
grep 'de*' logfile.txt        # filtra le righe contenenti "de", "dei", "del", "degli", "delle", "deambulante"  
grep '^\.' logfile.txt        # filtra le righe che iniziano col . (uso il \ per indicare un carattere speciale)
grep [.ca] logfile.txt        # filtra le righe contenenti almeno un carattere tra quelli tra parentesi (un punto o una "a" o una "c")
grep ^[d]  logfile.txt        # filtra le righe che iniziano col carattere "d"
grep [^.ca] logfile.txt       # filtra le righe contenenti almeno un carattere NON tra quelli tra parentesi

cat SCRIPT.md | grep ciao       # apre "SCRIPT.md" e filtra le righe contenenti "ciao"
cat SCRIPT.md | grep -c ciao    # UGUALE, ma restituisce solo il numero di righe filtrate
cat SCRIPT.md | grep -n ciao    # UGUALE, ma restituisce solo gli indici riga delle righe filtrate
cat SCRIPT.md | grep -v ciao    # apre "SCRIPT.md" ed esclude le righe contenenti "ciao"
cat SCRIPT.md | grep -v '^[#;]' # apre "SCRIPT.md" ed esclude le righe che non cominciano per # o ;
grep ciao SCRIPT.md | grep ls   # filtra le righe contenenti "ciao" e sul risultato filtra le righe contenenti "ls"
```


# Pipeline di comandi
```bash
cd cartella ; ls # due distinti comandi: prima và nella cartella poi esegue ls
ls | tr "AEIOU" "12345" #  pipeline di comandi: ls(output) diventa tr(input)
echo "6+9"| bc # svolge l'operazione e stampa il risultato

ls | grep "log"                        # filtra i file di log, che si chiamano log_qualcosa
find /cartella -type f | grep "config" # cerca i file nella directory "cartella" e filtra quelli che contengono "config" nel percorso

cat -n SCRIPT.md              # numera tutte le righe mostrate
cat -b SCRIPT.md              # numera solo le righe non vuote
cat file1 file2 > new_file    # concatena la visualizzazione di più file e scrive tutto in new_file
cat file2 >> file1            # appende il contenuto di file2 a file1. Risultato=file1+file2
cat > nuovo_file              # crea nuovo_file e dentro ci scrive ciò che l'utente scrive dopo

ls |& tr "AEIOU" "12345"  # ls(output+error) collegato con tr(input)
lss | tr "AEIOU" "12345"  # dà errore
lss |& tr "AEIOU" "12345" # traduce l'errore

cd .. ; ls divina_commedia.txt | sort -f | uniq # esempio di sequenza + pipeline

echo {1..9} | xargs -n4       # xargs prende i suoi parametri dallo std_input (default 0), li processa 4 alla volta, e ne fa un echo
find /etc/ -iname '*.conf' | xargs tar -czvf configs.tar.gz    # mi scrive tutto in un archivio compresso tar 
tar -tf configs.tar.gz | wc -l                                 # leggo quante righe sono
```


# User
```bash
whoami     # restituisce il mio username
echo $USER # UGUALE
users      # indica tutti gli utenti connessi

who      # mostra gli utenti loggati sul sistema
w        # mostra gli utenti loggati sul sistema con altre info
uname -a # info sul sistema operativo

hostname    # hostname della macchina
hostname -i # IP

hostnamectl # info hostname
```


# Memoria e risorse
```bash
lshw	               # info sull'hardware della macchina
lshw -short            # UGUALE ma senza tante info inutili
lscpu                  # info sulla CPU
lsmem                  # info sulla memoria

du -hs /home/edo/*     # restituisce la dimensione di ogni elemento dentro /home/edo/
du -hs /home/edo/      # restituisce la dimensione totale della cartella /home/edo/
df -h                  # mostra spazio occupato e libero (per ogni partizione)
df -h --total          # aggiunge il totale alla fine
df -h /dev/sda1        # uso dello spazio su una partizione specifica
df -hT                 # mostra anche il tipo di file system 
df -hT | grep -v tmpfs # calcolo escludendo i file system temp (es: tmpfs)

watch ls -lh /var/log/       # esegue ls -lh ogni 2 secondi
watch -n 5 ls -lh /var/log/  # esegue ls -lh ogni 5 secondi

free -h # mostra la memoria libera e occupata
```

Posso gestire la priority di un processo e la sua niceness (capacità di condividere le sue risorse) con nice e renice:
```bash
ps -l                   # mostra anche priorità e niceness dei processi
nice -n 5 sleep 1000&   # lancia un processo in bg che dura un po' con niceness 5
nice -n 10 sleep 1000&  # lancia un processo in bg che dura un po' con niceness 10
ps -l                   # questi processi hanno priorità e nicenessdifferenti dal default
renice -n 7 95740       # cambia la priorità del PID 95740 a 7. Posso solo incrementargliela se non sono root
renice -n 10 -u edoardo # cambia la priorità di tutti i processi di edoardo a 10
```
Posso fare il renice anche tramite il comando top, premendo la r.  
Il valore di nice è tra -20 e 19, dove -20 è la priorità più alta e 19 la più bassa. 
Ma solo root può diminuire la priorità di un processo, nonchè creare un processo con priorità negativa.


## Dischi
```bash
mount /dev/sda1 /mnt            # monta il disco sda1 nella cartella /mnt
umount /mnt                     # smonta il disco sda1 dalla cartella /mnt

mount                           # mostra i dischi montati
mount | column -t               # UGUALE più leggibile
mount | grep sda1               # mostra solo il disco sda1

lsblk | grep -v loop            # mostra dischi/partizioni (anche l'alberatura): più dettagliato di mount
lsblk -f | grep -v loop         # UGUALE ma mostra anche i punti di mount
blkid                           # mostra gli UUID dei dischi
blkid /dev/sda /dev/sdb         # se gli passo i dischi specifici mi fornisce anche info più dettagliate

cat /etc/fstab | grep -v '#'    # mostra i dischi montati automaticamente all'avvio.
ls -lh /dev/disk/by-uuid/       # mostra i dischi montati con i loro UUID
ls -lh /dev/disk/by-id/         # mostra i dischi montati con i loro ID

cat /etc/systemd/system/snap-snapd-21759.mount   # esempio di configurazione di un disco montato
```





## tmux   
Terminali e finestre multipli su una singola istanza (es: su un singolo collegamento SSH)
```bash
tmux                 # apre una nuova sessione
tmux ls              # mostra le sessioni attive
tmux new -s sessione # crea una nuova sessione chiamata "sessione"
tmux attach -t 0     # permette di ricollegarsi alla sessione 0
exit                 # esce da una sezione/finestra/sessione in base a dove mi trovo nei vari livelli
```

All'interno di tmux posso fare diverse azioni, ognuna delle quali deve essere sempre preceduta da `CTRL+B`:
- CTRL+B seguito da ?: mostra l'elenco dei comandi disponibili
- CTRL+B seguito da C: (create) crea una nuova finestra
- CTRL+B seguito da ,: permette di rinominare la finestra corrente
- CTRL+B seguito da N: (next) passa alla finestra successiva
- CTRL+B seguito da P: (previous) passa alla finestra precedente
- CTRL+B seguito da W: (windows) 
- 
- CTRL+B seguito da [: (copy) permette di copiare il testo dalla finestra corrente
- CTRL+B seguito da &: (kill) chiude la sezione/finestra/sessione corrente. E' come digitare `exit`
- CTRL+B seguito da %: (split) divide la finestra corrente in due sezioni verticali
- CTRL+B seguito da ": (split) divide la finestra corrente in due sezioni orizzontali
- CTRL+B seguito da freccia: permette di spostarsi tra le varie sezioni della finestra.
- 
- CTRL+B seguito da D: (detach) stacca la sessione corrente ma non la chiude, così posso sempre riaprirla


## top e htop
```bash
top              # mostra processi e risorse occupate imodalità interattiva
top -p 1234,5678 # mostra solo i processi con PID 1234 e 5678
top -u edoardo   # mostra solo i processi di edoardo
top -b -n2 -d2   # esegue top 2 volte, ogni 2 secondi, in background (invece che in modalità interattiva)
```
**Opzioni di top**:
* h: Mostra l'aiuto (elenco dei comandi interattivi).
* q: Esce da top.
* F: Fields management: permette di scegliere (premendo D o spazio) quali colonne mostrare, e anche su cosa ordinare i processi.
* l: Attiva/disattiva la visualizzazione della prima riga
* c: Attiva/disattiva la visualizzazione del percorso completo del comando.
* m: Mostra in modo diverso la visualizzazione dell'utilizzo della memoria.
* t: Mostra in modo diverso la visualizzazione dell'utilizzo della CPU.
* M: Ordina i processi per utilizzo della memoria.
* P: Ordina i processi per utilizzo della CPU (predefinito).
* T: Ordina i processi per tempo di CPU cumulativo.
* R: Ordina i processi in ordine inverso rispetto a quello attuale.
* k: Uccide un processo. Ti verrà chiesto di inserire il PID del processo e il segnale da inviare.
* r: Cambia la priorità (niceness) di un processo. Fa ciò che fa il comando `renice`
* u: Filtra i processi per utente. Ti verrà chiesto di inserire il nome utente.
* n: Cambia il numero di processi visualizzati.

```bash
htop              # versione migliorata e più interattiva di TOP
htop -p 1234,5678 # mostra solo i processi con PID 1234 e 5678
htop -u edoardo   # mostra solo i processi di edoardo
```
**Opzioni di htop**:
1. [x] h: Mostra l'aiuto (elenco dei comandi interattivi).
2. [x] q / F10: Esce da htop.
3. [x] F2: Entra nel menu di configurazione.
3. [x] F3: Cerca un processo per nome.
4. [x] F4: Filtra i processi per nome.
5. [x] F5: Visualizzazione ad albero dei processi.
6. [x] F6: Cambia il criterio di ordinamento (ad esempio, CPU, memoria, tempo di esecuzione).
7. [x] F9: Uccidi un processo. Ti verrà chiesto di scegliere il segnale da inviare.
8. [x] F7/F8: Aumenta/diminuisci la priorità (niceness) di un processo.
9. [x] F2: Configura htop. Puoi modificare colonne, colori e altre impostazioni.


```bash
free -h # mostra le risorse di sistema in utilizzo e disponibili

sudo wall messaggio # broadcast del messaggio a tutti gli utenti. Per testarlo dovrei creare 2 utenti in 2 terminali
sudo write messaggio # invio del messaggio a un solo utente. Per testarlo dovrei creare 2 utenti in 2 terminali

cat /proc/cpuinfo # info sulla CPU: memoria, modello, ecc.
cat /proc/meminfo # info sulla memoria
ls /proc/         # ci sono tante cartelle chiamate coi PID dei processi in esecuzione: se chiudo un processo scompare la cartella corrispondente
```

```bash
shutdown -r now # riavvia adesso
shutdown -h now # spegne  adesso
shutdown    now # UGUALE
shutdown  20:40 # spegne alle 20:40
shutdown -h +10 # spegne  fra 10 min
shutdown -c     # annulla lo spegnimento

tail file      # mostra le ultime 10 righe del file
tail -n 3 file # mostra le ultime 3  righe del file
head file      # mostra le prime  10 righe del file
head -n 3 file # mostra le prime  3  righe del file

cmatrix # inutile, è Matrix
```


## History
```bash
history            # storico di tutti i comandi lanciati
cat  .bash_history # viene letto questo file della mia home
history 5          # gli ultimi 5 comandi lanciati
history -c         # cancello tutta la history

!101    # esegue il comando con ID=101 della history
!!      # esegue l'ultimo comando della history
sudo !! # esegue l'ultimo comando come SUDO (TRUCCHETTO UTILE)
!?at?   # esegue l'ultimo comando della history contenente 'at'. Es: date
!apt    # esegue l'ultimo comando della history che inizia con 'apt'. Es: apt-get update

rm !$   # !$ è l'argomento dell'ultimo comando digitato, per cui rimuove il file (se) digitato nel comando precedente (es: touch file nuovo)

fc 92 94 # apre nano/vim scrivendo in un file tmp i comandi 92-93-94. Come esco, li esegue tutti
```


## Date
```bash
dpkg-reconfigure tzdata  # modifica timezone/fuso orario
dpkg-reconfigure locales # modifica la lingua del terminale

date                          # stampa data e ora di oggi
date -I                       # stampa solo la data
date '+%d-%m-%Y'              # stampa la data nel formato che gli dico io
date '+%H:%M:%S'              # posso indicargli anche un formato per stampare l'ora
date '+%d-%m-%Y --- %H:%M:%S' # altro esempio per combinarli
touch docum-$(date -I)        # trucco per creare un file con la data di oggi nel nome

cal     # mostra il calendario
uptime  # orario, tempo di attività, utenti connessi, carico di lavoro sulla macchina (è la prima riga del comando "top")
last    # elenca login/logout di tutti gli utenti da che esiste la macchina

ping 8.8.8.8 # verifica semplice di connessione
sleep 3; echo ciao # attende 3 secondi poi esegue il comando echo
```


## Simlink e hardlink
```bash
ln -s file link1      # LINK SIMBOLICO
ln -s cartella link2  # è un altro file con permessi 777, ma tanto eredita i permessi del file che linka
ls -l                 # riconosco il link dalla l iniziale

touch pippo
ls -l                 # vedo che pippo ha 1 nella colonna degli inode
ln origine link       # HARD LINK. Apparentemente è come un file diverso
ls -l                 # hanno entrambi 2 nella colonna degli inode
ls -i                 # hanno lo stesso numero di inode
ls -li                # son proprio lo stesso file, tutti i dati coincidono. Se ne modifico uno, modifico anche l'altro
```


# Gestione pacchetti
```bash
apt-cache search pdf   # cerca ad esempio programmi per PDF
apt-cache pkgnames pdf # cerca programmi che iniziano con "pdf"
apt-cache show xpdf    # mostra info sul programma "xpdf"
apt-cache showpkg xpdf # info sulle dipendenze
apt-cache depends xpdf # elenco dipendenze di xpdf
apt-cache stats        # statistiche sulla cache dei pacchetti
apt-cache stats        # statistiche sulla cache dei pacchetti
apt-cache unmet        # quali dipendenze non sono soddisfatte

apt-get -s install virtualbox # con -s simula l'install così vedo se ci sarebbero errori/problemi
ls /var/cache/apt/archives/   # elenco pacchetti scaricati (non necessariamente anche installati)
apt-get remove virtualbox     # lo elimina ma lascia i pacchetti delle dipendenze ormai inutili
apt-get autoremove virtualbox # lo elimina con tutte le dipendenze

apt list          # restituisce una lista immensa
apt list ssh      # mostra 2 versioni per questo particolare pacchetto
apt show ssh      # dettagli sul SW
apt search webcam # trova software per la webcam
```
