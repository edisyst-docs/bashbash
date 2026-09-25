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

## Scheletro di uno script robusto
Base da cui partire per uno script "serio". Ogni riga ha un motivo preciso.
```bash
#!/usr/bin/env bash
set -Eeuo pipefail   # -e esce al primo comando fallito, -u errore se uso una variabile non definita,
                     # -o pipefail una pipeline fallisce se fallisce un comando qualsiasi,
                     # -E fa ereditare il trap ERR anche alle funzioni
IFS=$'\n\t'          # il word splitting avviene solo su a capo e tab, non sugli spazi (meno sorprese coi nomi file)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # cartella dello script, da qualunque cartella venga lanciato
LOG="/tmp/$(basename "$0" .sh).log"

log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }   # messaggio con timestamp a video e nel log
muori() { log "ERRORE: $*"; exit 1; }

TMPDIR_LAVORO=$(mktemp -d)                                 # cartella temporanea con nome univoco
pulizia() { rm -rf "$TMPDIR_LAVORO"; }
trap pulizia EXIT                                          # eseguita SEMPRE all'uscita: fine normale, errore o CTRL+C
trap 'muori "comando fallito alla riga $LINENO"' ERR       # dice dove si è rotto

[[ $# -ge 1 ]] || muori "uso: $(basename "$0") <cartella>"
[[ -d "$1" ]]  || muori "'$1' non è una cartella"

log "inizio elaborazione di $1"
# ... lavoro vero ...
log "fine"
```
> **NOTA**: `set -e` ha eccezioni poco intuitive (non scatta dentro gli `if`, nei `&&`/`||`, ecc.).
> Aiuta molto, ma non sostituisce il controllo esplicito dei comandi critici.

## Script di esempio
Gli script di questa cartella sono gli appunti in forma eseguibile: `variabili.sh`,
`condizioni1.sh`, `condizioni2.sh`, `cicli1.sh`, `select.sh`, `array.sh`, `read1.sh`, `read2.sh`.
Per esempi completi e funzionanti vedi [../zz-esempi/](../zz-esempi/).
