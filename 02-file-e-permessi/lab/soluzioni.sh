#!/usr/bin/env bash
# soluzioni.sh N [controllo] - la soluzione di riferimento dell'esercizio N di 10-esercizi.md.
#   soluzioni.sh N             esegue la soluzione (stampa il risultato, o cambia lo stato dei file)
#   soluzioni.sh N controllo   stampa lo stato che il controllo dell'esercizio guarda (vuoto se basta l'output)
# La usa verifica.sh: lancia questa e la risposta dello studente ciascuna in una COPIA della palestra, poi confronta
# output e stato. Si lancia da dentro la palestra.
set -uo pipefail
n=${1:?uso: $0 N [controllo]}
if [[ ${2:-} == controllo ]]; then
    case $n in
        7)  find . -name '*.tmp' | sort ;;
        9)  stat -c '%a' segreto.txt ;;
        10) find progetto -printf '%m %p\n' | sort -k2 ;;
        11) stat -c '%a' condivisa ;;
        12) find sito -printf '%m %p\n' | sort -k2 ;;
        13) stat -c '%a' script.sh ;;
        14) readlink corrente ;;
        15) stat -c '%h' dati.txt; [[ dati.txt -ef dati-copia ]] && echo "stesso inode" ;;
        16) tar tzf backup.tar.gz | sort ;;
        17) cat release/config.ini; ls release ;;
        18) [[ -s out.txt ]] && echo "out.txt non vuoto"; cat err.txt ;;
        20) find destinazione | sort ;;
        21) find copia | sort ;;
        22) find mirror | sort ;;
        23) find posta -type f | wc -l; find arrivo -type f | sort ;;
        24) find copia2 | sort ;;
        25) find cestino -type f | sort; cat backup/index.html ;;
    esac
    exit 0
fi
case $n in
    1)  find . -name '*.log' | sort ;;
    2)  find . -name '*.php' -not -path './vendor/*' -not -path './node_modules/*' | sort ;;
    3)  find . -type f -size +1M ;;
    4)  find . -name '*.tmp' -mtime +30 | sort ;;
    5)  find . -type d -empty | sort ;;
    6)  find . -type f -perm -u+x | sort ;;
    7)  find . -name '*.tmp' -mtime +30 -delete ;;
    8)  find . -name '*.sh' -exec cat {} + | wc -l ;;
    9)  chmod u=rw,g=,o= segreto.txt ;;
    10) chmod -R go-w progetto ;;
    11) chmod 2775 condivisa ;;
    12) find sito -type d -exec chmod 755 {} + ; find sito -type f -exec chmod 644 {} + ;;
    13) chmod +x script.sh ;;
    14) ln -s release-2 corrente; readlink corrente ;;
    15) ln dati.txt dati-copia ;;
    16) tar czf backup.tar.gz --exclude='*.tmp' dati ;;
    17) tar xzf release.tar.gz release/config.ini ;;
    18) ls . nonesiste > out.txt 2> err.txt ;;
    19) sort lista1.txt | comm -23 - <(sort lista2.txt) ;;
    20) rsync -a --exclude .git origine/ destinazione/ ;;
    21) rsync -am --include='*/' --include='*.jpg' --exclude='*' web/ copia/ ;;
    22) rsync -ain --delete web/ mirror/ | grep deleting | sort ;;
    23) rsync -a --remove-source-files posta/ arrivo/ ;;
    24) rsync -a --max-size=1M --exclude .git --exclude logs web/ copia2/ ;;
    25) rsync -a --delete --backup --backup-dir="$PWD/cestino" web/ backup/ ;;
    26) rsync -a nonesiste/ x/ 2> /dev/null; echo $? ;;
    *)  echo "esercizi da 1 a 26" >&2; exit 2 ;;
esac
