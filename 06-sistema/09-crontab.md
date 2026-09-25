# Crontab

`crontab -e` apre (in EDIT MODE, tipicamente con VIM) il crontab dell'utente in corso

`crontab -e -u pippo` lo lancia root impersonando l'utente pippo, evidentemente perché l'owner non è root ma pippo

Usage: `crontab [-c DIR] [-u USER] [-ler]|[FILE]`

```bash
-c      Crontab directory
-u      User
-l      List crontab
-e      Edit crontab
-r      Delete crontab
FILE    Replace crontab by FILE ('-': stdin)
```

**Esempio**: aggiungo questo nel crontab per fargli scrivere ogni minuto una riga nel file prova:
```bash
* * * * * echo "Oggi è il giorno $(date '+%d-%m-%Y') e sono le ore $(date '+%H:%M:%S')" >> orario.txt
```

**Esempi**: https://crontab.guru/examples.html

## La sintassi dei 5 campi
```
┌──────── minuto        (0-59)
│ ┌────── ora           (0-23)
│ │ ┌──── giorno mese   (1-31)
│ │ │ ┌── mese          (1-12)
│ │ │ │ ┌ giorno sett.  (0-7, 0 e 7 = domenica)
│ │ │ │ │
* * * * * comando
```
```bash
*/5 * * * *    comando   # ogni 5 minuti
0 2 * * *      comando   # ogni giorno alle 02:00
30 8 * * 1-5   comando   # alle 08:30 dal lunedì al venerdì
0 */6 * * *    comando   # ogni 6 ore (00, 06, 12, 18)
0 3 1 * *      comando   # il primo del mese alle 03:00
@reboot        comando   # all'avvio della macchina
```

## Esempi pratici
Un crontab reale, con le intestazioni che evitano i problemi più comuni:
```bash
# ATTENZIONE: nelle righe di variabili cron NON accetta commenti in coda, andrebbero dentro il valore
# cron usa /bin/sh di default: niente sintassi bash
SHELL=/bin/bash
# il PATH di cron è minimo: molti "comando non trovato" nascono da qui
PATH=/usr/local/bin:/usr/bin:/bin
# non inviare mail con l'output
MAILTO=""

# scheduler di Laravel: un'unica riga, il resto si configura nel codice
* * * * * cd /var/www/app && php artisan schedule:run >> /dev/null 2>&1

# backup notturno, con log. flock -n impedisce che parta se il precedente è ancora in corso
30 2 * * * flock -n /tmp/backup.lock /usr/local/bin/backup-db.sh >> /var/log/backup-db.log 2>&1

# pulizia dei file temporanei più vecchi di 7 giorni, ogni domenica alle 04:00
0 4 * * 0 find /var/www/app/storage/tmp -type f -mtime +7 -delete

# data nel nome del file: in crontab il % va SEMPRE preceduto da backslash, altrimenti diventa un a capo
0 1 * * * tar -czf /backup/etc_$(date +\%F).tar.gz /etc 2>/dev/null
```

Script di backup MySQL con rotazione (`/usr/local/bin/backup-db.sh`):
```bash
#!/usr/bin/env bash
set -euo pipefail
DEST=/backup/mysql
GIORNI=14                                                # quanti giorni di backup tenere
mkdir -p "$DEST"

for db in $(mysql -N -e 'SHOW DATABASES' | grep -Ev '^(information_schema|performance_schema|mysql|sys)$'); do
    mysqldump --single-transaction --routines "$db" | gzip > "$DEST/${db}_$(date +%F_%H%M).sql.gz" # --single-transaction: dump coerente senza bloccare le tabelle InnoDB
done

find "$DEST" -name '*.sql.gz' -mtime +"$GIORNI" -delete # rotazione: elimino i backup vecchi
echo "$(date '+%F %T') backup OK"
```
Le credenziali vanno in `~/.my.cnf` (permessi 600) dell'utente che esegue il cron, non nello script:
```ini
[client]
user=backup
password=segreta
```

```bash
grep CRON /var/log/syslog | tail           # verifico che il cron sia partito (su Debian/Ubuntu)
journalctl -u cron --since today           # UGUALE su sistemi con systemd
```

Vedi anche: [07-servizi.md](07-servizi.md) per i timer di systemd, alternativa più moderna a cron.
