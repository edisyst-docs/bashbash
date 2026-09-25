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

## Esempi pratici
```bash
[[ $EUID -eq 0 ]] || { echo "va lanciato come root" >&2; exit 1; }       # lo script richiede root
[[ $1 =~ ^[0-9]+$ ]] || { echo "'$1' non è un numero intero" >&2; exit 1; } # validazione con regex
[[ -z "${1:-}" ]] && { echo "manca il parametro" >&2; exit 1; }          # ${1:-} evita l'errore con set -u
if (( $(df --output=pcent / | tail -1 | tr -dc '0-9') > 90 )); then     # (( )) per i confronti numerici: niente -gt
    echo "disco / oltre il 90%"
fi
if ! command -v jq >/dev/null; then                                     # ! nega l'exit status del comando
    sudo apt-get install -y jq
fi
if systemctl is-active --quiet nginx; then echo "nginx su"; fi          # molti comandi hanno un'opzione "quiet" pensata per gli if

[[ "backup_2026-09-25.tar.gz" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]] && echo "anno ${BASH_REMATCH[1]}, giorno ${BASH_REMATCH[3]}" # gruppi di cattura
```
> **NOTA**: dentro `[[ ]]` la regex a destra di `=~` va scritta **senza apici**. Tra apici
> diventa una stringa letterale. Se è complessa, conviene metterla in una variabile: `[[ $x =~ $re ]]`.

### case con pattern multipli
```bash
case "${1,,}" in                         # ${1,,} = primo argomento in minuscolo: accetta Start, START, ecc.
    start|avvia)   systemctl start app ;;
    stop|ferma)    systemctl stop app ;;
    restart)       systemctl restart app ;;
    *.tar.gz|*.tgz) tar -xzf "$1" ;;      # i pattern sono glob, non regex
    [0-9]*)        echo "inizia con una cifra" ;;
    "")            echo "argomento mancante" ;;
    *)             echo "uso: $0 {start|stop|restart}"; exit 1 ;;
esac
```

Esempi eseguibili: [04-condizioni1.sh](04-condizioni1.sh), [04-condizioni2.sh](04-condizioni2.sh).
