#!/usr/bin/env bash
# server.sh - prepara un server del laboratorio 08. Lo esegue compose (post_start) come root, a ogni avvio.
set -euo pipefail

# utenti: deploy senza sudo, edoardo con sudo. Password uguali al nome: si entra la prima volta con
# la password, si copia la chiave con ssh-copy-id, poi si disattivano le password (02-firewall-e-hardening.md)
for u in deploy edoardo; do
    id "$u" > /dev/null 2>&1 || useradd -m -s /bin/bash "$u"
    echo "$u:$u" | chpasswd
done
usermod -aG sudo edoardo

# una pagina che dice su quale server si è arrivati (utile con i tunnel: curl localhost:8080)
echo "risposta da $(hostname)" > /var/www/html/index.html

# qualche file da scaricare con scp e sftp
mkdir -p /var/log/app
seq 1 50 | sed "s/^/$(hostname) riga di log /" > /var/log/app/app.log
chmod 644 /var/log/app/app.log
