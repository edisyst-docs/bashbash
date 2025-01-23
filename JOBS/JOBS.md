# Foreground e Background

Creo un contatore infinito e lo rendo eseguibile. 
```bash
vi contatore.sh

chmod +x contatore.sh
./contatore.sh
```

Se lo eseguo e apro un'altra shell controllo il file conta.txt e vedo che il contatore si incrementa in background. 
```bash
tail -f conta.txt
``` 

Il problema è che nella prima shell non posso più fare niente. Se volessi fare tutto in background dovrei fare così:
```bash
./contatore.sh &
```

Mi viene restituito il PID del processo in background, così posso stopparlo quando voglio, ma la shell rimane utilizzabile.
```bash
ps                     # Mostra i processi attivi
ps aux | grep 6522     # Mostra più info, tra cui chi esegue il processo, ossia /bin/bash

jobs                   # Mostra i processi in background (al momento 1 solo)
fg 1                   # Riporta il processo 1 in foreground: come se lo avessi lanciato normalmente senza la &
bg 1                   # Riporta il processo 1 in background
``` 

Se invece lancio il processo senza la & ma volgio metterlo in background posso fare così:
```bash
./contatore.sh 
```

Premo CTRL+Z per mettere in pausa il processo
```bash
jobs    # Vedo che ho un solo processo in stato Stopped, non Running
bg 1    # Riporta il processo 1 in background, se è un processo unico posso anche fare bg
```

Altro esempio:
```bash
./contatore.sh &                     # lo lancio in background
find / -iname "*.conf" > /dev/null   # premo subito CTRL+Z per stopparlo (ci impiega un po' a trovare tutti i file)
jobs                                 # vedo che ho 2 processi in background: uno in esecuzione e uno stoppato
```


**Ricapitolando**:
- `processo &` per lanciare un processo in background
- `CTRL+Z` per mettere in pausa un processo
- `bg` per riportare un processo in background
- `fg` per riportare un processo in foreground
- `jobs` per vedere i processi in background
- `ps` per vedere i processi attivi

```bash
nohup ./contatore.sh &  # Lancia il processo in background e non lo ferma se chiudo la shell o mi disconnetto dal server
```
