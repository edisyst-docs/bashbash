# tmux

Terminali e finestre multipli su una singola istanza, per esempio su un singolo collegamento SSH.

## Gestione sessioni
```bash
tmux                 # apre una nuova sessione
tmux ls              # mostra le sessioni attive
tmux new -s sessione # crea una nuova sessione chiamata "sessione"
tmux attach -t 0     # permette di ricollegarsi alla sessione 0
exit                 # esce da una sezione/finestra/sessione in base a dove mi trovo nei vari livelli
```

## Comandi interni
All'interno di tmux ogni azione deve essere preceduta da `CTRL+B`.

**Finestre**
- `CTRL+B` poi `?`: mostra l'elenco dei comandi disponibili
- `CTRL+B` poi `C`: (create) crea una nuova finestra
- `CTRL+B` poi `,`: rinomina la finestra corrente
- `CTRL+B` poi `N`: (next) passa alla finestra successiva
- `CTRL+B` poi `P`: (previous) passa alla finestra precedente
- `CTRL+B` poi `W`: (windows) elenca le finestre per sceglierne una

**Sezioni (pane)**
- `CTRL+B` poi `%`: (split) divide la finestra corrente in due sezioni verticali
- `CTRL+B` poi `"`: (split) divide la finestra corrente in due sezioni orizzontali
- `CTRL+B` poi freccia: sposta il focus tra le varie sezioni della finestra
- `CTRL+B` poi `[`: (copy) permette di copiare il testo dalla finestra corrente
- `CTRL+B` poi `&`: (kill) chiude la sezione/finestra/sessione corrente. È come digitare `exit`

**Sessione**
- `CTRL+B` poi `D`: (detach) stacca la sessione corrente ma non la chiude, così posso sempre riaprirla
