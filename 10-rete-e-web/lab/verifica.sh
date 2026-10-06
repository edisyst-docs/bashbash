#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 10-esercizi.md (area 10, rete). ATTENZIONE: agisce sulla rete VERA del container
# "host" (indirizzi, rotte, MTU, namespace, nginx, /etc/hosts): si lancia solo nel laboratorio 10, che è usa-e-getta.
# Ogni risposta è uno script in risposte/NN.sh. Per ogni esercizio:
#   1. si riporta il sistema allo stato di partenza, si esegue la risposta, si legge lo STATO che l'esercizio chiede
#      (indirizzi, rotta, MTU, risposta di nginx...) e si rimette tutto com'era;
#   2. lo stesso con la soluzione di riferimento, e si confrontano output e stato.
# Gli esercizi di diagnostica (9-14) e di calcolo (1-3) si confrontano sull'output. Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LAB=${LAB:-/kb/10-rete-e-web/lab}
SOL=$LAB/soluzioni.sh
SOLO_STATO="4 5 6 7 8 15 16"       # esercizi che cambiano la rete: si controlla lo stato, non l'output
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 16)
[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 10: ./lab.sh 10)" >&2; exit 2; }
ip -4 addr show dev eth0 2> /dev/null | grep -q '10.10.1.10/24' || { echo "serve il container host del laboratorio 10 (10.10.1.10)" >&2; exit 2; }

# prova SCRIPT N: stato pulito, risposta, controllo, pulizia; stampa output e stato
prova() {
    local script=$1 n=$2 d out
    bash "$SOL" pulisci "$n"; bash "$SOL" prepara "$n"
    d=$(mktemp -d)
    out=$(cd "$d" && LC_ALL=C timeout 60 bash "$script" 2>&1)
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
