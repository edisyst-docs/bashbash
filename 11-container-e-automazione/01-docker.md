# docker da riga di comando

Uso quotidiano della CLI: immagini e container. Come si scrive un Dockerfile è in [02-dockerfile.md](02-dockerfile.md),
volumi e reti in [03-volumi-e-reti.md](03-volumi-e-reti.md), `docker compose` in [04-compose/](04-compose/).

- **immagine**: il modello in sola lettura, fatto di layer sovrapposti (es. `nginx:alpine`). Si scarica da un registry (Docker Hub) o si costruisce con un Dockerfile
- **container**: un'istanza in esecuzione di un'immagine, con il suo filesystem scrivibile sopra i layer. Muore quando termina il suo processo principale
- quasi ogni comando esiste in due forme: `docker container ls` e `docker ps`, `docker image rm` e `docker rmi`. Sono equivalenti
- un container si indica con il **nome** o con l'**ID** (bastano i primi caratteri, es. `ab29`)

Documentazione: https://docs.docker.com/get-started/ · riferimento CLI: https://docs.docker.com/reference/cli/docker/
Per esercitarsi senza installare nulla: https://labs.play-with-docker.com/ (lì copia e incolla sono `CTRL+INS` e `SHIFT+INS`).

## Immagini
```bash
docker pull redis                         # scarica l'ultima versione (tag implicito :latest)
docker pull php:8.3-fpm                   # scarica un tag preciso: in produzione sempre un tag, mai latest
docker image pull redis                   # UGUALE a docker pull redis
docker pull utente/repository:1.0         # immagine non ufficiale: prefisso con l'utente di Docker Hub
docker search ubuntu                      # cerca su Docker Hub
docker images                             # immagini scaricate
docker image ls                           # UGUALE
docker images | grep mod                  # solo quelle che contengono "mod" nel nome
docker history alpine                     # layer e dimensione di ciascuno: per capire cosa pesa
docker inspect redis                      # tutti i dettagli in JSON, compresi i layer
docker rmi mia-app:1.0                    # elimina un'immagine
docker image rm mia-app:1.0               # UGUALE

docker build -t mia-app:1.0 .             # costruisce dal Dockerfile nella cartella corrente
docker build -t mia-app:1.0 ./cartella    # il contesto di build è ./cartella (lì cerca il Dockerfile)
docker build --no-cache -t mia-app:1.0 .  # UGUALE ignorando la cache (se un layer "non si aggiorna")
docker tag mia-app:1.0 utente/mia-app:1.0 # secondo nome per la stessa immagine: serve per pubblicarla
docker login                              # accesso a Docker Hub (una volta)
docker push utente/mia-app:1.0            # pubblica sul proprio repository
```

## Avviare un container: docker run
`docker run` = `pull` (se l'immagine manca) + `create` + `start`. **Le opzioni vanno prima del nome dell'immagine**:
tutto ciò che sta dopo è il comando da eseguire nel container.
```bash
docker run hello-world                    # prova l'installazione: stampa un messaggio ed esce
docker run alpine                         # parte ed esce subito: non ha un processo che resti vivo
docker run alpine sleep 5                 # resta in esecuzione 5 secondi, poi termina
docker run -it ubuntu bash                # -i stdin aperto + -t terminale: shell interattiva nel container
docker run -it alpine sh                  # le immagini alpine non hanno bash, solo sh
docker run --rm -it ubuntu bash           # container usa e getta: --rm lo elimina all'uscita
docker run -d --name web -p 8080:80 nginx # background (-d), nome "web", porta 8080 del PC -> 80 del container
docker run -d -p 127.0.0.1:8080:80 nginx  # porta raggiungibile solo dal PC, non dalla rete
docker run -d -P nginx                    # -P: pubblica le porte EXPOSE su porte casuali del PC
docker run -d --name db -e MYSQL_ROOT_PASSWORD=segreta mysql:8.0 # -e: variabile d'ambiente
docker run -d --env-file .env mia-app     # variabili lette da un file
docker run --rm -v "$PWD":/app -w /app composer install # esegue composer senza installarlo: monta la cartella corrente in /app
docker run --rm --entrypoint sh -it nginx # sostituisce l'ENTRYPOINT dell'immagine
docker run -d --memory 512m --cpus 1 app  # limiti di risorse
```
In PowerShell `"$PWD"` funziona uguale; in CMD si usa `%cd%`. Per andare a capo in PowerShell si usa il backtick `` ` `` invece di `\`.

### Uscire senza fermare il container
In un container avviato con `-it`:
- `CTRL+P` seguito da `CTRL+Q`: esce e lo lascia in esecuzione (detach)
- `CTRL+D` o `exit`: termina la shell, cioè il processo principale, e quindi il container

```bash
docker attach web                         # si ricollega al processo PRINCIPALE (uscire con CTRL+P CTRL+Q)
docker exec -it web bash                  # apre un NUOVO processo: exit chiude solo questo, il container resta
```

### Policy di riavvio
Di default un container fermo resta fermo, anche dopo un riavvio del PC.
```bash
docker run -d --restart unless-stopped nginx # riparte sempre, tranne se l'ho fermato io: la più usata
docker run -d --restart always nginx         # riparte sempre, anche se l'ho fermato (al riavvio del demone)
docker run -d --restart on-failure:3 app     # riparte solo se esce con errore, massimo 3 tentativi
docker update --restart unless-stopped web   # cambia la policy di un container esistente
```

## Gestire i container
```bash
docker ps                                 # container in esecuzione
docker container ls                       # UGUALE
docker ps -a                              # anche quelli fermi
docker ps -q                              # solo gli ID: utile da passare ad altri comandi
docker stop web && docker start web       # ferma / riavvia (stop manda SIGTERM e dopo 10 s SIGKILL)
docker restart web                        # UGUALE in un solo comando
docker kill web                           # SIGKILL immediato
docker rm web                             # elimina un container fermo
docker rm -f web                          # elimina anche se in esecuzione
docker exec -it web bash                  # shell dentro un container attivo (sh se bash non c'è)
docker exec web nginx -t                  # esegue un singolo comando dentro il container
docker exec -u www-data app id            # come un altro utente
docker logs -f --tail 100 web             # log (stdout/stderr del container), ultimi 100 e poi in diretta
docker logs --since 10m web               # log degli ultimi 10 minuti
docker cp web:/etc/nginx/nginx.conf .     # copia un file dal container al PC (funziona anche al contrario)
docker port web                           # quali porte sono pubblicate e dove
docker inspect web                        # tutti i dettagli in JSON
docker inspect -f '{{.State.Status}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web # solo alcuni campi (template Go): stato e IP
docker stats                              # CPU, RAM, rete di tutti i container attivi, in diretta
docker stats --no-stream web db           # solo alcuni, una sola volta
docker top web                            # processi dentro il container, visti dall'host
docker diff web                           # file aggiunti (A), cambiati (C), eliminati (D) rispetto all'immagine
```

### Formattare l'output
`--format` accetta un template Go: i campi sono `{{.ID}}`, `{{.Names}}`, `{{.Image}}`, `{{.Ports}}`, `{{.Status}}`,
`{{.Command}}`, `{{.CreatedAt}}`. Con `table` davanti ottiene le intestazioni e l'allineamento.
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'      # ps con colonne scelte
docker ps --format '{{.Names}} usa {{.Image}}'                      # una frase per container
docker ps --format "ID\t{{.ID}}\nNOME\t{{.Names}}\nPORTE\t{{.Ports}}\n" # una scheda per container
```
Per non riscriverlo ogni volta si mette in `~/.docker/config.json`: `{ "psFormat": "table {{.Names}}\t{{.Status}}\t{{.Ports}}" }`.

## Salvare e spostare container e immagini
```bash
docker commit web mio-nginx:modificato   # crea un'IMMAGINE dallo stato attuale del container (meglio un Dockerfile)
docker save -o nginx.tar nginx:alpine     # immagine -> file tar, con layer e storia: per portarla su una macchina offline
docker load -i nginx.tar                  # file tar -> immagine
docker export web > web.tar               # filesystem del container -> tar (senza layer né metadati)
docker import web.tar mio-web:1.0         # tar -> immagine a un solo layer (CMD ed ENV vanno ridefiniti)
```

## Pulizia dello spazio
```bash
docker system df                          # quanto spazio occupano immagini, container, volumi, cache di build
docker container prune                    # elimina i container fermi
docker image prune                        # elimina le immagini "dangling" (<none>)
docker image prune -a                     # elimina TUTTE le immagini non usate da un container
docker builder prune                      # svuota la cache di build (spesso la voce più grossa)
docker system prune                       # tutto quanto sopra insieme (container, reti, immagini dangling), tranne i volumi
docker volume prune                       # ATTENZIONE: volumi non collegati a nessun container, dati compresi
```

## Esempi pratici
```bash
docker exec -i mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" app | gzip > app_$(date +%F).sql.gz # backup del DB di un container
gunzip -c app_2026-09-25.sql.gz | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" app  # ripristino (-i: passa lo stdin al container)

docker run --rm -v mysql_data:/dati -v "$PWD":/backup alpine tar -czf /backup/mysql_data.tar.gz -C /dati . # backup di un VOLUME con un container usa e getta

docker ps -q | xargs -r docker stop                             # ferma tutti i container attivi
docker ps -a --filter status=exited --format '{{.Names}}'       # container usciti (magari con errore)
docker inspect -f '{{.State.ExitCode}} {{.State.Error}}' app    # perché è uscito
docker inspect -f '{{json .State.Health}}' app | jq              # esito dell'healthcheck
docker events --since 1h --filter event=die                     # container morti nell'ultima ora

docker exec -u www-data app php artisan cache:clear # esegue come utente www-data: evita file di cache creati da root
```

Servizi pronti all'uso, da provare con il browser:
```bash
docker run -d --name web -p 8080:80 nginx                       # http://localhost:8080: home di Nginx
docker run -d --name redis -p 6379:6379 redis                   # senza -p Redis gira ma non è raggiungibile dal PC
docker run -d --name php -p 8100:80 -v "$PWD":/var/www/html php:8.3-apache # Apache+PHP che serve la cartella corrente
docker run -d -p 80:80 docker/getting-started                   # il tutorial ufficiale, in locale
```

Un comando artisan dentro un container Laravel:
```bash
docker exec -it laravel php artisan list
docker exec -it laravel composer require laravel/ui --dev
docker exec -it laravel php artisan migrate --force
```
