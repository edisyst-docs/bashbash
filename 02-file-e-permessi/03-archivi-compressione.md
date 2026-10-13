# Archiviazione e compressione

> **Laboratorio**: `./lab.sh 02`, poi `cd 03-archivi-compressione`. Cosa contiene: [lab/](lab/).

- **Archiviazione**: un file unico che ne contiene N più le cartelle (`tar`).
- **Compressione**: riduzione dello spazio occupato (`gzip`, `bzip2`, `xz`).

## Leggere un file compresso senza scompattarlo
```bash
cat  /var/log/apt/history.log      # legge un file di testo
zcat /var/log/apt/history.log.1.gz # legge un file compresso .gz senza scompattarlo
bzcat, xzcat                       # analoghi per file compressi .bz e .xz
```

## gzip e xz
```bash
gzip file1 file2   # SOSTITUISCE file1 e file2 con file1.gz e file2.gz compressi
zcat file1.gz      # non lo posso leggere con cat ma con zcat
gzip -l file1.gz   # dice quanto occupa da compresso e da scompattato
gunzip file1.gz    # SOSTITUISCE file1.gz compresso con file1 (INVERSO di gzip)

xz file1     # SOSTITUISCE file1 con file1.xz compresso (comprime più di gzip)
xz -l file1.xz # dice quanto occupa da compresso e da scompattato
xz -d file1.xz # SOSTITUISCE file1.xz compresso con file1 (INVERSO di xz)
```

## tar
```bash
tar -cvf archivio.tar file1 file2          # CREA (-c) VERBOSAMENTE (-v) il file chiamato (-f) archivio.tar NON COMPRESSO contenente file1 e file2
tar -xf  archivio.tar -C /destinazione     # ESTRAE (-x) il contenuto di archivio.tar in una cartella specifica (-C)
tar -cf  archivio.tar file1 directory1     # CREA (-c) un archivio contenente sia file che directory
tar -czf compresso.tar.gz file1 directory1 # COMPRIME l'archivio con gzip (-z), bzip2 (-j) o xz (-J)
tar -xzf compresso.tar.gz                  # ESTRAE (-x) un archivio COMPRESSO (-z) di tipo tar.gz
tar -tf  compresso.tar.gz                  # è come fare "ls -l" ma dentro un archivio compresso

du -sh compresso.tar.gz file1 directory1   # confronto quanto occupano tutti quegli elementi
```

## Esempi pratici
```bash
# backup datato di un progetto senza le cartelle rigenerabili
# $(date +%F) diventa la data ISO (es. 2026-10-13) e dà un nome diverso a ogni backup;
# --exclude va ripetuto per ogni pattern e saltare vendor, node_modules e .git riduce di molto la dimensione
tar -czf progetto_$(date +%F).tar.gz --exclude='vendor' --exclude='node_modules' --exclude='.git' progetto/ 

tar -tzf backup.tar.gz | grep '\.env$'                  # cerco un file dentro l'archivio senza estrarlo
tar -xzf backup.tar.gz progetto/.env                    # estraggo SOLO quel file (percorso esatto come mostrato da -t)
tar -xzf backup.tar.gz --wildcards '*.sql'              # estraggo solo i file che corrispondono al pattern
tar -xzf backup.tar.gz --strip-components=1 -C /tmp/x   # estraggo togliendo la prima cartella del percorso (progetto/app/... => app/...)

gzip -t backup.tar.gz && echo "archivio integro"        # verifica l'integrità senza estrarre
```

### Archivi in streaming (senza file temporanei)
Con `-f -` tar scrive su stdout o legge da stdin, quindi si può mettere in pipe.
```bash
# comprime in locale e scrive direttamente sul server remoto
# '-f -' = stdout, che ssh passa a cat; le virgolette singole fanno espandere $(date) sul server, non in locale
tar -czf - /var/www/app | ssh user@backup 'cat > /backup/app_$(date +%F).tar.gz'

# il contrario: scarica e scompatta al volo
# -C /var/www fa entrare tar in quella cartella: nell'archivio il percorso è app/..., non var/www/app/...
ssh user@server 'tar -czf - -C /var/www app' | tar -xzf - -C ./restore

# archivio spezzato in pezzi da 100 MB (es. limiti di upload)
# -b 100M = dimensione di ogni pezzo, il '-' dopo è stdin, part_ è il prefisso (part_aa, part_ab, ...)
tar -czf - dati/ | split -b 100M - dati.tar.gz.part_

# ricompone ed estrae
# il glob part_* è ordinato alfabeticamente, quindi i pezzi tornano nell'ordine giusto
cat dati.tar.gz.part_* | tar -xzf -

# archivia i log più vecchi di 7 giorni e li rimuove
# -T - legge l'elenco dei file da stdin, --null perché separati da NUL
# --remove-files cancella gli originali SOLO dopo averli archiviati: occhio, è irreversibile
find /var/log/app -name '*.log' -mtime +7 -print0 | tar -czf log_vecchi.tar.gz --null -T - --remove-files
```

### zip (per chi deve aprirli su Windows)
```bash
zip -r progetto.zip progetto/ -x 'progetto/vendor/*' 'progetto/.git/*' # zip ricorsivo escludendo cartelle
unzip -l progetto.zip                                                  # elenca il contenuto
unzip progetto.zip -d /tmp/estratto                                    # estrae in una cartella specifica
```
