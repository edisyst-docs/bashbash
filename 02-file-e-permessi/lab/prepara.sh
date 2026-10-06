#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 02: file e permessi
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
    chmod -R u+rwX "$DEST" 2>/dev/null || true   # gli esercizi sui permessi potrebbero impedire rm
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md
righe()   { for i in $(seq "$2"); do echo "$1 $i"; done; }  # righe "testo N" da 1 a N

# ---------------------------------------------------------------- 01-file-base
sezione 01-file-base
printf '# Titolo\n\nUn file **markdown** di prova.\n' > crontab.md
echo "file di testo semplice" > file1.txt
echo "contenuto di file1" > file1
printf 'prima riga del file\nseconda riga, un po'"'"' più lunga\nterza e ultima riga\n' > file
echo "file per verificare l'integrità" > file.txt
echo "il file da copiare" > origine
cp "$LAB_SRC/materiale/img.png" immagine.png
gzip -c file > file.gz
printf '#!/bin/bash\necho ciao\n' > script.sh && chmod +x script.sh
ln -s file1.txt collegamento
mkdir -p destinazione dir_1 directory_vuota genitore/figlio/nipote directory_non_vuota/sotto
touch dir_1/a.txt dir_1/b.txt directory_non_vuota/uno.txt directory_non_vuota/sotto/due.txt
mkdir -p cartella/documenti/2026 cartella/immagini
touch cartella/leggimi.txt cartella/documenti/fattura.pdf cartella/documenti/2026/bilancio.ods cartella/immagini/logo.png
mkdir -p prova1/sotto
touch prova1/testo1.txt prova1/testo2.txt prova1/appunti.md prova1/sotto/testo3.txt

# ---------------------------------------------------------------- 02-find
sezione 02-find
echo "sono long.txt" > long.txt
mkdir -p conf test_dir backup vuota1 vuota2/vuota3 foto
echo "chiave=valore" > config
echo "chiave=valore" > conf/app.conf
touch test1.txt test2.log test_dir/test3.txt
printf 'testo vecchio da sostituire\n' > note.txt
printf 'altro testo vecchio\n' > leggimi.txt
echo "log dell'app" > app.log
echo "log degli errori" > errori.log
touch cache.tmp sessione.tmp foto/mare.jpg foto/montagna.jpg
echo "privato" > privato.txt && chmod 600 privato.txt
printf '#!/bin/bash\necho senza x\n' > senza_x.sh
printf '#!/bin/bash\necho con x\n' > con_x.sh && chmod +x con_x.sh
echo "stesso contenuto" > copia1.txt
echo "stesso contenuto" > copia2.txt
head -c 3M /dev/zero > grande.bin
head -c 200K /dev/urandom > medio.bin
mkdir -p app vendor/pacchetto node_modules/libreria
echo "<?php return ['debug' => env('APP_DEBUG')];" > app/config.php
echo "<?php echo 'ciao';" > app/index.php
echo "<?php // codice di terzi" > vendor/pacchetto/lib.php
echo "<?php // non dovrebbe stare qui" > node_modules/libreria/strano.php
echo "{}" > composer.lock
touch -d '2026-09-10 12:00' composer.lock
touch -d '2026-09-05 12:00' note.txt                  # PRIMA del lock e dentro 1-15 settembre
touch -d '2026-09-12 12:00' leggimi.txt               # DOPO il lock e dentro 1-15 settembre
touch -d '2025-01-01 12:00' app.log                   # più vecchio di un anno
mkdir -p laravel/storage/logs laravel/bootstrap/cache laravel/app laravel/public
touch laravel/storage/logs/laravel.log laravel/bootstrap/cache/services.php laravel/app/Model.php laravel/public/index.php
printf '#!/usr/bin/env php\n<?php\n' > laravel/artisan

# ---------------------------------------------------------------- 03-archivi-compressione
sezione 03-archivi-compressione
righe "riga ripetuta per comprimere bene" 500 > file1
righe "altro testo compressibile" 500 > file2
mkdir -p directory1/sotto
righe "dentro directory1" 50 > directory1/a.txt
righe "ancora più in basso" 50 > directory1/sotto/b.txt
mkdir -p progetto/app progetto/db progetto/vendor/pacchetto progetto/node_modules/libreria progetto/.git
echo "<?php echo 'ciao';" > progetto/app/index.php
echo "APP_KEY=segreta" > progetto/.env
echo "CREATE TABLE utenti (id INT);" > progetto/db/schema.sql
echo "INSERT INTO utenti VALUES (1);" > progetto/db/dati.sql
echo "// dipendenza" > progetto/vendor/pacchetto/lib.php
echo "// dipendenza js" > progetto/node_modules/libreria/index.js
echo "ref: refs/heads/main" > progetto/.git/HEAD
tar -czf backup.tar.gz progetto                       # per gli esempi di estrazione selettiva
mkdir -p dati
head -c 1M /dev/urandom > dati/binario.dat
righe "dato" 1000 > dati/testo.txt

# ---------------------------------------------------------------- 04-link
sezione 04-link
echo "sono il file originale" > file

# ---------------------------------------------------------------- 05-redirezioni
sezione 05-redirezioni
printf 'pera\nmela\nbanana\nkiwi\narancia\n' > elenco
printf 'localhost\n127.0.0.1\n' > elenco_server.txt

# ---------------------------------------------------------------- 06-dd
sezione 06-dd                                          # vuota: i file li crea il .md stesso

# ---------------------------------------------------------------- 07-diff-e-rsync
sezione 07-diff-e-rsync
printf '#IFS=";"\necho "Riga uguale"\necho "Riga simile"\n\necho "Riga diversa"\n' > simile1.sh
printf '#IFS=";"\necho "Riga uguale"\necho "Riga quasi simile"\n\necho "Riga COMPLETAMENTE DIFFERENTE"\n' > simile2.sh
printf 'Ciao mondo\nriga   con   spazi\nterza riga\n' > file1
printf 'ciao mondo\nriga con spazi\nterza riga modificata\n' > file2
head -c 1024 /dev/urandom > file1.bin
cp file1.bin file2.bin
printf 'X' | dd of=file2.bin bs=1 seek=100 conv=notrunc status=none   # un solo byte diverso, al 101°
printf 'carlo\nanna\nbeppe\ndario\n' > lista1.txt
printf 'dario\nanna\nelena\n' > lista2.txt
printf 'porta=8080\nlog=info\ncache=on\n' > config
mkdir -p sorgente/sotto sorgente/cache destinazione
righe "file a" 20 > sorgente/a.txt
righe "file b" 20 > sorgente/b.txt
righe "file c" 20 > sorgente/sotto/c.txt
touch sorgente/cache/dati.bin sorgente/lavoro.tmp
echo "esiste solo nella destinazione" > destinazione/vecchio.txt
mkdir -p cartella1/sotto cartella2/sotto
echo uguale > cartella1/uguale.txt ; echo uguale > cartella2/uguale.txt
echo versione1 > cartella1/diverso.txt ; echo versione2 > cartella2/diverso.txt
echo solo1 > cartella1/sotto/solo_in_1.txt
echo solo2 > cartella2/solo_in_2.txt
mkdir -p src dst
righe "sorgente" 10 > src/dati.txt
printf '*.tmp\ncache/\n' > escludi.txt
printf '.git/\nnode_modules/\n.env\nstorage/logs/*\n' > .rsyncignore

# ---------------------------------------------------------------- 08-permessi
sezione 08-permessi
echo "file su cui cambiare i permessi" > file
mkdir -p cart/sotto protetta cartella
touch cart/a.txt cart/sotto/b.txt
printf '#!/bin/bash\necho "sono eseguibile"\n' > eseguibile
mkdir -p progetto/src progetto/config
touch progetto/src/main.sh progetto/config/app.ini progetto/leggimi.txt
chmod +x progetto/src/main.sh
echo "DB_PASSWORD=segreta" > .env

# ---------------------------------------------------------------- 09-proprietari
sezione 09-proprietari
echo "file a cui cambiare proprietario" > file.txt

# Stato iniziale uniforme: file 644 e cartelle 755, tranne quelli resi diversi apposta sopra
cd "$DEST"
find . -type d -exec chmod 755 {} +
find . -type f ! -perm -u+x ! -name privato.txt -exec chmod 644 {} +

# ---------------------------------------------------------------- 10-esercizi
sezione 10-esercizi
mkdir -p palestra risposte
(
    cd palestra
    # log, di cui uno nella sottocartella
    mkdir -p server/old cache vuota src/vuota vendor node_modules progetto sito/img sito/css condivisa release-1 release-2 dati
    echo "avvio" > app.log; echo "errore: disco" > errori.log; echo "GET /" > server/access.log; echo "vecchio" > server/old/vecchio.log
    # php: due nostri, uno in src, e quelli di terzi
    echo '<?php echo 1;' > index.php; echo '<?php echo 2;' > lib.php; echo '<?php echo 3;' > src/a.php
    echo '<?php echo 4;' > vendor/x.php; echo '<?php echo 5;' > node_modules/y.php
    # .tmp: due vecchi (2020) e due recenti
    touch cache/a.tmp cache/b.tmp nuovo1.tmp nuovo2.tmp
    touch -d 2020-01-01 cache/a.tmp cache/b.tmp
    # un file grande e uno piccolo
    head -c 2097152 /dev/zero > grande.bin; echo piccolo > piccolo.bin
    # script e permessi
    printf '#!/bin/sh\necho deploy\n' > deploy.sh; printf '#!/bin/sh\necho backup\n' > backup.sh; printf '#!/bin/sh\necho test\n' > script.sh
    chmod 755 deploy.sh backup.sh; chmod 644 script.sh
    echo "una nota" > nota.txt; echo "chiave=segreta" > segreto.txt; chmod 644 nota.txt segreto.txt
    # progetto: permessi larghi da stringere
    echo a > progetto/a.txt; echo b > progetto/b.txt; mkdir progetto/sub; echo c > progetto/sub/c.txt
    chmod 666 progetto/a.txt; chmod 664 progetto/b.txt progetto/sub/c.txt; chmod 777 progetto/sub; chmod 775 progetto
    # sito: tutto a 700/600, da portare a 755/644
    echo '<html>' > sito/index.html; echo 'body{}' > sito/css/stile.css; echo png > sito/img/logo.png; echo txt > sito/robots.txt
    chmod 600 sito/index.html sito/css/stile.css sito/img/logo.png sito/robots.txt; chmod 700 sito sito/css sito/img
    chmod 755 condivisa
    # link e hard link
    echo "dati" > dati.txt; echo uno > dati/a.csv; echo due > dati/b.csv; echo t1 > dati/c.tmp; echo t2 > dati/d.tmp
    # archivio da cui estrarre un file
    mkdir -p /tmp/rel-$$/release; echo "porta=8080" > /tmp/rel-$$/release/config.ini; echo "print(1)" > /tmp/rel-$$/release/app.py
    tar czf release.tar.gz -C /tmp/rel-$$ release; rm -rf /tmp/rel-$$
    # rsync / confronto
    printf 'mela\npera\nbanana\narancia\n' > lista1.txt; printf 'pera\nkiwi\nbanana\n' > lista2.txt
    mkdir -p origine/.git origine/css; echo "x" > origine/.git/HEAD; echo "<html>" > origine/index.html; echo "b{}" > origine/css/s.css; echo "nota" > origine/LEGGIMI
)
cp "$LAB_SRC/verifica.sh" .
chmod +x verifica.sh

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 02 pronto in $DEST: una cartella per ogni .md"
    ls "$DEST" | sed 's/^/  /'
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
