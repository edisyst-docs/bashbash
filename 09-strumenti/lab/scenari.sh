#!/usr/bin/env bash
# scenari.sh - gli scenari guidati di 14-scenari.md (area 09): un guasto vero negli strumenti (curl, jq, MySQL, git, RabbitMQ, Kafka).
#   scenari.sh guasta N      azzera tutto, poi prepara lo scenario N nella cartella lavoro/ e stampa il "ticket"
#   scenari.sh controlla [N] dice se il problema è risolto (senza rivelare la causa); N è lo scenario in corso se omesso
#   scenari.sh ripristina    toglie ogni guasto: utenti, indici, code, repository e file dello scenario
# NON si legge prima di aver provato: qui dentro ci sono i guasti. Gira come root nella shell del laboratorio 09.
set -uo pipefail
cmd=${1:-}
n=${2:-}
NSCENARI=8
DIR=${LAB_SCENARI:-$HOME/lab/14-scenari}
W=$DIR/lavoro
STATO=/run/scenario-in-corso
AMQP=amqp://lab:lab@rabbitmq
RMQ=http://rabbitmq:15672/api

[[ $(id -u) -eq 0 ]] || { echo "serve root (laboratorio 09: ./lab.sh 09)" >&2; exit 2; }
getent hosts mysql > /dev/null && getent hosts api > /dev/null || { echo "serve la shell del laboratorio 09 (non vede 'mysql' e 'api')" >&2; exit 2; }

my() { mysql -h mysql -uroot -plab "$@" 2> /dev/null; }
rmq() { curl -s -u lab:lab "$@"; }
git_() { git -C "$1" -c user.name=Lab -c user.email=lab@example.com -c init.defaultBranch=main "${@:2}"; }

# ---------------------------------------------------------------- tutto in salute
salute() {
    mkdir -p "$W"; find "$W" -mindepth 1 -delete
    my -e "DROP USER IF EXISTS 'report'@'%'"
    local i
    for i in $(my -N -e "SELECT DISTINCT index_name FROM information_schema.statistics WHERE table_schema='app_db' AND table_name='logs' AND index_name<>'PRIMARY'"); do
        my app_db -e "DROP INDEX \`$i\` ON logs"
    done
    rmq -X DELETE "$RMQ/exchanges/%2F/ordini" > /dev/null
    rmq -X DELETE "$RMQ/queues/%2F/da-spedire" > /dev/null
    rm -f "$STATO"
}

# ---------------------------------------------------------------- i guasti e i loro sintomi
guasta() {
    case $1 in
        1) cat > "$W/scarica.sh" << 'EOF'
#!/usr/bin/env bash
# scarica gli utenti dell'API in utenti.json e stampa quanti sono
curl -s http://api/redirect > utenti.json
jq length utenti.json
EOF
           echo "Lo script lavoro/scarica.sh dovrebbe stampare quanti utenti ha l'API (sono 10), ma non stampa niente." ;;
        2) cat > "$W/conta-items.sh" << 'EOF'
#!/usr/bin/env bash
# stampa quanti elementi ha in tutto l'API /items
curl -s "http://api/items?page=1" | jq length
EOF
           echo "Lo script lavoro/conta-items.sh dovrebbe stampare il numero di elementi in tutto (le pagine sono più d'una), ma stampa 5." ;;
        3) my -e "CREATE USER 'report'@'%' IDENTIFIED BY 'report'; GRANT SELECT ON app_db.users TO 'report'@'%'"
           cat > "$W/report.sh" << 'EOF'
#!/usr/bin/env bash
# conta gli ordini, con l'utente "report" (sola lettura)
mysql -h mysql -ureport -preport app_db -N -e 'SELECT COUNT(*) FROM orders'
EOF
           echo "Lo script lavoro/report.sh (utente report) dà un errore invece di contare gli ordini." ;;
        4) cat > "$W/cerca-log.sh" << 'EOF'
#!/usr/bin/env bash
# quanti eventi di log ci sono stati in un'ora precisa
mysql -h mysql -uroot -plab app_db -N -e "SELECT COUNT(*) FROM logs WHERE created_at >= '2026-09-14 10:00:00' AND created_at < '2026-09-14 11:00:00'"
EOF
           echo "lavoro/cerca-log.sh funziona, ma in produzione (con 20 milioni di righe in logs, non 20 mila) ci mette minuti. Va resa veloce." ;;
        5) local r=$W/progetto; mkdir -p "$r"; git_ "$r" init -q; git_ "$r" config user.name Studente; git_ "$r" config user.email studente@example.com
           echo "bozza" > "$r/note.txt"; git_ "$r" add -A; git_ "$r" commit -q -m "prima bozza"
           echo "listino" > "$r/listino.txt"; git_ "$r" add -A; git_ "$r" commit -q -m "aggiunto il listino"
           echo "fattura 2026-0042: 1200 euro" > "$r/fattura.txt"; git_ "$r" add -A; git_ "$r" commit -q -m "lavoro importante: fattura"
           git_ "$r" reset -q --hard HEAD~1
           echo "Nel repository lavoro/progetto hai fatto il commit \"lavoro importante: fattura\", poi un 'git reset --hard' e ora non c'è più: né nel log, né il file fattura.txt." ;;
        6) local r=$W/app; mkdir -p "$r"; git_ "$r" init -q; git_ "$r" config user.name Studente; git_ "$r" config user.email studente@example.com
           printf 'colore=blu\nporta=80\n' > "$r/config.txt"; git_ "$r" add -A; git_ "$r" commit -q -m "configurazione iniziale"
           git_ "$r" switch -q -c feature
           printf 'colore=rosso\nporta=80\ndebug=true\n' > "$r/config.txt"; git_ "$r" commit -q -am "debug acceso, colore rosso"
           git_ "$r" switch -q main
           printf 'colore=verde\nporta=80\ntimeout=30\n' > "$r/config.txt"; git_ "$r" commit -q -am "timeout a 30, colore verde"
           git_ "$r" merge feature > /dev/null 2>&1
           echo "In lavoro/app un 'git merge feature' è finito con un conflitto: config.txt è pieno di segni strani e il merge non è concluso. Servono sia il timeout sia il debug." ;;
        7) rmq -X PUT -H 'content-type: application/json' -d '{"type":"direct","durable":true}' "$RMQ/exchanges/%2F/ordini" > /dev/null
           rmq -X PUT -H 'content-type: application/json' -d '{"durable":true}' "$RMQ/queues/%2F/da-spedire" > /dev/null
           rmq -X POST -H 'content-type: application/json' -d '{"routing_key":"nuovo"}' "$RMQ/bindings/%2F/e/ordini/q/da-spedire" > /dev/null
           cat > "$W/invia.sh" << EOF
#!/usr/bin/env bash
# pubblica un ordine nell'exchange "ordini": deve finire nella coda da-spedire
amqp-publish --url=$AMQP -e ordini -r nuovi -b "ordine \$RANDOM"
EOF
           echo "lavoro/invia.sh pubblica un ordine senza nessun errore, ma la coda da-spedire resta vuota." ;;
        8) local t; t=eventi-$(date +%s)
           printf 'avvio\nlogin anna\nlogin bruno\nordine 1\nspegnimento\n' | kcat -b kafka:9092 -P -t "$t" 2> /dev/null
           cat > "$W/leggi.sh" << EOF
#!/usr/bin/env bash
# stampa gli eventi del topic $t
kcat -b kafka:9092 -C -t $t -o end -e -q
EOF
           echo "lavoro/leggi.sh dovrebbe stampare gli eventi del topic $t (ci sono 5 messaggi), ma non stampa niente." ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    chmod +x "$W"/*.sh 2> /dev/null
    return 0
}

# ---------------------------------------------------------------- i controlli: il problema è risolto?
ESITO=0
prova() {
    local d=$1; shift
    if "$@" > /dev/null 2>&1; then echo "  OK        $d"; else echo "  ANCORA NO $d"; ESITO=1; fi
}
esegue() { (cd "$W" && timeout 60 bash "$1" 2> /dev/null); }
c1() { rm -f "$W/utenti.json"; [[ $(esegue scarica.sh) == 10 ]] && jq -e 'length == 10 and .[0].id == 1' "$W/utenti.json"; }
c2() { [[ $(esegue conta-items.sh) == 15 ]]; }
c3() { [[ $(esegue report.sh) == 3000 ]]; }
c3_stretto() {      # non vale ALL PRIVILEGES né il permesso di scrivere: il report legge e basta
    ! my -N -e "SHOW GRANTS FOR 'report'@'%'" | grep -qiE 'ALL PRIVILEGES|GRANT OPTION|INSERT|UPDATE|DELETE'
}
c4() {
    local riga; riga=$(mysql -h mysql -uroot -plab app_db -N -e "EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) FROM logs WHERE created_at >= '2026-09-14 10:00:00' AND created_at < '2026-09-14 11:00:00'" 2> /dev/null | head -1)
    local tipo chiave righe; tipo=$(cut -f5 <<< "$riga"); chiave=$(cut -f7 <<< "$riga"); righe=$(cut -f10 <<< "$riga")
    [[ $tipo == range && $chiave != NULL && $righe -lt 2000 ]]
}
c4_script() { [[ $(esegue cerca-log.sh) =~ ^[0-9]+$ ]]; }
c5() {
    local r=$W/progetto
    [[ $(git_ "$r" log -1 --format=%s 2> /dev/null) == "lavoro importante: fattura" && -f $r/fattura.txt && $(git_ "$r" branch --show-current) == main ]]
}
c6() {
    local r=$W/app
    ! grep -rqE '^(<<<<<<<|=======|>>>>>>>)' "$r/config.txt" && grep -q '^timeout=30$' "$r/config.txt" && grep -q '^debug=true$' "$r/config.txt" \
        && [[ ! -e $r/.git/MERGE_HEAD ]] && [[ $(git_ "$r" rev-list --parents -n1 HEAD | wc -w) == 3 ]] && [[ -z $(git_ "$r" status --porcelain) ]]
}
c7() {
    # le statistiche della coda arrivano ogni pochi secondi: si svuota, si pubblica e si aspetta di vedere 1 messaggio
    rmq -X DELETE "$RMQ/queues/%2F/da-spedire/contents" > /dev/null
    esegue invia.sh > /dev/null
    local i
    for i in $(seq 1 15); do
        [[ $(rmq "$RMQ/queues/%2F/da-spedire" | jq -r '.messages // 0') == 1 ]] && return 0
        sleep 1
    done
    return 1
}
c8() { [[ $(esegue leggi.sh | wc -l) == 5 ]]; }
controlla() {
    case $1 in
        1) prova "lo script stampa 10 e scrive utenti.json con gli utenti" c1 ;;
        2) prova "lo script stampa il totale degli elementi (15)" c2 ;;
        3) prova "report.sh conta gli ordini (3000)" c3
           prova "l'utente report può leggere e basta (niente ALL, niente scritture)" c3_stretto ;;
        4) prova "la ricerca per ora usa un indice e legge poche righe" c4
           prova "cerca-log.sh funziona ancora" c4_script ;;
        5) prova "il commit \"lavoro importante: fattura\" è di nuovo in cima al ramo main, con il suo file" c5 ;;
        6) prova "il merge è concluso, senza segni di conflitto, con timeout e debug" c6 ;;
        7) prova "un ordine pubblicato da invia.sh arriva nella coda da-spedire" c7 ;;
        8) prova "leggi.sh stampa i 5 eventi" c8 ;;
        *) echo "scenari da 1 a $NSCENARI" >&2; exit 2 ;;
    esac
    if (( ESITO == 0 )); then echo "RISOLTO"; else echo "non ancora"; fi
    return $ESITO
}

case $cmd in
    guasta)
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 guasta N   (N da 1 a $NSCENARI)" >&2; exit 2; }
        salute; guasta "$n"; echo "$n" > "$STATO" ;;
    controlla)
        [[ -n $n ]] || n=$(cat "$STATO" 2> /dev/null) || { echo "nessuno scenario in corso: ./scenari.sh guasta N" >&2; exit 2; }
        [[ $n =~ ^[1-8]$ ]] || { echo "uso: $0 controlla [N]" >&2; exit 2; }
        controlla "$n" ;;
    ripristina) salute; echo "tutto in salute" ;;
    *) echo "uso: $0 guasta N | controlla [N] | ripristina" >&2; exit 2 ;;
esac
