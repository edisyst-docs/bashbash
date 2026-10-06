# Rubrica

> **Laboratorio**: `./lab.sh zz-esempi`, poi `cd rubrica`. I dati sono già in `~/rubrica/.rubrica`; `../esercizi/verifica.sh` prova lo script con 10 casi. Dettagli in [../lab/](../lab/).

Rubrica telefonica interattiva in bash: funzioni, `case`, `select`, lettura e scrittura di un file con un record per riga.

| File | Contenuto |
|---|---|
| [rubrica.sh](rubrica.sh) | Lo script principale, con il menu e le opzioni `-h -i -d -f` |
| [recordInsert.sh](recordInsert.sh) | Inserimento di un record |
| [patternSelect.sh](patternSelect.sh) | Ricerca dei record per pattern |
| [patternDelete.sh](patternDelete.sh) | Eliminazione dei record per pattern |
| `.rubrica` | Il file dati di esempio, un record per riga con i campi separati da `\|` |

`rubrica.sh` cerca i dati in `~/rubrica/.rubrica` (variabile `RUBRICA` in cima allo script). Senza il laboratorio, per provarlo da qui:
```bash
mkdir -p ~/rubrica && cp .rubrica ~/rubrica/
bash rubrica.sh
```

## Dalla riga di comando
```bash
./rubrica.sh -f marco                       # cerca (senza distinguere maiuscole/minuscole)
# Record selezionati: 2
#
#     Nome: Marco
#  Cognome: Liverani
# Telefono: 06 123 456
#   E-mail: m.liverani@aquilante.net
# ...
./rubrica.sh -i Anna Rossi 333 a.rossi@example.com
# Inserito record n. 6
./rubrica.sh -i "Maria Chiara" Verdi "06 111 222" mc@example.com    # gli spazi vanno fra virgolette: sono un solo campo
./rubrica.sh -d "06 111"                    # elimina i record che contengono la stringa
# Record eliminati: 1
./rubrica.sh -d                             # senza filtro: rifiuta (e non cancella niente)
# ./rubrica.sh: ERRORE: non e' stato specificato nessun filtro
./rubrica.sh -f ''                          # stringa vuota: li mostra tutti
```
Con `./rubrica.sh` senza opzioni parte il menu (`select`): 1 inserimento, 2 eliminazione, 3 ricerca, 4 uscita. Un'opzione inesistente dà `ERRORE: opzione non prevista`.

## Cosa è stato corretto provandolo
Il codice originale funzionava sull'esempio, ma nel laboratorio si sono visti questi difetti (ora corretti, e coperti da `verifica.sh`):

| Difetto | Effetto | Correzione |
|---|---|---|
| il file `.rubrica` non finiva con un a capo | il primo record inserito si **attaccava** all'ultimo: `...pippo.itAnna\|Rossi\|...` | a capo finale nel file |
| `recordInsert $2 $3 $4 $5` senza virgolette | `"Maria Chiara"` diventava due argomenti: il record era `Maria\|Chiara\|Verdi\|06` | `"$2" "$3" "$4" "$5"` |
| `echo "Inserito record n. $(wc -l $RUBRICA \| cut -c 1-8)"` | stampava anche l'inizio del percorso: `Inserito record n. 5 /root/` | `wc -l < "$RUBRICA"` |
| `grep $filtro $RUBRICA` senza virgolette né `-F` | `-d "06 111"` cercava `06` nei file `111` e la rubrica, e cancellava **2** record invece di 1; il filtro era una regex (`M.rco` trovava `Marco`) | `grep -F -- "$filtro" "$RUBRICA"` |
| filtro vuoto in `-f` / ricerca | `grep -i` leggeva il percorso come pattern e restava in attesa su stdin | la stringa vuota è un pattern valido: mostra tutti |
| `exit 1` dentro `patternDelete` | dal menu, premere Invio alla richiesta di eliminazione **chiudeva il programma** | `return 1` (e `exit 1` solo nella modalità da riga di comando) |
| `IFS` modificato in `patternSelect` | restava `\|` anche dopo la funzione | `local IFS=$IFS` |

Il filtro cerca la stringa in **qualunque campo**, anche come parte di una parola: `-d Mar` toglie tutti i record con `Marco` (e anche `Mario` o `Maria`, se ci fossero). Per questo il commento originale ("esattamente quella stringa") è stato corretto.

Torna a [../](../)
