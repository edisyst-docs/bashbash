#!/usr/bin/env bash
# restic-backup.sh - backup di /srv/sito con restic: backup, rotazione, controllo
#
# Legge repository e password da /etc/restic.env (RESTIC_REPOSITORY, RESTIC_PASSWORD_FILE).
# Il repository va creato una volta a mano con "restic init": se lo script lo creasse da solo, un
# RESTIC_REPOSITORY sbagliato produrrebbe in silenzio un repository nuovo e vuoto.
# Esce con un errore se un passo fallisce: systemd (o cron) se ne accorge e lo segnala.
set -euo pipefail
PATH=/usr/local/bin:/usr/bin:/bin           # cron parte con un PATH minimo (/usr/bin:/bin): restic può stare in /usr/local/bin

SORGENTE=/srv/sito
ESCLUDI=/etc/restic-escludi

[[ -r /etc/restic.env ]] || { echo "manca /etc/restic.env" >&2; exit 1; }
# shellcheck source=/dev/null
set -a; source /etc/restic.env; set +a      # set -a: le variabili del file diventano d'ambiente, le vede restic

restic backup "$SORGENTE" --exclude-file="$ESCLUDI" --one-file-system --tag sito --quiet

# rotazione: 7 giornalieri, 4 settimanali, 6 mensili; prune libera lo spazio dei dati non più usati
restic forget --group-by host,tags --tag sito --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune --quiet

# controllo: la struttura per intero e il 5% dei dati, scelto a caso a ogni giro
restic check --read-data-subset=5% --quiet
echo "$(date '+%F %T') backup OK: $(restic snapshots --tag sito --json | grep -o '"short_id"' | wc -l) snapshot"
