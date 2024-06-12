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



