#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 01: basi della shell
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Per ogni .md dell'area crea una sottocartella con lo stesso nome. Non servono servizi: bastano la shell e l'immagine.
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

# ---------------------------------------------------------------- 01-shell, 02-shortcut, 03-help-e-manuali, 07-concatenazioni
# si lavora sul prompt, senza file: le cartelle ci sono per coerenza con le altre aree
for s in 01-shell 02-shortcut 03-help-e-manuali 07-concatenazioni; do sezione "$s"; done

# ---------------------------------------------------------------- 04-comandi-base
sezione 04-comandi-base
touch doc1.rar doc22.rar docA.rar apple eagle zebra testo
mkdir -p d1/sotto d2
touch d1/sotto/file.txt

# ---------------------------------------------------------------- 05-alias
sezione 05-alias
ln -s /kb/01-basi/bashrc-esempio bashrc-esempio     # da caricare con: source bashrc-esempio

# ---------------------------------------------------------------- 06-history
sezione 06-history
cat > comandi.txt << 'EOF'
echo uno
echo due
!!
!echo
!?du?
touch file nuovo
rm !$
echo a b c
echo !*
echo !:1
!echo:p
^a^A
echo dev dev
!!:s/dev/prod/
echo dev dev
!!:gs/dev/prod/
history 4
EOF
cat > prova.sh << 'EOF'
#!/usr/bin/env bash
# prova.sh [FILE] - lancia i comandi di un file in una shell INTERATTIVA, cioè con l'espansione della history
# (!!, !$, ^a^b...), che in uno script normale non c'è. Uso: ./prova.sh comandi.txt
# Il prompt e le righe digitate le stampa bash stesso: si vede il comando espanso (es. "echo due") e il suo output.
FILE=${1:-comandi.txt}
HISTFILE=$(mktemp) bash --norc -i < "$FILE" 2>&1 | grep -v -e 'cannot set terminal process group' -e 'no job control'
EOF
chmod +x prova.sh

# ---------------------------------------------------------------- 08-pipeline
sezione 08-pipeline
mkdir -p logs backup
printf 'prima riga\nseconda riga\n' > logs/app.log
printf 'una riga\n' > "logs/errori vecchi.log"       # il nome ha uno spazio: serve -print0 / -0
touch vecchio.bak copia.bak log_a log_b
printf 'log_a\nlog_b\n' > lista_file.txt
printf 'riga uno\n\nriga tre\n' > SCRIPT.md

# ---------------------------------------------------------------- 09-file-di-avvio
sezione 09-file-di-avvio
# una "home" finta: ogni file di avvio dice quando viene letto. Si prova con HOME=$PWD/casa, senza toccare quella vera
mkdir -p casa
for f in .profile .bash_profile .bash_login .bashrc .bash_logout; do
    printf 'echo "   [letto %s]"\n' "$f" > "casa/$f"
done
echo "echo '   [letto BASH_ENV]'" > benv.sh
cat > prova.sh << 'EOF'
#!/usr/bin/env bash
# prova.sh - quali file di avvio legge bash, a seconda di come parte. Usa la home finta ./casa (non quella vera).
# Per ogni caso stampa il comando e le righe "[letto ...]" che i file di avvio producono.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
export HOME=$PWD/casa
caso() {
    echo "\$ $1"
    bash -c "$1" 2>&1 | grep -v -e 'cannot set terminal process group' -e 'no job control' | sed 's/^[^ ]*[#$] //'
}
caso 'bash -lc "echo fatto"'                              # login, non interattiva
caso 'echo "echo fatto" | bash -i'                        # interattiva, non login
caso 'echo "echo fatto" | bash -li'                       # login e interattiva
caso 'bash -c "echo fatto"'                               # non interattiva, non login: uno script
caso 'BASH_ENV=$PWD/benv.sh bash -c "echo fatto"'      # non interattiva, ma con BASH_ENV
caso 'bash --noprofile -lc "echo fatto"'                   # login senza leggere i profili: le opzioni lunghe vanno PRIMA
caso 'echo "echo fatto" | bash --norc -i'                 # interattiva senza .bashrc
echo "--- senza .bash_profile: ora legge .bash_login"
mv casa/.bash_profile casa/.bash_profile.off
caso 'bash -lc "echo fatto"'
mv casa/.bash_login casa/.bash_login.off
echo "--- senza .bash_profile e .bash_login: legge .profile"
caso 'bash -lc "echo fatto"'
mv casa/.bash_profile.off casa/.bash_profile; mv casa/.bash_login.off casa/.bash_login
EOF
chmod +x prova.sh

if (( ! SILENZIOSO )); then
    echo "Laboratorio dell'area 01 pronto in $DEST: una cartella per ogni .md"
    ls "$DEST" | sed 's/^/  /'
    echo "Per ripartire da zero: bash $LAB_SRC/prepara.sh"
fi
