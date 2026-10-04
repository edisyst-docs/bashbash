#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 03: testo e regex
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Per ogni .md dell'area crea una sottocartella con lo stesso nome e dentro i file che i
# comandi di quel .md si aspettano di trovare. Rilanciarlo riporta tutto allo stato iniziale.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
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

# access.log in formato combined: IP, data, richiesta, status, byte (usato da awk, grep e sed)
access_log() {
    local ip=(10.0.0.5 10.0.0.5 10.0.0.5 192.168.1.20 192.168.1.20 172.16.0.8 10.0.0.9 203.0.113.7)
    local url=(/ /login /api/utenti /api/ordini /img/logo.png /carrello /admin /api/ordini)
    local st=(200 200 200 404 500 200 302 200 503 200)
    local i
    for i in $(seq 0 199); do
        printf '%s - - [25/Sep/2026:10:%02d:%02d +0200] "GET %s HTTP/1.1" %s %d "-" "curl/8.5"\n' \
            "${ip[i % 8]}" $((i / 60 % 60)) $((i % 60)) "${url[i * 7 % 8]}" "${st[i % 10]}" $(( (i * 997) % 50000 + 200 ))
    done
}

# log di Laravel tra le 09:50 e le 11:10 del 25/09/2026, con qualche ERROR e il suo stack trace
laravel_log() {
    local t
    for t in 09:50 09:55 10:00 10:05 10:10 10:15 10:20 10:25 10:30 10:40 10:50 11:00 11:05 11:10; do
        case $t in
            10:25) echo "[2026-09-25 $t:00] production.ERROR: SQLSTATE[HY000] [2002] Connection refused"
                   echo "#0 /var/www/app/vendor/laravel/framework/src/Database/Connection.php(412)"
                   echo "#1 /var/www/app/app/Http/Controllers/OrdiniController.php(37)" ;;
            11:05) echo "[2026-09-25 $t:00] production.ERROR: Undefined variable \$totale"
                   echo "#0 /var/www/app/app/Services/Carrello.php(88)" ;;
            *)     echo "[2026-09-25 $t:00] production.INFO: richiesta servita user_id=${t/:/}" ;;
        esac
    done
}

# ---------------------------------------------------------------- 01-stampa-e-taglia
sezione 01-stampa-e-taglia
cp "$LAB_SRC/materiale/divina_commedia.txt" .
{
    printf '%s\n' "10 banane:gialle" "2 mele:rosse" "23 kiwi:verdi" "1 arance:arancioni" \
        "20 pere:verdi" "2 mele:rosse" "3 fragole:rosse" "2 mele:rosse"
    for i in $(seq 9 25); do echo "$i riga di riempimento:numero$i"; done
    echo "99 riga lunghissima:$(printf 'x%.0s' $(seq 130))"
} > file
printf 'ciao\nda\nciao\n' > ciao
printf 'addio\ne\ngrazie\nper\ntutto\n' > addio
seq 5000 | sed 's/^/riga numero /' > file_5000
printf '%s\n' "Franco Nero 555-4440" "Aldo Baglio 555-4441" "Giovanni Storti 555-5002" \
    "Giacomo Poretti 555-4443" "Aldo Baglio 555-4441" "Mario Brega 555-4444" > phonebook
printf 'nome;città;età\nMario;Roma;34\nLuca;Milano;28\nAnna;Napoli;41\n' > file.csv
printf 'prodotto,qta,prezzo\npenne,10,1.50\nquaderni,4,3.20\nzaini,1,39.90\ngomme,25,0.40\n' > vendite.csv
printf 'A01\nA03\n' > ids.txt
printf 'A01,Mario,Roma\nA02,Luca,Milano\nA03,Anna,Napoli\nA04,Sara,Torino\n' > dati.csv
access_log > access.log
mkdir -p storage/logs
laravel_log > storage/logs/laravel.log
printf 'ciao\ncane e gatto\nrosso di sera\n' > t.txt
head -c 12M /dev/urandom > video.mp4

# ---------------------------------------------------------------- 02-grep
sezione 02-grep
cat > logfile.txt << 'EOF'
errore di connessione al database
ERRORE critico nel modulo pagamenti
Errore minore, ignorato
tutto ok, nessun problema
buongiorno a tutti
backup completato
questa riga arriva alla fine
.nascosto: questa riga inizia col punto
dei gatti e dei cani
la deità del tempio
Ciao raga
Ciao ragazzi, come va?
codici 404 e 500 nel log
prezzo [circa] 30 euro
opzione -v per invertire la ricerca
uno due tre
EOF
cp logfile.txt logfile
printf '[0-9]{3}\nERRORE\n' > regexfile
printf 'prima riga di file\n' > file
printf 'riga di file1\n' > file1
printf 'riga di file2\n' > file2
cat > script.md << 'EOF'
# appunti
ciao, prova con ls -l
; commento stile ini
ciao di nuovo
comando echo
EOF
laravel_log > laravel.log
printf 'GET /carrello user_id=42\nGET /ordini user_id=7\nGET /home\n' > log
access_log > access.log
printf 'login user=mario\nlogin user=anna\nlogout user=mario\n' > app.log
printf '<?php\ndeclare(strict_types=1);\n// TODO: validare input\n' > ordini.php
printf '<?php\n// tutto fatto\n' > utenti.php
printf '<?php\n' > vuoto.php
mkdir -p app/Http vendor/pacchetto node_modules/libreria sito
printf '<?php\ndd($ordine);\n' > app/Http/OrdiniController.php
printf '<?php\nreturn view("home");\n' > app/Http/HomeController.php
printf '<?php\ndump($x); // di terzi: da ignorare\n' > vendor/pacchetto/lib.php
printf 'dump(x)\n' > node_modules/libreria/index.js
printf 'APP_ENV=production\nAPP_DEBUG=true\n' > .env
printf 'https://vecchio.dominio.it/pagina\n' > sito/link.txt
printf 'server_name vecchio.dominio.it;\n' > sito/nginx.conf

# ---------------------------------------------------------------- 03-regex
sezione 03-regex
cat > ./crontab << 'EOF'
# m h dom mon dow comando
# backup notturno
0 2 * * * /usr/local/bin/backup.sh
*/5 * * * * php /var/www/app/artisan schedule:run
# pulizia (disattivata)
0 4 * * 0 find /tmp -mtime +7 -delete
30 6 * * 1-5 echo "$(date)"
EOF
printf 'Mario 555-123-4567\nLuca 5551234567\nAnna tel. 555-987-6543 (ufficio)\nSara 55-12-345\n' > contatti.txt
printf 'index.html\nchi-siamo.html\nstile.css\nhtml/leggimi.txt\n' > file.txt
printf 'mario.rossi@example.com\nanna@posta.it\nnon-una-email\nluca@server\nsara_b+news@example.org\n' > utenti.txt
cat > testo.txt << 'EOF'
Linux e linux sono lo stesso sistema, Xinux no
Ciao mondo, ciao a tutti
il colour inglese e il color americano
ROMA, Roma e roma
scopo, scopone, lo scopo
cane gatto topo 123 45 6789
EOF

# ---------------------------------------------------------------- 04-sed
sezione 04-sed
cat > config << 'EOF'
# file di configurazione di prova
# le righe con # sono commenti
porta=8080
prima=uno
host=localhost
# Inizio blocco
pattern=attivo
ciao=mondo
tre=3
# Fine blocco
log=info
EOF
printf 'ciao a tutti\nriga senza saluto\nciao di nuovo\nPattern maiuscolo\n' > file.txt
printf '>>> contenuto di altrofile.txt\n' > altrofile.txt
printf 'unix is great os. unix is opensource. unix is free os.\nlearn operating system.\nunix linux which one you choose.\n' > geek.txt
printf 'APP_NAME=Demo\nAPP_DEBUG=true\nAPP_URL=http://localhost\n' > .env
printf '#!/bin/bash\r\necho "scritto su Windows"\r\n' > script.sh
{ printf 'riga %s   \n' 1 2 3; echo; printf '   \n'; printf 'riga %s\n' $(seq 4 12); } > file
laravel_log > laravel.log
printf '{"utente":"mario","password": "segreta123"}\n{"utente":"anna","password":"pippo"}\n' > log.json
mkdir -p progetto/src progetto/test
printf 'class OldClass {}\n' > progetto/src/OldClass.php
printf 'new OldClass(); // e non OldClassHelper\n' > progetto/src/uso.php
printf 'assert(new OldClass());\n' > progetto/test/OldClassTest.php
git -C progetto init -q -b main
git -C progetto add .
git -C progetto -c user.name=lab -c user.email=lab@example.com commit -qm "stato iniziale"

# ---------------------------------------------------------------- 05-vim
sezione 05-vim
head -n 120 "$LAB_SRC/materiale/divina_commedia.txt" > testo.txt

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 03 pronto in $DEST: una cartella per ogni .md"
    ls "$DEST" | sed 's/^/  /'
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
