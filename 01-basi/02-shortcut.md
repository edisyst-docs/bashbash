# Scorciatoie da tastiera

Combinazioni della shell interattiva. Funzionano in bash indipendentemente dal terminale usato.

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

Vedi anche: [06-history.md](06-history.md) per richiamare i comandi con `!!`, `!$` e `!101`.
