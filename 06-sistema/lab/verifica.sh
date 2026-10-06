#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 13-esercizi.md (area 06). ATTENZIONE: agisce sul sistema VERO del container
# (utenti, unit di systemd, mount, crontab...): si lancia solo nel laboratorio 06, che è usa-e-getta.
# Ogni risposta è uno script in risposte/NN.sh. Per ogni esercizio:
#   1. si porta il sistema nello stato di partenza (utenti creati dagli esercizi tolti, unit tolte...), poi
#   2. si esegue la risposta, si legge lo STATO che l'esercizio chiede (utenti, mount, journal...) e si riporta tutto com'era;
#   3. lo stesso con la soluzione di riferimento, e si confrontano output e stato.
# Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LAB=${LAB:-/kb/06-sistema/lab}
SOL=$LAB/soluzioni.sh
SOLO_STATO="1 2 3 7 10 11 12 13 15 16 17 18"    # esercizi che cambiano il sistema: si controlla lo stato, non l'output
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 18)
[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 06: ./lab.sh 06)" >&2; exit 2; }
[[ $(systemctl is-system-running 2> /dev/null) =~ ^(running|degraded)$ ]] || { echo "serve systemd: è il laboratorio 06?" >&2; exit 2; }

# prova SCRIPT N: stato pulito, risposta, controllo, pulizia; stampa output e stato
prova() {
    local script=$1 n=$2 d out
    bash "$SOL" pulisci "$n"; bash "$SOL" prepara "$n"
    d=$(mktemp -d)
    # il journal ricorda i messaggi delle prove precedenti: il controllo guarda solo quelli DOPO questo punto
    export VERIFICA_CURSORE; VERIFICA_CURSORE=$(journalctl -n0 --show-cursor -o cat --no-pager 2> /dev/null | sed -n "s/^-- cursor: //p")
    out=$(cd "$d" && LC_ALL=C timeout 30 bash "$script" 2>&1)
    sleep 0.3
    if [[ " $SOLO_STATO " == *" $n "* ]]; then out="(solo lo stato)"; fi
    printf '%s\n' "$out"
    ( cd "$d" && bash "$SOL" controllo "$n" 2>&1 )
    rm -rf "$d"
    bash "$SOL" pulisci "$n"
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
