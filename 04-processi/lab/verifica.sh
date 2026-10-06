#!/usr/bin/env bash
# verifica.sh [N...] - controlla le risposte di 06-esercizi.md (area 04, processi).
# Ogni risposta è uno script in risposte/NN.sh. Per ogni esercizio:
#   1. si (ri)avvia lo SCENARIO (scenario.sh): i processi worker, ostinato, padre/figlio, ascolto, lento, fermo, scrittore;
#   2. si esegue la risposta in una copia nuova della palestra, e poi il controllo dell'esercizio (lo stato dei processi);
#   3. lo stesso con la soluzione di riferimento, e si confrontano output e stato. A fine esercizio lo scenario si spegne.
# Gli PID cambiano a ogni avvio: gli esercizi chiedono nomi, numeri e stati, mai PID. Senza argomenti li controlla tutti.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LAB=${LAB:-/kb/04-processi/lab}
SOLO_STATO="2 3 7 9"          # esercizi che agiscono sui processi: si controlla lo stato, non l'output
ESERCIZI=("$@")
(( ${#ESERCIZI[@]} )) || mapfile -t ESERCIZI < <(seq 1 16)

# esegue lo script $1 per l'esercizio $2 in uno scenario nuovo; stampa output, esito e stato
prova() {
    local script=$1 n=$2 d out
    bash "$LAB/scenario.sh" start
    d=$(mktemp -d); cp -a palestra/. "$d"/
    # l'output va su un FILE, non in una pipe: con una pipe la shell aspetterebbe anche i processi lasciati in background
    # dallo script (come un "./lavora.sh &" senza wait), e il controllo non si accorgerebbe che non li ha aspettati
    if (( n == 13 )); then
        # servizio.sh: si avvia, si manda SIGTERM dopo un secondo, si guarda cosa ha stampato e come è uscito
        ( cd "$d" && { timeout 10 bash "$script" > uscita.txt 2>&1 & p=$!; sleep 1; kill -TERM "$p" 2> /dev/null; wait "$p"; echo "rc=$?" >> rc.txt; } > /dev/null 2>&1 )
    else
        ( cd "$d" && timeout 10 bash "$script" > uscita.txt 2>&1; echo "rc=$?" > rc.txt )
    fi
    sleep 0.5
    # esercizi che agiscono sui processi (kill, renice): conta lo STATO dopo, non quello che lo script ha stampato
    if [[ " $SOLO_STATO " == *" $n "* ]]; then out="(solo lo stato)"; else out="$(cat "$d/uscita.txt")"$'\n'"$(cat "$d/rc.txt")"; fi
    ( cd "$d" && bash "$LAB/soluzioni.sh" "$n" controllo 2>&1 )
    printf '%s\n' "$out" | sed 's/^ *//; s/ *$//'
    rm -rf "$d"
    bash "$LAB/scenario.sh" stop
}

ok=0 sbagliati=0 mancanti=0
for n in "${ESERCIZI[@]}"; do
    n=$((10#$n)); nn=$(printf '%02d' "$n")
    if [[ ! -f risposte/$nn.sh ]]; then
        echo "  $nn  da fare (manca risposte/$nn.sh)"; mancanti=$((mancanti + 1)); continue
    fi
    # per la soluzione di riferimento lo "script" è un piccolo programma che chiama soluzioni.sh
    ref=$(mktemp)
    if (( n == 13 )); then bash "$LAB/soluzioni.sh" 13 script > "$ref"; else printf 'bash %s %d\n' "$LAB/soluzioni.sh" "$n" > "$ref"; fi
    atteso=$(prova "$ref" "$n"); rm -f "$ref"
    ottenuto=$(prova "$PWD/risposte/$nn.sh" "$n")
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
