# docker e docker compose da riga di comando

Uso quotidiano della CLI. Per scrivere Dockerfile e compose file servono appunti a parte.

## Container
```bash
docker ps                                 # container in esecuzione
docker ps -a                              # anche quelli fermi
docker run -d --name web -p 8080:80 nginx # avvia in background (-d), nome "web", porta 8080 del PC -> 80 del container
docker run --rm -it ubuntu bash           # container usa e getta interattivo: --rm lo elimina all'uscita
docker run --rm -v "$PWD":/app -w /app composer install # esegue composer senza installarlo: monta la cartella corrente in /app
docker stop web && docker start web       # ferma / riavvia
docker rm -f web                          # elimina (anche se in esecuzione, con -f)
docker exec -it web bash                  # shell dentro un container attivo (sh se bash non c'è, es. immagini alpine)
docker exec web nginx -t                  # esegue un singolo comando dentro il container
docker logs -f --tail 100 web             # log (stdout/stderr del container), ultimi 100 e poi in diretta
docker logs --since 10m web               # log degli ultimi 10 minuti
docker cp web:/etc/nginx/nginx.conf .     # copia un file dal container al PC (funziona anche al contrario)
docker inspect web                        # tutti i dettagli in JSON
docker inspect -f '{{.State.Status}} {{.NetworkSettings.IPAddress}}' web # solo alcuni campi (template Go)
docker stats --no-stream                  # CPU, RAM, rete di ogni container, una sola volta
docker top web                            # processi dentro il container
```

## Immagini, volumi, reti
```bash
docker images                             # immagini scaricate
docker pull php:8.3-fpm                   # scarica
docker build -t mia-app:1.0 .             # costruisce dal Dockerfile nella cartella corrente
docker build --no-cache -t mia-app:1.0 .  # UGUALE ignorando la cache (se un layer "non si aggiorna")
docker history mia-app:1.0                # layer e dimensione di ciascuno: per capire cosa pesa
docker rmi mia-app:1.0                    # elimina un'immagine

docker volume ls                          # volumi (dove vivono i dati persistenti, es. il DB)
docker volume inspect mysql_data          # dove si trova sul disco
docker network ls                         # reti
docker network inspect progetto_default   # quali container sono collegati e con che IP
```

## docker compose
Tutti i comandi vanno lanciati nella cartella del `compose.yaml` (o con `-f percorso`).
> **NOTA**: il comando moderno è `docker compose` (plugin v2). Il vecchio `docker-compose` col trattino è deprecato.
```bash
docker compose up -d                      # avvia tutti i servizi in background
docker compose up -d --build              # ricostruisce le immagini prima di avviare
docker compose ps                         # stato dei servizi
docker compose logs -f app                # log di un servizio
docker compose exec app bash              # shell nel servizio "app"
docker compose exec app php artisan migrate # comando nel servizio
docker compose run --rm app composer install # container temporaneo del servizio per un comando una tantum
docker compose restart app                # riavvia un servizio
docker compose stop                       # ferma senza eliminare
docker compose down                       # ferma ed elimina container e reti (i volumi RESTANO)
docker compose down -v                    # ATTENZIONE: elimina anche i volumi, cioè i dati del database
docker compose config                     # compose finale dopo aver risolto variabili e override: per il debug
docker compose pull && docker compose up -d # aggiorna le immagini e ricrea solo i container cambiati
```

## Pulizia dello spazio
```bash
docker system df                          # quanto spazio occupano immagini, container, volumi, cache di build
docker container prune                    # elimina i container fermi
docker image prune                        # elimina le immagini "dangling" (<none>)
docker image prune -a                     # elimina TUTTE le immagini non usate da un container
docker builder prune                      # svuota la cache di build (spesso la voce più grossa)
docker system prune                       # tutto quanto sopra insieme, tranne i volumi
docker volume prune                       # ATTENZIONE: volumi non collegati a nessun container, dati compresi
```

## Esempi pratici
```bash
docker exec -i mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" app | gzip > app_$(date +%F).sql.gz # backup del DB di un container
gunzip -c app_2026-09-25.sql.gz | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" app  # ripristino (-i: passa lo stdin al container)

docker run --rm -v mysql_data:/dati -v "$PWD":/backup alpine tar -czf /backup/mysql_data.tar.gz -C /dati . # backup di un VOLUME con un container usa e getta

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' # ps con colonne scelte
docker ps -q | xargs -r docker stop                             # ferma tutti i container attivi
docker ps -a --filter status=exited --format '{{.Names}}'       # container usciti (magari con errore)
docker inspect -f '{{.State.ExitCode}} {{.State.Error}}' app    # perché è uscito
docker inspect -f '{{json .State.Health}}' app | jq              # esito dell'healthcheck
docker events --since 1h --filter event=die                     # container morti nell'ultima ora

docker exec -u www-data app php artisan cache:clear # esegue come utente www-data: evita file di cache creati da root
docker compose exec -T app php artisan migrate --force # -T: niente terminale, necessario in cron e nelle pipeline CI
```

Aspettare che un servizio sia pronto prima di proseguire (es. in uno script di CI):
```bash
docker compose up -d
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q mysql)")" = healthy ]; do
    echo "attendo mysql..."; sleep 2
done
docker compose exec -T app php artisan migrate --force
```
