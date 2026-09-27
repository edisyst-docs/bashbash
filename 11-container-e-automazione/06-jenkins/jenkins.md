# Jenkins con Docker

Jenkins è un server di automazione open source: esegue **pipeline** (serie di passi) quando il codice cambia.
La configurazione vive in `jenkins_home` (volumi, plugin, job, utenti): se si monta un volume, sopravvive a qualsiasi
riavvio o aggiornamento del container.

**Riferimento**: https://www.jenkins.io/doc/book/pipeline/

## Setup: controller da solo
```bash
docker compose up -d --build         # costruisce l'immagine (jenkins + docker CLI) e avvia
docker compose exec jenkins sh -c 'cat /var/jenkins_home/secrets/initialAdminPassword'
```
1. Aprire http://localhost:8080, inserire la password stampata sopra
2. *Install suggested plugins* (qualche minuto la prima volta)
3. Creare l'utente amministratore
4. Lasciare l'URL di default e salvare

### Immagine personalizzata
Il `Dockerfile` aggiunge la CLI di docker al controller Jenkins: le pipeline che costruiscono immagini (es. `Jenkinsfile`
qui sotto) trovano `docker` nell'`$PATH`. Il demone usato è quello dell'host, condiviso via `/var/run/docker.sock`.
```dockerfile
FROM jenkins/jenkins:lts-jdk21
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
```
> **Attenzione**: chi può eseguire pipeline ha accesso al demone docker dell'host, e quindi può fare qualsiasi cosa
> (montare il filesystem host, avviare container privilegiati, …). In produzione usare agenti dedicati,
> non montare il socket sul controller.

## Agenti
Gli agenti eseguono le pipeline al posto del controller, che si occupa solo di coordinare.
In `compose.yaml` ci sono tre agenti nel profilo `agenti`; partono solo dopo averli registrati nella UI:

1. *Manage Jenkins → Nodes → New Node*: nome `agent1`, tipo *Permanent Agent*
2. Configurare: *Remote root directory* `/home/jenkins/agent`, label `agent1`, launch method *Launch agent by connecting it to the controller*
3. Copiare il **secret** mostrato nella pagina del nodo
4. Ripetere per `agent2` e `agent3`
5. Creare il file `.env` nella cartella di questo compose:
```bash
cp .env.example .env
# incollare i secret copiati dalla UI
```
6. Avviare gli agenti:
```bash
docker compose --profile agenti up -d
```
Gli agenti si connettono al controller via WebSocket (porta 8080, non serve la 50000 per questa configurazione).

Condivisione di `jenkins_home` tra due controller (stesso volume → stessa configurazione, stessi job):
```bash
docker run -p 8080:8080 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
docker run -p 8081:8080 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts   # accede agli stessi dati
```

## Jenkinsfile

Il `Jenkinsfile` descrive la pipeline ed è committato insieme al codice. Sintassi **Declarative** (consigliata).

### Struttura di base
```groovy
pipeline {
    agent any        // qualsiasi nodo disponibile; "none" per sceglierlo stage per stage

    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh 'make'           // comando shell (bat 'build.bat' su Windows)
            }
        }
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
        stage('Deploy') {
            when { branch 'main' }  // esegui solo sul branch main
            steps {
                sh 'make deploy'
            }
        }
    }

    post {
        success { echo 'OK' }
        failure { echo 'Qualcosa è andato storto' }
        always  { cleanWs() }       // pulisce il workspace
    }
}
```

### Pipeline con parametri
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'VERSION', defaultValue: '1.0', description: 'Versione da rilasciare')
        choice(name: 'ENV', choices: ['dev', 'stage', 'prod'], description: 'Ambiente target')
        booleanParam(name: 'RUN_TESTS', defaultValue: true)
    }
    stages {
        stage('Deploy') {
            when { expression { return params.ENV == 'prod' } }
            steps {
                echo "Deploy versione ${params.VERSION} in ${params.ENV}"
            }
        }
    }
}
```

### Build parallelo
```groovy
pipeline {
    agent none
    stages {
        stage('Build e test in parallelo') {
            parallel {
                stage('Linux') {
                    agent { label 'agent1' }
                    steps { sh 'make linux' }
                }
                stage('Windows') {
                    agent { label 'windows' }
                    steps { bat 'build.bat' }
                }
                stage('Unit test') {
                    agent any
                    steps { sh 'make test-unit' }
                }
            }
        }
    }
}
```

### Pipeline CI/CD: build immagine → push → deploy
Questo `Jenkinsfile` clona un repo, costruisce l'immagine, la pubblica su Docker Hub e deploya su un VPS:
```groovy
pipeline {
    environment {
        REGISTRY     = 'utente/mia-app'
        REGISTRY_CRED = 'dockerhub'           // credenziali salvate in Jenkins (Manage > Credentials)
        VPS_HOST     = '1.2.3.4'
        dockerImage  = ''
    }
    agent any

    stages {
        stage('Clone') {
            steps {
                git branch: 'main', url: 'https://github.com/utente/repo.git'
            }
        }
        stage('Build') {
            steps {
                script {
                    dockerImage = docker.build("${REGISTRY}:${BUILD_NUMBER}")
                }
            }
        }
        stage('Push') {
            steps {
                script {
                    docker.withRegistry('', REGISTRY_CRED) {
                        dockerImage.push()
                    }
                }
            }
        }
        stage('Pulisci immagine locale') {
            steps {
                sh "docker rmi ${REGISTRY}:${BUILD_NUMBER}"
            }
        }
        stage('Deploy sul VPS') {
            steps {
                sh "ssh -T root@${VPS_HOST} docker rm -f app || true"
                sh "ssh -T root@${VPS_HOST} docker run --name app -p 3000:3000 -d ${REGISTRY}:${BUILD_NUMBER}"
            }
        }
    }
}
```

### Groovy: il minimo indispensabile
Le pipeline usano Groovy. I blocchi `script { ... }` dentro `steps` permettono logica più complessa:
```groovy
// variabili: def (non tipizzata) o tipo esplicito
def nome = "Mario"
def n = 42
def lista = [1, 2, 3]
def mappa = [env: 'prod', versione: '1.0']

// interpolazione: solo dentro le doppie virgolette
echo "Ciao ${nome}, versione ${mappa.versione}"

// condizionale
if (params.ENV == 'prod') { echo 'produzione!' }

// ciclo
lista.each { v -> echo "valore: ${v}" }
mappa.each { k, v -> echo "${k}: ${v}" }

// metodo
def somma(a, b) { a + b }   // l'ultima espressione è il valore di ritorno
```

### Gate di approvazione manuale
```groovy
stage('Deploy in produzione') {
    steps {
        input message: 'Sei sicuro di voler deployare in prod?',
              ok: 'Procedi',
              submitter: 'admin,ops'   // solo questi utenti Jenkins possono sbloccare
        sh 'make deploy-prod'
    }
}
```

### Elementi avanzati
```groovy
options {
    timeout(time: 1, unit: 'HOURS')
    buildDiscarder(logRotator(numToKeep: 5))
}

triggers {
    pollSCM('H/5 * * * *')    // controlla SCM ogni 5 minuti
}

environment {
    TOKEN = credentials('mio-token')  // variabile legata a una credenziale di Jenkins
}

// quality gate con SonarQube
stage('Analisi statica') {
    steps {
        withSonarQubeEnv('sonar') { sh 'mvn sonar:sonar' }
    }
}
stage('Quality Gate') {
    steps {
        timeout(time: 1, unit: 'MINUTES') { waitForQualityGate abortPipeline: true }
    }
}
```

## Best practices
1. `Jenkinsfile` nella radice del repository
2. Sintassi Declarative (più leggibile del Scripted Pipeline)
3. Credenziali sempre con `credentials()`, mai in chiaro
4. Stage atomici, focalizzati su un'azione sola
5. Logica complessa in Shared Libraries (riusabile da più job)
