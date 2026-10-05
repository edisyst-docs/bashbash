#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 09: jq/curl, git, mysql
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Per ogni .md dell'area crea una sottocartella con lo stesso nome. I servizi (MySQL e l'API
# finta su http://api) li avvia compose.yaml: questo script prepara solo i file.
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

# ---------------------------------------------------------------- 01-jq-e-curl
sezione 01-jq-e-curl
echo '{"nome":"Mario","eta":42,"tag":["a","b"]}' > file.json
python3 "$LAB_SRC/api.py" utenti > users.json         # gli stessi utenti che restituisce http://api/users
printf '{\n  "nome": "app",\n  "versione": "1.0",\n  "debug": false\n}\n' > config.json
printf '{"nome":"mario","email":"mario@example.com","password":"segreta"}\n' > utente.json
printf '{"name":"Mario","email":"mario@example.com"}\n' > payload.json
printf 'Authorization: Bearer token-di-prova\n' > header.txt
head -c 2048 /dev/urandom > foto.jpg
printf 'http://api/file.zip\nhttp://api/style.css\nhttp://api/docs/index.html\n' > lista_url.txt
mkdir -p storage/logs
cat > storage/logs/laravel.json << 'EOF'
{"datetime":"2026-09-25T10:00:00+02:00","level_name":"INFO","message":"richiesta servita","context":{"user_id":7}}
{"datetime":"2026-09-25T10:25:00+02:00","level_name":"ERROR","message":"SQLSTATE[HY000] [2002] Connection refused","context":{}}
{"datetime":"2026-09-25T10:40:00+02:00","level_name":"WARNING","message":"cache lenta","context":{"ms":900}}
{"datetime":"2026-09-25T11:05:00+02:00","level_name":"ERROR","message":"Undefined variable $totale","context":{"file":"Carrello.php"}}
EOF
cat > composer.json << 'EOF'
{
    "name": "lab/app",
    "require": {
        "php": "^8.3",
        "laravel/framework": "^12.0",
        "guzzlehttp/guzzle": "^7.9"
    }
}
EOF

# ---------------------------------------------------------------- 02-git
# Repository "progetto" con una storia da indagare: due autori, date sparse negli ultimi 2 mesi,
# un file rinominato, un tag v2.3.0, un bug introdotto dopo il tag (per bisect), un branch già
# unito, un branch cancellato (per il reflog), un remoto "origin" e modifiche non committate.
sezione 02-git
git init -q --bare -b main origin.git
git init -q -b main progetto
cd progetto
git config user.name "Edoardo"                        # identità solo di questo repo: non tocca ~/.gitconfig
git config user.email "edoardo@example.com"
git remote add origin ../origin.git

commit() {                                            # commit AUTORE GIORNI_FA MESSAGGIO
    local data
    data=$(date -d "$2 days ago 10:00" '+%F %T')
    git add -A
    GIT_AUTHOR_NAME=$1 GIT_AUTHOR_EMAIL="${1,,}@example.com" GIT_AUTHOR_DATE=$data \
    GIT_COMMITTER_NAME=$1 GIT_COMMITTER_EMAIL="${1,,}@example.com" GIT_COMMITTER_DATE=$data \
        git commit -qm "$3"
}

mkdir -p app/Models app/Http app/Services config vecchio
printf '# Progetto di prova\n' > README.md
printf "<?php\nreturn ['name' => 'Lab', 'timezone' => 'UTC'];\n" > config/app.php
printf '<?php\nclass User\n{\n    public $name;\n}\n' > app/Models/User.php
{ echo '<?php'; echo 'class Kernel'; echo '{'; for i in $(seq 4 79); do echo "    // riga $i del kernel"; done; echo '}'; } > app/Http/Kernel.php
printf '<?php\n// funzioni di utilità\n' > vecchio/percorso.php
cat > app/Services/Carrello.php << 'EOF'
<?php
function calcolaTotale(array $righe): float
{
    $totale = array_sum($righe);
    return $totale * 1.22;
}
EOF
printf '<?php\necho "file di prova";\n' > file.php
commit Mario 60 "struttura iniziale"

printf "<?php\nreturn [\n    'host' => env('DB_HOST', '127.0.0.1'),\n    'database' => env('DB_DATABASE', 'app'),\n];\n" > config/database.php
commit Edoardo 55 "configurazione database"

printf '<?php\nclass User\n{\n    public $name;\n    public $email;\n}\n' > app/Models/User.php
commit Mario 50 "modello User: campo email"

mkdir -p nuovo
git mv vecchio/percorso.php nuovo/percorso.php
commit Edoardo 45 "sposta percorso.php in nuovo/"
git tag -a v2.3.0 -m "release 2.3.0"

sed -i '45s|.*|    protected $middleware = [\\App\\Http\\Middleware\\TrustProxies::class];|' app/Http/Kernel.php
commit Mario 40 "kernel: middleware globale"

sed -i 's|    $totale = array_sum($righe);|    $totale = array_sum($righe) - 0;   // sconto: per ora zero|' app/Services/Carrello.php
commit Edoardo 30 "carrello: prepara lo sconto"

sed -i 's|return $totale \* 1.22;|return round($totale * 1.20, 2);|' app/Services/Carrello.php   # IL BUG: IVA al 20% invece del 22%
commit Mario 25 "carrello: arrotondamento a 2 decimali"

git switch -q -c fix/typo
sed -i 's/# Progetto di prova/# Progetto di prova (laboratorio git)/' README.md
commit Mario 13 "README: titolo più chiaro"
git switch -q main
GIT_COMMITTER_DATE="$(date -d '12 days ago' '+%F %T')" git merge -q --no-ff fix/typo -m "merge fix/typo"

printf '# Progetto di prova (laboratorio git)\n\nIstruzioni: vedi docs/.\n' > README.md
commit Edoardo 10 "README: istruzioni"

printf '<?php\nclass User\n{\n    public $name;\n    public $email;\n\n    // TODO: gestire il secondo nome\n    public function nomeCompleto() { return $this->name; }\n}\n' > app/Models/User.php
commit Edoardo 8 "User: metodo nomeCompleto"

sed -i "s/'UTC'/'Europe\/Rome'/" config/app.php
commit Mario 3 "config: timezone"

sed -i '60s|.*|    // log di ogni richiesta|' app/Http/Kernel.php
commit Edoardo 1 "kernel: log delle richieste"

git switch -q -c feature/vecchio HEAD~2                 # branch che poi verrà cancellato sul server
printf '<?php\n// esperimento abbandonato\n' > vecchio.php
commit Mario 5 "esperimento vecchio"
git push -q origin main feature/vecchio v2.3.0
git branch -q --set-upstream-to=origin/feature/vecchio
git switch -q main
git branch -q -u origin/main
git branch -q -D feature/vecchio
git -C ../origin.git branch -q -D feature/vecchio     # ora origin/feature/vecchio è "orfano": lo toglie fetch --prune

git switch -q -c esperimento                          # branch cancellato per sbaglio: si recupera col reflog
printf '<?php\n// idea da non perdere\n' > idea.php
commit Edoardo 0 "esperimento: idea da non perdere"
git switch -q main
git branch -q -D esperimento

git switch -q -c feature/login                        # il branch su cui si sta lavorando
mkdir -p app/Http/Controllers
printf '<?php\nclass LoginController\n{\n    public function form() { return view("login"); }\n}\n' > app/Http/Controllers/LoginController.php
commit Edoardo 0 "login: form"
printf '<?php\nclass LoginController\n{\n    public function form() { return view("login"); }\n    public function valida($r) { dd($r); }\n}\n' > app/Http/Controllers/LoginController.php
commit Edoardo 0 "login: validazione (con un dd dimenticato)"

echo "    // modifica non ancora committata" >> app/Models/User.php
echo 'echo "modifica in corso";' >> file.php
echo "appunti non tracciati" > appunti.txt
cd ..

cat > verifica.sh << 'EOF'
#!/usr/bin/env bash
# verifica.sh - test per "git bisect run": esce 0 se l'IVA è al 22% (va bene), 1 se no (c'è il bug)
grep -q '1.22' app/Services/Carrello.php
EOF
cat > pre-commit << 'EOF'
#!/usr/bin/env bash
trovati=$(git diff --cached --name-only --diff-filter=ACM -- '*.php' | xargs -r grep -nHE '\b(dd|dump|var_dump)\(')
if [[ -n $trovati ]]; then
    echo "$trovati"
    echo "ERRORE: debug dimenticato nei file sopra. Commit bloccato (bypass: git commit --no-verify)" >&2
    exit 1
fi
EOF
chmod +x verifica.sh pre-commit

# ---------------------------------------------------------------- 03-mysql
sezione 03-mysql
cat > script.sql << 'EOF'
-- script di prova: mysql app_db < script.sql
SELECT COUNT(*) AS utenti FROM users;
SELECT u.name, COUNT(o.id) AS ordini, SUM(o.total) AS speso
FROM users u JOIN orders o ON o.user_id = u.id
GROUP BY u.id ORDER BY speso DESC LIMIT 3;
EOF
# ~/.my.cnf verso il MySQL del laboratorio. Non sovrascrive un .my.cnf vero (senza il marcatore)
if [[ ! -e $HOME/.my.cnf ]] || grep -q '^# lab-bashbash' "$HOME/.my.cnf"; then
    printf '# lab-bashbash: credenziali del MySQL del laboratorio\n[client]\nuser=root\npassword=lab\nhost=mysql\n' > "$HOME/.my.cnf"
    chmod 600 "$HOME/.my.cnf"
fi
if mysql -e 'SELECT 1' app_db > /dev/null 2>&1; then  # c'è il server: statistiche aggiornate e un dump da ripristinare
    mysql app_db -e 'ANALYZE TABLE users, orders, products, logs' > /dev/null
    mysqldump --single-transaction --set-gtid-purged=OFF app_db 2> /dev/null | gzip > app_db_2026-09-25.sql.gz
fi

# ---------------------------------------------------------------- 08-make e 09-bats
# lo stesso progetto: Makefile, uno script con la sua funzione e i test (lab/materiale/make/)
sezione 08-make
cp -r "$LAB_SRC"/materiale/make/. .
sezione 09-bats
cp "$LAB_SRC"/materiale/make/saluta.sh "$LAB_SRC"/materiale/make/test.bats "$LAB_SRC"/materiale/bats/stato.sh "$LAB_SRC"/materiale/bats/stato.bats .

# ---------------------------------------------------------------- 10-ricerca-veloce
# un progetto con codice, note, log e cartelle da ignorare, in un repository git (rg e fd rispettano .gitignore)
sezione 10-ricerca-veloce/progetto
mkdir -p app/modelli app/controller tests docs logs node_modules/lib vendor/pacchetto
cat > app/modelli/utente.py << 'EOF'
class Utente:
    """Un utente dell'applicazione."""

    def __init__(self, nome, email):
        self.nome = nome
        self.email = email

    # TODO: validare l'indirizzo email
    def saluta(self):
        return f"Ciao {self.nome}"

    def salva(self, db):
        # FIXME: manca la transazione
        db.execute("INSERT INTO utenti VALUES (?, ?)", (self.nome, self.email))
EOF
cat > app/modelli/ordine.py << 'EOF'
from app.modelli.utente import Utente


class Ordine:
    def __init__(self, utente: Utente, totale):
        self.utente = utente
        self.totale = totale

    def importo_con_iva(self, iva=0.22):
        return round(self.totale * (1 + iva), 2)

    # TODO: gestire gli sconti
    def descrizione(self):
        return f"Ordine di {self.utente.nome}: {self.totale}"
EOF
cat > app/controller/login.js << 'EOF'
// gestione del login
export function login(utente, password) {
  // TODO: limitare i tentativi
  if (!utente || !password) {
    throw new Error("credenziali mancanti");
  }
  return fetch("/api/login", { method: "POST", body: JSON.stringify({ utente, password }) });
}

export function logout() {
  localStorage.removeItem("token");
}
EOF
cat > app/controller/ordini.php << 'EOF'
<?php
// elenco degli ordini
function elenca_ordini($db, $utente) {
    // FIXME: la query non è parametrizzata
    return $db->query("SELECT * FROM ordini WHERE utente = '$utente'");
}
EOF
cat > tests/test_utente.py << 'EOF'
from app.modelli.utente import Utente


def test_saluta():
    assert Utente("Anna", "anna@example.com").saluta() == "Ciao Anna"
EOF
cat > docs/README.md << 'EOF'
# Progetto di prova

Un'applicazione per gestire utenti e ordini. Per installarla vedi `docs/installazione.md`.
TODO: scrivere la guida all'installazione.
EOF
printf 'function inutile() { return 1; }\n' > node_modules/lib/index.js
printf '<?php // libreria di terzi\n' > vendor/pacchetto/Lib.php
awk 'BEGIN { srand(7); split("INFO WARN ERROR", livelli, " "); for (i = 1; i <= 20000; i++) {
        l = livelli[(i % 7 == 0) ? 3 : (i % 3 == 0) ? 2 : 1]
        printf "2026-09-%02d 10:%02d:%02d %s richiesta %d da 10.0.%d.%d\n", 1 + i % 28, i % 60, (i * 7) % 60, l, i, i % 5, i % 250 } }' > logs/app.log
printf 'node_modules/\nvendor/\nlogs/\n' > .gitignore
git init -q . && git add -A && git -c user.name=lab -c user.email=lab@example.com commit -qm "progetto di prova"

# una cartella con file di dimensioni diverse, per ncdu e du
sezione 10-ricerca-veloce/spazio
mkdir -p video cache/pip cache/thumbnails log documenti
head -c 40M /dev/zero > video/registrazione.mp4
head -c 18M /dev/zero > video/clip.mp4
head -c 12M /dev/zero > cache/pip/pacchetti.whl
for i in 1 2 3 4 5 6; do head -c 2M /dev/zero > "cache/thumbnails/img$i.jpg"; done
head -c 9M /dev/zero > log/vecchio.log.1
head -c 1M /dev/zero > log/app.log
for i in 1 2 3; do head -c 300K /dev/zero > "documenti/relazione$i.pdf"; done

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 09 pronto in $DEST: una cartella per ogni .md"
    ls "$DEST" | sed 's/^/  /'
    echo "Servizi: API finta su http://api, MySQL su host 'mysql' (credenziali in ~/.my.cnf)"
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
