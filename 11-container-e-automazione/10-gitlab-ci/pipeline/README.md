# Pipeline di esempio

Ogni file `NN-nome.gitlab-ci.yml` diventa il `.gitlab-ci.yml` del progetto `root/NN-nome`, creato da
[../configura.sh](../configura.sh) insieme a `app/` e `ci/`. Il push avvia la pipeline: *Build > Pipelines*, poi un
job per leggerne il log. In locale: `gitlab-ci-local --file pipeline/NN-nome.gitlab-ci.yml` dalla cartella `10-gitlab-ci`.

| Progetto | Cosa mostra | Cosa guardare |
|---|---|---|
| [01-base](01-base.gitlab-ci.yml) | `stages`, `default`, `variables` globali e del job, variabili predefinite, `before_script`/`after_script`, `artifacts` | `out/` fra gli artefatti di `saluto` (*Browse*) e letto da `leggi` nello stage dopo; `SALUTO` che usa l'`APP` del job |
| [02-regole](02-regole.gitlab-ci.yml) | `workflow:rules` e `workflow:name`, `rules` con `if`, `changes`, `exists`, `when: manual` e `delayed`, variabili con `options` | *New pipeline*: menu `AMBIENTE` e campo `VERSIONE`. Con `produzione` compare il job manuale, con `collaudo` uno ritardato di 30 s, con `VERSIONE=2.1` fallisce la validazione. Un branch `feature/x` fa girare `solo-feature` |
| [03-errori](03-errori.gitlab-ci.yml) | `allow_failure` (anche con `exit_codes`), `retry`, `timeout`, `when: on_failure`/`always`, `interruptible` | pipeline *passed with warnings*; i tentativi di `riprova`; `troppo-lento` fermato dopo 30 s; con `ESITO=fallimento` gira `notifica-errore`, con `ESITO=avviso` `codici-uscita` diventa arancione |
| [04-parallelo](04-parallelo.gitlab-ci.yml) | `needs` (anche `needs: []` e su una combinazione della matrice), `parallel:matrix`, `parallel: N` | *Group jobs by: Job dependencies*: il grafo. `test-frontend` parte prima che finisca `build-backend`; 4 job `matrice`, 3 job `diviso` |
| [05-variabili](05-variabili.gitlab-ci.yml) | variabili CI/CD masked, protected, di tipo file, con environment scope; report `dotenv`; `CI_JOB_TOKEN` | `[MASKED]` nel log; `SOLO_PROTETTI` presente su main e vuota su un altro branch; `PASSWORD_STAGING` solo nel job con `environment: staging`. Le variabili: *Settings > CI/CD > Variables* |
| [06-servizi](06-servizi.gitlab-ci.yml) | `services` con `alias` (PostgreSQL, MySQL, Redis), `image` con `entrypoint: [""]` | il ciclo di attesa prima delle query: il servizio parte insieme al job ma non è subito pronto |
| [07-ci-app](07-ci-app.gitlab-ci.yml) | CI di [../app/](../app/): pytest con report JUnit e copertura, `cache` di pip, Hadolint con report Code Quality, build, scansione con Trivy prima del push (blocca i CRITICAL), push nel Container Registry, smoke test | scheda *Tests* (3 test e le vulnerabilità HIGH correggibili del job `immagine`), copertura nella lista dei job, l'immagine in *Deploy > Container registry*, `risposta.txt` fra gli artefatti |
| [08-ambienti](08-ambienti.gitlab-ci.yml) | `environment` con `url`, `on_stop`, `auto_stop_in`, `deployment_tier`; `resource_group`; deploy manuale in produzione; job nascosto con `extends` | *Operate > Environments*; staging su http://localhost:8930; il pulsante *play* di `deploy-produzione` e poi http://localhost:8931; *Stop* su staging lancia `ferma-staging` |
| [09-riuso](09-riuso.gitlab-ci.yml) | `include: local` ([../ci/modelli.yml](../ci/modelli.yml)), `extends` con più modelli, `!reference`, ancore YAML | *Build > Pipeline editor > Full configuration*: il file finale; `personalizzato` che cambia `image` ma tiene il resto del modello |

Per ripubblicare dopo una modifica: `./configura.sh 03` (solo i progetti che iniziano con `03`). Per provare un branch:
dalla pagina del progetto *Code > Branches > New branch*, oppure con git
(`git clone http://gitlab.localhost:8929/root/05-variabili.git`, utente `root` e come password il token di `.env`).

Torna a [../](../)
