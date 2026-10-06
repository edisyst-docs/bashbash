#!/usr/bin/env bash
# 11 - opzioni.sh [-v] [-n NUM] FILE: stampa "verbose=V num=N file=FILE" (default verbose=0 num=1); opzione sconosciuta o FILE mancante: uso su stderr ed exit 2
v=0 n=1
while getopts ":vn:" o; do
    case $o in
        v) v=1 ;;
        n) n=$OPTARG ;;
        *) echo "uso: $0 [-v] [-n NUM] file" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 1 ]] || { echo "uso: $0 [-v] [-n NUM] file" >&2; exit 2; }
echo "verbose=$v num=$n file=$1"
