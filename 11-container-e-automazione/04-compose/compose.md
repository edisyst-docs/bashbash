# docker compose

Descrive in un file YAML più container che lavorano insieme (web server, database, cache) e li gestisce con un comando solo.
Compose crea anche una rete per il progetto, in cui ogni servizio si raggiunge con il suo **nome**.

- il file si chiama `compose.yaml` (vanno bene anche `docker-compose.yml` e le varianti `.yml`/`.yaml`)
- il comando moderno è `docker compose` (plugin v2). Il vecchio `docker-compose` col trattino è deprecato: stessi sottocomandi
- la riga `version: '3.8'` in testa ai file vecchi è obsoleta e viene ignorata: si omette
- il nome del progetto è quello della cartella; container, reti e volumi prendono il prefisso `progetto-` (es. `php-mysql-database-1`)

Riferimento del file: https://docs.docker.com/reference/compose-file/

## Il file
```yaml
services:
  app:                                   # nome del servizio: è anche il suo hostname sulla rete del progetto
    build: .                             # costruisce dal Dockerfile nella cartella indicata...
    image: mia-app:1.0                   # ...e dà questo nome all'immagine (senza build: la scarica)
    container_name: app                  # nome fisso del container (impedisce di scalare il servizio)
    ports:
      - "8080:80"                        # host:container, tra virgolette (YAML legge 22:22 come numero in base 60)
      - "127.0.0.1:9000:9000"            # solo dal PC
    volumes:
      - ./:/var/www/html                 # bind mount (percorso che comincia con . o /)
      - dati:/var/lib/app                # volume con nome, dichiarato in fondo
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    environment:
      APP_ENV: local
      DB_HOST: db
    env_file: .env                       # variabili da file
    depends_on:
      db:
        condition: service_healthy       # aspetta l'healthcheck di db (la forma breve "- db" aspetta solo l'avvio)
    restart: unless-stopped
    networks: [backend]
    command: php artisan serve --host=0.0.0.0 # sostituisce il CMD dell'immagine
    profiles: [debug]                    # parte solo con --profile debug

  db:
    image: mysql:8.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1"]
      interval: 5s
      retries: 20
    networks: [backend]

volumes:
  dati:                                  # docker crea il volume progetto_dati

networks:
  backend:                               # se non se ne dichiarano, compose ne crea una "default"
```

### Variabili
Compose legge un file `.env` nella stessa cartella e sostituisce `${VARIABILE}` nel YAML:
```yaml
    image: "mysql:${MYSQL_VERSION:-8.0}"  # :- valore di default se la variabile non c'è
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:?manca DB_ROOT_PASSWORD} # :? errore se manca
```
`docker compose config` mostra il file finale con le variabili risolte.

### Inizializzare un database
Le immagini ufficiali di MySQL, MariaDB e PostgreSQL eseguono i file `.sql`, `.sql.gz` e `.sh` che trovano in
`/docker-entrypoint-initdb.d`, in ordine alfabetico, **solo al primo avvio** (quando il volume dei dati è vuoto).
Si monta lì una cartella di script: vedi [mysql-phpmyadmin/](mysql-phpmyadmin/) e [postgres/](postgres/).
Per rieseguirli bisogna cancellare il volume: `docker compose down -v`.

> **NOTA**: durante l'inizializzazione MySQL gira un server temporaneo senza rete. Un healthcheck con `-h localhost`
> usa il socket e risulta "sano" troppo presto; con `-h 127.0.0.1` passa da TCP e aspetta il server vero.

### Ancore YAML
Evitano di ripetere la stessa configurazione per più servizi:
```yaml
x-base: &base                          # ancora (nome scelto dall'utente; x- è convenzione per estensioni compose)
  restart: unless-stopped
  logging:
    driver: "json-file"
    options: { max-size: "10m", max-file: "3" }

services:
  app:
    <<: *base                          # merge: incolla tutto il blocco &base
    image: mia-app:1.0

  worker:
    <<: *base                          # stesso blocco riusato
    image: mia-app:1.0
    command: php artisan queue:work
```

### File di override
Il secondo file sovrascrive o aggiunge campi del primo; utile per differenziare sviluppo e produzione:
```yaml
# compose.override.yaml (caricato in automatico da compose up se esiste accanto a compose.yaml)
services:
  app:
    ports: ["8080:80"]                 # porta esposta in sviluppo
    volumes:
      - .:/var/www/html                # bind mount del codice in sviluppo
    environment:
      APP_DEBUG: "true"
```
```bash
docker compose up -d                  # usa compose.yaml + compose.override.yaml in automatico
docker compose -f compose.yaml -f compose.prod.yaml up -d  # produzione: secondo file esplicito
```

## I comandi
Vanno lanciati nella cartella del `compose.yaml` (o con `-f percorso`).
```bash
docker compose config                     # valida il file e mostra il risultato dopo variabili e override
docker compose up -d                      # crea e avvia tutti i servizi in background
docker compose up -d --build              # ricostruisce le immagini prima di avviare
docker compose up -d --wait               # aspetta che i servizi siano avviati e healthy prima di tornare
docker compose up -d app                  # solo un servizio (e quelli da cui dipende)
docker compose up -d --scale web=3        # tre container del servizio web (senza container_name e senza porta fissa)
docker compose ps                         # stato dei servizi
docker compose logs -f app                # log di un servizio
docker compose exec app bash              # shell nel servizio "app"
docker compose exec app php artisan migrate # comando nel servizio
docker compose exec -T app php artisan migrate --force # -T: niente terminale, necessario in cron e nelle pipeline CI
docker compose run --rm app composer install # container temporaneo del servizio per un comando una tantum
docker compose restart app                # riavvia un servizio
docker compose stop                       # ferma senza eliminare
docker compose start                      # riavvia quelli fermati
docker compose down                       # ferma ed elimina container e reti (i volumi RESTANO)
docker compose down -v                    # ATTENZIONE: elimina anche i volumi, cioè i dati del database
docker compose pull && docker compose up -d # aggiorna le immagini e ricrea solo i container cambiati
docker compose -f compose.yaml -f compose.prod.yaml up -d # il secondo file sovrascrive/integra il primo
docker compose --profile debug up -d      # attiva anche i servizi del profilo "debug"
docker compose -p altro up -d             # nome di progetto diverso: una seconda copia indipendente
```

Aspettare che un servizio sia pronto prima di proseguire, in uno script di CI (oggi basta `up -d --wait`):
```bash
docker compose up -d
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q mysql)")" = healthy ]; do
    echo "attendo mysql..."; sleep 2
done
docker compose exec -T app php artisan migrate --force
```

## Laboratori
| Cartella | Servizi | Cosa mostra |
|---|---|---|
| [php-mysql/](php-mysql/) | Apache+PHP, MySQL | `build`, bind mount del codice, variabili passate a PHP, `depends_on` con healthcheck |
| [mysql-phpmyadmin/](mysql-phpmyadmin/) | MySQL, phpMyAdmin | database popolato al primo avvio da `init/` |
| [postgres/](postgres/) | PostgreSQL, pgAdmin | import automatico, esercizi SQL da lanciare con `psql` |

Altri esempi completi: [../08-ansible/laboratorio/](../08-ansible/laboratorio/) (master Ansible + due server),
[../07-jenkins/](../07-jenkins/) (Jenkins con Docker in Docker e agenti), [../../10-rete-e-web/05-load-balancer/](../../10-rete-e-web/05-load-balancer/) (profili, ancore YAML).
