# Apache e Nginx

> **Laboratorio**: `./lab.sh 10`, poi `cd 04-apache-nginx`. Cosa contiene: [lab/](lab/).

I due web server più diffusi su Debian/Ubuntu. Si gestiscono entrambi con `systemctl`
(vedi [../06-sistema/07-servizi.md](../06-sistema/07-servizi.md)); cambiano il modo di abilitare siti e moduli.

| | Apache | Nginx |
|---|---|---|
| configurazione principale | `/etc/apache2/apache2.conf` | `/etc/nginx/nginx.conf` |
| porte | `/etc/apache2/ports.conf` | direttiva `listen` in ogni sito |
| siti disponibili | `/etc/apache2/sites-available/` | `/etc/nginx/sites-available/` |
| siti abilitati (link simbolici) | `/etc/apache2/sites-enabled/` | `/etc/nginx/sites-enabled/` |
| abilitare un sito | `a2ensite` | `ln -s` a mano |
| moduli | `a2enmod` / `a2dismod` | compilati o caricati con `load_module` |
| verifica configurazione | `apache2ctl configtest` | `nginx -t` |
| log | `/var/log/apache2/` | `/var/log/nginx/` |

## Il ciclo di ogni modifica
Modifico la configurazione, la **verifico**, poi faccio **reload** (non restart).
```bash
sudo nginx -t && sudo systemctl reload nginx              # reload solo se la sintassi è corretta
sudo apache2ctl configtest && sudo systemctl reload apache2
```
`reload` rilegge la configurazione senza interrompere le connessioni in corso; `restart` ferma e riavvia il processo.
Se la configurazione ha un errore, `reload` fallisce e il server continua a girare con quella vecchia,
mentre dopo un `restart` il server resta **spento**.

> **NOTA**: `systemctl reload nginx` torna appena ha mandato il segnale al processo master: per un istante
> rispondono ancora i worker con la configurazione vecchia. Un `curl` lanciato subito dopo, in uno script,
> può vedere il sito di prima: meglio un `sleep 1` prima di verificare.

## Apache
```bash
sudo a2ensite mio_sito.conf       # abilita un sito (crea il link in sites-enabled/)
sudo a2dissite mio_sito.conf      # lo disabilita (rimuove il link)
sudo a2dissite 000-default.conf   # disabilita la pagina di default di Apache

sudo a2enmod rewrite              # abilita mod_rewrite (serve a Laravel e WordPress per gli URL "puliti")
sudo a2enmod ssl headers          # più moduli insieme
sudo a2dismod status              # disabilita un modulo
sudo systemctl restart apache2    # abilitare o disabilitare un modulo richiede restart, non basta reload

apache2ctl configtest             # verifica la configurazione ("Syntax OK")
apache2ctl -S                     # virtual host attivi: quale file risponde a quale nome e porta
apache2ctl -M                     # moduli caricati
a2query -s                        # siti abilitati
```

Esempio: file `/etc/apache2/sites-available/mio_sito.conf`
```apache
<VirtualHost *:80>
    ServerName miosito.com
    ServerAlias www.miosito.com
    DocumentRoot /var/www/mio_sito/public

    <Directory /var/www/mio_sito/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mio_sito_error.log
    CustomLog ${APACHE_LOG_DIR}/mio_sito_access.log combined
</VirtualHost>
```
`AllowOverride All` fa leggere i file `.htaccess` del progetto (Laravel ne ha uno in `public/`).

## Nginx
```bash
sudo nginx -t                     # verifica la configurazione
sudo nginx -T                     # verifica E stampa la configurazione completa, con tutti i file inclusi: per il debug
nginx -V                          # versione, moduli compilati e opzioni di compilazione
sudo nginx -s reload              # ricarica la configurazione (UGUALE a systemctl reload nginx)
sudo nginx -s stop                # ferma subito
sudo nginx -s quit                # ferma dopo aver finito di servire le richieste in corso
sudo nginx -s reopen              # riapre i file di log (lo usa logrotate dopo averli ruotati)
nginx -c /percorso/nginx.conf     # avvia con un file di configurazione alternativo
```

Abilitare e disabilitare un sito:
```bash
sudo ln -s /etc/nginx/sites-available/mio_sito /etc/nginx/sites-enabled/ # abilita
sudo rm /etc/nginx/sites-enabled/mio_sito                                 # disabilita: toglie solo il link, il file resta in sites-available
sudo rm /etc/nginx/sites-enabled/default                                  # disabilita il sito di default
sudo nginx -t && sudo systemctl reload nginx
```

Moduli: i moduli dinamici si installano con apt (es. `libnginx-mod-http-image-filter`) e su Debian/Ubuntu il
pacchetto aggiunge da solo un file in `/etc/nginx/modules-enabled/`. A mano si carica con una riga in cima a `nginx.conf`:
```nginx
load_module modules/ngx_http_image_filter_module.so;
```
Per disattivarlo si commenta la riga (o si rimuove il file da `modules-enabled/`), poi `nginx -t` e reload.

### Esempio: sito statico
File `/etc/nginx/sites-available/mio_sito`:
```nginx
server {
    listen 80;
    server_name miosito.com www.miosito.com;
    root /var/www/mio_sito;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Esempio: applicazione Laravel con PHP-FPM
```nginx
server {
    listen 80;
    server_name app.example.com;
    root /var/www/app/public;            # SEMPRE la cartella public, mai la radice del progetto (esporrebbe .env)
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;  # tutto ciò che non è un file reale va al front controller
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;     # il socket di PHP-FPM (ls /run/php/ per la versione)
    }

    location ~ /\.(?!well-known) {
        deny all;                                       # blocca i file nascosti (.env, .git), tranne .well-known per i certificati
    }

    client_max_body_size 20M;                           # dimensione massima degli upload (default 1M)
}
```

### Esempio: reverse proxy verso un'altra applicazione
Nginx riceve le richieste e le passa a un servizio in ascolto su un'altra porta (Node, un container, un bilanciatore).
```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;                                  # il nome richiesto dal client, non "127.0.0.1"
        proxy_set_header X-Real-IP $remote_addr;                      # l'IP vero del client
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # la catena di proxy attraversati
        proxy_set_header X-Forwarded-Proto $scheme;                   # http o https: serve all'app per generare URL corretti
    }
}
```
Senza gli header `X-Forwarded-*` l'applicazione vede tutte le richieste arrivare da `127.0.0.1`.
In Laravel vanno accettati configurando i trusted proxies.

## HTTPS con Let's Encrypt
`certbot` ottiene un certificato gratuito e modifica da solo la configurazione del sito. Servono un dominio che
punta già al server (record A) e la porta 80 aperta: Let's Encrypt verifica il dominio chiamando
`http://dominio/.well-known/acme-challenge/...`.
```bash
sudo apt install certbot python3-certbot-nginx   # per Apache: python3-certbot-apache
sudo certbot --nginx -d miosito.com -d www.miosito.com   # certificato + blocco "listen 443 ssl" + redirect da http a https
sudo certbot --apache -d miosito.com                      # UGUALE per Apache
sudo certbot certificates                        # certificati installati, domini e scadenza
sudo certbot renew --dry-run                     # prova il rinnovo: i certificati durano 90 giorni, li rinnova un timer di systemd
systemctl list-timers | grep certbot             # il timer del rinnovo automatico
```
I file finiscono in `/etc/letsencrypt/live/miosito.com/` (`fullchain.pem` e `privkey.pem`).
Il nome nel certificato deve coincidere con `server_name`/`ServerName`: per questo i nomi di dominio non possono
contenere `_` (sono ammessi lettere, cifre e `-`).

## Esempi pratici
```bash
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log   # entrambi i log in tempo reale

# le 10 pagine che rispondono più spesso con errore 5xx (il campo 9 del formato combined è lo status)
awk '$9 ~ /^5/ {print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# i 10 IP che fanno più richieste
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head

# prima di cambiare il DNS: il nuovo server risponde per quel dominio?
curl -I -H 'Host: miosito.com' http://203.0.113.10/

# chi è in ascolto su 80 e 443 (se nginx non parte: "Address already in use", spesso c'è apache2 attivo)
sudo ss -tlnp | grep -E ':(80|443)\b'
```

Vedi anche: [05-load-balancer/](05-load-balancer/) per mettere più server dietro un bilanciatore.
