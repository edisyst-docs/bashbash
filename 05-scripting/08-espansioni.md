# Espansioni

Quando esegue un comando, la shell applica per prima cosa le eventuali redirezioni, poi in
quest'ordine le varie espansioni.

> Le **single quotes** inibiscono sempre tutte le espansioni.

## 1) Brace expansion
*Le double quotes la inibiscono.*
```bash
echo {1..10}            # numeri da 1 a 10
echo {1..10..2}         # numeri da 1 a 10 saltando di 2
echo {1..-10}           # 1 0 -1 -2 -3 -4 -5 -6 -7 -8 -9 -10
echo {a..z}             # a b c d e f g h i j k l m n o p q r s t u v w x y z
echo sal{v,d,modi}are   # salvare saldare salmodiare
echo c{{er,as}c,ucin}are # cercare cascare cucinare
echo {a,b,c}{1..3}      # prodotto cartesiano: a1 a2 a3 b1 ...
```

## 2) Tilde expansion
*Le double quotes la inibiscono.*
```bash
echo ~            # /home/utente_attuale
cd ~altro_utente  # va su /home/altro_utente
```

## 3) Parameter & variable expansion
*Le double quotes NON la inibiscono.*
```bash
a="ciao"; echo $a          # $stringa o ${stringa}: viene sostituita col suo valore
Unix[2]='Ubuntu'; echo ${Unix[2]}  # Ubuntu. Vale anche per gli array

a=""; echo ${a:-stringaAlternativa} # se $a è vuota usa il valore alternativo (senza assegnarlo)
a=""; echo ${a:=nuovoValore}        # se $a è vuota assegna e usa il nuovo valore
a="stringa"; echo ${a:3}            # OFFSET: stampa "inga"
```

## 4) Arithmetic expansion
*Le double quotes NON la inibiscono.*
```bash
a=13; b=19; echo $(( a+b ))  # 32
echo $((12+13))              # 25
```

## 5) Command substitution
*Le double quotes NON la inibiscono.*
```bash
echo $(date)  # esegue date e ne sostituisce l'output
echo `date`   # UGUALE, sintassi vecchia
```

## 6) Word splitting
*Le double quotes la inibiscono.* La shell spezza il risultato usando `IFS`.

## 7) Filename expansion (globbing)
*Le double quotes la inibiscono.* È quella che trasforma `*.txt` nell'elenco dei file.

## 8) Process substitution
*Le double quotes la inibiscono.*
```bash
diff <(ls dir1) <(ls dir2)  # ogni <( ) diventa un file temporaneo con l'output del comando
```

## 9) Quote removal
Ultimo passo: la shell rimuove gli apici che non derivano da un'espansione.
