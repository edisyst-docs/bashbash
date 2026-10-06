#!/usr/bin/env bash
# scenario.sh start|stop - i processi su cui lavorano gli esercizi di 06-esercizi.md (stessi nomi, stessi parametri ogni volta).
# I nomi sono veri nomi di processo (il campo COMM di ps): i collegamenti simbolici in /tmp/sc puntano a sleep e a nc.
#   worker (x3)  sleep 600                     ostinato   script che ignora SIGTERM
#   padre        script che avvia "figlio"     figlio     sleep 600, figlio di padre
#   ascolto      nc in ascolto sulla porta 9999
#   lento        sleep 600 con nice 10         fermo      sleep 600 fermato con SIGSTOP
#   scrittore    script che tiene aperto /tmp/sc/dati.log in scrittura
SC=/tmp/sc
PIDS=/tmp/sc.pids       # i capogruppo (setsid): si uccide tutto il gruppo, figli compresi
parti() {
    rm -rf "$SC"; mkdir -p "$SC"
    ln -s "$(command -v sleep)" "$SC/worker"; ln -s "$(command -v sleep)" "$SC/figlio"
    ln -s "$(command -v sleep)" "$SC/lento";  ln -s "$(command -v sleep)" "$SC/fermo"
    ln -s "$(command -v nc)" "$SC/ascolto"
    printf '#!/bin/bash\ntrap "" TERM\nwhile :; do sleep 1; done\n' > "$SC/ostinato"
    printf '#!/bin/bash\n/tmp/sc/figlio 600 &\nwait\n' > "$SC/padre"
    printf '#!/bin/bash\nexec 3> /tmp/sc/dati.log\nsleep 600\n' > "$SC/scrittore"
    chmod +x "$SC/ostinato" "$SC/padre" "$SC/scrittore"
    : > "$PIDS"
    lancia() { setsid "$@" > /dev/null 2>&1 & echo $! >> "$PIDS"; }
    for _ in 1 2 3; do lancia "$SC/worker" 600; done
    lancia "$SC/ostinato"
    lancia "$SC/padre"
    lancia "$SC/ascolto" -l 9999
    lancia nice -n 10 "$SC/lento" 600
    lancia "$SC/fermo" 600
    lancia "$SC/scrittore"
    # aspetta che ci siano tutti, poi ferma "fermo"
    for _ in $(seq 1 50); do
        [[ $(pgrep -c -x 'worker|ostinato|padre|figlio|ascolto|lento|fermo|scrittore' 2> /dev/null || true) -ge 10 ]] && break
        sleep 0.1
    done
    for _ in $(seq 1 50); do ss -ltn 2> /dev/null | grep -q ':9999 ' && break; sleep 0.1; done
    pkill -STOP -x fermo
}
ferma() {
    if [[ -f $PIDS ]]; then
        while read -r p; do kill -KILL -- "-$p" 2> /dev/null || true; done < "$PIDS"
        rm -f "$PIDS"
    fi
    rm -rf "$SC"
}
case ${1:-} in
    start) ferma; parti ;;
    stop)  ferma ;;
    *)     echo "uso: $0 start|stop" >&2; exit 2 ;;
esac
