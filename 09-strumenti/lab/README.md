# Laboratorio dell'area 09

Qui non bastano dei file: servono un server MySQL e un'API HTTP. [compose.yaml](compose.yaml) avvia tre container
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

Torna all'[indice dell'area](../README.md)
