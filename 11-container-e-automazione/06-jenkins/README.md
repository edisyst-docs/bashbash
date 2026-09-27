# 06 - Jenkins

| File | Contenuto |
|---|---|
| [jenkins.md](jenkins.md) | Setup con compose, agenti, Jenkinsfile: struttura, parametri, parallelo, CI/CD, Groovy |
| [Dockerfile](Dockerfile) | `jenkins/jenkins:lts-jdk21` con la CLI di docker |
| [compose.yaml](compose.yaml) | Controller + tre agenti (profilo `agenti`); volume `jenkins_home` |
| [.env.example](.env.example) | Template per i secret degli agenti |

Torna a [../](../)
