# Parametri speciali

```bash
$0 # nome dello script eseguito
$1 # primo argomento dello script. A seguire $2, $3, ecc.
$# # numero degli argomenti passati allo script
$* # tutti gli argomenti come una singola stringa: "$*" equivale a "$1 $2 $3"
$@ # SIMILE, ma ogni argomento resta una stringa separata: "$@" equivale a "$1" "$2" "$3"

$$ # PID dello script in esecuzione
$! # PID dell'ultimo comando eseguito in background. Es: dopo "sleep 10 &", $! è il PID di sleep
$? # exit status dell'ultimo comando eseguito: 0 vuol dire SUCCESS
```

> **NOTA**: la differenza tra `"$*"` e `"$@"` conta solo quando sono fra doppi apici.
> Con `"$@"` un argomento che contiene spazi resta un argomento solo; con `"$*"` viene
> tutto appiattito in un'unica stringa.

Esempio pratico in [07-read2.sh](07-read2.sh).
