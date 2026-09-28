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

> **Sicurezza**: il container non è `--privileged`. Ha solo `CAP_SYS_ADMIN` e il cgroup in scrittura, che servono
> a systemd, e **non vede i dischi** della macchina: `mkfs.ext4 /dev/sdb` risponde `The file /dev/sdb does not exist`.
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

Da sapere:
- `journalctl -p err -b` mostra degli errori `bpf-firewall: Attaching egress BPF program ... failed`: dipendono dal
  container, non da un problema dei servizi.
- `shutdown` e `systemctl poweroff` spengono davvero il container: il laboratorio si chiude. `shutdown -h +10` seguito
  da `shutdown -c` si può provare senza conseguenze.
- `resolvectl` e `netplan` non si possono provare: la rete del container la gestisce Docker.

Torna all'[indice dell'area](../README.md)
