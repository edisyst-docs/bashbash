# Makefile di esempio per 08-make.md: un piccolo "progetto" di script e testi.
# Le righe dei comandi cominciano con un TAB, non con spazi.
# I commenti stanno su righe a sé: un commento a fine di un'assegnazione lascia gli spazi nel valore,
# e uno a fine di un comando viene passato alla shell (e stampato).

SHELL := /bin/bash
# senza argomenti, "make" mostra l'aiuto invece di costruire qualcosa
.DEFAULT_GOAL := help

NOME := demo
# $(shell ...) esegue un comando e ne prende l'output
VERSIONE := $(shell date +%Y.%m.%d)
# tutti i file src/*.txt, e per ognuno il suo risultato: src/uno.txt -> build/uno.upper
SORGENTI := $(wildcard src/*.txt)
FINALI := $(patsubst src/%.txt,build/%.upper,$(SORGENTI))
PACCHETTO := dist/$(NOME)-$(VERSIONE).tar.gz

# target che non sono file: vanno eseguiti sempre
.PHONY: help all test lint dist clean

help:  ## mostra questo aiuto
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

all: $(FINALI)  ## costruisce tutto

# regola a schema: come si ottiene build/X.upper da src/X.txt
# $< è il primo prerequisito, $@ il target
build/%.upper: src/%.txt
	@mkdir -p build
	tr '[:lower:]' '[:upper:]' < $< > $@

test:  ## esegue i test (bats)
	bats test.bats

lint:  ## controlla lo script con shellcheck
	shellcheck saluta.sh

dist: $(PACCHETTO)  ## crea il pacchetto in dist/

# $^ è l'elenco di tutti i prerequisiti
$(PACCHETTO): $(FINALI) saluta.sh
	@mkdir -p dist
	tar -czf $@ $^
	@echo "creato $@"

clean:  ## cancella build/ e dist/
	rm -rf build dist
