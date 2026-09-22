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

Vedi anche: [../04-processi/04-risorse.md](../04-processi/04-risorse.md) per `df` e `du`,
[../02-file-e-permessi/06-dd.md](../02-file-e-permessi/06-dd.md) per la copia a basso livello delle partizioni.
