#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 10: rete e web
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gira sul container "host". La rete (host, router, web) la crea compose.yaml; qui si preparano
# i file: lo script cidr, le liste per nmap, lo script dei namespace, i siti per nginx e apache.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
AREA="$(dirname "$LAB_SRC")"
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md

# ---------------------------------------------------------------- 01-indirizzi-e-configurazione
sezione 01-indirizzi-e-configurazione
cat > cidr.sh << 'EOF'
#!/usr/bin/env bash
# cidr.sh - la funzione cidr del .md come script. Uso: ./cidr.sh 192.168.1.10/23   (oppure: source cidr.sh; cidr ...)
cidr() {
    local ip=${1%/*} bits=${1#*/} a b c d
    IFS=. read -r a b c d <<< "$ip"
    local n=$(( (a << 24) | (b << 16) | (c << 8) | d ))
    local mask=$(( bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
    local rete=$(( n & mask ))
    local bcast=$(( rete | (~mask & 0xFFFFFFFF) ))
    local x
    for x in mask rete bcast; do
        printf '%-10s %d.%d.%d.%d\n' "$x" $(( ${!x} >> 24 & 255 )) $(( ${!x} >> 16 & 255 )) $(( ${!x} >> 8 & 255 )) $(( ${!x} & 255 ))
    done
    echo "host       $(( bits >= 31 ? 2 ** (32 - bits) : 2 ** (32 - bits) - 2 ))"
}
[[ ${BASH_SOURCE[0]} == "$0" ]] && cidr "${1:?uso: $0 IP/PREFISSO}"
EOF
chmod +x cidr.sh
cat > 01-statico.yaml << 'EOF'
# esempio di netplan del .md: da leggere, netplan nel container non c'è (la rete la gestisce Docker)
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.1.10/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
EOF

# ---------------------------------------------------------------- 02-diagnostica
sezione 02-diagnostica
printf '10.10.1.254\n10.10.2.10\n10.10.2.254\n' > host.txt
printf '10.10.2.254\n' > esclusi.txt

# ---------------------------------------------------------------- 03-namespace
sezione 03-namespace
cp "$AREA/03-namespace.sh" . && chmod +x 03-namespace.sh

# ---------------------------------------------------------------- 04-apache-nginx
sezione 04-apache-nginx
mkdir -p mio_sito
echo "<h1>mio sito</h1>" > mio_sito/index.html
cat > mio_sito.nginx << 'EOF'
server {
    listen 80;
    server_name miosito.com www.miosito.com;
    root /var/www/mio_sito;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
cat > api.nginx << 'EOF'
server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
# nel laboratorio apache2 ascolta sulla 8080 (la 80 è di nginx): il virtual host del .md, sulla 8080
cat > mio_sito.conf << 'EOF'
<VirtualHost *:8080>
    ServerName miosito.com
    ServerAlias www.miosito.com
    DocumentRoot /var/www/mio_sito

    <Directory /var/www/mio_sito>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mio_sito_error.log
    CustomLog ${APACHE_LOG_DIR}/mio_sito_access.log combined
</VirtualHost>
EOF
cat > backend.py << 'EOF'
#!/usr/bin/env python3
# backend.py - l'applicazione dietro il reverse proxy: risponde con gli header ricevuti (porta 3000)
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        testo = "".join(f"{k}: {v}\n" for k, v in self.headers.items() if k.lower().startswith(("host", "x-")))
        corpo = f"backend sulla 3000, visto da {self.client_address[0]}\n{testo}".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(corpo)

HTTPServer(("127.0.0.1", 3000), H).serve_forever()
EOF
chmod +x backend.py

# ---------------------------------------------------------------- 10-esercizi
sezione 10-esercizi
mkdir -p risposte
cp "$LAB_SRC/verifica.sh" .
chmod +x verifica.sh

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 10 pronto in $DEST: una cartella per ogni .md"
    echo "Rete: questo host 10.10.1.10 -> router 10.10.1.254 -> web 10.10.2.10 (prova: traceroute -n web)"
    echo "Per ripartire da zero con i file: bash $LAB_SRC/prepara.sh"
fi
