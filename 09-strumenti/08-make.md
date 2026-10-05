# make e Makefile

> **Laboratorio**: `./lab.sh 09`, poi `cd 08-make`. File pronti: [lab/materiale/make/](lab/materiale/make/).

`make` esegue **compiti** descritti in un file `Makefile`, e li esegue **solo se serve**: ogni compito dice da quali file dipende, e `make` lo rifà soltanto se uno di quei file è più recente del risultato.
Nato per compilare programmi C, oggi è il modo più diffuso di dare un nome corto ai comandi di un progetto (`make test`, `make deploy`), e nei progetti di ogni linguaggio è il punto di ingresso che
un nuovo arrivato prova per primo. Gli esempi sono stati eseguiti con GNU Make 4.3 nel laboratorio.

## La regola
```make
target: prerequisiti
	comando
```
- il **target** è di solito un file da produrre (o un nome di compito, vedi `.PHONY`)
- i **prerequisiti** sono i file da cui dipende
- il **comando** è quello che lo produce, e **comincia con un TAB**, non con spazi

```make
saluto.txt: nome.txt
	echo "ciao $$(cat nome.txt)" > saluto.txt
```
`make saluto.txt` lo costruisce; rilanciato, dice `make: 'saluto.txt' is up to date.` e non fa nulla, finché `nome.txt` non cambia. È l'idea di tutto: **ricostruire solo quello che è cambiato**.

> Il TAB è il primo inciampo: con otto spazi al posto del TAB, `make` dà `Makefile:2: *** missing separator.  Stop.` Gli editor vanno impostati perché nei `Makefile` non trasformino i TAB in spazi.

## Il Makefile del laboratorio
In [lab/materiale/make/Makefile](lab/materiale/make/Makefile) c'è un progetto minuscolo: tre file di testo in `src/` da convertire in maiuscolo in `build/`, uno script `saluta.sh`, i suoi test e un pacchetto finale.
```bash
cd ~/lab/08-make
make                    # senza argomenti: parte il target predefinito, qui "help"
#   make help     mostra questo aiuto
#   make all      costruisce tutto
#   make test     esegue i test (bats)
#   make lint     controlla lo script con shellcheck
#   make dist     crea il pacchetto in dist/
#   make clean    cancella build/ e dist/
make all
# tr '[:lower:]' '[:upper:]' < src/due.txt > build/due.upper
# tr '[:lower:]' '[:upper:]' < src/tre.txt > build/tre.upper
# tr '[:lower:]' '[:upper:]' < src/uno.txt > build/uno.upper
make all                # make: Nothing to be done for 'all'.
touch src/due.txt
make all                # rifà SOLO build/due.upper: è l'unico con un prerequisito più nuovo
```
Per default `make` **stampa ogni comando** prima di eseguirlo (un `@` davanti lo nasconde: `@mkdir -p build`).

## Variabili
```make
NOME := demo                          # := valuta subito
VERSIONE := $(shell date +%Y.%m.%d)   # $(shell ...) prende l'output di un comando
SORGENTI := $(wildcard src/*.txt)     # i file che corrispondono: src/due.txt src/tre.txt src/uno.txt
FINALI := $(patsubst src/%.txt,build/%.upper,$(SORGENTI))   # sostituisce lo schema: build/due.upper ...
```
Si usano con `$(NOME)`. Si possono **sovrascrivere dalla riga di comando**, ed è il modo di parametrizzare:
```bash
make NOME=altro dist
# tar -czf dist/altro-2026.10.05.tar.gz build/due.upper build/tre.upper build/uno.upper saluta.sh
# creato dist/altro-2026.10.05.tar.gz
```
| Operatore | Significato |
|---|---|
| `:=` | assegna **subito** il valore (quasi sempre quello che serve) |
| `=` | valuta ogni volta che la variabile è **usata** (ricorsiva: più lenta e sorprendente) |
| `?=` | assegna solo se la variabile **non è già** impostata (nemmeno dall'ambiente): `PORTA ?= 8080` |
| `+=` | aggiunge: `CFLAGS += -Wall` |

Le variabili dell'**ambiente** della shell sono visibili in `make`; quelle dalla riga di comando (`make X=1`) hanno la precedenza sul `Makefile`.

> **Un commento a fine riga lascia gli spazi nel valore.** `V := a   # commento` produce `a` seguito dagli spazi che c'erano prima del `#`: `echo "[$(V)]"` stampa `[a   ]`. Dove il valore è usato per costruire un percorso
> (`dist/$(NOME)-$(VERSIONE).tar.gz`) il risultato diventa **due parole** e `tar` crea un file di nome `.tar.gz`. I commenti si scrivono su righe a sé.

### Variabili automatiche
Dentro un comando, `make` sa già di cosa si sta occupando:

| Variabile | Contenuto |
|---|---|
| `$@` | il **target** |
| `$<` | il **primo** prerequisito |
| `$^` | **tutti** i prerequisiti |
| `$*` | la parte che corrisponde al `%` in una regola a schema |

### Regole a schema
```make
# come si ottiene build/X.upper da src/X.txt, per ogni X
build/%.upper: src/%.txt
	@mkdir -p build
	tr '[:lower:]' '[:upper:]' < $< > $@
```
Una regola sola vale per tutti i file: `make build/uno.upper` la usa con `X=uno`.

## `.PHONY`: i target che non sono file
`clean`, `test`, `all` non producono un file con quel nome. Se un giorno esistesse un file `test` nella cartella, `make test` direbbe che è già aggiornato e non farebbe niente. `.PHONY` dice a `make` di eseguirli **sempre**:
```make
.PHONY: help all test lint dist clean
```

## Un aiuto che si scrive da solo
Il trucco più usato: un commento `##` a fianco del target, e un target `help` che li elenca.
```make
help:  ## mostra questo aiuto
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'
.DEFAULT_GOAL := help
```
`.DEFAULT_GOAL` è il target di `make` senza argomenti (altrimenti è il **primo** del file). Il `$$` serve per passare un `$` vero ad `awk`, perché `make` ne consuma uno.

## Capire cosa fa, prima di farlo
```bash
make -n all             # -n (dry run): stampa i comandi senza eseguirli
# mkdir -p build
# tr '[:lower:]' '[:upper:]' < src/due.txt > build/due.upper
# ...
make -B all             # -B: ricostruisce tutto, come se ogni file fosse cambiato
make -j3 all            # -j N: fino a N comandi in parallelo (le dipendenze sono rispettate)
make -s test            # -s: silenzioso, senza stampare i comandi
make -f altro.mk target # un file diverso da Makefile
make -C cartella target # entra nella cartella, poi lavora lì
make -k all             # -k: continua con gli altri target anche dopo un errore
```
Il parallelismo vale per i target **indipendenti**: con `-j3`, tre `build/*.upper` partono insieme.

## Errori e cosa significano
```bash
make nonesiste
# make: *** No rule to make target 'nonesiste'.  Stop.         <- nessun file e nessuna regola con quel nome
```
Un comando che esce con un codice diverso da 0 **ferma tutto**:
```make
all:
	false
	@echo mai
# false
# make: *** [Makefile:2: all] Error 1          <- lo "echo mai" non parte, e make esce con 2
```
Con un `-` davanti al comando l'errore è **ignorato**:
```make
all:
	echo visibile
	@echo nascosto
	-false
	@echo dopo-errore-ignorato
# echo visibile
# visibile
# nascosto
# false
# make: [Makefile:4: all] Error 1 (ignored)
# dopo-errore-ignorato
```

### Ogni riga di comando è una shell diversa
```make
sbagliato:
	cd src
	pwd            # è ancora la cartella di prima: il "cd" è finito con la sua shell
giusto:
	cd src && pwd
```
Anche le variabili della shell non passano da una riga all'altra: `x=1` su una riga e `echo $$x` sulla successiva non funzionano (`.ONESHELL:` fa eseguire tutta la ricetta in un'unica shell). Nei comandi il `$` della shell va
**raddoppiato**: `echo $$x`.

## Un Makefile di tutti i giorni
Per un progetto qualunque (qui uno in Python), con i compiti che si ripetono:
```make
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help venv test lint run clean

help:  ## mostra questo aiuto
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

venv: requirements.txt  ## crea o aggiorna l'ambiente virtuale
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt
	touch venv

test: venv  ## esegue i test
	.venv/bin/pytest -q

lint:  ## controlla il codice
	shellcheck scripts/*.sh

run: venv  ## avvia l'applicazione
	.venv/bin/python app.py

clean:  ## cancella i file generati
	rm -rf .venv build dist venv
```
`venv: requirements.txt` con `touch venv` alla fine usa un file "segnaposto": l'ambiente si rifà soltanto se `requirements.txt` è cambiato. (Questo esempio è lo schema; il `Makefile` provato è quello del laboratorio.)

## `make` in un progetto vero
- `make test` e `make lint` sono anche la **fonte unica** per la CI: il workflow di GitHub Actions ([../11-container-e-automazione/13-github-actions/](../11-container-e-automazione/13-github-actions/)) chiama `make test` invece di ripetere i comandi
- `include altro.mk` (e `-include` che ignora un file mancante) divide un Makefile grande; `.env` si legge con `include .env` ed `export`
- per i comandi di un progetto **senza** compilazione esistono alternative più moderne (`just`, `task`): stessa idea, sintassi senza TAB. `make` però c'è già ovunque
- in `Dockerfile`, `Makefile` e script, le stesse ricette si possono usare anche per le immagini: `docker build` dentro un target

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `*** missing separator.  Stop.` | spazi al posto del TAB nel comando | un TAB vero all'inizio della riga |
| `No rule to make target 'X'` | il file o il target non esiste (o errore di battitura) | `make -n X`, controllare il nome e la cartella |
| `'X' is up to date.` ma non è vero | esiste un file chiamato come il target | `.PHONY: X` |
| un comando riesegue sempre tutto | un prerequisito è sempre più nuovo (data del file nel futuro, o un file che il comando non crea) | `ls -l --time-style=full-iso`, e il target deve **creare** il file che dichiara |
| una variabile ha uno spazio di troppo | commento a fine riga dopo un'assegnazione | il commento su una riga a sé |
| `cd` non ha effetto sulla riga dopo | ogni riga è una shell | `cd dir && comando`, oppure `.ONESHELL:` |
| `$HOME` o `$x` non funzionano nel comando | `make` consuma il `$` | `$$HOME`, `$$x` |
| `make: *** [Makefile:N: target] Error 1` | il comando alla riga N è uscito con errore | leggere il comando stampato subito sopra |

Torna all'[indice dell'area](README.md)
