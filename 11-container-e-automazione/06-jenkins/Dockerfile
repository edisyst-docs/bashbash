# Jenkins con la CLI di docker, per le pipeline che costruiscono immagini
# (il demone è quello dell'host, raggiunto tramite /var/run/docker.sock montato in compose.yaml)
FROM jenkins/jenkins:lts-jdk21
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
