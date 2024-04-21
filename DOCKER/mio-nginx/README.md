Una prova banale di container nginx è:
```bash
cd DOCKER
docker pull nginx
docker run -p 8080:80 --name=originale nginx
# se vado sulla mia porta 8080 vedo la home di nginx
```

Creo il Dockerfile per modificare la home di nginx, sostituendo il file
```bash
docker build mio-nginx/ -t edisyst/nginx-mod:latest
docker images
docker images | grep modif

docker login
docker push edisyst/nginx-mod

docker run -p 8080:80 --name=modificato edisyst/nginx-mod
# se vado sulla mia porta 8080 ora vedo la mia index.html personalizzata
```


