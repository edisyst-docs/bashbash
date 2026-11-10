# 13 - Plesk

Il pannello di controllo per l'hosting più diffuso: dal sysadmin che crea siti, posta e database con `plesk bin`, al cliente che li gestisce dal browser.
Dietro il pannello ci sono i servizi delle aree precedenti: [nginx e apache](../10-rete-e-web/04-apache-nginx.md), [BIND](../10-rete-e-web/06-dns-server.md),
[Postfix e Dovecot](../10-rete-e-web/07-posta-postfix.md), [MySQL](../09-strumenti/03-mysql.md) e [fail2ban](../08-remoto-e-sicurezza/02-firewall-e-hardening.md).

| # | File | Contenuto |
|---|---|---|
| 01 | [introduzione](01-introduzione.md) | Cos'è Plesk, chi c'è (admin, reseller, cliente), cliente / subscription / dominio / piano, i servizi dentro (nginx → apache → PHP-FPM, BIND, Postfix, Dovecot, MariaDB), dove stanno i file, i punti d'ingresso (`plesk bin`, `plesk db`, `plesk repair`, `plesk login`) |
| 02 | [da terminale](02-cli-hosting.md) | `plesk bin`: clienti, subscription, sottodomini e alias, DNS, caselle di posta, database (anche dump), versione e impostazioni di PHP, certificati, FTP, cron; password da `PSA_PASSWORD`; i limiti ("no available resources") |
| 03 | [manutenzione](03-manutenzione.md) | Servizi, `plesk repair` (con un guasto provocato e riparato), `httpdmng`, backup e ripristino di un file con `pleskbackup`/`pleskrestore`, log, il database `psa`, accesso e password, fail2ban con `ip_ban`, estensioni, licenza, API REST con chiave segreta |
| 04 | [pannello del cliente](04-pannello-cliente.md) | Il pannello pilotato dal browser: File Manager, posta, database (con `Recreate the database`), sottodomini, DNS (e il pulsante `Update`), PHP, certificato autofirmato, backup, log, statistiche, utenti e permessi; per ogni azione la prova da terminale |

**Laboratorio**: `./lab.sh 13` dalla radice della KB avvia un Plesk Obsidian 18.0 vero in un container (immagine ufficiale `plesk/plesk`, 3 GB, Ubuntu 24.04, systemd) e vi si entra come `root`.
Il pannello si apre dal PC su `https://localhost:8443`. La licenza inclusa nell'immagine ammette **un dominio e un cliente**. Dettagli e limiti in [lab/](lab/).

Area precedente: [../12-osservabilita/](../12-osservabilita/) · Torna all'[indice](../README.md)
