# Pipeline di esempio

Ogni file `*.jenkinsfile` diventa un job con lo stesso nome, creato da [jobs.groovy](jobs.groovy) all'avvio di Jenkins.
Si lanciano con *Build Now* (o *Build with Parameters*) e si leggono in *Console Output* e nella vista degli stage.

| Job | Cosa mostra | Cosa guardare |
|---|---|---|
| [01-base](01-base.jenkinsfile) | struttura Declarative, `environment`, `options`, variabili di Jenkins, `sh` con `returnStdout`/`returnStatus`, artefatti, `post` | apici doppi (Groovy) e singoli (shell) nel log; `saluto.txt` fra gli artefatti del build |
| [02-parametri](02-parametri.jenkinsfile) | `parameters`, `when` con `expression`, `allOf`, `not`; validazione con `error` | il primo build usa i default; poi *Build with Parameters*. Con `VERSIONE=2.1` fallisce; con `AMBIENTE=produzione` gira l'ultimo stage |
| [03-errori-e-post](03-errori-e-post.jenkinsfile) | `retry`, `timeout`, `catchError`, `unstable`, `error`; tutte le condizioni di `post` | `ESITO=successo`, `instabile`, `fallimento`, poi di nuovo `successo`: cambiano colore e blocchi `post` eseguiti (`changed`, `fixed`) |
| [04-parallelo-e-matrix](04-parallelo-e-matrix.jenkinsfile) | `parallel` con `failFast`, `matrix` con `axes` ed `excludes` | tre rami insieme (workspace `@2`, `@3`); tre combinazioni della matrice invece di quattro |
| [05-credenziali](05-credenziali.jenkinsfile) | `credentials()` per secret text e utente/password, `withCredentials` | i segreti nel log sono `****`; nell'ultimo stage il `Warning` sull'interpolazione Groovy |
| [06-agente-docker](06-agente-docker.jenkinsfile) | `agent { docker }`, `args`, `docker.image().inside` | `docker run -u 1000:1000 -v workspace...`: il workspace montato nel container; versioni di Python e Node senza installarli |
| [07-ci-app](07-ci-app.jenkinsfile) | CI completa di [../app/](../app/): test con pytest in un container, report JUnit, lint del Dockerfile con Hadolint, `docker.build`, scansione con Trivy (blocca i CRITICAL), smoke test | *Test Result* nella pagina del build: 3 test più le vulnerabilità HIGH correggibili, che rendono il build **UNSTABLE** (giallo); `risposta.txt` fra gli artefatti; l'immagine `kb-app:N` nel demone dind |
| [08-approvazione](08-approvazione.jenkinsfile) | direttiva `input` con `submitter` e parametri, timeout dello stage | il build si ferma su *Input requested*: rispondere dalla pagina del build (o dalla vista degli stage). Intanto nessun esecutore è occupato |
| [09-agenti](09-agenti.jenkinsfile) | `agent { label }`, `stash`/`unstash` fra nodi, rami paralleli su agenti diversi | richiede `./agenti.sh && docker compose --profile agenti up -d`; il file preparato su agent1 letto su agent2 e agent3 |

Primo build con i parametri di default, provato su Jenkins avviato da zero (Docker Desktop su Windows): da `01-base` a
`06-agente-docker` finiscono tutti in `SUCCESS`. `07-ci-app` richiede che i container dentro `docker` raggiungano
internet (pip, Trivy); se la rete blocca i DNS pubblici fallisce su `pip install`: vedi *Problemi comuni* in
[../jenkins.md](../jenkins.md). `08-approvazione` aspetta una risposta e `09-agenti` richiede gli agenti: non sono nei
build automatici.

Aggiungere un esempio: un nuovo file `NN-nome.jenkinsfile` qui, poi *Manage Jenkins > Configuration as Code >
Reload existing configuration*.

Torna a [../](../)
