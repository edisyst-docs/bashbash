# Condizioni

La condizione si può scrivere in 3 modi: `[ condizione ]`, `[[ condizione ]]`, `test condizione`.

## Test sui file
```bash
-e file          # se file esiste
-d file          # se file esiste ed è una directory
-f file          # se file esiste e non è speciale (dir, dev)
-s file          # se file esiste e non è vuoto
-x -r -w file    # se ho i diritti di esecuzione, lettura e scrittura del file
-O file          # se sono l'owner del file
-G file          # se un mio gruppo è il gruppo del file
file1 -nt file2  # se file1 è più nuovo  di file2 (data ultima modifica)
file1 -ot file2  # se file1 è più vecchio di file2 (data ultima modifica)
```

## Confronto fra numeri
```bash
-eq  # EQUAL          ==
-ne  # NOT EQUAL      !=
-gt  # GREATER THAN   >
-lt  # LESS THAN      <
-ge  # GREATER EQUAL  >=
-le  # LESS EQUAL     <=
```

## IF
```bash
if condizione
then
    cmd1
    cmd2
fi
```

Forma compatta con gli operatori di concatenazione:
```bash
[[ a > b ]] || echo "a viene prima di b"
[[ a = a ]] && echo "a è uguale ad a"
```
Vedi [../01-basi/07-concatenazioni.md](../01-basi/07-concatenazioni.md).

## CASE (funziona come lo switch)
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

Esempi eseguibili: [04-condizioni1.sh](04-condizioni1.sh), [04-condizioni2.sh](04-condizioni2.sh).
