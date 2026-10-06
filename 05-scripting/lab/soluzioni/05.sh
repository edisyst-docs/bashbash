#!/usr/bin/env bash
# 05 - conta-righe.sh FILE...: per ogni file "FILE: N righe"; se un file non esiste lo dice su stderr, va avanti e alla fine esce con 1
rc=0
for f in "$@"; do
    if [[ -f $f ]]; then
        echo "$f: $(wc -l < "$f") righe"
    else
        echo "$f: non esiste" >&2
        rc=1
    fi
done
exit $rc
