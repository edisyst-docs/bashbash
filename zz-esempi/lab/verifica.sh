#!/usr/bin/env bash
# verifica.sh - prova gli script di zz-esempi/esercizi e zz-esempi/rubrica con dei casi noti e confronta l'output.
# Uso: ./verifica.sh            (dalla cartella ~/lab/verifica, dove prepara.sh l'ha messo)
# Gli script sono quelli della KB (/kb/zz-esempi); i file di prova li crea prepara.sh. Esce con 0 solo se tutti i casi passano.
set -uo pipefail
KB=${KB:-/kb/zz-esempi}
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
ok=0 ko=0

# controlla "descrizione" "atteso" "ottenuto"
controlla() {
    if [[ $3 == "$2" ]]; then
        echo "  OK       $1"; ok=$((ok + 1))
    else
        echo "  ERRATO   $1"; ko=$((ko + 1))
        diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | head -6 | sed 's/^/             /'
    fi
}
# esegue un comando e restituisce "output | rc=N" (stdout e stderr insieme)
esegui() { local o; o=$("$@" 2>&1); printf '%s | rc=%d' "$o" "$?"; }

echo "base2.sh"
E=$KB/esercizi
controlla "11 -> 1011"                      "11 --> 1011 | rc=0"   "$(esegui bash $E/base2.sh 11)"
controlla "255 -> 11111111"                 "255 --> 11111111 | rc=0" "$(esegui bash $E/base2.sh 255)"
controlla "0 -> 0"                          "0 --> 0 | rc=0"       "$(esegui bash $E/base2.sh 0)"
controlla "una parola non è un numero"      "ERRORE: usa: base2.sh intero | rc=1" "$(esegui bash $E/base2.sh abc)"
controlla "senza argomenti"                 "ERRORE: usa: base2.sh intero | rc=1" "$(esegui bash $E/base2.sh)"

echo "toupper.sh"
controlla "solo i nomi con minuscole"       $'pippo --> PIPPO\nPluto --> PLUTO | rc=0' "$(esegui bash $E/toupper.sh pippo Pluto MINNI)"
controlla "un nome con uno spazio"          "con spazio --> CON SPAZIO | rc=0" "$(esegui bash $E/toupper.sh "con spazio")"
controlla "toglie il percorso"              "ls --> LS | rc=0"     "$(esegui bash $E/toupper.sh /usr/bin/ls)"

echo "include.sh"
cd include || exit 1
controlla "prova.c: globali e locali, non i commenti" $'Il file "prova.c" contiene l\'include globale: stdio.h\nIl file "prova.c" contiene l\'include locale:  prova.h\nIl file "prova.c" contiene l\'include globale: stdlib.h | rc=0' "$(esegui bash $E/include.sh prova.c)"
controlla "prova.h"                         'Il file "prova.h" contiene l'\''include locale:  altro.h | rc=0' "$(esegui bash $E/include.sh prova.h)"
controlla "estensione .txt rifiutata"       "ERRORE: il file a.txt non ha estensione .c o .h | rc=2" "$(esegui bash $E/include.sh a.txt)"
controlla "estensione .cpp rifiutata"       "ERRORE: il file prova.cpp non ha estensione .c o .h | rc=2" "$(esegui bash $E/include.sh prova.cpp)"
controlla "file inesistente"                "ERRORE: il file nonesiste.c non esiste o non è un file regolare | rc=1" "$(esegui bash $E/include.sh nonesiste.c)"
controlla "senza argomenti"                 "ERRORE: usa: include.sh 'file' | rc=1" "$(esegui bash $E/include.sh)"
cd ..

echo "removeblanklines.sh"
cd vuote || exit 1
cp uno.txt uno.prova; cp "con spazio.txt" "con spazio.prova"
bash $E/removeblanklines.sh uno.prova "con spazio.prova"
controlla "toglie le righe vuote (anche con nome con spazio)" "a|b|c|x|y|" "$(cat uno.prova "con spazio.prova" | tr '\n' '|')"
controlla "una riga con soli spazi resta"   "a|  |b|" "$(printf 'a\n  \n\nb\n' > s.prova; bash $E/removeblanklines.sh s.prova; tr '\n' '|' < s.prova)"
controlla "file inesistente"                "ERRORE, il file nonesiste non esiste o non è un file regolare | rc=1" "$(esegui bash $E/removeblanklines.sh nonesiste)"
controlla "senza argomenti"                 "ERRORE: usa: removeblanklines.sh lista-di-file | rc=1" "$(esegui bash $E/removeblanklines.sh)"
cd ..

echo "spaziodisco.sh"
controlla "ordine per dimensione, tipo F/D, nome con spazi" $'grande\tF\nnome con spazio\tD\nsub\tD\npiccolo.txt\tF' "$(bash $E/spaziodisco.sh disco | awk -F'\t' '{gsub(/ +$/, "", $1); gsub(/ /, "", $2); print $1 "\t" $2}')"
controlla "con lo slash finale"             "$(bash $E/spaziodisco.sh disco)" "$(bash $E/spaziodisco.sh disco/)"
controlla "non è una directory"             "ERROR: nonesiste non è una directory | rc=2" "$(esegui bash $E/spaziodisco.sh nonesiste)"

echo "rubrica"
R=$KB/rubrica
H=$(mktemp -d); mkdir "$H/rubrica"; cp rubrica/.rubrica "$H/rubrica/"     # una home usa-e-getta: la rubrica vera non si tocca
r() { HOME=$H bash $R/rubrica.sh "$@" < /dev/null; }
controlla "-f: ricerca senza maiuscole"     "Record selezionati: 2" "$(r -f marco | head -1)"
controlla "-i: il record non si attacca all'ultimo" "Inserito record n. 6" "$(r -i Anna Rossi 333 a.rossi@example.com)"
controlla "-i: argomenti con spazi restano interi" "Maria Chiara|Verdi|06 111 222|mc@example.com" "$(r -i "Maria Chiara" Verdi "06 111 222" mc@example.com > /dev/null; tail -1 "$H/rubrica/.rubrica")"
controlla "-i: sono 7 record, uno per riga" "7" "$(wc -l < "$H/rubrica/.rubrica" | tr -d ' ')"
controlla "-d: una stringa con spazi"       "Record eliminati: 1" "$(r -d "06 111")"
controlla "-d: la stringa è testo, non regex" "Record eliminati: 0" "$(r -d 'M.rco')"
controlla "-d senza filtro"                 "$R/rubrica.sh: ERRORE: non e' stato specificato nessun filtro | rc=1" "$(HOME=$H esegui bash $R/rubrica.sh -d < /dev/null)"
controlla "-f senza filtro: li mostra tutti" "Record selezionati: 6" "$(r -f '' | head -1)"
controlla "opzione sconosciuta"             "ERRORE: opzione non prevista" "$(r -x)"
controlla "menu: una stringa vuota in eliminazione non chiude il programma" "Opzione errata" "$(printf '2\n\n9\n4\n' | HOME=$H bash $R/rubrica.sh 2>&1 | grep -o 'Opzione errata')"
rm -rf "$H"

echo "giusti $ok, errati $ko"
(( ko == 0 ))
