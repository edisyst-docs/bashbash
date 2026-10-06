#!/usr/bin/env bash
# 04 - tabellina.sh N: dieci righe "N x K = R"
for ((k = 1; k <= 10; k++)); do echo "$1 x $k = $(( $1 * k ))"; done
