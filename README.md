# Esempi
- http://didawiki.cli.di.unipi.it/doku.php/informatica/sol/laboratorio15/esercitazionia/bashscriptexamples
- https://kinsta.com/it/blog/comandi-linux/
- https://www.html.it/pag/53628/redirezione-dellio/
- https://www.aquilante.net/bash/cap6_esempi.shtml
- https://www.youtube.com/watch?v=aghQ6P3Qu3Y

# Comandi base
```bash
apropos copy # cerca in tutti gli helper la parola "copy" per aiutarmi a trovare il comando che mi serve

ls -R cartella # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color # colora i file in base al tipo
ls [a,e]* # mostra i file che cominciano per "a" o per "e"

pwd # stampa la directory corrente
ps # elenco processi
(ps;ps) # per vedere che ci son 2 PID annidati
{ ps;ps; } # così c'è un solo PID, un'unica sequenza di processi
```

```bash
date # stampa la data di oggi
cal # mostra il calendario
tar -cf compresso.tar file1 file2 # crea un file compresso.tar contenente file1, file2
tar -xf compresso.tar # estrae i file contenuti in compresso.tar
ping 8.8.8.8 # verifica semplice di connessione
sleep 3; echo ciao # attende 3 secondi poi esegue il comando echo
touch pippo_{1,2,3} # crea pippo_1, pippo_2, pippo_3 
touch pippo_{01..12} # crea pippo_01, pippo_02, ..., pippo_12
shred pippo_01 # sovrascrive in modo illeggibile il file. Meglio che eliminarlo, perchè si potrebbe ripristinare
```

```bash
nano .bashrc
whoami # restituisce il mio username
which ls # dice dove si trova il comando ls, in quale folder
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

```bash
echo ciao ho $[2024-1981] anni # il $ esegue l'operazione tra le quadre
echo ciao ci sono $(ls | wc) righe, parole e lettere nei files qui dentro # wc = words count
echo ciao ci sono $(ls | wc -w) parole nei files qui dentro # wc = words count
echo $? # stampa 13 (valore di ritorno) di uno script che finisce con exit 13
echo $? # stampa l'exit status dell'ultimo script eseguito # stampa 13 se lo script finisce con exit 13
```

## Variabili e alias
```bash
env # mostra le variabili d'ambiente
alias # mostra gli alias temporanei creati da me. Se faccio exit, scompaiono
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza
unalias x # rimuove quell'alias
```
- Con le {} bisogna mettere uno spazio all'inizio e uno alla fine, e bisogna terminare con ;

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

## Concatenazioni di comandi
In AND continuo l'esecuzione finchè un comando non riesce, in OR mi fermo alla prima esecuzione riuscita
```bash
cmd1 && cmd2
cmd1 || cmd2

ls && echo ciao && ls
ls && echi ciao && ls # si và avanti stampando gli errori di ogni comando
lss || echo ciao || ls # si và avanti finchè un comando non ha successo

{ ls || echo ciao; } && echo finito
{ lss || echo ciao; } && echo finito
```

# REDIREZIONI
## Lettura e scrittura
```bash
exec > ~/t.txt #  serve per la redirezione permanente
exec > /dev/pts/0 #  serve per la redirezione permanente
exec 5>~/t.txtv  creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file
exec 5<>~/t.txt #  così lo creo sia per LETTURA che SCRITTURA
exec 5>&- #  chiudo il file descriptor "custom" 5 in SCRITTURA
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
tr "1234" "abcd" # provo a digitare 1261681185
tr "1234" "abcd" < t.txt

ls > tt.txt  # SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt # SCRITTURA - stessa cosa ma opera in APPEND
echo "prima riga" >> file.txt # scrivo "prima riga" dentro file.txt (creandolo se non esiste)

cd /dev/fd
ls -l

sed 's/unix/linux/' geekfile.txt # sostituisce ogni occorrenza di "unix" con "linux" nel file geekfile.txt
```

## Differenze tra file
```bash
diff read/simile1.sh read/simile2.sh # mostra le differenze tra i file
diff -y read/simile1.sh read/simile2.sh # mostra riga per riga evidenziando le differenze

comm read/simile1.sh read/simile2.sh # 3 colonne: nella terza ci son le righe in comune tra i due file
```

# PIPELINE
```bash
cd cartella ; ls # due distinti comandi: prima và nella cartella poi esegue ls
ls | tr "AEIOU" "12345" #  pipeline di comandi: ls(output) diventa tr(input)
echo "6+9"| bc # svolge l'operazione e stampa il risultato

cat README.md | grep ciao # apre "README.md" e filtra le righe contenenti "ciao"
cat README.md | grep -v ciao # apre "README.md" e filtra le righe NON contenenti "ciao"
grep ciao README.md | grep ls # filtra le righe contenenti "ciao" e filtra le righe contenenti "ls"
```

```bash
ls |& tr "AEIOU" "12345" #   ls(output+error) collegato con tr(input)
lss | tr "AEIOU" "12345" #  dà errore
lss |& tr "AEIOU" "12345" #   traduce l'errore

cd .. ; ls bashbash/cartella | sort -f | less # esempio di sequenza + pipeline
```

# SCRIPTING
Così facendo eseguo il file `s1.sh` e accedo al suo codice, altrimenti $a='' di default
```bash
. s1.sh
echo $a
```
Ci sono 4 modi per lanciare uno script bash
```bash
./s1.sh      # Delegato a una sottoshell. Ho bisogno dei permessi di esecuzione (es: `chmod 744 s1.sh`). 
. s1.sh      # si esegue dalla shell bash corrente
source s1.sh # si esegue dalla shell bash corrente
bash s1.sh   # Delegato a una sottoshell
```
 
# VARIABILI
```bash
variabile="valore" # senza nessuno spazio
declare -i numero=13 # se non è stringa lo devo dichiarare: integer
declare -r costante="ciao" # costante: se le assegno un altro valore ho un errore
declare -x variabileglobale="globale" # costante: se le asegno un altro valore ho un errore
export -n variabileglobale # setta la variabile come NON PIU' GLOBALE

declare -a array=[] # array numerico
declare -A arrayassociativo=[] # array associativo
```

```bash
$nomevar   #  prendo il valore della variabile
${nomevar} #  stessa cosa ma è più leggibile in caso di concatenazioni strane
unset      # per settare a NULL una variabile. Dà errore se applicato a una costante
export     #  mi elenca le variabili globali 

./s3.sh par1 par2 par3 # lo eseguo dandogli anche dei parametri
```

# ALTRO INTERPRETE
```bash
which python # mi dice il percorso di python
./s4.sh      # esegue del python perchè gli ho detto sopra qual è l'interprete da interpellare
```

# ARRAY
- array classici (indicizzati da numeri) - POSSO NON dichiararli
- array associativi (indicizzati da stringhe) - DEVO dichiararli

# CONDIZIONI
- La condizione in 3 modi: `[condizione]` - `[[condizione]]` - `test condizione`

## IF
```bash
if condizione
then
    cmd1
    cmd2
fi
```

## CASE (FUNZIONA TIPO LO SWITCH)
```bash
variabile="stringa"
case $variabile in
  pattern1)
    cmd1
    cmd2
    ;;
  pattern2)
    cmd3
    cmd4
    ;;
esac
```

# CICLI
- La condizione sempre in: `[condizione]` - `[[condizione]]` - `test condizione`
- `IFS` ha 3 valori: \n, spazio, tab => `"\n   "` => identifica i separatori fra parole

## WHILE
```bash
while condizione
do
    cmd1
    cmd2
done
```

## UNTIL (contrario di WHILE)
```bash
until condizione
do
    cmd1
    cmd2
done
```
## FOR
```bash
for var in listaElementi
do
    cmd1
    cmd2
done
```

```bash
for (( i=0;i<=10;i++ ))
do
    echo "valore di i: "$i
done
```

# INPUT E READ
```bash
read var1 var2 var3
```

```bash
# here documents
# cmd << EOF "end of file"
tr "aeiou" "56789" << FINE
> ciao questa è una frase lunga
> divisa in più righe
> e finisco qua
> FINE
```

```bash
# here strings
python <<< 'print("Hello Word in python")'
```

# ESPANSIONI (non credo che mi servirà mai approfondirle tutte)
Quando eseguo un cmdN, la shell bash per prima cosa applica eventuali redirezioni date, di seguito 
applica in ordine le varie espansioni della shell bach che vi sono in gioco.
**A me non funziona niente di niente**

Le single quotes inibiscono sempre

**ORDINE**:
1) Brace expansion (double quotes inibiscono)
- `echo {1..10}` # numeri da 1 a 10
- `echo {1..10..2}` # numeri da 1 a 10 saltando di 2
- `echo '{1..-10}'`
- `echo {a..z}`
- `echo {a,b,c}{1..3}`  # prodotto cartesiano: a1 a2 a3 b1...

2) Tilde expansion (double quotes inibiscono)
- `cd ~` # va alla home folder dell'utente attuale
- `cd ~ALTROUTENTE` # cambia utente

3) Parameter & variable expansion (double quotes NON inibiscono)
- `a="ciao" & echo $a`
- `a="ciao" & echo ${a:-stringaAlternativa}`
- `a="" & echo ${a:=nuovoValore}`
- `a="stringa" & echo ${a:3}` # è un OFFSET: mi stampa "inga"

4) Arithmetic expansion (double quotes NON inibiscono)
- `a=13 b=19 echo $(( $a+$b ))`

5) Command expansion (o substitution) (double quotes NON inibiscono)

6) Word splitting (double quotes inibiscono)

7) Filename expansion (globbing)  (double quotes inibiscono)

8) Process substitution (double quotes inibiscono)

9) Quote removal



