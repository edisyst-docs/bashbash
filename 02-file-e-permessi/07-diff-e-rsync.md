# Confronto e sincronizzazione di file

## diff: differenze tra file (anche binari)
```bash
diff ../sandbox/simile1.sh ../sandbox/simile2.sh    # mostra le differenze tra i file
diff -y ../sandbox/simile1.sh ../sandbox/simile2.sh # mostra riga per riga, affiancate, evidenziando le differenze
diff -i file1 file2                                 # ignora le differenze di maiuscole/minuscole
diff -w file1 file2                                 # ignora gli spazi bianchi nelle differenze
diff -u file1 file2                                 # output più leggibile, è il formato usato dai sistemi di controllo versione

cmp file1.bin file2.bin                             # confronta file byte per byte, ma si ferma alla prima differenza

comm ../sandbox/simile1.sh ../sandbox/simile2.sh    # 3 colonne: nella terza ci sono le righe in comune tra i due file
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
