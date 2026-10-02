# 11 - Container e automazione

Docker, compose, swarm e Kubernetes; CI/CD con Jenkins e GitLab; configurazione con Ansible e infrastruttura con Terraform.

| # | File/cartella | Contenuto |
|---|---|---|
| 01 | [docker](01-docker.md) | CLI: `docker run`, `exec`, `logs`, immagini, pulizia, policy di riavvio, porte |
| 02 | [dockerfile](02-dockerfile/) | `FROM`, `RUN`, `CMD`, layer e cache, `.dockerignore`, multi-stage; esempi nginx / python / flask / node |
| 03 | [volumi e reti](03-volumi-e-reti.md) | Volumi con nome, bind mount, rete bridge e host, overlay, DNS interno, NAT |
| 04 | [compose](04-compose/) | `compose.yaml`, variabili, healthcheck, init DB; lab php+mysql, mysql+phpmyadmin, postgres |
| 05 | [swarm](05-swarm/) | Cluster, servizi, repliche, aggiornamenti a rotazione, rollback, reti overlay, stack |
| 06 | [kubernetes](06-kubernetes/) | Architettura, kind, `kubectl`, Deployment, Service, ConfigMap e Secret, storage, probe, HPA, Ingress e Gateway, Helm; 7 laboratori |
| 07 | [jenkins](07-jenkins/) | Laboratorio configurato da codice (JCasC, Docker in Docker, agenti), Jenkinsfile Declarative, 9 pipeline di esempio, API REST |
| 08 | [ansible](08-ansible/) | Inventory, playbook, moduli, group_vars; laboratorio Docker master→slave |
| 09 | [terraform](09-terraform/) | Infrastructure as Code: HCL, variabili, `for_each`, moduli, stato, import; esempi Docker, AWS e Kubernetes |
| 10 | [gitlab ci](10-gitlab-ci/) | GitLab CE + runner in compose e `gitlab-ci-local`, `.gitlab-ci.yml`: rules, needs, matrix, artefatti e cache, variabili protette, servizi, registry, ambienti, include; 9 pipeline di esempio |

Area precedente: [../10-rete-e-web/](../10-rete-e-web/) · Prossima: [../12-osservabilita/](../12-osservabilita/)
