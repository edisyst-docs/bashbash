# Il pannello Plesk del cliente

> **Laboratorio**: `./lab.sh 13`, poi `cd 02-cli-hosting && ./crea-esempio.sh` e, dal PC, `https://localhost:8443`. Dettagli in [lab/](lab/).

Questa pagina è per chi **ha un sito** su un server Plesk e lo gestisce dal browser: il *cliente* (`mario`) della subscription `esempio.test`. Il lavoro dell'amministratore (creare il cliente, controllare i servizi, i backup del server) è in [02-cli-hosting.md](02-cli-hosting.md) e [03-manutenzione.md](03-manutenzione.md).

Gli esempi sono stati eseguiti **sul pannello vero** (Plesk Obsidian 18.0.82 nel laboratorio dell'area 13), pilotato con un browser (Chrome); dopo ogni azione si è controllato dal terminale che il server avesse davvero fatto la modifica. Il riquadro "**Sul server**" di ogni sezione mostra quella prova, e serve due volte: a capire cosa succede sotto il pulsante e a ritrovare la causa quando un'azione del pannello non fa quello che ci si aspetta.

> **NOTA**: l'interfaccia del laboratorio è in **inglese** (la licenza dell'immagine ammette solo `en-US`): i nomi dei menu e dei pulsanti sono quelli inglesi. Su un server con più lingue si cambia in *My Profile > Plesk language*.

## Entrare
Un cliente riceve di solito un'email con l'indirizzo del pannello (`https://NOMESERVER:8443`) e il suo nome utente. Nel laboratorio l'amministratore genera un **link di accesso** monouso e lo si apre nel browser:
```bash
plesk login mario
# https://localhost/login?secret=...      <- nel laboratorio il pannello è su https://localhost:8443/login?secret=...
```
Il browser avvisa che il certificato è **non attendibile** (è quello di Plesk, autofirmato): è normale nel laboratorio, si prosegue. Alla prima visita compare un banner, *"Tell us whether you accept cookies"*, con tre pulsanti: `Accept all cookies`, `Accept necessary cookies`, `Set cookie preferences`. Su un server vero si entra con nome utente e password, e con la verifica in due passaggi se è attiva (*My Profile > Multi-Factor Authentication*).

> **ATTENZIONE**: se si apre un secondo accesso con lo stesso utente, il pannello avvisa: *"Warning: Another user with the same username (mario) is already logged in to Plesk."* Succede se ci si dimentica una scheda aperta o la password è usata da un'altra persona: un'avvertenza da non ignorare su un server vero.

## Come è fatto
A sinistra il menu:

| Voce | Cosa contiene |
|---|---|
| **Websites & Domains** | i siti (domini e sottodomini) e i loro strumenti: la pagina di partenza |
| **Mail** | gli indirizzi email, le impostazioni della posta |
| **Files** | il Gestore file (*File Manager*) |
| **Databases** | i database e i loro utenti |
| **Statistics** | spazio disco e traffico |
| **Users** | gli utenti che possono entrare nel pannello (collaboratori) |
| **Account** | i limiti e i permessi del proprio abbonamento, il profilo |
| **WordPress** | l'estensione WP Toolkit per i siti WordPress |

In **Websites & Domains** ogni sito è una riga (nome, stato `Active`, spazio usato, traffico) con le icone rapide (file, posta, database, impostazioni). Aprendola si vedono quattro schede:

| Scheda | Cosa c'è |
|---|---|
| **Dashboard** | gli strumenti del sito, in tre gruppi: *Files & Databases* (`Connection Info`, `Files`, `Databases`, `FTP`, `Backup & Restore`, `Website Copying`), *Dev Tools* (`PHP`, `Logs`), *Security* (`SSL/TLS Certificates`, `Password-Protected Directories`) |
| **Hosting & DNS** | `Hosting` (le impostazioni del sito) e `DNS`. Il DNS segnala **"Domain is not resolvable"** finché il dominio non punta al server (nel laboratorio sempre, `esempio.test` non esiste su internet) |
| **Mail** | la posta del dominio |
| **Get Started** | `Upload Files`, `Sitejet Builder`, `WordPress`: i modi di creare un sito |

In basso, per ogni sito: il percorso (`Website at httpdocs`), l'indirizzo IP e l'**utente di sistema** (`System user mrossi`). Il pulsante `Add Subdomain` sta in alto.

Cosa un cliente può fare lo decide l'amministratore con il **piano** (*service plan*) e i **permessi** della sua subscription. In **Account** si leggono: il piano (`Default Domain`), l'uso delle risorse (`Domains 1 used of 10`, `Databases 2 used of 10`, `Mailboxes 1 used of 100`, `Disk space 0 MB used of 10 GB`, `Traffic 0 MB/month used of 100 GB/month`), le opzioni di hosting (PHP, FastCGI, SSL/TLS) e i **permessi**: gestione del DNS, della versione di PHP, dei backup, dei sottodomini, degli account FTP, delle directory protette, di WP Toolkit... Un'operazione che il piano non concede **non compare, o è in sola lettura**.

## Mettere online un sito statico
**Files** > `File Manager`. È un gestore di file nel browser: a sinistra l'albero (`httpdocs`, `logs`), a destra la cartella con nome, data, dimensione, permessi (`rwx r-x ---`), utente (`mrossi`) e gruppo. In alto: `Copy`, `Move`, `Archive`, `More`, `Remove` e il pulsante `+`.

1. aprire `httpdocs` (la cartella dei file del sito, dove c'è già un `index.html` di Plesk);
2. `+` > `Upload File` (gli altri voci: `Upload Directory`, `Import file via URL`, `Create File`, `Create Directory`);
3. scegliere il file dal computer: in `lab/` ce n'è uno, `04-pannello-cliente/sito-statico/index.html`.

**Sul server**:
```bash
ls -l /var/www/vhosts/esempio.test/httpdocs
# -rw-r--r-- 1 mrossi psacln 187 Nov 10 12:56 sito.html          <- il file caricato: proprietario mrossi, come se l'avesse scritto lui
curl -sk --resolve esempio.test:443:$IP https://esempio.test/sito.html     # il contenuto del file
```
Il file è già online. Il dominio senza `index.html` mostra la pagina di Plesk *"Domain Default page"*: il proprio `index.html` la sostituisce.

> **NOTA**: gli stessi file si gestiscono anche via **FTP**: `Dashboard` > `FTP` > `Add an FTP Account` crea un accesso limitato a una cartella (equivale a `plesk bin ftpsubaccount --create`, [02-cli-hosting.md](02-cli-hosting.md)). `Connection Info` mostra l'IP, l'utente `mrossi`, la password nascosta, e il nome, l'utente e l'host (`localhost:3306 (MariaDB)`) del database.

## La posta
**Mail** > `Create Email Address`. Il modulo:

| Campo | Cosa mettere |
|---|---|
| `Email address` | la parte prima della `@` (`ufficio`); il dominio (`@esempio.test`) è fisso |
| `Can be used to log in to Plesk` | spuntato: la casella diventa anche un accesso al pannello (da togliere se non serve) |
| `External email address` | un indirizzo esterno, per reimpostare la password |
| `Password` / `Confirm password` | la password (`Generate` ne propone una, `Show` la rivela) |
| `Mailbox` | spuntato crea una casella vera; con `Default size (100 MB)` o `Another size` |
| schede `Forwarding`, `Email Aliases`, `Auto-Reply` | inoltro, indirizzi alias, risposta automatica |

`OK` e l'indirizzo compare nell'elenco.

**Sul server**:
```bash
plesk bin mail --list
# Mail name	ufficio@esempio.test
doveadm auth test ufficio@esempio.test 'Pl3sk-Lab!2026x'
# passdb: ufficio@esempio.test auth succeeded
ls /var/qmail/mailnames/esempio.test/ufficio/Maildir       # la casella: cartelle Maildir, vuote finché non arriva posta
```
Da un programma di posta (Thunderbird, Outlook) si usano come **server** `mail.esempio.test` (o il nome del server), utente = **l'indirizzo completo**, IMAP sulla `993` (SSL/TLS) o SMTP sulla `465`. Il pannello pubblica già i record `SRV` e le pagine di configurazione automatica (`autodiscover`, `autoconfig`) che permettono a molti client di configurarsi da soli (vedi [02-cli-hosting.md](02-cli-hosting.md), sezione DNS).

## I database
**Databases** > `Add Database`. Si apre una finestra:

| Campo | Cosa mettere |
|---|---|
| `Database name` | **parte già da `mario_`**: si scrive il resto (`negozio` → `mario_negozio`) |
| `Related site` | il sito a cui è associato (o `No related sites`) |
| `Create a database user` | spuntato: serve un utente, senza il database non è accessibile |
| `Database user name`, `Password` | l'utente (`mario_neg`) e la sua password (`Generate`) |
| `User has access to all databases within the selected subscription` | di norma no |

`Create Database`. Per ogni database ci sono i comandi: `phpMyAdmin` (l'interfaccia web), `Connection info`, `Export dump`, `Import dump`, `Copy database`, `Check and repair`, e in alto `User Management`.

**Importare un dump** (`Import dump`): finestra *Import Database Dump*, con due modi (`Upload a dump from your local computer` oppure `Import a dump stored on your hosting server`), `Choose file...` e la casella **`Recreate the database`**, **spuntata di default**.

> **ATTENZIONE**: `Recreate the database` **cancella e ricrea** il database prima dell'importazione: con la casella spuntata il contenuto attuale va perso. Per aggiungere dati a un database esistente si toglie la spunta (e il dump deve poterlo accettare).

**Sul server**:
```bash
plesk db "select d.name, u.login from data_bases d left join db_users u on u.db_id = d.id"
# | mario_negozio | mario_neg |
plesk db -Ne "select nome, citta from mario_negozio.clienti"      # dopo aver importato 02-cli-hosting/dump.sql
# Anna Verdi	Torino
# Luca Bianchi	Bologna
# Sara Neri	Napoli
```
Il pannello **propone** il prefisso `mario_` (il login del cliente): serve a evitare collisioni fra i nomi di database e utenti di clienti diversi sulla stessa istanza di MariaDB. Non è obbligatorio per tutti: lo impone l'amministratore con `plesk bin server_pref --update -force-db-prefix true` (da `server_pref --help`; il valore attuale, `force-db-prefix: false`, si legge con `plesk bin server_pref --show`). I database creati dall'amministratore da riga di comando non hanno prefisso (`esempio_wp` in [02-cli-hosting.md](02-cli-hosting.md)).

## Sottodomini
**Websites & Domains** > `Add Subdomain`: il nome (`blog`), il dominio padre (`esempio.test`) e il **Document root**. Quest'ultimo si **compila da solo** appena si scrive il nome: `blog.esempio.test`, cioè la cartella `/var/www/vhosts/esempio.test/blog.esempio.test`.

> **ATTENZIONE**: il *Document root* si compila **dopo** che si è scritto il nome. Chi lo riempie a mano prima o durante, o lo ritocca con un taglio e incolla, può ottenere percorsi sbagliati (nel laboratorio un'edizione maldestra ha dato una cartella `blog.esempio.thttpdocs`). Meglio lasciare quello proposto, o scriverlo per ultimo e controllarlo.

`OK` apre una finestra di avanzamento: `Adding a domain`, `Configuring the DNS zone`, `Creating physical hosting`, `Configuring PHP`, tutti `Done`: quello che fa `plesk bin subdomain --create`.

**Sul server**:
```bash
plesk bin site --list                         # blog.esempio.test / esempio.test
plesk db "select d.name, h.www_root from domains d join hosting h on h.dom_id = d.id"
# | blog.esempio.test | /var/www/vhosts/esempio.test/blog.esempio.test |
dig @127.0.0.1 blog.esempio.test +short       # 172.17.0.2   (il record A lo ha aggiunto Plesk)
```

## Il DNS
**Websites & Domains** > scheda `Hosting & DNS` > `DNS` (oppure `Dashboard`). La pagina *DNS Settings for esempio.test* mostra la zona (18 record, con i `NS`, `MX`, `SPF`, `DMARC`, `DKIM`) e i comandi `Add Record`, `Disable`, `Switch to Secondary`, `Reset to Default`, `Remove`.

`Add Record`: il tipo (`A` di default), il nome (`test`), il TTL e l'indirizzo.

> **ATTENZIONE**: dopo `OK` la modifica **non è ancora applicata**. La pagina mostra in alto *"The changes you made to DNS records are not saved yet... Click Update to apply the changes to the DNS zone"*, con i pulsanti `Update` e `Revert`: finché non si preme **`Update`** il record non arriva a BIND.

**Sul server**, dopo `Update`:
```bash
plesk bin dns --info esempio.test | grep '^test'
# test.esempio.test. A  172.17.0.2
dig @127.0.0.1 test.esempio.test +short
# 172.17.0.2
```
Il messaggio **"The website's domain name does not resolve or resolves to a different IP address"** indica che i nameserver **pubblici** del dominio non sono quelli di Plesk: la zona del server è corretta, ma per il mondo conta quella presso il registrar. Per mettere online il sito, lì si impostano i nameserver (o i record `A`) verso l'IP del server.

## PHP
**Dashboard** > `PHP` (con la versione sotto, `Version 8.4.27`). La pagina *PHP Settings for esempio.test* ha in alto:

> PHP support (PHP version **[8.4.27 ▾]**, run PHP as **[FPM application served by Apache ▾]**) · *View the phpinfo() page*

Il menu delle versioni offre `8.3.36` e `8.4.27`: quelle installate sul server. Scegliendo `8.3.36` e `OK`, il sito passa a PHP 8.3.

**Sul server**:
```bash
echo '<?php echo "PHP ", PHP_VERSION, "\n";' > /var/www/vhosts/esempio.test/httpdocs/info.php    # (di mrossi)
curl -sk --resolve esempio.test:443:$IP https://esempio.test/info.php        # prima: PHP 8.4.27
                                                                              # dopo:  PHP 8.3.36        <- un paio di secondi dopo OK
plesk db "select d.name, h.php_handler_id from domains d join hosting h on h.dom_id = d.id"
# | esempio.test      | plesk-php83-fpm |         <- cambiato dal pannello
# | blog.esempio.test | plesk-php84-fpm |         <- il sottodominio ha il suo gestore, ancora 8.4
```
Sotto, i parametri in elenco: `memory_limit` (`128M (Default)`), `max_execution_time` (`30`), `post_max_size` (`8M`), `upload_max_filesize` (`2M`), `open_basedir`, `error_reporting`, `display_errors`, le impostazioni di `PHP-FPM` (`pm`, `pm.max_children`...).

> **NOTA**: nel laboratorio quei parametri sono **in sola lettura**: la pagina dice *"You can change the PHP configuration if the hosting provider grants you the corresponding permission"*. Spetta all'amministratore concedere il permesso (o impostarli lui, `plesk bin site --update-php-settings`, [02-cli-hosting.md](02-cli-hosting.md)). Quando sono modificabili, ogni valore si cambia dalla stessa pagina e si applica al **solo sito**, non agli altri della subscription. I valori in un file `.user.ini` o `.htaccess` nel sito hanno la precedenza.

## Il certificato HTTPS
Un sito appena creato usa il certificato di default di Plesk (non attendibile). Il flusso per mettere il proprio:

1. **Dashboard** > `SSL/TLS Certificates` > `Add SSL/TLS Certificate`: *Certificate name* (`autofirmato`), `Bits` (`2048`), Country, State, City, Organization, Domain name, Email. I pulsanti: `Request` (genera una richiesta *CSR* da inviare a una CA) e **`Self-Signed`** (genera subito un certificato autofirmato). In fondo, *Upload the certificate files*: chiave (`*.key`), certificato (`*.crt`) e catena (`*-ca.crt`) comprati altrove;
2. il certificato compare nell'elenco, ma **non è ancora in uso**: la pagina lo ricorda (*"you need to enable SSL/TLS support and select that certificate in the website hosting settings"*);
3. **Hosting & DNS** > `Hosting` (*Hosting Settings*) > sezione `SSL/TLS support` > `Certificate`: nel menu compaiono `Not selected`, `autofirmato (esempio.test)` e `Default Certificate (other repository)`; si sceglie il proprio e `Save`.

**Sul server**:
```bash
plesk bin certificate --list -domain esempio.test
# CSR Priv Cert CA Name        Used
# N   Y    Y    N  autofirmato 0           <- esiste, ma non è assegnato (Used 0, finché non si fa il passo 3)
echo | openssl s_client -connect $IP:443 -servername esempio.test 2>/dev/null | openssl x509 -noout -subject
# subject=C = CH, L = Schaffhausen, O = Plesk, CN = Plesk, emailAddress = info@plesk.com           <- prima del passo 3
# subject=C = IT, ST = Piemonte, L = Torino, O = Rossi SRL, CN = esempio.test, emailAddress = ...   <- dopo
```
La finestra *Hosting Settings* ha le impostazioni importanti del sito: `Preferred domain` (con o senza `www`, con redirect 301), `Document root` (`httpdocs`), `SSL/TLS support` e `Redirect visitors from HTTP to HTTPS` (entrambi spuntati), `Web statistics` (`GoAccess`, protette con la password FTP), `Web scripting` (`FastCGI`, `Custom error documents`), `System user's credentials` (utente e nuova password), `SSH access` (`Forbidden`) e `IP addresses`.

## Backup
**Dashboard** > `Backup & Restore` apre il *Backup Manager* (`Back Up`, `Upload`, `Remove`, `Schedule`, `Remote Storage Settings`). `Back Up` chiede cosa salvare: `Configuration`, `Mail`, `Files`, `Database` (tutto, di default), `Full` o `Incremental`, un commento (`All configuration and content`), se escludere i log, e un indirizzo email per la notifica. `OK` fa partire il backup e, a fine corsa, l'archivio compare nell'elenco con la sua data e la possibilità di ripristinarlo.

**Sul server**:
```bash
ls /var/lib/psa/dumps/clients/mario/domains/esempio.test/
# backup_apache-files_2611101300.tzst  backup_conf_2611101300.tzst  backup_domainmail_2611101300.tzst  backup_info_2611101300.xml ...
```
È lo stesso backup di `plesk bin pleskbackup` ([03-manutenzione.md](03-manutenzione.md)): sul disco del server, finché non lo si scarica o si imposta un archivio remoto (`Remote Storage Settings`). Con `Schedule` il pannello lo ripete da solo.

## Gli altri strumenti
| Strumento | A cosa serve |
|---|---|
| **Logs** (`Dashboard`) | il log del sito in una tabella (data, tipo `Access`/`Error`/`Warning`, IP, codice, richiesta, dimensione, origine): `Start real-time updates`, `Refresh`, `Manage Log Files`, `Log Rotation`. Sono i file di `/var/www/vhosts/system/esempio.test/logs/` |
| **Statistics** | spazio e traffico usati rispetto ai limiti (`10 GB`, `100 GB/month`), per servizio; `FTP Statistics`, `Data Transfer Statistics`, `Web Statistics SSL/TLS` (rapporti GoAccess in `/plesk-stat/`) |
| **Password-Protected Directories** | protegge una cartella con utente e password: la finestra *Create Protected Directory* chiede `Directory name` (`/` è tutto il sito) e `Title of the protected area` (il testo della finestra di accesso). Esiste già `/plesk-stat`, le statistiche (titolo `Domain statistics`) |
| **Website Copying** | copia i file del sito su un altro sito dello stesso account o su un server FTP (utile per creare un ambiente di prova): `Keep existing files`, `Overwrite`, `Delete all existing files` |
| **Users** | gli accessi per collaboratori: ruoli `Owner` (chi c'è già: `mario`), `WebMaster`, `Application User`, `Accountant`; `Create User Account` chiede nome, email, ruolo, accesso al sito |
| **Mail Settings** | il comportamento della posta del dominio (`Mail` > `Mail Settings`), e gli `Smarthosts` |
| **My Profile** | dati di contatto, password, lingua, **Multi-Factor Authentication** (`Off`/`On`): *Account* > `My Profile` |
| **WordPress** | installazione e gestione dei siti WordPress con WP Toolkit (non provato nel laboratorio: serve un accesso a internet per scaricare WordPress) |

## Quando qualcosa non va
| Sintomo | Causa | Cosa fare |
|---|---|---|
| un record DNS non risulta | manca il clic su **`Update`** nella pagina DNS | `Update` (o `Revert` per annullare); poi `dig` o `plesk bin dns --info` |
| il sito mostra la pagina "Domain Default page" | manca un `index.html` / `index.php` in `httpdocs` | caricarlo con il File Manager o via FTP |
| un database sparito dopo un'importazione | era spuntato `Recreate the database` | si ripristina dal backup ([03-manutenzione.md](03-manutenzione.md)); la prossima volta togliere la spunta |
| il certificato caricato non si vede nel browser | è nel repository ma **non selezionato** in *Hosting Settings* | `Hosting` > `Certificate` > `Save`; un paio di secondi dopo |
| *Domain is not resolvable* | il DNS pubblico del dominio non punta al server | impostare nameserver o record `A` presso il registrar |
| non trovo l'opzione che mi serve (PHP, DNS, backup...) | il piano o i permessi non la concedono | *Account* > `Permissions`; chiedere all'amministratore |
| *"Another user with the same username is already logged in"* | un'altra sessione dello stesso utente è aperta | chiudere le sessioni inutili; cambiare la password se non si riconosce l'accesso |
| `Error: An invalid URL was requested` | un indirizzo del pannello digitato a mano e sbagliato | tornare a *Websites & Domains* e navigare con i menu |

Torna all'[indice dell'area](README.md)
