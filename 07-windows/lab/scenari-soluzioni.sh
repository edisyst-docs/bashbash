#!/usr/bin/env bash
# scenari-soluzioni.sh FASE N - le riparazioni di riferimento degli scenari di 10-scenari.md (area 07), e alcune "scorciatoie"
# che sembrano ripararli ma non lo fanno (servono a provare che scenari.sh controlla non si lascia ingannare).
#   scenari-soluzioni.sh risolvi N     la riparazione giusta
#   scenari-soluzioni.sh sbagliata N   un tentativo che non basta (non esiste per tutti gli scenari)
# La usa scenari-autotest.sh. Gira come root su pc01 del laboratorio 07.
set -uo pipefail
fase=${1:?uso: $0 risolvi|sbagliata N}
n=${2:?uso: $0 FASE N}
W=${LAB_SCENARI:-$HOME/lab/10-scenari}/lavoro
PW='Passw0rd!2026'
A=(-H ldap://dc1.lab.test -U "administrator%$PW")
DNS=(-U "administrator%$PW")
ZONA=0.30.10.in-addr.arpa
st() { samba-tool "$@" 2> /dev/null; }

risolvi() {
    case $n in
        1) printf 'nameserver 10.30.0.10\nsearch lab.test\n' > /etc/resolv.conf ;;
        2) st user unlock anna "${A[@]}" ;;
        3) st user enable sara "${A[@]}" ;;
        4) sed -i 's/anna@lab.test/anna@LAB.TEST/' "$W/accedi.sh" ;;
        5) sed -i "s/marco123/Marco!2026/g" "$W/reimposta.sh" ;;
        6) st dns zonecreate dc1.lab.test "$ZONA" "${DNS[@]}"
           st dns add dc1.lab.test "$ZONA" 10 PTR dc1.lab.test "${DNS[@]}"
           st dns add dc1.lab.test "$ZONA" 5 PTR pc01.lab.test "${DNS[@]}" ;;
        7) st dns delete dc1.lab.test lab.test web A 10.30.0.99 "${DNS[@]}"
           st dns add dc1.lab.test lab.test web A 10.30.0.50 "${DNS[@]}" ;;
        8) net ads join -U "administrator%$PW" > /dev/null 2>&1 ;;
        *) echo "scenari da 1 a 8" >&2; exit 2 ;;
    esac
}
sbagliata() {
    case $n in
        1) echo "10.30.0.10 dc1.lab.test dc1" >> /etc/hosts ;;                                                # il nome del controller si trova, ma il DNS resta rotto (e SRV non esiste in /etc/hosts)
        2) st user enable anna "${A[@]}" ;;                                                                   # l'account non era disabilitato: era bloccato
        3) st user unlock sara "${A[@]}" ;;                                                                   # l'account non era bloccato: era disabilitato
        4) sed -i 's/Passw0rd!anna/Passw0rd!sara/' "$W/accedi.sh" ;;                                          # un'altra password: il realm resta minuscolo
        5) st domain passwordsettings set --complexity=off --min-pwd-length=1 "${A[@]}" > /dev/null ;;        # lo script riesce, ma si è indebolita la policy di tutti
        6) echo "10.30.0.10 dc1.lab.test dc1" >> /etc/hosts ;;                                                # non è il DNS a rispondere al nome inverso
        7) st dns add dc1.lab.test lab.test web A 10.30.0.50 "${DNS[@]}" ;;                                   # il record giusto si aggiunge, ma quello sbagliato resta
        8) st computer create PC01 "${A[@]}" ;;                                                               # un account con lo stesso nome ma senza la password del PC
        *) echo "nessun tentativo sbagliato per lo scenario $n" >&2; exit 2 ;;
    esac
}
case $fase in
    risolvi|sbagliata) "$fase" ;;
    *) echo "fasi: risolvi, sbagliata" >&2; exit 2 ;;
esac
