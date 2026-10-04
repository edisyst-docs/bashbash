# Jenkins LTS pronto all'uso: CLI di docker, plugin già installati, configurazione da casc.yaml
FROM jenkins/jenkins:lts-jdk21

# CLI di docker e il plugin buildx: le pipeline costruiscono immagini e avviano container.
# Il demone non è qui: è il servizio "docker" (Docker in Docker) di compose.yaml
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# i plugin si installano durante il build dell'immagine, non a mano dalla UI: così sono ripetibili
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# niente procedura guidata al primo avvio: utenti, credenziali, nodi e job li crea casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/lab/casc.yaml
