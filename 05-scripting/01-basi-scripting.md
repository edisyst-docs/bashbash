# Basi dello scripting

## I 4 modi per lanciare uno script
```bash
./s1.sh      # delegato a una sottoshell. Servono i permessi di esecuzione (es: chmod 744 s1.sh)
bash s1.sh   # delegato a una sottoshell
. s1.sh      # eseguito dalla shell bash corrente
source s1.sh # UGUALE a ". s1.sh"
```

La differenza è sostanziale: nei primi due casi lo script gira in una **sottoshell**, quindi le
variabili che definisce muoiono con lei. Negli ultimi due gira nella shell corrente, quindi le
variabili restano disponibili anche dopo.

```bash
. s1.sh   # eseguo il file s1.sh e accedo alle sue variabili
echo $a   # ora $a ha il valore assegnato in s1.sh; con ./s1.sh sarebbe rimasta vuota
```

## Passare parametri
```bash
./s3.sh par1 par2 par3 # lo eseguo dandogli anche dei parametri
```
Vedi [03-parametri.md](03-parametri.md) per leggerli dentro lo script.

## Script di esempio
Gli script di questa cartella sono gli appunti in forma eseguibile: `variabili.sh`,
`condizioni1.sh`, `condizioni2.sh`, `cicli1.sh`, `select.sh`, `array.sh`, `read1.sh`, `read2.sh`.
Per esempi completi e funzionanti vedi [../zz-esempi/](../zz-esempi/).
