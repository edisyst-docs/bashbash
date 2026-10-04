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

## Esempi pratici
```bash
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%mem | head -11 # top 10 per memoria, con da quanto tempo girano (etime)
ps -o etimes= -p 1234                  # da quanti SECONDI gira il processo 1234 (il "=" toglie l'intestazione, comodo negli script)
ps -o rss= -p 1234 | awk '{printf "%.1f MB\n", $1/1024}' # memoria residente del processo in MB
pgrep -af 'artisan queue:work'         # -f cerca nell'intera riga di comando, -a la stampa: vedo tutti i worker Laravel attivi
pkill -f 'artisan queue:work'          # li termina tutti (poi supervisor/systemd li fa ripartire con il codice nuovo)
pkill -u mario                         # termina tutti i processi dell'utente mario
kill -0 1234 && echo "vivo"            # il segnale 0 non fa niente: serve solo a sapere se il processo esiste

timeout 30s ./script_lento.sh          # lo termina se dopo 30 secondi non ha finito (exit status 124)
timeout -k 5s 30s ./script_lento.sh    # UGUALE, ma se ignora il SIGTERM dopo altri 5 secondi manda SIGKILL

lsof -iTCP -sTCP:LISTEN -P -n          # porte TCP in ascolto e processo che le usa (-P -n: niente risoluzione di porte e nomi, più veloce)
lsof +L1                               # file ELIMINATI ma ancora aperti: il classico "df dice disco pieno ma du non trova niente"
fuser -v 8000/tcp                      # chi occupa la porta 8000
fuser -k 8000/tcp                      # UGUALE ma lo termina (es. un "php artisan serve" rimasto appeso)
```

### Fermare un processo con garbo
Prima si chiede di terminare (TERM), si aspetta, e solo se non basta si forza (KILL).
Il processo così ha tempo di chiudere file e connessioni.
```bash
ferma() {
    local pid=$1 attesa=${2:-10}              # secondo argomento opzionale: secondi di attesa, default 10
    kill -TERM "$pid" 2>/dev/null || return 0 # se il processo non esiste già più, ho finito
    for (( i=0; i<attesa; i++ )); do
        kill -0 "$pid" 2>/dev/null || return 0 # terminato da solo
        sleep 1
    done
    echo "PID $pid ancora vivo dopo ${attesa}s, invio SIGKILL" >&2
    kill -KILL "$pid"
}

ferma 1234 15
```

Vedi anche: [02-jobs.md](02-jobs.md) per i job ID, [03-top-htop.md](03-top-htop.md) per il monitoraggio interattivo.
