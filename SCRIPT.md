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


# ALTRO INTERPRETE
```bash
which python # mi dice il percorso di python
./s4.sh      # esegue del python perchè gli ho detto sopra qual è l'interprete da interpellare
```

# ARRAY
- array classici (indicizzati da numeri) - POSSO NON dichiararli
- array associativi (indicizzati da stringhe) - DEVO dichiararli


# CONDIZIONI
- La condizione si può scrivere in 3 modi: `[condizione]` - `[[condizione]]` - `test condizione`
```bash
-e file          # se file esiste
-d file          # se file esiste ed è directory
-f file          # se file esiste e non è speciale (dir,dev)
-s file          # se file esiste e non è vuoto
-x -r -w file    # se hai diritti esecuzione, lettura e scrittura del file
-O file          # se sei l’owner del file
-G file          # se un tuo gruppo è gruppo di file
file1 -nt file2  # se file1 è più  nuovo  di file2 (data ultima modifica)
file1 -ot file2  # se file1 è più vecchio di file2 (data ultima modifica)
```


# Parametri speciali
```bash
$0 # nome dello script eseguito
$1 # primo argomento dello script. A seguire $2, $3, ecc.
$# # numero degli argomenti passati allo script
$* # tutti gli argomenti passati allo script come una singola stringa. Quindi "$*" equivale a "$1 $2 $3"
$@ # SIMILE, ma ma ogni argomento è trattato come una singola stringa. Quindi "$@" equivale a "$1" "$2" "$3"

$$ # PID dello script in esecuzione
$! # PID dell'ultimo comando eseguito in background. Es: se eseguo "sleep 10 &" allora $! è il PID del processo "sleep"
$? # exit-status dell'ultimo comando eseguito: 0 vuol dire SUCCESS

```


## IF
```bash
if condizione
then
    cmd1
    cmd2
fi

[[ a > b ]] || echo "a viene prima di b"
[[ a = a ]] && echo "a è uguale ad a"
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

# ESPANSIONI (non credo che mi servirà mai approfondirle tutte)
Quando esegue un comando, la shell bash per prima cosa applica eventuali redirezioni,
di seguito applica in ordine le varie espansioni della shell bash che vi sono in gioco.
**A me non funziona niente di niente**

Le single quotes inibiscono sempre le espansioni

**ORDINE**:
1) Brace expansion (double quotes inibiscono)
- `echo {1..10}`    # numeri da 1 a 10
- `echo {1..10..2}` # numeri da 1 a 10 saltando di 2
- `echo '{1..-10}'` #  0 -1 -2 -3 -4 -5 -6 -7 -8 -9 -10
- `echo {a..z}`     # a b c d e f g h i j k l m n o p q r s t u v w x y z
- `echo sal{v,d,modi}are`    # salvare saldare salmodiare
- `echo c{{er,as}c,ucin}are` # cercare cascare cucinare
- `echo {a,b,c}{1..3}`       # prodotto cartesiano: a1 a2 a3 b1...

2) Tilde expansion (double quotes inibiscono)
- `echo ~`           # /home/utente_attuale
- `cd ~altro_utente` # va su /home/altro_utente

3) Parameter & variable expansion (double quotes NON inibiscono)
- `a="ciao" & echo $a`   # $stringa, ${stringa} : stringa è interpretato come var_name e viene espanso col suo valore
- `Unix[2]='Ubuntu' & echo ${Unix[2]}`   # Ubuntu. Vale anche per gli array
- `a="ciao" & echo ${a:-stringaAlternativa}`
- `a="" & echo ${a:=nuovoValore}`
- `a="stringa" & echo ${a:3}` # è un OFFSET: mi stampa "inga"

4) Arithmetic expansion (double quotes NON inibiscono)
- `a=13 b=19 echo $(( $a+$b ))` # 32
- `echo $((12+13))`             # 25

5) Command expansion (o substitution) (double quotes NON inibiscono)

6) Word splitting (double quotes inibiscono)

7) Filename expansion (globbing)  (double quotes inibiscono)

8) Process substitution (double quotes inibiscono)

9) Quote removal
