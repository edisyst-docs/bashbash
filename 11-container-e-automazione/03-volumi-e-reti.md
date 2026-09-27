# Volumi e reti

Il filesystem di un container sparisce con il container: i dati da conservare vanno in un **volume** o in una cartella
del PC (**bind mount**). I container parlano fra loro, e con l'esterno, attraverso le **reti** di docker.

## Volumi
| Tipo | Sintassi `-v` | Dove stanno i dati | Uso tipico |
|---|---|---|---|
| volume con nome | `-v dati:/var/lib/mysql` | gestiti da docker (`/var/lib/docker/volumes/`) | database, dati persistenti |
| bind mount | `-v /percorso/sul/pc:/app` | una cartella del PC | codice in sviluppo, file di configurazione |
| volume anonimo | `-v /var/lib/mysql` | come i volumi, con un nome casuale | creato da `VOLUME` nel Dockerfile |
| tmpfs | `--tmpfs /tmp` | in RAM, sparisce allo stop | file temporanei |

Se il primo elemento di `-v` contiene `/` (o `C:\`) è un bind mount, altrimenti è il nome di un volume.
La forma lunga `--mount type=bind,source=...,target=...` fa la stessa cosa ed è più esplicita.

```bash
docker volume create dati                 # crea un volume (non serve: -v lo crea al primo uso)
docker volume ls                          # elenco
docker volume inspect dati                # dove si trova sul disco
docker volume rm dati                     # elimina (solo se nessun container lo usa)
docker run -d -v dati:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=x mysql:8.0 # il DB sopravvive all'eliminazione del container
docker run -d -v "$PWD":/usr/share/nginx/html:ro -p 8080:80 nginx       # bind mount in sola lettura (:ro)
docker run -d -v "$PWD/nginx.conf":/etc/nginx/nginx.conf:ro nginx       # si può montare anche un singolo file
docker run --rm --volumes-from db -v "$PWD":/backup alpine tar czf /backup/db.tgz /var/lib/mysql # monta gli stessi volumi di "db"
```
Con un bind mount le modifiche fatte sul PC si vedono subito nel container e viceversa: con Nginx che serve la cartella corrente,
basta modificare `index.html` e ricaricare il browser.

> **NOTA**: su Windows con Docker Desktop il percorso si scrive `C:\Users\io\cartella:/test` o `/c/Users/io/cartella:/test` (Git Bash).
> I bind mount dal filesystem di Windows sono lenti: per progetti grossi conviene tenere il codice dentro WSL.
> In Git Bash i path assoluti come `-w /app` e le path in `tar` vengono convertiti da MSYS: anteporre `MSYS_NO_PATHCONV=1` al comando.

### Esercizio: un volume condiviso da due container
```bash
docker run -it --name c1 -v volumeuno:/test ubuntu bash   # dentro: touch /test/primo.txt, poi CTRL+P CTRL+Q
docker run -it --name c2 -v volumeuno:/test2 ubuntu bash  # dentro: ls /test2 -> c'è già primo.txt
                                                          # touch /test2/secondo.txt, poi CTRL+P CTRL+Q
docker exec c1 ls /test                                   # primo.txt secondo.txt: stesso volume, percorsi diversi
docker volume ls                                          # un solo volume
docker rm -f c1 c2 && docker volume rm volumeuno
```
Stessa cosa con Jenkins: due container che montano lo stesso `jenkins_home` vedono la stessa installazione,
gli stessi job e la stessa password (vedi [06-jenkins/](06-jenkins/)).

## Reti
```bash
docker network ls                         # bridge, host e none esistono sempre
docker network inspect bridge             # sottorete e container collegati, con i loro IP
docker network create app-net             # rete bridge definita dall'utente
docker run -d --name db --network app-net -e MYSQL_ROOT_PASSWORD=x mysql:8.0
docker run -d --name web --network app-net -p 8080:80 php:8.3-apache
docker exec web getent hosts db           # "db" si risolve nell'IP del container db
docker network connect app-net altro      # collega un container già avviato a una seconda rete
docker network disconnect app-net altro
docker network rm app-net
```

| Driver | Cosa fa |
|---|---|
| `bridge` | rete privata sull'host (default `172.17.0.0/16`). I container escono su internet in NAT attraverso l'host |
| `host` | nessun isolamento: il container usa direttamente le interfacce e le porte dell'host (niente `-p`) |
| `none` | solo loopback, nessuna rete |
| `overlay` | una rete che attraversa più host, per Docker Swarm (vedi [05-swarm/](05-swarm/)) |

### Risoluzione per nome
Sulla rete `bridge` **predefinita** i container si vedono solo per IP. Su una rete **creata dall'utente**, e su quella che
`docker compose` crea per ogni progetto, docker fa da DNS: ogni container si raggiunge con il suo **nome** (o il nome del servizio).
Per questo in un'app PHP in compose l'host del database è `database` o `db` e non `localhost`: `localhost` dentro il
container è il container stesso.

La vecchia opzione `--link` serviva a questo sulla rete predefinita: è deprecata, si usa una rete definita dall'utente.

### Esercizio: due container sulla rete predefinita
```bash
docker run -dit --name contA ubuntu bash
docker run -dit --name contB ubuntu bash
docker network inspect bridge -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}' # IP di ciascuno
docker exec contA bash -c 'apt-get update -qq && apt-get install -yqq iputils-ping >/dev/null'
docker exec contA ping -c2 172.17.0.3     # per IP funziona (l'IP di contB stampato sopra)
docker exec contA ping -c2 contB          # per nome no: "ping: contB: Name or service not known"
docker rm -f contA contB
```

### NAT verso l'esterno
Un container sulla rete bridge naviga su internet perché l'host traduce il suo IP privato nel proprio (NAT).
```bash
docker run --rm alpine ping -c2 8.8.8.8                     # esce su internet
docker run --rm curlimages/curl -s ifconfig.me              # IP pubblico: è quello dell'host
docker run --rm --network none alpine ping -c1 8.8.8.8      # con --network none no
```
Per osservarlo dall'interno: `tcpdump -n host 8.8.8.8` in un secondo terminale nello stesso container (`docker exec`)
mostra le richieste partire dall'IP privato `172.17.0.x`.

### Porte
`-p host:container` pubblica una porta: le connessioni alla porta dell'host arrivano al container.
Senza `-p` il servizio è raggiungibile solo dagli altri container della stessa rete.
```bash
docker run -d --name webserver1 -p 8082:80 nginx
docker port webserver1                    # 80/tcp -> 0.0.0.0:8082
curl -I 127.0.0.1:8082                    # 200 OK
```
> **ATTENZIONE**: su Linux le porte pubblicate con `-p` scavalcano le regole di `ufw`, perché docker scrive direttamente
> in iptables. Su un server esposto usare `-p 127.0.0.1:porta:porta` e mettere davanti un reverse proxy.

Per un laboratorio completo con più container sulla stessa rete: [../10-rete-e-web/05-load-balancer/](../10-rete-e-web/05-load-balancer/).
