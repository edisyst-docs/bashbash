# Cicli

La condizione si scrive sempre in uno dei 3 modi: `[ condizione ]`, `[[ condizione ]]`, `test condizione`.

> **NOTA su IFS**: `IFS` (Internal Field Separator) ha 3 valori di default — newline, spazio e tab
> (`"\n \t"`) — e identifica i separatori fra parole quando bash divide una stringa.

## WHILE
Cicla finché la condizione è vera.
```bash
while condizione
do
    cmd1
    cmd2
done
```

## UNTIL
Contrario di WHILE: cicla finché la condizione è falsa.
```bash
until condizione
do
    cmd1
    cmd2
done
```

## FOR su una lista
```bash
for var in listaElementi
do
    cmd1
    cmd2
done
```

## FOR in stile C
```bash
for (( i=0; i<=10; i++ ))
do
    echo "valore di i: "$i
done
```

## SELECT: menu interattivo
Costruisce un menu numerato a partire da una lista e cicla finché non esce.
```bash
PS3="Scegli un'opzione: "
select vardir in $(ls -d ../sandbox/zz_esempi/*/)
do
    echo "Hai scelto la directory: $vardir"
    break
done
```

Esempi eseguibili: [05-cicli1.sh](05-cicli1.sh), [05-select.sh](05-select.sh).
