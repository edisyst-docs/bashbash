# Laboratorio dell'area 09

Qui non bastano dei file: servono un server MySQL, un'API HTTP e tre servizi di messaggi e dati. [compose.yaml](compose.yaml) avvia sei container (compresa la shell)
sulla stessa rete, senza pubblicare porte sull'host:

| Servizio | Cosa è | Come si raggiunge dalla shell |
|---|---|---|
| `shell` | la shell in cui si lavora (immagine `bashbash`) | è quella in cui si entra |
| `mysql` | MySQL 9.7 LTS con il database `app_db` già popolato da [mysql-init/](mysql-init/01-app_db.sql) | `mysql app_db`: le credenziali sono in `~/.my.cnf` |
| `api` | API finta scritta in Python ([api.py](api.py)), più un piccolo sito statico in [materiale/sito/](materiale/sito/) | `http://api` |

I file di lavoro li genera [prepara.sh](prepara.sh), come nelle altre aree.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 09               # la prima volta scarica l'immagine mysql:9.7; poi parte in ~15 secondi
cd 03-mysql
mysql app_db -e 'SHOW TABLES'
```
All'uscita `lab.sh` spegne ed elimina i container, la rete e il volume del database: ogni avvio riparte
dagli stessi dati. Per ricreare solo i file senza uscire: `bash /kb/09-strumenti/lab/prepara.sh && cd ~/lab`.

## 01-jq-e-curl
File pronti: `file.json`, `users.json` (gli stessi utenti di `http://api/users`), `config.json`, `utente.json`,
`payload.json`, `header.txt`, `foto.jpg`, `lista_url.txt`, `storage/logs/laravel.json`, `composer.json`.

Negli esempi basta sostituire `https://api.example.com` con `http://api`. Cosa risponde l'API:

| Percorso | Risposta |
|---|---|
| `GET /users`, `/users/ID` | 10 utenti con `id`, `name`, `username`, `email` (alcune `.biz`), `address.city` (città ripetute, per `group_by`) |
| `POST /users`, `/posts` | `201` con il body ricevuto e un `id` nuovo; `PUT`/`PATCH`/`DELETE /users/ID` |
| `GET /items?page=N` | 3 pagine da 5 elementi, poi `[]`: per l'esempio di paginazione |
| `/echo`, `/form`, `/cerca`, `/upload` | restituiscono metodo, header, query e body ricevuti: si vede cosa manda davvero `-d`, `--data-urlencode`, `-F`, `-H` |
| `GET /status/500`, `/x` | errori `500` e `404`, per provare `-f` |
| `GET /redirect` | `301` verso `/users`, per `-L` |
| `GET /lento?secondi=5` | risposta lenta, per `--max-time` |
| `GET /protetta` | Basic Auth `utente` / `password`, per `-u` e `wget --user` |
| `GET /login` poi `/profilo` | cookie di sessione, per `-c` e `-b` |
| `GET /file.zip`, `/grande.iso` | file binari da 256 KB e 8 MB che supportano la ripresa (`curl -C - -O`, `wget -c`) |
| `GET /`, `/docs/`, `/style.css` | sito statico per `wget -r -np http://api/docs/` e `wget -m -k -p http://api/` |

`example.com` e `jsonplaceholder.typicode.com` sono siti veri: funzionano se il PC è in rete.

## 02-git
- `progetto/`: repository con 13 commit su `main` di due autori (Edoardo e Mario) sparsi negli ultimi due mesi,
  il tag `v2.3.0`, un file rinominato (`vecchio/percorso.php` → `nuovo/percorso.php`), un branch già
  unito (`fix/typo`) e il branch di lavoro `feature/login` con modifiche non committate e un file non tracciato.
- `origin.git/`: il remoto (repository bare). Il branch `feature/vecchio` è già stato cancellato lì:
  `git fetch --prune` rimuove `origin/feature/vecchio`.
- Il branch `esperimento` è stato cancellato: il suo commit "idea da non perdere" si ritrova con `git reflog`.
- Dopo il tag `v2.3.0` un commit ha portato l'IVA dal 22% al 20% in `app/Services/Carrello.php`: è il bug
  da trovare con bisect. Il test automatico è `../verifica.sh`: `git stash -u`, poi
  `git bisect start HEAD v2.3.0 && git bisect run ../verifica.sh`.
- `pre-commit`: l'hook del `.md`, da copiare in `progetto/.git/hooks/`. L'ultimo commit di `feature/login`
  contiene un `dd(`: se si modifica di nuovo quel file, il commit viene bloccato.

Al posto degli hash di esempio (`a1b2c3d`) si usano quelli di `git log --oneline`. L'esempio con `php -l`
richiede PHP, che nel container non c'è.

## 03-mysql
- `~/.my.cnf` punta al MySQL del laboratorio (`root` / `lab`, host `mysql`): per questo `mysql` e `mysqldump` non
  chiedono niente. Non viene toccato un `.my.cnf` già esistente che non sia del laboratorio.
- `app_db` contiene `users` (8 righe), `orders` (3000, dal 1° gennaio al 25 settembre 2026), `products` (5) e `logs` (20000).
- `script.sql` per `mysql app_db < script.sql`; `app_db_2026-09-25.sql.gz` per l'esempio di ripristino da file compresso.
- Per `mysql_config_editor`: `--host=mysql --user=root`, password `lab`.
- Per vedere `SHOW PROCESSLIST` con una query lunga: `mysql -e 'SELECT SLEEP(60)' &`.

## 08-make, 09-bats, 10-ricerca-veloce
Niente servizi: sono strumenti della shell, e i file di lavoro li crea `prepara.sh`.
- `08-make/`: il `Makefile` dell'esempio, tre testi in `src/`, `saluta.sh` e `test.bats`. `make` mostra l'aiuto, `make all` converte i testi, `make test` lancia `bats`, `make lint` lancia `shellcheck`, `make dist` crea un pacchetto in `dist/`
- `09-bats/`: `saluta.sh` con `test.bats` (asserzioni, `--separate-stderr`, `source`, `skip`) e `stato.sh` con `stato.bats` (un finto `curl` nel `PATH`, `setup_file`)
- `10-ricerca-veloce/progetto/`: un repository git con codice Python, JavaScript e PHP (con `TODO` e `FIXME`), `node_modules/` e `vendor/` ignorati, e `logs/app.log` di 20000 righe: per `rg`, `fd`, `fzf`, `bat`
- `10-ricerca-veloce/spazio/`: 93 MB di file vuoti di dimensioni diverse (video, cache, log, documenti) per `du` e `ncdu`

Da sapere:
- `fd` e `bat` si chiamano `fdfind` e `batcat` (nomi di Debian e Ubuntu)
- `ncdu`, `fzf` con l'anteprima e le scorciatoie di tastiera sono interattivi: nel laboratorio si provano a mano, e le scorciatoie di `fzf` (`key-bindings.bash`) non ci sono, perché l'immagine Ubuntu per container esclude `/usr/share/doc`
- le cartelle del `.md` `10-ricerca-veloce` sono sotto `~/lab/10-ricerca-veloce/`

## 11-rabbitmq, 12-kafka, 13-mongodb
Tre servizi in più, sulla stessa rete, senza porte pubblicate sull'host:

| Servizio | Cosa è | Come si raggiunge dalla shell |
|---|---|---|
| `rabbitmq` | RabbitMQ 4.3 con la gestione e le metriche Prometheus; utente `lab` / `lab` | AMQP `amqp://lab:lab@rabbitmq`, API `http://rabbitmq:15672/api`, metriche `http://rabbitmq:15692/metrics` |
| `kafka` | Kafka 4.3.1 in modalità KRaft, **un solo broker**, topic creati al volo con 3 partizioni | `kcat` (l'indirizzo è in `~/.config/kcat.conf`), `kafka:9092` |
| `mongo` | MongoDB 8.0 con il database `app` ([mongo-init/](mongo-init/01-app.js): `utenti`, `ordini`, un indice, l'utente `app`) e l'amministratore `lab` | `mongosh "mongodb://app:app@mongo/app?authSource=app"` |

- `11-rabbitmq/`: `lavori.txt` (cinque lavori da mettere in coda) e `worker.sh`, il consumer da dare a `amqp-consume` (esce con 1 sulle fatture, e il messaggio resta in coda)
- `12-kafka/`: `ordini.txt`, righe `chiave:valore` per `kcat -K:`
- `13-mongodb/`: `nuovi.json` (JSON Lines) e `clienti.csv` per `mongoimport`

Da sapere:
- i tre servizi usano circa 700 MB di memoria (Kafka ~400, MongoDB ~200, RabbitMQ ~130), e `./lab.sh 09` li aspetta tutti (health check): l'avvio è di circa 20-30 secondi, più il download delle immagini la prima volta
- `rabbitmqctl` e le utility `kafka-*.sh` stanno **nei container dei broker**: da un secondo terminale dell'host, dalla radice della KB,
  `docker compose -f 09-strumenti/lab/compose.yaml exec rabbitmq rabbitmqctl ...` e `... exec kafka /opt/kafka/bin/kafka-topics.sh ...`
- le interfacce web (gestione di RabbitMQ sulla 15672) e le sessioni interattive non sono state provate: per aprirle dall'host bisogna aggiungere `ports:` al servizio

## 14-scenari
`14-scenari/` ha `scenari.sh`, che lancia [scenari.sh](scenari.sh) (qui in `lab/`, con i guasti dentro): `./scenari.sh guasta N` azzera tutto e prepara lo scenario N (8 in tutto) nella cartella `lavoro/`, stampando il sintomo; `controlla` dice se è risolto; `ripristina` toglie ogni guasto (utente `report`, indici su `logs`, exchange e coda di RabbitMQ, file e repository di `lavoro/`).
I guasti: uno script che scarica un reindirizzamento, uno che legge una sola pagina, un utente MySQL senza il permesso su `orders`, nessun indice su `logs.created_at`, un `reset --hard` che nasconde un commit, un merge in conflitto, una routing key sbagliata, un consumer Kafka che parte dalla fine. Il topic dell'ultimo (`eventi-NNN`) ha un nome diverso a ogni `guasta`, perché Kafka non si svuota. I repository hanno un'identità git propria (`Studente`), per poter fare commit.
Le riparazioni di riferimento e i tentativi che non bastano (`GRANT ALL`, `ANALYZE TABLE`, `git merge --abort`, `-o -1`...) sono in [scenari-soluzioni.sh](scenari-soluzioni.sh); [scenari-autotest.sh](scenari-autotest.sh) rompe, prova le scorciatoie e ripara ogni scenario, e deve dire che tutti i controlli sono ok (lo lancia la CI).
Da sapere, trovato provando: in MySQL 9 `EXPLAIN` stampa per default un **albero**; la tabella con `type`, `key` e `rows` richiede `EXPLAIN FORMAT=TRADITIONAL`. Le statistiche delle code di RabbitMQ si aggiornano ogni 5 secondi circa: subito dopo aver creato una coda l'API dà `messages: null`.

Torna all'[indice dell'area](../README.md)
