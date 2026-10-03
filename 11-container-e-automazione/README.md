# 11 - Container e automazione

Docker, compose, swarm e Kubernetes; CI/CD con Jenkins, GitLab e GitHub Actions, sicurezza delle immagini con Trivy e Hadolint, deploy GitOps con Argo CD; configurazione con Ansible e infrastruttura con Terraform.

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
| 11 | [argo cd](11-argocd/) | GitOps su kind con registry e Gitea locali: Application, sync automatica, self-heal, rollback con `git revert`, Kustomize e Helm, hook, app of apps, ApplicationSet, AppProject; laboratorio in 11 passi |
| 12 | [trivy e hadolint](12-trivy-hadolint/) | Lint dei Dockerfile, vulnerabilità e segreti nelle immagini, configurazione di Kubernetes e Terraform, SBOM; stage che bloccano i CRITICAL nelle pipeline di Jenkins e GitLab |
| 13 | [github actions](13-github-actions/) | Workflow, eventi, matrix, needs, artefatti e cache, servizi, CI con Trivy e ghcr.io, ambienti, segreti e OIDC, riuso; sicurezza e `act`; nove esempi in `.github/workflows/` e la CI della KB |

Area precedente: [../10-rete-e-web/](../10-rete-e-web/) · Prossima: [../12-osservabilita/](../12-osservabilita/)
