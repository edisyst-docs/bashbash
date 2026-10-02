# GitLab CI/CD

La CI/CD integrata in GitLab: la pipeline è descritta da un file **`.gitlab-ci.yml`** nella radice del repository e
parte da sola a ogni push, merge request, tag o a orario. A differenza di Jenkins ([../07-jenkins/jenkins.md](../07-jenkins/jenkins.md))
non c'è un server di CI separato da installare e collegare al repository: GitLab tiene codice, pipeline, registry delle
immagini, ambienti e segreti nello stesso posto; il lavoro lo fanno i **runner**.

- **pipeline**: un'esecuzione completa, creata da un evento (push, MR, tag, pulsante, schedule, API, trigger)
- **stage**: una fase (build, test, deploy). Gli stage vanno in fila; i job dello stesso stage partono insieme
- **job**: l'unità di lavoro, con il suo `script`. Gira in un ambiente pulito (di solito un container) e finisce con
  un esito: `success`, `failed`, `canceled`, `skipped`, `manual`
- **runner**: il programma (`gitlab-runner`) che prende i job da GitLab e li esegue. Ha un **executor**: `docker`
  (ogni job in un container nuovo, il più usato), `shell` (direttamente sulla macchina), `kubernetes` (un pod per job),
  `docker-autoscaler` (macchine create al volo)
- **artefatti**: file prodotti da un job, conservati con la pipeline e passati ai job successivi
- **cache**: file riusati fra una pipeline e l'altra (dipendenze scaricate), senza garanzie: se manca si riscarica
- **ambiente** (*environment*): dove si rilascia (staging, production), con lo storico dei deploy
- **variabili CI/CD**: predefinite (`CI_COMMIT_SHA`...), scritte nel file, o salvate nelle impostazioni del progetto
  (i segreti), con le opzioni *masked*, *protected* e *file*

Documentazione: https://docs.gitlab.com/ci/ · tutte le parole chiave: https://docs.gitlab.com/ci/yaml/ ·
variabili predefinite: https://docs.gitlab.com/ci/variables/predefined_variables/

Versioni del laboratorio: GitLab CE e runner 19.4.1 (settembre 2026).

## Il laboratorio
Due modi di far girare le pipeline di [pipeline/](pipeline/):

| | GitLab completo (`compose.yaml`) | `gitlab-ci-local` |
|---|---|---|
| cosa serve | Docker con ~6 GB di RAM, 5 minuti al primo avvio | Node.js (o il binario), Docker |
| cosa mostra | tutto: interfaccia, grafo, registry, ambienti, variabili mascherate, MR, schedule | il log dei job nel terminale |
| ciclo di prova | modifica, push, pipeline | modifica, invio: parte subito |
| quando usarlo | per imparare GitLab | per provare un `.gitlab-ci.yml` prima del push |

### GitLab completo
```
 browser ──:8929──> gitlab (web, API, git, registry :5050)
                       ▲
                  runner ──TLS :2376──> docker (Docker in Docker)
                                           └ i container dei job, i servizi, le immagini costruite
                                             (porte 8930 e 8931 pubblicate: gli ambienti della pipeline 08)
```

| File | Contenuto |
|---|---|
| [compose.yaml](compose.yaml) | GitLab CE con le impostazioni per poca memoria, Docker in Docker, il runner |
| [configura.sh](configura.sh) | Token di root, runner creato con l'API e registrato, un progetto per ogni pipeline di esempio |
| [.env.example](.env.example) | Password di root (facoltativa) e token scritto da `configura.sh` |
| [pipeline/](pipeline/) | Nove `.gitlab-ci.yml` di esempio, uno per progetto |
| [app/](app/) | Applicazione Flask con i test (la stessa del laboratorio Jenkins) |
| [ci/modelli.yml](ci/modelli.yml) | Job nascosti inclusi dalla pipeline 09 |

```bash
docker compose up -d
./configura.sh                    # aspetta GitLab, poi crea token, runner e progetti; rilanciabile
```
http://gitlab.localhost:8929, utente `root`, password `Tiglio-Arancio-4729` (o `GITLAB_ROOT_PASSWORD` in `.env`
prima del primo avvio: GitLab rifiuta le password con parole comuni e allora non parte). I browser risolvono da soli
ogni nome `*.localhost` a 127.0.0.1, senza toccare il file hosts.
Ogni progetto (`root/01-base` ... `root/09-riuso`) ha già la sua pipeline: *Build > Pipelines*. Cosa mostra ciascuno è
spiegato in [pipeline/README.md](pipeline/README.md).

Per modificare una pipeline: cambiare il file in `pipeline/` e `./configura.sh 03` (ripubblica solo i progetti che
iniziano con `03`); oppure modificarla nel browser con *Build > Pipeline editor*, che controlla la sintassi mentre si
scrive e fa il commit.

Smontare:
```bash
docker compose down              # ferma tutto, i volumi (repository, database, immagini) restano
docker compose down -v           # ATTENZIONE: cancella anche i volumi, si riparte da zero (e rm .env: il token non vale più)
```

Dettagli che fanno funzionare il laboratorio, utili anche fuori:
- **Docker in Docker** come nel laboratorio Jenkins: il runner avvia i container dei job su un demone dedicato, non su
  quello del PC. Il runner passa ai job `DOCKER_HOST` e i certificati: i job con `image: docker:29-cli` costruiscono
  immagini senza `services: [docker:dind]`
- **il nome di GitLab**: `external_url` è `http://gitlab.localhost:8929`, così i link dell'interfaccia funzionano nel
  browser. Dentro i container, però, curl e git mandano ogni `*.localhost` a 127.0.0.1 (cioè al container stesso) senza
  leggere `/etc/hosts`: per questo il runner usa `url` e `clone_url` `http://gitlab:8929`, e la pipeline 05 chiama l'API
  con `curl --connect-to`. Con un nome vero (`gitlab.azienda.it`) il problema non esiste
- **IP fissi** nella rete di compose: i container dei job vivono dentro dind, non vedono il DNS di compose, e raggiungono
  GitLab e dind con `extra_hosts`
- **registry HTTP**: `--insecure-registry=gitlab.localhost:5050` nel demone dind. In produzione il registry sta in HTTPS

### gitlab-ci-local
Esegue un `.gitlab-ci.yml` sul PC, job per job, con Docker (https://github.com/firecow/gitlab-ci-local, 4.76).
```bash
npm install -g gitlab-ci-local                 # oppure: npx gitlab-ci-local ...
cd 11-container-e-automazione/10-gitlab-ci     # la cartella fa da radice del progetto (app/, ci/)
gitlab-ci-local --file pipeline/01-base.gitlab-ci.yml            # tutta la pipeline
gitlab-ci-local --file pipeline/01-base.gitlab-ci.yml --list     # i job, con stage, when e needs
gitlab-ci-local --file pipeline/04-parallelo.gitlab-ci.yml lint  # un solo job (più nomi separati da spazio)
gitlab-ci-local --file pipeline/04-parallelo.gitlab-ci.yml pacchetto --needs   # un job e quelli da cui dipende
gitlab-ci-local --file pipeline/02-regole.gitlab-ci.yml --variable AMBIENTE=produzione --variable VERSIONE=2.1
gitlab-ci-local --file pipeline/02-regole.gitlab-ci.yml --variable AMBIENTE=produzione --manual produzione  # anche il job manuale
gitlab-ci-local --preview --file pipeline/09-riuso.gitlab-ci.yml # il file finale, dopo include ed extends
```
- usa solo i file **tracciati da git** (quelli non ancora aggiunti con `git add` non arrivano nei job) e legge branch,
  commit e `origin/main` dal repository: `rules:changes` confronta con `origin/main`
- i job senza `image` girano come shell sul PC; gli artefatti finiscono in `.gitlab-ci-local/` e, per comodità,
  anche nella cartella di lavoro (`out/`, `dist/`...: sono in `.gitignore`)
- le variabili segrete vanno in `.gitlab-ci-local-variables.yml` nella cartella (anche questo in `.gitignore`):
```yaml
TOKEN_DEMO: tok-1234-segreto-abcd
UTENTE_DEMO: deploy
CONFIG_DEMO:
  type: file                   # come una variabile "File" di GitLab: il job riceve un percorso
  values:
    '*': |
      server: 203.0.113.10
      porta: 22
PASSWORD_STAGING:
  values:
    staging: pw-staging-1234   # solo nei job con environment staging
```
- non fa tutto: niente mascheramento nel log, niente `timeout`, niente registry né ambienti veri. Le pipeline 07 e 08
  vogliono il demone dind del laboratorio; 01-06 e 09 girano bene
- su Windows serve `rsync` in Git Bash e, se un percorso viene storpiato, `--variable MSYS_NO_PATHCONV=1`

## .gitlab-ci.yml: la struttura
```yaml
stages: [build, test, deploy]          # ordine degli stage (default: .pre, build, test, deploy, .post)

default:                               # valori per tutti i job
  image: alpine:3.22
  interruptible: true

variables:                             # variabili globali
  APP: demo

workflow:                              # se creare la pipeline
  rules:
    - if: $CI_COMMIT_BRANCH || $CI_COMMIT_TAG

test:                                  # un job: qualunque chiave che non sia una parola riservata
  stage: test
  image: python:3.13-slim
  before_script: [pip install -r requirements.txt]
  script:
    - pytest
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  artifacts:
    reports: { junit: report.xml }

.modello:                              # un job che inizia con il punto è nascosto: non gira, si eredita
  tags: [docker]
```
Il file si controlla prima del commit in *Build > Pipeline editor* (scheda *Validate* per simulare un branch), o con
l'API di lint. Lo script di ogni job è una lista di comandi della shell dell'immagine (`sh` in Alpine, `bash` dove c'è):
il job fallisce al primo comando con codice di uscita diverso da 0.

> **ATTENZIONE allo YAML**: `- echo "esito: $X"` non è un comando ma una mappa (`echo "esito` → `$X"`), perché contiene
> `: `. GitLab risponde `jobs:nome:script config should be a string or a nested array of strings`. Si mette tra apici
> singoli tutta la riga: `- 'echo "esito: $X"'`. Stessa trappola con `#` preceduto da spazio (diventa un commento YAML)
> e con valori come `yes`, `no`, `on`, `3.10` (meglio tra apici: `"3.10"`).

### Le parole chiave dei job
| Chiave | A cosa serve |
|---|---|
| `stage` | lo stage del job (default: `test`) |
| `image` | l'immagine Docker in cui gira; forma estesa `{ name: ..., entrypoint: [""] }` |
| `services` | container accanto al job (database, cache), raggiungibili con `alias` |
| `script`, `before_script`, `after_script` | i comandi. `after_script` gira anche se `script` fallisce, in una shell separata (le variabili esportate in `script` non ci sono), con al massimo 5 minuti |
| `variables` | variabili del job, che sostituiscono quelle globali con lo stesso nome |
| `rules` | se il job entra nella pipeline e come (`when`, `allow_failure`, `variables`) |
| `needs` | da quali job dipende: parte appena finiscono, senza aspettare tutto lo stage precedente |
| `dependencies` | da quali job scaricare gli artefatti (`[]`: nessuno) |
| `artifacts` | file da conservare e passare avanti; `reports` per test, copertura, dotenv |
| `cache` | file da riusare fra pipeline (`key`, `paths`, `policy: pull`/`push`) |
| `when` | `on_success` (default), `on_failure`, `always`, `manual`, `delayed`, `never` |
| `allow_failure` | `true`, o `exit_codes: [..]`: un fallimento che non blocca la pipeline |
| `retry` | `max` (fino a 2) e `when` (quali tipi di errore) |
| `timeout` | tempo massimo del job, entro quello del runner e del progetto |
| `parallel` | `N` copie del job, o `matrix` di variabili |
| `environment` | l'ambiente di un deploy: `name`, `url`, `on_stop`, `action`, `auto_stop_in`, `deployment_tier` |
| `resource_group` | un job alla volta fra tutte le pipeline (due deploy sullo stesso server non si accavallano) |
| `tags` | quali runner possono prenderlo (devono avere tutte queste tag) |
| `interruptible` | un push più recente sullo stesso branch può annullarlo |
| `extends`, `!reference` | ereditare da job nascosti, riusare pezzi |
| `trigger` | avviare un'altra pipeline (child o di un altro progetto) |
| `release` | creare una release di GitLab |
| `coverage` | regex che legge la percentuale di copertura dal log |

### Variabili predefinite più usate
| Variabile | Contenuto |
|---|---|
| `CI_COMMIT_SHA`, `CI_COMMIT_SHORT_SHA` | il commit, intero e corto (8 caratteri) |
| `CI_COMMIT_BRANCH` | il branch; **vuota** nelle pipeline di MR e di tag |
| `CI_COMMIT_TAG` | il tag, solo nelle pipeline di tag |
| `CI_COMMIT_REF_NAME`, `CI_COMMIT_REF_SLUG` | branch o tag; lo *slug* è minuscolo, con solo `a-z0-9-` (per nomi di immagini e URL) |
| `CI_COMMIT_MESSAGE`, `CI_COMMIT_TITLE`, `CI_COMMIT_AUTHOR` | messaggio, prima riga, autore |
| `CI_DEFAULT_BRANCH` | il branch di default del progetto (main) |
| `CI_PIPELINE_SOURCE` | cosa l'ha avviata: `push`, `merge_request_event`, `web`, `schedule`, `api`, `trigger`, `pipeline`, `parent_pipeline` |
| `CI_PIPELINE_ID`, `CI_PIPELINE_IID`, `CI_PIPELINE_URL` | id globale, numero nel progetto, indirizzo |
| `CI_JOB_ID`, `CI_JOB_NAME`, `CI_JOB_STAGE`, `CI_JOB_URL`, `CI_JOB_STATUS` | il job (`CI_JOB_STATUS` in `after_script`) |
| `CI_JOB_TOKEN` | token temporaneo del job: API, registry, clone di altri progetti autorizzati |
| `CI_PROJECT_DIR` | la cartella del repository nel container (`/builds/gruppo/progetto`) |
| `CI_PROJECT_PATH`, `CI_PROJECT_NAME`, `CI_PROJECT_ID`, `CI_PROJECT_URL` | il progetto |
| `CI_REGISTRY`, `CI_REGISTRY_IMAGE` | il registry e il nome dell'immagine del progetto |
| `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` | credenziali temporanee per il registry, valide durante il job |
| `CI_MERGE_REQUEST_IID`, `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME`, `CI_MERGE_REQUEST_TARGET_BRANCH_NAME` | solo nelle pipeline di MR |
| `CI_ENVIRONMENT_NAME`, `CI_ENVIRONMENT_URL` | nei job con `environment` |
| `CI_SERVER_URL`, `CI_API_V4_URL` | indirizzo di GitLab e della sua API |
| `GITLAB_USER_LOGIN` | chi ha avviato la pipeline |
| `CI`, `GITLAB_CI` | sempre `true`: per sapere se uno script gira in CI |

### rules
Le regole si leggono dall'alto: **la prima che corrisponde decide**; se nessuna corrisponde il job non c'è.
```yaml
rules:
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH            # == != =~ !~ && || e le parentesi
  - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/              # regex (sintassi RE2)
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    changes: [src/**/*, composer.lock]                    # e il diff tocca questi file
  - if: $CI_PIPELINE_SOURCE == "schedule"
    when: never                                           # mai nelle pipeline programmate
  - exists: [Dockerfile]                                  # se il file esiste nel repository
  - if: $AMBIENTE == "produzione"
    when: manual                                          # pulsante "play"
    allow_failure: false                                  # la pipeline aspetta (blocked) finché qualcuno non preme
  - when: on_success                                      # in tutti gli altri casi: c'è
```
- una variabile non definita vale stringa vuota: `if: $DEPLOY` è vero solo se `DEPLOY` ha un valore
- `changes` senza `compare_to` confronta con il push precedente; sul primo push di un branch nuovo (e nelle pipeline
  avviate dal pulsante o da schedule) è sempre vero. In una MR confronta con il branch di destinazione.
  `changes: { paths: [...], compare_to: refs/heads/main }` fissa il riferimento
- `only`/`except` sono la sintassi vecchia, che si trova ancora in giro: le `rules` la sostituiscono e non si mescolano
  nello stesso job

### workflow: quando creare la pipeline
Senza `workflow`, un push su un branch con una MR aperta crea **due** pipeline (una di branch, una di MR) se i job
hanno regole per entrambe. Lo schema consigliato:
```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS     # branch con MR aperta: basta quella della MR
      when: never
    - if: $CI_COMMIT_BRANCH
    - if: $CI_COMMIT_TAG
  auto_cancel:
    on_new_commit: interruptible                          # un push nuovo annulla i job interruptible della pipeline vecchia
```
Un commit con `[skip ci]` (o `git push -o ci.skip`) non crea pipeline. `workflow:name` dà un titolo alla pipeline.

### needs: grafo invece di stage in fila
```yaml
test-frontend:
  stage: test
  needs: [build-frontend]                     # parte appena finisce build-frontend; scarica solo i SUOI artefatti
lint:
  needs: []                                   # parte subito, all'inizio della pipeline
deploy:
  needs:
    - job: test
    - job: build
      artifacts: false                        # aspetta build ma non ne scarica gli artefatti
    - job: opzionale
      optional: true                          # se il job non è nella pipeline, va bene lo stesso
```
Con `needs` lo stage serve solo a disporre i job nell'interfaccia. Nella pagina della pipeline, *Job dependencies*
mostra il grafo.

### parallel
```yaml
test:
  parallel: 4                                 # 4 copie: CI_NODE_INDEX (1..4), CI_NODE_TOTAL (4)
  script: ./test.sh --shard "$CI_NODE_INDEX/$CI_NODE_TOTAL"
compatibilità:
  image: php:$PHP-cli
  parallel:
    matrix:                                   # una copia per combinazione: "compatibilità: [8.3, mysql]"...
      - PHP: ["8.3", "8.4"]
        DB: [mysql, postgres]
      - PHP: "8.4"                            # più blocchi: combinazioni aggiuntive
        DB: sqlite
```

### artifacts e cache
```yaml
build:
  script: npm ci && npm run build
  artifacts:
    paths: [dist/]
    exclude: [dist/**/*.map]
    expire_in: 1 week                         # dopo, cancellati (gli artefatti dell'ultima pipeline riuscita restano)
    when: always                              # anche se il job fallisce (on_success di default)
    name: "dist-$CI_COMMIT_SHORT_SHA"
    reports:
      junit: report.xml                       # scheda Tests della pipeline, e i test falliti nella MR
      coverage_report: { coverage_format: cobertura, path: coverage.xml }   # righe coperte nel diff della MR
      dotenv: build.env                       # CHIAVE=valore -> variabili dei job successivi
  cache:
    key:
      files: [package-lock.json]              # una cache per ogni versione del lockfile
    paths: [.npm/]                            # dentro CI_PROJECT_DIR: fuori non viene salvata
    policy: pull-push                         # pull: solo lettura (per i job che non la cambiano)
```
| | artefatti | cache |
|---|---|---|
| scopo | risultato del lavoro: pacchetti, report, binari | velocità: dipendenze scaricate |
| fra job della stessa pipeline | sì, sempre | forse |
| fra pipeline diverse | no (si scaricano dall'API) | sì, se la chiave coincide |
| dove stanno | su GitLab, scaricabili dalla pagina del job | sul runner (o su S3/GCS con più runner) |

Scaricare un artefatto da fuori: `curl -L -H "PRIVATE-TOKEN: $T" "$API/projects/ID/jobs/artifacts/main/download?job=build" -o a.zip`.

### Variabili CI/CD: segreti e impostazioni
Si salvano in *Settings > CI/CD > Variables* (progetto, gruppo o istanza) e arrivano ai job come variabili d'ambiente.
| Opzione | Effetto |
|---|---|
| **Masked** | nel log compare `[MASKED]`. Il valore deve avere almeno 8 caratteri, su una riga, senza alcuni simboli |
| **Masked and hidden** | in più, nessuno lo rilegge dall'interfaccia dopo il salvataggio |
| **Protected** | solo nelle pipeline di branch e tag **protetti**: un branch qualunque non vede le chiavi di produzione |
| **Type: File** | il job riceve il percorso di un file temporaneo con il valore: kubeconfig, chiavi SSH, certificati |
| **Environment scope** | solo nei job con quell'`environment` (`production`, `review/*`) |
| **Expand** | se `$ALTRO` dentro il valore viene espanso (spento: il valore è preso alla lettera) |

Precedenza, dalla più forte: variabili della pipeline (avvio manuale, API, schedule, trigger) > variabili del progetto >
del gruppo > dell'istanza > variabili da report `dotenv` > `variables` del job > `variables` globali del file > predefinite.

> **ATTENZIONE**: *masked* nasconde il valore **esatto** nel log, non lo protegge. `echo $T | base64` o un `set -x`
> con trasformazioni lo stampano in chiaro, e chi può modificare il `.gitlab-ci.yml` di un branch che vede la variabile
> può leggerla. Per questo i segreti di produzione si fanno **protected** e si limita chi può fare push o merge sui branch
> protetti (*Settings > Repository > Protected branches*).

Variabili che si scelgono all'avvio manuale (*New pipeline*), con menu a tendina:
```yaml
variables:
  AMBIENTE:
    value: sviluppo
    options: [sviluppo, collaudo, produzione]
    description: Dove rilasciare
```
Le versioni recenti di GitLab offrono per lo stesso scopo gli **input** (`spec:inputs`, tipizzati e validati), sia per
le pipeline avviate a mano sia per i componenti.

### services: database nei test
```yaml
test:
  image: php:8.4-cli
  services:
    - name: mysql:8.4
      alias: db                               # il nome host con cui il job lo raggiunge
      variables: { MYSQL_ROOT_PASSWORD: segreta, MYSQL_DATABASE: test }   # solo per il servizio
  variables:
    DB_HOST: db                               # le variabili del job arrivano anche ai servizi
  script:
    - until php -r 'new PDO("mysql:host=db", "root", "segreta");' 2>/dev/null; do sleep 1; done
    - vendor/bin/phpunit
```
Il servizio parte prima dello script ma "partito" non vuol dire "pronto": un ciclo di attesa serve sempre.

### Ambienti e deploy
```yaml
deploy-staging:
  environment:
    name: staging
    url: https://staging.example.com            # pulsante "Open" in Operate > Environments
    on_stop: ferma-staging                      # il job che lo spegne (pulsante "Stop")
    auto_stop_in: 1 week
  resource_group: staging                       # mai due deploy insieme
  script: ./deploy.sh staging

review:                                         # un ambiente per ogni branch: review app
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

deploy-produzione:
  environment: { name: production, deployment_tier: production }
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
```
Dalla pagina di un ambiente si rilancia un deploy precedente (*Rollback*): riesegue il job di quel commit.
Con gli **ambienti protetti** (Premium) si sceglie chi può lanciare i deploy di produzione; in CE si ottiene qualcosa di
simile con variabili protette e branch protetti.

### include, extends, !reference: non ripetersi
```yaml
include:
  - local: ci/modelli.yml                                    # stesso repository
  - project: gruppo/ci-comune                                # un altro progetto
    ref: v2.1.0                                              # un tag: le modifiche al modello non rompono tutti
    file: [php.yml, docker.yml]
  - remote: https://example.com/ci/lint.yml
  - template: Jobs/SAST.gitlab-ci.yml                        # modelli forniti da GitLab
  - component: $CI_SERVER_FQDN/gruppo/componenti/php-test@1.2.0   # componente CI/CD, con input
    inputs:
      versione_php: "8.4"

test:
  extends: [.php, .solo-main]                 # unisce le mappe in profondità; le liste (script) si sostituiscono
  script:
    - !reference [.comandi, prepara]          # inserisce una lista presa da un altro blocco, anche da un include
    - vendor/bin/phpunit
```
- le **ancore YAML** (`&nome`, `<<: *nome`) funzionano solo dentro lo stesso file; `extends` e `!reference` anche fra
  file inclusi
- un **componente CI/CD** è un modello versionato con parametri dichiarati (`spec:inputs`), pubblicato nel *CI/CD
  Catalog*: il modo moderno di condividere pipeline fra progetti, al posto di `include: project`
- *Build > Pipeline editor > Full configuration* mostra il risultato dopo include ed extends

### Pipeline figlie e fra progetti
```yaml
frontend:
  trigger:
    include: frontend/.gitlab-ci.yml          # child pipeline: una pipeline a parte, collegata a questa
    strategy: depend                          # questo job prende l'esito della pipeline figlia
  rules:
    - changes: [frontend/**/*]                # monorepo: si costruisce solo la parte cambiata
deploy-infra:
  trigger:
    project: gruppo/infrastruttura            # pipeline di un altro progetto
    branch: main
```

## Runner
```bash
# 1. crearlo su GitLab: Settings > CI/CD > Runners > New project runner (o Admin > CI/CD > Runners per l'istanza),
#    oppure con l'API. Si ottiene un token glrt-...
curl -H "PRIVATE-TOKEN: $T" -X POST "$API/user/runners" \
    --data runner_type=project_type --data project_id=42 --data tag_list=docker,php

# 2. installarlo sulla macchina (Debian/Ubuntu)
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt install gitlab-runner

# 3. registrarlo: scrive /etc/gitlab-runner/config.toml
sudo gitlab-runner register --non-interactive --url https://gitlab.example.com --token glrt-... \
    --executor docker --docker-image alpine:3.22

sudo gitlab-runner list                       # i runner in config.toml
sudo gitlab-runner verify                     # sono ancora validi su GitLab?
sudo systemctl status gitlab-runner           # il servizio
sudo journalctl -u gitlab-runner -f           # log
```
I vecchi *registration token* (`gitlab-runner register -r ...`, senza creare prima il runner) sono deprecati e verranno
rimossi in GitLab 20.0: le guide che li usano sono vecchie.

| Tipo | Chi lo usa |
|---|---|
| instance | tutti i progetti dell'istanza (su GitLab.com: i runner condivisi di GitLab, con minuti di calcolo a consumo) |
| group | i progetti di un gruppo |
| project | un progetto solo |

Le **tag** legano job e runner: un job con `tags: [php, docker]` va solo a un runner che ha entrambe; un runner con
*Run untagged jobs* prende anche i job senza tag.

Il pezzo importante di `config.toml` per l'executor docker:
```toml
concurrent = 4                                # job contemporanei, in totale

[[runners]]
  name = "runner-1"
  url = "https://gitlab.example.com"
  token = "glrt-..."
  executor = "docker"
  [runners.docker]
    image = "alpine:3.22"                     # se il job non ha image
    privileged = false                        # true solo se servono servizi docker:dind (e allora il runner è dedicato)
    volumes = ["/cache"]
    pull_policy = ["if-not-present"]          # non riscaricare ogni volta le immagini (default: always)
```
Il runner rilegge `config.toml` da solo quando cambia. Per costruire immagini Docker nei job le strade sono tre:
`services: [docker:dind]` con runner `privileged` (isolato, lento), il socket dell'host montato nei job
(`volumes = ["/var/run/docker.sock:/var/run/docker.sock"]`: veloce, ma ogni job controlla l'host), oppure strumenti che
non vogliono un demone (`buildah`, `kaniko` non più mantenuto, `buildkit` rootless).

## GitLab da riga di comando
### API REST
Token: *User settings > Access tokens* (personal), oppure token di progetto o di gruppo (*Settings > Access tokens*),
legati a un utente-robot: meglio per gli automatismi.
```bash
T=glpat-...; API=https://gitlab.example.com/api/v4; P=gruppo%2Fprogetto     # il percorso del progetto con / -> %2F
curl -s -H "PRIVATE-TOKEN: $T" "$API/projects/$P/pipelines?per_page=5" | jq '.[] | {id, ref, status}'
curl -s -H "PRIVATE-TOKEN: $T" -X POST "$API/projects/$P/pipeline" \
    -H "Content-Type: application/json" \
    -d '{"ref":"main","variables":[{"key":"AMBIENTE","value":"collaudo"}]}'   # avvia una pipeline
curl -s -H "PRIVATE-TOKEN: $T" "$API/projects/$P/pipelines/123/jobs" | jq -r '.[] | "\(.name) \(.status)"'
curl -s -H "PRIVATE-TOKEN: $T" "$API/projects/$P/jobs/456/trace"            # il log di un job
curl -s -H "PRIVATE-TOKEN: $T" -X POST "$API/projects/$P/jobs/456/retry"    # riprova
curl -s -H "PRIVATE-TOKEN: $T" -X POST "$API/projects/$P/jobs/457/play"     # avvia un job manuale
curl -s -H "PRIVATE-TOKEN: $T" -X POST "$API/projects/$P/pipelines/123/cancel"
curl -s -H "PRIVATE-TOKEN: $T" "$API/projects/$P/variables"                 # variabili CI/CD (valori in chiaro!)
curl -s -H "PRIVATE-TOKEN: $T" -X POST "$API/projects/$P/variables" \
    --data key=API_KEY --data value=segreto12345 --data masked=true --data protected=true
jq -Rs '{content: .}' .gitlab-ci.yml | curl -s -H "PRIVATE-TOKEN: $T" -H "Content-Type: application/json" \
    -X POST "$API/projects/$P/ci/lint" -d @- | jq '{valid, errors}'        # valida il file prima del push
```
Avviare una pipeline da un altro sistema senza token personali: *Settings > CI/CD > Pipeline trigger tokens*, poi
`curl -X POST --form token=$TRIGGER --form ref=main "$API/projects/ID/trigger/pipeline"` (nel job `CI_PIPELINE_SOURCE`
vale `trigger`).

### glab
La CLI ufficiale di GitLab (https://gitlab.com/gitlab-org/cli), come `gh` per GitHub.
```bash
glab auth login --hostname gitlab.example.com
glab ci status                                # pipeline del branch corrente
glab ci view                                  # vista interattiva: job, log, retry
glab ci run -b main --variables AMBIENTE:collaudo
glab ci trace                                 # segue il log di un job
glab ci lint                                  # valida .gitlab-ci.yml
glab mr create --fill --target-branch main    # merge request dal branch corrente
glab variable set API_KEY "valore-segreto" --masked --protected
```

## Esempi di riferimento
Pipeline complete che nel laboratorio non girano perché servono servizi esterni.

### Laravel: test, build, deploy via SSH
```yaml
stages: [test, build, deploy]

variables:
  IMMAGINE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

test:
  stage: test
  image: php:8.4-cli
  services:
    - name: mysql:8.4
      alias: mysql
  variables:
    MYSQL_ROOT_PASSWORD: secret
    MYSQL_DATABASE: testing
    DB_CONNECTION: mysql
    DB_HOST: mysql
    DB_DATABASE: testing
    DB_USERNAME: root
    DB_PASSWORD: secret
    COMPOSER_CACHE_DIR: $CI_PROJECT_DIR/.composer
  cache:
    key: { files: [composer.lock] }
    paths: [.composer/, vendor/]
  before_script:
    - apt-get update -qq && apt-get install -yqq git unzip libzip-dev > /dev/null
    - docker-php-ext-install pdo_mysql zip > /dev/null
    - curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  script:
    - composer install --no-interaction --prefer-dist --no-progress
    - cp .env.example .env && php artisan key:generate
    - php artisan migrate --force
    - php artisan test --log-junit report.xml
  artifacts:
    when: always
    reports: { junit: report.xml }

build:
  stage: build
  image: docker:29-cli
  services: [docker:29-dind]                  # con un runner privileged; DOCKER_HOST lo imposta l'immagine docker
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build -t "$IMMAGINE" .
    - docker push "$IMMAGINE"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy:
  stage: deploy
  image: alpine:3.22
  environment: { name: production, url: https://app.example.com }
  resource_group: production
  before_script:
    - apk add --no-cache openssh-client
    - chmod 600 "$SSH_KEY"                    # SSH_KEY: variabile di tipo File, protected
    - echo "$SSH_KNOWN_HOSTS" > known_hosts   # ssh-keyscan del server, salvato come variabile: niente accept-new
  script:
    - ssh -i "$SSH_KEY" -o UserKnownHostsFile=known_hosts deploy@203.0.113.10
        "cd /srv/app && IMMAGINE=$IMMAGINE docker compose up -d && docker compose exec -T app php artisan migrate --force"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
```

### Terraform con piano approvato
Il piano si calcola nella MR, si guarda, si applica **quel** piano ([../09-terraform/terraform.md](../09-terraform/terraform.md)).
GitLab può fare da backend per lo stato (*Operate > Terraform states*, backend `http`).
```yaml
.terraform:
  image: { name: hashicorp/terraform:1.16, entrypoint: [""] }
  variables: { TF_IN_AUTOMATION: "1" }
  before_script: [terraform init -input=false]

plan:
  extends: .terraform
  script:
    - terraform plan -input=false -out=piano.tfplan
    - terraform show -no-color piano.tfplan > piano.txt
  artifacts:
    paths: [piano.tfplan, piano.txt]
    expire_in: 1 week

apply:
  extends: .terraform
  needs: [plan]                               # usa il piano salvato, non ne calcola uno nuovo
  script: [terraform apply -input=false piano.tfplan]
  environment: { name: production }
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
```

### Deploy su Kubernetes
Con un kubeconfig in una variabile di tipo File chiamata `KUBECONFIG`, protected
([../06-kubernetes/kubernetes.md](../06-kubernetes/kubernetes.md)):
```yaml
deploy:
  image: { name: alpine/k8s:1.34.1, entrypoint: [""] }
  environment: { name: production }
  script:
    - kubectl set image deployment/mia-app app="$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"
    - kubectl rollout status deployment/mia-app --timeout=120s
    # con Helm: helm upgrade --install mia-app ./chart --set image.tag=$CI_COMMIT_SHORT_SHA --wait --rollback-on-failure
```
L'alternativa senza credenziali del cluster in GitLab è il **GitLab agent for Kubernetes** (`agentk`), installato nel
cluster: si collega lui a GitLab, e i job usano il contesto `gruppo/progetto:agente`. Oppure GitOps con Argo CD o Flux:
la pipeline aggiorna un repository di manifest, il cluster si allinea da solo.

### Release su tag
```yaml
release:
  image: registry.gitlab.com/gitlab-org/cli:latest   # glab: crea la release
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  script: [echo "release $CI_COMMIT_TAG"]
  release:
    tag_name: $CI_COMMIT_TAG
    description: "Versione $CI_COMMIT_TAG"
```

## Jenkins e GitLab CI a confronto
| | Jenkins | GitLab CI |
|---|---|---|
| definizione | `Jenkinsfile` (Groovy) | `.gitlab-ci.yml` (YAML) |
| server | Jenkins da installare, plugin da curare, collegato al Git | integrato in GitLab |
| esecuzione | agenti ed esecutori | runner ed executor |
| ambiente del job | il workspace sul nodo (o `agent { docker }`) | un container nuovo per job (executor docker) |
| condizioni | `when { branch 'main' }` | `rules: - if: $CI_COMMIT_BRANCH == "main"` |
| parallelo | `parallel`, `matrix` | job nello stesso stage, `needs`, `parallel:matrix` |
| passare file | `stash`/`unstash`, `archiveArtifacts` | `artifacts` (automatici fra stage) |
| segreti | Credentials, `withCredentials` | variabili CI/CD masked/protected/file |
| approvazione | `input` | `when: manual` (+ ambienti protetti) |
| codice condiviso | Shared Library (Groovy) | `include`, `extends`, componenti CI/CD |
| interfaccia di MR | plugin | nativa: test, copertura, ambienti di review nella MR |
| logica complessa | Groovy, quanto si vuole | poca: la logica va negli script, il YAML resta dichiarativo |

## Buone pratiche
1. `workflow:rules` sempre, per non avere pipeline doppie (branch + MR) e controllare quando si parte
2. immagini con versione (`python:3.13-slim`, non `python:latest`) e `pull_policy: if-not-present` sul runner
3. `needs` per non aspettare stage interi; `interruptible: true` e `auto_cancel` per non sprecare runner su commit vecchi
4. segreti solo nelle variabili CI/CD, **protected** per tutto ciò che tocca la produzione, di tipo **File** per chiavi e
   kubeconfig; mai `set -x` in un job che usa segreti
5. cache con `key: files` sul lockfile; artefatti con `expire_in`, solo quello che serve davvero ai job dopo
6. logica lunga in script nel repository (`./ci/deploy.sh`), non in decine di righe YAML: si prova anche in locale
7. deploy con `environment`, `resource_group` e un job manuale (o ambiente protetto) per la produzione
8. modelli condivisi con `include: project` su un **tag**, o componenti versionati: un cambio al modello non rompe 100 progetti
9. provare il file prima del push: *Pipeline editor*, `glab ci lint`, `gitlab-ci-local`

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `This job is stuck because you don't have any active runners that can run this job` | nessun runner online con quelle `tags` | togliere le tag, o abilitare *Run untagged jobs*, o avviare un runner con quelle tag |
| `jobs:x:script config should be a string or a nested array of strings` | una riga dello script contiene `: ` ed è diventata una mappa YAML | la riga tra apici singoli |
| il job non compare nella pipeline | nessuna `rules` corrisponde (o `workflow:rules` ha escluso la pipeline) | *Pipeline editor > Validate* simulando il branch; ricordare che `CI_COMMIT_BRANCH` è vuota nelle MR |
| due pipeline per lo stesso push | pipeline di branch e di MR insieme | `workflow:rules` con `$CI_OPEN_MERGE_REQUESTS` |
| variabile vuota nel job | variabile **protected** e branch non protetto, o `environment scope` diverso | proteggere il branch o togliere l'opzione |
| `Variable masking failed` / non si può mascherare | valore troppo corto o con caratteri non ammessi | almeno 8 caratteri, o codificarlo in base64 e decodificarlo nel job |
| `Cannot connect to the Docker daemon at tcp://docker:2375` | manca `services: [docker:dind]`, o il runner non è `privileged`, o TLS non allineato | servizio dind + runner privileged; con TLS `DOCKER_TLS_CERTDIR: "/certs"` |
| `blob unknown to registry` al `docker push` | indice OCI con attestazione (Docker 29, image store containerd) rifiutato dal registry | `docker build --provenance=false` |
| `fatal: unable to access 'http://gitlab.localhost/...'` dal job | `*.localhost` risolto a 127.0.0.1 da curl e git | un nome vero, o `clone_url` del runner |
| `toomanyrequests` scaricando le immagini | limiti di Docker Hub | `pull_policy: if-not-present`, Dependency Proxy di GitLab, un mirror |
| la cache non viene mai trovata | percorso fuori da `CI_PROJECT_DIR`, o chiave diversa, o runner diversi senza cache condivisa | percorsi relativi al progetto; cache distribuita (S3) con più runner |
| `ERROR: Job failed: execution took longer than 1h0m0s` | timeout del progetto (default 1 ora) o del runner | `timeout:` nel job, *Settings > CI/CD > General pipelines* |
