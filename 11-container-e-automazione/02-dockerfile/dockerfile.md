# Dockerfile: costruire un'immagine

Un `Dockerfile` è la ricetta di un'immagine: parte da un'immagine esistente e ci aggiunge file, pacchetti e configurazione.
```bash
docker build -t nome:tag percorso          # percorso = contesto di build: la cartella che docker può vedere (di solito .)
docker build -t nome -f altro.Dockerfile . # Dockerfile con un nome diverso
docker run nome                            # container dalla nuova immagine
```
Riferimento completo: https://docs.docker.com/reference/dockerfile/

## Le istruzioni
```dockerfile
FROM immagine:tag           # immagine di partenza: prima la cerca in locale, poi su Docker Hub. Sempre la prima riga
ARG  VERSIONE=stable        # variabile usata solo durante la build (docker build --build-arg VERSIONE=...)
ENV  APP_ENV=production     # variabile d'ambiente che resta anche nel container
WORKDIR /app                # cartella di lavoro per le istruzioni successive e per il CMD (la crea se non c'è)
COPY file.txt cartella/     # copia dal contesto di build all'immagine (percorso relativo alla WORKDIR)
COPY . .                    # copia tutto il contesto nella WORKDIR (tranne quanto escluso da .dockerignore)
ADD  archivio.tar.gz /opt/  # come COPY, ma estrae gli archivi locali e accetta URL
RUN  apt-get update && apt-get install -y curl # comando eseguito DURANTE LA BUILD: installa, compila, configura
EXPOSE 80 443               # documenta le porte del servizio (non le pubblica: serve -p al run)
VOLUME ["/var/lib/mysql"]   # cartella destinata ai dati: docker ci crea un volume anonimo se non ne monto uno
USER node                   # utente con cui girano le istruzioni successive e il container
HEALTHCHECK CMD curl -f http://localhost/ || exit 1 # come verificare che il servizio sia sano
ENTRYPOINT ["eseguibile"]   # il programma che il container esegue sempre
CMD ["param1", "param2"]    # comando di default (o argomenti di default dell'ENTRYPOINT) all'AVVIO del container
```

### RUN, CMD, ENTRYPOINT
- `RUN` gira durante `docker build`; `CMD` ed `ENTRYPOINT` girano a ogni `docker run`
- può esserci **un solo CMD effettivo**: se ce ne sono più, vale l'ultimo (vedi [python/Dockerfile](python/Dockerfile))
- `CMD` si sostituisce scrivendo un comando dopo l'immagine: `docker run immagine altro-comando`
- `ENTRYPOINT` resta fisso (si cambia solo con `docker run --entrypoint`); se c'è anche un `CMD`, questo diventa l'elenco dei suoi argomenti di default:
```dockerfile
ENTRYPOINT ["echo"]
CMD ["sto eseguendo il container"]
# docker run img           -> echo sto eseguendo il container
# docker run img ciao      -> echo ciao
```
- forma **exec** `["prog", "arg"]` (consigliata): il processo è il PID 1 e riceve i segnali, quindi `docker stop` lo ferma pulito.
  Forma **shell** `CMD prog arg`: passa da `/bin/sh -c`, che espande le variabili ma non inoltra i segnali

### COPY o ADD
`ADD` fa di più (URL, estrazione automatica degli archivi) e proprio per questo può sorprendere. Si usa `COPY`,
a meno di non volere esplicitamente l'estrazione di un `.tar`.

## Layer e cache
Ogni `RUN`, `COPY` e `ADD` crea un **layer**. Docker riusa un layer dalla cache finché l'istruzione e i file che copia
non cambiano; appena uno cambia, tutti i successivi vengono ricostruiti. Da qui due regole:

1. **prima le cose che cambiano poco**: copiare il file delle dipendenze, installarle, e solo dopo copiare il codice
```dockerfile
COPY package*.json ./        # cambia raramente
RUN npm install              # rieseguito solo se cambia package.json
COPY . .                     # cambia a ogni modifica del codice
```
2. **unire i comandi correlati in un solo RUN** e pulire nello stesso layer, altrimenti i file cancellati restano nel layer precedente
```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl git \
    && rm -rf /var/lib/apt/lists/*
```

`docker history immagine` mostra quanto pesa ogni layer.

## .dockerignore
Come `.gitignore`, ma per il contesto di build: quello che è elencato non viene inviato a docker e non finisce nell'immagine
con `COPY . .`. Build più veloce e niente segreti nell'immagine. Esempio: [node-api/.dockerignore](node-api/.dockerignore).
```
node_modules
.git
.env
vendor/
```

## Multi-stage build
Più `FROM` nello stesso file: si compila in un'immagine grande e si copia solo il risultato in una piccola.
```dockerfile
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist

FROM php:8.3-apache
COPY --from=vendor /app/vendor /var/www/html/vendor   # dallo stage "vendor" solo la cartella vendor
COPY . /var/www/html
```

## Esempi
Ogni cartella ha un `Dockerfile` con in testa i comandi per costruirlo e provarlo.

| Cartella | Cosa mostra |
|---|---|
| [nginx/](nginx/) | `FROM` + `COPY`: sostituire un file di un'immagine ufficiale |
| [python/](python/) | `WORKDIR`, `CMD`, cosa succede con due `CMD` e come si sostituisce al run |
| [flask/](flask/) | Web server: dipendenze prima del codice per sfruttare la cache, `EXPOSE`, `--host=0.0.0.0` |
| [node-api/](node-api/) | API Express: `package*.json` prima del codice, `.dockerignore`, `USER` non root |

PHP con l'estensione `mysqli` collegato a MySQL è in [../04-compose/php-mysql/](../04-compose/php-mysql/).

Il più piccolo possibile, per vedere che un'immagine derivata ha quello che l'originale non ha:
```bash
docker run --rm alpine which vim             # nessun output: alpine non ha vim

printf 'FROM alpine\nRUN apk add --no-cache vim\n' | docker build -t alpine-vim - # Dockerfile da stdin, senza contesto
docker run --rm -it alpine-vim vim                                                  # ora vim c'è
```

## Pubblicare su Docker Hub
Il nome dell'immagine deve cominciare con il proprio utente di Docker Hub.
```bash
docker build -t utente/mio-nginx:1.0 nginx/
docker login
docker push utente/mio-nginx:1.0
docker run -d -p 8080:80 utente/mio-nginx:1.0 # da qualsiasi macchina: la scarica e la avvia
```
