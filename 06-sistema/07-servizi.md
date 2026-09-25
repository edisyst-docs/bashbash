# Servizi, spegnimento e messaggi broadcast

## systemd
```bash
systemctl reload apache2  # ricarica la configurazione di Apache dopo aver modificato le conf dei sites
systemctl status apache2  # stato del servizio
systemctl restart apache2 # riavvio completo del servizio
```

```bash
systemctl enable --now nginx       # abilita all'avvio E avvia subito
systemctl disable --now apache2    # il contrario
systemctl is-active nginx          # stampa active/inactive: comodo negli script (con --quiet dà solo l'exit status)
systemctl is-enabled nginx         # partirà al boot?
systemctl --failed                 # servizi andati in errore
systemctl list-units --type=service --state=running # servizi in esecuzione
systemctl cat nginx                # mostra il file di unit (e gli eventuali override)
sudo systemctl edit nginx          # crea un override senza toccare il file originale del pacchetto
sudo systemctl daemon-reload       # obbligatorio dopo aver creato o modificato un file .service
```

## journalctl: i log di systemd
```bash
journalctl -u nginx                # tutti i log del servizio nginx
journalctl -u nginx -f             # in tempo reale, come tail -f
journalctl -u nginx -n 100 --no-pager # ultime 100 righe, senza paginazione (per gli script)
journalctl -u nginx --since '1 hour ago'
journalctl --since '2026-09-25 10:00' --until '2026-09-25 11:00'
journalctl -p err -b               # solo gli errori (priorità err e superiori) dall'ultimo boot
journalctl -b -1                   # log del boot PRECEDENTE: utile dopo un riavvio improvviso
journalctl -k                      # messaggi del kernel (come dmesg)
```

## Esempi pratici

### Un servizio systemd per i worker delle code di Laravel
Alternativa a supervisor: systemd lo avvia al boot e lo riavvia se muore.
File `/etc/systemd/system/laravel-queue.service`:
```ini
[Unit]
Description=Laravel queue worker
After=network.target mysql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/app
ExecStart=/usr/bin/php artisan queue:work --sleep=3 --tries=3 --max-time=3600
# riavvia sempre, anche quando esce "bene" per --max-time
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now laravel-queue
journalctl -u laravel-queue -f              # seguo i log del worker
sudo systemctl restart laravel-queue        # dopo ogni deploy, per caricare il codice nuovo
```

### Timer systemd: alternativa a cron
Due file: il `.service` dice COSA fare, il `.timer` QUANDO.
File `/etc/systemd/system/backup-db.service`:
```ini
[Unit]
Description=Backup database

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-db.sh
```
File `/etc/systemd/system/backup-db.timer`:
```ini
[Unit]
Description=Backup database ogni notte

[Timer]
OnCalendar=*-*-* 02:30:00
# se la macchina era spenta alle 02:30, lo esegue appena si riaccende
Persistent=true

[Install]
WantedBy=timers.target
```
```bash
sudo systemctl enable --now backup-db.timer
systemctl list-timers                       # tutti i timer, con prossima e ultima esecuzione
systemd-analyze calendar '*-*-* 02:30:00'   # verifica la sintassi di OnCalendar e mostra la prossima esecuzione
```
Rispetto a cron: log automatici in `journalctl -u backup-db`, recupero delle esecuzioni perse, niente sovrapposizioni.

## Spegnimento e riavvio
```bash
shutdown -r now # riavvia adesso
shutdown -h now # spegne  adesso
shutdown    now # UGUALE
shutdown  20:40 # spegne alle 20:40
shutdown -h +10 # spegne fra 10 min
shutdown -c     # annulla lo spegnimento programmato
```

## Messaggi agli altri utenti
```bash
sudo wall messaggio  # broadcast del messaggio a tutti gli utenti connessi
sudo write utente    # invio del messaggio a un solo utente
```
> Per testarli servono almeno 2 utenti loggati su 2 terminali diversi.

## Librerie di un eseguibile
```bash
ldd /bin/pwd /sbin/pwck # mostra le dipendenze di questi eseguibili, quali librerie servono per funzionare
ldconfig -p             # per ogni libreria stampa il path sul file system: i comandi sono tutti link simbolici
```

## Curiosità
```bash
cmatrix # inutile, è Matrix
```
