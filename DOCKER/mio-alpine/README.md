Una prova banale di container alpine è:
```bash
cd DOCKER
docker pull alpine
docker run -it --name=originale alpine
# se eseguo vim ho un errore perchè non è installato
```

Creo il Dockerfile per installare VIM sull'immagine originale di Alpine
```bash
docker build mio-alpine/ -t alpine-modificata
docker images | grep modif

docker run -it --name=modificato alpine-modificata
# se eseguo vim vedo che ora è installato
```


