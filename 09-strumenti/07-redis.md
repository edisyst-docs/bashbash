# Redis da riga di comando

Client `redis-cli`: ispezione, lettura/scrittura chiavi, monitoraggio, amministrazione.

## Collegarsi
```bash
redis-cli                                 # localhost:6379
redis-cli -h 10.0.0.5 -p 6379
redis-cli -h 10.0.0.5 -a password
redis-cli --no-auth-warning -h 10.0.0.5 -a password  # sopprime il warning sulla password in chiaro
redis-cli -n 2                            # database 2 (default: 0)
redis-cli ping                            # risponde PONG se il server è raggiungibile
```

## Chiavi
```bash
redis-cli KEYS '*'                        # tutte le chiavi (evitare in produzione su istanze grandi)
redis-cli SCAN 0 MATCH 'cache:*' COUNT 100  # alternativa non bloccante a KEYS
redis-cli TYPE chiave                     # string / list / set / zset / hash
redis-cli TTL chiave                      # secondi alla scadenza (-1 = nessuna, -2 = non esiste)
redis-cli PTTL chiave                     # come TTL ma in millisecondi
redis-cli EXISTS chiave
redis-cli DEL chiave1 chiave2
redis-cli UNLINK chiave                   # come DEL ma asincrono: non blocca il server
redis-cli RENAME vecchia nuova
redis-cli OBJECT ENCODING chiave          # encoding interno (embstr, ziplist, skiplist…)
```

## Lettura e scrittura
```bash
redis-cli SET foo bar
redis-cli SET foo bar EX 3600             # con TTL in secondi
redis-cli GET foo
redis-cli MGET foo bar baz                # più chiavi in un colpo
redis-cli INCR contatore                  # incrementa un intero atomicamente
redis-cli APPEND foo " world"

# Hash
redis-cli HSET utente:1 nome "Mario" email "mario@example.com"
redis-cli HGET utente:1 nome
redis-cli HGETALL utente:1

# List
redis-cli RPUSH coda item1 item2
redis-cli LRANGE coda 0 -1               # tutti gli elementi
redis-cli LPOP coda

# Set
redis-cli SADD tag:php laravel composer symfony
redis-cli SMEMBERS tag:php
```

## Monitoraggio
```bash
redis-cli INFO                            # tutto: server, memoria, statistiche, keyspace
redis-cli INFO memory                     # solo la sezione memoria
redis-cli INFO keyspace                   # database con numero di chiavi e scadenze
redis-cli MONITOR                         # stream in tempo reale di tutti i comandi (DEBUG: evitare in produzione)
redis-cli --latency                       # latenza in ms verso il server
redis-cli --stat                          # statistiche aggiornate ogni secondo
redis-cli SLOWLOG GET 10                  # ultime 10 query lente
redis-cli SLOWLOG RESET
```

## Amministrazione
```bash
redis-cli DBSIZE                          # numero di chiavi nel database corrente
redis-cli FLUSHDB                         # svuota il database corrente
redis-cli FLUSHDB ASYNC                   # idem, asincrono
redis-cli FLUSHALL                        # svuota TUTTI i database
redis-cli SELECT 1                        # cambia database (solo in sessione interattiva)
redis-cli SAVE                            # forza un dump RDB sincrono su disco
redis-cli BGSAVE                          # idem, in background
redis-cli CONFIG GET maxmemory
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG REWRITE                  # salva la configurazione corrente nel redis.conf
redis-cli DEBUG SLEEP 0                   # verifica che il server risponda (0 = nessuna pausa)
```

## Usare redis-cli in pipe e script
```bash
redis-cli GET foo                         # output grezzo, senza decorazioni
# eliminare tutte le chiavi che matchano un pattern (SCAN è non bloccante, a differenza di KEYS)
redis-cli SCAN 0 MATCH 'cache:*' COUNT 100 | tail -n +2 | xargs -r redis-cli DEL
# esportare tutte le chiavi con tipo e TTL
redis-cli KEYS '*' | while read k; do
    printf '%s\t%s\t%s\n' "$k" "$(redis-cli TYPE "$k")" "$(redis-cli TTL "$k")"
done
```
