# Scorciatoie da tastiera

> **Laboratorio**: `./lab.sh 01`. Le scorciatoie si premono sulla tastiera: qui sono state verificate **chiedendo alla shell** a cosa sono associate (`bind -P`, `stty -a`), non premendo i tasti.

Combinazioni della shell interattiva. Funzionano in bash indipendentemente dal terminale usato.

Vengono da **tre livelli diversi**, e sapere quale è utile quando una non funziona:

| Livello | Chi la gestisce | Esempi |
|---|---|---|
| Emulatore di terminale | il programma (GNOME Terminal, Windows Terminal, ...): cambia da uno all'altro | `CTRL+SHIFT+C`, `CTRL+SHIFT+V`, `CTRL++`, `CTRL+-` |
| Driver del terminale (tty) | il kernel, configurabile con `stty` | `CTRL+C`, `CTRL+Z`, `CTRL+D`, `CTRL+S`, `CTRL+Q` |
| Readline | la libreria di editing di bash, configurabile con `bind` e `~/.inputrc` | `CTRL+R`, `CTRL+A`, `CTRL+E`, `CTRL+U`, `CTRL+K`, `CTRL+Y`, `CTRL+L`, `CTRL+P`, `CTRL+N` |

```bash
stty -a | tr ';' '\n' | grep -E 'intr|susp|eof|stop|start'     # i tasti di controllo del tty
# intr = ^C
#  eof = ^D
#  start = ^Q
#  stop = ^S
#  susp = ^Z
bind -P | grep -E '^(beginning-of-line|end-of-line|kill-line|unix-line-discard|yank|previous-history|next-history|reverse-search-history|clear-screen) '
# beginning-of-line can be found on "\C-a", "\eOH", "\e[1~", "\e[H".
# clear-screen can be found on "\C-l".
# end-of-line can be found on "\C-e", "\eOF", "\e[4~", "\e[F".
# kill-line can be found on "\C-k".
# next-history can be found on "\C-n", "\eOB", "\e[B".
# previous-history can be found on "\C-p", "\eOA", "\e[A".
# reverse-search-history can be found on "\C-r".
# unix-line-discard can be found on "\C-u".
# yank can be found on "\C-y".
```
`\C-a` è `CTRL+A`; `\e[A` è la freccia su: **le frecce e `CTRL+P`/`CTRL+N` fanno la stessa cosa**, e `Home`/`End` come `CTRL+A`/`CTRL+E`.
`bind` e `stty` hanno bisogno di un terminale vero: da uno script o da `bash -c` non mostrano niente o dicono `Inappropriate ioctl for device`.

## Controllo del terminale
```bash
CTRL+L # pulisce la shell, shortcut del comando clear

CTRL++ # aumenta (temporaneamente) la dimensione del font
CTRL+- # riduce  (temporaneamente) la dimensione del font

CTRL+SHIFT+C # copia
CTRL+SHIFT+V # incolla
```

## Controllo dei processi
```bash
CTRL+C # interrompe l'esecuzione di un comando
CTRL+Z # mette in pausa un processo lasciandolo in background. Es: esco da VIM col file non salvato

CTRL+D # esce dalla shell (sottoshell se sto impersonando un altro utente). Equivale a digitare "exit"

CTRL+S # sospende la visualizzazione dell'output che scorre sullo schermo senza interrompere il comando
CTRL+Q # riprende la visualizzazione dell'output che scorre sullo schermo
```
`CTRL+D` è il carattere di **fine file** (`eof`): chiude la shell solo sulla riga **vuota**; con del testo scritto cancella il carattere sotto il cursore. `CTRL+Z` ferma il processo (`fg` lo riprende, `bg` lo fa
proseguire in sottofondo); non lo "lascia in background" in esecuzione.

## Navigazione nella history
```bash
CTRL+R # ricerca comandi nella history (scrivo qualcosa da cercare, tipo stat, poi premo altre volte CTRL+R per scorrere le altre occorrenze)

CTRL+P # history: indietro di un comando
CTRL+N # history: avanti   di un comando
```

## Editing della riga di comando
```bash
CTRL+U # taglia la parte sinistra di ciò che ho scritto sulla shell
CTRL+K # taglia la parte destra   di ciò che ho scritto sulla shell
CTRL+Y # incolla la parte eliminata coi comandi precedenti

CTRL+A # vado all'inizio di ciò che ho scritto sulla shell
CTRL+E # vado alla fine   di ciò che ho scritto sulla shell
```
`CTRL+U` e `CTRL+K` non cancellano: **tagliano** nel *kill ring*, e `CTRL+Y` incolla (`unix-line-discard` e `kill-line` nell'elenco sopra). Altre utili: `CTRL+W` (taglia la parola prima del cursore),
`ALT+B` / `ALT+F` (una parola indietro/avanti), `CTRL+_` (annulla). *(Queste ultime, e il comportamento di `CTRL+D` con del testo sulla riga, non sono state verificate come le altre.)*

Vedi anche: [06-history.md](06-history.md) per richiamare i comandi con `!!`, `!$` e `!101`.
