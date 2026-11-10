# Plesk da terminale: clienti, siti, DNS, posta, database

> **Laboratorio**: `./lab.sh 13`, poi `cd 02-cli-hosting`. Dettagli in [lab/](lab/).

Tutto quello che si fa nel pannello si può fare con `plesk bin`: è la strada degli amministratori (si scrive in uno script, si ripete uguale su cento server) e dei provisioning automatici. Il modello di oggetti è in [01-introduzione.md](01-introduzione.md).

Gli esempi sono stati eseguiti nel laboratorio dell'area 13 (Plesk Obsidian 18.0.82, Ubuntu 24.04). Il sito di prova è `esempio.test`, del cliente `mario`. Lo script `crea-esempio.sh` fa in un colpo solo i passi delle prime sezioni, per chi vuole saltare alle altre pagine.

## Sintassi e convenzioni
```
plesk bin COMANDO --AZIONE [OGGETTO] [-opzione valore ...]
```
```bash
plesk bin customer --help             # ogni comando ha il proprio --help: azioni e opzioni
plesk bin customer --create mario ...
plesk bin customer --list
plesk bin customer --info mario
plesk bin customer --update mario -company "Rossi SRL"
plesk bin customer --remove mario
```
Quasi tutti i comandi seguono lo schema `--create`, `--update`, `--info`, `--remove`, `--list`. Le opzioni hanno **un solo trattino** (`-owner`, `-passwd`), anche se hanno il nome lungo. Un'opzione sbagliata dà `Unrecognized option: 'nome'`, un comando sbagliato `Unknown command: --list` (non tutti i comandi hanno tutte le azioni: `database --list` non esiste, per l'elenco si usa `plesk db`, vedi sotto).

### Le password: `PSA_PASSWORD`
Una password scritta nella riga di comando finisce nella cronologia della shell e in `ps`. I comandi che ne hanno bisogno la leggono dalla variabile **`PSA_PASSWORD`** quando l'opzione è vuota:
```bash
export PSA_PASSWORD='Pl3sk-Lab!2026x'     # nel laboratorio; in uno script vero, da un file o da un gestore di segreti
plesk bin customer --create mario -name "Mario Rossi" -email mario@example.test -passwd ""
# SUCCESS: Creation of customer account for 'mario' completed.
```
Le **password sono controllate** in base alla robustezza impostata sul server: una troppo semplice viene rifiutata. Per le password già cifrate esiste `PSA_CRYPTED_PASSWORD` con `-passwd_type encrypted`.

## Clienti
```bash
plesk bin customer --list                                    # admin / mario
plesk bin customer --info mario
```
```
General
=============================
Product version:                        Plesk Obsidian 18.0.82
Status:                                 OK On
Personal name:                          Mario Rossi
Username:                               mario
Provider's username:                    admin
Email:                                  mario@example.test
Creation date:                          2026-11-10
Domains
=============================
Disk usage:                             0 B
Active domains:                         0
...
```
`customer --off mario` sospende l'account **e con lui i suoi siti** (dopo un secondo `esempio.test` risponde `503`), `--on` li riattiva. Cambiare password o dati: `plesk bin customer --update mario -passwd "" -company "Rossi SRL"`.

> **NOTA**: nel laboratorio la licenza ammette **un solo cliente** (oltre ad `admin`): un secondo `customer --create` dà `There are no available resources of this type (clients) left. Requested: 1; available: 0.` Su un server con una licenza vera il limite è molto più alto, o assente.

## Service plan e subscription
Il piano è un modello di limiti: `Default Domain` esiste già.
```bash
plesk bin service_plan --info "Default Domain"
```
```
Limits
================================================
Domains                                         10
Subdomains                                      Unlimited
Disk space                                      10 GB
Traffic                                         100 GB/month
Databases                                       10
Mailboxes                                       100
Mailbox size                                    100 MB
...
Physical hosting
================================================
SSL/TLS support                                 true
Permanent SEO-safe 301 redirect from HTTP to HTTPS true
```
Una **subscription** nasce da un cliente, un piano e un indirizzo IP. L'IP è quello del container (`plesk bin ipmanage --ip_list`; negli esempi `172.17.0.2`, il tuo può essere un altro, per questo si legge con il comando):
```bash
plesk bin ipmanage --ip_list
# State Type IP                          Clients Hosting PublicIP
# 0     S    eth0:172.17.0.2/255.255.0.0 0       0
IP=$(plesk bin ipmanage --ip_list | awk 'NR==2 {split($3, a, /[:\/]/); print a[2]}')    # 172.17.0.2
plesk bin subscription --create esempio.test -owner mario -service-plan "Default Domain" \
      -ip "$IP" -login mrossi -passwd ""
# SUCCESS: Creation of domain 'esempio.test' completed.
```
`-login mrossi` è l'**utente di sistema** della subscription, quello che si usa anche per FTP (e per SSH, se abilitato): è il proprietario dei file del sito.
```bash
plesk bin subscription --list            # esempio.test
plesk bin domain --list                  # esempio.test
ls -ld /var/www/vhosts/esempio.test /var/www/vhosts/esempio.test/httpdocs
# drwx--x--- 4 mrossi psaserv 4096 ... /var/www/vhosts/esempio.test
# drwxr-x--- 2 mrossi psaserv 4096 ... /var/www/vhosts/esempio.test/httpdocs
```
Plesk ha già preparato `httpdocs/index.html` (la pagina "Domain Default page") e ha scritto la configurazione di nginx, apache, BIND e Postfix. Il sito risponde subito (senza DNS vero, si indica a `curl` dove andare con `--resolve`):
```bash
curl -sI --resolve esempio.test:80:$IP http://esempio.test/ | head -1
# HTTP/1.1 301 Moved Permanently       <- il piano ha "redirect da HTTP a HTTPS"
curl -skI --resolve esempio.test:443:$IP https://esempio.test/ | head -1
# HTTP/1.1 200 OK
```
`domain --info esempio.test` riassume tutto: stato, limiti, FTP, PHP, caselle, certificato. Le opzioni importanti per cambiare un sito sono `domain --update` (comuni) e `site --update` (il sito web).

> **ATTENZIONE**: i comandi che creano oggetti (`subscription --create`, `mail --create`, `site --update`) **tornano subito**, ma le configurazioni di nginx e apache si rigenerano e si ricaricano **un attimo dopo**. Uno script che fa `curl` subito dopo vede ancora la situazione vecchia: aspettare un secondo o due.

> **NOTA**: oltre al limite sui domini, nel laboratorio un secondo sito dà `site --create secondo.test ...` → `There are no available resources of this type (domains) left.` (sottodomini e alias non contano).

### Sospendere e riattivare
```bash
plesk bin domain --suspend esempio.test       # SUCCESS: Changing status of domain 'esempio.test' completed.
curl -sk --resolve esempio.test:443:$IP https://esempio.test/ -o /dev/null -w '%{http_code}\n'    # 503, dopo un secondo
plesk bin domain --on esempio.test            # il sito torna a rispondere 200
plesk bin domain --info esempio.test | grep 'Domain status'    # Domain status: The domain was suspended by the administrator.  (da sospeso)
```

## Sottodomini, alias e domini aggiuntivi
```bash
plesk bin subdomain --create blog -domain esempio.test -www-root /httpdocs/blog
# SUCCESS: Creation of domain 'blog.esempio.test' completed.
plesk bin domalias --create alias-esempio.test -domain esempio.test
# The domain alias alias-esempio.test was successfully created.
plesk bin domalias --info alias-esempio.test
#    Name             alias-esempio.test
#    Domain           esempio.test
#    Status           enabled
#    Mail             On
#    Web              On
#    DNS              On
#    Seo redirect     On
plesk bin site --list                    # blog.esempio.test / esempio.test    (site elenca domini e sottodomini)
```
`-www-root` è relativo alla cartella della subscription (`/httpdocs/blog` è `/var/www/vhosts/esempio.test/httpdocs/blog`).
Un **alias** non ha un sito suo: risponde col sito del dominio principale (di default con un redirect `301` verso il nome principale, il *SEO redirect*). Un **dominio aggiuntivo** (un sito indipendente nella stessa subscription) si crea con `plesk bin site --create altro.test -hosting true -webspace-name esempio.test`.

## DNS
Plesk tiene una zona BIND per ogni dominio e la riempie da sola: l'elenco è nel database ed è questo, con la zona nella *chroot* di `named`:
```bash
plesk bin dns --info esempio.test
```
```
esempio.test. A  172.17.0.2
esempio.test. NS  ns1.esempio.test.
esempio.test. NS  ns2.esempio.test.
esempio.test. MX 10 mail.esempio.test.
esempio.test. TXT  v=spf1 +a +mx +a:localhost -all
www.esempio.test. CNAME  esempio.test.
ftp.esempio.test. CNAME  esempio.test.
mail.esempio.test. A  172.17.0.2
webmail.esempio.test. A  172.17.0.2
ns1.esempio.test. A  172.17.0.2
ns2.esempio.test. A  172.17.0.2
_dmarc.esempio.test. TXT  v=DMARC1; p=quarantine; adkim=s; aspf=s
default._domainkey.esempio.test. TXT  v=DKIM1; p=MIIBIjANBgkq...
_imaps._tcp.esempio.test. SRV 0 0 993 esempio.test.
...
```
Ci sono già: `A`, `NS` (`ns1`, `ns2`), `MX` verso `mail.`, `SPF`, `DMARC`, la chiave **DKIM** e i `SRV` per la configurazione automatica dei client di posta. Per modificare:
```bash
plesk bin dns --add esempio.test -a test -ip 172.17.0.2             # test.esempio.test A 172.17.0.2
plesk bin dns --add esempio.test -txt "ciao" -domain verifica       # verifica.esempio.test TXT ciao   (-domain è il nome del record)
plesk bin dns --add esempio.test -cname www2 -canonical esempio.test.
plesk bin dns --del esempio.test -a test -ip 172.17.0.2
```
Subito dopo, BIND risponde (le zone di Plesk si interrogano con `dig`, come in [dig](../10-rete-e-web/12-dig.md)):
```bash
dig @127.0.0.1 esempio.test MX +short           # 10 mail.esempio.test.
dig @127.0.0.1 test.esempio.test +short         # 172.17.0.2
dig @127.0.0.1 esempio.test SOA +short          # ns2.esempio.test. mario.example.test. 2026111012 10800 3600 1209600 10800
```
Il `SOA` è fatto con l'indirizzo email del cliente (`mario@example.test` → `mario.example.test.`) e il **serial** è del tipo `AAAAMMGGNN`, aumentato da Plesk a ogni modifica.

Errori che si incontrano:
```bash
plesk bin dns --add esempio.test -a ftp -ip 172.17.0.2
# This record will conflict with the CNAME record for the zone.       <- ftp.esempio.test è già un CNAME: un nome con un CNAME non ha altri record
plesk bin dns --add esempio.test -txt "v=spf1 mx -all"
# DNS record 'esempio.test. IN TXT v=spf1 mx -all' already exists.
```
> **ATTENZIONE**: una zona di Plesk è la copia **dentro il server**. Per il mondo la zona vera sta dove sono i nameserver del dominio presso il registrar: `ns1.esempio.test` e `ns2.esempio.test` devono avere un *glue record* che punta all'IP pubblico del server, altrimenti Plesk risponde correttamente e nessuno lo interroga. Lo stesso vale per DKIM: la chiave pubblica sta nella zona, ma conta quella che il resolver vede.

## Posta
```bash
plesk bin mail --create info@esempio.test -passwd "" -mailbox true -mbox_quota 50M
# SUCCESS: Creation of mailname 'info@esempio.test' complete
plesk bin mail --list
# Mail name	info@esempio.test
plesk bin mail --info info@esempio.test
# Mailname:           info
# Domain:             esempio.test
# Mailbox:            true
# Password type:      sym
# Mbox quota:         52428800
# ...
```
La casella è una cartella Maildir in `/var/qmail/mailnames/esempio.test/info/Maildir`. Si prova la password come la proverebbe un client (Dovecot), e si legge la casella via IMAP:
```bash
doveadm auth test info@esempio.test 'Pl3sk-Lab!2026x'
# passdb: info@esempio.test auth succeeded
doveadm auth test info@esempio.test sbagliata
# passdb: info@esempio.test auth failed: Authentication failed          <- exit code 77
curl -sk --url 'imaps://127.0.0.1/INBOX' --user 'info@esempio.test:Pl3sk-Lab!2026x' -X 'STATUS INBOX (MESSAGES)'
# * STATUS INBOX (MESSAGES 0)
```
Una consegna locale con `sendmail` (che in Plesk è un wrapper, `plesk-sendmail`, che firma con DKIM e applica i limiti di invio):
```bash
printf 'Subject: prova\nFrom: root@esempio.test\nTo: info@esempio.test\n\nciao dalla CLI\n' | sendmail -f root@esempio.test info@esempio.test
```
> **NOTA**: nel laboratorio il messaggio arriva in **circa dieci secondi**: Plesk controlla DKIM e SPF e il resolver del container non conosce `esempio.test`, quindi aspetta i timeout delle richieste DNS. Intanto `postqueue -p` lo mostra in coda; non è un guasto.

Altri comandi di posta: `plesk bin mail --update info@esempio.test -passwd "" ...`, `plesk bin mail --remove info@esempio.test`, `plesk bin mailserver --help` (limite di dimensione, MAPS, tipo di relay). Il log è `/var/log/maillog` (Postfix, Dovecot, `plesk-sendmail`).

## Database
```bash
plesk bin database --create esempio_wp -domain esempio.test -type mysql
plesk bin database --create-dbuser wpuser -passwd "" -domain esempio.test -database esempio_wp -type mysql
# The database user was successfully created.
plesk bin database-server --list
# mysql localhost:3306 default
```
`database --create` non stampa niente se va a buon fine (exit code 0). L'elenco dei database e degli utenti non è un'azione di `plesk bin database`: si legge nel database di Plesk.
```bash
plesk db "select d.id, d.name, d.type, dom.name dominio from data_bases d join domains dom on dom.id = d.dom_id"
# +----+------------+-------+--------------+
# | id | name       | type  | dominio      |
# +----+------------+-------+--------------+
# |  1 | esempio_wp | mysql | esempio.test |
# +----+------------+-------+--------------+
plesk db "select id, login, db_id from db_users"        # wpuser
```
`plesk db "SQL"` esegue una query sul database `psa` (senza argomenti apre la console `mysql`). Il database del cliente è un normale database di MariaDB:
```bash
plesk db -Ne "show databases like 'esempio%'"            # esempio_wp
mysql -uadmin -p"$(cat /etc/psa/.psa.shadow)" -e "select user, host from mysql.user"    # l'utente admin è quello che Plesk usa per creare database e utenti
```
> **ATTENZIONE**: l'utente di database creato così risulta in `mysql.user` con host `%`: può collegarsi da qualunque macchina **se la rete lo permette**. Si restringe con `-set-acl`, che **sostituisce** l'elenco degli host ammessi, e con il firewall ([03-manutenzione.md](03-manutenzione.md)):
> ```bash
> plesk bin database --update-dbuser wpuser -type mysql -domain esempio.test -database esempio_wp -set-acl 10.0.0.5
> plesk db -Ne "select user, host from mysql.user where user = 'wpuser'"      # wpuser  10.0.0.5     <- ora solo da lì
> ```

Il dump di un database si carica e si scarica da riga di comando:
```bash
plesk bin database --upload esempio_wp -domain esempio.test -dump-file "$PWD/dump.sql"       # carica dump.sql (la tabella clienti)
# Finished uploading the dump '/root/lab/02-cli-hosting/dump.sql' to database 'esempio_wp'.
plesk db -Ne "select nome, citta from esempio_wp.clienti"
# Anna Verdi	Torino
# Luca Bianchi	Bologna
# Sara Neri	Napoli
plesk bin database --download esempio_wp -domain esempio.test -dump-file /tmp/esempio_wp.zip      # un archivio compresso (zip) del database
# Finished downloading the dump of database 'esempio_wp' to '/tmp/esempio_wp.zip'.
```
> **ATTENZIONE**: il percorso del dump deve essere **assoluto**. Con `-dump-file dump.sql` il comando parte dal programma di Plesk (non dalla cartella in cui ci si trova) e fallisce con `Unable to upload database dump: [Errno 2] No such file or directory: 'dump.sql'`, preceduto da un `ERR [util_exec] proc_close() failed ['/opt/psa/admin/bin/dbbackup' '--restore' ...]`. `"$PWD/dump.sql"` risolve.

## PHP
Ogni sito ha un **gestore PHP** (versione e modalità). Quelli installati:
```bash
plesk bin php_handler --list
#                         id:  display name:  full version:  version:    type: ...
#             plesk-php83-fpm         8.3.36         8.3.36       8.3     fpm
#         plesk-php83-fastcgi         8.3.36         8.3.36       8.3  fastcgi
#             plesk-php84-fpm         8.4.27         8.4.27       8.4     fpm
#   plesk-php84-fpm-dedicated         8.4.27         8.4.27       8.4     fpm
#   ...
```
**FPM** è la modalità normale (nginx → apache → socket PHP-FPM); `fpm-dedicated` dà al sito un proprio pool di processi; `cgi` e `fastcgi` sono più vecchie.

Una pagina che dice quale PHP la serve (`info.php`, nella cartella del laboratorio):
```bash
cp info.php /var/www/vhosts/esempio.test/httpdocs/ && chown mrossi:psacln /var/www/vhosts/esempio.test/httpdocs/info.php
curl -sk --resolve esempio.test:443:$IP https://esempio.test/info.php
# PHP 8.4.27 (fpm-fcgi)
# memory_limit=128M upload_max_filesize=2M
# open_basedir=/var/www/vhosts/esempio.test/:/tmp/
# sito: esempio.test
```
Cambiare versione per il sito:
```bash
plesk bin site --update esempio.test -php_handler_id plesk-php83-fpm
curl -sk --resolve esempio.test:443:$IP https://esempio.test/info.php | head -1
# PHP 8.3.36 (fpm-fcgi)                  <- subito dopo il comando: un secondo di attesa
```
E le impostazioni: si scrivono in un file di direttive e si applicano al sito; il risultato è in `/var/www/vhosts/system/esempio.test/etc/php.ini`:
```bash
cat php-extra.ini                         # memory_limit=256M / upload_max_filesize=64M
plesk bin site --update-php-settings esempio.test -settings php-extra.ini
plesk bin site --show-php-settings esempio.test | grep -E 'memory_limit|upload_max'
# memory_limit = 256M
# upload_max_filesize = 64M
grep -E '^(memory_limit|upload_max_filesize|open_basedir)' /var/www/vhosts/system/esempio.test/etc/php.ini
```
`open_basedir` limita i percorsi che il PHP del sito può aprire alla sua cartella e a `/tmp`: un sito non può leggere i file di un altro. Per applicare un `php.ini` globale a tutti i siti: `plesk bin php_settings --update-all`.

> **ATTENZIONE**: `php.ini` in `system/` è un file generato: una modifica a mano viene sovrascritta. Le impostazioni si danno con `site --update-php-settings` (o dal pannello, vedi [04-pannello-cliente.md](04-pannello-cliente.md)).

## Certificati
Un certificato si importa dalla propria chiave e dal file del certificato e si assegna al sito. Qui uno autofirmato (con Let's Encrypt, nelle installazioni vere, lo fa l'estensione con una sola riga):
```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/esempio.key -out /tmp/esempio.crt -days 30 \
        -subj "/CN=esempio.test" -addext "subjectAltName=DNS:esempio.test,DNS:www.esempio.test"
plesk bin certificate --create esempio-selfsigned -domain esempio.test -key-file /tmp/esempio.key -cert-file /tmp/esempio.crt
# SSL/TLS certificate 'esempio-selfsigned' was successfully created
plesk bin certificate --list -domain esempio.test
# CSR Priv Cert CA Name               Used
# N   Y    Y    N  esempio-selfsigned 0
plesk bin site --update esempio.test -certificate-name esempio-selfsigned
sleep 3
echo | openssl s_client -connect $IP:443 -servername esempio.test 2>/dev/null | openssl x509 -noout -subject -dates
# subject=CN = esempio.test
# notBefore=Nov 10 12:26:39 2026 GMT
# notAfter=Dec 10 12:26:39 2026 GMT
```
Subito dopo il comando il server presenta ancora il certificato di default (`CN = Plesk`): l'aggiornamento è asincrono (la `sleep 3`). Senza un certificato assegnato, ogni sito riceve il certificato di Plesk, quello visto da un browser come *non attendibile*.

## Utenti FTP
Oltre all'utente principale della subscription (`mrossi`), si creano account FTP limitati a una cartella:
```bash
plesk bin ftpsubaccount --create sviluppo -domain esempio.test -passwd "" -home /httpdocs/blog
# SUCCESS: Creation of FTP account 'sviluppo' completed.
plesk bin ftpsubaccount --info sviluppo -domain esempio.test
# FTP account name              sviluppo
# Home directory                /httpdocs/blog
```
## Attività pianificate (cron)
Per un cron di un sito si indica la subscription; il comando può essere un eseguibile (`exec`), un indirizzo (`http`) o uno script PHP (`php`):
```bash
cp cron.php /var/www/vhosts/esempio.test/httpdocs/ && chown mrossi:psacln /var/www/vhosts/esempio.test/httpdocs/cron.php
plesk bin scheduler --create -subscription esempio.test -type php -php 8.4.27 \
      -command /var/www/vhosts/esempio.test/httpdocs/cron.php -schedule "*/5 * * * *" \
      -description "Cron del sito" -notify errors
# ID: 13   Active: true   Subscription: esempio.test   Type: php   PHP version: 8.4.27   Schedule: */5 * * * *
ID=$(plesk bin scheduler --list -subscription esempio.test | awk '/^ID:/ {print $2}')    # l'ID lo assegna Plesk (qui 13)
plesk bin scheduler --run "$ID"                    # lo lancia adesso
# Running task id '13'...
# Successfully completed in 0 seconds
cat /var/www/vhosts/esempio.test/httpdocs/cron.log        # 2026-11-10T12:37:45+00:00 eseguito
tail -2 /var/spool/cron/crontabs/mrossi
# #@desc: Cron del sito
# */5	*	*	*	*	(/opt/plesk/php/8.4/bin/php -f '/var/www/vhosts/esempio.test/httpdocs/cron.php')  > /dev/null
plesk bin scheduler --delete "$ID"
```
Due trappole:
- per `-type php`, `-php` vuole la **versione completa** (`8.4.27`, come in `php_handler --list`): `8.4` o `plesk-php84-fpm` danno `PHP handler with the version '8.4' does not exist`;
- il percorso dello script deve essere **assoluto**: con `/httpdocs/cron.php` il cron parte e fallisce con `Could not open input file: /httpdocs/cron.php`.

`plesk bin scheduler --list` senza `-subscription` mostra anche i cron **di Plesk stesso** (utente `psaadm`: aggiornamento del catalogo delle estensioni, controlli del pannello): non vanno toccati.

## Il limite e l'errore più comune: "no available resources"
```
An error occurred during domain creation: There are no available resources of this type (domains) left. Requested: 1; available: 0.
```
Vuol dire che un limite è esaurito: **del piano** (domini, caselle, database della subscription) o **della licenza** (nel laboratorio, un dominio e un cliente). Si controlla con `plesk bin service_plan --info NOME`, `plesk bin domain --info DOMINIO` e `plesk bin keyinfo --list`.

## Riepilogo dei comandi
| Voglio | Comando |
|---|---|
| un cliente | `plesk bin customer --create LOGIN -name "..." -email ... -passwd ""` |
| un sito completo | `plesk bin subscription --create DOMINIO -owner LOGIN -service-plan "..." -ip IP -login UTENTE -passwd ""` |
| un sottodominio | `plesk bin subdomain --create NOME -domain DOMINIO -www-root /httpdocs/NOME` |
| un record DNS | `plesk bin dns --add DOMINIO -a NOME -ip IP` (`-cname`, `-mx`, `-txt`) |
| una casella | `plesk bin mail --create utente@dominio -passwd "" -mailbox true` |
| un database | `plesk bin database --create NOME -domain DOMINIO -type mysql` |
| un utente di database | `plesk bin database --create-dbuser UTENTE -passwd "" -domain DOMINIO -database NOME -type mysql` |
| la versione di PHP | `plesk bin site --update DOMINIO -php_handler_id plesk-php83-fpm` |
| un certificato | `plesk bin certificate --create NOME -domain DOMINIO -key-file ... -cert-file ...` poi `site --update -certificate-name` |
| un cron | `plesk bin scheduler --create -subscription DOMINIO -type exec -command ... -schedule "..."` |
| sospendere / riattivare | `plesk bin domain --suspend` / `--on` |

Torna all'[indice dell'area](README.md)
