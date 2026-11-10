# Plesk: cos'è e come è fatto

> **Laboratorio**: `./lab.sh 13`. Un container con Plesk Obsidian 18.0 vero (immagine ufficiale `plesk/plesk`) su Ubuntu 24.04; il pannello si apre dal PC su `https://localhost:8443`. Dettagli in [lab/](lab/).

Plesk è un **pannello di controllo per l'hosting**: una sola interfaccia (web, riga di comando e API) sopra i servizi che fanno funzionare un sito. Chi lo usa non edita `nginx.conf`, `named.conf` o `main.cf`: crea un dominio e Plesk **genera** tutta la configurazione di web server, DNS, posta, database e PHP, e la rigenera quando qualcosa cambia.

È il lavoro che nelle aree precedenti si fa a mano: [nginx e apache](../10-rete-e-web/04-apache-nginx.md), [BIND](../10-rete-e-web/06-dns-server.md), [Postfix e Dovecot](../10-rete-e-web/07-posta-postfix.md), [MySQL](../09-strumenti/03-mysql.md), `fail2ban`. Capire cosa c'è sotto serve per un motivo pratico: **quando Plesk si rompe si ripara a livello di sistema**, e un file generato a mano viene cancellato alla prossima riconfigurazione.

Gli esempi di queste pagine sono stati eseguiti nel laboratorio dell'area 13 (Plesk Obsidian 18.0.82, Ubuntu 24.04, PHP 8.3 e 8.4).

## Le due metà del lavoro
Questa area è divisa secondo chi usa Plesk:

| Chi | Cosa fa | Pagina |
|---|---|---|
| **amministratore del server** (sysadmin) | crea clienti e siti, controlla servizi, backup, sicurezza, ripara | [02-cli-hosting.md](02-cli-hosting.md) e [03-manutenzione.md](03-manutenzione.md), da terminale |
| **cliente** (chi ha il sito) | gestisce il proprio dominio, la posta, i database, i file | [04-pannello-cliente.md](04-pannello-cliente.md), dal pannello |

Il pannello e la riga di comando sono **due porte sullo stesso database**: quello che si crea con `plesk bin` compare nel pannello e viceversa.

## Chi c'è nel pannello
Plesk ha una gerarchia di account:

| Livello | Cosa può fare |
|---|---|
| **admin** | tutto: il server, i servizi, le impostazioni globali, tutti i clienti |
| **reseller** | rivende hosting: crea clienti propri entro i limiti di un *reseller plan* |
| **customer** (cliente) | ha una o più *subscription*, vede solo le proprie |
| **utente** (*power user*) | un accesso più limitato dentro la subscription del cliente |

Gli oggetti che un cliente possiede:

```
cliente (customer)        mario
  └─ subscription         esempio.test         <- il "webspace": una cartella, un utente di sistema, i limiti
       ├─ dominio principale   esempio.test    (e le sue risorse: sito, posta, DNS, database, cron)
       ├─ sottodomini          blog.esempio.test
       ├─ alias di dominio     alias-esempio.test   (un altro nome per lo stesso sito)
       └─ domini aggiuntivi    (un altro sito nella stessa subscription)
```
- Una **subscription** (in italiano "abbonamento") è l'unità che si assegna a un cliente: un **utente di sistema** (`mrossi`), una cartella (`/var/www/vhosts/esempio.test`) e dei limiti (spazio, traffico, numero di caselle e di database).
- Un **service plan** è un modello di limiti e permessi: la subscription nata da un piano si aggiorna quando si cambia il piano. Il piano `Default Domain` esiste già.
- Un **sottodominio** vive dentro il dominio; un **alias** è un nome in più per lo stesso sito; un **dominio aggiuntivo** è un sito distinto che condivide la subscription.

## Cosa gira dentro
Un solo comando mostra l'elenco dei servizi che Plesk gestisce:
```bash
plesk bin service --list -detail
# web          Apache                         is running  installed      httpd
# smtp         Postfix                        is running  installed      postfix
# imap-pop3    Dovecot IMAP and POP3 server   is running  installed      dovecot
# dns          BIND                           is running  installed      bind
# nginx        Nginx                          is running  installed      nginx
# fail2ban     fail2ban                       is running  installed      fail2ban
# plesk-php83-fpm  plesk-php83-fpm            is stopped  installed      plesk-php83-fpm
# plesk-php84-fpm  plesk-php84-fpm            is running  installed      plesk-php84-fpm
# ...                                         (courier, postgresql, spamassassin: N/A, non installati)
```
E `ss -tlnp` dice dove ascoltano (nel laboratorio, dopo aver creato un dominio):

| Porta | Chi | A cosa serve |
|---|---|---|
| `80`, `443` | **nginx** (solo sull'IP del server) | riceve tutto il traffico web, serve i file statici |
| `7080`, `7081` | **apache** (solo `127.0.0.1`) | dietro nginx: gestisce `.htaccess` e passa il PHP a PHP-FPM |
| `8443`, `8880` | `sw-cp-server` (nginx del pannello) | il **pannello** Plesk, HTTPS e HTTP |
| `53` | **BIND** (`named`) | DNS autoritativo delle zone dei domini |
| `25`, `465` | **Postfix** | posta in uscita e in entrata (SMTP, SMTPS) |
| `110`, `143`, `993`, `995` | **Dovecot** | caselle (POP3, IMAP e le versioni cifrate) |
| `21` | **proftpd** (via `xinetd`) | FTP |
| `3306` | **MariaDB** (solo `127.0.0.1`) | i database dei clienti e quello di Plesk (`psa`) |

Il percorso di una richiesta web:
```
browser ──443──> nginx ──(statici: serve lui)
                    └──7080──> apache ──socket──> PHP-FPM (PHP 8.3 o 8.4, per sito)
```
nginx davanti e apache dietro sono una scelta di Plesk: la velocità dei file statici di nginx più la compatibilità di apache con `.htaccess`. Si può anche usare nginx da solo, per sito.

## Dove sta cosa
| Percorso | Cosa contiene |
|---|---|
| `/opt/psa/` (`/usr/local/psa` è un link) | il prodotto: `bin/` (i comandi), `admin/` (il pannello), `var/` (certificati, stato) |
| `/var/www/vhosts/DOMINIO/httpdocs` | i file del sito (la *document root*) |
| `/var/www/vhosts/DOMINIO/logs` | i log del sito: gli stessi file stanno in `/var/www/vhosts/system/DOMINIO/logs` (`access_log`, `access_ssl_log`, `error_log`, `proxy_*`) |
| `/var/www/vhosts/system/DOMINIO/` | la parte "di sistema" del sito: `etc/php.ini`, `conf/`, `statistics/`, il socket PHP-FPM |
| `/etc/nginx/plesk.conf.d/vhosts/`, `/etc/apache2/plesk.conf.d/vhosts/` | la configurazione **generata** dei siti |
| `/var/named/run-root/var/` | le zone DNS (BIND gira in una *chroot*) |
| `/var/qmail/mailnames/DOMINIO/CASELLA/Maildir` | la posta delle caselle (formato Maildir) |
| `/var/lib/psa/dumps/` | i backup locali |
| `/var/log/plesk/` | i log di Plesk (`panel.log`, `repair.log`, `PMM/` per i backup) |
| `/etc/psa/` | `.psa.shadow` (la password cifrata con cui Plesk parla a MariaDB, leggibile solo da `psaadm`), `psa.conf` |

> **ATTENZIONE**: i file in `plesk.conf.d/` iniziano con *"DO NOT MODIFY THIS FILE BECAUSE IT WAS GENERATED AUTOMATICALLY"*: **ogni modifica a mano si perde** alla prossima riconfigurazione. Per cambiare il comportamento di un sito si usano le impostazioni del pannello (o `plesk bin`), oppure i punti di estensione previsti (direttive aggiuntive nginx/apache per dominio, che si impostano dal pannello).

Plesk tiene tutto lo stato in un database MariaDB, `psa`: clienti, domini, caselle, limiti. I file di configurazione sono **derivati** da lì. Si può interrogare (`plesk db`, vedi [03-manutenzione.md](03-manutenzione.md)), ma non si modifica a mano: lo si cambia con `plesk bin` o con il pannello.

## I punti d'ingresso
| Comando | A cosa serve |
|---|---|
| `plesk bin NOME ...` | i comandi di amministrazione (`customer`, `subscription`, `domain`, `mail`, `database`, `dns`, ...): [02](02-cli-hosting.md) |
| `plesk db` | una console MariaDB già collegata al database `psa` |
| `plesk repair ...` | controlla e ripara configurazioni e permessi: [03](03-manutenzione.md) |
| `plesk login` | un link di accesso al pannello senza password |
| `plesk sbin NOME` | utilità interne (`httpdmng` rigenera la configurazione del web server) |
| `plesk ext NOME` | la riga di comando di un'estensione (es. `wp-toolkit`) |
| `plesk installer` | aggiornare o aggiungere componenti |
| `plesk version` | la versione |
| API REST e XML | per programmi esterni (WHMCS, script): [03](03-manutenzione.md) |

```bash
plesk version
# Product version: Plesk Obsidian 18.0.82.2
#      OS version: Ubuntu 24.04 x86_64
#      Build date: 2026/11/02 14:00
#        Revision: fd08e8b619cdd0020399d171208ddf6c9687087b
plesk help                  # elenco dei sottocomandi; plesk bin NOME --help per le opzioni di ciascuno
```

## Il laboratorio
```bash
./lab.sh 13                  # la prima volta scarica l'immagine (3 GB) e Plesk parte in circa 30 secondi
cd 02-cli-hosting
```
Nel container si lavora come `root`, come un amministratore sul server. Cose da sapere:
- l'immagine include una **licenza di prova che ammette un solo dominio** (e `admin` più un cliente): negli esempi c'è un sito, `esempio.test`; i sottodomini e gli alias non contano, un secondo dominio sì (vedi i limiti in [02-cli-hosting.md](02-cli-hosting.md));
- non c'è Let's Encrypt (l'estensione non è inclusa e i domini `.test` non esistono su internet) e il DNS vero non c'è: i nomi si provano con `curl --resolve` o interrogando BIND del container;
- l'interfaccia del pannello è in **inglese**: la licenza dell'immagine ammette solo `en-US`;
- all'uscita (`exit`) il container e il suo stato spariscono: si riparte da zero.

Torna all'[indice dell'area](README.md)
