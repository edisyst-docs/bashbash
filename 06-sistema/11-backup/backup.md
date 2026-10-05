# Backup con restic

> **Laboratorio**: `./lab.sh 06`, poi `cd 11-backup`. Cosa contiene: [lab/](../lab/).

Un backup che non è mai stato ripristinato è una speranza, non un backup. Questa pagina usa **restic**: un programma
solo, repository cifrato, deduplicato e con snapshot, senza server da installare. Gli esempi sono stati eseguiti con la
versione 0.19.1 nel laboratorio dell'area 06.

## Prima del comando: cosa si vuole proteggere
- **RPO** (*recovery point objective*): quanti dati posso perdere. Un backup notturno vuol dire fino a 24 ore di lavoro
- **RTO** (*recovery time objective*): quanto posso restare fermo. Ripristinare 500 GB da un servizio remoto richiede ore
- **backup ≠ replica**: una replica (RAID, database secondario) copia anche l'errore, un `DROP TABLE` o un `rm -rf`. Il backup tiene
  le versioni passate
- **regola 3-2-1**: 3 copie dei dati, su 2 supporti diversi, di cui 1 fuori sede. Un repository sullo stesso disco del sito non
  protegge dal guasto del disco
- cosa salvare: dati e configurazione (`/srv/sito`, `/etc`, il dump del database). Cosa no: cache, log, `/proc`, ciò che si
  rigenera da solo

| Strumento | Cosa fa | Quando |
|---|---|---|
| `tar` | un archivio per volta, tutto o niente ([02-file-e-permessi](../../02-file-e-permessi/03-archivi-compressione.md)) | copie una tantum |
| `rsync` | copia la differenza, ma **sovrascrive**: non tiene le versioni vecchie ([07-diff-e-rsync](../../02-file-e-permessi/07-diff-e-rsync.md)) | specchio di una cartella |
| `restic` | snapshot incrementali, cifrati e deduplicati, su disco, SFTP o cloud | backup periodici con storico |
| `borg` | simile a restic; ha bisogno di `borg` anche sul server remoto, niente backend cloud nativi | server proprio via SSH |

## Installazione
```bash
restic version                     # restic 0.19.1 compiled with go1.26.4 on linux/amd64
sudo apt install restic            # Ubuntu 24.04: arriva la 0.16.4, funziona ma è vecchia
```
Per l'ultima versione si scarica il binario da https://github.com/restic/restic/releases, si controlla lo SHA-256 con il file
`SHA256SUMS` della release, si decomprime (`bunzip2`) e si copia in `/usr/local/bin`: è quello che fa il [Dockerfile](../../Dockerfile)
del laboratorio.

## Il repository
Il **repository** è la cartella (o il bucket) che contiene tutti gli snapshot, cifrati. Si indica con `-r` oppure con la
variabile `RESTIC_REPOSITORY`:

| Dove | Come si scrive |
|---|---|
| cartella locale o disco montato | `-r /backup/restic` |
| un altro server via SSH | `-r sftp:utente@host:/percorso/restic` |
| S3 e compatibili (MinIO, Wasabi) | `-r s3:https://s3.example.com/bucket` (con `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`) |
| Backblaze B2, Azure, Google Cloud | `-r b2:bucket:percorso`, `azure:contenitore:/`, `gs:bucket:/` |
| qualsiasi servizio di `rclone` | `-r rclone:remoto:percorso` |
| un `rest-server` HTTP | `-r rest:https://host:8000/` |

Provati nel laboratorio: cartella locale e `sftp:`. Gli altri backend si usano nello stesso modo, cambiano solo le credenziali.

### La password
Tutto è cifrato con una password: **se la perdi, i dati sono persi**, nessuno può recuperarli. Va conservata *fuori* dal
server che si salva (gestore di password, cassaforte), non solo accanto al repository. Restic la cerca in quest'ordine:
```bash
export RESTIC_PASSWORD_FILE=/etc/restic-password     # un file con la sola password: chmod 600, proprietario root
export RESTIC_PASSWORD_COMMAND='pass show backup'    # un comando che la stampa (gestore di segreti)
export RESTIC_PASSWORD=...                           # direttamente nell'ambiente: visibile in `ps e` e nei log, da evitare
```
Con `-p`/`--password-file FILE` si indica per una sola chiamata. Se non c'è nessuna delle tre restic la chiede a tastiera.
```bash
echo 'una-password-lunga-e-casuale' > /etc/restic-password; chmod 600 /etc/restic-password
export RESTIC_REPOSITORY=/backup/restic RESTIC_PASSWORD_FILE=/etc/restic-password

restic init                                    # crea il repository (una volta sola)
# created restic repository c0d666f679 at /backup/restic
RESTIC_PASSWORD=sbagliata restic snapshots     # Fatal: wrong password or no key found
```
Il repository non contiene nulla di leggibile: nomi dei file, cartelle e contenuti sono cifrati (`ls /backup/restic`
mostra solo `config data index keys locks snapshots`).

## Fare un backup
```bash
restic backup /srv/sito --tag sito
# no parent snapshot found, will read all files
# Files:           2 new,     0 changed,     0 unmodified
# Added to the repository: 108.405 KiB (28.333 KiB stored)
# snapshot 3ee6f0dd saved
```
Ogni `backup` crea uno **snapshot**: la fotografia della cartella in quel momento. È **incrementale** e **deduplicato**: restic
spezza i file in blocchi e ne salva uno solo per ogni contenuto, anche se compare in più file o più snapshot. Un secondo
backup senza modifiche non aggiunge nulla:
```bash
restic backup /srv/sito --tag sito
# using parent snapshot 3ee6f0dd
# Files:           0 new,     0 changed,     2 unmodified
# Added to the repository: 0 B   (0 B   stored)
```
Dopo aver cambiato un file e aggiunto un altro, nel repository finiscono 2 KiB, non 106 (`restic stats --mode raw-data`
mostra anche `Compression Ratio: 3.78x`: i dati sono compressi).

### Cosa escludere
```bash
restic backup /srv/sito --exclude=/srv/sito/cache --exclude='*.log'     # pattern sulla riga di comando
restic backup /srv/sito --exclude-file=/etc/restic-escludi              # un pattern per riga in un file
restic backup /srv/sito --exclude-caches                                # salta le cartelle con un file CACHEDIR.TAG
restic backup /srv/sito --exclude-larger-than 500M                      # salta i file più grandi
restic backup /srv/sito --one-file-system                               # non entrare in altri filesystem montati
restic backup --files-from /tmp/lista                                   # i percorsi da salvare, uno per riga
```
Prima di fidarsi di un'esclusione si guarda cosa farebbe, senza scrivere niente:
```bash
restic backup /srv/sito --exclude-file=/etc/restic-escludi --dry-run -vv | grep -E '^new|Files'
# new       /srv/sito/html/index.html, saved in 0.006s (14 B added, 96 B stored)
# new       /srv/sito/uploads/grande.txt, saved in 0.007s (106.342 KiB added, 26.762 KiB stored)
# Files:           2 new,     0 changed,     0 unmodified
```

### Salvare l'output di un comando (database)
Con `--stdin` restic salva ciò che arriva dalla pipe, senza file temporanei sul disco:
```bash
mysqldump --single-transaction --all-databases | restic backup --stdin --stdin-filename db.sql --tag mysql
restic dump latest db.sql --tag mysql | mysql          # il ripristino: dump stampa il file su stdout
```
Qui il dump è stato sostituito da un `echo` (il server MySQL è nel laboratorio dell'area 09): `restic dump latest db.sql --tag mysql`
ha restituito esattamente la riga salvata. Per PostgreSQL: `pg_dumpall | restic backup --stdin --stdin-filename pg.sql`.

## Guardare cosa c'è
```bash
restic snapshots                      # elenco degli snapshot
# ID        Time                 Host    Tags   Paths      Size
# 3ee6f0dd  2026-10-05 10:54:57  lab-06  sito   /srv/sito  106.355 KiB
# c10fbb91  2026-10-05 10:54:58  lab-06  sito   /srv/sito  106.355 KiB
# 345fca38  2026-10-05 10:54:59  lab-06  sito   /srv/sito  23 B
restic snapshots --tag mysql --compact   # solo con quel tag, senza i percorsi
restic snapshots --json                  # per gli script
restic ls latest                         # i file dell'ultimo snapshot (latest) o di uno preciso (ID)
restic find grande.txt                   # in quali snapshot compare un file
# Found matching entries in snapshot c10fbb91 from 2026-10-05 10:54:58
restic diff 3ee6f0dd 345fca38            # cosa è cambiato fra due snapshot
# M    /srv/sito/html/index.html
# +    /srv/sito/html/nuovo.html
# -    /srv/sito/uploads/grande.txt
restic stats                             # dimensione "da ripristinare"; --mode raw-data: quanto occupa il repository
```
`restic mount /mnt/backup` mostra gli snapshot come cartelle da sfogliare, ma serve FUSE: nel container del laboratorio non è
disponibile e non l'ho provato.

## Ripristinare
```bash
restic restore latest --target /tmp/ripristino                         # tutto l'ultimo snapshot
restic restore 3ee6f0dd --target /tmp/uno --include /srv/sito/uploads/grande.txt   # un solo file, da uno snapshot vecchio
restic dump latest /srv/sito/html/index.html                           # un file su stdout, senza scrivere sul disco
```
Restic ricrea il **percorso completo** sotto `--target`: il file arriva in `/tmp/ripristino/srv/sito/html/index.html`. Con
`--target /` rimette tutto dov'era, sopra l'esistente.

**Simulare un disastro** (il vero collaudo, da fare prima di averne bisogno):
```bash
rm -rf /srv/sito                          # il sito sparisce
restic restore latest --target /
# Summary: Restored 7 files/dirs (106.362 KiB) in 0:00
cat /srv/sito/html/index.html             # <h1>Il mio sito</h1>
```
I file in `cache/` e `*.log` non tornano: erano esclusi. Ripristinare **a mano**, su una macchina pulita e partendo dalla sola
password, è la prova che il backup serve davvero.

## Quanti snapshot tenere
Gli snapshot crescono a ogni backup. `forget` decide quali tenere con una **politica**, `prune` libera lo spazio dei dati che
nessuno snapshot usa più:
```bash
restic forget --keep-last 2 --dry-run          # PRIMA si guarda cosa succederebbe, senza toccare niente
# keep 2 snapshots:  c10fbb91 345fca38
# remove 1 snapshots:  3ee6f0dd
# Would have removed the following snapshots: {3ee6f0dd}
restic forget --keep-last 2 --prune            # poi si applica (--prune: libera lo spazio subito)
restic forget 3ee6f0dd                         # oppure un solo snapshot, per ID
```

| Opzione | Tiene |
|---|---|
| `--keep-last N` | gli ultimi N snapshot |
| `--keep-hourly/daily/weekly/monthly/yearly N` | l'ultimo di ognuna delle ultime N ore, giorni, settimane, mesi o anni |
| `--keep-within 30d` | tutti quelli degli ultimi 30 giorni |
| `--keep-tag TAG` | quelli con quel tag, qualunque sia la politica |

Una politica da server: `--keep-daily 7 --keep-weekly 4 --keep-monthly 6` (una settimana di giornalieri, un mese di settimanali,
sei mesi di mensili). Le opzioni **si sommano**: ciò che una di loro vuole tenere resta.

> **ATTENZIONE**: senza `--tag` né `--group-by` la politica si applica a ogni gruppo di snapshot con lo stesso host *e* gli
> stessi percorsi. Con più tag o più server nello stesso repository si indica `--group-by host,tags`, e si prova **sempre**
> con `--dry-run`: una politica sbagliata cancella davvero i backup, e `prune` non si annulla.

## Controllare che il repository sia sano
```bash
restic check                         # struttura: indici, snapshot, alberi (veloce)
# no errors were found
restic check --read-data             # legge e verifica OGNI blocco di dati: lento, scarica tutto da un repository remoto
restic check --read-data-subset=5%   # un campione a caso: un controllo completo a rate, ad esempio la domenica
```
Un blocco danneggiato (qui un byte alterato a mano in un file di `data/`) viene trovato solo da `--read-data`:
```bash
restic check --read-data
# pack eb990bf6... contains 2 errors: [blob ded6194a...: ciphertext verification failed ...]
# The repository contains damaged pack files. These damaged files must be removed to repair the repository.
# restic repair packs eb990bf6...
# restic repair snapshots --forget
# Fatal: repository contains errors
```
Il messaggio suggerisce i comandi di riparazione, nell'ordine:
```bash
restic repair index                          # ricostruisce l'indice dai file di dati
restic repair packs eb990bf6...              # rimuove il file danneggiato salvando ciò che si può
restic repair snapshots --forget             # riscrive gli snapshot che usavano i dati persi e toglie quelli vecchi
restic check --read-data                     # no errors were found
```
I **dati persi restano persi**: la riparazione toglie dal repository ciò che era rovinato, non lo ricostruisce. Gli snapshot
colpiti perdono quei file. Per questo serve una seconda copia (vedi sotto).

**Lock**: ogni operazione lascia un segno nel repository. Se un backup viene interrotto bruscamente il segno può restare:
`Fatal: unable to create lock ...`. Se si è sicuri che non giri nient'altro, `restic unlock` lo toglie.

## Chiavi e password
Un repository può avere più password (chiavi), tutte valide per gli stessi dati:
```bash
restic key list                                    # le chiavi; * indica quella in uso
restic key add --new-password-file /tmp/pw2        # aggiunge una password: es. una per l'amministratore di riserva
restic key passwd --new-password-file /tmp/pw3     # cambia la password della chiave in uso
restic key remove 90b73816                         # toglie una chiave (non si può togliere quella con cui si è entrati)
```
Così si cambia la password senza rifare i backup, e si revoca l'accesso a una persona senza toccare quella degli altri.

## La seconda copia (3-2-1)
`restic copy` copia gli snapshot da un repository a un altro, anche con password diverse, senza rileggere i file originali:
```bash
restic init --repo /backup/repo2 --from-repo /backup/restic --copy-chunker-params     # il secondo repo ha gli stessi parametri: la deduplica funziona
restic copy --from-repo /backup/restic -r /backup/repo2 --tag sito
# snapshot 07c549f5 saved, copied from source snapshot e7b1cd5c
# snapshot f4cea4c9 saved, copied from source snapshot 804aec9c
```
(Le password dei due repository vanno indicate con `--from-password-file` e `--password-file`, o con le variabili `RESTIC_FROM_*`.)
Il secondo repository sta su un altro disco, un altro server o un servizio cloud: ecco il "fuori sede". Quello via SSH si prova
subito nel laboratorio, che ha già `sshd`:
```bash
useradd -m salvataggi                                      # l'utente "backup" di Ubuntu esiste già: ne serve uno nuovo
ssh-keygen -q -t ed25519 -N '' -f /root/.ssh/id_ed25519     # la chiave di root...
install -d -m 700 -o salvataggi /home/salvataggi/.ssh && install -m 600 -o salvataggi /root/.ssh/id_ed25519.pub /home/salvataggi/.ssh/authorized_keys   # ...autorizzata
ssh-keyscan localhost >> /root/.ssh/known_hosts            # altrimenti: "Host key verification failed"
restic -r sftp:salvataggi@localhost:/home/salvataggi/restic init
restic -r sftp:salvataggi@localhost:/home/salvataggi/restic backup /srv/sito --tag sito
```
Per un server vero si usa una chiave dedicata, con un utente senza privilegi ([../../08-remoto-e-sicurezza/01-ssh.md](../../08-remoto-e-sicurezza/01-ssh.md)).

## Automatizzare
Un backup a mano non resta fatto a lungo. Lo script [restic-backup.sh](restic-backup.sh) fa un giro completo: backup, rotazione e
controllo a campione. Legge repository e password da `/etc/restic.env` ([restic.env.example](restic.env.example)):
```bash
cd ~/lab/11-backup
echo 'una-password-lunga-e-casuale' > /etc/restic-password; chmod 600 /etc/restic-password
install -m 755 restic-backup.sh /usr/local/bin/                   # lo script
cp restic-escludi /etc/                                           # cosa escludere
install -m 600 restic.env.example /etc/restic.env                 # dove sta il repository (chmod 600: contiene i riferimenti ai segreti)
restic-backup.sh                                                  # senza repository: si ferma e lo dice
# Fatal: repository does not exist: unable to open config file: stat /backup/restic/config: no such file or directory
RESTIC_REPOSITORY=/backup/restic RESTIC_PASSWORD_FILE=/etc/restic-password restic init
restic-backup.sh                                                  # 2026-10-05 11:00:11 backup OK: 1 snapshot
```
Lo script **non crea** il repository da solo: un percorso sbagliato in `RESTIC_REPOSITORY` produrrebbe in silenzio un
repository nuovo e vuoto, e il backup "riuscirebbe" salvando nel posto sbagliato.

### Con un timer systemd
Meglio di cron perché lo stato, i log e gli errori sono in `systemctl` e `journalctl` ([../07-servizi.md](../07-servizi.md)):
```bash
cp restic-backup.service restic-backup.timer /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now restic-backup.timer
systemctl list-timers restic-backup.timer
# NEXT                            LEFT LAST PASSED UNIT                ACTIVATES
# Mon 2026-10-05 11:02:00 UTC 1min 47s -         - restic-backup.timer restic-backup.service
journalctl -u restic-backup.service -o cat | tail -3
# 2026-10-05 11:02:03 backup OK: 2 snapshot
# restic-backup.service: Deactivated successfully.
```
Nella unit ci sono due righe che non si indovinano:
- `CacheDirectory=restic` e `Environment=RESTIC_CACHE_DIR=/var/cache/restic`: un servizio senza `User=` non ha `$HOME`, restic non sa
  dove tenere la cache e **fallisce** (`unable to locate cache directory: neither $XDG_CACHE_HOME nor $HOME are defined`). Da
  cron o da una shell non succede: succede solo quando si passa a systemd
- `Nice=10` e `IOSchedulingClass=idle`: il backup cede il passo al resto del server

Se qualcosa si rompe, systemd lo mostra. Qui la password è sparita:
```bash
systemctl start restic-backup.service        # Job for restic-backup.service failed because the control process exited with error code.
systemctl is-failed restic-backup.service    # failed
journalctl -u restic-backup.service -o cat | tail -2
# Fatal: Resolving password failed: Fatal: /etc/restic-password does not exist
# restic-backup.service: Failed with result 'exit-code'.
```
Un backup che fallisce in silenzio è peggio di nessun backup: va controllato. Per essere avvisati si aggiunge alla unit
`OnFailure=notifica@%n.service` (una unit che manda una mail o un messaggio), oppure si usa un servizio di *dead man's switch*
(healthchecks.io: il backup lo chiama a fine corsa e il servizio avvisa se la chiamata non arriva).

### Con cron
```bash
30 2 * * * flock -n /tmp/restic.lock /usr/local/bin/restic-backup.sh >> /var/log/restic-backup.log 2>&1
```
Come in [../09-crontab.md](../09-crontab.md): `flock -n` evita due backup contemporanei. Provato nel laboratorio con una riga ogni
minuto: `/var/log/restic-backup.log` si riempie di `backup OK`. Da `root` cron imposta `HOME=/root`, quindi la cache funziona; il
`PATH` invece è minimo (`/usr/bin:/bin`), per questo lo script lo imposta da sé: con restic in `/usr/local/bin` (come nel
laboratorio) altrimenti cron risponderebbe `restic: command not found`.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `Fatal: wrong password or no key found` | password sbagliata o chiave rimossa | controllare `RESTIC_PASSWORD_FILE`; dopo `key passwd` la vecchia non vale più |
| `Fatal: unable to open config file ... no such file` | il repository non c'è lì | `RESTIC_REPOSITORY` sbagliato, disco di backup non montato: **non fare `init`** prima di aver capito |
| `unable to locate cache directory` in una unit systemd | senza `User=` non c'è `$HOME` | `RESTIC_CACHE_DIR`, come nella unit di esempio |
| `subprocess ssh: Host key verification failed` con `sftp:` | il server non è in `known_hosts` | `ssh-keyscan host >> ~/.ssh/known_hosts` |
| `Fatal: unable to create lock in backend` | un'altra operazione in corso, o una interrotta male | aspettare; se non gira niente, `restic unlock` |
| il repository cresce senza fine | manca `forget --prune` | politica di rotazione nello script |
| `restore` non rimette un file | era escluso dal backup, o il percorso è sotto `--target` | `restic ls latest`, `restic find nome` |
| il backup di un database non si ripristina | si è salvato il file di dati in uso, non un dump | `mysqldump --single-transaction` o `pg_dump`, mai la cartella di un database acceso |
