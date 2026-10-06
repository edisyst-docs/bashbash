#!/usr/bin/env bash
# verifica.sh [N...] - controlla gli script di 13-esercizi.md.
# Ogni risposta è uno SCRIPT bash in risposte/NN.sh (per esempio risposte/01.sh). Per ogni caso di casi.txt si esegue
# lo script dello studente e la soluzione di riferimento, ciascuno in una COPIA nuova della palestra, con gli stessi argomenti
# e lo stesso stdin, e si confronta: l'output, il codice d'uscita, se c'è stato qualcosa su stderr (il testo no: è libero)
# e se sono rimasti file in TMPDIR. Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
CASI=${CASI:-/kb/05-scripting/lab/casi.txt}
SOL=${SOLUZIONI:-/kb/05-scripting/lab/soluzioni}
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 16)

# esegui SCRIPT ARGOMENTI STDIN: in una copia nuova della palestra; stampa un riassunto
esegui() {
    local script=$1 args=$2 stdin=$3 d t out err residui
    d=$(mktemp -d); t=$(mktemp -d)
    cp -a palestra/. "$d"/
    out=$(cd "$d" && eval "set -- $args" && printf '%b' "$stdin" | TMPDIR=$t LC_ALL=C timeout 10 bash "$script" "$@" 2> "$d/.stderr"; echo "rc=$?")
    err=vuoto; [[ -s $d/.stderr ]] && err="non vuoto"
    residui=$(find "$t" -mindepth 1 | wc -l)
    printf '%s\nstderr: %s\nresidui in TMPDIR: %s' "$out" "$err" "$residui"
    rm -rf "$d" "$t"
}

ok=0 sbagliati=0 mancanti=0
for n in "${ESERCIZI[@]}"; do
    n=$((10#$n)); nn=$(printf '%02d' "$n")
    if [[ ! -f risposte/$nn.sh ]]; then
        echo "  $nn  da fare (manca risposte/$nn.sh)"; mancanti=$((mancanti + 1)); continue
    fi
    errati=0 casi=0
    while IFS='|' read -r num desc args stdin; do
        [[ $num == "$n" ]] || continue
        casi=$((casi + 1))
        atteso=$(esegui "$SOL/$nn.sh" "$args" "$stdin")
        ottenuto=$(esegui "$PWD/risposte/$nn.sh" "$args" "$stdin")
        if [[ $ottenuto != "$atteso" ]]; then
            (( errati == 0 )) && echo "  $nn  SBAGLIATO"
            errati=$((errati + 1))
            echo "        caso: $desc   (argomenti: ${args:-nessuno})"
            diff <(echo "$atteso") <(echo "$ottenuto") | head -6 | sed 's/^/          /'
        fi
    done < <(grep -v '^#' "$CASI")
    if (( errati == 0 )); then echo "  $nn  OK ($casi casi)"; ok=$((ok + 1)); else sbagliati=$((sbagliati + 1)); fi
done
echo "giusti $ok, sbagliati $sbagliati, da fare $mancanti   (< atteso, > ottenuto)"
(( sbagliati == 0 ))
