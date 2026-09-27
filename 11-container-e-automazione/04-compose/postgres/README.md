# PostgreSQL + pgAdmin

| File | Contenuto |
|---|---|
| [compose.yaml](compose.yaml) | PostgreSQL 17 e pgAdmin 4, ognuno con il suo volume |
| [init/ecommerce.sql](init/ecommerce.sql) | Schema e dati di un piccolo e-commerce (prodotti, clienti, ordini), importato al primo avvio |
| [query-esercizi.sql](query-esercizi.sql) | 16 query di esercizio: SELECT, JOIN, aggregazioni, subquery, window function, CTE |

```bash
docker compose up -d
docker compose exec db psql -U postgres -d ecommerce                        # client interattivo (\dt tabelle, \q esce)
docker compose exec -T db psql -U postgres -d ecommerce < query-esercizi.sql # tutte le query del file
docker compose down -v                                                      # smonta e cancella i dati
```

## pgAdmin
1. http://localhost:8080, accesso con `admin@example.com` / `admin`
2. *Register > Server*: nella scheda **General** un nome qualsiasi; nella scheda **Connection**:
   - Host: `db` (il nome del servizio, non `localhost`: pgAdmin è in un altro container)
   - Port `5432`, database `ecommerce`, utente `postgres`, password `secret`, spuntare *Save password*
3. Le tabelle sono in *Databases > ecommerce > Schemas > public > Tables*
4. *Tools > Query Tool*: incollare le query di [query-esercizi.sql](query-esercizi.sql) ed eseguirle con `F5`

Il tema scuro è in *File > Preferences > User Interface > Theme*.

Torna a [../](../)
