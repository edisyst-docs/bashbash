# MySQL popolato + phpMyAdmin

| File | Contenuto |
|---|---|
| [compose.yaml](compose.yaml) | MySQL 8 con `./init` montata in `/docker-entrypoint-initdb.d`, phpMyAdmin collegato |
| [init/01-employees.sql](init/01-employees.sql) | Schema del database di esempio `employees` (tabelle e viste) |
| [init/02-departments.sql](init/02-departments.sql) | I 9 dipartimenti |

```bash
docker compose up -d                   # phpMyAdmin su http://localhost:8888 (root / mysqlroot)
docker compose exec db mysql -uroot -pmysqlroot employees -e 'SELECT * FROM departments'
docker compose down -v                 # smonta e cancella il DB: al prossimo up gli script ripartono
```

## Il database completo
`employees` è il database di prova di MySQL (https://github.com/datacharmer/test_db): circa 300.000 dipendenti
e 2,8 milioni di stipendi, utile per esercitarsi con query lente e indici. Qui ci sono solo schema e dipartimenti;
i dati (~170 MB) si scaricano dal repository:
```bash
git clone --depth 1 https://github.com/datacharmer/test_db.git /tmp/test_db
n=3
for f in employees dept_emp dept_manager titles salaries1 salaries2 salaries3; do
    { echo "USE employees;"; cat /tmp/test_db/load_$f.dump; } > init/0${n}-$f.sql   # l'ordine rispetta le chiavi esterne
    n=$((n+1))
done
docker compose down -v && docker compose up -d   # il primo avvio dura qualche minuto
```
I file scaricati non finiscono nel repository: li esclude [init/.gitignore](init/.gitignore).

Torna a [../](../)
