# bats: testare gli script bash

> **Laboratorio**: `./lab.sh 09`, poi `cd 09-bats`. File pronti: `saluta.sh`, `test.bats`, `stato.sh`, `stato.bats` (da [lab/materiale/](lab/materiale/)).

Uno script che "sembra funzionare" si rompe alla prima modifica. **bats** (*Bash Automated Testing System*) è il modo più semplice di scrivere test per script bash: un file `.bats` con una serie di `@test`, ognuno dei quali
passa se tutti i suoi comandi riescono. Gli esempi sono stati eseguiti con Bats 1.10 e `bats-assert` 2.1 nel laboratorio.
```bash
bats --version           # Bats 1.10.0
```
Con `apt install bats bats-assert bats-support` (già nell'immagine del laboratorio). Si affianca a [shellcheck](../05-scripting/): `shellcheck` controlla **come è scritto** lo script, `bats` controlla **cosa fa**.

## Un test
Un test è una funzione con un nome in chiaro. Passa se **ogni comando** al suo interno esce con 0 (bash è eseguito con `set -e`):
```bash
#!/usr/bin/env bats

@test "senza argomenti saluta il mondo" {
    run ./saluta.sh
    [ "$status" -eq 0 ]
    [ "$output" = "ciao mondo" ]
}
```
`run` esegue un comando **senza far fallire il test** se esce con un errore, e salva il risultato in tre variabili:

| Variabile | Contenuto |
|---|---|
| `$status` | il codice d'uscita |
| `$output` | l'output (stdout e stderr insieme) |
| `${lines[@]}` | lo stesso output, **riga per riga** (`${lines[0]}`, `${#lines[@]}` per quante) |

Un'asserzione è una qualunque condizione che fallisce: `[ ... ]`, `[[ ... ]]`, `grep -q`, `test -f file`.
```bash
bats test.bats
# 1..8
# ok 1 senza argomenti saluta il mondo
# ok 2 con un nome lo saluta (assert_output)
# ...
# ok 8 un test saltato # skip esempio di skip
```
L'output è il formato **TAP** (*Test Anything Protocol*): `ok N nome` o `not ok N nome`. Il codice d'uscita di `bats` è 0 se tutti passano, `1` se uno fallisce: è ciò che serve a `make test` e alla CI.

## Lo script da testare
Per testare le **funzioni** di uno script, lo script deve poter essere incluso con `source` senza partire. Lo schema è questa guardia finale:
```bash
saluto() { printf 'ciao %s\n' "${1:-mondo}"; }

main() { ...; saluto "${1:-}"; }

# main parte solo se lo script è eseguito, non se è incluso con "source"
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
```
```bash
@test "la funzione saluto, chiamata direttamente con source" {
    source "$BATS_TEST_DIRNAME/saluta.sh"
    run saluto Marco
    assert_output "ciao Marco"
}
```
`$BATS_TEST_DIRNAME` è la cartella del file `.bats`: così i test funzionano da qualunque cartella.

## bats-assert: messaggi di errore utili
`[ "$output" = "x" ]` quando fallisce dice solo `failed`. Le librerie **bats-support** e **bats-assert** danno asserzioni che spiegano **perché**:
```bash
setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
}

@test "con un nome lo saluta" {
    run ./saluta.sh Anna
    assert_success                      # status 0
    assert_output "ciao Anna"           # output uguale
}
```
Un test **che fallisce** mostra la differenza:
```
not ok 2 assert_output
# (in test file falliti.bats, line 8)
#   `assert_output "arrivederci"' failed
#
# -- output differs --
# expected : arrivederci
# actual   : ciao
# --
not ok 3 stato
#   `assert_success' failed
# -- command failed --
# status : 1
# output :
not ok 4 partial
#   `assert_output --partial "breve"' failed
# -- output does not contain substring --
# substring : breve
# output    : un testo lungo
```
| Asserzione | Verifica |
|---|---|
| `assert_success`, `assert_failure [N]` | il codice d'uscita (0, o diverso da 0, o proprio `N`) |
| `assert_output "x"` | l'output intero è uguale a `x` |
| `assert_output --partial "x"` | contiene `x` |
| `assert_output --regexp 'REGEX'` | corrisponde alla regex |
| `assert_line "x"`, `assert_line --index 1 "x"` | una riga dell'output (o la riga numero N) |
| `refute_output`, `refute_line` | l'opposto: **non** c'è |
| `assert_equal a b` | due valori uguali |

## stderr, codici d'uscita e `run` con opzioni
```bash
bats_require_minimum_version 1.5.0     # serve per le opzioni di run

@test "un'opzione sconosciuta fallisce con 2 e scrive su stderr" {
    run --separate-stderr ./saluta.sh --boh
    assert_failure 2
    [ -z "$output" ]                                    # su stdout niente
    [[ $stderr == *"opzione sconosciuta: --boh"* ]]    # l'errore su stderr
}

@test "un comando che non esiste esce con 127" {
    run -127 comandoinesistente         # run -N: il test passa solo se lo status è N
}
```
Senza `bats_require_minimum_version` le opzioni di `run` stampano un avviso (`BW02`). E un `run` su un comando che non esiste (127) senza `-127` avvisa (`BW01`): bats pensa che sia un errore di battitura.

## setup, teardown e cartelle temporanee
```bash
setup()         { ... }          # prima di OGNI test
teardown()      { ... }          # dopo ogni test, anche se è fallito
setup_file()    { ... }          # una volta, prima di tutti i test del file
teardown_file() { ... }          # una volta, alla fine
@test "usa una cartella temporanea" {
    echo dati > "$BATS_TEST_TMPDIR/f.txt"      # una cartella nuova per ogni test, cancellata da bats
    run cat "$BATS_TEST_TMPDIR/f.txt"
    assert_output "dati"
}
```
Quello che un test **stampa** non si vede se passa. Per un messaggio durante i test si scrive sul **file descriptor 3**: `echo "# messaggio" >&3` (la riga comincia con `#`, perché TAP la tratti come commento).
`skip "motivo"` salta un test (`ok 8 ... # skip esempio di skip`).

## Un finto comando: testare senza la rete
Uno script che chiama `curl`, `docker` o `date` non si può testare in modo ripetibile con i comandi veri. Si mette un **finto comando in testa al `PATH`**, e lo script userà quello:
```bash
# stato.sh URL: stampa "su" se curl riceve 200, altrimenti "giù (CODICE)" ed esce con 1
codice=$(curl -s -o /dev/null -w '%{http_code}' "$1")
```
```bash
setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"          # il curl finto vince su quello vero
}
finto_curl() {
    printf '#!/bin/sh\necho %s\n' "$1" > "$BATS_TEST_TMPDIR/bin/curl"
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
}
@test "503 -> giù, e esce con 1" {
    finto_curl 503
    run "$BATS_TEST_DIRNAME/stato.sh" http://esempio
    [ "$status" -eq 1 ]
    [ "$output" = "giù (503)" ]
}
```
```bash
bats stato.bats
# 1..3
# una volta sola, prima di tutti i test
# ok 1 200 -> su
# ok 2 503 -> giù, e esce con 1
# ok 3 un comando che non esiste esce con 127
# una volta sola, alla fine
```
Il `PATH` modificato vale solo dentro quel test.

## Lanciare i test
```bash
bats test.bats                  # un file
bats tests/                     # tutti i .bats di una cartella
bats -r .                       # ricorsivo
bats -f maiuscolo test.bats     # solo i test il cui nome contiene "maiuscolo"
bats -c test.bats               # quanti test ci sono, senza eseguirli (8)
bats -T test.bats               # con i tempi: ok 1 senza argomenti saluta il mondo in 36ms
bats --formatter junit test.bats   # il risultato come XML JUnit, per la CI
bats --tap test.bats            # il TAP puro
```
I percorsi relativi dentro un test (`./stato.sh`) dipendono dalla cartella da cui si lancia `bats`: con `$BATS_TEST_DIRNAME` il test funziona da dovunque, anche con `bats -r .` da una cartella sopra.

## Dentro il progetto
Il `Makefile` ([08-make.md](08-make.md)) dà un nome corto: `make test` lancia `bats test.bats`, e il passaggio successivo è la CI:
```yaml
# .github/workflows/test.yml
- run: sudo apt-get install -y bats bats-assert bats-support shellcheck
- run: make lint test
```

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `bats_load_safe: Could not find '/usr/lib/bats/bats-support/load'` | `bats-support`/`bats-assert` non installati | `apt install bats-support bats-assert` |
| un test passa anche se dovrebbe fallire | `run` non fa fallire il test: manca l'asserzione sullo `$status` | aggiungere `[ "$status" -eq 0 ]` o `assert_success` |
| un test fallisce solo con `bats` e non a mano | l'ambiente è diverso (`PATH`, cartella corrente, variabili) | `$BATS_TEST_DIRNAME`, percorsi assoluti, `setup` esplicito |
| `BW01: run's command exited with code 127` | comando non trovato (nome o percorso sbagliato) | correggere il comando, o `run -127` se è voluto |
| `BW02: Using flags on run requires at least BATS_VERSION=1.5.0` | opzioni di `run` senza dichiarare la versione | `bats_require_minimum_version 1.5.0` |
| lo script parte durante `source` nel test | manca la guardia `[[ ${BASH_SOURCE[0]} == "$0" ]]` | `main` solo se eseguito |
| `$output` contiene anche gli errori | `run` unisce stdout e stderr | `run --separate-stderr` e `$stderr` |
| il messaggio `echo` di un test non si vede | l'output dei test che passano è nascosto | `echo "# ..." >&3` |

Torna all'[indice dell'area](README.md)
