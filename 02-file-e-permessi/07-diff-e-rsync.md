# Confronto e sincronizzazione di file

> **Laboratorio**: `./lab.sh 02`, poi `cd 07-diff-e-rsync`. Cosa contiene: [lab/](lab/).

## diff: differenze tra file (anche binari)
```bash
diff simile1.sh simile2.sh    # mostra le differenze tra i file
diff -y simile1.sh simile2.sh # mostra riga per riga, affiancate, evidenziando le differenze
diff -i file1 file2           # ignora le differenze di maiuscole/minuscole
diff -w file1 file2           # ignora gli spazi bianchi nelle differenze
diff -u file1 file2           # output più leggibile, è il formato usato dai sistemi di controllo versione

cmp file1.bin file2.bin       # confronta file byte per byte, ma si ferma alla prima differenza

comm simile1.sh simile2.sh    # 3 colonne: nella terza ci sono le righe in comune tra i due file
```
> **NOTA**: `comm` si aspetta file ordinati. Su file non ordinati come questi avvisa con
> `comm: file 2 is not in sorted order` e le colonne possono essere sbagliate: vedi più sotto `comm <(sort ...)`.

## patch: applicare un diff
```bash
diff file1 file2 > diff.txt # salva le differenze in un file di testo
patch file1 diff.txt        # applica le differenze di diff.txt a file1, rendendolo uguale a file2
diff file1 file2            # verifico che ora sono uguali (ho trasformato file1 in file2)
```

## rsync: sincronizzare e trasferire
Trasferisce solo le differenze tra sorgente e destinazione.
```bash
rsync -azvP sorgente/ destinazione/  # ricorsivo, preserva permessi, comprime per risparmiare banda, verboso, con progress bar
rsync -azvP sorgente  destinazione   # senza lo / finale copia la cartella + il suo contenuto, altrimenti solo il contenuto
rsync -azvn sorgente  destinazione   # -n (oppure --dry-run) simula soltanto l'operazione, senza eseguirla
rsync --delete sorgente destinazione # in "destinazione" elimina ciò che non è presente in "sorgente". SINCRONIZZAZIONE
```

### Su host remoto via SSH
```bash
rsync -azv -e ssh /percorso/sorgente/ utente@host_remoto:/percorso/destinazione/          # da locale a remoto
rsync -avz -e ssh utente@host_remoto:/percorso/sorgente/ /percorso/destinazione/          # da remoto a locale
rsync -avz -e "ssh -p 225" utente@host_remoto:/percorso/sorgente/ /percorso/destinazione/ # UGUALE con porta diversa da 22
rsync -azv -e ssh utente@host_remoto:/home/utente/*.jpg ~/immagini/                       # da remoto solo i file jpg
```

### Escludere file
```bash
rsync -avz -e ssh --exclude='*.tmp' --exclude='cache/' ~/sito/ user@server:/web/ # escludo pattern specifici
rsync -avz -e ssh --exclude-from='escludi.txt' ~/dati/ user@server:/backup/      # uso un file coi nomi da escludere
```

## Esempi pratici
```bash
diff -rq cartella1/ cartella2/                                     # confronta due alberi di cartelle: elenca solo i file diversi o mancanti
diff <(ssh web1 cat /etc/nginx/nginx.conf) <(ssh web2 cat /etc/nginx/nginx.conf) # confronta lo stesso file su due server diversi
diff <(sort lista1.txt) <(sort lista2.txt)                         # confronta due liste ignorando l'ordine
comm -23 <(sort lista1.txt) <(sort lista2.txt)                     # righe presenti SOLO in lista1 (comm vuole input ordinati)
comm -12 <(sort lista1.txt) <(sort lista2.txt)                     # righe presenti in ENTRAMBE

cp config config.orig                                              # copia dell'originale, poi modifico config
diff -u config.orig config > modifiche.patch                       # salvo le modifiche come patch in formato unificato
patch --dry-run -p0 < modifiche.patch                              # su un'altra macchina (dove config è ancora l'originale) verifico che si applichi
patch -p0 < modifiche.patch                                        # la applico: modifica config
patch -R -p0 < modifiche.patch                                     # la annullo (reverse)
```


### Leggere cosa fa rsync: `-i`, `--stats`, `--progress`
Prova su una cartella di esempio (si crea con questi comandi, in qualsiasi cartella vuota):
```bash
mkdir -p sito/css sito/img sito/logs sito/.git
echo '<h1>ciao</h1>' > sito/index.html;  echo 'body{}' > sito/css/stile.css
head -c 20000 /dev/urandom > sito/img/foto.jpg;  head -c 3000000 /dev/zero > sito/dump.sql
echo log > sito/logs/app.log;  echo x > sito/.git/HEAD
```
```bash
rsync -ai sito/ copia/                # -i (--itemize-changes): una riga per ogni cosa che rsync fa
# cd+++++++++ ./                      <- cartella creata
# >f+++++++++ index.html              <- file copiato (+++ = nuovo)
rsync -ai sito/ copia/                # seconda volta: NESSUN output, è già tutto uguale
```
Dopo aver modificato `index.html`, aggiunto `nuovo.txt` e cancellato `logs/app.log` nella sorgente:
```bash
rsync -ain --delete sito/ copia/      # -n: solo simulazione
# >f.s....... index.html              <- la lettera dopo "f" dice COSA è cambiato: s = dimensione, t = data
# >f+++++++++ nuovo.txt
# *deleting   logs/app.log            <- verrebbe cancellato dalla destinazione per via di --delete
rsync -a --stats -h sito/ copia/      # riepilogo finale: file creati/cancellati/trasferiti, byte inviati
# Number of regular files transferred: 2
# Total file size: 3.02M bytes        <- quanto pesa tutto
# Total transferred file size: 17 bytes  <- quanto è stato DAVVERO trasferito: solo le differenze
rsync -a --info=progress2 sito/ copia/ # UNA sola barra di avanzamento per tutto il trasferimento (invece di una per file)
```

### Includere solo certi file
Le regole `--include`/`--exclude` si valutano **in ordine, vince la prima che corrisponde**: per tenere solo i `.jpg` bisogna lasciar passare le cartelle, poi i `.jpg`, poi escludere tutto il resto.
```bash
rsync -a --include='*/' --include='*.jpg' --exclude='*' sito/ soloimg/    # copia anche le cartelle vuote (css/, logs/, .git/)
rsync -am --include='*/' --include='*.jpg' --exclude='*' sito/ soloimg/   # -m (--prune-empty-dirs): niente cartelle vuote, resta solo img/foto.jpg
printf 'index.html\ncss/stile.css\n' > elenco.txt
rsync -av --files-from=elenco.txt sito/ da-elenco/                        # copia SOLO i percorsi (relativi a sito/) scritti in elenco.txt
rsync -avn --max-size=1M sito/ grandi/                                  # salta i file più grandi di 1 MB (dump.sql): nell'elenco resta foto.jpg; esiste anche --min-size
```

### Non perdere nulla: `--backup` e `--remove-source-files`
`--delete` e la sovrascrittura sono definitivi. Con `--backup-dir` rsync sposta lì i file che altrimenti perderebbe:
```bash
mkdir -p /backup/cestino                                                  # la cartella PADRE deve esistere (rsync crea solo l'ultimo livello)
rsync -a --delete --backup --backup-dir=/backup/cestino/$(date +%F) sito/ copia/
find /backup/cestino -type f
# /backup/cestino/2026-10-09/index.html    <- la versione che è stata sovrascritta
# /backup/cestino/2026-10-09/css/stile.css <- il file cancellato dalla sorgente
```
> **ATTENZIONE**: senza `mkdir -p` del padre rsync si ferma con `rsync error: error in file IO (code 11)`.

```bash
rsync -a --remove-source-files posta/ arrivo/     # SPOSTA invece di copiare: cancella dalla sorgente ogni file trasferito
find posta -type f | wc -l                        # 0: i file non ci sono più... ma le cartelle vuote restano (togli con: find posta -type d -empty -delete)
rsync -ai --ignore-existing posta/ arrivo/        # non tocca i file che esistono già in destinazione (anche se sono diversi)
rsync -au posta/ arrivo/                          # -u (--update): salta i file che in destinazione sono PIÙ RECENTI
```

### Il / finale, ancora una volta
```bash
rsync -ai sito  prog/    # senza / finale: crea prog/sito/ con tutto dentro
rsync -ai sito/ prog/    # con /: il CONTENUTO di sito finisce direttamente in prog/
```
Nella **destinazione** il `/` finale non cambia nulla: conta solo sulla sorgente.

### Remoto: provato con sshd su una porta diversa
Provati contro un `sshd` sulla porta 2222 in un container (`localhost`, qui con utente `root`; `--rsync-path="sudo rsync"` è il solo non provato):
```bash
rsync -az -e "ssh -p 2222" --exclude='.git/' --exclude='logs/' sito/ deploy@localhost:/srv/sito/  # porta diversa + esclusioni
rsync -az -e "ssh -p 2222 -o BatchMode=yes" sito/ deploy@localhost:/srv/sito/ # BatchMode: se serve una password FALLISCE subito invece di chiederla (indispensabile in cron)
rsync -az -e "ssh -p 2222" --rsync-path="sudo rsync" sito/ deploy@localhost:/etc/sito/ # sul server rsync parte con sudo: per scrivere dove l'utente non può (serve sudo senza password per rsync)
rsync -az -e "ssh -p 2222" --rsync-path="nice -n 10 rsync" sito/ deploy@localhost:/srv/sito/ # sul server a priorità bassa: non rallenta i servizi
```

### Codici di uscita (per gli script)
```bash
rsync -a nonesiste/ x/ ; echo "exit=$?"
# rsync: [sender] change_dir "/w/nonesiste" failed: No such file or directory (2)
# exit=23                                  <- 23 = trasferimento parziale, 24 = file spariti durante la copia, 12 = errore di protocollo, 30 = timeout
```
Negli script di backup controlla sempre `$?`: `0` è l'unico "tutto ok". `23` e `24` spesso si possono tollerare (file che cambiano mentre li copi, per esempio i log); gli altri no.
### Deploy con rsync
```bash
rsync -azn --delete --exclude-from=.rsyncignore ./ deploy@server:/var/www/app/ # PRIMA simulo (-n): vedo cosa verrebbe copiato ed eliminato
rsync -az  --delete --exclude-from=.rsyncignore ./ deploy@server:/var/www/app/ # poi eseguo davvero
rsync -azP --partial --bwlimit=5000 grosso.iso user@server:/tmp/               # file grande: riprende da dove si era interrotto, max ~5 MB/s
rsync -a --checksum src/ dst/                                                  # confronta il contenuto (hash) invece di data e dimensione: più lento ma sicuro
```
Esempio di `.rsyncignore`:
```
.git/
node_modules/
.env
storage/logs/*
```

### Backup incrementali a snapshot con hard link
Ogni giorno una cartella completa e navigabile, ma i file non modificati sono hard link a quelli
del giorno prima: occupano spazio solo i file cambiati. Vedi [04-link.md](04-link.md).
```bash
#!/bin/bash
SRC=/var/www/app/                    # lo / finale copia il contenuto, non la cartella
DEST=/backup/app
OGGI=$(date +%F)

rsync -a --delete \
    --link-dest="$DEST/ultimo" \
    "$SRC" "$DEST/$OGGI/"            # i file identici a quelli in "ultimo" diventano hard link

ln -sfn "$DEST/$OGGI" "$DEST/ultimo" # "ultimo" punta sempre allo snapshot più recente
find "$DEST" -maxdepth 1 -type d -name '20*' -mtime +30 -exec rm -rf {} + # tengo 30 giorni di snapshot
```
