#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 13: Plesk
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gira sul container "plesk" (root). Plesk e i suoi servizi li avvia compose.yaml; qui si preparano i file
# che servono agli esempi dei .md: lo script che crea il cliente e il sito di prova, le pagine PHP, il file
# per le impostazioni PHP, un sito statico e un dump SQL da caricare dal pannello.
set -euo pipefail

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

# ---------------------------------------------------------------- 02-cli-hosting
sezione 02-cli-hosting
cat > crea-esempio.sh << 'EOF'
#!/usr/bin/env bash
# crea-esempio.sh - il cliente "mario" e il sito esempio.test usati da 03-manutenzione.md e 04-pannello-cliente.md
# (02-cli-hosting.md li crea un comando alla volta: qui sono tutti insieme). Si lancia una volta sola per laboratorio.
set -euo pipefail
export PSA_PASSWORD='Pl3sk-Lab!2026x'        # la password passa dall'ambiente, non dalla riga di comando (vedi 02-cli-hosting.md)
IP=$(plesk bin ipmanage --ip_list | awk 'NR==2 {split($3, a, /[:\/]/); print a[2]}')   # l'indirizzo del container
plesk bin customer --create mario -name "Mario Rossi" -email mario@example.test -passwd ""
plesk bin subscription --create esempio.test -owner mario -service-plan "Default Domain" -ip "$IP" -login mrossi -passwd ""
echo "pronto: esempio.test (cliente mario, utente FTP/SSH mrossi, password $PSA_PASSWORD)"
EOF
chmod +x crea-esempio.sh

cat > info.php << 'EOF'
<?php
// quale PHP sta servendo la pagina, con quali limiti e con quale open_basedir
echo "PHP ", PHP_VERSION, " (", PHP_SAPI, ")\n";
echo "memory_limit=", ini_get("memory_limit"), " upload_max_filesize=", ini_get("upload_max_filesize"), "\n";
echo "open_basedir=", ini_get("open_basedir"), "\n";
echo "sito: ", $_SERVER["SERVER_NAME"], "\n";
EOF

cat > cron.php << 'EOF'
<?php
// lo script del cron di 02-cli-hosting.md: aggiunge una riga a cron.log accanto a se stesso
file_put_contents(__DIR__ . "/cron.log", date("c") . " eseguito\n", FILE_APPEND);
EOF

cat > php-extra.ini << 'EOF'
memory_limit=256M
upload_max_filesize=64M
EOF

cat > dump.sql << 'EOF'
-- una tabella piccola da importare in un database di Plesk (02-cli-hosting.md: plesk bin database --upload)
CREATE TABLE IF NOT EXISTS clienti (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(60) NOT NULL,
    citta VARCHAR(60) NOT NULL
);
INSERT INTO clienti (nome, citta) VALUES
    ('Anna Verdi', 'Torino'),
    ('Luca Bianchi', 'Bologna'),
    ('Sara Neri', 'Napoli');
EOF

# ---------------------------------------------------------------- 04-pannello-cliente
sezione 04-pannello-cliente
mkdir -p sito-statico
cat > sito-statico/index.html << 'EOF'
<!doctype html>
<html lang="it">
<head><meta charset="utf-8"><title>Sito di prova</title></head>
<body><h1>Sito di prova</h1><p>Caricato dal Gestore file del pannello.</p></body>
</html>
EOF
cat > sito-statico/chi-siamo.html << 'EOF'
<!doctype html>
<html lang="it">
<head><meta charset="utf-8"><title>Chi siamo</title></head>
<body><h1>Chi siamo</h1><p>Una pagina in più, per provare gli upload.</p></body>
</html>
EOF

if (( ! SILENZIOSO )); then
    echo "Laboratorio pronto in $DEST:"
    (cd "$DEST" && find . -type f ! -name .lab-bashbash | sort | sed 's|^\./|  |')
    echo
    echo "Prima di iniziare:  cd 02-cli-hosting && ./crea-esempio.sh     (poi: plesk login, vedi lab/README.md per il pannello)"
fi
