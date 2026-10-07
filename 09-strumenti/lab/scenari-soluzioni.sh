#!/usr/bin/env bash
# scenari-soluzioni.sh FASE N - le riparazioni di riferimento degli scenari di 14-scenari.md (area 09), e alcune "scorciatoie"
# che sembrano ripararli ma non lo fanno (servono a provare che scenari.sh controlla non si lascia ingannare).
#   scenari-soluzioni.sh risolvi N     la riparazione giusta
#   scenari-soluzioni.sh sbagliata N   un tentativo che non basta (non esiste per tutti gli scenari)
# La usa scenari-autotest.sh. Gira come root nella shell del laboratorio 09.
set -uo pipefail
fase=${1:?uso: $0 risolvi|sbagliata N}
n=${2:?uso: $0 FASE N}
W=${LAB_SCENARI:-$HOME/lab/14-scenari}/lavoro

my() { mysql -h mysql -uroot -plab "$@" 2> /dev/null; }
git_() { git -C "$1" -c user.name=Lab -c user.email=lab@example.com "${@:2}"; }

risolvi() {
    case $n in
        1) sed -i 's#http://api/redirect#http://api/users#' "$W/scarica.sh" ;;
        2) cat > "$W/conta-items.sh" << 'EOF'
#!/usr/bin/env bash
tot=0; p=1
while :; do
    k=$(curl -s "http://api/items?page=$p" | jq length)
    (( k )) || break
    tot=$((tot + k)); p=$((p + 1))
done
echo "$tot"
EOF
           ;;
        3) my -e "GRANT SELECT ON app_db.orders TO 'report'@'%'" ;;
        4) my app_db -e "CREATE INDEX idx_logs_created_at ON logs (created_at)" ;;
        5) git_ "$W/progetto" reset -q --hard 'HEAD@{1}' ;;
        6) printf 'colore=verde\nporta=80\ntimeout=30\ndebug=true\n' > "$W/app/config.txt"
           git_ "$W/app" add config.txt; git_ "$W/app" commit -q -m "merge feature" ;;
        7) sed -i 's/-r nuovi /-r nuovo /' "$W/invia.sh" ;;
        8) sed -i 's/-o end/-o beginning/' "$W/leggi.sh" ;;
        *) echo "scenari da 1 a 8" >&2; exit 2 ;;
    esac
}
sbagliata() {
    case $n in
        1) printf '#!/usr/bin/env bash\necho 10\n' > "$W/scarica.sh" ;;                                          # stampa 10 senza scaricare niente
        2) sed -i 's/page=1/page=2/' "$W/conta-items.sh" ;;                                                      # un'altra pagina: sempre 5
        3) my -e "GRANT ALL PRIVILEGES ON app_db.* TO 'report'@'%'" ;;                                           # funziona, ma regala tutto
        4) my app_db -e "ANALYZE TABLE logs" ;;                                                                  # aggiorna le statistiche, non crea indici
        5) git_ "$W/progetto" checkout -q . ;;                                                                   # non fa tornare un commit
        6) git_ "$W/app" merge --abort ;;                                                                        # il conflitto sparisce, ma il merge no
        7) sed -i 's/-r nuovi /-r nuov /' "$W/invia.sh" ;;                                                       # un'altra chiave sbagliata
        8) sed -i 's/-o end/-o -1/' "$W/leggi.sh" ;;                                                             # legge solo l'ultimo messaggio
        *) echo "nessun tentativo sbagliato per lo scenario $n" >&2; exit 2 ;;
    esac
}
case $fase in
    risolvi|sbagliata) "$fase" ;;
    *) echo "fasi: risolvi, sbagliata" >&2; exit 2 ;;
esac
