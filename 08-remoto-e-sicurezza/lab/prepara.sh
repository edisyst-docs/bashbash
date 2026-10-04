#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 08: ssh, firewall, gpg
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gira sul container "client". I server (produzione, staging, db-interno) li avvia compose.yaml
# e li prepara server.sh; qui si creano i file da usare dal client.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
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

# ---------------------------------------------------------------- 01-ssh
sezione 01-ssh
# il ~/.ssh/config del .md adattato ai server del laboratorio: da copiare in ~/.ssh/config
cat > config-esempio << 'EOF'
Host produzione
    HostName produzione
    User deploy
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host staging
    HostName staging
    User deploy

# raggiungibile solo passando da produzione
Host db-interno
    HostName db-interno
    User deploy
    ProxyJump produzione

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
EOF
cat > multiplexing << 'EOF'
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
EOF
echo "file da copiare sul server" > file.txt
echo "SELECT 1;" > file.sql
mkdir -p cartella && touch cartella/uno.txt cartella/due.txt
printf '#!/usr/bin/env bash\necho "script eseguito su $(hostname) da $(whoami), argomenti: $*"\n' > script_locale.sh
cp script_locale.sh script.sh
touch dump1.sql dump2.sql

# ---------------------------------------------------------------- 02-firewall-e-hardening
# i file di configurazione del .md, pronti da copiare sul server (scp) e spostare con sudo
sezione 02-firewall-e-hardening
cat > 10-hardening.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
AllowUsers deploy edoardo
EOF
echo 'Port 2222' > 05-porta.conf
cat > jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1
backend  = systemd

[sshd]
enabled = true
port    = ssh,2222
EOF

# ---------------------------------------------------------------- 03-gpg
sezione 03-gpg
printf 'CREATE TABLE utenti (id INT);\nINSERT INTO utenti VALUES (1), (2);\n' > backup.sql
echo "appunti riservati" > note.txt
mkdir -p cartella && echo "documento" > cartella/documento.txt
head -c 4096 /dev/urandom > contratto.pdf
tar -czf release.tar.gz cartella
# il secondo utente per l'esempio "scambio tra due utenti sulla stessa macchina"
if [[ $EUID -eq 0 ]] && ! id utente > /dev/null 2>&1; then
    useradd -m -s /bin/bash utente
    echo "utente:utente" | chpasswd
fi

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 08 pronto in $DEST: una cartella per ogni .md"
    echo "Server: produzione, staging (dal client), db-interno (solo via produzione)"
    echo "Utenti sui server: deploy/deploy, edoardo/edoardo (con sudo)"
    echo "Per ripartire da zero con i file: bash $LAB_SRC/prepara.sh"
fi
