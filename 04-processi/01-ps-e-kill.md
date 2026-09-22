# Processi: ps e kill

## ps: elenco dei processi
```bash
ps                  # elenco processi attivi (in esecuzione ce ne sono tanti altri, anche in altre shell)
ps -u edoardo       # elenco processi del solo utente "edoardo"
ps -f               # qualche info in più
ps -lf              # qualche info in più ancora
ps -e               # elenco di tutti i processi in esecuzione
ps -p 1,764         # mostro solo i processi con PID=1 e PID=764
ps aux              # indica anche l'uso di CPU e memoria
ps aux --sort=-%cpu # UGUALE ma ordinati per uso di CPU
ps -o pid,uid,s,pri # mostra solo i campi specificati: pid, uid, s, pri
ps --forest         # mostra la gerarchia padre-figlio dei processi
ps -l               # mostra anche priorità e niceness dei processi
```

## Cercare un processo per nome
```bash
pgrep snap         # cerca i processi facendo un grep sul nome
ps -ef | grep snap # UGUALE
```

## kill: inviare segnali
```bash
kill -l      # lista dei segnali che posso mandare
kill -1 1234 # forza il reload del processo 1234 (SIGHUP)

kill    1234 # di default manda il segnale 15 (SIGTERM): chiede al processo 1234 di terminarsi

kill -9 1234       # termina forzatamente il processo con PID=1234. Solo l'owner, root o un sudoer può farlo
kill -SIGKILL 1234 # UGUALE (SIGKILL=9)
kill -KILL    1234 # UGUALE (tutti i segnali si chiamano SIGXXX)
kill -s KILL  1234 # UGUALE
kill -9 %1         # con questa sintassi gli passo non il PID, ma il JOB_ID
```

## Terminare più processi insieme
```bash
pkill calc    # termina tutti i processi facendo un grep sul nome
killall calc  # SIMILE: termina tutti i processi con quel nome esatto
```

## lsof: file aperti dai processi
> **SINTASSI**: `lsof [opzioni] [nome_file|PID|utente|comando]`
```bash
lsof -u utente       # file aperti da un utente specifico
lsof -p 1234         # file aperti dal solo processo con PID=1234
lsof /var/log/syslog # processi che hanno aperto il file /var/log/syslog
lsof -c nome_comando # file aperti dai processi corrispondenti a un comando specifico
lsof -i              # tutte le connessioni di rete aperte
lsof -i :80          # connessioni di rete per una porta specifica
```

Vedi anche: [02-jobs.md](02-jobs.md) per i job ID, [03-top-htop.md](03-top-htop.md) per il monitoraggio interattivo.
