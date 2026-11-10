#!/usr/bin/env bash
# autotest.sh - riesegue gli esempi di 02-cli-hosting.md e 03-manutenzione.md sul Plesk del laboratorio 13 e controlla
# che ognuno faccia quello che il .md dice. Si lancia in un laboratorio appena avviato (senza il cliente mario):
#   ./lab.sh 13 -- 'bash /kb/13-plesk/lab/autotest.sh'
# Esce con 0 e scrive "tutti i controlli sono ok" se è tutto giusto.
set -uo pipefail

LAB=${LAB:-$HOME/lab/02-cli-hosting}
cd "$LAB" 2> /dev/null || { echo "lancialo da un laboratorio 13 appena avviato (manca $LAB)" >&2; exit 2; }

export PSA_PASSWORD='Pl3sk-Lab!2026x'
PASS="$PSA_PASSWORD"
VH=/var/www/vhosts/esempio.test
OK=0 KO=0

ok()   { OK=$((OK + 1)); printf '  ok     %s\n' "$1"; }
ko()   { KO=$((KO + 1)); printf '  ERRORE %s\n' "$1"; }
# prova DESCRIZIONE COMANDO...   (il comando deve uscire con 0)
prova() { local d=$1; shift; if "$@" > /dev/null 2>&1; then ok "$d"; else ko "$d  ($*)"; fi; }
# contiene DESCRIZIONE TESTO COMANDO...   (l'output del comando, anche l'errore, deve contenere TESTO)
contiene() { local d=$1 t=$2 out; shift 2; out=$("$@" 2>&1); if grep -qF -- "$t" <<< "$out"; then ok "$d"; else ko "$d  (atteso: $t; ottenuto: ${out:0:160})"; fi; }
# attende SECONDI DESCRIZIONE 'ESPRESSIONE'   (riprova ogni secondo la valutazione dell'espressione finché esce con 0: le modifiche di Plesk sono asincrone)
attende() { local n=$1 d=$2 e=$3 i; for ((i = 0; i < n; i++)); do eval "$e" > /dev/null 2>&1 && { ok "$d"; return; }; sleep 1; done; ko "$d  (dopo ${n}s: $e)"; }

IP=$(plesk bin ipmanage --ip_list | awk 'NR==2 {split($3, a, /[:\/]/); print a[2]}')
web()  { curl -sk --max-time 5 --resolve "esempio.test:443:$IP" "https://esempio.test$1"; }
codice() { curl -sk --max-time 5 -o /dev/null -w '%{http_code}' --resolve "esempio.test:443:$IP" "https://esempio.test$1"; }
codice80() { curl -s --max-time 5 -o /dev/null -w '%{http_code}' --resolve "esempio.test:80:$IP" http://esempio.test/; }
cert() { echo | openssl s_client -connect "$IP:443" -servername esempio.test 2> /dev/null | openssl x509 -noout -subject; }
echo "IP del server: $IP"

echo "== clienti, subscription, siti"
prova "il piano Default Domain esiste" plesk bin service_plan --info "Default Domain"
contiene "customer --create" "completed" plesk bin customer --create mario -name "Mario Rossi" -email mario@example.test -passwd ""
contiene "customer --list" "mario" plesk bin customer --list
contiene "subscription --create" "completed" plesk bin subscription --create esempio.test -owner mario -service-plan "Default Domain" -ip "$IP" -login mrossi -passwd ""
contiene "domain --list" "esempio.test" plesk bin domain --list
prova "httpdocs è di mrossi" test "$(stat -c %U "$VH/httpdocs")" = mrossi
attende 15 "HTTP risponde 301 (redirect a HTTPS)" 'test "$(codice80)" = 301'
attende 15 "HTTPS risponde 200" 'test "$(codice /)" = 200'
contiene "un secondo cliente supera il limite della licenza" "no available resources" plesk bin customer --create luigi -name "Luigi Verdi" -email l@example.test -passwd ""
contiene "un secondo dominio supera il limite della licenza" "no available resources" plesk bin site --create secondo.test -hosting true -webspace-name esempio.test

echo "== sottodomini, alias, sospensione"
contiene "subdomain --create" "blog.esempio.test" plesk bin subdomain --create blog -domain esempio.test -www-root /httpdocs/blog
contiene "domalias --create" "successfully created" plesk bin domalias --create alias-esempio.test -domain esempio.test
contiene "domalias --info" "enabled" plesk bin domalias --info alias-esempio.test
contiene "site --list" "blog.esempio.test" plesk bin site --list
prova "la cartella del sottodominio esiste" test -d "$VH/httpdocs/blog"
prova "domain --suspend" plesk bin domain --suspend esempio.test
attende 15 "sospeso: il sito risponde 503" 'test "$(codice /)" = 503'
contiene "customer --off" "completed" plesk bin customer --off mario
prova "customer --on" plesk bin customer --on mario
prova "domain --on" plesk bin domain --on esempio.test
attende 15 "riattivato: il sito risponde 200" 'test "$(codice /)" = 200'

echo "== DNS"
contiene "dns --info ha l'MX" "mail.esempio.test" plesk bin dns --info esempio.test
contiene "dns --add -a" "complete" plesk bin dns --add esempio.test -a test -ip "$IP"
attende 10 "BIND risponde per test.esempio.test" 'test "$(dig @127.0.0.1 test.esempio.test +short)" = "$IP"'
contiene "dns --add -txt" "complete" plesk bin dns --add esempio.test -txt ciao -domain verifica
contiene "dns --add -cname" "complete" plesk bin dns --add esempio.test -cname www2 -canonical esempio.test.
contiene "dns --del -cname" "complete" plesk bin dns --del esempio.test -cname www2 -canonical esempio.test.
contiene "un A su un CNAME è rifiutato" "conflict with the CNAME" plesk bin dns --add esempio.test -a ftp -ip "$IP"
contiene "un TXT doppio è rifiutato" "already exists" plesk bin dns --add esempio.test -txt "v=spf1 mx -all"
prova "MX di BIND" test "$(dig @127.0.0.1 esempio.test MX +short)" = "10 mail.esempio.test."
contiene "il SOA usa l'email del cliente" "mario.example.test." dig @127.0.0.1 esempio.test SOA +short

echo "== posta"
contiene "mail --create" "complete" plesk bin mail --create info@esempio.test -passwd "" -mailbox true -mbox_quota 50M
contiene "mail --list" "info@esempio.test" plesk bin mail --list
contiene "mail --info (quota 50M)" "52428800" plesk bin mail --info info@esempio.test
contiene "doveadm: password giusta" "auth succeeded" doveadm auth test info@esempio.test "$PASS"
contiene "doveadm: password sbagliata" "auth failed" doveadm auth test info@esempio.test sbagliata
prova "IMAP risponde sulla casella" curl -sk --max-time 10 --url 'imaps://127.0.0.1/INBOX' --user "info@esempio.test:$PASS" -X 'STATUS INBOX (MESSAGES)'
printf 'Subject: prova\nFrom: root@esempio.test\nTo: info@esempio.test\n\nciao dalla CLI\n' | sendmail -f root@esempio.test info@esempio.test
attende 60 "la posta arriva nella Maildir (ci mette una decina di secondi)" 'test -n "$(find /var/qmail/mailnames/esempio.test/info/Maildir/new -type f 2> /dev/null)"'

echo "== database"
prova "database --create" plesk bin database --create esempio_wp -domain esempio.test -type mysql
contiene "database --create-dbuser" "successfully created" plesk bin database --create-dbuser wpuser -passwd "" -domain esempio.test -database esempio_wp -type mysql
contiene "database-server --list" "localhost:3306" plesk bin database-server --list
contiene "plesk db vede il database" "esempio_wp" plesk db "select d.name from data_bases d join domains dom on dom.id = d.dom_id"
contiene "database --upload con percorso relativo: errore" "No such file or directory" plesk bin database --upload esempio_wp -domain esempio.test -dump-file dump.sql
contiene "database --upload" "Finished uploading" plesk bin database --upload esempio_wp -domain esempio.test -dump-file "$PWD/dump.sql"
contiene "i dati del dump ci sono" "Sara Neri" plesk db -Ne "select nome, citta from esempio_wp.clienti"
contiene "database --download" "Finished downloading" plesk bin database --download esempio_wp -domain esempio.test -dump-file /tmp/esempio_wp.zip
prova "l'archivio scaricato esiste" test -s /tmp/esempio_wp.zip
contiene "update-dbuser -set-acl" "successfully updated" plesk bin database --update-dbuser wpuser -type mysql -domain esempio.test -database esempio_wp -set-acl 10.0.0.5
contiene "l'utente ha solo l'host dell'ACL" "10.0.0.5" plesk db -Ne "select user, host from mysql.user where user = 'wpuser'"

echo "== PHP"
contiene "php_handler --list" "plesk-php84-fpm" plesk bin php_handler --list
cp info.php "$VH/httpdocs/" && chown mrossi:psacln "$VH/httpdocs/info.php"
attende 15 "info.php gira con PHP 8.4" 'test "$(web /info.php | head -1)" = "PHP 8.4.27 (fpm-fcgi)"'
contiene "site --update -php_handler_id" "completed" plesk bin site --update esempio.test -php_handler_id plesk-php83-fpm
attende 15 "ora gira con PHP 8.3" 'test "$(web /info.php | head -1)" = "PHP 8.3.36 (fpm-fcgi)"'
contiene "site --update-php-settings" "" plesk bin site --update-php-settings esempio.test -settings php-extra.ini
attende 15 "memory_limit e upload_max_filesize cambiati" 'test "$(web /info.php | sed -n 2p)" = "memory_limit=256M upload_max_filesize=64M"'
contiene "site --show-php-settings" "memory_limit = 256M" plesk bin site --show-php-settings esempio.test
contiene "open_basedir limita il sito" "open_basedir=$VH/:/tmp/" web /info.php

echo "== certificato"
openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/esempio.key -out /tmp/esempio.crt -days 30 \
    -subj "/CN=esempio.test" -addext "subjectAltName=DNS:esempio.test,DNS:www.esempio.test" 2> /dev/null
contiene "il certificato di default è quello di Plesk" "CN = Plesk" cert
contiene "certificate --create" "successfully created" plesk bin certificate --create esempio-selfsigned -domain esempio.test -key-file /tmp/esempio.key -cert-file /tmp/esempio.crt
contiene "certificate --list" "esempio-selfsigned" plesk bin certificate --list -domain esempio.test
contiene "site --update -certificate-name" "completed" plesk bin site --update esempio.test -certificate-name esempio-selfsigned
attende 20 "il server presenta il certificato nuovo" 'test "$(cert)" = "subject=CN = esempio.test"'

echo "== FTP e cron"
contiene "ftpsubaccount --create" "completed" plesk bin ftpsubaccount --create sviluppo -domain esempio.test -passwd "" -home /httpdocs/blog
contiene "ftpsubaccount --info" "/httpdocs/blog" plesk bin ftpsubaccount --info sviluppo -domain esempio.test
cp cron.php "$VH/httpdocs/" && chown mrossi:psacln "$VH/httpdocs/cron.php"
contiene "-php 8.4 (versione corta) è rifiutato" "does not exist" plesk bin scheduler --create -subscription esempio.test -type php -php 8.4 -command "$VH/httpdocs/cron.php" -schedule "*/5 * * * *"
contiene "scheduler --create" "Type:               php" plesk bin scheduler --create -subscription esempio.test -type php -php 8.4.27 -command "$VH/httpdocs/cron.php" -schedule "*/5 * * * *" -description "Cron del sito" -notify errors
ID=$(plesk bin scheduler --list -subscription esempio.test | awk '/^ID:/ {print $2}')
contiene "scheduler --run" "Successfully completed" plesk bin scheduler --run "$ID"
prova "il cron ha scritto cron.log" grep -q eseguito "$VH/httpdocs/cron.log"
contiene "il cron è nel crontab di mrossi" "cron.php" cat /var/spool/cron/crontabs/mrossi
prova "scheduler --delete" plesk bin scheduler --delete "$ID"

echo "== servizi e riparazione"
contiene "service --status web" "is running" plesk bin service --status web
contiene "service --list -detail" "Postfix" plesk bin service --list -detail
prova "service --restart web" plesk bin service --restart web
contiene "repair web -n: tutto ok" "Errors resolved: 0" plesk repair web -n
rm -f /etc/nginx/plesk.conf.d/vhosts/esempio.test.conf
prova "nginx -t NON si accorge del file perso" nginx -t
contiene "repair web -n trova il file perso" "File not found: esempio.test.conf" plesk repair web -n
contiene "repair web -y lo ripara" "[FIXED]" plesk repair web -y
prova "il file generato è tornato" test -f /etc/nginx/plesk.conf.d/vhosts/esempio.test.conf
prova "httpdmng --reconfigure-domain" plesk sbin httpdmng --reconfigure-domain esempio.test
contiene "repair dns -n" "Errors resolved: 0" plesk repair dns -n
contiene "repair db -n" "Errors resolved: 0" plesk repair db -n
contiene "repair sysusers -n" "esempio.test" plesk repair sysusers -n

echo "== backup e ripristino"
contiene "pleskbackup" "The backup finished successfully" plesk bin pleskbackup --domains-name esempio.test -v
B=$(find /var/lib/psa/dumps/clients/mario/domains/esempio.test -name 'backup_info_*.xml' | sort | tail -1)
contiene "pleskrestore --info" "[Domain] esempio.test" plesk bin pleskrestore --info "$B"
contiene "pleskrestore --check-backup" "valid" plesk bin pleskrestore --check-backup "$B"
rm -f "$VH/httpdocs/index.html"
prova "pleskrestore di un solo file" plesk bin pleskrestore --restore "$B" -only-web-content list:httpdocs/index.html -domain-name esempio.test
prova "index.html è tornato, di mrossi" test "$(stat -c %U "$VH/httpdocs/index.html" 2> /dev/null)" = mrossi

echo "== sicurezza e API"
contiene "ip_ban --info" "active" plesk bin ip_ban --info
contiene "ip_ban --ban" "banned" plesk bin ip_ban --ban "203.0.113.7,plesk-apache"
contiene "ip_ban --banned" "203.0.113.7" plesk bin ip_ban --banned
contiene "fail2ban conferma" "203.0.113.7" fail2ban-client status plesk-apache
contiene "ip_ban --unban" "unbanned" plesk bin ip_ban --unban "203.0.113.7,plesk-apache"
contiene "keyinfo: il limite di domini" "lim_dom: 1" plesk bin keyinfo --list
prova "license -c" plesk bin license -c
contiene "admin --set-admin-password" "successfully updated" env PSA_PASSWORD='Admin-Lab!2026x' plesk bin admin --set-admin-password -passwd ""
K=$(plesk bin secret_key --create -ip-address 127.0.0.1 -description "autotest")
contiene "REST: /api/v2/server" "panel_version" curl -sk -H "X-API-Key: $K" https://127.0.0.1:8443/api/v2/server
contiene "REST: /api/v2/domains" "esempio.test" curl -sk -H "X-API-Key: $K" https://127.0.0.1:8443/api/v2/domains
contiene "REST: cli/domain/call" "Domain name:" curl -sk -H "X-API-Key: $K" -H 'Content-Type: application/json' -d '{"params": ["--info", "esempio.test"]}' https://127.0.0.1:8443/api/v2/cli/domain/call
contiene "REST: dominio inesistente" '"code": 1' curl -sk -H "X-API-Key: $K" -H 'Content-Type: application/json' -d '{"params": ["--info", "nonesiste.test"]}' https://127.0.0.1:8443/api/v2/cli/domain/call
contiene "REST: password dell'admin" "esempio.test" curl -sk -u 'admin:Admin-Lab!2026x' https://127.0.0.1:8443/api/v2/domains
test "$(curl -sk -o /dev/null -w '%{http_code}' -H 'X-API-Key: sbagliata' https://127.0.0.1:8443/api/v2/server)" = 401 && ok "REST: chiave sbagliata → 401" || ko "REST: chiave sbagliata → 401"
contiene "secret_key --delete" "removed" plesk bin secret_key --delete -key "$K"
contiene "plesk login" "secret=" plesk login mario

echo
if ((KO == 0)); then
    echo "tutti i controlli sono ok ($OK)"
else
    echo "$KO controlli falliti su $((OK + KO))" >&2
    exit 1
fi
