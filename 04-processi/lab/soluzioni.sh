#!/usr/bin/env bash
# soluzioni.sh N [controllo] - la soluzione di riferimento dell'esercizio N di 06-esercizi.md.
#   soluzioni.sh N             esegue la soluzione (stampa il risultato, o agisce sui processi dello scenario)
#   soluzioni.sh N controllo   stampa lo stato che il controllo dell'esercizio guarda (vuoto se basta l'output)
# La usa verifica.sh, con lo scenario (scenario.sh) già avviato. Si lancia dalla palestra.
set -uo pipefail
n=${1:?uso: $0 N [controllo]}
if [[ ${2:-} == script ]]; then
    cat << 'EOT'
trap 'echo pulizia; exit 0' TERM
echo avviato
while :; do sleep 0.2; done
EOT
    exit 0
fi
if [[ ${2:-} == controllo ]]; then
    case $n in
        2|3) pgrep -c -x "$([[ $n == 2 ]] && echo worker || echo ostinato)" || true ;;
        7)   ps -o ni= -C lento | tr -d ' ' ;;
        9)   ps -o stat= -C fermo | cut -c1 ;;
        12)  ls ./*.out | tr '\n' ' '; echo ;;
    esac
    exit 0
fi
case $n in
    1)  pgrep -c -x worker ;;
    2)  pkill -TERM -x worker ;;
    3)  pkill -KILL -x ostinato ;;
    4)  ps -o comm= -p "$(ps -o ppid= -C figlio | tr -d ' ')" ;;
    5)  ss -ltnpH | grep '"ascolto"' | awk '{print $4}' | sed 's/.*://' ;;
    6)  ps -o ni= -C lento | tr -d ' ' ;;
    7)  renice -n 15 -p "$(pgrep -x lento)" > /dev/null ;;
    8)  ps -o stat= -C fermo | cut -c1 ;;
    9)  pkill -CONT -x fermo ;;
    10) tr '\0' ' ' < "/proc/$(pgrep -x figlio)/cmdline" | sed 's/ $//'; echo ;;
    11) lsof -p "$(pgrep -x scrittore)" 2> /dev/null | awk '$4 ~ /w/ && $NF ~ /dati.log/ {print $NF}' ;;
    12) cat > tutti.sh << 'EOT'
./lavora.sh A &
./lavora.sh B &
./lavora.sh C &
wait
echo "tutti finiti"
EOT
        bash tutti.sh ;;
    13) echo "l'esercizio 13 è uno script che si avvia da solo: soluzioni.sh 13 script ne stampa il testo" >&2; exit 2 ;;
    14) ulimit -Sn ;;
    15) echo $(( $(cat /sys/fs/cgroup/memory.max) / 1024 / 1024 )) ;;
    16) ps -eo stat=,comm= | awk '$1 ~ /^T/ {print $2}' ;;
    *)  echo "esercizi da 1 a 16" >&2; exit 2 ;;
esac
