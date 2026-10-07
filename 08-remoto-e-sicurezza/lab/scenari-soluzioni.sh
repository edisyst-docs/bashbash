#!/usr/bin/env bash
# scenari-soluzioni.sh FASE N - le riparazioni di riferimento degli scenari di 07-scenari.md (area 08), e alcune "scorciatoie"
# che sembrano ripararli ma non lo fanno (servono a provare che scenari.sh controlla non si lascia ingannare).
#   scenari-soluzioni.sh risolvi N     la riparazione giusta
#   scenari-soluzioni.sh sbagliata N   un tentativo che non basta (non esiste per tutti gli scenari)
# La usa scenari-autotest.sh. Gira come root sul client del laboratorio 08. Per toccare i server usa l'accesso del banco di prova
# (stessa chiave e stessa config di scenari.sh): lo studente, invece, lo fa con la password di edoardo.
set -uo pipefail
fase=${1:?uso: $0 risolvi|sbagliata N}
n=${2:?uso: $0 FASE N}
HK=/root/.scenari
SSHDIR=$HOME/.ssh
DIR=${LAB_SCENARI:-$HOME/lab/07-scenari}

srv() { local s=$1; shift; ssh -F "$HK/config" "$s" "$@"; }
rootexec() {
    local b; b=$(printf '%s' "$2" | base64 -w0)
    srv "$1" "echo edoardo | sudo -S -p '' bash -c \"\$(echo $b | base64 -d)\"" 2> /dev/null
}

risolvi() {
    case $n in
        1) chmod 600 "$SSHDIR/id_ed25519" ;;
        2) sed -i '/^    Port 2222$/d' "$SSHDIR/config" ;;
        3) ssh-keygen -R produzione > /dev/null 2>&1
           ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes produzione true > /dev/null 2>&1 ;;
        4) rootexec produzione "chmod 700 /home/deploy/.ssh" ;;
        5) sed -i 's/^    ProxyJump staging$/    ProxyJump produzione/' "$SSHDIR/config" ;;
        6) rootexec staging "ufw allow 80/tcp" ;;
        7) rootexec produzione "fail2ban-client set sshd unbanip 10.20.1.5" ;;
        8) gpg --import "$DIR/la-mia-chiave.asc" ;;
        *) echo "scenari da 1 a 8" >&2; exit 2 ;;
    esac
}
sbagliata() {
    case $n in
        1) chmod 640 "$SSHDIR/id_ed25519" ;;                                                                    # il gruppo non deve leggerla: ssh vuole 600
        2) ssh -p 22 -o BatchMode=yes produzione true ;;                                                        # a mano si entra, ma il config resta rotto
        3) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null produzione true ;;                   # si entra ignorando l'avviso (pericoloso), ma known_hosts resta sbagliato
        4) rootexec produzione "cat /home/deploy/.ssh/authorized_keys >> /home/deploy/.ssh/authorized_keys" ;;  # ricopiare la chiave non cambia i permessi della cartella
        5) sed -i '/^    ProxyJump staging$/d' "$SSHDIR/config" ;;                                              # senza salto, db-interno non si raggiunge
        6) rootexec staging "ufw allow 8080/tcp" ;;                                                             # la porta sbagliata
        7) rootexec produzione "systemctl restart ssh" ;;                                                       # riavviare sshd non toglie il ban
        8) gpg --batch --passphrase '' --quick-gen-key "Altro <altro@example.com>" default default never 2> /dev/null ;;   # una chiave nuova non apre un messaggio cifrato per un'altra
        *) echo "nessun tentativo sbagliato per lo scenario $n" >&2; exit 2 ;;
    esac
}
case $fase in
    risolvi|sbagliata) "$fase" ;;
    *) echo "fasi: risolvi, sbagliata" >&2; exit 2 ;;
esac
