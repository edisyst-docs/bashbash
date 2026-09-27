# 11 - Container e automazione

Docker, compose, swarm, Jenkins e Ansible.

| # | File/cartella | Contenuto |
|---|---|---|
| 01 | [docker](01-docker.md) | CLI: `docker run`, `exec`, `logs`, immagini, pulizia, policy di riavvio, porte |
| 02 | [dockerfile](02-dockerfile/) | `FROM`, `RUN`, `CMD`, layer e cache, `.dockerignore`, multi-stage; esempi nginx / python / flask / node |
| 03 | [volumi e reti](03-volumi-e-reti.md) | Volumi con nome, bind mount, rete bridge e host, overlay, DNS interno, NAT |
| 04 | [compose](04-compose/) | `compose.yaml`, variabili, healthcheck, init DB; lab php+mysql, mysql+phpmyadmin, postgres |
| 05 | [swarm](05-swarm/) | Cluster, servizi, repliche, aggiornamenti a rotazione, rollback, reti overlay, stack |
| 06 | [jenkins](06-jenkins/) | Setup con compose, agenti, Jenkinsfile: struttura, parametri, parallelo, CI/CD, Groovy |
| 07 | [ansible](07-ansible/) | Inventory, playbook, moduli, group_vars; laboratorio Docker master→slave |

Area precedente: [../10-rete-e-web/](../10-rete-e-web/) · Torna all'[indice](../README.md)
