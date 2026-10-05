# 05 - Docker Swarm

| File | Contenuto |
|---|---|
| [swarm.md](swarm.md) | Nodi manager e worker, servizi, scalare e aggiornare, reti overlay, stack |
| [wordpress-stack.yaml](wordpress-stack.yaml) | Stack WordPress + MySQL: web replicato, database a una replica |

```bash
docker swarm init                                 # serve Docker; la macchina diventa manager
docker stack deploy -c wordpress-stack.yaml wp    # poi http://localhost:8080
docker stack rm wp                                # pulizia (docker swarm leave --force per uscire dal cluster)
```

Torna a [../](../)
