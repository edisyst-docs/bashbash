# 09 - Strumenti

Gli strumenti da riga di comando che si usano ogni giorno sviluppando e gestendo applicazioni web.
Docker, Kubernetes, Jenkins, Ansible e Terraform hanno un'area tutta loro: [../11-container-e-automazione/](../11-container-e-automazione/).

| # | File | Contenuto |
|---|---|---|
| 01 | [jq e curl](01-jq-e-curl.md) | Richieste HTTP, API, misurare i tempi, download con `wget`, leggere e costruire JSON |
| 02 | [git](02-git.md) | Storia, `stash`, correzioni, `reflog`, `bisect`, branch, hook |
| 03 | [mysql](03-mysql.md) | Client `mysql`, `mysqldump`, ripristino, diagnostica, utenti |
| 04 | [php](04-php.md) | Ispezione installazione, esecuzione al volo, lint, server built-in, Composer |
| 05 | [python](05-python.md) | Ispezione installazione, snippet al volo, venv, pip, moduli stdlib utili |
| 06 | [postgresql](06-postgresql.md) | Client `psql`, `pg_dump`/`pg_restore`, diagnostica, utente applicativo |
| 07 | [redis](07-redis.md) | `redis-cli`, chiavi, strutture dati, monitoraggio, amministrazione |
| 08 | [make](08-make.md) | `Makefile`: regole, variabili, `.PHONY`, regole a schema, `-n`/`-j`, errori tipici |
| 09 | [bats](09-bats.md) | Testare gli script bash: `@test`, `run`, `bats-assert`, finti comandi nel `PATH`, `setup`/`teardown` |
| 10 | [ricerca veloce](10-ricerca-veloce.md) | `ripgrep`, `fd`, `fzf`, `bat` e `ncdu` al posto di `grep -r`, `find`, `cat` e `du` |
| 11 | [rabbitmq](11-rabbitmq.md) | Code, exchange e binding, ack e consumer, TTL e dead letter, vhost e utenti, API HTTP, `rabbitmqctl` |
| 12 | [kafka](12-kafka.md) | Topic e partizioni, offset, consumer group e lag, `kcat`, `kafka-topics.sh`, compattazione |
| 13 | [mongodb](13-mongodb.md) | `mongosh`, `find`, `aggregate`, indici e `explain`, utenti e ruoli, `mongodump`, `mongoimport` |
| 14 | [scenari guidati](14-scenari.md) | 8 problemi veri da diagnosticare: `curl` e `jq`, permessi e indici di MySQL, `git reflog` e conflitti, binding di RabbitMQ, offset di Kafka; `scenari.sh controlla` guarda se è risolto |

**Laboratorio**: `./lab.sh 09` dalla radice della KB avvia un MySQL 9.7 con un database già popolato,
un'API finta su `http://api` e un repository git con una storia da indagare; per `make`, `bats` e gli strumenti di ricerca ci sono un progetto di esempio e una cartella con file grandi; e tre servizi di messaggi e dati, RabbitMQ, Kafka (un solo broker) e MongoDB. Dettagli in [lab/](lab/).

Area precedente: [../08-remoto-e-sicurezza/](../08-remoto-e-sicurezza/) · Prossima: [../10-rete-e-web/](../10-rete-e-web/) · Torna all'[indice](../README.md)
