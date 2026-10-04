# Apache+PHP e MySQL

| File | Contenuto |
|---|---|
| [compose.yaml](compose.yaml) | I due servizi: `php-apache` costruito dal Dockerfile, `database` con healthcheck e volume |
| [Dockerfile](Dockerfile) | `php:8.3-apache` + estensione `mysqli` |
| [index.php](index.php) | Si collega al database leggendo host e credenziali dalle variabili d'ambiente |

```bash
docker compose up -d --build   # poi http://localhost:8100 -> "Connesso a MySQL 8.0.x"
docker compose logs database   # se qualcosa non va
docker compose down -v         # smonta tutto, database compreso
```
L'host del database in PHP è `database`, il nome del servizio: dentro il container `localhost` è il container PHP stesso.
Dal PC, invece, MySQL è su `localhost:9100`.

Torna a [../](../)
