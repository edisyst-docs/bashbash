# Help e manuali

> **Laboratorio**: `./lab.sh 01`, poi `cd 03-help-e-manuali`. L'immagine del laboratorio ha le pagine di manuale installate (quella base di Ubuntu le toglie: vedi la nota in fondo).

Come trovare il comando giusto e leggerne la documentazione senza uscire dal terminale.

## Cercare il comando che serve
```bash
apropos copy     # cerca in tutti gli helper la parola "copy" per trovare il comando che serve
# cp (1)               - copy files and directories
# cpgr (8)             - copy with locking the given file to the password or gr...
# cppw (8)             - copy with locking the given file to the password or gr...
whatis ls        # cosa fa il comando ls
# ls (1)               - list directory contents

man -k YAML YML  # cerca in tutti i man le parole YAML oppure YML
apropos YAML YML # UGUALE
# YAML: nothing appropriate.        <- nessuna pagina di manuale installata parla di YAML
```
Il numero fra parentesi è la **sezione** del manuale: `1` comandi, `5` formati dei file (`man 5 crontab`), `8` amministrazione di sistema. `apropos` e `whatis` leggono un indice (`mandb`):
se è vuoto o vecchio rispondono `nothing appropriate` anche per comandi che ci sono.

## Dove si trova un eseguibile
```bash
which ls    # dove si trova l'eseguibile di ls, in quale folder
# /usr/bin/ls
whereis ls  # dove si trovano l'eseguibile e il manuale di ls
# ls: /usr/bin/ls /usr/share/man/man1/ls.1.gz

echo $PATH        # elenca le cartelle in cui la shell cerca gli eseguibili (usato da which e whereis)
PATH=$PATH:/opt/  # aggiungo /opt/ ai percorsi di $PATH
```
`PATH=$PATH:/opt/` vale solo per la shell corrente e per i suoi figli; per renderlo permanente va nel `~/.profile` ([09-file-di-avvio.md](09-file-di-avvio.md)).

## I quattro livelli di documentazione
```bash
ls --help  # helper sintetico del comando
man ls     # helper più dettagliato: ls è un comando esterno a bash, pertanto ha il man
info ls    # helper ancora più dettagliato
help cd    # cd è una funzionalità di bash, non un comando esterno come ls, pertanto ha l'help e non il man
```
Nel `man` si scorre con le frecce o `Spazio`, si cerca con `/parola` (poi `n` per la successiva), si esce con `q`. `man -k` e `man -f` sono le forme lunghe di `apropos` e `whatis`.

> **NOTA**: la distinzione `man` / `help` dipende da dove vive il comando. I builtin di bash
> (`cd`, `export`, `alias`, `type`) si documentano con `help`, tutto il resto con `man`.
> Per capire in quale categoria ricade un comando, vedi [05-alias.md](05-alias.md) e il comando `type`.

> **NOTA - nei container**: le immagini Docker di Ubuntu sono *minimizzate*: `dpkg` scarta le pagine di manuale, e `man ls` stampa solo
> `This system has been minimized by removing packages and content that are not required on a system that users do not log into`.
> Si rimedia con `unminimize` (scarica centinaia di MB). L'immagine del laboratorio le ha già, e `whereis ls` mostra il percorso `/usr/share/man/man1/ls.1.gz`.
