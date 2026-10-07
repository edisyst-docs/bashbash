#!/usr/bin/env bash
# scenari.sh - gli scenari guidati di 07-scenari.md (area 08): un guasto vero fra il client e i tre server, da diagnosticare e riparare.
#   scenari.sh guasta N      porta tutto in perfetta salute (chiave, config, server), poi rompe come lo scenario N e stampa il "ticket"
#   scenari.sh controlla [N] dice se il sintomo è sparito (senza rivelare la causa); N è lo scenario in corso se omesso
#   scenari.sh ripristina    toglie ogni guasto: il sistema torna in salute
# NON si legge prima di aver provato: qui dentro ci sono i guasti. Gira come root sul client del laboratorio 08.
# Per toccare i server usa una chiave sua (in /root/.scenari, fuori da ~/.ssh) e passa sempre da staging per arrivare a produzione:
# così funziona anche quando il client è stato bannato da produzione (scenario 7).
set -uo pipefail
cmd=${1:-}
n=${2:-}
NSCENARI=8
HK=/root/.scenari
STATO=$HK/scenario-in-corso
DIR=${LAB_SCENARI:-$HOME/lab/07-scenari}      # dove l'8 mette i file
SSHDIR="$HOME/.ssh"

[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 08: ./lab.sh 08)" >&2; exit 2; }
getent hosts produzione > /dev/null || { echo "serve il client del laboratorio 08 (non risolve 'produzione')" >&2; exit 2; }

# ---------------------------------------------------------------- l'accesso del banco di prova ai server
srv() { local s=$1; shift; ssh -F "$HK/config" "$s" "$@"; }
rootexec() {        # rootexec SERVER 'script': esegue lo script come root sul server (edoardo ha sudo)
    local b; b=$(printf '%s' "$2" | base64 -w0)
    srv "$1" "echo edoardo | sudo -S -p '' bash -c \"\$(echo $b | base64 -d)\"" 2> /dev/null
}
accesso_banco() {
    mkdir -p "$HK"; chmod 700 "$HK"
    [[ -f $HK/chiave ]] || ssh-keygen -q -t ed25519 -N '' -C scenari -f "$HK/chiave"
    cat > "$HK/config" << EOF
Host *
    User edoardo
    IdentityFile $HK/chiave
    IdentitiesOnly yes
    UserKnownHostsFile $HK/known_hosts
    StrictHostKeyChecking accept-new
    LogLevel ERROR
    ConnectTimeout 8
Host staging
Host produzione
    ProxyJump staging
Host db-interno
    ProxyJump staging,produzione
EOF
    srv staging true 2> /dev/null && srv produzione true 2> /dev/null && srv db-interno true 2> /dev/null && return 0
    # la prima volta: la chiave del banco di prova si autorizza con la password di edoardo (una volta sola, in silenzio)
    local ap; ap=$(mktemp); printf '#!/bin/sh\necho edoardo\n' > "$ap"; chmod +x "$ap"
    local pub; pub=$(cat "$HK/chiave.pub")
    for s in staging produzione db-interno; do
        srv "$s" true 2> /dev/null && continue
        case $s in db-interno) salto=(-o ProxyJump=edoardo@produzione) ;; *) salto=() ;; esac
        SSH_ASKPASS=$ap SSH_ASKPASS_REQUIRE=force ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
            -o PubkeyAuthentication=no "${salto[@]}" "edoardo@$s" \
            "mkdir -p ~/.ssh; chmod 700 ~/.ssh; echo '$pub' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys" > /dev/null 2>&1
    done
    rm -f "$ap"
    srv staging true 2> /dev/null && srv produzione true 2> /dev/null && srv db-interno true 2> /dev/null
}

# ---------------------------------------------------------------- il sistema in salute
salute() {
    accesso_banco || { echo "non riesco a raggiungere i server (sono avviati?)" >&2; exit 2; }
    # i server: niente ban, niente firewall, la chiave dello studente autorizzata, nginx e sshd attivi
    rm -rf "$SSHDIR" "$HOME/.gnupg"; rm -f "$DIR/messaggio.txt.gpg" "$DIR/la-mia-chiave.asc"    # la cartella DIR no: ci sta lo script che sta girando
    mkdir -p "$SSHDIR" "$DIR"; chmod 700 "$SSHDIR"
    ssh-keygen -q -t ed25519 -N '' -C studente -f "$SSHDIR/id_ed25519"
    local pub; pub=$(cat "$SSHDIR/id_ed25519.pub")
    for s in staging produzione db-interno; do
        rootexec "$s" "
            fail2ban-client unban --all > /dev/null 2>&1
            ufw --force disable > /dev/null 2>&1; ufw --force reset > /dev/null 2>&1
            install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
            echo '$pub' > /home/deploy/.ssh/authorized_keys
            chown deploy:deploy /home/deploy/.ssh/authorized_keys; chmod 600 /home/deploy/.ssh/authorized_keys
            chmod 755 /home/deploy; systemctl start ssh nginx 2> /dev/null; true"
    done
    # ufw lascia le sue catene anche da spento: al giro dopo "ufw enable" non le ricollega a INPUT e blocca tutto (anche ssh).
    # Si tolgono tutte e si fa ripartire fail2ban, che ricrea la propria catena
    rootexec staging "if iptables -S | grep -q '^-N ufw'; then
            for t in iptables ip6tables; do \$t -P INPUT ACCEPT; \$t -P FORWARD ACCEPT; \$t -F; \$t -X; done
            systemctl restart fail2ban; sleep 2
        fi; true"
    # staging è la porta di servizio del banco di prova (e la via d'uscita dello scenario 7): il client non deve poter essere bannato lì
    rootexec staging "printf '[DEFAULT]\nignoreip = 127.0.0.1/8 ::1 10.20.1.5\n' > /etc/fail2ban/jail.d/zz-scenari.local; fail2ban-client reload > /dev/null 2>&1; true"
    # la config dello studente e i server già conosciuti (le chiavi vere dei server)
    cat > "$SSHDIR/config" << 'EOF'
Host produzione
    HostName produzione
    User deploy
Host staging
    User deploy
Host db-interno
    User deploy
    ProxyJump produzione
EOF
    : > "$SSHDIR/known_hosts"
    for s in staging produzione db-interno; do
        k=$(srv "$s" 'cut -d" " -f1,2 /etc/ssh/ssh_host_ed25519_key.pub')
        echo "$s $k" >> "$SSHDIR/known_hosts"
    done
    chmod 600 "$SSHDIR/config" "$SSHDIR/known_hosts"
    rm -f "$STATO"
}

# ---------------------------------------------------------------- i guasti e i loro sintomi
guasta() {
    case $1 in
        1) chmod 644 "$SSHDIR/id_ed25519"
           echo "'ssh produzione' ieri entrava da solo con la chiave. Oggi chiede la password." ;;
        2) sed -i '/^Host produzione$/a\    Port 2222' "$SSHDIR/config"
           echo "'ssh produzione' risponde 'Connection refused', ma il server è acceso e gli altri colleghi ci entrano." ;;
        3) local f; rm -f "$HK/falsa" "$HK/falsa.pub"; ssh-keygen -q -t ed25519 -N '' -f "$HK/falsa"; f=$(cut -d' ' -f1,2 "$HK/falsa.pub"); rm -f "$HK/falsa" "$HK/falsa.pub"
           sed -i '/^produzione /d' "$SSHDIR/known_hosts"; echo "produzione $f" >> "$SSHDIR/known_hosts"
           echo "'ssh produzione' si rifiuta di collegarsi e parla di un attacco. Ieri funzionava." ;;
        4) rootexec produzione "chmod 777 /home/deploy/.ssh"
           echo "'ssh produzione' chiede la password da stamattina, ma la chiave non è cambiata e sul tuo computer non hai toccato nulla." ;;
        5) sed -i 's/^    ProxyJump produzione$/    ProxyJump staging/' "$SSHDIR/config"
           echo "'ssh db-interno' (il database, dietro il bastion) non si apre più. Il collega dice che ieri ci entrava." ;;
        6) rootexec staging "ufw allow 22/tcp > /dev/null; ufw --force enable > /dev/null"
           echo "Il sito su staging (http://staging/) non risponde più da questo computer. Via ssh, però, ci si entra." ;;
        7) rootexec produzione "fail2ban-client set sshd banip 10.20.1.5 > /dev/null"
           echo "'ssh produzione' va in timeout da stamattina. Il server è acceso, e un collega da un altro computer ci entra." ;;
        8) guasto_gpg
           echo "Un collega ti ha mandato un messaggio cifrato ($DIR/messaggio.txt.gpg) e questo computer non riesce a leggerlo." ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
}
guasto_gpg() {
    local g=$HK/gpg; rm -rf "$g"; mkdir -p "$g"; chmod 700 "$g"
    local G=(gpg --batch --pinentry-mode loopback --passphrase '' --homedir "$g")
    "${G[@]}" --quick-gen-key "Studente <studente@example.com>" default default never 2> /dev/null
    echo "il codice del cassetto è 4721" > "$g/in-chiaro.txt"
    "${G[@]}" --trust-model always -r studente@example.com --armor -o "$DIR/messaggio.txt.gpg" -e "$g/in-chiaro.txt" 2> /dev/null
    "${G[@]}" --armor --export-secret-keys studente@example.com > "$DIR/la-mia-chiave.asc" 2> /dev/null
    rm -rf "$g"; rm -rf "$HOME/.gnupg"
}

# ---------------------------------------------------------------- i controlli: il sintomo è sparito?
ESITO=0
prova() {       # prova "descrizione" comando...   (stampa OK / ANCORA NO)
    local d=$1; shift
    if "$@" > /dev/null 2>&1; then echo "  OK        $d"; else echo "  ANCORA NO $d"; ESITO=1; fi
}
entra() { ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=yes "$@" true; }     # con la chiave, senza chiedere nulla, e con host noto
chiave_ok() { [[ $(stat -c %a "$SSHDIR/id_ed25519") == 600 || $(stat -c %a "$SSHDIR/id_ed25519") == 400 ]]; }
web_staging() { [[ $(curl -s --max-time 4 http://staging/) == "risposta da staging" ]]; }
decifra() { [[ $(gpg --batch -d "$DIR/messaggio.txt.gpg" 2> /dev/null) == "il codice del cassetto è 4721" ]]; }
controlla() {
    case $1 in
        1) prova "la chiave ha permessi che ssh accetta" chiave_ok
           prova "ssh produzione entra con la chiave, senza password" entra produzione ;;
        2) prova "ssh produzione entra con la chiave" entra produzione ;;
        3) prova "ssh produzione entra, con la chiave vera del server" entra produzione ;;
        4) prova "ssh produzione entra con la chiave" entra produzione ;;
        5) prova "ssh db-interno entra (passando dal bastion)" entra db-interno
           prova "ssh produzione entra ancora" entra produzione ;;
        6) prova "il sito su staging risponde" web_staging
           prova "ssh staging entra ancora" entra staging ;;
        7) prova "ssh produzione entra da questo computer" entra produzione ;;
        8) prova "il messaggio si decifra e dice il codice" decifra ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    if (( ESITO == 0 )); then echo "RISOLTO"; else echo "non ancora"; fi
    return $ESITO
}

case $cmd in
    guasta)
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 guasta N   (N da 1 a $NSCENARI)" >&2; exit 2; }
        salute; guasta "$n"; echo "$n" > "$STATO" ;;
    controlla)
        [[ -n $n ]] || n=$(cat "$STATO" 2> /dev/null) || { echo "nessuno scenario in corso: ./scenari.sh guasta N" >&2; exit 2; }
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 controlla [N]" >&2; exit 2; }
        controlla "$n" ;;
    ripristina) salute; echo "sistema in salute" ;;
    *) echo "uso: $0 guasta N | controlla [N] | ripristina" >&2; exit 2 ;;
esac
