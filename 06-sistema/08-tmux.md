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

## Esempi pratici
```bash
tmux new -A -s lavoro            # si attacca alla sessione "lavoro" se esiste, altrimenti la crea: ideale appena entrato in SSH
tmux kill-session -t lavoro      # chiude una sessione dall'esterno
tmux new -d -s migrazione 'php artisan migrate --force 2>&1 | tee migrazione.log' # lancia un comando lungo in una sessione staccata (-d)
                                                                                 # se cade la connessione il comando continua
```

Script che prepara un ambiente di lavoro con più pane:
```bash
#!/usr/bin/env bash
S=monitor
tmux has-session -t "$S" 2>/dev/null && exec tmux attach -t "$S"   # esiste già? mi attacco e basta

tmux new-session  -d -s "$S" -n log                                # finestra "log"
tmux send-keys    -t "$S":log 'tail -f /var/www/app/storage/logs/laravel.log' C-m # C-m = INVIO
tmux split-window -t "$S":log -h                                   # pane a destra
tmux send-keys    -t "$S":log.1 'journalctl -u nginx -f' C-m
tmux split-window -t "$S":log.1 -v                                 # sotto al pane di destra
tmux send-keys    -t "$S":log.2 'htop' C-m
tmux new-window   -t "$S" -n shell                                 # seconda finestra vuota
tmux select-window -t "$S":log
tmux attach -t "$S"
```
