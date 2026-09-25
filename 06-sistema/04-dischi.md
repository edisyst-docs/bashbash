# Dischi e partizioni

## Montare e smontare
```bash
mount /dev/sda1 /mnt # monta il disco sda1 nella cartella /mnt
umount /mnt          # smonta il disco dalla cartella /mnt
```

## Vedere cosa è montato
```bash
mount             # mostra i dischi montati
mount | column -t # UGUALE, più leggibile
mount | grep sda1 # mostra solo il disco sda1

lsblk | grep -v loop    # mostra dischi/partizioni con l'alberatura: più dettagliato di mount
lsblk -f | grep -v loop # UGUALE ma mostra anche i punti di mount e il filesystem
```

## UUID e identificativi
```bash
blkid                   # mostra gli UUID dei dischi
blkid /dev/sda /dev/sdb # passando i dischi specifici fornisce info più dettagliate

ls -lh /dev/disk/by-uuid/ # mostra i dischi con i loro UUID
ls -lh /dev/disk/by-id/   # mostra i dischi con i loro ID
```

## Mount automatico all'avvio
```bash
cat /etc/fstab | grep -v '#'                   # mostra i dischi montati automaticamente all'avvio
cat /etc/systemd/system/snap-snapd-21759.mount # esempio di configurazione di un disco montato via systemd
```

## Esempi pratici
```bash
findmnt                          # albero dei mount: più leggibile di mount
findmnt -T /var/www              # su quale disco/partizione sta questa cartella
lsblk -o NAME,SIZE,FSTYPE,UUID,MOUNTPOINTS # solo le colonne che mi servono
sudo mount -o loop immagine.iso /mnt/iso   # monta un file .iso come se fosse un disco
sudo mount -o remount,ro /dati             # rimonta in sola lettura senza smontare
```

### Aggiungere un disco dati in modo permanente
```bash
lsblk                                            # 1. individuo il disco nuovo, es. /dev/sdb (senza partizioni)
sudo mkfs.ext4 -L dati /dev/sdb                  # 2. filesystem ext4 con etichetta "dati". ATTENZIONE: cancella tutto il contenuto
sudo mkdir -p /mnt/dati
sudo blkid /dev/sdb                              # 3. leggo l'UUID
echo 'UUID=xxxx-xxxx  /mnt/dati  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab # 4. uso l'UUID e non /dev/sdb: il nome può cambiare al riavvio
                                                                                       # nofail: se il disco manca la macchina si avvia lo stesso
sudo mount -a                                    # 5. monta tutto ciò che è in fstab: se dà errore lo scopro ORA e non al prossimo riavvio
findmnt /mnt/dati                                # 6. verifico
```

### Creare un file di swap
```bash
sudo fallocate -l 2G /swapfile                                # file da 2 GB
sudo chmod 600 /swapfile                                      # leggibile solo da root
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab    # permanente
swapon --show                                                 # verifico
```

Vedi anche: [../04-processi/04-risorse.md](../04-processi/04-risorse.md) per `df` e `du`,
[../02-file-e-permessi/06-dd.md](../02-file-e-permessi/06-dd.md) per la copia a basso livello delle partizioni.
