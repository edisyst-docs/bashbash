#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 04: processi
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gli esempi dei primi quattro .md agiscono sul sistema; qui si preparano gli script del 05-debug-e-prestazioni:
# programmi che si comportano male in modo prevedibile, da osservare con strace, ulimit, cgroup e perf.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
AREA="$(dirname "$LAB_SRC")"
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md

# ---------------------------------------------------------------- 01-04: si lavora sul sistema
for s in 01-ps-e-kill 02-jobs 03-top-htop 04-risorse; do sezione "$s"; done
cp "$AREA/02-contatore.sh" "$DEST/02-jobs/" && chmod +x "$DEST/02-jobs/02-contatore.sh"

# ---------------------------------------------------------------- 05-debug-e-prestazioni
sezione 05-debug-e-prestazioni

cat > cerca-config.sh << 'EOF'
#!/usr/bin/env bash
# cerca-config.sh - un programma che "non trova" la sua configurazione e non lo dice
# legge /etc/miaapp/config.ini e, se non c'è, in silenzio usa i valori di default
for f in ./config.ini "$HOME/.miaapp.ini" /etc/miaapp/config.ini; do
    [[ -r $f ]] && { echo "configurazione: $f"; exit 0; }
done
echo "uso i valori di default"
EOF

cat > bloccato.sh << 'EOF'
#!/usr/bin/env bash
# bloccato.sh - resta fermo in attesa di una riga che non arriva mai (il processo "si è impiantato")
mkfifo /tmp/coda 2>/dev/null || true
echo "PID $$: aspetto dati da /tmp/coda..."
read -r riga < /tmp/coda
echo "ricevuto: $riga"
EOF

cat > apri-file.py << 'EOF'
#!/usr/bin/env python3
# apri-file.py - apre file senza chiuderli, finché il sistema non dice basta
import errno, sys
aperti = []
try:
    while True:
        aperti.append(open("/etc/hostname"))
        if len(aperti) >= 20000:       # con il limite predefinito (oltre un milione) finirebbe prima la RAM del container
            print("20000 file aperti: nessun limite raggiunto")
            sys.exit(0)
except OSError as e:
    print(f"fermato dopo {len(aperti)} file aperti: {errno.errorcode[e.errno]} - {e.strerror}")
    sys.exit(1)
EOF

cat > mangia-ram.py << 'EOF'
#!/usr/bin/env python3
# mangia-ram.py - occupa 20 MB al secondo (e li tocca davvero) finché qualcuno non lo ferma
import time
blocchi = []
n = 0
while True:
    blocchi.append(bytearray(b"x" * 20 * 1024 * 1024))
    n += 20
    print(f"{n} MB occupati", flush=True)
    time.sleep(1)
EOF

cat > calcola.py << 'EOF'
#!/usr/bin/env python3
# calcola.py - un programma lento "per colpa" di una funzione sola: la trova perf (o cProfile)
def primo(n):
    if n < 2:
        return False
    for d in range(2, int(n ** 0.5) + 1):
        if n % d == 0:
            return False
    return True

def conta_primi(limite):
    return sum(1 for n in range(limite) if primo(n))

def poca_roba():
    return sum(range(1000))

if __name__ == "__main__":
    for _ in range(40):
        poca_roba()
        conta_primi(60000)
    print("fatto")
EOF

cat > scrive-lento.sh << 'EOF'
#!/usr/bin/env bash
# scrive-lento.sh - scrive 200 blocchi da 4 KB e aspetta il disco a ogni scrittura (oflag=dsync)
dd if=/dev/zero of=/tmp/lento.dat bs=4k count=200 oflag=dsync 2>&1 | tail -1
rm -f /tmp/lento.dat
EOF

cat > cpu.sh << 'EOF'
#!/usr/bin/env bash
# cpu.sh - un processo che usa il 100% di una CPU per 60 secondi, per top, pidstat e il limite del cgroup
timeout 60 bash -c 'while :; do :; done'
EOF
chmod +x ./*.sh ./*.py

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 04 pronto in $DEST: una cartella per ogni .md"
    echo "Limiti del container: 256 MB di RAM senza swap, 1 CPU, 200 processi. Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
