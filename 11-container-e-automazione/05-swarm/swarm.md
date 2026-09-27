# Docker Swarm

L'orchestratore integrato in docker: gestisce container su **più macchine** come un'unica risorsa.
Invece di avviare container si dichiarano **servizi** ("voglio 5 repliche di nginx") e swarm li mantiene in quello stato:
se un container muore o un nodo si spegne, ricrea le repliche mancanti altrove.

- **nodo**: una macchina (fisica o VM) con Docker Engine. Un insieme di nodi è un **cluster**
- **manager**: riceve i comandi, decide dove far girare le repliche, conserva lo stato. Di default fa anche da worker
- **worker**: esegue i container che il manager gli assegna
- **servizio**: la definizione (immagine, repliche, porte, rete); **task**: una singola replica, cioè un container
- **stack**: un gruppo di servizi descritto da un file compose, l'equivalente swarm di `docker compose up`

Esempio: un sito con frontend e backend. Studiando il traffico so che servono N container per il frontend e M per il backend.
Se uno si ferma, lo swarm se ne accorge e ne ricrea uno, senza intervento manuale.

Swarm è semplice e incluso in docker; per cluster grandi lo standard di fatto è **Kubernetes**, con gli stessi concetti
(nodi, servizi, repliche) e molte più opzioni: vedi [../06-kubernetes/](../06-kubernetes/), dove lo stack WordPress qui
sotto è rifatto come laboratorio.

## Il cluster
Si prova anche su una sola macchina (Docker Desktop): un nodo manager che fa anche da worker.
Per più nodi senza installare nulla: https://labs.play-with-docker.com/ (ogni *Add new instance* è un nodo).
```bash
docker swarm init                                  # questa macchina diventa manager (e stampa il comando per i worker)
docker swarm init --advertise-addr 192.168.0.18    # se ha più interfacce: quale IP annunciare agli altri nodi
docker swarm join-token worker                     # ristampa il comando per aggiungere un worker
docker swarm join-token manager                    # e quello per aggiungere un altro manager
docker swarm join --token SWMTKN-1-... 192.168.0.18:2377 # sul nuovo nodo: entra nel cluster
docker node ls                                     # (manager) nodi, ruolo, stato
docker node inspect --pretty node2                 # dettagli di un nodo
docker node update --availability drain node2      # svuota un nodo (per manutenzione): le repliche migrano
docker node update --availability active node2    # rimette il nodo in servizio dopo la manutenzione
docker swarm leave                                 # (worker) esce dal cluster; su un manager serve --force
```
Porte da aprire tra i nodi: `2377/tcp` (gestione), `7946/tcp+udp` (comunicazione fra nodi), `4789/udp` (rete overlay).

## Servizi
Tutti i comandi si danno dal **manager**, che distribuisce i container sui nodi in base al loro stato.
```bash
docker service create --name web -p 8080:80 --replicas 3 nginx:1.26-alpine # 3 repliche, porta 8080 su ogni nodo
docker service ls                                  # servizi e repliche attive/richieste (es. 3/3)
docker service ps web                              # su quale nodo gira ogni replica, e la storia dei tentativi
docker service inspect --pretty web
docker service logs -f web                         # log di tutte le repliche insieme
docker service scale web=5                         # scala a 5 repliche
docker service update --replicas 5 web             # UGUALE
docker service update --image nginx:1.27-alpine web # aggiornamento a rotazione alla nuova versione
docker service update \
    --update-delay 10s \
    --update-parallelism 1 \
    --update-failure-action rollback \
    --image nginx:1.27-alpine web               # aggiornamento con pausa e rollback automatico in caso di errore
docker service rollback web                        # torna alla versione precedente manualmente
docker service rm web
docker ps                                          # sul singolo nodo: solo i container che girano lì
```
Se si elimina a mano un container di un servizio (`docker rm -f`), dopo pochi secondi swarm ne crea un altro.

La porta pubblicata usa la rete **ingress** (routing mesh): risponde su ogni nodo del cluster, anche su quelli che non
ospitano repliche, e distribuisce le richieste fra le repliche.

### Reti overlay
Una rete `overlay` attraversa tutti i nodi: i container dei servizi collegati si parlano per nome come su una rete bridge.
```bash
docker network create -d overlay backend
docker service create --name app --network backend --replicas 4 alpine sleep 1d
docker network inspect backend
```

### Vincoli di posizionamento
Controllano su quali nodi viene schedulato un servizio. Si basano sulle **label** dei nodi.
```bash
docker node update --label-add tipo=db node3      # aggiunge una label a un nodo
docker service create \
    --name db \
    --constraint node.labels.tipo==db \
    --replicas 1 mysql:8.0                         # solo sul nodo con quella label
docker service create \
    --name web \
    --constraint node.role==worker \
    --replicas 3 nginx                             # solo sui worker (non sul manager)
```

## Stack: compose in swarm
Un file compose con il blocco `deploy:` descrive repliche, aggiornamenti e vincoli di posizionamento.
`build:` non è supportato: le immagini devono già stare in un registry.
```bash
docker stack deploy -c wordpress-stack.yaml wp     # crea (o aggiorna) i servizi wp_wordpress e wp_db
docker stack ls
docker stack services wp                           # repliche di ogni servizio
docker stack ps wp                                 # tutti i task e i loro nodi
docker stack rm wp                                 # elimina servizi e reti (i volumi restano)
```
Esempio completo: [wordpress-stack.yaml](wordpress-stack.yaml). Il database resta a **una** replica: le repliche di un
servizio non condividono i dati, e ogni nodo avrebbe il suo volume. Si replicano i servizi senza stato, come il web server.

### Esercizio: Jenkins replicato
```bash
docker service create -d --name serv-jenk -p 8003:8080 jenkins/jenkins:lts
docker service ps serv-jenk                        # 1 replica
docker service update serv-jenk --replicas 5
docker service ps serv-jenk                        # 5 repliche distribuite sui nodi
```
Da ogni nodo `http://IP-del-nodo:8003` risponde Jenkins. Però ogni replica ha il suo `jenkins_home`: la configurazione fatta
su una non si vede sulle altre, e le richieste finiscono a turno su repliche diverse. Un'applicazione con stato
va replicata solo con uno storage condiviso, e non tutte lo permettono: Jenkins no, cresce aggiungendo agenti
(vedi [../07-jenkins/](../07-jenkins/)).
