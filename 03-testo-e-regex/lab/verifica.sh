#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 06-esercizi.md.
# Ogni risposta è uno script in risposte/NN.sh (per esempio risposte/01.sh) che STAMPA il risultato; qui si
# confronta il suo output con quello della soluzione di riferimento. Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
SOL=${SOLUZIONI:-/kb/03-testo-e-regex/lab/soluzioni.sh}
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 18)
ok=0 sbagliati=0 mancanti=0
for n in "${ESERCIZI[@]}"; do
    nn=$(printf '%02d' "$((10#$n))")
    if [[ ! -f risposte/$nn.sh ]]; then
        echo "  $nn  da fare (manca risposte/$nn.sh)"; mancanti=$((mancanti + 1)); continue
    fi
    atteso=$(bash "$SOL" "$((10#$n))" 2> /dev/null)
    ottenuto=$(bash "risposte/$nn.sh" 2>&1)
    if [[ $ottenuto == "$atteso" ]]; then
        echo "  $nn  OK"; ok=$((ok + 1))
    else
        echo "  $nn  SBAGLIATO"; sbagliati=$((sbagliati + 1))
        diff <(echo "$atteso") <(echo "$ottenuto") | head -6 | sed 's/^/        /'
        echo "        (< atteso, > ottenuto)"
    fi
done
echo "giusti $ok, sbagliati $sbagliati, da fare $mancanti"
(( sbagliati == 0 ))
