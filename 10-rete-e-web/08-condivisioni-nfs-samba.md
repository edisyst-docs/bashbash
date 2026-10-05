# Condividere cartelle: NFS e Samba

> **Laboratorio**: `./lab.sh 10`. Il server è `web`, il client `host`. Dettagli e limiti dei container in [lab/](lab/).

Una cartella su un server, usata da altre macchine come se fosse locale. Due protocolli, per due mondi:

| | NFS | Samba (SMB/CIFS) |
|---|---|---|
| nasce in | Unix | Windows |
| client tipici | Linux, macOS, server | Windows, ma anche Linux e macOS |
| porta | 2049 (v4) | 445 |
| utenti | si fidano dell'**UID** numerico del client | utenti e password propri di Samba |
| quando | Linux ↔ Linux: home, dati condivisi fra server, volumi dei container | Linux ↔ Windows: la cartella dell'ufficio, `\\server\cartella` |

Gli esempi sono stati eseguiti nel laboratorio dell'area 10 (NFS: `nfs-kernel-server`, Samba 4.19). Il server NFS è del kernel: nel container funziona perché quello di Docker Desktop ha `nfsd`.

## NFS
### Il server
```bash
sudo apt install nfs-kernel-server
sudo mkdir -p /srv/nfs/dati
```
Cosa esportare e a chi lo dice `/etc/exports`: una riga per cartella, con **chi** (un indirizzo o una rete) e le **opzioni** fra parentesi, attaccate al client.
```bash
# /etc/exports
/srv/nfs/dati  10.10.1.0/24(rw,sync,no_subtree_check)
```
```bash
sudo exportfs -ra                 # rilegge /etc/exports (-r) e applica (-a)
sudo exportfs -v                  # cosa è esportato, con TUTTE le opzioni effettive (anche i default)
# /srv/nfs/dati   10.10.1.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
showmount -e web                  # dal client: l'elenco delle esportazioni di un server
# Export list for web:
# /srv/nfs/dati 10.10.1.0/24
```
| Opzione | Cosa fa |
|---|---|
| `rw` / `ro` | lettura e scrittura / sola lettura |
| `sync` | risponde "scritto" solo dopo aver scritto sul disco: più sicuro, più lento di `async` |
| `no_subtree_check` | non controllare che il file sia nella sottocartella esportata: meno problemi se un file viene rinominato |
| `root_squash` (default) | l'utente **root del client** diventa `nobody` sul server (UID 65534) |
| `no_root_squash` | root del client resta root sul server: **pericoloso**, solo se ci si fida dell'intera macchina client |
| `all_squash` | **tutti** gli utenti diventano `nobody` (con `anonuid=`/`anongid=` un altro utente) |
| `fsid=0` | marca la radice dell'albero NFSv4 (vedi sotto) |

### Il client
```bash
sudo apt install nfs-common
sudo mkdir -p /mnt/dati
sudo mount -t nfs -o vers=4.2 web:/dati /mnt/dati          # NFSv4: il percorso è relativo alla radice esportata (/dati)
mount | grep /mnt/dati
# web:/dati on /mnt/dati type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.1.10,local_lock=none,addr=10.10.2.10)
ls /mnt/dati ; echo da-host > /mnt/dati/da-host
```
**`root_squash` in azione**: root del client scrive un file, e sul server (e dal client) appartiene a `nobody`:
```bash
ls -ln /mnt/dati
# -rw-r--r-- 1 65534 65534 8 Oct  5 14:30 da-host          <- creato da root del client, ora è di "nobody"
# con no_root_squash nell'export, lo stesso file sarebbe  1 0 0 ...  (root)
```
**Gli UID devono coincidere.** NFS (con `sec=sys`) manda solo il numero: se `anna` è l'UID 1002 sul server e 1001 sul client, su `/mnt/dati` Anna del client scrive come l'utente 1001 del server,
che può essere un'altra persona. Gli account si allineano (stessi UID ovunque, o LDAP) oppure si usa Kerberos (`sec=krb5`).

### NFSv3 contro NFSv4
- **v3**: serve anche `rpcbind` (111) e altri servizi su porte variabili, e si monta con il percorso completo: `mount -t nfs -o vers=3 web:/srv/nfs/dati /mnt/dati`
- **v4**: una sola porta (**2049**), più facile con i firewall; il server presenta un albero con una **radice** (`fsid=0`), e i client montano percorsi relativi a quella radice

Nel laboratorio il server è un container, il cui disco è un `overlayfs`, che **non si può esportare** per NFS (`exportfs: /srv/nfs/dati does not support NFS export`, e per v4 `rpc.mountd: Cannot export /`).
Per questo la cartella è un filesystem a parte (un `tmpfs`) e per la v4 si usa lo schema classico con `bind mount` e radice `fsid=0`; su un server vero con `ext4` o `xfs` non serve:
```bash
# solo nel laboratorio, perché l'overlayfs non si esporta:
sudo mkdir -p /srv/nfs /srv/dati /srv/nfs/dati
sudo mount -t tmpfs -o size=64m tmpfs /srv/dati             # il "disco" dei dati
sudo mount -t tmpfs -o size=64m tmpfs /srv/nfs              # la radice esportabile
sudo mkdir /srv/nfs/dati && sudo mount --bind /srv/dati /srv/nfs/dati
cat <<'EOF' | sudo tee /etc/exports
/srv/nfs        10.10.1.0/24(ro,sync,no_subtree_check,fsid=0)
/srv/nfs/dati   10.10.1.0/24(rw,sync,no_subtree_check)
EOF
sudo exportfs -ra
```
I tentativi finiti male, per riconoscerli: `reason given by server: No such file or directory` (percorso v4 che non esiste nell'albero esportato), e `Read-only file system` quando la radice `ro` e la
cartella `rw` stanno nello **stesso** filesystem: per questo i dati sono in un `bind mount` di un altro.

### Montarlo sempre: `/etc/fstab`
```bash
echo 'web:/dati  /mnt/dati  nfs4  _netdev,rw  0  0' | sudo tee -a /etc/fstab
sudo umount /mnt/dati ; sudo mount -a ; findmnt /mnt/dati
# /mnt/dati nfs4 web:/dati
```
`_netdev` dice che è un filesystem di rete: va montato dopo che la rete c'è. Se il server è spento all'avvio, il boot può restare in attesa: con `x-systemd.automount` si monta alla **prima richiesta**
(vedi [../06-sistema/12-storage-avanzato.md](../06-sistema/12-storage-avanzato.md), `autofs` e automount), e `nofail` non blocca l'avvio se manca.
Un `mount` NFS è `hard` di default: se il server sparisce, i programmi che toccano la cartella **restano appesi** invece di dare errore (`soft` dà errore, ma rischia dati persi a metà).

Lato server: `sudo nfsstat -s` (contatori), `cat /proc/fs/nfsd/clients/*/info` (i client connessi: `address: "10.10.1.10:907"`, `name: "Linux NFSv4.2 host"`). Il firewall deve lasciar passare la 2049 per v4.

## Samba
### Il server
```bash
sudo apt install samba
samba --version                    # Version 4.19.5-Ubuntu
```
Samba ha i **propri utenti e password**, ma gli utenti devono esistere anche come utenti Linux (i file sono di un utente vero):
```bash
sudo groupadd ufficio ; sudo usermod -aG ufficio anna ; sudo usermod -aG ufficio marco
sudo mkdir -p /srv/smb/condivisa /srv/smb/pubblica
sudo chgrp ufficio /srv/smb/condivisa ; sudo chmod 2775 /srv/smb/condivisa     # il 2 = setgid: i nuovi file prendono il gruppo "ufficio"
echo listino | sudo tee /srv/smb/pubblica/listino.txt
sudo smbpasswd -a anna             # password SMB di anna (chiede due volte); -s legge da stdin, per gli script
sudo pdbedit -L                    # gli utenti Samba: anna:1002:
```
Le condivisioni sono sezioni di `/etc/samba/smb.conf`, in fondo al file:
```ini
[condivisa]
   path = /srv/smb/condivisa
   comment = Cartella dell'ufficio
   valid users = @ufficio          # solo il gruppo ufficio (@ = un gruppo)
   read only = no
   create mask = 0664              # permessi dei file creati
   directory mask = 2775

[pubblica]
   path = /srv/smb/pubblica
   guest ok = yes                  # senza password
   read only = yes
```
```bash
testparm -s                        # controlla la sintassi e mostra la configurazione effettiva (nessun errore = ok)
sudo systemctl restart smbd nmbd   # smbd: i file (445), nmbd: i nomi NetBIOS (137-139)
ss -tlnp | grep -E ':445|:139'     # LISTEN 0.0.0.0:445 ... smbd
```
### Il client
```bash
sudo apt install smbclient cifs-utils
smbclient -L web -N                # l'elenco delle condivisioni, senza password (-N)
#         Sharename       Type      Comment
#         ---------       ----      -------
#         print$          Disk      Printer Drivers
#         condivisa       Disk      Cartella dell'ufficio
#         pubblica        Disk
#         IPC$            IPC       IPC Service (web server (Samba, Ubuntu))
smbclient //web/pubblica -N -c ls                                 # anonimo, funziona
smbclient //web/condivisa -N -c ls                                # tree connect failed: NT_STATUS_ACCESS_DENIED
smbclient //web/condivisa -U anna%sbagliata -c ls                 # session setup failed: NT_STATUS_LOGON_FAILURE
smbclient //web/condivisa -U anna%anna -c 'put /tmp/p.txt p.txt; mkdir sub; ls; get p.txt /tmp/p2.txt'
# putting file /tmp/p.txt as \p.txt ...
#   p.txt                               A        6  Mon Oct  5 14:31:18 2026
```
Sul server il file è di `anna` e del gruppo `ufficio` (grazie al `setgid`), leggibile dagli altri dell'ufficio:
```bash
ls -ln /srv/smb/condivisa
# -rw-rw-r-- 1 1002 1004    6 Oct  5 14:31 p.txt
# drwxrwsr-x 2 1002 1004 4096 Oct  5 14:31 sub
sudo smbstatus                     # chi è connesso e a cosa, e i file bloccati
```
Per montarla come cartella: `mount.cifs`.
```bash
sudo mkdir -p /mnt/smb
sudo mount -t cifs //web/condivisa /mnt/smb -o username=anna,password=anna,vers=3.1.1
findmnt /mnt/smb                   # /mnt/smb cifs //10.10.2.10/condivisa
```
Sulla riga di comando la password si vede nei processi e nella history: in `/etc/fstab` si mette in un file con permessi `600` (`credentials=`):
```bash
printf 'username=anna\npassword=anna\n' | sudo tee /root/.smb-anna ; sudo chmod 600 /root/.smb-anna
echo '//web/condivisa  /mnt/smb  cifs  credentials=/root/.smb-anna,uid=1000,_netdev,vers=3.1.1  0  0' | sudo tee -a /etc/fstab
```
`uid=1000` fa apparire i file come dell'utente 1000 sul client (CIFS non ha gli UID di Unix: i permessi li decide il mount, `file_mode` e `dir_mode`).
Da un PC Windows: `\\web\condivisa` in Esplora file, o `net use Z: \\web\condivisa /user:anna` (non provato qui).

**Nel laboratorio** `mount.cifs` dà `Unable to apply new capability set.` se il container non ha anche `CAP_DAC_READ_SEARCH` (oltre a `SYS_ADMIN`): il `compose.yaml` del laboratorio 10 lo aggiunge al `host`.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `mount.nfs: access denied by server` | il client non è nell'`exports` (indirizzo o rete sbagliati) | `exportfs -v` sul server, `showmount -e server` dal client |
| `mount.nfs: ... No such file or directory` (v4) | il percorso non è relativo alla radice `fsid=0` | `exportfs -v`; con v3 il percorso è quello completo |
| `exportfs: ... does not support NFS export` | filesystem non esportabile (`overlayfs`, in un container) | un filesystem vero, o `fsid=` e un bind mount |
| i file creati appartengono a `nobody` | `root_squash` (è il default) | è la protezione; per un utente vero, UID uguali sul client e sul server |
| `Read-only file system` su una cartella `rw` | radice `ro` e cartella nello stesso filesystem | dati in un bind mount di un altro filesystem |
| il boot si ferma in attesa di un mount NFS | server spento, `hard` | `_netdev,nofail,x-systemd.automount` |
| `NT_STATUS_LOGON_FAILURE` | password SMB sbagliata, o l'utente non è in `pdbedit -L` | `smbpasswd -a utente` |
| `NT_STATUS_ACCESS_DENIED` su una condivisione | l'utente non è in `valid users`, o permessi Linux sulla cartella | `testparm -s`, `ls -ld`, `id utente` |
| i file creati sono illeggibili agli altri | mancano `create mask`/`directory mask` o il `setgid` | `chmod 2775` sulla cartella e le due direttive |
| `mount error(115)` / `Unable to apply new capability set` | nessun percorso verso il server, o capacità mancanti (container) | `ping`, `ip route`; nel container `CAP_DAC_READ_SEARCH` |
| Samba non vede più le modifiche a `smb.conf` | non ricaricato | `testparm`, poi `sudo systemctl reload smbd` |

Torna all'[indice dell'area](README.md)
