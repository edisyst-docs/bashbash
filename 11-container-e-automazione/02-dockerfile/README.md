# 02 - Dockerfile

| File | Contenuto |
|---|---|
| [dockerfile.md](dockerfile.md) | Le istruzioni, `RUN`/`CMD`/`ENTRYPOINT`, layer e cache, `.dockerignore`, multi-stage, pubblicare su Docker Hub |
| [nginx/](nginx/) | Nginx con una home personalizzata |
| [python/](python/) | Script Python: `WORKDIR` e `CMD` |
| [flask/](flask/) | Web server Flask con le dipendenze in un layer a parte |
| [node-api/](node-api/) | API Node/Express con `.dockerignore` e utente non root |

```bash
cd nginx && docker build -t mio-nginx . && docker run -d --name mio-nginx -p 8080:80 mio-nginx   # http://localhost:8080
docker rm -f mio-nginx                                                                           # pulizia
```
Serve Docker; ogni esempio ha in testa al `Dockerfile` i suoi comandi.

Torna a [../](../)
