#!/usr/bin/env bash
# scenari.sh - gli scenari guidati di 10-scenari.md (area 07): un guasto vero nel dominio Active Directory lab.test.
#   scenari.sh guasta N      porta il dominio in perfetta salute, poi lo rompe come lo scenario N e stampa il "ticket"
#   scenari.sh controlla [N] dice se il sintomo è sparito (senza rivelare la causa); N è lo scenario in corso se omesso
#   scenari.sh ripristina    toglie ogni guasto: utenti, DNS, policy e join tornano in salute
# NON si legge prima di aver provato: qui dentro ci sono i guasti. Gira come root su pc01 del laboratorio 07.
set -uo pipefail
cmd=${1:-}
n=${2:-}
NSCENARI=8
DIR=${LAB_SCENARI:-$HOME/lab/10-scenari}
W=$DIR/lavoro
STATO=/run/scenario-in-corso
PW='Passw0rd!2026'
A=(-H ldap://dc1.lab.test -U "administrator%$PW")
DNS=(-U "administrator%$PW")
ZONA=0.30.10.in-addr.arpa

[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 07: ./lab.sh 07)" >&2; exit 2; }
[[ $(hostname) == pc01 ]] && getent hosts dc1.lab.test > /dev/null || { echo "serve pc01 del laboratorio 07 (non vede dc1.lab.test)" >&2; exit 2; }

st() { samba-tool "$@" 2> /dev/null; }       # samba-tool senza l'avviso sulle password in riga di comando

# ---------------------------------------------------------------- tutto in salute
utente() {      # utente NOME: esiste, con la password Passw0rd!NOME, abilitato e sbloccato
    st user create "$1" "Passw0rd!$1" "${A[@]}" > /dev/null || st user setpassword "$1" --newpassword="Passw0rd!$1" "${A[@]}" > /dev/null
    st user enable "$1" "${A[@]}" > /dev/null; st user unlock "$1" "${A[@]}" > /dev/null
}
salute() {
    printf 'nameserver 10.30.0.10\nsearch lab.test\n' > /etc/resolv.conf
    local t; t=$(mktemp); grep -v 'dc1.lab.test' /etc/hosts > "$t"; cat "$t" > /etc/hosts; rm -f "$t"    # /etc/hosts è montato da Docker: si riscrive sul posto
    st domain passwordsettings set --complexity=on --min-pwd-length=7 --account-lockout-threshold=0 "${A[@]}" > /dev/null
    local u; for u in anna marco sara; do utente "$u"; done
    st dns zoneinfo dc1.lab.test "$ZONA" "${DNS[@]}" > /dev/null || {
        st dns zonecreate dc1.lab.test "$ZONA" "${DNS[@]}" > /dev/null
        st dns add dc1.lab.test "$ZONA" 10 PTR dc1.lab.test "${DNS[@]}" > /dev/null
        st dns add dc1.lab.test "$ZONA" 5 PTR pc01.lab.test "${DNS[@]}" > /dev/null; }
    local ip; for ip in $(st dns query dc1.lab.test lab.test web A "${DNS[@]}" | grep -oE 'A: [0-9.]+' | cut -d' ' -f2); do
        st dns delete dc1.lab.test lab.test web A "$ip" "${DNS[@]}" > /dev/null
    done
    net ads testjoin > /dev/null 2>&1 || net ads join -U "administrator%$PW" > /dev/null 2>&1
    kdestroy 2> /dev/null
    mkdir -p "$W"; find "$W" -mindepth 1 -delete
    rm -f "$STATO"
}

# ---------------------------------------------------------------- i guasti e i loro sintomi
guasta() {
    case $1 in
        1) printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf
           echo "Su questo PC nessuno riesce più a entrare nel dominio: 'kinit anna@LAB.TEST' non trova il controller. La rete funziona." ;;
        2) st domain passwordsettings set --account-lockout-threshold=3 --account-lockout-duration=30 --reset-account-lockout-after=30 "${A[@]}" > /dev/null
           for _ in 1 2 3 4; do echo sbagliata | kinit anna@LAB.TEST > /dev/null 2>&1; done
           echo "anna dice di usare la password giusta (Passw0rd!anna) ma 'kinit anna@LAB.TEST' risponde \"Client's credentials have been revoked\"." ;;
        3) st user disable sara "${A[@]}" > /dev/null
           echo "sara è tornata dalle ferie e non entra: 'kinit sara@LAB.TEST' con la sua password (Passw0rd!sara) risponde \"Client's credentials have been revoked\"." ;;
        4) cat > "$W/accedi.sh" << 'EOF'
#!/usr/bin/env bash
# prende il biglietto Kerberos di anna e lo mostra
echo 'Passw0rd!anna' | kinit anna@lab.test
klist | grep 'Default principal'
EOF
           echo "lavoro/accedi.sh usa la password giusta di anna, ma 'kinit' risponde \"KDC reply did not match expectations\" e non c'è nessun biglietto." ;;
        5) cat > "$W/reimposta.sh" << EOF
#!/usr/bin/env bash
# reimposta la password di marco (la nuova è marco123)
samba-tool user setpassword marco --newpassword='marco123' -H ldap://dc1.lab.test -U 'administrator%$PW'
EOF
           echo "lavoro/reimposta.sh dovrebbe reimpostare la password di marco, ma dà un errore." ;;
        6) st dns zonedelete dc1.lab.test "$ZONA" "${DNS[@]}" > /dev/null
           echo "Dopo una pulizia del DNS, 'ldapsearch -Y GSSAPI' verso dc1.lab.test non funziona più (anche con un biglietto Kerberos valido), mentre samba-tool e il DNS diretto vanno." ;;
        7) st dns add dc1.lab.test lab.test web A 10.30.0.99 "${DNS[@]}" > /dev/null
           echo "web.lab.test dovrebbe puntare al server 10.30.0.50, ma 'host web.lab.test' risponde un altro indirizzo." ;;
        8) st computer delete PC01 "${A[@]}" > /dev/null
           echo "Su questo PC 'net ads testjoin' dice che il join non è valido. Ieri il PC era nel dominio." ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    chmod +x "$W"/*.sh 2> /dev/null
    return 0
}

# ---------------------------------------------------------------- i controlli: il sintomo è sparito?
ESITO=0
prova() {
    local d=$1; shift
    if "$@" > /dev/null 2>&1; then echo "  OK        $d"; else echo "  ANCORA NO $d"; ESITO=1; fi
}
entra() { kdestroy 2> /dev/null; echo "Passw0rd!$1" | kinit "$1@LAB.TEST" && klist | grep -q "Default principal: $1@LAB.TEST"; }
srv_trovato() { host -t SRV _ldap._tcp.lab.test | grep -q '389 dc1.lab.test'; }
c4() { rm -f /tmp/krb5cc_0; kdestroy 2> /dev/null; [[ $(cd "$W" && timeout 30 bash accedi.sh 2> /dev/null) == *"anna@LAB.TEST" ]]; }
c5() {      # lo script riesce davvero: la password di marco cambia (pwdLastSet)
    local prima dopo; prima=$(st user show marco "${A[@]}" | grep '^pwdLastSet:')
    (cd "$W" && timeout 30 bash reimposta.sh > /dev/null 2>&1) || return 1
    dopo=$(st user show marco "${A[@]}" | grep '^pwdLastSet:'); [[ -n $dopo && $dopo != "$prima" ]]
}
c5_policy() { st domain passwordsettings show "${A[@]}" | grep -q 'complexity: on' && st domain passwordsettings show "${A[@]}" | grep -qE 'Minimum password length: ([7-9]|[1-9][0-9])$'; }
c6_dns() { host 10.30.0.10 | grep -q 'dc1.lab.test'; }
c6_gssapi() { echo "$PW" | kinit administrator@LAB.TEST && ldapsearch -H ldap://dc1.lab.test -Y GSSAPI -LLL -b 'DC=lab,DC=test' '(sAMAccountName=anna)' dn | grep -q '^dn: CN=anna'; }
c7() { [[ $(host web.lab.test | grep -c 'has address') == 1 ]] && host web.lab.test | grep -q '10.30.0.50$'; }
controlla() {
    case $1 in
        1) prova "il DNS del dominio trova il controller (record SRV _ldap)" srv_trovato
           prova "anna entra (kinit anna@LAB.TEST)" entra anna ;;
        2) prova "anna entra (kinit anna@LAB.TEST)" entra anna ;;
        3) prova "sara entra (kinit sara@LAB.TEST)" entra sara ;;
        4) prova "accedi.sh ottiene il biglietto di anna" c4 ;;
        5) prova "reimposta.sh riesce a reimpostare la password di marco" c5
           prova "la policy delle password non è stata indebolita (complessità attiva, minimo 7 caratteri)" c5_policy ;;
        6) prova "il DNS risolve il nome inverso di 10.30.0.10 (dc1.lab.test)" c6_dns
           prova "ldapsearch -Y GSSAPI trova anna" c6_gssapi ;;
        7) prova "web.lab.test ha un solo indirizzo: 10.30.0.50" c7 ;;
        8) prova "net ads testjoin: il join è valido" net ads testjoin ;;
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
    ripristina) salute; echo "dominio in salute" ;;
    *) echo "uso: $0 guasta N | controlla [N] | ripristina" >&2; exit 2 ;;
esac
