# PostgreSQL da riga di comando

Client `psql`, dump e ripristino con `pg_dump`/`pg_restore`, diagnostica.

## Collegarsi
```bash
psql -U postgres                          # utente postgres, database omonimo
psql -U app -d app_db                     # utente e database espliciti
psql -h 10.0.0.5 -p 5432 -U app app_db   # host e porta
psql "postgresql://app:password@10.0.0.5/app_db"  # connection string
```

Credenziali senza scriverle sulla riga di comando: file `~/.pgpass` con permessi 600:
```
# hostname:porta:database:utente:password
10.0.0.5:5432:app_db:app:password_lunga
*:*:*:postgres:password_locale
```
```bash
chmod 600 ~/.pgpass
psql -h 10.0.0.5 -U app app_db            # non chiede la password
```

## Comandi dentro psql
```sql
\l                        -- lista database
\c app_db                 -- cambia database
\dt                       -- tabelle dello schema corrente
\dt schema.*              -- tabelle di uno schema specifico
\d users                  -- struttura di una tabella (colonne, tipi, indici)
\di                       -- indici
\du                       -- utenti e ruoli
\x                        -- attiva/disattiva output espanso (una riga = un blocco)
\timing                   -- mostra il tempo di ogni query
\copy users TO 'utenti.csv' CSV HEADER   -- esporta in CSV
\i script.sql             -- esegue un file SQL
\q                        -- esci
```

## Eseguire query senza entrare in psql
```bash
psql -U app app_db -c 'SELECT count(*) FROM users'
psql -U app app_db -c '\dt'               # anche i metacomandi
psql -U app app_db -f script.sql          # esegue un file
psql -U app app_db -t -A -c 'SELECT email FROM users'  # -t niente intestazione, -A no padding: per gli script
```

## Backup: pg_dump
```bash
pg_dump -U app app_db > app_db.sql                      # dump SQL plain
pg_dump -U app -Fc app_db > app_db.dump                 # formato custom (compresso, ripristinabile in parallelo)
pg_dump -U app -Fc app_db | gzip > app_db_$(date +%F).dump.gz
pg_dump -U app -t users -t orders app_db > parziale.sql # solo alcune tabelle
pg_dump -U app -s app_db > schema.sql                   # solo la struttura
pg_dumpall -U postgres > tutto.sql                      # tutti i database + ruoli
```

## Ripristino
```bash
psql -U postgres -c 'CREATE DATABASE app_db'
psql -U app app_db < app_db.sql                         # da dump plain
pg_restore -U app -d app_db app_db.dump                 # da dump custom
pg_restore -U app -d app_db -j 4 app_db.dump            # -j: parallelizza su 4 worker
gunzip -c app_db.dump.gz | pg_restore -U app -d app_db
```

## Diagnostica
```bash
psql -U postgres -c 'SELECT version()'
psql -U postgres -c 'SHOW max_connections'
psql -U postgres -d app_db -c 'SELECT pid, state, query_start, query FROM pg_stat_activity WHERE state != '\''idle'\'''
psql -U postgres -d app_db -c 'SELECT pg_terminate_backend(1234)'  # termina una connessione
psql -U postgres -d app_db -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10"
```

## Utente applicativo
```sql
CREATE USER app WITH PASSWORD 'password_lunga_e_casuale';
CREATE DATABASE app_db OWNER app;
GRANT CONNECT ON DATABASE app_db TO app;
GRANT USAGE ON SCHEMA public TO app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app;
```
