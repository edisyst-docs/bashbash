# Alias

Scorciatoie per comandi lunghi o per comandi da lanciare sempre con gli stessi flag.

## Capire cosa sto eseguendo davvero
```bash
type pwd  # mi dice se è un builtin di bash, un alias o un percorso
type apt  # mi dice il suo percorso eseguibile
type ls   # mi dice il suo alias, perché ls ne ha uno

ls   # in realtà è come lanciare "ls --color=auto"
\ls  # è come lanciare "ls" puro: il backslash bypassa l'eventuale alias
```

## Creare e rimuovere alias
```bash
alias                                # mostra tutti gli alias della sessione
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza

unalias ls # rimuove l'alias per questa sessione di terminale
```

> **NOTA**: `alias` e `unalias` valgono solo per la sessione corrente. Per renderli permanenti
> vanno scritti in `~/.bashrc` (vedi [bashrc-esempio](bashrc-esempio)), che è anche il posto
> dove si mettono di solito le variabili d'ambiente personali.
> Attenzione: prima e dopo il segno `=` non devono comparire spazi.
