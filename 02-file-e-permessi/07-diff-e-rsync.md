# Confronto e sincronizzazione di file

## diff: differenze tra file (anche binari)
```bash
diff ../zz-sandbox/simile1.sh ../zz-sandbox/simile2.sh    # mostra le differenze tra i file
diff -y ../zz-sandbox/simile1.sh ../zz-sandbox/simile2.sh # mostra riga per riga, affiancate, evidenziando le differenze
diff -i file1 file2                                       # ignora le differenze di maiuscole/minuscole
diff -w file1 file2                                       # ignora gli spazi bianchi nelle differenze
diff -u file1 file2                                       # output più leggibile, è il formato usato dai sistemi di controllo versione

cmp file1.bin file2.bin                                   # confronta file byte per byte, ma si ferma alla prima differenza

comm ../zz-sandbox/simile1.sh ../zz-sandbox/simile2.sh    # 3 colonne: nella terza ci sono le righe in comune tra i due file
```

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
