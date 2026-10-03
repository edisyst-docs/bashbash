# 12 - Trivy e Hadolint

| File | Contenuto |
|---|---|
| [trivy-hadolint.md](trivy-hadolint.md) | L'attacco a Trivy di marzo 2026 e come difendersi (digest, SHA, firme), uso con Docker e installazione verificata, Hadolint: regole e configurazione, Trivy: Dockerfile, immagini, segreti, eccezioni con scadenza, SBOM, manifest Kubernetes e Terraform, cluster; Jenkins, GitLab CI e GitHub Actions; problemi comuni |
| [esempio/](esempio/) | La stessa app Flask con un `Dockerfile.prima` pieno di errori comuni e un `Dockerfile` corretto, più le configurazioni di Hadolint e Trivy |

```bash
cd esempio
docker build -f Dockerfile.prima -t esempio:prima . && docker build -t esempio:dopo .
docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile.prima
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.75.0 image --severity CRITICAL --ignore-unfixed esempio:prima
```
Gli stage nelle pipeline: [../07-jenkins/pipeline/07-ci-app.jenkinsfile](../07-jenkins/pipeline/07-ci-app.jenkinsfile),
[../10-gitlab-ci/pipeline/07-ci-app.gitlab-ci.yml](../10-gitlab-ci/pipeline/07-ci-app.gitlab-ci.yml).

Torna a [../](../)
