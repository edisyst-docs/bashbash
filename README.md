https://www.youtube.com/watch?v=aghQ6P3Qu3Y

# Esempi
```bash
ls -R cartella # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls [a,e]* # mostra i fileche cominciano per "a" o per "e"
ps # elenco processi
pwd # stampa la directory corrente
date # stampa la data di oggi
sleep 3; echo ciao # attende 3 secondi poi esegue il comando echo
history # storico di tutti i comandi lanciati
history 5 # gli ultimi 5 comandi lanciati
!! # esegue l'ultimo comando della history
!?at? # esegue l'ultimo comando della history contenente 'at'. Es: date
!101 # esegue il 101-esimo comando della history
fc 92 94 # apre nano/vim scrivendo in un file tmp i comandi 92-93-94. Come esco, li esegue tutti
echo ciao ho $[2024-1981] anni # il $ esegue l'operazione tra le quadre
echo ciao ci sono $(ls | wc) righe, parole e lettere nei files qui dentro # wc = words count
echo ciao ci sono $(ls | wc -w) parole nei files qui dentro # wc = words count
nano .bashrc
env # mostra le variabili d'ambiente
alias # mostra gli alias temporanei creati da me. Se faccio exit, scompaiono
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza
unalias x # rimuove quell'alias
(ps;ps) # per vedere che ci son 2 PID annidati
{ ps;ps; } # così c'è un solo PID, un'unica sequenza di processi
```
- Con le {} bisogna mettere uno spazio all'inizio e uno alla fine, e bisogna terminare con ;

```bash
CTRL+R # attiva reverse-search, x cercare i comandi
CTRL+S # search, non so esattamente cosa faccia
```
CTRL+U e CTRL+K nella riga di comando tagliano la parte sinistra e la parte destra di ciò che digito

In AND continuo l'esecuzione finchè un comando non riesce, in OR mi fermo alla prima esecuzione riuscita
```bash
cmd1 && cmd2
cmd1 || cmd2

ls && echo ciao && ls
ls && echi ciao && ls # si và avanti stampando gli errori di ogni comando
lss || echo ciao || ls # si và avanti finchè un comando non ha successo

which ls # dice dove si trova il comando ls, in quale folder
echo $? # stampa l'exit status dell'ultimo processo eseguito

{ ls || echo ciao; } && echo finito
{ lss || echo ciao; } && echo finito

CMD n< file # LETTURA - aprire il file in lettura; default n=0 

tr "1234" "abcd" # provo a digitare 1261681185
tr "1234" "abcd" < t.txt

ls > tt.txt  # SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt # SCRITTURA - stessa cosa ma opera in APPEND

cd /dev/fd
ls -l
```

# REDIREZIONI
```bash
exec > ~/t.txt #  serve per la redirezione permanente
exec > /dev/pts/0 #  serve per la redirezione permanente
exec 5>~/t.txtv  creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file
exec 5<>~/t.txt #  così lo creo sia per LETTURA che SCRITTURA
exec 5>&- #  chiudo il file descriptor "custom" 5 in SCRITTURA
```

# PIPELINE
```bash
cd cartella ; ls # due distinti comandi: prima và nella cartella poi esegue ls
ls | tr "AEIOU" "12345" #  pipeline di comandi: ls(output) diventa tr(input)
cat README.md | grep ciao # apre "README.md" e gerppa solo le righe contenenti "ciao"
grep ciao README.md | grep ls # greppa le righe contenenti "ciao" e greppa le righe contenenti "ls"
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
export -n variabileglobale # la setta NON PIU' GLOBALE
declare -a array=[] # array numerico
declare -A arrayassociativo=[] # array associativo

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
```bash
if condizione
then
    cmd1
    cmd2
fi
```

```bash
ln -s s.sh link1
ln -s cartella link2
ls -l
```

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
```bash
while condizione
do
    cmd1
    cmd2
done
```

```bash
until condizione
do
    cmd1
    cmd2
done
```

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



