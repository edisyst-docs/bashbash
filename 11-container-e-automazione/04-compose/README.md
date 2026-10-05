# 04 - docker compose

| File | Contenuto |
|---|---|
| [compose.md](compose.md) | Il file `compose.yaml`, variabili, init dei database, tutti i comandi |
| [php-mysql/](php-mysql/) | Apache+PHP con `mysqli` collegato a MySQL |
| [mysql-phpmyadmin/](mysql-phpmyadmin/) | MySQL popolato con il database di esempio `employees` + phpMyAdmin |
| [postgres/](postgres/) | PostgreSQL con un piccolo e-commerce + pgAdmin, ed esercizi SQL |

Serve Docker. Ogni laboratorio parte con `docker compose up -d` dalla sua cartella e si smonta con `docker compose down -v`: comandi e indirizzi sono nel README di ciascuno.

Torna a [../](../)
