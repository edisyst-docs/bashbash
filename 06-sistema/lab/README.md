# Laboratorio dell'area 06

Quasi tutti i comandi di quest'area agiscono sulla macchina stessa: utenti, pacchetti, servizi, log, cron.
Per questo il laboratorio è un container con **systemd come PID 1** ([compose.yaml](compose.yaml)): `systemctl`,
`journalctl`, i timer e `timedatectl` funzionano come su un server vero. Girano già `ssh`, `nginx` (porta 80),
`apache2` (porta 8080, per non litigare con nginx), `cron`, `rsyslog` e `fail2ban`.

[prepara.sh](prepara.sh) aggiunge in `~/lab` i file di supporto: le unit del `.md` pronte da installare,
script finti al posto di `php artisan` e `mysqldump`, un crontab, la configurazione di logrotate.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 06               # la prima volta costruisce l'immagine bashbash-systemd (qualche minuto)
systemctl status nginx
```
All'uscita il container viene eliminato: utenti creati, servizi installati e crontab spariscono con lui.

> **Sicurezza**: il container non è `--privileged`. Ha solo `CAP_SYS_ADMIN` e AppArmor disattivato, che servono a
> systemd per rendere scrivibile il **proprio** cgroup (non quello della macchina), e **non vede i dischi** della macchina: `mkfs.ext4 /dev/sdb` risponde `The file /dev/sdb does not exist`.
> `lsblk` mostra comunque i dischi della VM di Docker, ma solo in lettura.

## Cosa si prova e dove

| Cartella | File pronti | Note |
|---|---|---|
| `01-filesystem/` | nessuno | si esplora `/` |
| `02-utenti/` | `id_ed25519_deploy` e `.pub` | nell'esempio dell'utente deploy, al posto di `echo "ssh-ed25519 AAAA..."` si usa `cat 02-utenti/id_ed25519_deploy.pub`; poi `ssh -i 02-utenti/id_ed25519_deploy deploy@localhost` entra davvero |
| `03-pacchetti-apt/` | nessuno | le liste dei pacchetti non ci sono: prima `apt update` (serve internet) |
| `04-dischi/` | nessuno | niente dischi da montare né swap (`swapon` risponde `Operation not permitted`). Per provare `mount`, `findmnt`, `remount,ro` si usa un tmpfs: `mkdir /mnt/dati && mount -t tmpfs -o size=20M tmpfs /mnt/dati` |
| `05-data-e-ora/` | `script.sh`, `backup.sh` | `timedatectl set-timezone` funziona; per `time ./script.sh` e `SECONDS` |
| `06-rete-e-host/` | nessuno | `ss -tulpn` mostra ssh, nginx e apache2; `nc -zv localhost 22` |
| `07-servizi/` | `laravel-queue.service` + `finto-worker.sh`, `backup-db.service` + `backup-db.timer` + `backup-db.sh` | le unit del `.md` con uno script al posto di php. `cp finto-worker.sh backup-db.sh /usr/local/bin/ && cp *.service *.timer /etc/systemd/system/`, poi come nel `.md`. Il timer scatta ogni 2 minuti invece che alle 02:30 |
| `08-tmux/` | `monitor.sh` | lo script del `.md`, con `/var/log/syslog` al posto del log di Laravel |
| `09-crontab/` | `crontab-esempio` | `crontab 09-crontab/crontab-esempio`: dopo un minuto compare `09-crontab/orario.txt`, e `grep CRON /var/log/syslog` mostra le esecuzioni |
| `10-logrotate/` | `genera_log.sh`, `mio_test` (la config), `logrotate.sh` | per `logrotate.sh` c'è già `/tmp/mylog` |
| `11-backup/` | `restic-backup.sh`, `.service`, `.timer`, `restic.env.example`, `restic-escludi` | i file del `.md`; in `/srv/sito` c'è il "sito" da salvare (html e uploads da tenere, cache e log da escludere). restic 0.19.1 è già nell'immagine; per provare `sftp:` basta il `sshd` del container |
| `12-storage/` | `src/` (due file da mettere in un'immagine con `mke2fs -d`) | si provano i filesystem su file (`mkfs.ext4`, `e2fsck`, `resize2fs`, `tune2fs`, `debugfs`). `losetup` risponde `cannot find an unused loop device`; LVM, RAID, `smartctl` e automount si provano su una VM Ubuntu (vedi il `.md`) |
| `13-esercizi/` | `risposte/`, `verifica.sh` | le risposte sono script in `risposte/NN.sh`; `./verifica.sh [N]` per ogni esercizio riporta il sistema allo stato di partenza, esegue la risposta, legge lo stato (utenti, mount, `systemctl`, journal, crontab...) e ripulisce; poi lo stesso con la soluzione di [soluzioni.sh](soluzioni.sh). **Agisce sul container: solo qui** |

Da sapere:
- `journalctl -p err -b` mostra degli errori `bpf-firewall: Attaching egress BPF program ... failed`: dipendono dal
  container, non da un problema dei servizi.
- `shutdown` e `systemctl poweroff` spengono davvero il container: il laboratorio si chiude. `shutdown -h +10` seguito
  da `shutdown -c` si può provare senza conseguenze.
- `resolvectl` e `netplan` non si possono provare: la rete del container la gestisce Docker.

Torna all'[indice dell'area](../README.md)
