# Input e read

`read` legge una riga dallo standard input e la assegna a una o più variabili.
```bash
read var1 var2 var3  # legge una riga e la spezza in 3 variabili usando IFS come separatore
```

```bash
echo -n "Inserisci: " # -n evita l'a capo, così il cursore resta sulla stessa riga
read a b c
echo $a
```

Cambiando `IFS` cambio il separatore usato per spezzare l'input:
```bash
IFS=";"     # ora read spezza sui punto e virgola invece che sugli spazi
read a b c
```

Esempi eseguibili: [07-read1.sh](07-read1.sh), [07-read2.sh](07-read2.sh).
