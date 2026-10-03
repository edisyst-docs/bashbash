# GitHub Actions

La CI/CD integrata in GitHub. I **workflow** sono file YAML in `.github/workflows/` del repository e partono da
soli a ogni evento scelto: push, pull request, tag, una release, un orario, un pulsante, una chiamata API. Come in
GitLab CI ([../10-gitlab-ci/gitlab-ci.md](../10-gitlab-ci/gitlab-ci.md)) non c'è un server da installare; a differenza
di GitLab, i pezzi riusabili sono **Action** pubblicate da chiunque, che si richiamano per nome.

- **workflow**: un file `.github/workflows/*.yml`. Ha un nome, gli eventi che lo fanno partire (`on:`) e i job
- **evento**: cosa lo avvia (`push`, `pull_request`, `workflow_dispatch`, `schedule`, `release`...), con i suoi filtri
- **job**: un insieme di step che gira su un **runner**. I job di un workflow partono insieme, salvo `needs:`
- **step**: un comando (`run:`) o un'Action (`uses:`). Gli step di un job condividono la macchina e i file
- **runner**: la macchina. Quelli di GitHub (Ubuntu, Windows, macOS, Arm) sono macchine virtuali nuove per ogni job;
  quelli *self-hosted* sono macchine proprie con il programma `actions/runner`
- **Action**: un pezzo riusabile, da un repository (`actions/checkout@<sha>`), dallo stesso repository
  (`./.github/actions/nome`) o da un'immagine Docker
- **contesti ed espressioni**: `${{ github.ref_name }}`, `${{ secrets.TOKEN }}`, `${{ matrix.python }}`: valori che
  GitHub sostituisce prima di eseguire lo step
- **segreti, variabili, ambienti**: valori salvati nelle impostazioni del repository (o dell'organizzazione, o di un
  ambiente), con regole di protezione per gli ambienti come `produzione`
- **`GITHUB_TOKEN`**: un token creato per ogni esecuzione, con i permessi decisi da `permissions:`, che scade a fine job

Documentazione: https://docs.github.com/actions · sintassi completa:
https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax · contesti:
https://docs.github.com/actions/reference/workflows-and-actions/contexts

Versioni del laboratorio: runner `ubuntu-24.04` 2.337.0 (Ubuntu 24.04.5), `gh` 2.92, `act` 0.2.89 (ottobre 2026).

## Gli esempi

I workflow stanno dove GitHub li cerca, in [.github/workflows/](../../.github/workflows/) alla radice del repository:

| Workflow | Cosa mostra |
|---|---|
| [esempio-01-base](../../.github/workflows/esempio-01-base.yml) | struttura, variabili di GitHub, espressioni, gruppi e annotazioni nel log, `GITHUB_OUTPUT`, `GITHUB_ENV`, riepilogo |
| [esempio-02-eventi](../../.github/workflows/esempio-02-eventi.yml) | `push` e `pull_request` con filtri, `workflow_dispatch` con input, condizioni `if:`, input passati in sicurezza |
| [esempio-03-matrix](../../.github/workflows/esempio-03-matrix.yml) | test su Python 3.12-3.15, Linux e Windows: `exclude`, `include`, `fail-fast`, job sperimentali |
| [esempio-04-dipendenze](../../.github/workflows/esempio-04-dipendenze.yml) | `needs`, output dei job, runner Arm, `if: always()`, esito dei job precedenti |
| [esempio-05-artefatti-cache](../../.github/workflows/esempio-05-artefatti-cache.yml) | artefatti fra job, cache di pip, `actions/cache` con `hashFiles` |
| [esempio-06-servizi](../../.github/workflows/esempio-06-servizi.yml) | PostgreSQL e Redis come servizi; job sulla macchina e job in un container |
| [esempio-07-ci-app](../../.github/workflows/esempio-07-ci-app.yml) | la CI di [app/](app/): Hadolint, pytest, build con cache, Trivy, push su `ghcr.io`, `concurrency` |
| [esempio-08-ambienti](../../.github/workflows/esempio-08-ambienti.yml) | ambienti, segreti mascherati, variabili, token OIDC |
| [esempio-09-riuso](../../.github/workflows/esempio-09-riuso.yml) | un'Action composita ([.github/actions/python-app/](../../.github/actions/python-app/action.yml)) e un workflow riusabile ([esempio-09-modello](../../.github/workflows/esempio-09-modello.yml)) |
| [kb](../../.github/workflows/kb.yml) | la CI vera di questa KB: shellcheck, Hadolint con report nella scheda Security, link dei `.md`, tutti i laboratori |

Ogni esempio parte quando cambia il suo file (`push` con `paths:`), o a mano:
```bash
gh workflow run esempio-02-eventi.yml -f ambiente=produzione -f dettagli=true    # sul ramo predefinito
gh workflow run esempio-04-dipendenze.yml --ref mio-ramo -f rompi=true
gh run list --workflow esempio-04-dipendenze.yml --limit 3
gh run watch                                                                      # segue l'ultima esecuzione
gh run view 37142558619 --log                                                     # il log completo
```
La documentazione dice che per `workflow_dispatch` il file deve stare sul ramo predefinito. Nel laboratorio
`gh workflow run ... --ref refactor/riorganizzazione-kb` è partito anche con il file presente solo su quel ramo
(il workflow era già noto a GitHub perché girato con un push).

## Struttura di un workflow
Dall'[esempio 01](../../.github/workflows/esempio-01-base.yml):
```yaml
name: "Esempio 01: base"

on:
  push:
    paths: [.github/workflows/esempio-01-base.yml]
  workflow_dispatch:

permissions:
  contents: read                         # il GITHUB_TOKEN di questo workflow può solo leggere il repository

env:
  SALUTO: Ciao

jobs:
  ciao:
    runs-on: ubuntu-24.04                # una macchina virtuale nuova, distrutta alla fine del job
    timeout-minutes: 5                   # il default è 360 minuti
    steps:
      - name: Scarica il repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Dove sono
        run: |
          echo "$SALUTO da $GITHUB_REPOSITORY, ramo $GITHUB_REF_NAME, commit ${GITHUB_SHA::7}"
```
Senza `actions/checkout` la cartella di lavoro è vuota: il job parte su una macchina pulita e il codice va scaricato.
Sul runner GitHub l'esempio stampa `Ubuntu 24.04.5 LTS`, `4 CPU, 15Gi di RAM, utente runner`: sono le macchine dei
repository pubblici (gratuite e senza limite di minuti; per i privati ci sono minuti inclusi e poi a pagamento).

### Runner

| `runs-on` | Macchina |
|---|---|
| `ubuntu-24.04`, `ubuntu-latest` | Ubuntu 24.04 x64 (`latest` è ancora la 24.04; la 26.04 va chiesta con `ubuntu-26.04`) |
| `ubuntu-24.04-arm` | Ubuntu Arm64: provato nell'esempio 04, `uname -m` stampa `aarch64` |
| `windows-2025`, `windows-latest` | Windows Server 2025; la shell di default è PowerShell |
| `macos-15`, `macos-latest` | macOS su Apple Silicon (per i privati costa 10 volte un minuto Linux) |
| `[self-hosted, linux, gpu]` | un runner proprio, scelto per etichette |

Usare la versione (`ubuntu-24.04`) e non `latest`: quando `latest` passa alla versione nuova cambiano gli strumenti
preinstallati, e una pipeline che funzionava smette senza un commit. L'elenco di cosa c'è su ogni immagine:
https://github.com/actions/runner-images

### Espressioni, variabili, contesti
```yaml
run: |
  echo "espressione: ${{ github.workflow }} sul runner ${{ runner.os }}"   # la sostituisce GitHub, prima
  echo "variabile:   $GITHUB_WORKFLOW sul runner $RUNNER_OS"              # la espande la shell, durante
```
Stessa uscita (`Esempio 01: base sul runner Linux`), ma il meccanismo è diverso, e conta:
- `${{ }}` viene sostituita **nel testo dello script** prima che la shell lo veda, anche dentro i commenti. Un
  `${{ }}` vuoto in un commento rende il workflow non valido (act: `Failed to parse: unexpected end of input`)
- se il valore viene da fuori (titolo di una PR, nome di un ramo, testo di un input), finisce eseguito come codice:
  vedi [Iniezione di comandi](#iniezione-di-comandi)

| Contesto | Esempi |
|---|---|
| `github` | `github.event_name`, `github.ref`, `github.ref_name`, `github.sha`, `github.actor`, `github.repository`, `github.event.*` (tutto il JSON dell'evento) |
| `env`, `vars`, `secrets` | variabili del file, variabili e segreti salvati nelle impostazioni |
| `inputs` | gli input di `workflow_dispatch` e `workflow_call` |
| `steps`, `needs`, `jobs` | output ed esito di step e job: `steps.data.outputs.oggi`, `needs.versione.outputs.numero`, `needs.verifica.result` |
| `matrix`, `strategy` | i valori della combinazione corrente |
| `runner` | `runner.os`, `runner.arch`, `runner.temp` |

Funzioni: `contains()`, `startsWith()`, `format()`, `join()`, `toJSON()`, `fromJSON()`, `hashFiles()`, e per le
condizioni `success()`, `failure()`, `always()`, `cancelled()`. Operatori `==`, `!=`, `&&`, `||`, `!` (`a || 'default'`
dà un valore di ripiego).

### Comandi per il runner
Uno step parla con il runner scrivendo righe speciali sullo standard output o in alcuni file:

| Comando | Effetto |
|---|---|
| `echo "nome=valore" >> "$GITHUB_OUTPUT"` | output dello step (`steps.<id>.outputs.nome`) |
| `echo "NOME=valore" >> "$GITHUB_ENV"` | variabile d'ambiente per gli step successivi del job |
| `echo "$HOME/bin" >> "$GITHUB_PATH"` | aggiunge al `PATH` degli step successivi |
| `echo "## Titolo" >> "$GITHUB_STEP_SUMMARY"` | Markdown nella pagina riepilogo dell'esecuzione |
| `echo "::group::Titolo"` ... `echo "::endgroup::"` | una sezione richiudibile nel log |
| `echo "::notice title=T::testo"`, `::warning::`, `::error file=f,line=3::` | annotazioni: nel riepilogo, e sul file nelle PR |
| `echo "::add-mask::$VALORE"` | maschera un valore calcolato (i segreti lo sono già) |
| `echo "::add-matcher::matcher.json"` | trasforma in annotazioni le righe di un programma (vedi la CI della KB) |

### Shell
Il default su Linux è `bash -e {0}`: si ferma al primo comando fallito, ma **senza** `pipefail`. Con `shell: bash`
scritto esplicitamente diventa `bash --noprofile --norc -eo pipefail {0}`: l'esempio 01 lo mostra con
`false | true`, che fallisce solo nel secondo caso. Su Windows il default è PowerShell; `shell: bash` usa Git Bash
(nell'esempio 03 i test girano così su `windows-2025`). Per tutti gli step di un job: `defaults: run: shell: bash`.

## Eventi
| Evento | Quando | Filtri utili |
|---|---|---|
| `push` | push di commit o tag | `branches`, `branches-ignore`, `tags`, `paths`, `paths-ignore` |
| `pull_request` | PR aperta, aggiornata, riaperta | come `push`, più `types: [opened, synchronize, labeled...]` |
| `pull_request_target` | come sopra, ma con il codice e i permessi del ramo **di destinazione** | pericoloso: vedi [Sicurezza](#sicurezza) |
| `workflow_dispatch` | pulsante *Run workflow*, `gh workflow run`, API | `inputs` di tipo `string`, `boolean`, `choice`, `number`, `environment` |
| `schedule` | a orario, `cron` in UTC, sul ramo predefinito | può partire con minuti di ritardo nelle ore di punta |
| `workflow_call` | chiamato da un altro workflow | `inputs`, `secrets`, `outputs` |
| `release`, `issues`, `issue_comment`... | gli eventi del repository | `types` |
| `workflow_run` | quando un altro workflow finisce | `workflows`, `types: [completed]` |

Nell'[esempio 02](../../.github/workflows/esempio-02-eventi.yml), avviato con
`gh workflow run esempio-02-eventi.yml -f ambiente=produzione -f dettagli=true`: il job `evento` stampa
`ambiente scelto: produzione`, e il job `produzione`, con `if: inputs.ambiente == 'produzione'`, parte. Con il push
dello stesso file invece `produzione` è *skipped*: un job saltato non è un errore.

`paths:` serve anche nei monorepo: la CI del backend parte solo se cambia `backend/**`. Un workflow saltato per i
filtri non compare proprio; se quel workflow è un controllo obbligatorio per il merge, la PR resta bloccata in attesa.

## Matrix
Un job, molte combinazioni ([esempio 03](../../.github/workflows/esempio-03-matrix.yml)):
```yaml
    continue-on-error: ${{ matrix.sperimentale }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-24.04, windows-2025]
        python: ["3.12", "3.13", "3.14"]
        sperimentale: [false]
        exclude:
          - {os: windows-2025, python: "3.12"}
        include:
          - {os: ubuntu-24.04, python: "3.15", sperimentale: true}
```
2 × 3 = 6 combinazioni, meno una esclusa, più una aggiunta: 6 job, partiti tutti insieme.

| Job | Python | Durata |
|---|---|---|
| test py3.12 su ubuntu-24.04 | 3.12.14 | 9 s |
| test py3.13 su ubuntu-24.04 | 3.13.15 | 10 s |
| test py3.14 su ubuntu-24.04 | 3.14.7 | 11 s |
| test py3.15 su ubuntu-24.04 | 3.15.0rc2 (`allow-prereleases`) | 23 s |
| test py3.13 su windows-2025 | 3.13.15 | 24 s |
| test py3.14 su windows-2025 | 3.14.7 | 19 s |

- `fail-fast: true` (il default) annulla tutti gli altri job al primo fallimento: bene per risparmiare, male per capire
  su quali versioni si rompe
- `continue-on-error` a livello di job: la 3.15 può fallire senza rendere rosso il workflow
- i valori sono stringhe: `"3.10"` fra virgolette, altrimenti YAML legge il numero `3.1`
- al massimo 256 job per matrix; `max-parallel` limita quanti girano insieme

## Job in fila: needs e output
[Esempio 04](../../.github/workflows/esempio-04-dipendenze.yml):
```
versione ──┬── build-linux ──┬── riepilogo (sempre)
           └── build-arm  ───┤
                verifica ────┘
```
```yaml
  versione:
    outputs:
      numero: ${{ steps.calcola.outputs.numero }}
    steps:
      - id: calcola
        run: echo "numero=1.$GITHUB_RUN_NUMBER.0" >> "$GITHUB_OUTPUT"
  build-linux:
    needs: versione
    steps:
      - run: echo "build ${{ needs.versione.outputs.numero }} per $(uname -m)"
  riepilogo:
    needs: [build-linux, build-arm, verifica]
    if: always()
```
Avviato con `-f rompi=true` (il job `verifica` esce con 1): l'esecuzione è *failure*, ma `riepilogo` gira comunque
e stampa
```
build-linux: success
build-arm:   success
verifica:    failure
##[warning]almeno un job è fallito
```
Senza `if: always()` un job il cui `needs` è fallito viene saltato. Gli output dei job sono stringhe (al massimo
1 MB per job); per file veri si usano gli artefatti.

## Artefatti e cache
[Esempio 05](../../.github/workflows/esempio-05-artefatti-cache.yml).

| | Artefatti | Cache |
|---|---|---|
| a cosa servono | passare file fra job, o tenerli dopo l'esecuzione (report, binari) | non rifare lavoro lento fra un'esecuzione e l'altra |
| Action | `upload-artifact` / `download-artifact` | `actions/cache`, o `cache:` di `setup-python`, `setup-node`... |
| durata | `retention-days` (default 90) | 7 giorni senza uso; 10 GB per repository, poi i più vecchi vengono tolti |
| garantiti | sì | no: se manca si rifà il lavoro |

Nel laboratorio l'artefatto `report-test` (report JUnit e copertura HTML) pesa 27 KB, scade dopo 7 giorni, e il job
`usa-il-report` lo scarica e legge `tests="3"`. La cache, alla prima esecuzione:
```
Cache not found for input keys: dati-Linux-b35953f4..., dati-Linux-
Sat Oct  3 17:57:58 UTC 2026
Cache saved with key: dati-Linux-b35953f4...
```
alla seconda (avviata a mano due minuti dopo):
```
Cache restored from key: dati-Linux-b35953f4...
Sat Oct  3 17:57:58 UTC 2026
```
Il file è quello della prima esecuzione. La chiave contiene `hashFiles('.../requirements.txt')`: se cambiano le
dipendenze la chiave cambia e la cache si ricostruisce. `restore-keys` prende la più recente che comincia così.
Un avviso visto alla prima esecuzione, con più workflow partiti insieme sullo stesso push:
`Failed to save: Unable to reserve cache with key setup-python-Linux-..., another job may be creating this cache`.
È innocuo: la stessa chiave la stava già salvando un altro job.

## Servizi e container
[Esempio 06](../../.github/workflows/esempio-06-servizi.yml):
```yaml
  sulla-macchina:
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:18-alpine
        env: {POSTGRES_PASSWORD: prova, POSTGRES_DB: negozio}
        ports: ["5432:5432"]                # il job lo trova su localhost
        options: --health-cmd "pg_isready -U postgres" --health-interval 2s --health-retries 20

  in-un-container:
    runs-on: ubuntu-24.04
    container: python:3.13-slim             # tutti gli step girano qui dentro
    services:
      redis:
        image: redis:8-alpine               # raggiungibile come "redis", senza ports
```
```
2 prodotti, totale 59.40
PostgreSQL 18.6 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit
visite: 3 - Redis 8.10.2
```
Con `options: --health-cmd` il job aspetta che il servizio sia *healthy* prima del primo step. `psql` è già sul
runner (`postgresql-client` fa parte dell'immagine); nel container `python:3.13-slim` invece si installa quello che
serve. Servizi e `container:` funzionano solo sui runner Linux.

## Una CI completa
[Esempio 07](../../.github/workflows/esempio-07-ci-app.yml), la stessa app e la stessa logica delle pipeline
`07-ci-app` di [Jenkins](../07-jenkins/pipeline/07-ci-app.jenkinsfile) e
[GitLab](../10-gitlab-ci/pipeline/07-ci-app.gitlab-ci.yml):
```
lint (Hadolint, 11 s) ─┐
test (pytest, 9 s) ────┴── immagine (50 s): build con cache, Trivy, push su ghcr.io solo se richiesto
```
- `docker/metadata-action` calcola tag ed etichette OCI: `esempio-app:refactor-riorganizzazione-kb` (il ramo) e
  `esempio-app:sha-938003f`, tutti in minuscolo come vuole `ghcr.io`
- `docker/build-push-action` con `load: true` mette l'immagine nel Docker del runner, dove Trivy la legge; con
  `cache-from/cache-to: type=gha` i layer restano nella cache di Actions fra un'esecuzione e l'altra
- Trivy (immagine con digest, vedi [../12-trivy-hadolint/](../12-trivy-hadolint/trivy-hadolint.md)): report delle HIGH
  correggibili nel riepilogo, blocco sulle CRITICAL. Risultato: 0 CRITICAL, 1 HIGH di Debian e 4 del pip incluso
- il push avviene solo con `workflow_dispatch` e `pubblica: true` sul ramo `main`, con il `GITHUB_TOKEN` e
  `permissions: packages: write` **solo** nel job `immagine`. Nel laboratorio non è stato fatto: avrebbe pubblicato
  un'immagine nel profilo GitHub dell'organizzazione
- `concurrency` con `cancel-in-progress`: due push di fila sullo stesso ramo, la prima esecuzione viene annullata

## Ambienti, segreti, variabili, OIDC
[Esempio 08](../../.github/workflows/esempio-08-ambienti.yml). Segreto e variabile creati da riga di comando:
```bash
gh secret set TOKEN_DEMO --body "tok-1234-segreto-abcd"
gh variable set SERVER_DEMO --body "203.0.113.10"
gh secret list && gh variable list
```
```
token: ***
il token è lungo 21 caratteri
server: 203.0.113.10, ambiente: staging
```
- il valore di un segreto nel log diventa `***`. È una sostituzione di testo: un segreto trasformato (in base64,
  spezzato, una lettera alla volta) esce in chiaro. I segreti non si stampano, e basta
- `environment: staging` crea l'ambiente al primo uso (*Settings > Environments*, creato alle 17:57:49). Lì si
  aggiungono **revisori obbligatori** (il job aspetta un'approvazione), un **timer d'attesa**, i **rami ammessi** e
  segreti propri dell'ambiente: `secrets.DB_PASSWORD` vale una cosa in staging e un'altra in produzione
- `concurrency: group: deploy-staging` con `cancel-in-progress: false`: due deploy sullo stesso ambiente vanno in fila
- i segreti non arrivano ai workflow avviati da PR di un **fork**, e il `GITHUB_TOKEN` lì è in sola lettura

**OIDC**. Con `permissions: id-token: write` il job può chiedere a GitHub un token firmato che dice chi è. Il
contenuto, letto nell'esempio:
```
iss                  https://token.actions.githubusercontent.com
aud                  esempio-kb
sub                  repo:edisyst-docs/bashbash:ref:refs/heads/refactor/riorganizzazione-kb
repository           edisyst-docs/bashbash
ref                  refs/heads/refactor/riorganizzazione-kb
event_name           push
job_workflow_ref     edisyst-docs/bashbash/.github/workflows/esempio-08-ambienti.yml@refs/heads/refactor/riorganizzazione-kb
runner_environment   github-hosted
```
AWS, Azure, Google Cloud, Vault e Terraform Cloud si possono configurare per fidarsi di questi token: "a chi presenta
un token con `sub` = `repo:edisyst-docs/bashbash:environment:produzione` do il ruolo di deploy, per un'ora". Nessuna
chiave di accesso salvata nei segreti, niente da ruotare. Con AWS (non provato qui):
```yaml
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@<sha>   # v5
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-github
          aws-region: eu-south-1
```

## Riuso
[Esempio 09](../../.github/workflows/esempio-09-riuso.yml).

| | Action composita | Workflow riusabile |
|---|---|---|
| file | `action.yml` in una cartella qualsiasi (`.github/actions/python-app/`) | un workflow con `on: workflow_call` in `.github/workflows/` |
| si usa | come uno **step**: `- uses: ./.github/actions/python-app` | come un **job**: `jobs.x.uses: ./.github/workflows/esempio-09-modello.yml` |
| contiene | step (ognuno con `shell:` esplicita) | job interi, con `runs-on`, servizi, matrix, ambienti |
| segreti | li riceve come input | `secrets:` dichiarati, o `secrets: inherit` |
| da un altro repository | `uses: org/repo/percorso@<sha>` | `uses: org/repo/.github/workflows/file.yml@<sha>` |

Nel laboratorio: `azione-composita` stampa `Python 3.13.16` (default dell'Action) e `3 passed`; il workflow riusabile,
chiamato con `python: "3.14"`, restituisce la versione usata come output, e il job `dopo` stampa
`il modello ha usato Python 3.14.8`. L'output passa da tre livelli: step → job del modello → `on.workflow_call.outputs`.

## La CI di questa KB
[kb.yml](../../.github/workflows/kb.yml) gira a ogni push e pull request:

| Job | Cosa fa | Tempo |
|---|---|---|
| `shellcheck` | i 18 script dei laboratori e dell'area 11 (gli esercizi di `05-scripting` e `zz-esempi` restano fuori: alcuni sono sbagliati apposta) | 7 s |
| `hadolint` | i 17 Dockerfile: blocca gli errori, e carica il report completo in *Security > Code scanning* | 15 s |
| `link` | i link relativi di tutti i `.md` ([controlla-link.py](../../.github/scripts/controlla-link.py)): 787 controllati | 4 s |
| `laboratori` | matrix sulle 8 aree con un laboratorio: `./lab.sh NN -- 'ls'`, lo stesso comando di chi studia | da 39 s (area 05) a 91 s (area 12), in parallelo |

- **annotazioni**: `echo "::add-matcher::.github/shellcheck-matcher.json"` registra una regex
  ([shellcheck-matcher.json](../../.github/shellcheck-matcher.json)) che trasforma le righe `file:riga:colonna: warning:
  ... [SC2086]` di shellcheck in annotazioni sul file, visibili nella PR. Lo script dei link scrive direttamente
  `::error file=...,line=...::`
- **SARIF**: Hadolint con `--format sarif`, caricato con `github/codeql-action/upload-sarif`: nella scheda Security
  sono comparsi 57 avvisi (DL3008 ×9, DL4006 ×9, DL3059 ×9, DL3015 ×8, DL3007 ×6...), con stato aperto/chiuso e
  storia, senza bloccare la CI. Serve `permissions: security-events: write` in quel job
- **strumenti con digest**: shellcheck e Hadolint girano dalle loro immagini con versione e digest, non con quelli
  preinstallati sul runner (shellcheck 0.9.0 sul runner, 0.11.0 nell'immagine): stessi risultati in locale e in CI

La prima esecuzione ha trovato un difetto vero: i laboratori 06, 08, 10 e 12 (quelli con systemd) uscivano subito con
`exited (255)`, mentre su Docker Desktop funzionavano. Montavano il `/sys/fs/cgroup` della macchina, e su un Linux con
systemd (il runner, o il PC di chi usa la KB su Linux) i due systemd si scontrano. Un workflow di prova sul runner ha
confrontato tre soluzioni:

| Variante | Risultato sul runner |
|---|---|
| bind di `/sys/fs/cgroup` dell'host (com'era) | `Exited (255)` |
| cgroup privato rimontato in scrittura | `mount: /sys/fs/cgroup: cannot remount cgroup read-write, is write-protected` (AppArmor) |
| cgroup privato rimontato, `apparmor=unconfined` | `running`, ssh e nginx `active` |

Ora i laboratori usano la terza (script `avvia-systemd` nel [Dockerfile](../../Dockerfile)): con la correzione tutti
gli 8 laboratori passano sul runner, e il container non tocca più i cgroup della macchina. È il motivo per far girare i laboratori in CI: "funziona sul mio PC"
non bastava.

## Sicurezza

### Action fissate allo SHA
`uses: azienda/azione@v2` scarica quello a cui punta **oggi** il tag `v2`, e un tag si sposta. A marzo 2026 è
successo davvero: 76 dei 77 tag di `aquasecurity/trivy-action` sono stati spostati su commit che rubavano i segreti
dei runner ([../12-trivy-hadolint/trivy-hadolint.md](../12-trivy-hadolint/trivy-hadolint.md)). Uno SHA non si sposta:
```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```
Lo SHA di un tag (attenzione ai tag annotati, che puntano a un oggetto tag e non al commit):
```bash
gh api repos/actions/checkout/commits/v7.0.1 --jq .sha
```
Dependabot aggiorna da solo SHA e commento con una PR (`.github/dependabot.yml` con `package-ecosystem:
github-actions`). Nelle impostazioni dell'organizzazione si può rendere obbligatorio lo SHA, e limitare le Action
ammesse a quelle di GitHub e di autori verificati.

### Permessi minimi
`permissions:` in cima al workflow (`contents: read`) e permessi in più solo nel job che li usa (`packages: write` nel
job `immagine`, `security-events: write` nel job `hadolint`, `id-token: write` nel job `oidc`). Il default del
repository va messo a *read* (*Settings > Actions > General > Workflow permissions*): un'Action compromessa può fare
solo quello che il token permette.

### Iniezione di comandi
Il testo di `${{ }}` diventa parte dello script. Un workflow sbagliato, provato con act:
```yaml
      - run: |
          echo "messaggio: ${{ inputs.messaggio }}"
```
con l'input `ciao"; echo "INIETTATO: $(id -un) su $(hostname)`:
```
| messaggio: ciao
| INIETTATO: root su docker-desktop
```
Il secondo comando l'ha scritto chi ha compilato l'input. Con `github.event.pull_request.title`,
`github.head_ref` o il testo di un commento basta aprire una PR da un fork. La forma giusta, usata in tutti gli
esempi: il valore in una variabile d'ambiente, e la shell che la espande.
```yaml
      - env:
          MESSAGGIO: ${{ inputs.messaggio }}
        run: echo "messaggio: $MESSAGGIO"
```
Con lo stesso input, l'esempio 02 su GitHub stampa il testo così com'è, `INIETTATO` compreso, senza eseguirlo.

### pull_request_target
Gira con il codice del ramo di destinazione e con segreti e token in scrittura, anche per le PR dei fork: serve per
etichettare o commentare. Se fa il checkout del codice della PR (`ref: ${{ github.event.pull_request.head.sha }}`) e
lo esegue, chiunque apra una PR esegue codice con i segreti del repository. È l'attacco più comune alle Action
pubbliche. Per i test delle PR si usa `pull_request`.

### Runner self-hosted
Mai su repository pubblici: chiunque apra una PR può far girare codice sulla macchina. Per quelli privati: runner
effimeri (un job e via, `--ephemeral`, o Actions Runner Controller su Kubernetes) e una rete che non vede la produzione.

## act: i workflow in locale
[act](https://github.com/nektos/act) legge `.github/workflows/` ed esegue i job in container Docker. Per provare un
workflow senza fare push:
```bash
act -l                                                     # job ed eventi
act workflow_dispatch -W .github/workflows/esempio-02-eventi.yml \
    -P ubuntu-24.04=catthehacker/ubuntu:act-24.04 \
    --input ambiente=produzione --input dettagli=true
act workflow_dispatch -W .github/workflows/esempio-08-ambienti.yml -P ubuntu-24.04=catthehacker/ubuntu:act-24.04 \
    -s TOKEN_DEMO=tok-1234-segreto-abcd --var SERVER_DEMO=203.0.113.10
act workflow_dispatch -W .github/workflows/esempio-03-matrix.yml -P ubuntu-24.04=catthehacker/ubuntu:act-24.04 \
    -s GITHUB_TOKEN="$(gh auth token)" --matrix python:3.14 --matrix os:ubuntu-24.04
```
`-P` sceglie l'immagine al posto del runner (`catthehacker/ubuntu:act-24.04` imita quello di GitHub, ma non è
uguale); `-s GITHUB_TOKEN` serve alle Action che scaricano da GitHub (setup-python), per non finire nei limiti di richieste.
Cosa è emerso provando gli esempi:

| Esempio | Con act |
|---|---|
| 01, 02, 04, 07, 09 | come su GitHub (il runner Arm del 04 va mappato con `-P ubuntu-24.04-arm=...` e resta x86) |
| 03 matrix | i job Windows vengono saltati (`Skipping unsupported platform`); la matrix completa falliva con `image=` vuota e cache di Python condivisa e rovinata fra job paralleli. Una combinazione alla volta con `--matrix` funziona |
| 05 artefatti | la cache sì; l'upload no: `unknown field "mime_type"`, il server degli artefatti di act non conosce ancora il protocollo di `upload-artifact` v7 |
| 06 servizi | il job in container sì; quello sulla macchina no, `psql: command not found`: l'immagine di act ha meno strumenti del runner vero (manca anche `shellcheck`) |
| 08 | segreti e variabili sì (mascherati anche da act); OIDC no: `URL rejected: Bad hostname`, il servizio dei token esiste solo su GitHub |
| kb.yml | i job che montano la cartella del progetto in altri container (`docker run -v "$PWD:..."`) non vedono i file: il percorso del container di act non esiste sul Docker della macchina |

act è utile per sbagliare in fretta (YAML non valido, espressioni, step che falliscono subito); la prova vera resta
il push.

## gh: GitHub da riga di comando

| Comando | Cosa fa |
|---|---|
| `gh workflow list` | i workflow del repository |
| `gh workflow run file.yml -f chiave=valore --ref ramo` | avvia un `workflow_dispatch` |
| `gh run list --workflow file.yml --branch ramo --limit 5` | le esecuzioni, con stato ed esito |
| `gh run watch [id]` | segue un'esecuzione fino alla fine |
| `gh run view id --log` / `--log-failed` | il log completo, o solo dei job falliti |
| `gh run view id --json jobs --jq '.jobs[] \| "\(.name) \(.conclusion)"'` | esito di ogni job, per gli script |
| `gh run rerun id --failed` | rilancia solo i job falliti |
| `gh run download id -n report-test` | scarica un artefatto |
| `gh secret set NOME --body valore` (`--env produzione`) | crea un segreto del repository (o di un ambiente) |
| `gh variable set NOME --body valore` | crea una variabile |
| `gh api repos/{owner}/{repo}/actions/...` | tutto il resto dell'API REST |

## Jenkins, GitLab CI e GitHub Actions a confronto

| | Jenkins | GitLab CI | GitHub Actions |
|---|---|---|---|
| definizione | `Jenkinsfile` (Groovy) | `.gitlab-ci.yml` | `.github/workflows/*.yml`, anche più di uno |
| server | da installare e curare | integrato in GitLab | integrato in GitHub |
| macchine | agenti propri | runner propri o condivisi | runner di GitHub (gratuiti per i pubblici) o self-hosted |
| unità | stage e step | stage e job | workflow, job, step |
| riuso | Shared Library, plugin | `include`, `extends`, componenti | Action (Marketplace), Action composite, workflow riusabili |
| ordine | stage in fila, `parallel` | stage, `needs` | job in parallelo, `needs` |
| matrix | `matrix` | `parallel:matrix` | `strategy.matrix` con `include`/`exclude` |
| segreti | Credentials | variabili masked/protected | segreti di repository, organizzazione, ambiente |
| approvazioni | `input` | `when: manual`, ambienti protetti | ambienti con revisori obbligatori |
| credenziali cloud | plugin, chiavi | OIDC (`id_tokens`) | OIDC (`id-token: write`) |
| registry | esterno | integrato | `ghcr.io` |
| prova in locale | il proprio Jenkins | `gitlab-ci-local` | `act` |

## Buone pratiche
1. `permissions: contents: read` in cima a ogni workflow, il resto solo nei job che servono
2. Action fissate allo SHA con la versione in commento; Dependabot per aggiornarle
3. mai `${{ }}` con dati esterni dentro `run:`: sempre `env:` e la variabile della shell
4. runner con versione (`ubuntu-24.04`), `timeout-minutes` su ogni job, `concurrency` per non sprecare esecuzioni
5. `paths:` per i workflow che riguardano una sola parte del repository
6. segreti negli ambienti, con revisori su produzione; OIDC al posto delle chiavi cloud
7. cache per le dipendenze, artefatti solo per quello che serve dopo, con `retention-days` corti
8. la logica lunga in script nel repository (`.github/scripts/`): si prova in locale e si legge meglio di 50 righe di YAML
9. i workflow sono codice: revisione nelle PR, e il proprietario dei file `.github/` in `CODEOWNERS`

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `mapping values are not allowed in this context` | `run: echo "a: b"`: un valore YAML senza virgolette con `: ` dentro | `run: \|` e il comando nella riga sotto, o tutto fra apici |
| workflow non valido per un commento | `${{ }}` dentro uno script, anche in un commento, viene comunque interpretato | niente graffe nei commenti degli script |
| il workflow non parte | filtri `branches`/`paths` che escludono il push; file fuori da `.github/workflows/`; YAML non valido (errore nella scheda Actions) | controllare i filtri; `act -n` o il linter `actionlint` |
| `Resource not accessible by integration` | il `GITHUB_TOKEN` non ha il permesso | `permissions:` nel job (`packages: write`, `pull-requests: write`...) |
| segreto vuoto nel job | PR da un fork, o segreto di un ambiente non dichiarato nel job, o nome sbagliato | `environment:` nel job; i fork non ricevono segreti |
| `Unable to reserve cache with key ..., another job may be creating this cache` | più job salvano la stessa chiave insieme | innocuo |
| il job resta `Queued` | nessun runner con quell'etichetta (un'etichetta scritta male, un self-hosted spento) | correggere `runs-on` |
| comando trovato in locale ma non sul runner Windows | la shell di default è PowerShell | `shell: bash` |
| `denied: installation not allowed to Create organization package` o `permission_denied` su ghcr.io | manca `packages: write`, o il pacchetto esiste già ed è collegato a un altro repository | `permissions: packages: write`; nelle impostazioni del pacchetto, *Manage Actions access* |
| il nome dell'immagine con maiuscole viene rifiutato da ghcr.io | `github.repository` può avere maiuscole | `docker/metadata-action` (le converte), o `${VAR,,}` in bash |
| container con systemd che esce con 255 sul runner | bind di `/sys/fs/cgroup` dell'host, con systemd anche sull'host | cgroup privato rimontato e `apparmor=unconfined` (vedi sopra) |
| `act`: `unknown field "mime_type"`, `Bad hostname` per OIDC, `command not found` | limiti di act e della sua immagine | provare su GitHub; vedi la tabella di act |
