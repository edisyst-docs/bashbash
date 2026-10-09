#!/usr/bin/env bash
# soluzioni.sh FASE N - le soluzioni di riferimento e l'ambiente degli esercizi di 06-esercizi.md (area 08).
#   soluzioni.sh prepara N    porta il sistema nello stato di partenza dell'esercizio N
#   soluzioni.sh risolvi N    la soluzione di riferimento
#   soluzioni.sh controllo N  stampa lo stato che il controllo guarda (vuoto se basta l'output)
#   soluzioni.sh pulisci N    riporta il sistema com'era (tunnel, regole ufw, interfaccia wg0...)
# La usa verifica.sh, con l'agente ssh già avviato (ha la chiave autorizzata sui server) e GNUPGHOME in una cartella usa-e-getta.
# Gira come root sul client del laboratorio 08; si lancia dalla cartella di lavoro dell'esercizio (una copia della palestra).
set -uo pipefail
fase=${1:?uso: $0 prepara|risolvi|controllo|pulisci N}
n=${2:?uso: $0 FASE N}

# esegue un comando come root su un server via ssh e sudo (edoardo ha sudo, password edoardo)
rsudo() { local s=$1; shift; ssh "edoardo@$s" "echo edoardo | sudo -S -p '' $*"; }
GPG=(gpg --batch --pinentry-mode loopback)
# riporta ufw di staging com'era (nessuna regola; il firewall resta inattivo) e toglie le copie che "reset" lascia in /etc/ufw
ufw_pristina() { rsudo staging "sh -c 'ufw --force reset > /dev/null; rm -f /etc/ufw/*.rules.2*'"; }

prepara() {
    case $n in
        14) "${GPG[@]}" --passphrase '' --quick-gen-key "Firma <firma@example.com>" default default never 2> /dev/null ;;
        19) rsudo staging ufw allow 80/tcp > /dev/null ;;
        20) rsudo staging ufw allow 8080/tcp > /dev/null; rsudo staging ufw allow 9090/tcp > /dev/null ;;
        21) rsudo staging ufw allow OpenSSH comment ssh > /dev/null; rsudo staging ufw allow 80/tcp > /dev/null; rsudo staging ufw allow 443/tcp > /dev/null ;;
    esac
    return 0
}
pulisci() {
    case $n in
        8)  pkill -f 'ssh .*8081:' 2> /dev/null ;;
        9)  pkill -f 'ssh .*D ?1080' 2> /dev/null ;;
        10) rsudo staging ufw delete allow 8080/tcp > /dev/null 2>&1 ;;
        1[7-9]|2[0-2]) ufw_pristina > /dev/null 2>&1 ;;
        16) ip link del wg0 2> /dev/null ;;
    esac
    return 0
}
controllo() {
    case $n in
        1)  ssh-keygen -lf chiave.pub | awk '{print $1, $NF}'; awk '{print $3}' chiave.pub; stat -c %a chiave ;;
        2)  ssh -F config -G prod 2>&1 | grep -E '^(hostname|user) ' ;;
        3)  ssh -F config -G db 2>&1 | grep -E '^(hostname|user|proxyjump) ' ;;
        7)  head -1 app.log; wc -l < app.log ;;
        8)  sleep 1; curl -si --max-time 3 http://localhost:8081/ | tr -d '\r' | grep -iE '^(server:|risposta)' | sed 's|/.*||' ;;
        9)  sleep 1; curl -s --max-time 3 --socks5-hostname localhost:1080 http://db-interno/ ;;
        10) rsudo staging ufw show added 2>&1 | grep -E '^ufw' ;;
        17|18|19|20) rsudo staging ufw show added 2>&1 | grep -E '^ufw' ;;
        21) cat regole-ufw.txt ;;
        22) rsudo staging ufw show added 2>&1 | grep -c 8443 ;;
        12) gpg --list-keys --with-colons 2> /dev/null | awk -F: '/^uid/ {print $10}' ;;
        13) "${GPG[@]}" --passphrase lab -d segreto.txt.gpg 2> /dev/null ;;
        14) gpg --verify documento.txt.sig documento.txt 2>&1 | grep -c 'Good signature' ;;
        15) wc -c < priv; wc -c < pub; wg pubkey < priv | cmp -s - pub && echo coerenti ;;
        16) wg show wg0 listen-port; ip -4 -o addr show wg0 | awk '{print $4}'; ip link show wg0 | grep -c 'UP,LOWER_UP' ;;
    esac
    return 0
}
risolvi() {
    case $n in
        1)  ssh-keygen -q -t ed25519 -N '' -C esercizio -f chiave ;;
        2)  printf 'Host prod\n    HostName produzione\n    User deploy\n' > config ;;
        3)  printf 'Host db\n    HostName db-interno\n    User deploy\n    ProxyJump deploy@produzione\n' > config ;;
        4)  ssh deploy@produzione hostname ;;
        5)  ssh -J deploy@produzione deploy@db-interno hostname ;;
        6)  ssh deploy@produzione 'bash -s' < script.sh ;;
        7)  scp -q deploy@staging:/var/log/app/app.log . ;;
        8)  ssh -fNL 8081:db-interno:80 deploy@produzione ;;
        9)  ssh -fND 1080 deploy@produzione ;;
        10) rsudo staging ufw allow 8080/tcp > /dev/null ;;
        11) rsudo produzione fail2ban-client status sshd | awk '/Currently banned/ {print $NF}' ;;
        12) "${GPG[@]}" --passphrase '' --quick-gen-key "Mario Rossi <mario@example.com>" default default never 2> /dev/null ;;
        13) "${GPG[@]}" --passphrase lab -c segreto.txt ;;
        14) "${GPG[@]}" --passphrase '' --detach-sign documento.txt ;;
        15) wg genkey | tee priv | wg pubkey > pub ;;
        17) rsudo staging ufw allow from 10.20.1.5 to any port 3306 proto tcp comment "'mysql dal client'" > /dev/null ;;
        18) rsudo staging ufw deny from 198.51.100.7 comment scanner > /dev/null ;;
        19) rsudo staging ufw insert 1 deny from 198.51.100.7 > /dev/null ;;
        20) rsudo staging ufw delete allow 8080/tcp > /dev/null ;;
        21) rsudo staging ufw show added | grep '^ufw' > regole-ufw.txt ;;
        22) rsudo staging ufw --dry-run allow 8443/tcp | grep "ufw-user-input.*8443" ;;
        16) wg genkey > priv
            ip link add wg0 type wireguard
            wg set wg0 private-key priv listen-port 51820
            ip addr add 10.200.0.1/24 dev wg0
            ip link set wg0 up ;;
        *)  echo "esercizi da 1 a 22" >&2; exit 2 ;;
    esac
}
case $fase in
    prepara|risolvi|controllo|pulisci) "$fase" ;;
    *) echo "fasi: prepara, risolvi, controllo, pulisci" >&2; exit 2 ;;
esac
