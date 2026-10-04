# Rubrica

Rubrica telefonica interattiva in bash: funzioni, `case`, `select`, lettura e scrittura di un file con un record per riga.

| File | Contenuto |
|---|---|
| [rubrica.sh](rubrica.sh) | Lo script principale, con il menu |
| [recordInsert.sh](recordInsert.sh) | Inserimento di un record |
| [patternSelect.sh](patternSelect.sh) | Ricerca dei record per pattern |
| [patternDelete.sh](patternDelete.sh) | Eliminazione dei record per pattern |
| `.rubrica` | Il file dati di esempio, un record per riga con i campi separati da `\|` |

`rubrica.sh` cerca i dati in `~/rubrica/.rubrica` (variabile `RUBRICA` in cima allo script). Per provarlo da qui:
```bash
mkdir -p ~/rubrica && cp .rubrica ~/rubrica/
bash rubrica.sh
```

Torna a [../](../)
