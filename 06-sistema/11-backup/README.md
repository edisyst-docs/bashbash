# 11 - Backup con restic

| File | Contenuto |
|---|---|
| [backup.md](backup.md) | RPO, RTO e regola 3-2-1; repository e backend; backup, esclusioni, dump di database da stdin; snapshot, `diff`, `restore` e simulazione di un disastro; `forget` e `prune`; `check` e `repair`; chiavi; `copy` su un secondo repository; automazione con timer systemd e cron |
| [restic-backup.sh](restic-backup.sh) | Backup di `/srv/sito`: `backup`, rotazione (7 giornalieri, 4 settimanali, 6 mensili) e `check` a campione |
| [restic-backup.service](restic-backup.service), [restic-backup.timer](restic-backup.timer) | La unit e il timer systemd (nel laboratorio ogni 2 minuti, in produzione ogni notte) |
| [restic.env.example](restic.env.example) | Repository e file della password, letti dallo script (`/etc/restic.env`) |
| [restic-escludi](restic-escludi) | I pattern esclusi dal backup (`/etc/restic-escludi`) |

**Laboratorio**: `./lab.sh 06` dalla radice della KB, poi `cd 11-backup`. L'immagine contiene restic 0.19.1; `prepara.sh` crea il
"sito" in `/srv/sito` e copia qui i file. Dettagli in [../lab/](../lab/).

Torna a [../](../)
