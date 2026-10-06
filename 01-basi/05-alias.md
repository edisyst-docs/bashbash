# Alias

> **Laboratorio**: `./lab.sh 01`, poi `cd 05-alias`. Il file `bashrc-esempio` (un collegamento a [bashrc-esempio](bashrc-esempio)) si carica con `source bashrc-esempio`.

Scorciatoie per comandi lunghi o per comandi da lanciare sempre con gli stessi flag.

## Capire cosa sto eseguendo davvero
```bash
type pwd  # mi dice se è un builtin di bash, un alias o un percorso
# pwd is a shell builtin
type apt  # mi dice il suo percorso eseguibile
# apt is /usr/bin/apt
type ls   # mi dice il suo alias, perché ls ne ha uno
# ls is aliased to `ls --color=auto'

ls   # in realtà è come lanciare "ls --color=auto"
\ls  # è come lanciare "ls" puro: il backslash bypassa l'eventuale alias
```
L'alias di `ls` c'è perché il `~/.bashrc` di Debian e Ubuntu lo definisce (insieme a `grep`, `egrep`, `l`...): in una shell **senza** `.bashrc` (o in uno script) `type ls` dà `ls is /usr/bin/ls`.

## Creare e rimuovere alias
```bash
alias                                # mostra tutti gli alias della sessione
alias x="echo ciao;ls;ls;echo hello" # creo un alias con N comandi inline da eseguire in sequenza

unalias ls # rimuove l'alias per questa sessione di terminale
type ls    # ls is hashed (/usr/bin/ls)      <- "hashed": bash ricorda dove sta il comando
```

> **NOTA**: `alias` e `unalias` valgono solo per la sessione corrente. Per renderli permanenti
> vanno scritti in `~/.bashrc` (vedi [bashrc-esempio](bashrc-esempio)), che è anche il posto
> dove si mettono di solito le variabili d'ambiente personali.
> Attenzione: prima e dopo il segno `=` non devono comparire spazi.

Con gli spazi, `alias` interpreta **tre argomenti** e protesta su ognuno:
```bash
alias y = "echo a"
# bash: alias: y: not found
# bash: alias: =: not found
# bash: alias: echo a: not found
```
**Un alias non vale sulla riga in cui lo si definisce**: bash legge e interpreta l'intera riga *prima* di eseguirla.
```bash
alias z="echo z"; z
# bash: z: command not found          <- dalla riga dopo funziona
```
Per lo stesso motivo gli alias **non si espandono negli script** (shell non interattive): negli script servono funzioni o i comandi per esteso. Gli alias, poi, non accettano argomenti
in mezzo al comando: per questo nel [bashrc-esempio](bashrc-esempio) ci sono le **funzioni** `mkcd`, `estrai`, `bak`, `cerca` e `pesanti`, provate così:
```bash
source bashrc-esempio
mkcd uno/due && pwd         # crea la cartella ed entra: /root/lab/05-alias/uno/due
bak a.txt                   # a.txt.20261006-050731.bak
estrai a.tgz                # estrae l'archivio in base all'estensione
estrai a.txt.boh            # estrai: 'a.txt.boh' non è un file
cerca ciao                  # ./a.txt:1:ciao
pesanti . 3                 # le cartelle più grandi: "24K ." poi "8.0K ./uno"
```
