# top e htop

## top
```bash
top              # mostra processi e risorse occupate in modalità interattiva
top -p 1234,5678 # mostra solo i processi con PID 1234 e 5678
top -u edoardo   # mostra solo i processi di edoardo
top -b -n2 -d2   # esegue top 2 volte, ogni 2 secondi, in batch (invece che in modalità interattiva)
```

**Comandi interattivi di top**
* `h`: mostra l'aiuto (elenco dei comandi interattivi)
* `q`: esce da top
* `F`: fields management, permette di scegliere (premendo `D` o spazio) quali colonne mostrare e su cosa ordinare i processi
* `l`: attiva/disattiva la visualizzazione della prima riga
* `c`: attiva/disattiva la visualizzazione del percorso completo del comando
* `m`: cambia la visualizzazione dell'utilizzo della memoria
* `t`: cambia la visualizzazione dell'utilizzo della CPU
* `M`: ordina i processi per utilizzo della memoria
* `P`: ordina i processi per utilizzo della CPU (predefinito)
* `T`: ordina i processi per tempo di CPU cumulativo
* `R`: inverte l'ordinamento attuale
* `k`: uccide un processo. Chiede il PID e il segnale da inviare
* `r`: cambia la priorità (niceness) di un processo. Fa ciò che fa il comando `renice`
* `u`: filtra i processi per utente. Chiede il nome utente
* `n`: cambia il numero di processi visualizzati

## htop
Versione migliorata e più interattiva di `top`.
```bash
htop              # avvia htop
htop -p 1234,5678 # mostra solo i processi con PID 1234 e 5678
htop -u edoardo   # mostra solo i processi di edoardo
```

**Comandi interattivi di htop**
* `h`: mostra l'aiuto (elenco dei comandi interattivi)
* `q` / `F10`: esce da htop
* `F2`: entra nel menu di configurazione. Permette di modificare colonne, colori e altre impostazioni
* `F3`: cerca un processo per nome
* `F4`: filtra i processi per nome
* `F5`: visualizzazione ad albero dei processi
* `F6`: cambia il criterio di ordinamento (CPU, memoria, tempo di esecuzione, ...)
* `F7` / `F8`: aumenta/diminuisce la priorità (niceness) di un processo
* `F9`: uccide un processo. Chiede quale segnale inviare

Vedi anche: [04-risorse.md](04-risorse.md) per `nice`/`renice` da riga di comando.
