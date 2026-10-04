# Help e manuali

Come trovare il comando giusto e leggerne la documentazione senza uscire dal terminale.

## Cercare il comando che serve
```bash
apropos copy     # cerca in tutti gli helper la parola "copy" per trovare il comando che serve
whatis ls        # cosa fa il comando ls

man -k YAML YML  # cerca in tutti i man le parole YAML oppure YML
apropos YAML YML # UGUALE
```

## Dove si trova un eseguibile
```bash
which ls    # dove si trova l'eseguibile di ls, in quale folder
whereis ls  # dove si trovano l'eseguibile e il manuale di ls

echo $PATH        # elenca le cartelle in cui la shell cerca gli eseguibili (usato da which e whereis)
PATH=$PATH:/opt/  # aggiungo /opt/ ai percorsi di $PATH
```

## I quattro livelli di documentazione
```bash
ls --help  # helper sintetico del comando
man ls     # helper più dettagliato: ls è un comando esterno a bash, pertanto ha il man
info ls    # helper ancora più dettagliato
help cd    # cd è una funzionalità di bash, non un comando esterno come ls, pertanto ha l'help e non il man
```

> **NOTA**: la distinzione `man` / `help` dipende da dove vive il comando. I builtin di bash
> (`cd`, `export`, `alias`, `type`) si documentano con `help`, tutto il resto con `man`.
> Per capire in quale categoria ricade un comando, vedi [05-alias.md](05-alias.md) e il comando `type`.
