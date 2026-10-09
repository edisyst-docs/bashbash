#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 10-esercizi.md.
# Ogni risposta è uno script in risposte/NN.sh (per esempio risposte/01.sh). Per ogni esercizio:
#   1. si fa una COPIA nuova di palestra/ (permessi e date compresi) e ci si esegue la risposta;
#   2. lo stesso con la soluzione di riferimento in un'altra copia;
#   3. si confrontano l'output e, per gli esercizi che cambiano i file, lo stato che il controllo guarda.
# Così la palestra non si rovina: si può ritentare quante volte si vuole. Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
SOL=${SOLUZIONI:-/kb/02-file-e-permessi/lab/soluzioni.sh}
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 26)
ok=0 sbagliati=0 mancanti=0

# copia nuova della palestra, esegue "$@" dentro e poi il controllo di N; stampa tutto
in_copia() {
    local n=$1; shift
    local d; d=$(mktemp -d)
    cp -a palestra/. "$d"/
    ( cd "$d" && "$@" 2>&1; bash "$SOL" "$n" controllo 2>&1 )
    chmod -R u+rwX "$d" 2> /dev/null; rm -rf "$d"
}
for n in "${ESERCIZI[@]}"; do
    nn=$(printf '%02d' "$((10#$n))"); n=$((10#$n))
    if [[ ! -f risposte/$nn.sh ]]; then
        echo "  $nn  da fare (manca risposte/$nn.sh)"; mancanti=$((mancanti + 1)); continue
    fi
    atteso=$(in_copia "$n" bash "$SOL" "$n")
    ottenuto=$(in_copia "$n" bash "$PWD/risposte/$nn.sh")
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
