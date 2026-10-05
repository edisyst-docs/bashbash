# Storage avanzato: LVM, RAID, SMART, automount

> **Laboratorio**: `./lab.sh 06`, poi `cd 12-storage`. Cosa contiene: [lab/](lab/). Il container prova solo la prima metà (file immagine e
> filesystem): LVM, RAID e automount richiedono un kernel Linux vero, vedi [Dove si prova](#dove-si-prova).

[04-dischi.md](04-dischi.md) arriva fino al disco con una partizione e un filesystem. Qui si va oltre: unire più dischi in uno,
farli sopravvivere a un guasto, ingrandire un volume senza fermare il servizio, sapere in anticipo che un disco sta per morire.

```
disco  ──►  [partizione]  ──►  RAID (mdadm)  ──►  LVM (PV → VG → LV)  ──►  filesystem  ──►  mount
sdb, sdc                       md0                 /dev/vg0/dati           ext4, xfs         /srv/dati
```
Gli strati sono opzionali e si impilano: il filesystem non sa se sotto c'è un disco, un RAID o un volume LVM.

| Strumento | Risolve | Non risolve |
|---|---|---|
| **RAID** (`mdadm`) | il guasto di un disco senza fermare il servizio | un `rm -rf`, un ransomware, un incendio: **il RAID non è un backup** ([11-backup](11-backup/backup.md)) |
| **LVM** | volumi che si ingrandiscono, si spostano fra dischi, hanno snapshot | il guasto di un disco (non ha ridondanza propria) |
| **SMART** (`smartctl`) | accorgersi che un disco sta per rompersi | non è una garanzia: molti dischi muoiono senza preavviso |
| **automount** | montare un disco o una condivisione solo quando serve | |

## Dove si prova
Gli esempi sono stati eseguiti su un Ubuntu 24.04 vero (una VM di GitHub Actions, kernel 6.17) con `sudo`, usando **file al posto di
dischi**: nessun rischio per i dati.

| Cosa | Nel container del laboratorio | Su una VM Ubuntu |
|---|---|---|
| `mkfs`, `e2fsck`, `resize2fs`, `tune2fs` su un file immagine | sì | sì |
| `losetup`, `mount -o loop` | no: `losetup: cannot find an unused loop device` | sì |
| LVM | no: `device-mapper` non è utilizzabile | sì |
| RAID con `mdadm` | no: il kernel di Docker Desktop (WSL2) non ha il modulo `md` | sì |
| `smartctl` | no: non è installato e il container non ha dischi da leggere | sì (un disco virtuale risponde con dati finti) |
| autofs, `x-systemd.automount` | no: servono dispositivi e systemd | sì |

Per provarli sul proprio PC basta una VM Ubuntu 24.04 (VirtualBox, Hyper-V, Multipass): è un'immagine vecchia, si butta via.

> **ATTENZIONE**: `mkfs`, `pvcreate`, `mdadm --create` e `dd` **cancellano** ciò che c'è sul dispositivo indicato, senza chiedere conferma.
> Su un disco vero si controlla due volte il nome con `lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS` (un `sdb` può diventare `sdc` al riavvio).
> Negli esempi sotto i dischi sono `/dev/loop0`, `/dev/loop1`, ...: file da 200 MB.

## File immagine e loop device
Un file si può usare come un disco: è il modo di provare tutto senza hardware.
```bash
truncate -s 200M d1.img                 # un file "sparso": occupa spazio solo quando si scrive
L1=$(losetup -f --show d1.img)          # lo collega al primo /dev/loopN libero e stampa il nome: /dev/loop0
losetup -a                              # elenco dei loop attivi
# /dev/loop0: [66305]:12320772 (/lab/d1.img)
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS | grep -E 'NAME|loop'
# loop0         200M loop
losetup -d /dev/loop0                   # lo scollega (il file resta)
```
`mount -o loop disco.img /mnt` fa lo stesso in un passo solo, scollegando il loop quando si smonta.

## Filesystem su un file
Questi comandi funzionano anche nel laboratorio, perché lavorano sul file senza bisogno di loop:
```bash
truncate -s 64M disco.img
mkfs.ext4 -q -L dati disco.img                  # crea il filesystem con l'etichetta "dati"
dumpe2fs -h disco.img 2>/dev/null | grep -E 'volume name|Block count|Block size|Filesystem state'
# Filesystem volume name:   dati
# Filesystem state:         clean
# Block count:              16384
# Block size:               4096
blkid disco.img                                 # disco.img: LABEL="dati" UUID="..." TYPE="ext4"
e2fsck -f -p disco.img                          # controllo forzato (-f), riparazioni automatiche sicure (-p); si fa a filesystem SMONTATO
# dati: 11/16384 files (9.1% non-contiguous), 2065/16384 blocks
```
Ingrandire:
```bash
truncate -s 128M disco.img                      # prima si ingrandisce il "disco"...
resize2fs disco.img                             # ...poi il filesystem, che occupa tutto lo spazio nuovo
# The filesystem on disco.img is now 32768 (4k) blocks long.
tune2fs -L archivio disco.img                   # cambia l'etichetta (UGUALE: e2label disco.img archivio)
```
Popolare un filesystem da una cartella, senza montare niente:
```bash
mke2fs -q -t ext4 -d src -F pieno.img 8M        # crea pieno.img (8 MB) con dentro il contenuto di src/
debugfs -R "ls -l /" pieno.img                  # sfoglia il filesystem senza montarlo
debugfs -R "cat /numeri.txt" pieno.img | head -2
```
Su un disco vero ci sono le stesse operazioni: `mkfs.ext4 /dev/sdb1`, `e2fsck -f /dev/sdb1`, `resize2fs /dev/sdb1`.

### ext4 e xfs
| | ext4 | xfs |
|---|---|---|
| ingrandire | `resize2fs`, anche **montato** | `xfs_growfs`, solo **montato** |
| ridurre | sì, **smontato** | **mai**: non esiste il comando |
| controllare | `e2fsck -f` (smontato) | `xfs_repair` (smontato) |
| informazioni | `dumpe2fs -h`, `tune2fs -l` | `xfs_info /mount` |

```bash
truncate -s 300M xfs.img; mkfs.xfs -q -L xfsdati xfs.img           # xfs vuole almeno 300 MB
XL=$(losetup -f --show xfs.img); mount $XL /mnt/x                  # df: /dev/loop4  236M  20M  217M  9% /mnt/x
umount /mnt/x; losetup -d $XL
truncate -s 400M xfs.img                                           # il "disco" cresce...
XL=$(losetup -f --show xfs.img); mount $XL /mnt/x
xfs_growfs /mnt/x                                                  # ...e il filesystem lo segue
# data blocks changed from 76800 to 102400
# df: /dev/loop4  336M  22M  315M  7% /mnt/x
```
Un filesystem xfs sotto un LV si può ingrandire ma non ridurre: se serve più spazio ad altri volumi si deve ricreare e ricopiare.

## LVM: volumi flessibili
**LVM** (*Logical Volume Manager*) mette uno strato fra i dischi e i filesystem:
- **PV** (*physical volume*): un disco o una partizione dato a LVM
- **VG** (*volume group*): un "serbatoio" che mette insieme uno o più PV
- **LV** (*logical volume*): una fetta del VG, su cui si crea il filesystem. È il "disco" che si monta
- i dati sono divisi in **extent** (4 MB di default): un LV è una lista di extent presi dai PV

```bash
pvcreate /dev/loop0 /dev/loop1                  # i due dischi diventano PV
#   Physical volume "/dev/loop0" successfully created.
pvs                                             # elenco dei PV
#   PV         VG Fmt  Attr PSize   PFree
#   /dev/loop0    lvm2 ---  200.00m 200.00m
vgcreate vg0 /dev/loop0                         # un VG con il primo PV
vgextend vg0 /dev/loop1                         # ci aggiungo il secondo, anche a sistema in uso
vgs                                             #   vg0   2   0   0 wz--n- 392.00m 392.00m
lvcreate -L 150M -n dati vg0                    # un LV da 150 MB
#   Rounding up size to full physical extent 152.00 MiB
mkfs.ext4 -q /dev/vg0/dati                      # UGUALE: /dev/mapper/vg0-dati
mkdir -p /mnt/dati && mount /dev/vg0/dati /mnt/dati
```
Nome del dispositivo: `/dev/vg0/dati` e `/dev/mapper/vg0-dati` sono lo stesso LV (il secondo è quello che compare in `df` e `mount`).

### Ingrandire senza fermare niente
```bash
df -h /mnt/dati                                 # /dev/mapper/vg0-dati  127M  600K  116M   1%
lvextend -r -L +100M vg0/dati                   # +100 MB; -r ingrandisce anche il filesystem (resize2fs, xfs_growfs)
#   Size of logical volume vg0/dati changed from 152.00 MiB (38 extents) to 252.00 MiB (63 extents).
#   resize2fs: ... on-line resizing required ... The filesystem on /dev/mapper/vg0-dati is now 64512 (4k) blocks long.
df -h /mnt/dati                                 # /dev/mapper/vg0-dati  227M  600K  216M   1%
lvs -o lv_name,vg_name,lv_size,devices          # l'LV ora si estende su DUE dischi
#   dati vg0 252.00m /dev/loop0(0)
#   dati vg0 252.00m /dev/loop1(0)
```
Senza `-r` si ingrandisce solo l'LV, e il filesystem resta com'era finché non si lancia `resize2fs /dev/vg0/dati`.
`lvextend -l +100%FREE vg0/dati` prende **tutto** lo spazio libero del VG: è il comando per "ho aggiunto un disco, ora usalo".
Su un Ubuntu Server installato con LVM il volume radice si chiama di solito `ubuntu-vg/ubuntu-lv` (non provato qui).

### Snapshot: la fotografia di un volume
Uno **snapshot** conserva lo stato del volume in un momento; occupa solo lo spazio delle *differenze* (copy-on-write):
```bash
lvcreate -s -n snap -L 30M vg0/dati             # 30 MB per le modifiche che arriveranno
echo modificato > /mnt/dati/numeri.txt; echo extra > /mnt/dati/extra.txt
mount -o ro /dev/vg0/snap /mnt/snap
head -2 /mnt/snap/numeri.txt; ls /mnt/snap      # 1, 2 (il contenuto originale)  /  lost+found numeri.txt (extra.txt non c'è)
lvs -o lv_name,lv_size,origin,data_percent
#   dati 252.00m
#   snap  32.00m dati   0.05
umount /mnt/snap; lvremove -y vg0/snap          # a fine lavoro si toglie
```
`data_percent` indica quanto dello spazio dello snapshot è usato: **se arriva al 100% lo snapshot diventa inutilizzabile**. Va tenuto
per poco (una finestra di backup, un aggiornamento da provare), non come backup permanente. `lvconvert --merge vg0/snap` riporta il
volume allo stato dello snapshot.

### Spostare un volume da un disco a un altro
Il disco sta per rompersi, o va sostituito: i dati si spostano **a caldo**, con i filesystem montati:
```bash
pvs -o pv_name,pv_size,pv_used
#   /dev/loop0 196.00m 196.00m
#   /dev/loop1 196.00m  56.00m
pvmove /dev/loop0                               # sposta gli extent di loop0 sugli altri PV con spazio libero
#   Insufficient free space: 49 extents needed, but only 35 available     <- con due soli PV non c'era posto
vgextend vg0 /dev/loop2                         # aggiungo il PV nuovo...
pvmove /dev/loop0                               #   /dev/loop0: Moved: 100.00%
vgreduce vg0 /dev/loop0                         # ...e tolgo il vecchio dal VG
#   Removed "/dev/loop0" from volume group "vg0"
pvs -o pv_name,vg_name,pv_used
#   /dev/loop0          0
#   /dev/loop1 vg0  56.00m
#   /dev/loop2 vg0 196.00m
```
Il primo `pvmove` ha fallito con un messaggio chiaro: i PV di destinazione dovevano avere spazio per tutti gli extent da spostare.
Prima si aggiunge il disco nuovo, poi si sposta, poi si toglie il vecchio.

### Ridurre (solo ext4, solo smontato)
```bash
umount /mnt/dati
e2fsck -f -y /dev/vg0/dati                      # controllo obbligatorio prima di ridurre
lvreduce -r -y -L 100M vg0/dati                 # -r riduce prima il filesystem, poi l'LV
#   resize2fs ... Resizing the filesystem on /dev/mapper/vg0-dati to 25600 (4k) blocks.
#   Size of logical volume vg0/dati changed from 252.00 MiB (63 extents) to 100.00 MiB (25 extents).
```
> **ATTENZIONE**: ridurre un LV **senza** ridurre prima il filesystem (`lvreduce` senza `-r`, o un `lvreduce -L` su un filesystem pieno) taglia
> i dati: il filesystem si corrompe. Si riduce sempre con `-r`, o prima il filesystem e poi il volume. Ingrandire è invece sicuro.

### Il resto
```bash
vgdisplay vg0                                   # PE Size 4.00 MiB, Total PE 98, Alloc PE / Size 25 / 100.00 MiB, Free PE / Size 73 / 292.00 MiB
lvs -a                                          # tutti i volumi, anche quelli nascosti (snapshot, metadati)
lvremove -y vg0/dati && vgremove -y vg0 && pvremove -y /dev/loop0 /dev/loop1       # smontaggio ordinato: LV, VG, PV
```
Un LV si monta in modo permanente con una riga in `/etc/fstab`, come ogni dispositivo ([04-dischi.md](04-dischi.md)):
`/dev/vg0/dati  /srv/dati  ext4  defaults  0  2`.

## RAID software con mdadm
`mdadm` crea dischi RAID **in software**, gestiti dal kernel (`md`): nessuna scheda dedicata.

| Livello | Dischi | Capacità | Sopravvive a | Note |
|---|---|---|---|---|
| RAID 0 | 2+ | somma | **nulla**: un disco perso = dati persi | velocità, mai per dati importanti |
| RAID 1 | 2 | un disco | un disco | specchio: scrive lo stesso su entrambi |
| RAID 5 | 3+ | somma meno un disco | un disco | parità distribuita; scritture più lente |
| RAID 6 | 4+ | somma meno due dischi | due dischi | come il 5 con doppia parità |
| RAID 10 | 4+ | metà | un disco per coppia | specchi in striscia: veloce e sicuro |

```bash
cat /proc/mdstat                                # Personalities : [raid1] [raid4] [raid5] [raid6] / unused devices: <none>
mdadm --create /dev/md0 --level=1 --raid-devices=2 --run /dev/loop0 /dev/loop1
# mdadm: Defaulting to version 1.2 metadata
# mdadm: array /dev/md0 started.
cat /proc/mdstat
# md0 : active raid1 loop1[1] loop0[0]
#       203776 blocks super 1.2 [2/2] [UU]
```
Come si legge `/proc/mdstat`: `[2/2]` sono i dischi previsti e attivi; `[UU]` ha una `U` (*up*) per ogni disco funzionante. Un disco
perso diventa `[U_]`.

```bash
mdadm --detail /dev/md0
#         Raid Level : raid1
#         Array Size : 203776 (199.00 MiB 208.67 MB)
#              State : clean
#     Active Devices : 2
#     Failed Devices : 0
#     Number   Major   Minor   RaidDevice State
#        0       7        0        0      active sync   /dev/loop0
#        1       7        1        1      active sync   /dev/loop1
mkfs.ext4 -q /dev/md0 && mkdir -p /mnt/raid && mount /dev/md0 /mnt/raid     # poi si usa come un disco
```
`--detail` contiene anche `UUID` e `Name`, che identificano l'array.

### Un disco si rompe
Il caso per cui il RAID esiste. Simulato con `--fail`:
```bash
mdadm /dev/md0 --fail /dev/loop1                # lo segna guasto
# mdadm: set /dev/loop1 faulty in /dev/md0
cat /proc/mdstat
# md0 : active raid1 loop1[1]... loop0[0]        <- accanto a loop1 compare (F), "failed"
#       203776 blocks super 1.2 [2/1] [U_]       <- un disco solo, e i dati sono ancora tutti lì
mdadm /dev/md0 --remove /dev/loop1              # mdadm: hot removed /dev/loop1 from /dev/md0
mdadm --detail /dev/md0 | grep -E 'State|Active Devices'
#              State : active, degraded
#     Active Devices : 1
md5sum /mnt/raid/dati.txt                       # il file è leggibile e identico: c1d4ba52c72ac7bcc71ff2d6c083e684
```
Lo stato `degraded` significa "funziona, ma senza ridondanza": un secondo guasto fa perdere tutto. Si sostituisce il disco **subito**:
```bash
mdadm --zero-superblock /dev/loop1              # azzera i metadati RAID di un disco già usato (se riusato)
mdadm /dev/md0 --add /dev/loop2                 # mdadm: added /dev/loop2    -> parte la ricostruzione
cat /proc/mdstat                                # md0 : active raid1 loop2[2] loop0[0]   ...  [2/2] [UU]
```
Qui la ricostruzione è finita in un attimo (200 MB). Con dischi veri richiede ore: `cat /proc/mdstat` mostra una barra con
`recovery = 12.6%` e il tempo stimato. Si segue con `watch cat /proc/mdstat`.

### Rendere l'array permanente
```bash
mdadm --detail --scan                           # ARRAY /dev/md0 metadata=1.2 UUID=03006049:99475ed5:12cd8b7c:562a7553
mdadm --detail --scan >> /etc/mdadm/mdadm.conf  # lo registra: all'avvio il sistema riassembla l'array
mdadm --stop /dev/md0                           # lo ferma (smontare prima!)
mdadm --assemble --scan                         # lo riassembla leggendo i metadati dai dischi
# mdadm: /dev/md0 has been started with 2 drives.
```
Su un sistema vero, dopo aver modificato `mdadm.conf` si aggiorna l'initramfs (`update-initramfs -u`: non provato qui) perché
l'array sia disponibile già all'avvio. In `/etc/fstab` si usa l'UUID del filesystem (`blkid /dev/md0`), perché il nome `md0` può
cambiare (diventare `md127`).

### RAID 5
```bash
mdadm --create /dev/md1 --level=5 --raid-devices=3 --run /dev/loop0 /dev/loop2 /dev/loop3
# mdadm: /dev/loop0 appears to be part of a raid array: level=raid1 ...     <- dischi già usati: chiede conferma o --run
mdadm --detail /dev/md1 | grep -E 'Raid Level|Array Size|State :'
#         Raid Level : raid5
#         Array Size : 405504 (396.00 MiB 415.24 MB)         <- 3 dischi da 200 MB, ma 2 per i dati
#              State : clean
```

### Avvisi in caso di guasto
`mdadm --monitor` (come servizio `mdmonitor`, già installato con `mdadm`) manda una mail quando un disco esce dall'array: va configurato
`MAILADDR` in `/etc/mdadm/mdadm.conf`. Un RAID che si degrada senza che nessuno lo sappia è peggio di nessun RAID (non provato qui).

## SMART: la salute del disco
I dischi tengono un registro interno degli errori: **SMART**. `smartctl` (pacchetto `smartmontools`) lo legge.
```bash
smartctl --scan                                 # i dischi che trova
# /dev/nvme0 -d nvme # /dev/nvme0, NVMe device
smartctl -i /dev/sda                            # modello, seriale, firmware, capacità
smartctl -H /dev/sda                            # il verdetto
# SMART overall-health self-assessment test result: PASSED
smartctl -a /dev/sda                            # tutto: attributi, errori registrati, risultati dei test
smartctl -t short /dev/sda                      # avvia un test breve (pochi minuti), in background nel disco
smartctl -l selftest /dev/sda                   # i risultati dei test
```
Un esempio da un disco **virtuale** NVMe (una VM: i valori sono tutti zero, ma i nomi sono quelli veri):
```
=== START OF SMART DATA SECTION ===
SMART overall-health self-assessment test result: PASSED
SMART/Health Information (NVMe Log 0x02)
Critical Warning:                   0x00
Temperature:                        50 Celsius
Available Spare:                    0%
Percentage Used:                    0%
Data Units Written:                 0
Power On Hours:                     0
Unsafe Shutdowns:                   0
Media and Data Integrity Errors:    0
```
Un disco SATA o SAS mostra una tabella di **attributi** al posto di questo blocco; quelli che contano:

| Attributo | Significa | Allarme se |
|---|---|---|
| `Reallocated_Sector_Ct` (5) | settori danneggiati sostituiti da settori di riserva | cresce nel tempo |
| `Current_Pending_Sector` (197) | settori instabili in attesa di essere riallocati | maggiore di 0 |
| `Offline_Uncorrectable` (198) | settori che non si riescono a leggere | maggiore di 0 |
| `UDMA_CRC_Error_Count` (199) | errori sul cavo di collegamento | cresce: cavo o porta, non il disco |
| `Power_On_Hours` (9) | ore di accensione | informativo (età) |
| `Temperature_Celsius` (194) | temperatura | stabilmente oltre 55 °C |
| `Percentage Used` (NVMe) | usura rispetto alla vita prevista | vicino a 100% |
| `Media and Data Integrity Errors` (NVMe) | errori irrecuperabili | maggiore di 0 |

Per i dischi dietro un controller RAID hardware serve `-d` (`smartctl -a -d megaraid,0 /dev/sda`). Per controllare i dischi di continuo c'è
il servizio `smartd` (`/etc/smartd.conf`), che manda una mail quando un valore peggiora. Un disco con `Reallocated_Sector_Ct` che cresce,
o con `Current_Pending_Sector` maggiore di 0, si **sostituisce** anche se `PASSED`: il verdetto globale scatta tardi.

## Automount: montare quando serve
Una condivisione di rete o un disco esterno montati sempre in `/etc/fstab` bloccano l'avvio se non sono raggiungibili. Con l'**automount**
la cartella compare vuota e il montaggio avviene al primo accesso; dopo un po' di inattività si smonta da solo.

### autofs
```bash
sudo apt install autofs
echo '/mnt/auto  /etc/auto.lab  --timeout=5' > /etc/auto.master.d/lab.autofs     # cartella di base, mappa, timeout in secondi
echo 'dati  -fstype=ext4  :/dev/loop3' > /etc/auto.lab                          # chiave (sottocartella), opzioni, sorgente
systemctl restart autofs

ls /mnt/auto                                     # (vuota: "dati" non è ancora montata)
findmnt /mnt/auto/dati                           # nessun output: non è montata
ls /mnt/auto/dati                                # lost+found       <- l'accesso ha provocato il montaggio
findmnt /mnt/auto/dati
# TARGET         SOURCE     FSTYPE OPTIONS
# /mnt/auto/dati /dev/loop3 ext4   rw,relatime
# ... 8 secondi dopo: findmnt non stampa niente, si è smontata da sola
```
Per una condivisione NFS la riga della mappa è `docs  -fstype=nfs4,rw  server:/export/docs` (stessa struttura; non provata qui, serve un server NFS).
Con una mappa a caratteri jolly (`*  -fstype=nfs4  server:/home/&`) ogni sottocartella è una condivisione diversa, creata al volo.

### systemd automount
Senza installare nulla: bastano due opzioni in `/etc/fstab`.
```bash
mkdir -p /srv/sd
echo 'LABEL=auto /srv/sd ext4 noauto,x-systemd.automount,x-systemd.idle-timeout=5 0 0' >> /etc/fstab
systemctl daemon-reload
systemctl start srv-sd.automount                 # la unit è generata dalla riga di fstab
findmnt /srv/sd
# /srv/sd systemd-1 autofs rw,relatime,fd=78,pgrp=1,timeout=5,minproto=5,maxproto=5,direct,pipe_ino=25449       <- il "punto di aggancio"
ls /srv/sd                                       # lost+found       <- al primo accesso monta il disco vero
findmnt /srv/sd
# /srv/sd systemd-1  autofs ...
# /srv/sd /dev/loop3 ext4   rw,relatime          <- ora ci sono due righe: autofs sopra, ext4 sotto
# ... 8 secondi dopo: rimane solo la riga autofs
systemctl status srv-sd.automount                # Active: active (waiting) ... Got automount request for /srv/sd, triggered by 5203 (ls)
```
- `noauto`: non montare all'avvio, lo fa l'automount
- `x-systemd.automount`: crea la unit `.automount`
- `x-systemd.idle-timeout=5`: smonta dopo 5 secondi senza accessi (in pratica si usano minuti)
- `x-systemd.device-timeout=10s` e `nofail` evitano che un disco assente blocchi l'avvio
- i nomi delle unit seguono il percorso: `/srv/sd` diventa `srv-sd.mount` e `srv-sd.automount` (`systemd-escape -p --suffix=mount /srv/sd`)

> **ATTENZIONE**: in questa prova un punto di mount sotto `/mnt` falliva con `Dependency failed`: la VM di GitHub Actions monta già un disco su
> `/mnt` (dal suo `/etc/fstab`) e quel mount, sempre mancante, bloccava la dipendenza. Se un `.automount` non parte, si guarda
> `systemctl status` del `.mount` corrispondente e di quelli dei percorsi superiori.

Quale scegliere: **systemd automount** per un disco o una condivisione singola, perché non serve altro; **autofs** quando le
condivisioni sono tante, cambiano, o si vuole una mappa centralizzata (le home di una rete, via LDAP).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `e2fsck: need terminal for interactive repairs` | `e2fsck -f` vuole fare domande e non c'è un terminale (script, CI) | `-p` (riparazioni sicure automatiche) o `-y` (sì a tutto) |
| `resize2fs: Please run 'e2fsck -f' first` | ridurre senza controllare | `e2fsck -f` e poi di nuovo |
| `pvmove`: `Insufficient free space: N extents needed` | i PV di destinazione non hanno posto | `vgextend` con un disco nuovo prima di spostare |
| `vgreduce`: `Physical volume ... still in use` | il PV ha ancora extent assegnati | `pvmove` prima |
| `lvcreate`: `Volume group ... has insufficient free space` | il VG è pieno | `vgextend` con un altro PV, o un LV più piccolo |
| lo snapshot sparisce o diventa inutilizzabile | esaurito lo spazio (`data_percent` a 100) | snapshot più grande, e tenuto per poco |
| `mdadm: cannot open device ...: Device or resource busy` | il dispositivo è montato o già in un array | `umount`, `mdadm --stop`, `cat /proc/mdstat` |
| `/dev/md0` diventa `/dev/md127` al riavvio | array non registrato in `mdadm.conf` | `mdadm --detail --scan >> /etc/mdadm/mdadm.conf` e `update-initramfs -u` |
| array `degraded` | un disco è uscito | sostituirlo subito: `--remove` e `--add` |
| `smartctl`: `Smartctl open device: /dev/sda failed: No such device` | il dispositivo non c'è (VM, container, USB senza supporto SMART) | `smartctl --scan`; per le chiavette USB `-d sat` |
| `losetup: cannot find an unused loop device` | niente `/dev/loop*` (container senza accesso) | si prova su una VM |
| un `.automount` non parte: `Dependency failed` | un mount da cui dipende (anche un percorso superiore) è fallito | `systemctl status` delle unit `.mount` coinvolte |
