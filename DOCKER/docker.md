DOCS: 
https://docs.docker.com/get-started/
https://docs.docker.com/guides/docker-concepts/the-basics/what-is-an-image/
https://docs.docker.com/engine/reference/commandline/cli/

ESERCIZIO: https://labs.play-with-docker.com/

REPOSITORY (posso anche loggarmi e crearne uno mio oppure esaminare quelli esistenti): https://hub.docker.com/layers/library/centos/centos7.7.1908/images/sha256-8f2c78ca3141051eef77fb083066222abf20330a2345c970a5a61427aeb2dc7b


# IMAGE

## Scarica immagine: pull image

docker pull redis       # scarica l'immagine redis 
docker image pull redis # UGUALE 
docker inspect redis    # per vedere i layers di cui è composta l'immagine

docker pull ninjacloud/repository-1/immagine:latest # scarica da repository non ufficiale

docker image ls # lista immagini scaricate
docker images   # UGUALE

docker image rm pippo # rimuove l'immagine pippo
docker search ubuntu  # cerca la stringa ubuntu tra tutti i repository del docker hub    
docker history alpine # storico operazioni svolte sull'immagine alpine


## Crea immagine: docker build
Prendo i file della cartella creata. Cerco una versione di python compatibile con quella installata su Powershell, vedo che ha alpine 3.11 e parto da quella versione di python, poi aggiungo il file e lo eseguo

docker build -t python-ciao .\docker-immagine\



# CONTAINER

In generale i comandi si possono sempre scrivere
docker container <comando>
docker <comando>

In generale i comandi si possono riferire all'ID (ab29a05c708d) o al name (confident_bose) del container




# Avvia container: docker run

Anche appena installato Docker, posso provare subito:

docker run hello-world           # avvia un container dell'immagine hello-world
docker container run hello-world # UGUALE

Se non ho mai scaricato l'immagine, lo fa lui in automatico e poi crea+avvia un container di essa

Questi container si avviano e si stoppano all'istante. Normalmente avvio un container per utilizzarne un servizio/app

docker run <image> <app>


# docker ps

docker container ls # mostra i container in running
docker ps           # UGUALE
docker ps -a        # mostra anche i container stopped

docker container kill nifty_feistel # stoppa il container nifty_feistel
docker container rm   nifty_feistel   # rimuove il container nifty_feistel

docker run -it ubuntu bash    # avvia la console bash su ubuntu
docker run -it alpine /bin/sh # -it collega il mio terminale a quello del container

docker run alpine         # si avvia e si ferma, perchè non ho richiesto nessun servizio
docker run alpine sleep 5 # si avvia e rimane in running per 5 sec
docker run --name=docker_uno alpine sleep 10 # gli posso dare io il nome


## Container in background

docker run -d -it ubuntu bin/bash # -d per avviarlo 
docker run -d -it --name=gino ubuntu bin/bash


## Esercizio - Uscire lasciando il container in background

docker run -it ubuntu bin/bash # avvia una console bash
docker run -it ubuntu bin/sh   # avvia una console sh

In una delle due creo un file con touch PIPPO, così da riconoscerla
CTRL+P seguito da CTRL+Q mi fa uscire dalla shell di ubuntu senza stoppare però il container

docker ps # ho ancora 2 container in running


# Esci e stoppa: docker stop

docker stop happy_tharp # posso dargli il name o l'ID
docker ps # ho solo 1 container in running

Dentro il container ancora attivo digito
ps -elf #  mi dice i processi arrivi dentro quel container (solo la bash)
Posso anche digitare "exit" nella console del container per uscire


# Start/restart: docker start

docker start happy_tharp # posso dargli il name o l'ID


# Rientrare in un container in running

docker attach c8d94190f48e                # posso dargli il name o l'ID
docker exec -it c8d94190f48e sh           # posso dargli il name o l'ID
docker container exec -it c8d94190f48e sh # UGUALE


## Comandi che posso lanciare dall'esterno su container in running

docker top   suspicious_davinci
docker stats suspicious_davinci
docker logs  suspicious_davinci


# Policy di restart dei container
Di default non c'è alcun restart dei container

docker run -d -it --name=sempre --restart always         ubuntu bin/bash
docker run -d -it --name=nostop --restart unless-stopped ubuntu bin/bash
docker run -d -it --name=nostop --restart on-failure:3   ubuntu bin/bash # 3 tentativi di restart prima di fermarsi



# Esercizio - Web server

docker run -d -p 8080:80 nginx # fa il mapping delle porte (host:container)
docker ps

Se col browser vado su localhost:8080 vedrò la home di Nginx


# Esercizio - Redis

docker run -d redis
docker ps # vedo che Redis espone la porta 6379, ma io non ho ancora fatto mapping verso l'host fisico
docker run -d --name RedisHostPort -p 6379:6379 redis:latest # qui ho fatto il mapping

docker ps -q | docker stats # -q mostra solo gli ID; se ho più container in running, con questa riga li monitoro tutti quanti
docker stats container_x # è come lanciare questo su tutti i container contemporaneamente

docker ps --format 'Il container {{.Names}} stà usando la immagine {{.Image}}' # formattazione dei dati
docker ps --format 'table {{.Names}} \t {{.Image}}' # li mostra in tabella


# Altro

docker inspect hello-world # legge il Manifest dell'immagine
docker container prune # elimina tutti i container non in running



CERCA TUTORIAL CONSOLE DI GESTIONE DI HYPER-V DI WINDOWS




