# Esempi
- http://didawiki.cli.di.unipi.it/doku.php/informatica/sol/laboratorio15/esercitazionia/bashscriptexamples
- https://kinsta.com/it/blog/comandi-linux/
- https://www.html.it/pag/53628/redirezione-dellio/
- https://www.aquilante.net/bash/cap6_esempi.shtml
- https://www.youtube.com/watch?v=aghQ6P3Qu3Y


# Helpers
```bash
apropos copy # cerca in tutti gli helper la parola "copy" per aiutarmi a trovare il comando che mi serve
whatis ls    # dice solo cosa fa il comando ls
which ls     # dice dove si trova il comando ls, in quale folder

ls --help # helper del comando
man ls    # helper più dettagliato
info ls   # helper più dettagliato
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
```


# Comandi base
```bash
ls -R cartella  # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color      # colora i file in base al tipo
ls [a,e]*       # mostra i file che cominciano per "a" o per "e"
ls -l *.rar     # mostra i file che terminano con .rar
ls -l | grep ^d # mostra solo le directory: è un trucco perchè con ls -l le directory iniziano per "d"

pwd                 # stampa la directory corrente
ps                  # elenco processi attivi 
ps -e               # elenco processi in esecuzione
ps aux              # indica anche l'uso di CPU e memoria
ps aux --sort=-%cpu # UGUALE ma ordinati per uso di CPU
(ps;ps)             # per vedere che ci son 2 PID annidati
{ ps;ps; }          # così c'è un solo PID, un'unica sequenza di processi

echo ciao ho $[2024-1981] anni # il carattere $ esegue l'operazione tra le quadre
echo ciao ci sono $(ls | wc) righe, parole e lettere nei files qui dentro # wc = words count
echo ciao ci sono $(ls | wc -w) parole nei files qui dentro # wc = words count
```


# Variabili e alias
```bash
echo $? # stampa 13 (valore di ritorno) di uno script che finisce con exit 13
echo $? # stampa l'exit status dell'ultimo script eseguito # stampa 13 se lo script finisce con exit 13
env     # mostra le variabili d'ambiente

alias   # mostra gli alias temporanei creati da me. Se faccio exit, scompaiono
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza
unalias x # rimuove quell'alias
```
- Con le {} bisogna mettere uno spazio all'inizio e uno alla fine, e bisogna terminare con ;


# VARIABILI
```bash
variabile="valore" # senza nessuno spazio
declare -i numero=13 # se non è stringa lo devo dichiarare: integer
declare -r costante="ciao" # costante: se le assegno un altro valore ho un errore
declare -x variabileglobale="globale" # costante: se le asegno un altro valore ho un errore
export -n variabileglobale # setta la variabile come NON PIU' GLOBALE

declare -a array=[] # array numerico
declare -A arrayassociativo=[] # array associativo

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
Per cercare specifiche stringhe di testo o espressioni regolari all'interno di file, cartelle o output di altri comandi
```bash
grep stringa file             # SINTASSI BASE
cat file | grep stringa       # ALTERNATIVA

grep "errore" logfile.txt     # cerca la parola "errore" e restituisce le righe dove la trova
grep -i "errore" logfile.txt  # UGUALE ma non distingue maiuscole/minuscole, quindi trova anche ERRORE, Errore, ecc.
grep -r "errore" /var/log/    # cerca ricorsivamente "errore" in tutti i file dentro la cartella /var/log/
grep '^b' logfile.txt         # cerca tutte le righe del file che iniziano per "b"
grep 'fine$' logfile.txt      # cerca tutte le righe del file che finiscono con la parola "fine"
grep errore *                 # cerca la parola "errore" in tutti i file dentro la cartella corrente
grep 'de.' logfile.txt        # filtra le righe contenenti "dei", "del", "degli", "delle"  
grep 'de*' logfile.txt        # filtra le righe contenenti "de", "dei", "del", "degli", "delle", "deambulante"  
grep '^\.' logfile.txt        # filtra le righe che iniziano col . (uso il \ per indicare un carattere speciale)
grep [.ca] logfile.txt        # filtra le righe contenenti almeno un carattere tra quelli tra parentesi (un punto o una "a" o una "c")
grep [^.ca] logfile.txt       # filtra le righe contenenti almeno un carattere NON tra quelli tra parentesi

cat SCRIPT.md | grep ciao     # apre "SCRIPT.md" e filtra le righe contenenti "ciao"
cat SCRIPT.md | grep -c ciao  # UGUALE, ma restituisce solo il numero di righe filtrate
cat SCRIPT.md | grep -n ciao  # UGUALE, ma restituisce solo gli indici riga delle righe filtrate
cat SCRIPT.md | grep -v ciao  # apre "SCRIPT.md" e filtra le righe NON contenenti "ciao"
grep ciao SCRIPT.md | grep ls # filtra le righe contenenti "ciao" e sul risultato filtra le righe contenenti "ls"
```


# Pipeline di comandi
```bash
cd cartella ; ls # due distinti comandi: prima và nella cartella poi esegue ls
ls | tr "AEIOU" "12345" #  pipeline di comandi: ls(output) diventa tr(input)
echo "6+9"| bc # svolge l'operazione e stampa il risultato

ls | grep "log"               # filtra i file di log, che si chiamano log_qualcosa
ps aux | grep "apache"        # cerca il processo "apache"
find /cartella -type f | grep "config" # cerca i file nella directory "cartella" e filtra quelli che contengono "config" nel percorso

cat -n SCRIPT.md              # numera tutte le righe mostrate
cat -b SCRIPT.md              # numera solo le righe non vuote
cat file1 file2 > new_file    # concatena la visualizzazione di più file e scrive tutto in new_file
cat file2 >> file1            # appende il contenuto di file2 a file1. Risultato=file1+file2
cat > nuovo_file              # crea nuovo_file e dentro ci scrive ciò che l'utente scrive dopo

ls |& tr "AEIOU" "12345"  # ls(output+error) collegato con tr(input)
lss | tr "AEIOU" "12345"  # dà errore
lss |& tr "AEIOU" "12345" # traduce l'errore

cd .. ; ls bashbash/cartella | sort -f | less # esempio di sequenza + pipeline
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
lscpu                  # info sulla CPU
df -h                  # elenca i file nel disco fisso 
df -h --total          # aggiunge il totale alla fine
df -h /dev/sda1        # uso dello spazio su una partizione specifica
df -hT                 # mostra anche il tipo di file system 
df -hT | grep -v tmpfs # calcolo escludendo i file system temp (es: tmpfs)
du -h -s cartella      # per sapere quanto occupa la cartella

blkid /dev/sda /dev/sdb /dev/sdc # mostra gli UUID dei dischi
```

```bash
top              # mostra processi e risorse occupate in realtime
top -p 1234,5678 # mostra solo i processi con PID 1234 e 5678
top -u edoardo   # mostra solo i processi di edoardo
```
**Opzioni di top**:
* h: Mostra l'aiuto (elenco dei comandi interattivi).
* q: Esce da top.
* c: Attiva/disattiva la visualizzazione del percorso completo del comando.
* M: Ordina i processi per utilizzo della memoria.
* P: Ordina i processi per utilizzo della CPU (predefinito).
* T: Ordina i processi per tempo di CPU cumulativo.
* k: Uccide un processo. Ti verrà chiesto di inserire il PID del processo e il segnale da inviare.
* r: Cambia la priorità (niceness) di un processo. Ti verrà chiesto di inserire il PID del processo e il nuovo valore di niceness.
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

mount | column -t # mostra i dischi

sudo wall messaggio # broadcast del messaggio a tutti gli utenti. Per testarlo dovrei creare 2 utenti in 2 terminali
sudo write messaggio # invio del messaggio a un solo utente. Per testarlo dovrei creare 2 utenti in 2 terminali

cat /proc/cpuinfo # info sulla CPU: memoria, modello, ecc.
cat /proc/meminfo # info sulla memoria

shutdown -r now # riavvia adesso
shutdown -h now # spegne  adesso
shutdown -h +10 # spegne  fra 10 min

tail file      # mostra le ultime 10 righe del file
tail -n 3 file # mostra le ultime 3  righe del file
head file      # mostra le prime  10 righe del file
head -n 3 file # mostra le prime  3  righe del file

cmatrix # inutile, è Matrix
```


## History
```bash
history # storico di tutti i comandi lanciati
history 5 # gli ultimi 5 comandi lanciati
!!      # esegue l'ultimo comando della history
sudo !! # esegue l'ultimo comando come SUDO
!?at?   # esegue l'ultimo comando della history contenente 'at'. Es: date
!101    # esegue il comando con ID=101 della history
fc 92 94 # apre nano/vim scrivendo in un file tmp i comandi 92-93-94. Come esco, li esegue tutti
```


## Date
```bash
dpkg-reconfigure tzdata  # modifica timezone/fuso orario
dpkg-reconfigure locales # modifica la lingua del terminale

date   # stampa la data di oggi
cal    # mostra il calendario
uptime # orario, tempo di attività, utenti connessi, carico di lavoro sulla macchina
last   # elenca login/logout di tutti gli utenti da che esiste la macchina

ping 8.8.8.8 # verifica semplice di connessione
sleep 3; echo ciao # attende 3 secondi poi esegue il comando echo
```


## Link simbolici
```bash
ln -s s.sh link1
ln -s cartella link2
ls -l
```


# Shortcuts
```bash
CTRL+L # pulisce la shell, shortcut del comando cls

CTRL+Z # esco da un processo lasciandolo in background. Es: esco da VIM col file non salvato
fg     # per prendere il processo in background e portarlo in foreground

CTRL+P # history: indietro di un comando
CTRL+N # history: avanti   di un comando

CTRL+R # reverse-search, x cercare i comandi precedentemente usati
CTRL+S # search, non so esattamente cosa faccia

CTRL+U # taglia la parte sinistra di ciò che scritto sulla shell
CTRL+K # taglia la parte destra di ciò che scritto sulla shell

CTRL+A # vado all'inizio di ciò che ho scritto sulla shell
CTRL+E # vado alla fine  di ciò che ho scritto sulla shell
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

