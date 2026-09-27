# 06 - LoadBalancer, Ingress e Gateway API

Tre modi di far entrare il traffico dall'esterno, sulle stesse due applicazioni: `blu` e `verde`.

| File | Contenuto |
|---|---|
| [app.yaml](app.yaml) | Deployment e Service ClusterIP `blu` e `verde` (`traefik/whoami`: risponde con nome, Pod e header ricevuti) |
| [loadbalancer.yaml](loadbalancer.yaml) | Service `blu-lb` di tipo LoadBalancer sulla porta 8088 |
| [ingress.yaml](ingress.yaml) | Ingress `colori`: `/blu` e `/verde` per percorso, `verde.example.com` per nome host |
| [gateway.yaml](gateway.yaml) | Gateway `ingresso` (porta 8089) + HTTPRoute `colori`: canary 90/10 e instradamento per header |

## Chi realizza LoadBalancer, Ingress e Gateway
Kubernetes definisce questi oggetti ma non li realizza: in un cloud ci pensa il provider (crea un bilanciatore vero con
un IP pubblico), in un cluster proprio un controller installato apposta. Per kind c'è **cloud-provider-kind**: gira
come container accanto al cluster e per ogni LoadBalancer, Ingress o Gateway avvia un container Envoy (`kindccm-...`).
```bash
docker run -d --name cloud-provider-kind --network kind \
    -v /var/run/docker.sock:/var/run/docker.sock \
    registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.11.1
kubectl get ingressclass,gatewayclass    # cloud-provider-kind, per tutti e due
```
In Git Bash su Windows anteporre `MSYS_NO_PATHCONV=1` al `docker run` (vedi [../../01-docker.md](../../01-docker.md)).

```bash
kubectl apply -f app.yaml
```

## 1. Service LoadBalancer
```bash
kubectl apply -f loadbalancer.yaml
kubectl get svc blu-lb                   # EXTERNAL-IP 172.19.0.6: un IP della rete Docker "kind"
docker ps --filter name=kindccm          # il container Envoy che fa da bilanciatore
curl localhost:8088                      # Name: blu / Hostname: blu-56bdfbc94f-x544k ...
```
- su **Linux** l'EXTERNAL-IP è raggiungibile direttamente dal PC: `curl 172.19.0.6:8088`
- con **Docker Desktop** (Windows, Mac) i container stanno in una VM e quell'IP dal PC non si vede: cloud-provider-kind
  pubblica la porta del Service **con lo stesso numero** sul PC, da qui `localhost:8088`. La porta del PC deve essere
  libera: un LoadBalancer sulla 80 non parte se la 80 è occupata (Laragon, IIS)
- da qualunque sistema, dalla rete Docker: `docker run --rm --network kind curlimages/curl -s http://172.19.0.6:8088`

## 2. Ingress
```bash
kubectl apply -f ingress.yaml
kubectl get ingress colori               # ADDRESS 172.19.0.8, PORTS 80
```
cloud-provider-kind traduce l'Ingress in un Gateway (`kind-ingress-gateway`) con le HTTPRoute equivalenti
(`kubectl get gateway,httproute`). Su Docker Desktop la sua porta 80 viene pubblicata su una porta **casuale** del PC,
che si legge da Docker:
```bash
GW=$(docker ps -q --filter label=io.x-k8s.cloud-provider-kind.gateway.name=lab/default/kind-ingress-gateway)
PORTA=$(docker port "$GW" 80 | head -1 | cut -d: -f2)   # "0.0.0.0:54740" -> 54740
curl localhost:$PORTA/blu                            # Name: blu
curl localhost:$PORTA/verde                          # Name: verde
curl localhost:$PORTA/blu/sotto/pagina               # Name: blu (Prefix: vale tutto quello che inizia per /blu)
curl -H "Host: verde.example.com" localhost:$PORTA/  # Name: verde (regola per nome host)
curl -i localhost:$PORTA/altro                       # 404: nessuna regola
```
Il percorso arriva all'applicazione così com'è (`GET /blu/sotto/pagina`): un Ingress standard non lo riscrive.
L'header `Host` si simula con `-H`; con un nome vero basterebbe un record DNS (o una riga in `/etc/hosts`,
`C:\Windows\System32\drivers\etc\hosts`) che punta all'indirizzo del bilanciatore.

## 3. Gateway API
```bash
kubectl apply -f gateway.yaml
kubectl get gateway ingresso             # PROGRAMMED True
GW=$(docker ps -q --filter label=io.x-k8s.cloud-provider-kind.gateway.name=lab/default/ingresso)
PORTA=$(docker port "$GW" 8089 | head -1 | cut -d: -f2)
for i in $(seq 100); do curl -s localhost:$PORTA | grep "^Name"; done | sort | uniq -c
```
```
     93 Name: blu
      7 Name: verde
```
Il **rilascio canary**: la versione nuova (`verde`) riceve circa il 10% del traffico, secondo i `weight` della HTTPRoute.
Se va bene si spostano i pesi (50/50, poi 0/100) con un `kubectl apply`, senza toccare i Deployment.
Chi deve provare la versione nuova la chiede esplicitamente, con un header:
```bash
curl -s -H "X-Versione: verde" localhost:$PORTA | grep "^Name"   # sempre verde
curl -s localhost:$PORTA/prova | grep -E "^(X-|Host)"            # gli header aggiunti da Envoy: X-Forwarded-For, X-Request-Id...
```
Rispetto all'Ingress, le parti sono separate: il **Gateway** (dove si ascolta, porte, certificati) lo gestisce chi amministra
il cluster; le **HTTPRoute** (dove va il traffico) le scrive chi sviluppa l'applicazione, nel proprio namespace.

## Smontare
```bash
kubectl delete -f .
docker rm -f cloud-provider-kind         # i container kindccm-... li elimina lui quando si cancellano gli oggetti
```
Se si ferma cloud-provider-kind prima di cancellare gli oggetti, i `kindccm-...` restano:
`docker rm -f $(docker ps -aq --filter name=kindccm)`.

Torna a [../](../)
