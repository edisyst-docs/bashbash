#!/usr/bin/env bats
# test.bats - i test di saluta.sh. Si lanciano con:  bats test.bats   (o  make test)

bats_require_minimum_version 1.5.0     # serve per le opzioni di "run", come --separate-stderr

# setup gira prima di OGNI test, teardown dopo; $BATS_TEST_TMPDIR è una cartella nuova per ogni test
setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
    SCRIPT="$BATS_TEST_DIRNAME/saluta.sh"
}

@test "senza argomenti saluta il mondo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$output" = "ciao mondo" ]
}

@test "con un nome lo saluta (assert_output)" {
    run "$SCRIPT" Anna
    assert_success
    assert_output "ciao Anna"
}

@test "--maiuscolo mette il testo in maiuscolo" {
    run "$SCRIPT" --maiuscolo Anna
    assert_success
    assert_output "CIAO ANNA"
}

@test "un'opzione sconosciuta fallisce con 2 e scrive su stderr" {
    run --separate-stderr "$SCRIPT" --boh
    assert_failure 2
    [ -z "$output" ]
    [[ $stderr == *"opzione sconosciuta: --boh"* ]]
}

@test "la funzione saluto, chiamata direttamente con source" {
    source "$SCRIPT"
    run saluto Marco
    assert_output "ciao Marco"
}

@test "output su più righe: grep sul risultato" {
    run bash -c "printf 'a\nb\nc\n'"
    assert_line --index 1 "b"
    assert_output --partial "c"
    [ "${#lines[@]}" -eq 3 ]
}

@test "usa una cartella temporanea" {
    echo "dati" > "$BATS_TEST_TMPDIR/f.txt"
    run cat "$BATS_TEST_TMPDIR/f.txt"
    assert_output "dati"
}

@test "un test saltato" {
    skip "esempio di skip"
    false
}
