# DOCS
1. [ ] https://docs.docker.com/get-started/
2. [ ] https://docs.docker.com/guides/docker-concepts/the-basics/what-is-an-image/
3. [ ] https://docs.docker.com/engine/reference/commandline/cli/

ESERCIZI: https://labs.play-with-docker.com/

REPOSITORY: https://hub.docker.com/_/php/tags?page=&page_size=&ordering=&name=8.0-apache
- posso registrarmi e creare un mio repo oppure esaminare quelli esistenti

---

# IMAGE

## Comandi base: pull, ls, rm
```bash
docker pull redis       # scarica l'immagine redis 
docker image pull redis # UGUALE 
docker inspect redis    # per vedere i layers di cui è composta l'immagine

docker pull ninjacloud/repository-1/immagine:latest # scarica da repository non ufficiale


docker image ls # lista immagini scaricate
docker images   # UGUALE


docker image rm pippo # rimuove l'immagine pippo
docker rmi pippo      # UGUALE

docker search ubuntu  # cerca la stringa ubuntu tra tutti i repository del docker hub    
docker history alpine # storico operazioni svolte sull'immagine alpine
```

## Crea immagine: docker build
https://linuxhub.it/articles/howto-creare-un-Dockerfile/#:~:text=Per%20eseguire%20un%20Dockerfile%20dobbiamo,nostro%20repository%20locale%20di%20Docker.
- Metto i file per creare l'immagine nella cartella `mio-python`
- Dentro creo anche il `Dockerfile`
- Cerco nel docker hub una versione di python compatibile con quella installata su Powershell
- vedo che ha alpine 3.11 e parto da quella versione di python, poi aggiungo il file e lo eseguo
```bash
docker build -t python-ciao .\mio-python\
```
Da adesso posso creare container partendo dall'immagine python-ciao da me creata

---

# CONTAINER
1. In generale i comandi si possono sempre scrivere in 2 modi:
```bash
docker container <comando>
docker <comando>
```
2. In generale i comandi si possono riferire all'ID (ab29a05c708d) o al name (confident_bose) del container



## Avvia container: docker run
Appena installato Docker, posso provare subito:
```bash
docker run hello-world           # avvia un container dell'immagine hello-world
docker container run hello-world # UGUALE
```
Se non ho mai scaricato l'immagine, lo fa lui in automatico, poi crea+avvia un container di quest'immagine

Questi container si avviano e si stoppano all'istante. Normalmente avvio un container per utilizzarne un servizio/app
```bash
docker run <image> <app>
```

## docker ps
```bash
docker container ls # mostra i container in running
docker ps           # UGUALE
docker ps -a        # mostra anche i container stopped


docker container kill nifty_feistel # stoppa il container nifty_feistel
docker container rm   nifty_feistel # rimuove il container nifty_feistel
```
```bash
docker run -it alpine /bin/sh # -it collega il mio terminale a quello del container
docker run -it ubuntu bash    # avvia la console bash su ubuntu
ps -elf                       #  dice i processi attivi in quel container (solo la bash)


docker run alpine         # si avvia e si ferma, perchè non ho richiesto nessun servizio
docker run alpine sleep 5 # si avvia e rimane in running per 5 sec, poi si ferma
docker run --name=docker_uno alpine sleep 10 # gli posso dare io il nome
```

## Container in background
```bash
docker run -d -it ubuntu bin/bash # -d per avviarlo in background
docker run -d -it --name=gino ubuntu bin/bash
```

### Esercizio - Uscire lasciando il container in background
```bash
docker run -it ubuntu bin/bash # avvia una console bash
docker run -it ubuntu bin/sh   # avvia una console sh
```
In una delle due creo un file con touch PIPPO, così da riconoscerla
CTRL+P seguito da CTRL+Q mi fa uscire dalla shell di ubuntu senza stoppare però il container
```bash
docker ps # ho ancora 2 container in running
```

## Start stop restart
```bash
docker start happy_tharp # posso dargli il name o l'ID
docker stop  happy_tharp # posso dargli il name o l'ID
```

## Rientrare in un container in running
```bash
docker attach c8d94190f48e                # posso dargli il name o l'ID
docker exec -it c8d94190f48e sh           # posso dargli il name o l'ID
docker container exec -it c8d94190f48e sh # UGUALE
```

## Comandi che posso lanciare dall'esterno su container in running
```bash
docker top   suspicious_davinci
docker stats suspicious_davinci
docker logs  suspicious_davinci
```


# Altro
```bash
docker inspect hello-world # legge il Manifest dell'immagine
docker container prune # elimina tutti i container non in running
```

## Policy di restart dei container
Di default non c'è alcun restart dei container
```bash
docker run -d -it --name=sempre --restart always         ubuntu bin/bash
docker run -d -it --name=nostop --restart unless-stopped ubuntu bin/bash
docker run -d -it --name=nostop --restart on-failure:3   ubuntu bin/bash # 3 tentativi di restart prima di fermarsi
```


# Esercizio - Getting started
```bash
docker pull docker/getting-started
docker run -d -p 80:80 docker/getting-started # fa il mapping delle porte (host:container)
docker ps
```


# Esercizio - PHP Apache
```bash
docker pull php:8.0-apache
docker run -d -p 80:80 php:8.0-apache --name mio-apache-custom -v C:\laragon\www\mio-apache:/var/www/html/
docker ps
```


# Esercizio - Web server
```bash
docker run -d -p 8080:80 nginx # fa il mapping delle porte (host:container)
docker ps
```
Se col browser vado su localhost:8080 vedrò la home di Nginx


# Esercizio - Redis
```bash
docker run -d redis
docker ps # vedo che Redis espone la porta 6379, ma io non ho ancora fatto mapping verso l'host fisico
docker run -d --name RedisHostPort -p 6379:6379 redis:latest # qui ho fatto il mapping
```

```bash
docker ps -q | docker stats # -q mostra solo gli ID; se ho più container in running, così li monitoro tutti
docker stats container_x # è come lanciare questo su tutti i container contemporaneamente


docker ps --format 'Il container {{.Names}} stà usando la immagine {{.Image}}' # formattazione dei dati
docker ps --format 'table {{.Names}} \t {{.Image}}' # li mostra in tabella
```



# Esercizio - PHP Apache BIS
- https://www.youtube.com/watch?v=bw6Iq-hIcqo (MIN 34:31)
- https://tecadmin.net/deploying-php-apache-and-mysql-with-docker-compose/

Creo l'immagine con PHP e Apache per creare un container che apre una mia `folder-php`
```bash
docker pull php:8.0-apache
docker run -d --name=server1 php:8.0-apache 
docker logs server1
docker run -d --name=server2 -p 8100:80 -v C:\laragon\www\bashbash\DOCKER\folder-php:/var/www/html/ php:8.0-apache
```
`server1` non funge perchè vanno mappati la porta e il volume, al contrario di `server2`

Per collegare anche un server mySQL creo il `Dockerfile` con le istruzioni per le librerie `mysqli`
```bash
docker build -t my-php-apache-mysqli .
```
Per farlo interagire con `mysqli` devo creare un container `mysqli` e per farli cooperare uso `DOCKER-COMPOSE`.

Creo direttamente il `docker-compose.yml` senza scaricare l'immagine mysql




- https://www.youtube.com/watch?v=97OFAcndG-4&t=600s


# Esercizio - Jenkins - Docker Swarm
https://www.youtube.com/watch?v=SPVJuNS2Bi4&t=19s
```bash
docker pull jenkins/jenkins:lts
docker run -d --name mio-jenk -p 8081:8080 -p 50001:50000 jenkins/jenkins
docker ps

docker swarm
docker swarm init
docker swarm init --advertise-addre 192.168.0.16 # inserisco il mio IP
```

```bash
docker swarm join --token SWMTKN-1-3o42wwkdbanz1qoupsp2ympr4ffkbyzmvj56gdtx0qo7jab70y-392dj3vltlddajkiq3g25fgje 192.168.65.3:2377
docker swarm join --token SWMTKN-1-4k4q7d1lbsvdoukrkdy8n9qcxnc1is1sysk6gviy2uyvznmns0-d7mjmf89pkdxhrbgbb789biym 192.168.0.17:2377
```

```bash
docker node ls
docker service ls
docker network ls
docker inspect bridge

docker service create -d --name serv-jenk -p 80002:8080 jenkins/jenkins
docker service ls
docker service ps jenkins
docker service update jenkins --replicas 5
docker service ls
docker service ps jenkins
```


