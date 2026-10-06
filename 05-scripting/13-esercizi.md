# Esercizi di scripting

> **Laboratorio**: `./lab.sh 05`, poi `cd 13-esercizi`. Materiale in `palestra/`, risposte in `risposte/`, controllo con `./verifica.sh` (vedi [lab/](lab/)).

Sedici esercizi in cui **si scrive uno script** e `verifica.sh` lo prova con più casi (argomenti, stdin, file mancanti, nomi con spazi) e lo confronta con la soluzione di riferimento. Coprono i `.md` dell'area:
[parametri](03-parametri.md), [condizioni](04-condizioni.md), [cicli](05-cicli.md), [array](06-array.md), [read](07-input-read.md), [espansioni](08-espansioni.md), [quoting](10-quoting.md), [funzioni](11-funzioni.md), [trap](12-trap-e-debug.md).
Le soluzioni sono nascoste in fondo a ogni esercizio.
(Altri esercizi di scripting, più grandi, sono in [../zz-esempi/esercizi/](../zz-esempi/esercizi/).)

## Come si lavora
Ogni risposta è uno **script bash** `risposte/NN.sh` (due cifre), che **riceve gli argomenti** e legge lo **stdin** come un normale script:
```bash
cd ~/lab/13-esercizi
cat > risposte/01.sh << 'EOF'
[[ $# -ge 1 ]] || { echo "uso: $0 nome" >&2; exit 1; }
echo "Ciao $1!"
EOF
./verifica.sh 1
#   01  OK (3 casi)
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                     # tutti: quelli senza risposta sono "da fare"
```
Per ogni **caso** (la lista è in [lab/casi.txt](lab/casi.txt)) `verifica.sh` lancia il tuo script e la soluzione, ciascuno in una **copia nuova della palestra**, con gli stessi argomenti e lo stesso stdin, e confronta:
- l'**output** (stdout), riga per riga
- il **codice d'uscita**
- **se è uscito qualcosa su stderr** (il *testo* dell'errore no: è libero)
- se sono rimasti **file in `TMPDIR`** (per gli script che creano file temporanei)

Un caso sbagliato mostra la differenza (`<` atteso, `>` ottenuto), per esempio per uno script che dimentica di controllare l'esistenza del file:
```
  10  SBAGLIATO
        caso: file mancante   (argomenti: nonesiste.csv 1)
          1c1
          < rc=1
          ---
          > rc=0
```
Si può provare a mano come qualunque script: `bash risposte/01.sh Marco`. La palestra: `testo.txt` (3 righe), `"con spazio.txt"` (2), `vuoto.txt`, `dati.csv`, `parole.txt`, `misto/` (file di varie estensioni), `vuota/`, `flaky.sh`.

## Argomenti e condizioni
**1.** `saluta.sh NOME`: stampa `Ciao NOME!`. Con un nome fatto di più parole **fra virgolette** (`"Anna Maria"`) è un solo argomento. Senza argomenti: un messaggio su **stderr** ed exit **1**.
<details><summary>soluzione</summary>

```bash
[[ $# -ge 1 ]] || { echo "uso: $0 nome" >&2; exit 1; }
echo "Ciao $1!"
# ./saluta.sh "Anna Maria"   ->  Ciao Anna Maria!
```
`$#` è il numero di argomenti ([03-parametri.md](03-parametri.md)); `>&2` manda il messaggio su stderr.
</details>

**2.** `pari.sh N`: stampa `N è pari` o `N è dispari`. Funziona anche con numeri **negativi** (`-3 è dispari`). Se N non è un **intero** (o manca): un messaggio su stderr ed exit **2**.
<details><summary>soluzione</summary>

```bash
[[ ${1:-} =~ ^-?[0-9]+$ ]] || { echo "non è un intero" >&2; exit 2; }
if (( $1 % 2 == 0 )); then echo "$1 è pari"; else echo "$1 è dispari"; fi
```
Senza il controllo `abc` verrebbe valutato come `0` dall'aritmetica di bash e stampato `abc è pari`. `${1:-}` evita l'errore con `set -u` quando manca l'argomento.
</details>

**3.** `somma.sh N...`: stampa la **somma** di tutti gli argomenti (anche negativi); senza argomenti, `0`.
<details><summary>soluzione</summary>

```bash
s=0
for n in "$@"; do s=$((s + n)); done
echo "$s"
# ./somma.sh -5 5 7   ->  7
```
</details>

**4.** `tabellina.sh N`: dieci righe `N x K = R`, per K da 1 a 10 (`3 x 4 = 12`).
<details><summary>soluzione</summary>

```bash
for ((k = 1; k <= 10; k++)); do echo "$1 x $k = $(( $1 * k ))"; done
# ./tabellina.sh 12   ->  12 x 1 = 12 ... 12 x 10 = 120
```
</details>

## Cicli, file e quoting
**5.** `conta-righe.sh FILE...`: per ogni file stampa `FILE: N righe`. Funziona con **nomi con spazi**. Se un file non esiste lo dice su **stderr** (`FILE: non esiste`), **va avanti** con gli altri e alla fine esce con **1** (0 se erano tutti buoni).
<details><summary>soluzione</summary>

```bash
rc=0
for f in "$@"; do
    if [[ -f $f ]]; then
        echo "$f: $(wc -l < "$f") righe"
    else
        echo "$f: non esiste" >&2
        rc=1
    fi
done
exit $rc
# ./conta-righe.sh testo.txt nonesiste.txt vuoto.txt   ->  testo.txt: 3 righe / vuoto.txt: 0 righe, e rc=1
```
`"$@"` e `"$f"` con le virgolette: senza, `con spazio.txt` diventa due file ([10-quoting.md](10-quoting.md)). `wc -l < "$f"` stampa solo il numero (senza il nome del file).
</details>

**6.** `numera.sh`: legge lo **stdin** e stampa ogni riga **numerata e in maiuscolo** (`1: CIAO`). Spazi iniziali e **backslash** restano com'erano; con lo stdin vuoto non stampa niente.
<details><summary>soluzione</summary>

```bash
n=0
while IFS= read -r riga; do
    n=$((n + 1))
    echo "$n: ${riga^^}"
done
# printf '  a\\b  c\n' | ./numera.sh   ->  1:   A\B  C
```
`IFS=` impedisce a `read` di togliere gli spazi iniziali e finali, `-r` di interpretare i backslash ([07-input-read.md](07-input-read.md)). `${riga^^}` mette in maiuscolo senza `tr` ([08-espansioni.md](08-espansioni.md)).
</details>

**7.** `rovescia.sh ARG...`: stampa gli argomenti, **uno per riga**, in ordine **inverso** (`a b c` → `c`, `b`, `a`). Un argomento con spazi resta intero; senza argomenti non stampa **niente** (nemmeno una riga vuota).
<details><summary>soluzione</summary>

```bash
a=("$@")
for ((i = ${#a[@]} - 1; i >= 0; i--)); do echo "${a[i]}"; done
```
`("$@")` copia gli argomenti in un array senza spezzarli; `${#a[@]}` è la lunghezza ([06-array.md](06-array.md)). Con `printf '%s\n' "${r[@]}"` su un array vuoto uscirebbe invece una riga vuota.
</details>

**8.** `frequenze.sh FILE`: per ogni **parola** di FILE (senza distinguere maiuscole/minuscole e senza punteggiatura) una riga `CONTEGGIO PAROLA`, dalla più frequente; **a parità**, in ordine alfabetico. Con `parole.txt` la prima riga è `4 gatto`.
<details><summary>soluzione</summary>

```bash
declare -A c
while read -r p; do
    c[${p,,}]=$(( ${c[${p,,}]:-0} + 1 ))
done < <(tr -s '[:space:][:punct:]' '\n' < "$1" | grep .)
for p in "${!c[@]}"; do echo "${c[$p]} $p"; done | sort -k1,1nr -k2
# 4 gatto
# 4 il
# 2 cane
# 1 dorme
# 1 e
# 1 no
```
`declare -A` è un array associativo (parola → conteggio); `${!c[@]}` ne elenca le chiavi, e **non hanno un ordine**: per questo il `sort`. Il `< <( ... )` evita la sottoshell di una pipe, in cui le modifiche a `c` andrebbero perse ([08-espansioni.md](08-espansioni.md)).
</details>

**9.** `estensioni.sh DIR`: per ogni **estensione** dei file di DIR (solo i file, non le sottocartelle, non quelli nascosti) una riga `.ext CONTEGGIO`, in ordine alfabetico; i file senza estensione sono `(nessuna)`. Con `misto/`: `(nessuna) 1`, `.gz 1`, `.php 1`, `.sh 1`, `.txt 2`.
<details><summary>soluzione</summary>

```bash
declare -A c
for f in "$1"/*; do
    [[ -f $f ]] || continue
    b=${f##*/}
    if [[ $b == *.* ]]; then e=.${b##*.}; else e="(nessuna)"; fi
    c[$e]=$(( ${c[$e]:-0} + 1 ))
done
for e in "${!c[@]}"; do echo "$e ${c[$e]}"; done | sort
```
`${f##*/}` toglie tutto fino all'ultimo `/` (il nome), `${b##*.}` tutto fino all'ultimo `.` (l'estensione). `backup.tar.gz` conta come `.gz`. Il `*` non comprende i file che cominciano per `.`, e con la cartella vuota il ciclo non gira (qui `[[ -f ]]` salta il pattern non espanso).
</details>

**10.** `somma-colonna.sh FILE COLONNA`: somma (interi) la **colonna** COLONNA (da 1) di un CSV con **intestazione**. Con `dati.csv 3` stampa `400`. Se il file manca: messaggio su stderr ed exit **1**.
<details><summary>soluzione</summary>

```bash
[[ -f ${1:-} ]] || { echo "file mancante" >&2; exit 1; }
s=0
{
    read -r _                                  # salta l'intestazione
    while IFS=, read -r -a c; do
        s=$(( s + c[$2 - 1] ))
    done
} < "$1"
echo "$s"
```
Le graffe `{ ...; } < file` fanno leggere **a tutti e due** i `read` dallo stesso file, di seguito: il primo consuma la prima riga. `read -a` mette i campi in un array.
</details>

## Opzioni, funzioni e trap
**11.** `opzioni.sh [-v] [-n NUM] FILE`: stampa `verbose=V num=N file=FILE` (predefiniti `verbose=0` e `num=1`). Funzionano anche le opzioni **raggruppate** (`-vn 5`). Con un'opzione sconosciuta, o senza FILE: messaggio di uso su stderr ed exit **2**. Usa `getopts`.
<details><summary>soluzione</summary>

```bash
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
# ./opzioni.sh -vn 5 file.txt   ->  verbose=1 num=5 file=file.txt
```
Nella stringa `":vn:"` i due punti **dopo** `n` dicono che prende un valore (in `$OPTARG`); quello **iniziale** rende silenziosi gli errori di `getopts` per gestirli nel `case` (`*`). `shift $((OPTIND - 1))` toglie le opzioni lasciando i parametri ([03-parametri.md](03-parametri.md)).
</details>

**12.** `fattoriale.sh N`: stampa N! con una **funzione ricorsiva** (`5` → `120`, `0` → `1`, `10` → `3628800`). Se N non è un intero ≥ 0: messaggio su stderr ed exit **1**.
<details><summary>soluzione</summary>

```bash
fatt() {
    local n=$1
    (( n <= 1 )) && { echo 1; return; }
    echo $(( n * $(fatt $((n - 1))) ))
}
[[ ${1:-} =~ ^[0-9]+$ ]] || { echo "serve un intero >= 0" >&2; exit 1; }
fatt "$1"
```
La funzione **stampa** il risultato e il chiamante lo cattura con `$( )`: in bash `return` restituisce solo un codice da 0 a 255 ([11-funzioni.md](11-funzioni.md)). `local` tiene `n` separata a ogni livello della ricorsione.
</details>

**13.** `temp.sh [errore]`: crea una cartella temporanea con `mktemp -d`, ci scrive un file e stampa `fatto`. Con l'argomento `errore` un comando **fallisce a metà** (con `set -e` lo script esce con 1 senza stampare `fatto`). In **tutti e due** i casi la cartella temporanea deve **sparire**.
<details><summary>soluzione</summary>

```bash
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
echo dati > "$d/dati"
if [[ ${1:-} == errore ]]; then false; fi
echo fatto
```
`trap ... EXIT` esegue il comando **sempre** all'uscita: fine normale, errore con `set -e`, `exit`, o un segnale come `SIGTERM`/`SIGINT` ([12-trap-e-debug.md](12-trap-e-debug.md)). Un `rm -rf` finale **non** basta: se lo script esce prima, non viene eseguito.
`verifica.sh` lancia lo script con `TMPDIR` in una cartella sua e controlla che a fine esecuzione sia vuota.
</details>

**14.** `riprova.sh N COMANDO...`: esegue il comando **fino a N volte**, finché riesce. A ogni giro stampa `tentativo K`; se riesce `riuscito` ed exit **0**, se finisce i tentativi `fallito` ed exit **1**. `flaky.sh` della palestra fallisce le prime due volte.
<details><summary>soluzione</summary>

```bash
max=$1
shift
for ((t = 1; t <= max; t++)); do
    echo "tentativo $t"
    if "$@"; then echo "riuscito"; exit 0; fi
done
echo "fallito"
exit 1
# ./riprova.sh 5 ./flaky.sh   ->  tentativo 1 / 2 / 3 / riuscito
# ./riprova.sh 2 ./flaky.sh   ->  tentativo 1 / 2 / fallito   (rc=1)
```
`shift` toglie N e lascia in `"$@"` il comando con i suoi argomenti, da eseguire con `"$@"` (con le virgolette). Il `if` usa direttamente il codice d'uscita del comando ([05-cicli.md](05-cicli.md) ha un esempio di *retry*).
</details>

**15.** `esiste.sh PERCORSO`: un **file regolare** stampa `file` (exit **0**), una **cartella** `directory` (exit **1**); se non esiste: messaggio su stderr (`non esiste: PERCORSO`) ed exit **2**.
<details><summary>soluzione</summary>

```bash
p=${1:-}
if [[ -f $p ]]; then
    echo file
elif [[ -d $p ]]; then
    echo directory
    exit 1
else
    echo "non esiste: $p" >&2
    exit 2
fi
```
I test `-f` e `-d` sono in [04-condizioni.md](04-condizioni.md). I codici d'uscita diversi permettono a chi chiama lo script di distinguere i tre casi con `$?`.
</details>

**16.** `args.sh ARG...`: stampa `N argomenti:` e poi ogni argomento **fra parentesi quadre**, uno per riga, anche se contiene spazi o è **vuoto** (`a "b c" d` → `3 argomenti:`, `[a]`, `[b c]`, `[d]`).
<details><summary>soluzione</summary>

```bash
echo "$# argomenti:"
for a in "$@"; do echo "[$a]"; done
# ./args.sh "" x   ->  2 argomenti: / [] / [x]
```
`"$@"` con le virgolette conserva ogni argomento com'è, vuoti compresi; senza (`$@` o `$*`) un argomento con spazi diventa più parole e uno vuoto sparisce. È la differenza più importante di [10-quoting.md](10-quoting.md).
</details>

## Se non sai da dove cominciare
| Devi... | Costrutto |
|---|---|
| leggere gli argomenti | `$1`, `$2`, `"$@"`, `$#`; `shift` |
| uscire con un errore | `echo "..." >&2; exit N` |
| controllare un file o un numero | `[[ -f $f ]]`, `[[ $n =~ ^[0-9]+$ ]]`, `(( n % 2 == 0 ))` |
| ripetere | `for f in "$@"`, `for ((i=0; i<n; i++))`, `while read -r riga` |
| tenere un elenco o contare | array `a=("$@")`, associativo `declare -A c` |
| leggere un file riga per riga | `while IFS= read -r riga; do ...; done < file` |
| opzioni `-v -n 3` | `getopts ":vn:" o` |
| pulire sempre | `trap '...' EXIT` |
| spezzare un valore in campi | `IFS=, read -r -a campi` |

Torna all'[indice dell'area](README.md)
