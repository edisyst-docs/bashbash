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


# Comandi base
```bash
ls -R cartella # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color # colora i file in base al tipo
ls [a,e]* # mostra i file che cominciano per "a" o per "e"
ls -l | grep ^d # mostra solo le directory: è un trucco perchè con ls -l le directory iniziano per "d"

pwd        # stampa la directory corrente
ps         # elenco processi in esecuzione
(ps;ps)    # per vedere che ci son 2 PID annidati
{ ps;ps; } # così c'è un solo PID, un'unica sequenza di processi

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
Per cercare specifiche stringhe di testo o espressionni regolari all'interno di file, cartelle o output di altri comandi
```bash
grep "errore" logfile.txt    # cerca la parola "errore" e restituisce le righe dove la trova
grep -i "errore" logfile.txt # UGUALE ma non distingue maiuscole da minuscole, quindi trova anche ERRORE, Errore, ecc.
grep -r "errore" /var/log/   # cerca ricorsivamente "errore" in tutti i file dentro la directory /var/log/
```


# Pipeline di comandi
```bash
cd cartella ; ls # due distinti comandi: prima và nella cartella poi esegue ls
ls | tr "AEIOU" "12345" #  pipeline di comandi: ls(output) diventa tr(input)
echo "6+9"| bc # svolge l'operazione e stampa il risultato

ls | grep "log"               # filtra i file di log, che si chiamano log_qualcosa
ps aux | grep "apache"        # cerca il processo "apache"
find /path/to/search -type f | grep "config" # cerca i file nella directory /path/to/search e filtra quelli che contengono "config" nel percorso

cat SCRIPT.md | grep ciao     # apre "SCRIPT.md" e filtra le righe contenenti "ciao"
cat SCRIPT.md | grep -c ciao  # UGUALE, ma restituisce solo il numero di righe filtrate
cat SCRIPT.md | grep -n ciao  # UGUALE, ma restituisce solo gli indici riga delle righe filtrate
cat SCRIPT.md | grep -v ciao  # apre "SCRIPT.md" e filtra le righe NON contenenti "ciao"
grep ciao SCRIPT.md | grep ls # filtra le righe contenenti "ciao" e sul risultato filtra le righe contenenti "ls"

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

who # mostra gli utenti loggati sul sistema
w   # mostra gli utenti loggati sul sistema con altre info
uname -a # info sul sistema operativo

hostname    # hostname della macchina
hostname -i # IP
```


# Memoria e risorse
```bash
df -h          # elenca i file nel disco fisso 
df -h --total  # mette anche il totale alla fine

top     # mostra processi e risorse occupate
htop    # mostra le info sulle risorse usate da ogni processo
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


