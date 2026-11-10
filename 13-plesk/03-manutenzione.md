# Plesk: servizi, riparazioni, backup, log, sicurezza e API

> **Laboratorio**: `./lab.sh 13`, poi `cd 02-cli-hosting && ./crea-esempio.sh` (il sito `esempio.test` su cui si lavora qui). Dettagli in [lab/](lab/).

Quando un sito non risponde o la posta si ferma, in Plesk si ragiona su tre livelli, dal basso: il **servizio** (è acceso?), la **configurazione generata** (è a posto?), il **dato** nel database `psa` (è giusto?). Questa pagina è la cassetta degli attrezzi per tutti e tre, più backup, log, sicurezza e le API.

Gli esempi sono stati eseguiti nel laboratorio dell'area 13 (Plesk Obsidian 18.0.82, Ubuntu 24.04), con `esempio.test` già creato e `IP` impostato come in [02-cli-hosting.md](02-cli-hosting.md):
```bash
IP=$(plesk bin ipmanage --ip_list | awk 'NR==2 {split($3, a, /[:\/]/); print a[2]}')
```

## I servizi
```bash
plesk bin service --list                   # le chiavi dei servizi: web, smtp, imap-pop3, dns, nginx, fail2ban, plesk-php84-fpm, ...
plesk bin service --list -detail
# web          Apache                         is running  installed  httpd
# smtp         Postfix                        is running  installed  postfix
# imap-pop3    Dovecot IMAP and POP3 server   is running  installed  dovecot
# dns          BIND                           is running  installed  bind
# nginx        Nginx                          is running  installed  nginx
# fail2ban     fail2ban                       is running  installed  fail2ban
# plesk-php83-fpm  plesk-php83-fpm            is stopped  installed  plesk-php83-fpm        <- fermo: nessun sito usa PHP 8.3
# pop3 / imap (Courier), postgresql, spamassassin ... N/A  not installed
plesk bin service --status web             # is running
plesk bin service --restart web            # (anche --start, --stop)
```
Il vantaggio di `plesk bin service` rispetto a `systemctl restart apache2` è che Plesk sa **cosa va rigenerato** e in che ordine. Sotto, i servizi sono unit di systemd normali (`systemctl status apache2 nginx named postfix@- dovecot mariadb sw-cp-server sw-engine`), con una particolarità: il **pannello** è un nginx a parte (`sw-cp-server`, porta 8443) più `sw-engine` (il PHP del pannello). Se il pannello non si apre ma i siti sì, sono quei due.

Il database di Plesk e quelli dei clienti sono lo stesso MariaDB (`systemctl status mariadb`).

## `plesk repair`: il primo comando da lanciare
`plesk repair` controlla la configurazione e, con `-y`, **la ripara**. È lo strumento principale per tutto quello che è "generato" e potrebbe essere stato toccato o perso.
```bash
plesk repair --help
# Available aspects: all, mail, web, dns, ftp, fs, db, mysql, installation, sysusers.
# -y repara tutto quello che trova    -n solo controlla    -v più dettagli    -h aiuto sull'aspetto
plesk repair web -n                         # controlla la configurazione web (apache, nginx, PHP-FPM, certificati)
```
```
  Checking apache configuration ..................................... [OK]
  Checking nginx configuration ...................................... [OK]
Checking web server configuration. Please wait ...................... [OK]
Checking the usage of PHP handlers .................................. [OK]
Checking php-fpm configuration ...................................... [OK]
Error messages: 0; Warnings: 0; Errors resolved: 0
```
Gli aspetti:

| Aspetto | Cosa controlla |
|---|---|
| `web` | configurazione di apache e nginx, moduli, gestori PHP, PHP-FPM, certificati, rotazione dei log |
| `dns` | la configurazione di BIND e delle zone |
| `mail` | Postfix, Dovecot, la configurazione delle caselle |
| `db` | il database `psa`: struttura e coerenza |
| `sysusers` | gli utenti di sistema delle subscription (`mrossi` e i suoi permessi) |
| `fs` | i permessi e i proprietari dei file dei siti (**può durare a lungo**: non provato qui) |
| `installation` | l'installazione di Plesk (pacchetti, file del prodotto): non ha `-n`, solo la riparazione |
| `all` | tutto, in modo interattivo |

### Provarlo davvero: perdere un file generato
Si cancella la configurazione nginx del sito (`rm` di un file che Plesk ha generato) e si lascia che sia Plesk a segnalare e correggere:
```bash
rm /etc/nginx/plesk.conf.d/vhosts/esempio.test.conf
nginx -t                                  # ... syntax is ok       <- nginx NON si accorge di niente: il file semplicemente non c'è
plesk repair web -n
#   File not found: esempio.test.conf ............................................ [ERROR]
# Error messages: 1; Warnings: 0; Errors resolved: 0                                 <- exit code 1
plesk repair web -y
#   File not found: esempio.test.conf ............................................ [ERROR]
#     Repairing web server configuration for all domains. ........................ [FIXED]
# Error messages: 1; Warnings: 0; Errors resolved: 1
ls /etc/nginx/plesk.conf.d/vhosts/        # blog.esempio.test.conf  esempio.test.conf   <- ricreato
```
> **ATTENZIONE**: `nginx -t` e `apache2ctl configtest` verificano solo che la sintassi sia valida: un sito la cui configurazione è **sparita** non è un errore di sintassi. Il controllo che sa cosa dovrebbe esserci è `plesk repair web`.

Per rigenerare la configurazione senza il controllo completo si usa `httpdmng`, che fa solo quello:
```bash
plesk sbin httpdmng --reconfigure-domain esempio.test       # un sito
plesk sbin httpdmng --reconfigure-all                       # tutti (dopo un cambio di IP o di versione di PHP)
```
Entrambi tornano senza output se va bene. Chi ha modificato un file in `plesk.conf.d/` a mano lo perde con `--reconfigure-domain`: è proprio per questo che sono file "generati".

`plesk repair dns` e `plesk repair mail` fanno lo stesso per BIND e per la posta (`Repairing the mail server configuration ... [OK]`).

## Backup e ripristino
Il backup di Plesk è **logico**: raccoglie configurazione, file, database, caselle e DNS di un dominio, di un cliente o di tutto il server.
```bash
plesk bin pleskbackup --domains-name esempio.test -v
```
```
<execution-result log-location="/opt/psa/PMM/sessions/2026-11-10-122656.113/migration.result"
   local-dump-created="true" export-dump-created="false"
   local-dump-name="clients/mario/domains/esempio.test/backup_info_2611101226.xml"
   custom-log-file="/var/log/plesk/PMM/backup-2026-11-10-12-26-56-111/backup.log" status="success"/>
The backup finished successfully
```
- `--domains-name` fa il backup di uno o più domini; `--clients-name` di tutti i siti di un cliente; `--server` di tutto Plesk;
- l'archivio sta in `/var/lib/psa/dumps/clients/mario/domains/esempio.test/`: un file `backup_info_AAMMGGHHMM.xml` (l'indice) e vari `backup_*.tzst` (i dati: file, posta, configurazione, statistiche);
- `status="success"` e la riga finale dicono che è andato a buon fine; il dettaglio sta nel log indicato (`/var/log/plesk/PMM/.../backup.log`).

```bash
ls /var/lib/psa/dumps/clients/mario/domains/esempio.test/
# backup_apache-files_2611101226.tzst  backup_conf_2611101226.tzst  backup_domainmail_2611101226.tzst
# backup_info_2611101226.xml  backup_logs_2611101226.tzst  backup_user-data_2611101226.tzst  databases/  sites/ ...
B=/var/lib/psa/dumps/clients/mario/domains/esempio.test/backup_info_2611101226.xml
plesk bin pleskrestore --info "$B"
# Type: Domain      Date: 2611101226      Size: 53.2 K
# [Domain] esempio.test
plesk bin pleskrestore --check-backup "$B"
# The backup file is valid.
```
> **NOTA**: i backup locali stanno **sullo stesso disco** del server: non proteggono da un guasto del disco. Per i backup veri si usa un archivio remoto (FTP, un servizio di storage) o si copiano fuori `/var/lib/psa/dumps/` (`rsync`, [diff-e-rsync](../02-file-e-permessi/07-diff-e-rsync.md)). I backup programmati si impostano dal pannello o con `plesk bin scheduled-backup`.

### Ripristinare un file
Si cancella un file e lo si recupera dal backup, **solo quello**:
```bash
rm /var/www/vhosts/esempio.test/httpdocs/index.html
plesk bin pleskrestore --restore "$B" -only-web-content list:httpdocs/index.html -domain-name esempio.test
ls /var/www/vhosts/esempio.test/httpdocs/          # index.html è tornato (con il proprietario giusto, mrossi)
```
Il ripristino parziale (`-only-web-content`, `-only-mailnames`, `-only-databases`, `-only-dns-zones`, `-only-certificates`) non si combina con `-level`: una sola delle due famiglie per volta. `-level domains -filter list:esempio.test` ripristina tutto il dominio, `-configuration-only` solo la configurazione, `-content-only` solo i contenuti. Non stampa niente se va a buon fine.

> **ATTENZIONE**: un ripristino vero **sovrascrive** quello che c'è. Prima si guarda cosa contiene (`--info`, `--check-backup`) e si prova su un server di prova: un ripristino su un sito che nel frattempo è cambiato perde le modifiche successive al backup.

## Log
| Cosa | Dove |
|---|---|
| il pannello e i comandi `plesk bin` | `/var/log/plesk/panel.log` |
| i comandi di riparazione | `/var/log/plesk/repair.log`, `repairkit.log` |
| i backup | `/var/log/plesk/PMM/backup-.../backup.log` |
| gli accessi al sito | `/var/www/vhosts/system/DOMINIO/logs/access_log` e `access_ssl_log` (nginx in primo piano: `proxy_access_log`) |
| gli errori del sito (PHP incluso) | `/var/www/vhosts/system/DOMINIO/logs/error_log` |
| la posta | `/var/log/maillog` (Postfix, Dovecot, `plesk-sendmail`) |
| il web server del server | `/var/log/nginx/error.log`, `/var/log/apache2/error.log` |
| il pannello (nginx) | `/var/log/sw-cp-server/error_log`, `/var/log/plesk/sw-cp-server/` |

```bash
tail -3 /var/www/vhosts/system/esempio.test/logs/access_ssl_log
# 172.17.0.2 - - [10/Nov/2026:12:32:26 +0000] "GET / HTTP/1.1" 200 1771 "-" "curl/8.5.0"
tail -2 /var/log/plesk/panel.log
# [2026-11-10 12:32:43.278] 35481:... ERR [panel] [Action Log] Failed login attempt with login '<invalid>' from IP 127.0.0.1
plesk log panel.log                        # segue il log (come tail -f): plesk log NOMEFILE
```
`panel.log` ha anche messaggi `ERR` innocui. Un esempio visto nel laboratorio, con `domain --on` e `customer --off` quando esiste un sottodominio: `Attempt to change status of non-configured mail service. [domain_id = 2]`. Un `ERR` non è per forza un guasto: conta se accompagna un comando che è fallito.

Il formato dei log di accesso è quello **combinato** di nginx/apache: `awk '{print $9}' access_ssl_log | sort | uniq -c | sort -rn` dà i codici di risposta (vedi [stampa e taglia](../03-testo-e-regex/01-stampa-e-taglia.md)).

## Il database di Plesk
`plesk db` apre una console MariaDB già collegata a `psa`: serve per **guardare**, non per scrivere.
```bash
plesk db "select id, login, type from clients"
# | 1 | admin | admin  |
# | 2 | mario | client |
plesk db "select id, name, htype, status from domains"      # esempio.test  vrt_hst (hosting fisico)  0 (attivo)
plesk db "select dom_id, www_root from hosting"             # 1  /var/www/vhosts/esempio.test/httpdocs
plesk db -Ne "show tables" | wc -l                          # 170 tabelle: clients, domains, hosting, mail, data_bases, db_users, ...
```
Le tabelle che servono più spesso: `clients` (account), `domains` (domini e sottodomini), `hosting` (il sito fisico: cartella, utente), `mail` (caselle), `data_bases` e `db_users`, `Configurations` e `misc` (impostazioni). Tutto quello che si modifica passa da `plesk bin`: scrivere nelle tabelle a mano salta i controlli e i comandi che rigenerano la configurazione.

## Accesso al pannello e password
```bash
plesk login                                    # un link di accesso per admin, valido per un solo uso
# https://localhost/login?secret=cDLxSB4lLwICbxQkod_dMuxrdDOtiQmF9EKKsYdJ7lrKfWbu
# https://172.17.0.2/login?secret=cDLxSB4lLwICbxQkod_dMuxrdDOtiQmF9EKKsYdJ7lrKfWbu
plesk login mario                              # il link per il cliente mario (stesso formato)
plesk bin admin --get-login-link               # lo stesso link, dal comando
PSA_PASSWORD='Admin-Lab!2026x' plesk bin admin --set-admin-password -passwd ""
# The Plesk administrator's password was successfully updated.
```
Nel laboratorio il pannello è raggiungibile dal PC sulla porta **8443**: nel link, `https://localhost/` diventa `https://localhost:8443/` e il browser avvisa del certificato non attendibile (è autofirmato). Il link è **monouso** e scade: se non funziona se ne genera un altro. `plesk bin admin --force-admin-password-reset` impone il cambio al prossimo accesso. `admin --get-reset-link` **non** vale per l'amministratore (`The password reset link cannot be used to reset a Plesk administrator's password.`): per lui la strada è `--set-admin-password`.

> **ATTENZIONE**: chi ha il link ha il pannello. Non va incollato in chat o in un ticket: equivale alla password.

## Sicurezza
### fail2ban e il blocco degli IP
Plesk configura **fail2ban** con una serie di *jail* (una per servizio) e lo comanda con `ip_ban`:
```bash
plesk bin ip_ban --info
# Status                         active
# IP address ban period          600 seconds
# Time interval for detection of subsequent attacks 600 seconds
# The maximum number of failed login attempts 5
plesk bin ip_ban --jails
# ssh active, recidive, plesk-proftpd, plesk-postfix, plesk-dovecot, plesk-roundcube, plesk-apache,
# plesk-apache-badbot, plesk-panel, plesk-modsecurity, plesk-wordpress, plesk-mailconfig,
# plesk-permanent-ban, plesk-one-week-ban     (tutti active)
plesk bin ip_ban --trusted                     # gli indirizzi che non si bloccano mai: 127.0.0.1, gli IP del server, ...
plesk bin ip_ban --ban "203.0.113.7,plesk-apache"
# SUCCESS: The selected IP addresses were banned.
plesk bin ip_ban --banned
# Banned IP addresses:
# 203.0.113.7          plesk-apache
fail2ban-client status plesk-apache | tail -4          # Currently banned: 1 / Banned IP list: 203.0.113.7
plesk bin ip_ban --unban "203.0.113.7,plesk-apache"
```
Cinque tentativi falliti in dieci minuti bloccano l'IP per dieci minuti, in ogni jail. Per l'amministratore che si chiude fuori da solo: `--add-trusted "IP"` mette il proprio indirizzo nell'elenco degli esenti. Il comando agisce su fail2ban, quindi vale quanto in [firewall e hardening](../08-remoto-e-sicurezza/02-firewall-e-hardening.md); le jail con `-modsecurity` e `-wordpress` richiedono i rispettivi componenti.

### Il firewall
Plesk ha un'estensione **Firewall** che gestisce `iptables`/`ufw`; **non è inclusa** nell'immagine del laboratorio (`plesk bin extension --list` non la mostra). Le porte che il server deve esporre: `22` (ssh), `80`, `443`, `8443` (pannello), `25`, `465` (posta in uscita), `110`, `143`, `993`, `995` (caselle), `21` (FTP), `53` (DNS). Quello che non serve va chiuso, in particolare **`3306`**: MariaDB ascolta solo su `127.0.0.1`, ma una regola per aprirla (accessi remoti ai database) si decide caso per caso.

### Le estensioni
```bash
plesk bin extension --list
# configurations-troubleshooter - Configurations Troubleshooter
# default-login - Default Login Helper
# imunify360 - Imunify
# mfa - Multi-Factor Authentication (MFA)
# ntp-timesync - NTP Timesync
# plesk-sitejet - Sitejet Builder
# wp-toolkit - WP Toolkit
plesk ext wp-toolkit --list                    # i siti WordPress gestiti: vuoto, qui non ce ne sono
plesk ext wp-toolkit --help                    # backup, aggiornamenti, clonazione, sicurezza dei siti WordPress
```
Le estensioni aggiungono funzioni al pannello e hanno ciascuna la propria riga di comando (`plesk ext NOME`). Una a pagamento o non inclusa non compare in elenco.

### Cronologia delle configurazioni
`cfgmon` tiene la cronologia (con data) di alcuni file di configurazione importanti e permette di tornare indietro:
```bash
plesk bin cfgmon --list-all
#  TimeStamp             File path
#  2026-11-10 12:36:29   /etc/fail2ban/jail.local
plesk bin cfgmon -s /etc/fail2ban/jail.local         # tutte le revisioni
plesk bin cfgmon -f /etc/fail2ban/jail.local         # l'ultima
plesk bin cfgmon -w -r REVISIONE -f FILE             # ripristina una revisione (-N: senza backup del file attuale)
```

## Licenza e aggiornamenti
```bash
plesk bin keyinfo --list | head -8                   # la licenza: limiti (lim_dom, lim_cl, ...), data
# plesk_key_id: PLSK123417930000
# lim_date: 20261218
# lim_cl: 1            <- clienti
# lim_dom: 1           <- domini
plesk bin license -c; echo $?                        # 0: la licenza è valida
plesk installer list                                 # i componenti e le versioni disponibili (scarica gli elenchi: serve internet)
plesk installer update                               # aggiorna Plesk; plesk installer --help per aggiungere o togliere componenti
```
> **ATTENZIONE**: `plesk installer update` aggiorna un server **vero**: si fa dopo un backup (anche del server: `pleskbackup --server`) e con una finestra di manutenzione. Nel laboratorio non serve e non è stato provato (le immagini si aggiornano con un `pull` nuovo).

## Le API
Per gli script e i sistemi di fatturazione, Plesk offre due API: **REST** (`/api/v2/`) e **XML-RPC**. La REST si autentica con una **chiave segreta** legata a un indirizzo IP:
```bash
K=$(plesk bin secret_key --create -ip-address 127.0.0.1 -description "prova cli")
plesk bin secret_key --list
# Key ID: 2   Ip: 127.0.0.1   Description: prova cli   Login: admin
curl -sk -H "X-API-Key: $K" https://127.0.0.1:8443/api/v2/server
# { "platform": "Unix", "hostname": "localhost", "panel_version": "18.0.82", ... }
curl -sk -H "X-API-Key: $K" https://127.0.0.1:8443/api/v2/domains
# [ { "id": 1, "name": "esempio.test", "hosting_type": "virtual", "www_root": "/var/www/vhosts/esempio.test/httpdocs",
#     "aliases": [ { "name": "alias-esempio.test", ... } ] }, { "id": 2, "name": "blog.esempio.test", ... } ]
curl -sk -u 'admin:Admin-Lab!2026x' https://127.0.0.1:8443/api/v2/clients       # anche con utente e password
curl -sk -o /dev/null -w '%{http_code}\n' -H "X-API-Key: sbagliata" https://127.0.0.1:8443/api/v2/server     # 401
```
Una chiave **sbagliata** dà `401`. La chiave è valida **solo dall'IP indicato** (`-ip-address`) e per l'utente `-login` (default `admin`).

La REST espone anche tutta la riga di comando: `POST /api/v2/cli/NOME/call` con un JSON `{"params": [...]}` esegue `plesk bin NOME` e restituisce `stdout`, `stderr` e `code`:
```bash
curl -sk -H "X-API-Key: $K" -H 'Content-Type: application/json' \
     -d '{"params": ["--info", "esempio.test"]}' https://127.0.0.1:8443/api/v2/cli/domain/call
# {"code": 0, "stdout": "General\n=============================\nDomain ID: 1\nDomain name: esempio.test\n...", "stderr": ""}
# con un dominio inesistente: "code": 1, "stderr": "... Domain 'nonesiste.test' does not belong to any customer"
plesk bin secret_key --delete -key "$K"                          # revocare la chiave
```
Questo è quello che usano gli strumenti di provisioning: un sistema esterno che crea un cliente chiama `cli/customer/call` con gli stessi parametri di `plesk bin customer`.

> **ATTENZIONE**: una chiave API è una **password con tutti i poteri dell'utente** a cui è legata. Si limita a un IP, si tiene fuori dai repository e si revoca quando non serve più.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| un sito dà `503` (o `502`) | dominio o cliente **sospeso**, oppure PHP-FPM / apache fermo | `plesk bin domain --info DOM \| grep status`, `plesk bin service --status web`; `domain --on`; i log del sito |
| un sito appena creato non risponde | la configurazione si ricarica con un attimo di ritardo | aspettare 1-2 secondi; se persiste `plesk repair web -y` |
| il sito dà la pagina di default di Plesk | manca il contenuto in `httpdocs/` (c'è solo `index.html` generato) | caricare i file; se `index.html` è sparito: ripristino da backup |
| `no available resources of this type (...)` | limite del piano o della licenza esaurito | `service_plan --info`, `keyinfo --list` |
| `nginx -t` dice ok ma il sito non esiste | file generato perso | `plesk repair web -y`, poi `httpdmng --reconfigure-domain` |
| il pannello (8443) non si apre | `sw-cp-server` o `sw-engine` fermi, o 8443 chiusa dal firewall | `systemctl status sw-cp-server sw-engine`, `ss -tlnp \| grep 8443` |
| `Incorrect username or password` da `plesk login UTENTE` | l'utente non esiste (o ha un login diverso) | `plesk bin customer --list` |
| la posta si ferma / ritarda | coda piena, DNS che non risponde (SPF, DKIM) | `postqueue -p`, `tail /var/log/maillog`, `plesk repair mail` |
| un certificato non viene usato | assegnato ma il web server non l'ha ricaricato ancora | aspettare, o `httpdmng --reconfigure-domain`; `certificate --list -domain DOM` |
| un cron non parte | percorso relativo, versione PHP incompleta | `scheduler --run ID`, vedi [02-cli-hosting.md](02-cli-hosting.md) |
| i file di configurazione modificati a mano tornano com'erano | sono file generati | usare le impostazioni di Plesk; `plesk repair web` li rigenera |

Torna all'[indice dell'area](README.md)
