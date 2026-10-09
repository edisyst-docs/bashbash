#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 06-esercizi.md (area 08, accesso remoto e sicurezza). Si lancia dal client del
# laboratorio 08 (root): usa i server (produzione, staging, db-interno) e il firewall del container.
# Ogni risposta è uno script in risposte/NN.sh. Per ogni esercizio, in una COPIA nuova della palestra e con un GNUPGHOME vuoto:
#   1. si prepara (se serve), si esegue la risposta, si legge lo STATO che l'esercizio chiede (file, tunnel, regole ufw, wg0...);
#   2. si ripulisce; lo stesso con la soluzione di riferimento, e si confrontano output e stato.
# Prima di tutto si avvia un ssh-agent con una chiave già autorizzata sui server: le risposte usano "ssh deploy@produzione ..."
# senza password e senza chiedere nulla, e il primo contatto con un server non chiede conferma (config temporanea in /etc/ssh).
# Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LAB=${LAB:-/kb/08-remoto-e-sicurezza/lab}
SOL=$LAB/soluzioni.sh
SOLO_STATO="1 2 3 7 8 9 10 12 13 14 15 16 17 18 19 20 21"     # esercizi che producono file, tunnel o regole: si controlla lo stato, non l'output
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 22)
[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 08: ./lab.sh 08)" >&2; exit 2; }
getent hosts produzione > /dev/null || { echo "serve il client del laboratorio 08 (non risolve 'produzione')" >&2; exit 2; }

CONF=/etc/ssh/ssh_config.d/99-esercizi.conf
CHIAVE=$PWD/.chiave-esercizi
ASKPASS=$(mktemp); printf '#!/bin/sh\ncase "$1" in *edoardo*) echo edoardo ;; *) echo deploy ;; esac\n' > "$ASKPASS"; chmod +x "$ASKPASS"
TMPD=$(mktemp -d)
pulizia() { [[ -n ${SSH_AGENT_PID:-} ]] && kill "$SSH_AGENT_PID" 2> /dev/null; rm -f "$CONF" "$ASKPASS"; rm -rf "$TMPD"; }
trap pulizia EXIT

# il primo contatto con un server non deve chiedere "yes/no": le risposte girano senza tastiera
printf 'Host *\n    StrictHostKeyChecking accept-new\n    LogLevel ERROR\n' > "$CONF"
# la chiave degli esercizi, autorizzata (con la password, una volta sola) per deploy ed edoardo su tutti e tre i server
[[ -f $CHIAVE ]] || ssh-keygen -q -t ed25519 -N '' -C verifica -f "$CHIAVE"
for s in produzione staging db-interno; do
    for u in deploy edoardo; do
        ssh -i "$CHIAVE" -o IdentitiesOnly=yes -o BatchMode=yes -o ProxyJump=none "$u@$s" true 2> /dev/null && continue
        if [[ $s == db-interno ]]; then salto=(-o ProxyJump=deploy@produzione); else salto=(); fi
        SSH_ASKPASS=$ASKPASS SSH_ASKPASS_REQUIRE=force ssh-copy-id "${salto[@]}" -i "$CHIAVE.pub" "$u@$s" > /dev/null 2>&1 \
            || { echo "non riesco ad autorizzare la chiave su $u@$s (i server sono avviati?)" >&2; exit 2; }
    done
done
eval "$(ssh-agent -s)" > /dev/null
ssh-add -q "$CHIAVE"

# prova SCRIPT N: copia nuova della palestra, GNUPGHOME vuoto; stato pulito, risposta, controllo, pulizia
prova() {
    local script=$1 n=$2 d out
    d=$(mktemp -d); cp -a palestra/. "$d"/
    mkdir -p "$d/.gnupg"; chmod 700 "$d/.gnupg"
    export GNUPGHOME=$d/.gnupg
    ( cd "$d" && bash "$SOL" pulisci "$n"; bash "$SOL" prepara "$n" )
    out=$(cd "$d" && LC_ALL=C timeout 60 bash "$script" 2>&1)
    if [[ " $SOLO_STATO " == *" $n "* ]]; then out="(solo lo stato)"; fi
    printf '%s\n' "$out"
    ( cd "$d" && bash "$SOL" controllo "$n" 2>&1 )
    ( cd "$d" && bash "$SOL" pulisci "$n" )
    gpgconf --kill gpg-agent 2> /dev/null
    rm -rf "$d"
}

ok=0 sbagliati=0 mancanti=0
for n in "${ESERCIZI[@]}"; do
    n=$((10#$n)); nn=$(printf '%02d' "$n")
    if [[ ! -f risposte/$nn.sh ]]; then
        echo "  $nn  da fare (manca risposte/$nn.sh)"; mancanti=$((mancanti + 1)); continue
    fi
    ref=$(mktemp); printf 'bash %s risolvi %d\n' "$SOL" "$n" > "$ref"
    atteso=$(prova "$ref" "$n" | sed 's/^ *//; s/ *$//'); rm -f "$ref"
    ottenuto=$(prova "$PWD/risposte/$nn.sh" "$n" | sed 's/^ *//; s/ *$//')
    if [[ $ottenuto == "$atteso" ]]; then
        echo "  $nn  OK"; ok=$((ok + 1))
    else
        echo "  $nn  SBAGLIATO"; sbagliati=$((sbagliati + 1))
        diff <(echo "$atteso") <(echo "$ottenuto") | head -8 | sed 's/^/        /'
        echo "        (< atteso, > ottenuto)"
    fi
done
echo "giusti $ok, sbagliati $sbagliati, da fare $mancanti"
(( sbagliati == 0 ))
