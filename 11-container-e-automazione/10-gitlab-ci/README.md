# 10 - GitLab CI/CD

| File | Contenuto |
|---|---|
| [gitlab-ci.md](gitlab-ci.md) | Concetti, i due laboratori (GitLab completo e `gitlab-ci-local`), sintassi di `.gitlab-ci.yml`, rules e workflow, needs, artefatti e cache, variabili e segreti, servizi, ambienti, include e componenti, runner, API e `glab`, esempi Laravel/Terraform/Kubernetes, confronto con Jenkins, problemi comuni |
| [compose.yaml](compose.yaml) | GitLab CE 19.4 + runner con executor docker + Docker in Docker |
| [configura.sh](configura.sh) | Token, runner creato e registrato, un progetto per ogni pipeline di esempio |
| [.env.example](.env.example) | Password di root e token |
| [pipeline/](pipeline/) | Nove `.gitlab-ci.yml` di esempio (uno per progetto) |
| [app/](app/) | Applicazione Flask con test, per la pipeline di CI |
| [ci/](ci/) | Modelli inclusi dalla pipeline 09 |

```bash
docker compose up -d && ./configura.sh    # poi http://gitlab.localhost:8929, root / Tiglio-Arancio-4729
gitlab-ci-local --file pipeline/01-base.gitlab-ci.yml   # oppure in locale, senza GitLab
docker compose down                       # ferma tutto, i volumi restano
docker compose down -v && rm .env         # cancella anche i volumi (e il token, che non vale più)
```
Serve Docker con ~6 GB di RAM e le porte 8929-8931 libere; il primo avvio richiede circa 5 minuti.

Torna a [../](../)
