# Jenkins

Server di automazione open source: esegue **pipeline** (sequenze di passi: compilare, testare, costruire un'immagine,
rilasciare) quando qualcuno lo chiede, a orari fissi o quando il codice cambia. È il classico strumento di **CI/CD**.

- **controller**: il server Jenkins. Tiene configurazione, job, storico dei build e l'interfaccia web; coordina il lavoro
- **agente** (o nodo): una macchina (o un container) che esegue i build per conto del controller
- **esecutore**: uno "slot" di lavoro su un nodo. Un nodo con 2 esecutori fa girare 2 build insieme
- **job**: un compito configurato. Tipi principali: *Pipeline* (definita da un `Jenkinsfile`), *Multibranch Pipeline*
  (un job per ogni branch di un repository), *Freestyle* (configurato a clic, il vecchio modo)
- **build**: un'esecuzione di un job, con il suo numero, il suo log e il suo esito (SUCCESS, UNSTABLE, FAILURE, ABORTED)
- **workspace**: la cartella in cui un build lavora, sul nodo che lo esegue
- **plugin**: quasi tutto in Jenkins è un plugin, anche le pipeline stesse
- **`jenkins_home`**: la cartella con tutto lo stato del controller (configurazione, plugin, job, storico). Montata su un
  volume sopravvive a riavvii e aggiornamenti del container: è quella di cui fare il backup

Documentazione: https://www.jenkins.io/doc/book/pipeline/ · sintassi: https://www.jenkins.io/doc/book/pipeline/syntax/ ·
step: https://www.jenkins.io/doc/pipeline/steps/

## Il laboratorio
Jenkins configurato interamente da file: niente procedura guidata, niente plugin da scegliere, niente job da creare a mano.
```
 browser ──:8080──> jenkins (controller) ──TLS :2376──> docker (Docker in Docker)
                        ▲       ▲       ▲                  └ i container delle pipeline, le immagini costruite
                   WebSocket :8080
                     agent1  agent2  agent3     (profilo "agenti", facoltativo)
```

| File | Contenuto |
|---|---|
| [Dockerfile](Dockerfile) | `jenkins/jenkins:lts-jdk21` + CLI di docker e buildx + i plugin di `plugins.txt`; salta la procedura guidata |
| [plugins.txt](plugins.txt) | I plugin, installati durante il build dell'immagine con `jenkins-plugin-cli` |
| [casc.yaml](casc.yaml) | Configuration as Code: utente admin, esecutori, i tre agenti, due credenziali di esempio, URL, job |
| [compose.yaml](compose.yaml) | Controller, Docker in Docker, tre agenti nel profilo `agenti` |
| [agenti.sh](agenti.sh) | Legge dall'API il secret di ogni agente e lo scrive in `.env` |
| [.env.example](.env.example) | Password di admin (facoltativa) e secret degli agenti |
| [pipeline/](pipeline/) | `jobs.groovy` e nove Jenkinsfile di esempio: ognuno diventa un job |
| [app/](app/) | Un'applicazione Flask con i suoi test, per la pipeline di CI |

```bash
docker compose up -d --build      # la prima volta scarica immagini e plugin: qualche minuto
docker compose logs -f jenkins    # aspettare "Jenkins is fully up and running"
```
http://localhost:8080, utente `admin` e password `admin` (per cambiarla: `JENKINS_ADMIN_PASSWORD=...` in `.env`).
Nella home ci sono già i nove job, da `01-base` a `09-agenti`: *Build Now* e poi, nella pagina del build, *Console Output*.
Cosa mostra ciascuno è spiegato in [pipeline/README.md](pipeline/README.md).

Per modificare una pipeline si cambia il file in `pipeline/` e si ricarica la configurazione (*Manage Jenkins >
Configuration as Code > Reload existing configuration*): Job DSL aggiorna il job. Per provare al volo senza toccare i
file c'è *Replay*, nella pagina di un build: riesegue il build con lo script modificato nel browser.

Smontare:
```bash
docker compose --profile agenti down      # ferma tutto, i volumi (configurazione, storico, immagini) restano
docker compose --profile agenti down -v   # ATTENZIONE: cancella anche i volumi, si riparte da zero
```

### Configuration as Code
[casc.yaml](casc.yaml) descrive lo stato del controller come i manifest descrivono un cluster Kubernetes: il plugin
*Configuration as Code* (JCasC) lo applica a ogni avvio. Le parti:
- `jenkins:` sicurezza (utenti locali, *chi è loggato può fare tutto*), esecutori del controller, nodi
- `credentials:` le credenziali, qui finte. In un progetto vero i valori arrivano da variabili d'ambiente o da file di
  secret (`${GITHUB_TOKEN}`), non scritti nel file
- `unclassified:` le impostazioni dei plugin (qui l'URL di Jenkins)
- `jobs:` script Job DSL che creano i job; [pipeline/jobs.groovy](pipeline/jobs.groovy) ne crea uno per ogni `*.jenkinsfile`

Da un Jenkins esistente, *Manage Jenkins > Configuration as Code > View Configuration* mostra la configurazione attuale
in questo formato: il modo più rapido per scoprire come si scrive un'impostazione.

### Docker in Docker
Le pipeline che usano `agent { docker }` o costruiscono immagini hanno bisogno di un demone Docker. Due strade:

| | Socket dell'host (`/var/run/docker.sock` montato) | Docker in Docker (`docker:dind`, questo laboratorio) |
|---|---|---|
| demone | quello del PC | uno dedicato, in un container `privileged` |
| container e immagini delle pipeline | insieme a quelli del PC | separati, nel volume `docker_data` |
| rischio | chi scrive una pipeline controlla il Docker del PC, cioè il PC | limitato al demone interno |
| porte pubblicate dalle pipeline | su `localhost` | sull'host `docker`, visto da Jenkins (`http://docker:5000`) |

Due dettagli fanno funzionare la seconda strada:
- il volume `jenkins_home` è montato **anche** nel servizio `docker`, allo stesso percorso: quando Jenkins avvia un
  container con `-v /var/jenkins_home/workspace/job:/var/jenkins_home/workspace/job`, il demone quel percorso lo trova.
  Nel log compare `Jenkins seems to be running inside container ... could not be found among []`: il plugin non trova
  il container di Jenkins nel demone interno e ripiega sul montaggio per percorso, che qui è corretto
- `docker:dind` genera certificati TLS in un volume condiviso: la CLI di Jenkins li usa con `DOCKER_HOST`,
  `DOCKER_CERT_PATH` e `DOCKER_TLS_VERIFY`
```bash
docker compose exec docker docker images  # le immagini costruite dalle pipeline (kb-app:1, kb-app:latest...)
docker compose exec docker docker ps -a   # i container avviati dalle pipeline
```

### Gli agenti
Il controller dovrebbe solo coordinare: i build girano sugli agenti. Qui sono tre container `jenkins/inbound-agent`: sono
loro a collegarsi al controller (via WebSocket, sulla stessa porta 8080), autenticandosi con un **secret** che Jenkins
calcola per ogni nodo. I nodi sono già definiti in `casc.yaml`; manca solo il secret:
```bash
./agenti.sh                               # legge i secret dall'API e li scrive in .env
docker compose --profile agenti up -d
```
*Manage Jenkins > Nodes*: agent1, agent2, agent3 diventano online. La pipeline `09-agenti` li usa.
A mano, senza lo script: nella pagina di ogni nodo c'è il comando di collegamento con il valore di `-secret`, da copiare in `.env`.

Altri modi di collegare agenti: via SSH (il controller entra nell'agente con una chiave: plugin *SSH Build Agents*),
oppure agenti creati al volo per ogni build e distrutti alla fine (plugin *Docker* o *Kubernetes*).

## Jenkinsfile: la sintassi Declarative
Il `Jenkinsfile` descrive la pipeline e sta nel repository, insieme al codice che costruisce. Sintassi **Declarative**:
una struttura fissa, controllata prima di partire (un errore di sintassi fa fallire il build subito, con la riga).
```groovy
pipeline {
    agent any                          // dove girare: qualunque esecutore libero
    environment { APP = 'demo' }       // variabili d'ambiente
    options { timeout(time: 30, unit: 'MINUTES') }
    parameters { string(name: 'VERSIONE', defaultValue: '1.0.0') }
    triggers { pollSCM('H/5 * * * *') }
    stages {
        stage('Build') {
            when { branch 'main' }     // condizione
            steps {
                sh 'make'              // i passi
            }
            post { failure { echo 'build fallito' } }
        }
    }
    post { always { cleanWs() } }      // dopo tutti gli stage, in base all'esito
}
```
Scrivere a mano la sintassi di uno step non serve: *Pipeline Syntax* (link nella pagina di ogni job, `/pipeline-syntax/`)
genera il codice da un modulo; *Declarative Directive Generator* (`/directive-generator/`) fa lo stesso per `options`,
`when`, `triggers`, `parameters`...

### agent
```groovy
agent any                                        // qualunque nodo
agent none                                       // nessuno a livello di pipeline: lo sceglie ogni stage
agent { label 'linux && docker' }                // un nodo con queste label (&&, ||, !)
agent { docker { image 'python:3.13-slim' } }    // gli step girano in un container, sul workspace montato
agent { docker { image 'node:22'; args '-e HOME=/tmp'; reuseNode true } } // reuseNode: stesso nodo e workspace dello stage esterno
agent { dockerfile { dir 'ci'; filename 'Dockerfile.build' } }           // costruisce l'immagine dal repository e la usa
```
Il container di `agent { docker }` gira con lo stesso utente di Jenkins (uid 1000): strumenti che vogliono scrivere nella
home (npm, pip) hanno bisogno di `HOME` scrivibile o di un percorso esplicito.

### environment e credenziali
Le credenziali si salvano in Jenkins (*Manage Jenkins > Credentials*, o JCasC) e si usano per ID: nel Jenkinsfile non
compare nessun segreto, e nel log vengono mascherate con `****`.
```groovy
environment {
    TOKEN = credentials('token-demo')            // Secret text: $TOKEN
    LOGIN = credentials('login-demo')            // Username/password: $LOGIN (utente:password), $LOGIN_USR, $LOGIN_PSW
    KUBECONFIG = credentials('kubeconfig-prod')  // Secret file: $KUBECONFIG è il percorso di una copia temporanea del file
}
steps {
    withCredentials([string(credentialsId: 'token-demo', variable: 'API_TOKEN')]) {   // solo dentro il blocco
        sh 'curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com'
    }
    withCredentials([sshUserPrivateKey(credentialsId: 'deploy-key', keyFileVariable: 'CHIAVE', usernameVariable: 'UTENTE')]) {
        sh 'ssh -i "$CHIAVE" "$UTENTE@server" ./deploy.sh'
    }
}
```
> **ATTENZIONE**: con i segreti sempre **apici singoli** (`sh 'echo $TOKEN'`): la shell legge la variabile d'ambiente.
> Con i doppi (`sh "echo ${TOKEN}"`) è Groovy a scrivere il segreto dentro il comando, che diventa visibile nella lista
> dei processi del nodo; Jenkins lo segnala con `Warning: A secret was passed to "sh" using Groovy String interpolation`.
> Il nome utente di una credenziale Username/password non viene mascherato.

### parameters
```groovy
parameters {
    string(name: 'VERSIONE', defaultValue: '1.0.0', description: 'Versione da rilasciare')
    choice(name: 'AMBIENTE', choices: ['sviluppo', 'collaudo', 'produzione'])
    booleanParam(name: 'ESEGUI_TEST', defaultValue: true)
    text(name: 'NOTE', defaultValue: '')
    password(name: 'CHIAVE', defaultValue: '')
}
// uso: params.VERSIONE (Groovy), $VERSIONE (shell)
```
I parametri li definisce il Jenkinsfile stesso: Jenkins li conosce solo dopo il primo build, che gira con i default.
In quel primo build `params.VERSIONE` vale il default ma la variabile d'ambiente `$VERSIONE` è **vuota**, e
`buildWithParameters` dall'API risponde 400 finché il job non ha parametri: nel codice meglio usare sempre `params.X`.

### options e triggers
```groovy
options {
    timeout(time: 1, unit: 'HOURS')              // interrompe il build (ABORTED) oltre il tempo
    retry(2)                                     // riprova tutta la pipeline se fallisce
    timestamps()                                 // orario su ogni riga del log
    buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '5')) // stringhe, non numeri
    disableConcurrentBuilds()                    // un build alla volta per questo job
    skipDefaultCheckout()                        // niente checkout automatico del repository in ogni stage
    quietPeriod(10)                              // attende 10 s prima di partire (raggruppa più commit)
}
triggers {
    pollSCM('H/5 * * * *')                       // controlla il repository ogni 5 minuti; parte se ci sono commit nuovi
    cron('H 2 * * 1-5')                          // alle 2 di notte, dal lunedì al venerdì
    upstream(upstreamProjects: 'libreria', threshold: hudson.model.Result.SUCCESS) // dopo un altro job
}
```
La sintassi è quella di crontab ([../../06-sistema/09-crontab.md](../../06-sistema/09-crontab.md)) più la `H` (hash):
un minuto scelto da Jenkins in base al nome del job, fisso per quel job, così cento job con `H 2 * * *` non partono
tutti nello stesso secondo. Meglio di `pollSCM` è un **webhook**: GitHub o GitLab avvisano Jenkins a ogni push.

### when
```groovy
when { branch 'main' }                           // solo nei job Multibranch (altrimenti BRANCH_NAME non c'è e lo stage salta)
when { expression { params.AMBIENTE == 'produzione' } }
when { environment name: 'DEPLOY', value: 'true' }
when { changeset 'src/**' }                      // solo se il commit tocca quei file
when { tag 'v*' }                                // build di un tag
when { changeRequest() }                         // build di una pull request
when { allOf { branch 'main'; expression { params.ESEGUI_TEST } } }   // anyOf, not per le altre combinazioni
when { beforeAgent true; branch 'main' }         // valuta PRIMA di occupare l'agente
```
Uno stage saltato compare nel log come `Stage "Test" skipped due to when conditional`.

### parallel e matrix
```groovy
stage('Controlli') {
    failFast true                                // se un ramo fallisce, ferma gli altri
    parallel {
        stage('Lint') { steps { sh 'make lint' } }
        stage('Test') { steps { sh 'make test' } }
    }
}
stage('Compatibilità') {
    matrix {                                     // una copia degli stage per ogni combinazione degli assi
        axes {
            axis { name 'PHP'; values '8.3', '8.4' }
            axis { name 'DB';  values 'mysql', 'postgres' }
        }
        stages { stage('Test') { steps { sh './test.sh "$PHP" "$DB"' } } }
    }
}
```
Rami paralleli sullo stesso nodo usano workspace diversi: `job`, `job@2`, `job@3`.

### input: approvazione manuale
```groovy
stage('Produzione') {
    options { timeout(time: 1, unit: 'DAYS') }   // senza risposta: ABORTED
    input {
        message 'Rilasciare in produzione?'
        ok 'Rilascia'
        submitter 'admin,ops'                    // chi può approvare
        parameters { choice(name: 'FINESTRA', choices: ['subito', 'stanotte']) }
    }
    agent any                                    // l'agente si occupa DOPO la risposta
    steps { sh "./deploy.sh ${FINESTRA}" }
}
```
Con la direttiva `input` di uno stage l'attesa non occupa esecutori (con `agent none` in cima alla pipeline). Lo step
`input message: '...'` dentro `steps` fa la stessa domanda, ma tiene occupato l'esecutore finché non arriva la risposta.

### post
| Condizione | Quando gira |
|---|---|
| `always` | sempre |
| `success` / `unstable` / `failure` / `aborted` | con quell'esito |
| `unsuccessful` | con qualunque esito diverso da SUCCESS |
| `changed` | se l'esito è diverso da quello del build precedente (anche al primo build) |
| `fixed` | il precedente era fallito o instabile, questo è SUCCESS |
| `regression` | il precedente era SUCCESS, questo no |
| `cleanup` | sempre, per ultimo: pulizia |

Si scrive a livello di pipeline o di singolo stage.

### Gli step più usati
| Step | Cosa fa |
|---|---|
| `sh 'comando'` / `bat 'comando'` | shell su Linux / cmd su Windows. `sh(script: '...', returnStdout: true).trim()` restituisce l'output, `returnStatus: true` il codice di uscita |
| `echo 'testo'` | scrive nel log |
| `script { ... }` | un blocco di Groovy libero dentro `steps` |
| `dir('sotto') { ... }` | esegue gli step in una sottocartella del workspace |
| `writeFile`, `readFile`, `fileExists` | file nel workspace |
| `archiveArtifacts artifacts: 'dist/**', fingerprint: true` | conserva file con il build, scaricabili dalla sua pagina |
| `junit 'report.xml'` | legge i risultati dei test (formato JUnit): esito UNSTABLE se ce ne sono di falliti, storico nel job |
| `stash name: 'x', includes: '...'` / `unstash 'x'` | passa file da uno stage (e da un nodo) all'altro |
| `retry(3) { }`, `timeout(time: 5, unit: 'MINUTES') { }` | ritenta, limita il tempo |
| `catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') { }` | un errore nel blocco non ferma il build |
| `error 'messaggio'`, `unstable 'messaggio'` | FAILURE (si ferma), UNSTABLE (prosegue) |
| `sleep 10`, `waitUntil { script { sh(script: 'curl -fs http://app/health', returnStatus: true) == 0 } }` | attende; `waitUntil` ripete il blocco (a intervalli crescenti) finché restituisce `true` |
| `git url: '...', branch: 'main'` / `checkout scm` | clona un repository / quello da cui viene il Jenkinsfile |
| `withEnv(['PATH+BIN=/opt/bin']) { }` | variabili d'ambiente per un blocco (`PATH+X` aggiunge in testa al PATH) |
| `build job: 'deploy', parameters: [string(name: 'VERSIONE', value: '1.2.3')]` | avvia un altro job e ne aspetta l'esito |
| `cleanWs()` | svuota il workspace (plugin Workspace Cleanup) |

### Variabili disponibili
| Variabile | Contenuto |
|---|---|
| `BUILD_NUMBER`, `BUILD_ID` | numero del build |
| `BUILD_URL`, `JOB_NAME`, `JOB_URL` | indirizzo del build, nome e indirizzo del job |
| `WORKSPACE`, `NODE_NAME` | cartella e nodo dove gira lo step (`built-in` per il controller) |
| `JENKINS_URL` | l'URL di Jenkins |
| `BRANCH_NAME`, `CHANGE_ID` | branch e numero della pull request (solo Multibranch) |
| `GIT_COMMIT`, `GIT_BRANCH` | dopo un checkout git |
| `currentBuild.currentResult`, `currentBuild.number`, `currentBuild.durationString` | l'esito finora, il numero, la durata (solo Groovy) |

In Groovy: `env.BUILD_NUMBER`, `params.VERSIONE`. Nella shell: `$BUILD_NUMBER`, `$VERSIONE`.
L'elenco completo, con le variabili e gli oggetti dei plugin installati: *Pipeline Syntax > Global Variables Reference*
(`/job/NOME/pipeline-syntax/globals`).

### Groovy: il minimo indispensabile
Le pipeline sono Groovy. I blocchi `script { ... }` dentro `steps` permettono logica più complessa:
```groovy
def nome = "Mario"                               // def: variabile senza tipo
def lista = [1, 2, 3]
def mappa = [env: 'prod', versione: '1.0']
echo "Ciao ${nome}, versione ${mappa.versione}"  // interpolazione: solo tra doppi apici
if (params.AMBIENTE == 'produzione') { echo 'produzione!' }
if (params.VERSIONE ==~ /\d+\.\d+\.\d+/) { echo 'formato valido' }   // ==~ : tutta la stringa corrisponde alla regex
lista.each { v -> echo "valore: ${v}" }          // ciclo con una closure
mappa.each { k, v -> echo "${k}: ${v}" }
def somma(a, b) { a + b }                        // metodo (fuori da pipeline {}); l'ultima espressione è il ritorno
```
Le pipeline girano in una **sandbox**: i metodi Java/Groovy non ancora approvati si fermano con
`Scripts not permitted to use method ...`, e un amministratore li approva in *Manage Jenkins > In-process Script Approval*.
Logica lunga non va nel Jenkinsfile ma in una **Shared Library**.

### Scripted Pipeline
La sintassi più vecchia: Groovy puro dentro `node { }`, più flessibile ma senza controlli preventivi.
```groovy
node('linux') {
    stage('Build') {
        checkout scm
        sh 'make'
    }
}
```
Per i progetti nuovi si usa Declarative, con blocchi `script { }` dove serve.

### Shared Library
Codice di pipeline comune a molti progetti, in un repository a parte:
```
vars/deployApp.groovy          # uno step personalizzato: deployApp(ambiente: 'prod')
src/org/azienda/Utils.groovy   # classi Groovy
resources/template.yaml        # file letti con libraryResource
```
```groovy
// vars/deployApp.groovy
def call(Map args) {
    sh "./deploy.sh ${args.ambiente}"
}
```
```groovy
// nel Jenkinsfile di un progetto
@Library('libreria-ci@main') _                   // registrata in Manage Jenkins > System > Global Trusted Pipeline Libraries
pipeline {
    agent any
    stages { stage('Deploy') { steps { deployApp(ambiente: 'prod') } } }
}
```

## Dal repository: Pipeline da SCM e Multibranch
Nel laboratorio lo script dei job è copiato nella loro configurazione. In un progetto vero il `Jenkinsfile` sta nel
repository e Jenkins lo legge da lì:
- **Pipeline** con *Definition: Pipeline script from SCM*: URL del repository, branch, percorso del Jenkinsfile.
  Nel Jenkinsfile `checkout scm` scarica esattamente la revisione da cui arriva lo script
- **Multibranch Pipeline**: Jenkins scansiona il repository e crea un job per ogni branch (e pull request) che contiene
  un `Jenkinsfile`. Qui funzionano `BRANCH_NAME`, `when { branch 'main' }`, `when { changeRequest() }`
- **quando partire**: un webhook del server Git (GitHub: *Settings > Webhooks*, URL `https://jenkins.example.com/github-webhook/`)
  avvisa Jenkins a ogni push; `pollSCM` è il ripiego quando Jenkins non è raggiungibile da fuori

Il repository di questa KB è pubblico, quindi si prova nel laboratorio senza scrivere niente: *New Item > Pipeline*,
*Definition: Pipeline script from SCM*, SCM *Git*, URL `https://github.com/edisyst-docs/bashbash.git`, il branch che
contiene questi file e *Script Path* `11-container-e-automazione/07-jenkins/pipeline/01-base.jenkinsfile`.

## Esempi di riferimento
Pipeline complete che nel laboratorio non girano perché servono servizi esterni.

### Build, push e deploy su un server
```groovy
def immagine                                     // variabile Groovy condivisa fra gli stage

pipeline {
    agent any
    environment {
        REGISTRY  = 'utente/mia-app'
        VPS_HOST  = '203.0.113.10'
    }
    stages {
        stage('Build') {
            steps {
                script { immagine = docker.build("${REGISTRY}:${BUILD_NUMBER}") }
            }
        }
        stage('Push') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {  // credenziale Username/password "dockerhub"
                        immagine.push()                  // mia-app:42
                        immagine.push('latest')
                    }
                }
            }
        }
        stage('Deploy') {
            when { branch 'main' }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'vps', keyFileVariable: 'CHIAVE')]) {
                    sh '''
                        ssh -i "$CHIAVE" -o StrictHostKeyChecking=accept-new "root@$VPS_HOST" \
                            "docker pull $REGISTRY:$BUILD_NUMBER && docker rm -f app; docker run -d --name app -p 80:3000 $REGISTRY:$BUILD_NUMBER"
                    '''
                }
            }
        }
    }
    post {
        always { sh "docker rmi ${REGISTRY}:${BUILD_NUMBER} || true" }  // pulizia dell'immagine locale
    }
}
```

### Terraform con approvazione
Il piano si calcola, si mostra, si approva, e si applica **quel** piano ([../09-terraform/terraform.md](../09-terraform/terraform.md)):
```groovy
pipeline {
    agent { docker { image 'hashicorp/terraform:1.16'; args '--entrypoint=' } } // senza entrypoint: gli step sono comandi sh
    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret')
        TF_IN_AUTOMATION      = '1'
    }
    stages {
        stage('Plan') {
            steps {
                sh 'terraform init -input=false'
                sh 'terraform plan -input=false -out=piano.tfplan'
                sh 'terraform show -no-color piano.tfplan > piano.txt'
                archiveArtifacts 'piano.txt'
            }
        }
        stage('Apply') {
            when { branch 'main' }
            input { message 'Applicare il piano (vedi piano.txt fra gli artefatti)?' }
            steps { sh 'terraform apply -input=false piano.tfplan' }
        }
    }
}
```

### Deploy su Kubernetes
Con un kubeconfig salvato come credenziale *Secret file* ([../06-kubernetes/kubernetes.md](../06-kubernetes/kubernetes.md)):
```groovy
stage('Deploy su Kubernetes') {
    steps {
        withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
            sh 'kubectl set image deployment/mia-app app=registry.example.com/mia-app:$BUILD_NUMBER'
            sh 'kubectl rollout status deployment/mia-app --timeout=120s'   // fallisce (e fa fallire il build) se il rollout non va
        }
    }
}
```
Con Helm: `helm upgrade --install mia-app ./chart --set image.tag=$BUILD_NUMBER --wait --rollback-on-failure`.
Il kubeconfig dovrebbe appartenere a un ServiceAccount con i soli permessi necessari (RBAC), non all'amministratore del cluster.

### Analisi statica con SonarQube
Richiede il plugin SonarQube Scanner e un server SonarQube configurato con il nome `sonar`:
```groovy
stage('Analisi statica') {
    steps { withSonarQubeEnv('sonar') { sh 'mvn sonar:sonar' } }
}
stage('Quality Gate') {
    steps { timeout(time: 5, unit: 'MINUTES') { waitForQualityGate abortPipeline: true } }
}
```

## Jenkins da riga di comando
### API REST
Quasi ogni pagina di Jenkins ha la sua versione JSON aggiungendo `/api/json` all'indirizzo. Per le chiamate si usa un
**token API** al posto della password (utente in alto a destra > *Security* > *API Token* > *Add new Token*): con il
token le richieste POST non hanno bisogno del *crumb* (la protezione CSRF), e si può revocare senza cambiare la password.
```bash
J=http://localhost:8080
AUTH=admin:11d4...                                              # utente:token
curl -s -g -u "$AUTH" "$J/api/json?tree=jobs[name,color]"       # -g: le [] non sono pattern di curl. color: blue ok, red fallito, *_anime in corso
curl -s -X POST -u "$AUTH" "$J/job/01-base/build"               # avvia un build (201 Created)
curl -s -X POST -u "$AUTH" "$J/job/02-parametri/buildWithParameters" \
    --data VERSIONE=2.1.0 --data AMBIENTE=produzione           # con parametri
curl -s -u "$AUTH" "$J/job/01-base/lastBuild/api/json?tree=number,result,building"  # esito dell'ultimo build
curl -s -u "$AUTH" "$J/job/01-base/lastBuild/consoleText"       # il log completo
curl -s -X POST -u "$AUTH" "$J/job/01-base/lastBuild/stop"      # interrompe un build in corso
curl -s -u "$AUTH" "$J/job/08-approvazione/lastBuild/wfapi/pendingInputActions"   # input in attesa (con l'id)
curl -s -u "$AUTH" "$J/job/01-base/config.xml" > config.xml    # la configurazione di un job, in XML
curl -s -X POST -u "$AUTH" -H "Content-Type: application/xml" \
    --data-binary @config.xml "$J/job/01-base/config.xml"      # la sostituisce
curl -s -X POST -u "$AUTH" -H "Content-Type: application/xml" \
    --data-binary @config.xml "$J/createItem?name=nuovo-job"    # crea un job da un config.xml
```
Aspettare la fine di un build in uno script:
```bash
until curl -s -u "$AUTH" "$J/job/07-ci-app/lastBuild/api/json?tree=building" | grep -q '"building":false'; do sleep 5; done
curl -s -u "$AUTH" "$J/job/07-ci-app/lastBuild/api/json?tree=result"   # {"result":"SUCCESS"}
```
Senza token, con utente e password, ogni POST vuole il crumb, legato a un cookie di sessione:
```bash
CRUMB=$(curl -s -c cookie.txt -u admin:admin "$J/crumbIssuer/api/json" | sed -E 's/.*"crumb":"([^"]+)".*/\1/')
curl -s -b cookie.txt -u admin:admin -H "Jenkins-Crumb: $CRUMB" -X POST \
    "$J/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" --data newTokenName=script
# risposta: {"status":"ok","data":{"tokenName":"script","tokenUuid":"...","tokenValue":"11d4..."}}
```

### jenkins-cli.jar
Un client Java scaricabile dal proprio Jenkins (qui lo si usa dentro il container, che Java ce l'ha):
```bash
docker compose exec jenkins sh -c 'curl -so /tmp/cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar'
cli() { docker compose exec -T jenkins java -jar /tmp/cli.jar -s http://localhost:8080/ -auth "$AUTH" "$@"; }
cli who-am-i
cli list-jobs
cli build 01-base -s -v                          # -s aspetta la fine, -v stampa il log
cli console 01-base                              # log dell'ultimo build
cli reload-jcasc-configuration                   # rilegge casc.yaml
cli safe-restart                                 # riavvia quando i build in corso sono finiti
cli help                                         # tutti i comandi
```

## Amministrazione
- **plugin**: in `plugins.txt` e nell'immagine, non installati a mano dalla UI; per aggiornarli si ricostruisce
  l'immagine (`docker compose build --pull`). Pochi plugin, quelli che servono: ognuno è codice che gira nel controller
- **aggiornare Jenkins**: cambiare il tag nel `Dockerfile` (una nuova linea LTS ogni 12 settimane circa) e ricostruire;
  `jenkins_home` resta. Prima, un backup
- **backup** del volume, senza i workspace che si ricreano da soli:
```bash
docker compose stop jenkins
MSYS_NO_PATHCONV=1 docker run --rm -v 07-jenkins_jenkins_home:/dati -v "$PWD":/backup alpine \
    tar czf /backup/jenkins_home.tgz -C /dati --exclude=./workspace .
docker compose start jenkins
```
  Qui si potrebbe escludere anche `./plugins`: all'avvio Jenkins ce li ricopia dall'immagine.
- **un controller per `jenkins_home`**: due container Jenkins avviati sullo stesso volume si sovrascrivono a vicenda
  configurazione e storico. Per avere più capacità si aggiungono agenti, non controller
- **sicurezza**: 0 esecutori sul controller in produzione (i build girano sugli agenti), credenziali solo nel loro
  archivio, nessun socket Docker dell'host montato sul controller, aggiornamenti frequenti (*Manage Jenkins* mostra gli
  avvisi di sicurezza dei plugin installati), permessi per utente o gruppo con il plugin *Matrix Authorization*
- **Blue Ocean** non è più sviluppata: per la vista grafica degli stage c'è *Pipeline Graph View* (installato qui)
- log del controller: `docker compose logs -f jenkins`, oppure *Manage Jenkins > System Log*

## Buone pratiche
1. `Jenkinsfile` nel repository, nella radice: la pipeline si rivede e si versiona come il codice
2. sintassi Declarative; blocchi `script` corti, la logica lunga in script di shell nel repository o in una Shared Library
3. credenziali sempre dall'archivio di Jenkins, con `credentials()` o `withCredentials`, e apici singoli nella shell
4. strumenti di build nei container (`agent { docker }`) invece che installati sui nodi: ogni progetto porta le sue versioni
5. stage piccoli con nomi chiari: nel log e nella vista grafica si capisce subito dove si è rotto
6. `timeout` su ogni pipeline, `buildDiscarder` per non riempire il disco, `cleanWs()` alla fine
7. configurazione del controller come codice (JCasC + `plugins.txt`): un Jenkins si ricrea da zero in pochi minuti

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `Invalid parameter "numToKeep", did you mean "numToKeepStr"?` | `logRotator` vuole stringhe | `logRotator(numToKeepStr: '10')` |
| il build resta in coda: `Waiting for next available executor on 'agent1'` | nessun nodo online con quella label | *Manage Jenkins > Nodes*, avviare l'agente o correggere la label |
| `docker: not found` in una pipeline | nessuna CLI docker sul nodo | installarla nell'immagine del nodo (come nel `Dockerfile` qui) |
| `Cannot connect to the Docker daemon` | `DOCKER_HOST` mancante o demone spento | `docker compose ps docker`, variabili in `compose.yaml` |
| `Scripts not permitted to use method ...` | metodo Groovy non approvato nella sandbox | approvarlo in *In-process Script Approval*, o spostare la logica in uno script |
| `buildWithParameters` risponde 400 | il job non ha ancora parametri (manca il primo build) | un primo build con `/build` |
| uno stage con `when { branch 'main' }` salta sempre | job non Multibranch: `BRANCH_NAME` non esiste | job Multibranch, o `when { expression { ... } }` |
| `npm ERR! EACCES` o simili in `agent { docker }` | l'utente 1000 non ha una home scrivibile | `args '-e HOME=/tmp'` |
