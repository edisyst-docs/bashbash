#!/usr/bin/env bats
# stato.bats - testa stato.sh senza la rete, con un finto curl. Si lanciano con:  bats stato.bats

bats_require_minimum_version 1.5.0

# gira una volta sola, prima di tutti i test del file. Il file descriptor 3 mostra i messaggi anche se i test passano
setup_file() {
    echo "# una volta sola, prima di tutti i test" >&3
}

setup() {
    # un curl finto in testa al PATH: stato.sh userà lui invece di quello vero
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# crea il finto curl, che stampa il codice che gli si chiede
finto_curl() {
    printf '#!/bin/sh\necho %s\n' "$1" > "$BATS_TEST_TMPDIR/bin/curl"
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
}

@test "200 -> su" {
    finto_curl 200
    run "$BATS_TEST_DIRNAME/stato.sh" http://esempio
    [ "$status" -eq 0 ]
    [ "$output" = "su" ]
}

@test "503 -> giù, e esce con 1" {
    finto_curl 503
    run "$BATS_TEST_DIRNAME/stato.sh" http://esempio
    [ "$status" -eq 1 ]
    [ "$output" = "giù (503)" ]
}

@test "un comando che non esiste esce con 127" {
    run -127 comandoinesistente
}

teardown_file() {
    echo "# una volta sola, alla fine" >&3
}
