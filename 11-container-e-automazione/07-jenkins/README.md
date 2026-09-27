# 07 - Jenkins

| File | Contenuto |
|---|---|
| [jenkins.md](jenkins.md) | Concetti, il laboratorio (JCasC, Docker in Docker, agenti), sintassi Declarative completa, credenziali, Shared Library, Multibranch, esempi di CI/CD, API REST e CLI, amministrazione, problemi comuni |
| [Dockerfile](Dockerfile) | `jenkins/jenkins:lts-jdk21` + CLI di docker + plugin da `plugins.txt`, senza procedura guidata |
| [plugins.txt](plugins.txt) | I plugin installati nell'immagine |
| [casc.yaml](casc.yaml) | Configuration as Code: utente, esecutori, agenti, credenziali di esempio, job |
| [compose.yaml](compose.yaml) | Controller + Docker in Docker + tre agenti (profilo `agenti`) |
| [agenti.sh](agenti.sh) | Legge i secret degli agenti dall'API e li scrive in `.env` |
| [.env.example](.env.example) | Password di admin e secret degli agenti |
| [pipeline/](pipeline/) | Nove Jenkinsfile di esempio (uno per job) e `jobs.groovy` che li trasforma in job |
| [app/](app/) | Applicazione Flask con test, per la pipeline di CI |

```bash
docker compose up -d --build     # poi http://localhost:8080, admin / admin
```

Torna a [../](../)
