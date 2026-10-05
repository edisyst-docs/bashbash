#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 06: sistema
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Quasi tutti i comandi dell'area agiscono sul sistema stesso (utenti, servizi, log): il container
# del laboratorio ha systemd e i servizi veri. Qui si preparano solo i file di supporto: unit
# systemd pronte da installare, script finti al posto di php/mysql, un crontab, la config di logrotate.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
AREA="$(dirname "$LAB_SRC")"
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md

# ---------------------------------------------------------------- 01-filesystem, 03-pacchetti-apt, 04-dischi, 06-rete-e-host
# si lavora direttamente sul sistema: le cartelle ci sono per coerenza con le altre aree
for s in 01-filesystem 03-pacchetti-apt 04-dischi 06-rete-e-host; do sezione "$s"; done

# ---------------------------------------------------------------- 02-utenti
sezione 02-utenti
ssh-keygen -q -t ed25519 -N '' -C "deploy@lab" -f id_ed25519_deploy  # la chiave "del PC" da autorizzare per l'utente deploy

# ---------------------------------------------------------------- 05-data-e-ora
sezione 05-data-e-ora
printf '#!/usr/bin/env bash\nsleep 2\necho "script finito"\n' > script.sh
printf '#!/usr/bin/env bash\necho "backup in corso..."\nsleep 3\necho "backup fatto"\n' > backup.sh
chmod +x script.sh backup.sh

# ---------------------------------------------------------------- 07-servizi
# Le unit del .md usano php e /var/www/app, che qui non ci sono: stessi file, con script finti al posto di artisan.
sezione 07-servizi
cat > finto-worker.sh << 'EOF'
#!/usr/bin/env bash
# finto-worker.sh - fa le veci di "php artisan queue:work": elabora un "job" ogni 3 secondi
echo "worker avviato come $(id -un), PID $$"
n=0
while true; do
    (( ++n ))
    echo "elaborato job $n"
    sleep 3
done
EOF
cat > laravel-queue.service << 'EOF'
[Unit]
Description=Laravel queue worker (finto)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/tmp
ExecStart=/usr/local/bin/finto-worker.sh
# riavvia sempre, anche quando esce "bene"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat > backup-db.sh << 'EOF'
#!/usr/bin/env bash
# backup-db.sh - al posto del dump MySQL archivia /etc: basta per vedere il timer al lavoro
set -euo pipefail
mkdir -p /backup
tar -czf "/backup/etc_$(date +%F_%H%M%S).tar.gz" /etc 2>/dev/null
echo "$(date '+%F %T') backup OK: $(ls /backup | wc -l) archivi"
EOF
cat > backup-db.service << 'EOF'
[Unit]
Description=Backup database

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-db.sh
EOF
cat > backup-db.timer << 'EOF'
[Unit]
Description=Backup ogni 2 minuti (nel .md: ogni notte alle 02:30)

[Timer]
OnCalendar=*:0/2
Persistent=true

[Install]
WantedBy=timers.target
EOF
chmod +x finto-worker.sh backup-db.sh

# ---------------------------------------------------------------- 08-tmux
sezione 08-tmux
cat > monitor.sh << 'EOF'
#!/usr/bin/env bash
# lo script del .md, con log che in questo container esistono davvero
S=monitor
tmux has-session -t "$S" 2>/dev/null && exec tmux attach -t "$S"

tmux new-session  -d -s "$S" -n log
tmux send-keys    -t "$S":log 'tail -f /var/log/syslog' C-m
tmux split-window -t "$S":log -h
tmux send-keys    -t "$S":log.1 'journalctl -u nginx -f' C-m
tmux split-window -t "$S":log.1 -v
tmux send-keys    -t "$S":log.2 'htop' C-m
tmux new-window   -t "$S" -n shell
tmux select-window -t "$S":log
tmux attach -t "$S"
EOF
chmod +x monitor.sh

# ---------------------------------------------------------------- 09-crontab
sezione 09-crontab
cat > crontab-esempio << EOF
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""

# ogni minuto una riga in orario.txt (con il percorso assoluto: cron parte dalla home)
* * * * * echo "Oggi è il giorno \$(date '+\%d-\%m-\%Y') e sono le ore \$(date '+\%H:\%M:\%S')" >> $DEST/09-crontab/orario.txt

# ogni 2 minuti, con flock per non sovrapporsi: in 07-servizi c'è lo script
*/2 * * * * flock -n /tmp/backup.lock /usr/local/bin/backup-db.sh >> /tmp/backup-db.log 2>&1
EOF

# ---------------------------------------------------------------- 10-logrotate
sezione 10-logrotate
cp "$AREA/10-logrotate/logrotate.sh" . && chmod +x logrotate.sh
cat > genera_log.sh << 'EOF'
#!/bin/bash

LOGFILE="/var/log/mio_test/app.log"

while true; do
    echo "$(date) - Questo è un messaggio di log" >> "$LOGFILE"
    sleep 1  # Scrive un log ogni secondo
done
EOF
cat > mio_test << 'EOF'
/var/log/mio_test/*.log {
    daily
    rotate 5
    size 100k
    compress
    missingok
    notifempty
    copytruncate
}
EOF
chmod +x genera_log.sh
seq 1 200 | sed 's/^/riga di log /' > /tmp/mylog 2>/dev/null || true   # il log su cui lavora logrotate.sh

# ---------------------------------------------------------------- 11-backup
# il "sito" da salvare: html e uploads contano, cache e log no
sezione 11-backup
cp "$AREA/11-backup/"{restic-backup.sh,restic-backup.service,restic-backup.timer,restic.env.example,restic-escludi} .
mkdir -p /srv/sito/{html,uploads,cache,log} 2>/dev/null || true
if [[ -d /srv/sito/html ]]; then
    echo '<h1>Il mio sito</h1>' > /srv/sito/html/index.html
    seq 1 20000 > /srv/sito/uploads/catalogo.txt
    echo 'file temporaneo' > /srv/sito/cache/pagina.tmp
    echo 'accesso di prova' > /srv/sito/log/accessi.log
fi

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 06 pronto in $DEST: una cartella per ogni .md"
    echo "Il container ha systemd: systemctl, journalctl, ssh, nginx, apache2 (porta 8080), cron, fail2ban"
    echo "Per ripartire da zero con i file: bash $LAB_SRC/prepara.sh"
fi
