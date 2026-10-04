# zz - Esempi

Script completi e funzionanti, a differenza degli appunti-in-forma-di-codice che stanno
dentro [../05-scripting/](../05-scripting/). Non fanno parte del percorso numerato: sono
materiale da leggere quando vuoi vedere i costrutti applicati a un problema intero.

## [rubrica/](rubrica/)
Rubrica telefonica interattiva in bash. Mostra funzioni, `case`, `select`, lettura e
scrittura su un file con record separati da `|`.

| File | Contenuto |
|---|---|
| [rubrica.sh](rubrica/rubrica.sh) | Script principale con il menu |
| [recordInsert.sh](rubrica/recordInsert.sh) | Inserimento di un record |
| [patternSelect.sh](rubrica/patternSelect.sh) | Ricerca dei record per pattern |
| [patternDelete.sh](rubrica/patternDelete.sh) | Eliminazione dei record per pattern |
| `.rubrica` | Il file dati di esempio |

> **NOTA**: `rubrica.sh` cerca il file dati in `~/rubrica/.rubrica`. Per farlo girare da qui
> va copiato `.rubrica` in quella posizione, oppure va modificata la variabile `RUBRICA`
> in cima allo script.

## [esercizi/](esercizi/)
Esercizi di scripting, ognuno con l'enunciato nei commenti in cima al file e un esempio d'uso.

| File | Contenuto |
|---|---|
| [base2.sh](esercizi/base2.sh) | Converte un intero da base 10 a base 2 |
| [toupper.sh](esercizi/toupper.sh) | Converte in maiuscolo i nomi passati come argomento |
| [removeblanklines.sh](esercizi/removeblanklines.sh) | Rimuove le righe vuote da una lista di file |
| [include.sh](esercizi/include.sh) | Trova gli `#include` locali e globali in un sorgente C |
| [spaziodisco.sh](esercizi/spaziodisco.sh) | Lista ordinata per dimensione dei file di una directory |

Torna all'[indice](../README.md)
