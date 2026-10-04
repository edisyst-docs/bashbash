#!/usr/bin/env bash
# Laboratorio di rete con i network namespace: tre "host" collegati a uno switch virtuale.
#
#   host_1 (192.168.100.1) --\
#   host_2 (192.168.100.2) ---+-- br_lab (switch)
#   host_3 (192.168.100.3) --/
#
# Uso (serve root):
#   sudo ./03-namespace.sh up      crea la rete
#   sudo ./03-namespace.sh test    ping da host_1 verso gli altri
#   sudo ./03-namespace.sh down    elimina tutto
set -euo pipefail

HOSTS=(host_1 host_2 host_3)
BRIDGE=br_lab
RETE=192.168.100

[[ $EUID -eq 0 ]] || { echo "serve root: sudo $0 ${1:-}" >&2; exit 1; }

up() {
    if ip link show "$BRIDGE" &> /dev/null; then
        echo "il laboratorio esiste già: prima sudo $0 down" >&2
        exit 1
    fi
    ip link add "$BRIDGE" type bridge                      # lo switch virtuale, nel namespace principale
    ip link set "$BRIDGE" up

    local i=1 h
    for h in "${HOSTS[@]}"; do
        ip netns add "$h"                                  # il "computer"
        ip link add "veth_$i" type veth peer name "br_veth_$i" # il cavo: due estremità collegate
        ip link set "veth_$i" netns "$h"                   # un capo nel computer...
        ip link set "br_veth_$i" master "$BRIDGE"          # ...l'altro nello switch
        ip link set "br_veth_$i" up

        ip netns exec "$h" ip addr add "$RETE.$i/24" dev "veth_$i"
        ip netns exec "$h" ip link set "veth_$i" up
        ip netns exec "$h" ip link set lo up
        echo "creato $h con IP $RETE.$i"
        (( ++i ))
    done
}

test_rete() {
    local i
    for (( i = 2; i <= ${#HOSTS[@]}; i++ )); do
        ip netns exec host_1 ping -c 1 -W 1 "$RETE.$i" > /dev/null \
            && echo "host_1 -> $RETE.$i ok" \
            || echo "host_1 -> $RETE.$i NON raggiungibile"
    done
}

down() {
    local i
    for (( i = 1; i <= ${#HOSTS[@]}; i++ )); do
        # eliminando un capo del cavo sparisce subito anche l'altro. Eliminando solo il namespace la veth verrebbe
        # distrutta anche lei, ma in ritardo (il kernel lo fa in background): un "up" subito dopo troverebbe
        # ancora br_veth_N e fallirebbe con "File exists"
        ip link del "br_veth_$i" 2> /dev/null || true
        ip netns del "${HOSTS[i-1]}" 2> /dev/null || true
    done
    ip link del "$BRIDGE" 2> /dev/null || true
    echo "laboratorio rimosso"
}

case ${1:-} in
    up)   up ;;
    test) test_rete ;;
    down) down ;;
    *)    echo "uso: sudo $0 up|test|down" >&2; exit 2 ;;
esac
