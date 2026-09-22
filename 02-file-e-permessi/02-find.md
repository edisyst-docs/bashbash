# find: cercare file e cartelle

> **SINTASSI**: `find [percorso] [opzioni] [criteri] [azione]`

**Opzioni**
- `-maxdepth` per decidere quanto andare in profondità con la ricerca
- `-regextype posix-basic`
- `-regextype posix-extended`

**Criteri**
- `-name "file*"` specifica un "wildcard pattern": cerca i file con nome fileXXXXX
- `-type`: f (regular file), d (directory), l (simlink)
- `-size`: c (1B), k (1KB), b (512B), M (1MB), G (1GB)

## Cercare per nome e proprietario
```bash
find . -name "long.txt" # cerca un file chiamato "long.txt" nella cartella corrente
find / -name config     # cerca file/folder chiamati esattamente "config" in tutto il disco (avrò errori di Permesso Negato)
find / -iname config    # UGUALE ma è case insensitive
find / -user edoardo    # cerca file/folder con owner="edoardo"

find / -name config   2>/dev/null # redirige l'output 2 (std_error) su /dev/null, per nascondere i Permesso Negato
find / -name '*.conf' 2>/dev/null # cerca tutti i file .conf dentro il disco
```

## Cercare per data di modifica
```bash
find / -mtime 0 2>/dev/null # cerca tutti i file modificati oggi
find / -mtime 1 2>/dev/null # cerca tutti i file modificati ieri (conteggio a giorni)
find / -mmin  4 2>/dev/null # cerca tutti i file modificati esattamente 4 minuti fa (conteggio a minuti)

ls -lht /etc/                                                  # raggruppo i file per data
find /etc/ -iname '*' -mtime +365 -exec ls -lhdt {} \;         # tutti i file più vecchi di un anno
find /etc/ -iname '*' -mtime +365 -exec ls -lhdt {} \; | wc -l # così li conto
find /etc/ -iname '*' -mtime -30  -exec ls -lhdt {} \;         # tutti i file modificati nell'ultimo mese
```

## Cercare per tipo, dimensione e permessi
```bash
find . -type d,l,b         # cerca solo le Directory, i Simlink e i Binary
find . -type f -size +500M # cerca tutti i file più grandi di 500 MB
find . -type f -perm 644   # cerca tutti i file con permessi 644

find /etc/ -iname '*' -size +4k # file MAGGIORI di 4 KB
find /etc/ -iname '*' -size -1k # file MINORI   di 1 KB
find /etc/ -iname '*' -size  1k # file ESATTAMENTE di 1 KB
find /etc/ -empty               # file vuoti, di esattamente 0 KB
```

## Limitare la profondità ed escludere
```bash
find /etc/ -iname '*.conf' | wc -l             # cerca dentro tutta la ramificazione di /etc/
find /etc/ -maxdepth 2 -iname '*.conf' | wc -l # cerca solo fino al livello 2
find /etc/ -maxdepth 1 -iname '*.conf' | wc -l # cerca solo al 1° livello, cioè dentro la sola /etc/

find . -type f ! -name "*.txt" | wc -l         # cerca solo file, ma escludendo tutti i .txt
```

## Combinazioni utili
```bash
find /lib/modules/$(uname -r)/ -iname "*xt*.ko*" # cerca nella cartella dei moduli del kernel in uso tutti i file che contengono "xt" nel nome e hanno estensione .ko*

find /cartella -type f | grep "config"           # cerca i file dentro /cartella e filtra quelli che contengono "config" nel percorso
```

## Azioni dirette
```bash
find . -name "test*" -ls     # esegue un ls su tutti gli elementi trovati
find . -name "test*" -delete # esegue un rm su tutti gli elementi trovati
```

## -exec: eseguire un comando su ogni risultato
> **SINTASSI**: `find [percorso] [criteri] -exec [comando] {} \;`
- `[criteri]`: condizioni per selezionare i file (es. `-name`, `-size`, `-type`)
- `{}` è il placeholder per il risultato di find
- `\;` è il terminatore del comando; con `+` invece i risultati vengono passati tutti insieme a una sola istanza del comando

```bash
find /home/ -iname config -exec ls -ldh {} \;         # cerca file/cartelle chiamate config e fa un ls SU CIASCUNA
find /home/ -iname config -type f -exec ls -ldh {} \; # cerca solo file
find /home/ -iname config -type d -exec ls -ldh {} \; # cerca solo le directory
```

```bash
find /etc/ -iname '*.conf' -exec cp {} /tmp/ \;    # copia tutti i file .conf dentro /tmp/
find /etc/ -iname '*.conf' -exec cp -i {} /tmp/ \; # UGUALE ma chiede conferma in caso di overwriting
find /etc/ -iname '*.conf' -exec cp {} /tmp/ +     # UGUALE ma copia tutti i file in un'unica istanza di cp
find /etc/ -iname '*.conf' | xargs cp -t /tmp/     # UGUALE ma con xargs (serve l'opzione cp -t in questo caso)

find /etc/ -iname '*.conf' -exec mv {} /tmp/ \;    # sposta tutti i file .conf dentro /tmp/

find /etc/ -iname '*.conf' -exec rm {} \;          # elimina tutti i file .conf, un'istanza di rm per file
find /etc/ -iname '*.conf' -exec rm {} +           # UGUALE ma elimina tutti i file in un'unica istanza di rm
```

```bash
find . -name "*.jpg" -exec cp {} /backup/images/ \; # copia tutti i file .jpg dentro /backup/images/
find /var -type f -name "*.conf" -exec ls -lh {} \; # lista tutti i file .conf dentro /var/

find /tmp -name "*.tmp" -exec rm -i {} \;           # elimina INTERATTIVAMENTE tutti i file .tmp dentro /tmp/
find . -name "*.log" -exec rm {} +                  # elimina tutti i file .log IN UN COLPO SOLO (più efficiente che file per file)
find /home -name "*.tmp" | xargs rm                 # UGUALE ma con xargs

find /cart -type f -mtime +7 -exec mv {} /cart/bkp/ \;     # sposta i file più vecchi di 7gg in una cartella di backup
find . -maxdepth 1 -iname "*.txt" -exec cp {} ./backup/ \; # copia i file .txt in una cartella di backup
find /var/www -type f -perm 644 -exec chmod 600 {} \;      # cerca i file con permessi 644 e li modifica in 600
```

## locate: alternativa più veloce
```bash
locate ".log" # PIÙ VELOCE di find: usa un DB indicizzato del file system, ma può restituire risultati obsoleti se il DB non è aggiornato
updatedb      # aggiorna il DB di locate
```
