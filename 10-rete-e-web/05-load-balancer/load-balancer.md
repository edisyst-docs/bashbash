# Bilanciatori di carico in cascata con Docker

Laboratorio: un bilanciatore **primario** riceve le richieste dei client e le passa a un **HAProxy secondario**,
che le distribuisce a turno fra tre web server.
```
Client ---> Bilanciatore primario ---> HAProxy ---> web1, web2, web3
            (HAProxy, Nginx, Caddy,     (nodi         (server
             Envoy o Traefik)            multipli)     applicativi)
```
In produzione il primario è spesso un servizio del cloud (es. AWS ELB) e i secondari sono più istanze di HAProxy.
Qui gira tutto in container sulla stessa rete Docker, dove ogni container raggiunge gli altri per **nome**.

| Componente | Ruolo | Porta sul PC |
|---|---|---|
| `web1`, `web2`, `web3` | Nginx che risponde "risposta da webN" | 8081, 8082, 8083 |
| `haproxy` | HAProxy secondario, `roundrobin` fra i web | 8080, statistiche su 8404 |
| primario | uno a scelta tra cinque | 8000 |

> **NOTA**: il primario è sulla 8000 e non sulla 80 perché su Windows la 80 è spesso già occupata (Laragon, IIS).

## 1. A mano, passo per passo
Per capire cosa succede, la prima volta conviene crearlo a mano con `docker run`. I comandi vanno lanciati
dentro questa cartella. In PowerShell sostituire `"$(pwd)"` con `"${PWD}"`.

```bash
docker network create lb-net                            # rete comune: dentro, i container si trovano per nome

for n in 1 2 3; do                                      # tre web server che rispondono con il proprio nome
    docker run -d --name web$n --hostname web$n --network lb-net -p 808$n:80 nginx:alpine
    docker exec web$n sh -c 'echo "risposta da $(hostname)" > /usr/share/nginx/html/index.html'
done
curl localhost:8081                                     # "risposta da web1": i web funzionano da soli

docker run -d --name haproxy --network lb-net -p 8080:80 -p 8404:8404 \
    -v "$(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy:lts-alpine
for i in 1 2 3 4 5 6; do curl -s localhost:8080; done   # web1, web2, web3, web1, web2, web3: il bilanciamento

docker run -d --name primario --network lb-net -p 8000:80 \
    -v "$(pwd)/haproxy-primario.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy:lts-alpine
for i in 1 2 3; do curl -s localhost:8000; done         # stessa cosa passando dal primario
```
Smontare:
```bash
docker rm -f primario haproxy web1 web2 web3
docker network rm lb-net
```

## 2. Con docker compose
Il file [compose.yaml](compose.yaml) crea tutto insieme. Il primario si sceglie con un **profilo**:
```bash
docker compose --profile haproxy up -d   # oppure: nginx, caddy, envoy, traefik (uno alla volta: usano tutti la 8000)
docker compose ps                        # cosa è partito
for i in $(seq 6); do curl -s localhost:8000; done
docker compose logs -f haproxy           # ogni richiesta con il server che l'ha servita
docker compose --profile "*" down        # spegne tutto, qualunque profilo sia attivo
```
Per cambiare primario: `down` e poi `up` con l'altro profilo.

## 3. HAProxy: la configurazione
File [haproxy.cfg](haproxy.cfg):
```
frontend http_front             # dove ascolta: riceve le richieste
    bind *:80
    default_backend http_back

backend http_back               # a chi le passa
    balance roundrobin          # algoritmo: a turno. Altri: leastconn (al meno carico), source (stesso client -> stesso server)
    server web1 web1:80 check   # nome, indirizzo:porta, check = health check continuo
    server web2 web2:80 check
    server web3 web3:80 check

listen stats                    # frontend + backend in un blocco solo: qui la pagina di statistiche
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
```
Il primario HAProxy ([haproxy-primario.cfg](haproxy-primario.cfg)) è identico, ma nel backend ha gli HAProxy secondari
invece dei web server.

### Monitorare in tempo reale
Nel browser: http://localhost:8404/stats. Una riga per server, verde se il check passa, con richieste servite,
errori e tempi. Da terminale:
```bash
curl -s 'localhost:8404/stats;csv' | cut -d, -f1,2,18 | column -t -s,  # backend, server, stato (UP/DOWN) in formato CSV
docker compose exec haproxy wget -qO- 'localhost:8404/stats;csv' | head -3 # UGUALE da dentro il container (nell'immagine alpine c'è wget, non curl)
```

### Provare il failover
```bash
docker compose stop web2                 # "rompo" un server
for i in $(seq 6); do curl -s localhost:8000; done   # dopo pochi secondi solo web1 e web3: HAProxy l'ha escluso da solo
docker compose start web2                # torna nel giro appena il check ripassa
```

### Verificare una configurazione prima di usarla
```bash
docker run --rm -v "$(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy:lts-alpine \
    haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg   # "Configuration file is valid"
```
In HAProxy la risoluzione dei nomi (`web1`) avviene all'avvio: se un server non esiste ancora, HAProxy non parte.
Per questo nel compose c'è `depends_on`.

## 4. Gli altri bilanciatori primari
Tutti fanno lo stesso lavoro: ricevono sulla porta 80 del container e passano a `haproxy:80`.

| Profilo | File | Caratteristiche | Extra |
|---|---|---|---|
| `haproxy` | [haproxy-primario.cfg](haproxy-primario.cfg) | il più performante, configurazione esplicita | — |
| `nginx` | [nginx.conf](nginx.conf) | web server che fa anche da proxy; `upstream` elenca i backend | — |
| `caddy` | [Caddyfile](Caddyfile) | configurazione minima, HTTPS automatico con Let's Encrypt | — |
| `envoy` | [envoy.yaml](envoy.yaml) | molto flessibile, base dei service mesh (Istio); YAML verboso | admin su http://localhost:9901 |
| `traefik` | [traefik.yml](traefik.yml) + [traefik-dinamico.yml](traefik-dinamico.yml) | nato per i container: può leggere le rotte dalle label Docker | dashboard su http://localhost:8090 |

Errori tipici, corretti nei file di questa cartella:
- **Caddy**: `reverse_proxy / haproxy:80` inoltra solo il percorso `/` esatto, non `/pagina`. Senza matcher (`reverse_proxy haproxy:80`) inoltra tutto.
- **Nginx**: il file va montato **al posto** di `/etc/nginx/nginx.conf`. Montato con un altro nome, nginx lo ignora e parte con la configurazione di default.
- **Envoy**: le configurazioni con `config:` ed `envoy.router` sono dell'API v2, rimossa: le versioni recenti vogliono `typed_config` con il campo `@type`, e `load_assignment` al posto di `hosts`.
- **Traefik**: la dashboard usa la porta 8080 del container; se anche HAProxy è pubblicato sulla 8080 del PC, le due porte vanno in conflitto.

## 5. Traefik con le label Docker
Il punto di forza di Traefik: invece di un file di rotte, legge le **label** dei container attraverso il socket
di Docker e si aggiorna da solo quando un container parte o si ferma. Al posto del provider `file`:
```yaml
  primario-traefik:
    image: traefik:v3.3
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false    # espone solo i container con traefik.enable=true
      - --entrypoints.web.address=:80
      - --api.insecure=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro # ATTENZIONE: chi controlla il socket controlla Docker (e quindi l'host)
    ports: ["8000:80", "8090:8080"]

  haproxy:
    # ...come prima, più:
    labels:
      - traefik.enable=true
      - traefik.http.routers.lab.rule=PathPrefix(`/`)
      - traefik.http.routers.lab.entrypoints=web
      - traefik.http.services.lab.loadbalancer.server.port=80
```
