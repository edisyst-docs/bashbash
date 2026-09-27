# mysql e mysqldump da riga di comando

Client a riga di comando di MySQL/MariaDB: interrogare, fare dump e ripristini, diagnosticare.

## Credenziali senza scriverle sulla riga di comando
`-p password` finisce nella history e in `ps`. Meglio un file `~/.my.cnf` con permessi 600:
```ini
[client]
user=edoardo
password=segreta
host=127.0.0.1
```
```bash
chmod 600 ~/.my.cnf
mysql                                     # ora si collega senza chiedere niente (vale anche per mysqldump e mysqladmin)
mysql_config_editor set --login-path=prod --host=10.0.0.5 --user=admin --password # MySQL (non MariaDB): credenziali offuscate
mysql --login-path=prod                   # le usa
```

## Collegarsi ed eseguire query
```bash
mysql -u root -p                          # interattivo, chiede la password
mysql -h 10.0.0.5 -P 3306 -u app -p app_db # host, porta, utente, database
mysql app_db -e 'SHOW TABLES'             # esegue una query ed esce
mysql app_db -e 'SELECT id, email FROM users LIMIT 5' -t  # -t: output a tabella anche in pipe
mysql app_db -N -B -e 'SELECT email FROM users'          # -N niente intestazione, -B tab-separated: perfetto per gli script
mysql app_db < script.sql                 # esegue un file SQL
mysql app_db -e 'SELECT * FROM users\G'   # \G: un record per blocco, verticale (leggibile con tante colonne)
```

Dentro il client interattivo:
```sql
SHOW DATABASES;
USE app_db;
SHOW TABLES;
DESCRIBE users;                            -- struttura della tabella
SHOW CREATE TABLE users\G                  -- CREATE TABLE completo, indici compresi
SHOW PROCESSLIST;                          -- query in esecuzione
SOURCE /percorso/script.sql;               -- esegue un file
```

## Backup: mysqldump
```bash
mysqldump --single-transaction --routines --triggers app_db > app_db.sql # dump coerente di InnoDB senza bloccare le tabelle
mysqldump --single-transaction app_db | gzip > app_db_$(date +%F).sql.gz  # compresso, con la data
mysqldump --single-transaction app_db users orders > parziale.sql        # solo alcune tabelle
mysqldump --no-data app_db > schema.sql                                  # solo la struttura
mysqldump --no-create-info --where="created_at >= '2026-09-01'" app_db orders > ordini_settembre.sql # solo dati filtrati
mysqldump --single-transaction --all-databases > tutto.sql               # tutti i database
```

## Ripristino
```bash
mysql -e 'CREATE DATABASE IF NOT EXISTS app_db'
mysql app_db < app_db.sql                              # ripristina un dump
gunzip -c app_db_2026-09-25.sql.gz | mysql app_db      # da un dump compresso, senza scompattarlo su disco
pv app_db.sql.gz | gunzip | mysql app_db               # con barra di avanzamento (pacchetto pv): per i dump grandi
```
> **ATTENZIONE**: un dump contiene di solito `DROP TABLE IF EXISTS`: ripristinarlo sul database sbagliato
> sovrascrive i dati. Controllare sempre il nome del database di destinazione prima di premere INVIO.

## Esempi pratici
```bash
# dimensione di ogni database in MB
mysql -e "SELECT table_schema AS db, ROUND(SUM(data_length+index_length)/1024/1024,1) AS MB
          FROM information_schema.tables GROUP BY table_schema ORDER BY MB DESC"

# le 10 tabelle più grandi di un database
mysql -e "SELECT table_name, table_rows, ROUND((data_length+index_length)/1024/1024,1) AS MB
          FROM information_schema.tables WHERE table_schema='app_db' ORDER BY MB DESC LIMIT 10"

# numero di righe di ogni tabella, in un ciclo bash
for t in $(mysql app_db -N -B -e 'SHOW TABLES'); do
    printf '%-30s %s\n' "$t" "$(mysql app_db -N -B -e "SELECT COUNT(*) FROM \`$t\`")"
done

# esportare una query in CSV
mysql app_db -B -e "SELECT id, name, email FROM users" | sed 's/\t/;/g' > utenti.csv

# copiare un database da produzione a locale in streaming, senza file intermedi
ssh produzione 'mysqldump --single-transaction app_db | gzip' | gunzip | mysql app_db_locale

# copiare un database in un altro sullo stesso server (es. per una prova)
mysql -e 'CREATE DATABASE app_db_test'
mysqldump --single-transaction app_db | mysql app_db_test
```

Diagnostica:
```bash
mysqladmin status                          # uptime, thread, query al secondo
mysqladmin processlist                     # query in corso
mysql -e "SHOW FULL PROCESSLIST" | awk -F'\t' 'NR>1 && $6 > 10' # query che girano da più di 10 secondi (6ª colonna = Time, separatore TAB)
mysql -e "KILL 1234"                       # termina la connessione/query con Id 1234
mysql -e "SHOW VARIABLES LIKE 'max_connections'; SHOW STATUS LIKE 'Threads_connected'"
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A20 'LATEST DETECTED DEADLOCK' # ultimo deadlock
```

Utente applicativo con i soli permessi necessari:
```sql
CREATE USER 'app'@'localhost' IDENTIFIED BY 'password_lunga_e_casuale';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.* TO 'app'@'localhost';
-- migrazioni: aggiungere CREATE, ALTER, INDEX, DROP, REFERENCES solo se l'app le esegue con questo utente
SHOW GRANTS FOR 'app'@'localhost';
```

Vedi anche: [../06-sistema/09-crontab.md](../06-sistema/09-crontab.md) per il backup notturno con rotazione.
