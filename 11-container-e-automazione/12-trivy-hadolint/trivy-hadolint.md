# Trivy e Hadolint

Due controlli automatici sulle immagini dei container, da mettere nella pipeline prima che un'immagine arrivi nel
registry:

- **Hadolint** legge il `Dockerfile` e segnala gli errori di scrittura: versioni non fissate, cache lasciate
  nell'immagine, `CMD` in forma shell, segreti in `ENV`... Dentro c'è anche ShellCheck, che controlla gli script dei `RUN`
- **Trivy** cerca **vulnerabilità note** (CVE) nei pacchetti del sistema operativo e nelle librerie dell'applicazione,
  **segreti** lasciati nei file e **errori di configurazione** in Dockerfile, manifest Kubernetes, chart Helm e Terraform.
  Genera anche l'**SBOM**, l'elenco di tutto quello che c'è nell'immagine

```
 Dockerfile ──hadolint──> docker build ──trivy image──> docker push ──> registry ──> deploy ──trivy k8s──> cluster
      └───────────── trivy config (Dockerfile, YAML, Terraform) ─────────────┘
```
I due si sovrappongono poco: Hadolint conosce bene il Dockerfile e le sue convenzioni, Trivy sa cosa c'è
*dentro* l'immagine costruita, cioè quello che dal Dockerfile non si vede (l'immagine base, le dipendenze).

Versioni del laboratorio: Trivy 0.75.0, Hadolint 2.15.1 (ottobre 2026). Documentazione:
https://trivy.dev/docs/latest/ · https://github.com/hadolint/hadolint · elenco delle regole di Hadolint:
https://github.com/hadolint/hadolint#rules

> **ATTENZIONE**: a marzo 2026 Trivy ha subito un attacco alla supply chain. Il 19 marzo, con credenziali rubate,
> sono stati pubblicati il binario **v0.69.4** malevolo e 76 dei 77 tag di `aquasecurity/trivy-action` (più tutti quelli
> di `setup-trivy`), spostati su commit con un programma che rubava variabili d'ambiente, chiavi SSH, credenziali cloud
> e token Kubernetes dai runner CI. Il 22 marzo sono comparse anche le immagini Docker Hub **0.69.5** e **0.69.6**
> malevole. Chi le ha usate deve considerare compromessi tutti i segreti visibili a quelle pipeline.
> Le contromisure valgono per qualunque strumento della pipeline: versione fissa **con digest** per le immagini
> (`aquasec/trivy:0.75.0@sha256:...`), **SHA del commit** per le GitHub Actions (non il tag, che si può spostare),
> verifica di checksum e firma per i binari. Resoconto: https://www.aquasec.com/blog/trivy-supply-chain-attack-what-you-need-to-know

## Usarli con Docker
Non serve installare niente: le immagini ufficiali bastano, sul PC e in CI.
```bash
alias hadolint='docker run --rm -i -v "$PWD:/src" -w /src hadolint/hadolint:v2.15.1 hadolint'
alias trivy='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy -v "$PWD:/src" -w /src aquasec/trivy:0.75.0'
```
- `-v /var/run/docker.sock`: Trivy legge le immagini dal demone Docker locale (`trivy image esempio:dopo`). Con il socket
  il container può comandare tutto il demone: va bene sul proprio PC, in CI si usa con attenzione
- `-v trivy-cache:...`: il database delle vulnerabilità (127 MB da scaricare da `mirror.gcr.io/aquasec/trivy-db`, 1,4 GB
  una volta estratto) resta in un volume e si scarica una volta sola; poi Trivy lo aggiorna quando è vecchio
- `-v "$PWD:/src" -w /src`: la cartella corrente, per i file da controllare e i file di configurazione

In Git Bash su Windows: prima `export MSYS_NO_PATHCONV=1`, e negli alias `$(pwd -W)` al posto di `$PWD` (Docker Desktop
vuole i percorsi Windows, `C:/...`).

### Il digest
Un tag come `0.75.0` è un nome che il proprietario del repository può spostare su un'altra immagine; il **digest** è
l'hash del contenuto e non cambia mai. Per un'immagine multi-architettura il digest giusto è quello dell'**indice**
(che poi rimanda all'immagine amd64, arm64...), non quello di una singola architettura:
```bash
docker buildx imagetools inspect aquasec/trivy:0.75.0 | head -3
```
```
Name:      docker.io/aquasec/trivy:0.75.0
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa
```
Su Docker Hub, nella pagina del tag, quello in alto è l'indice; quelli nella tabella delle architetture sono diversi
(per amd64 `sha256:9db09910...`). In CI: `aquasec/trivy:0.75.0@sha256:af6acf9a...`. Docker scarica per digest e ignora il
tag, che resta solo come promemoria per chi legge.

### Installare i binari
```bash
# Hadolint: un binario statico
curl -fsSLo hadolint https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-linux-x86_64
sudo install -m 755 hadolint /usr/local/bin/

# Trivy: archivio, checksum e firma del checksum
V=0.75.0
for f in trivy_${V}_Linux-64bit.tar.gz trivy_${V}_checksums.txt trivy_${V}_checksums.txt.sigstore.json; do
    curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v$V/$f"
done
sha256sum --check --ignore-missing trivy_${V}_checksums.txt      # trivy_0.75.0_Linux-64bit.tar.gz: OK
cosign verify-blob trivy_${V}_checksums.txt --bundle trivy_${V}_checksums.txt.sigstore.json \
    --certificate-identity-regexp '^https://github.com/aquasecurity/trivy/' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com          # Verified OK
tar xzf trivy_${V}_Linux-64bit.tar.gz trivy && sudo install -m 755 trivy /usr/local/bin/
```
Il checksum da solo dice che il file non si è rovinato scaricandolo. La **firma** (Sigstore, con `cosign`) dice che
`checksums.txt` l'ha prodotto la pipeline di rilascio del repository `aquasecurity/trivy` su GitHub Actions, e non
qualcuno che ha caricato file nella pagina della release. Provato nel laboratorio con `ghcr.io/sigstore/cosign/cosign:v3.1.3`.

## L'esempio
La cartella [esempio/](esempio/) ha la stessa app Flask delle pipeline di Jenkins e GitLab, con due Dockerfile:

| File | Contenuto |
|---|---|
| [Dockerfile.prima](esempio/Dockerfile.prima) | "funziona", ma con gli errori più comuni: base vecchia (`python:3.12.0-slim`, dicembre 2023), `apt-get` senza opzioni, un token in `ENV`, `COPY . .`, root, `CMD` in forma shell |
| [requirements-prima.txt](esempio/requirements-prima.txt) | `flask==2.2.2`, `werkzeug==2.2.2`: dipendenze fissate e mai aggiornate |
| [Dockerfile](esempio/Dockerfile) | lo stesso corretto: base attuale, solo i file che servono, utente 1000, `HEALTHCHECK`, senza pip |
| [.hadolint.yaml](esempio/.hadolint.yaml) | configurazione di Hadolint |
| [trivy-ci.yaml](esempio/trivy-ci.yaml), [.trivyignore.yaml](esempio/.trivyignore.yaml) | configurazione ed eccezioni di Trivy |
| [.dockerignore](esempio/.dockerignore), [Dockerfile.prima.dockerignore](esempio/Dockerfile.prima.dockerignore) | cosa resta fuori dal contesto di build (il secondo, vuoto, vale solo per `Dockerfile.prima`) |

```bash
cd esempio
docker build -f Dockerfile.prima -t esempio:prima .
docker build -t esempio:dopo .
```

### 1. Hadolint
```bash
hadolint Dockerfile.prima
```
```
Dockerfile.prima:4 DL3009 info: Delete the apt lists (/var/lib/apt/lists) after installing something
Dockerfile.prima:4 DL3015 info: Avoid additional packages by specifying `--no-install-recommends`
Dockerfile.prima:5 DL3064 warning: Potentially sensitive data should not be used in the `ARG` or `ENV` commands
Dockerfile.prima:8 DL3042 warning: Avoid use of cache directory with pip. Use `pip install --no-cache-dir <package>`
Dockerfile.prima:9 DL3003 warning: Use WORKDIR to switch to a directory
Dockerfile.prima:11 DL3025 warning: Use arguments JSON notation for CMD and ENTRYPOINT arguments
```
Exit code 1. `hadolint Dockerfile` non stampa niente ed esce con 0. Senza `.hadolint.yaml` (per esempio
`hadolint - < Dockerfile.prima` in un'altra cartella) c'è anche
`DL3008 warning: Pin versions in apt get install`, che la configurazione dell'esempio ignora.

Cosa vuol dire ogni riga, e la correzione:

| Regola | Problema | Correzione |
|---|---|---|
| DL3008 | `apt-get install curl` senza versione: ogni build può installare una versione diversa | `curl=<versione>` (spesso troppo rigido: vedi la configurazione) |
| DL3009 | le liste di apt restano nell'immagine (decine di MB) | `&& rm -rf /var/lib/apt/lists/*` nello stesso `RUN` |
| DL3015 | senza `--no-install-recommends` arrivano anche i pacchetti "consigliati" | `apt-get install -y --no-install-recommends curl` |
| DL3064 | un segreto in `ENV` resta nell'immagine, visibile con `docker inspect` e `docker history` | segreti a runtime (variabili, file montati); al build `RUN --mount=type=secret` |
| DL3042 | la cache di pip finisce nel layer | `pip install --no-cache-dir` |
| DL3003 | `RUN cd /app && ...` | `WORKDIR /app` |
| DL3025 | `CMD python app.py` passa da `/bin/sh -c`: il processo non è PID 1 e non riceve SIGTERM, lo stop aspetta 10 secondi e poi lo uccide | `CMD ["python", "app.py"]` |

Altre regole che si incontrano spesso:

| Regola | Livello | Cosa segnala |
|---|---|---|
| DL3006 / DL3007 | warning | `FROM` senza tag, o con `latest` |
| DL3002 | warning | l'ultimo `USER` è root |
| DL3020 | error | `ADD` per file locali: si usa `COPY` (`ADD` scarica URL e scompatta archivi) |
| DL3059 | info | più `RUN` consecutivi: ognuno è un layer |
| DL4006 | warning | `RUN` con una pipe senza `SHELL ["/bin/bash", "-o", "pipefail", "-c"]`: se fallisce il primo comando nessuno se ne accorge |
| DL3026 | error | `FROM` da un registry non fidato (solo con `trustedRegistries`) |
| SC2086, SC2046... | vari | gli avvisi di ShellCheck sugli script dei `RUN` (vedi [../../05-scripting/12-trap-e-debug.md](../../05-scripting/12-trap-e-debug.md)) |

Passato su tutti i Dockerfile di questa KB, Hadolint ha trovato `latest` e `apt-get` senza opzioni nei laboratori di
Ansible, `pipefail` mancante nel Dockerfile dei laboratori e due `CMD` in [../02-dockerfile/python/](../02-dockerfile/python/)
(`DL4003`: vale solo l'ultimo).

### 2. Configurare Hadolint
[.hadolint.yaml](esempio/.hadolint.yaml) nella cartella da cui si lancia (o `~/.config/hadolint.yaml`):
```yaml
failure-threshold: warning           # exit code 1 da warning in su; gli "info" si vedono ma non bloccano
ignored:
  - DL3008                           # versioni fisse in apt-get install: troppo rigido con una base aggiornata spesso
trustedRegistries:                   # FROM solo da questi registry (DL3026)
  - docker.io
  - localhost:5001
override:
  error:
    - DL3002                         # USER root come ultimo utente: errore, non solo warning
```
Con `trustedRegistries` e `override`, su un Dockerfile con `FROM ghcr.io/...` e `USER root`:
```
prova.Dockerfile:1 DL3026 error: Use only an allowed registry in the FROM image
prova.Dockerfile:2 DL3002 error: Last USER should not be root
prova.Dockerfile:2 DL3066 info: Non-numeric user-id may not be resolvable by host system
```
Un'eccezione per una riga sola, con il motivo accanto, nel Dockerfile:
```dockerfile
# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
```
Opzioni da riga di comando:

| Opzione | A cosa serve |
|---|---|
| `-t, --failure-threshold warning` | da quale livello l'exit code è 1 (`error`, `warning`, `info`, `style`, `ignore`, `none`) |
| `--ignore DL3008` | ignora una regola (ripetibile; sostituisce la lista del file di configurazione) |
| `--error DL3002`, `--warning ...` | cambia il livello di una regola |
| `--trusted-registry docker.io` | come `trustedRegistries` |
| `-f, --format json` | `tty` (default), `json`, `checkstyle`, `codeclimate`, `gitlab_codeclimate`, `gnu`, `codacy`, `sonarqube`, `sarif`, `junit` |
| `--no-fail` | stampa ma esce sempre con 0 (per generare un report e decidere dopo) |
| `--disable-ignore-pragma` | ignora i commenti `# hadolint ignore=` |
| `-` | legge il Dockerfile da standard input: `hadolint - < Dockerfile` |

### 3. Trivy sul Dockerfile
`trivy config` controlla i file di configurazione senza costruire niente:
```bash
trivy config .
```
```
│ Dockerfile       │ dockerfile │         0         │
│ Dockerfile.prima │ dockerfile │         5         │

Dockerfile.prima (dockerfile)
Failures: 5 (UNKNOWN: 0, LOW: 1, MEDIUM: 1, HIGH: 2, CRITICAL: 1)
DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument
DS-0013 (MEDIUM): RUN should not be used to change directory: 'cd /app && python -m compileall .'. Use 'WORKDIR' statement instead.
DS-0026 (LOW): Add HEALTHCHECK instruction in your Dockerfile
DS-0029 (HIGH): '--no-install-recommends' flag is missed: 'apt-get update && apt-get install -y curl'
DS-0031 (CRITICAL): Possible exposure of secret env "API_TOKEN" in ENV
```
Cosa trova ciascuno sul `Dockerfile.prima`:

| Problema | Hadolint | Trivy |
|---|---|---|
| nessun `USER`: gira come root | | DS-0002 |
| nessun `HEALTHCHECK` | | DS-0026 |
| segreto in `ENV` | DL3064 (warning) | DS-0031 (CRITICAL) |
| `RUN cd` | DL3003 | DS-0013 |
| `--no-install-recommends` | DL3015 | DS-0029 |
| liste di apt, cache di pip, `CMD` in forma shell, versioni apt | DL3009, DL3042, DL3025, DL3008 | |

Hadolint conosce meglio lo stile, Trivy guarda di più la sicurezza: conviene usarli tutti e due.

### 4. Trivy sull'immagine
```bash
trivy image esempio:prima
```
Il riepilogo all'inizio dice dove ha guardato:
```
│                                    Target                                    │    Type    │ Vulnerabilities │ Secrets │
│ esempio:prima (debian 12.2)                                                  │   debian   │       614       │    -    │
│ usr/local/lib/python3.12/site-packages/Flask-2.2.2.dist-info/METADATA        │ python-pkg │        2        │    -    │
│ usr/local/lib/python3.12/site-packages/Werkzeug-2.2.2.dist-info/METADATA     │ python-pkg │        9        │    -    │
│ usr/local/lib/python3.12/site-packages/pip-23.2.1.dist-info/METADATA         │ python-pkg │        7        │    -    │
│ usr/local/lib/python3.12/site-packages/setuptools-69.0.2.dist-info/METADATA  │ python-pkg │        3        │    -    │
│ usr/local/lib/python3.12/site-packages/wheel-0.42.0.dist-info/METADATA       │ python-pkg │        1        │    -    │
│ /app/.env                                                                    │    text    │        -        │    1    │
```
Poi una tabella per ogni gruppo: pacchetto, CVE, gravità, **stato**, versione installata, **versione corretta**.
Le colonne che contano per decidere:
- **Severity**: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`, dal punteggio CVSS e dalla valutazione della distribuzione
- **Status** `fixed` con una **Fixed Version**: esiste una versione corretta, basta aggiornare. `affected`,
  `will_not_fix`, `fix_deferred`: la correzione non c'è (o la distribuzione ha deciso di non farla)

Il confronto fra i due Dockerfile:

| | `esempio:prima` | `esempio:dopo` |
|---|---|---|
| base | Debian 12.2 (`python:3.12.0-slim`, 2023) | Debian 13.7 (`python:3.13-slim`, ottobre 2026) |
| vulnerabilità del sistema | 614, di cui 15 CRITICAL (10 correggibili) | 167, nessuna CRITICAL; 1 sola correggibile (HIGH) |
| librerie Python | 22: Flask e Werkzeug vecchi, pip, setuptools, wheel | nessuna |
| segreti | `/app/.env` | nessuno |

Quasi tutto il miglioramento viene dall'immagine base aggiornata. Le vulnerabilità `affected` restano anche nella
base nuova: sono quelle senza una correzione, e con `--ignore-unfixed` non si vedono.

**Le librerie di pip.** Senza `pip uninstall -y pip` l'immagine `dopo` avrebbe 6 vulnerabilità Python (HIGH su
`urllib3`, `msgpack`, `setuptools`), anche se l'app non le installa e non le usa: sono le copie che pip si porta dentro
(`site-packages/pip/_vendor/`). Le trova Trivy, e le troverebbe un attaccante. Pip serve per costruire l'immagine, non
per farla girare: lo si toglie alla fine, o si installano le dipendenze in uno stadio di build e si copia solo il risultato.

Opzioni che si usano sempre:

| Opzione | A cosa serve |
|---|---|
| `--severity HIGH,CRITICAL` | solo queste gravità |
| `--ignore-unfixed` | solo le vulnerabilità con una versione corretta disponibile |
| `--exit-code 1` | exit code 1 se resta qualcosa dopo i filtri (il default è 0, anche con mille CVE) |
| `--scanners vuln,secret,misconfig,license` | cosa cercare (per le immagini il default è `vuln,secret`) |
| `--image-config-scanners misconfig,secret` | controlla anche la configurazione dell'immagine (la storia dei layer, `ENV`) |
| `--pkg-types os` / `library` | solo i pacchetti del sistema o solo le librerie |
| `--format table` / `json` / `sarif` / `cyclonedx` / `spdx-json` / `template` | formato; con `template`, `--template @/contrib/junit.tpl` (o `gitlab.tpl`, `html.tpl`) |
| `--output file` | scrive su file invece che sullo standard output |
| `--quiet` | niente righe di log, solo il risultato |
| `--input immagine.tar` | un'immagine salvata con `docker save`, senza demone |
| `--image-src remote` | dal registry, senza scaricarla prima |
| `--platform linux/arm64` | un'architettura precisa di un'immagine multi-architettura |
| `--exit-on-eol 3` | exit code dedicato se il sistema operativo dell'immagine non è più supportato |
| `--skip-db-update`, `--db-repository` | niente aggiornamento del database, o un mirror interno |

`--exit-on-eol` provato su `debian:10`: `ERROR Detected EOL OS family="debian" version="10.13"`, exit code 3.

### 5. Il blocco
La regola più comune in CI: **nessun CRITICAL con una correzione disponibile**. Le HIGH si mostrano senza bloccare;
quelle senza correzione non si possono sistemare e bloccarle vorrebbe dire non rilasciare mai.
```bash
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 esempio:dopo    # exit=0
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 esempio:prima   # exit=1
```
```
esempio:prima (debian 12.2)
Total: 10 (CRITICAL: 10)
```
Fra i 10: `libssl3` e `openssl` (CVE-2026-31789), `libgssapi-krb5-2` e le altre librerie di Kerberos (CVE-2024-37371),
tutte corrette da tempo nelle versioni successive di Debian 12.

### 6. Segreti
Trivy cerca token, chiavi private e password con regole per i formati noti (GitHub, GitLab, AWS, Google, Slack,
Stripe, chiavi PEM...). Un file `.env` di prova, con un token finto generato al momento:
```bash
printf 'GITHUB_TOKEN=ghp_%s\nDB_PASSWORD=laboratorio\n' "$(head -c 60 /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c 36)" > .env
trivy fs --scanners secret .
```
```
.env (secrets)
==============
Total: 1 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 1)

CRITICAL: GitHub (github-pat)
════════════════════════════════════════
GitHub Personal Access Token
────────────────────────────────────────
 .env:1 (offset: 13 bytes)
────────────────────────────────────────
   1 [ GITHUB_TOKEN=****************************************
   2   DB_PASSWORD=laboratorio
```
Il token ha una forma riconoscibile e viene trovato; `DB_PASSWORD=laboratorio` no: una password qualunque non si
distingue da un testo qualunque. Il valore trovato nel report viene mascherato.

Il problema vero è quando il file finisce nell'immagine. `Dockerfile.prima` fa `COPY . .` e il suo ignore file è
vuoto ([Dockerfile.prima.dockerignore](esempio/Dockerfile.prima.dockerignore): con BuildKit, `<Dockerfile>.dockerignore`
vale al posto di `.dockerignore` per quel Dockerfile), quindi dopo una nuova build:
```bash
docker build -f Dockerfile.prima -t esempio:prima .
docker run --rm --entrypoint ls esempio:prima -a /app   # .env, .gitignore, Dockerfile, i file di configurazione...
trivy image --scanners secret esempio:prima             # /app/.env (secrets) CRITICAL: GitHub (github-pat)
```
In `esempio:dopo` ci sono solo `app.py` e `requirements.txt`: il Dockerfile copia solo quelli, e
[.dockerignore](esempio/.dockerignore) tiene fuori `.env` anche da un eventuale `COPY . .`.
Un segreto finito in un'immagine pubblicata si considera esposto: si revoca, non basta ricostruire l'immagine.

### 7. Eccezioni e configurazione
Una vulnerabilità che non si può correggere subito si accetta in modo esplicito, con il motivo e una scadenza, in
[.trivyignore.yaml](esempio/.trivyignore.yaml):
```yaml
vulnerabilities:
  - id: CVE-2026-103111
    purls:
      - "pkg:deb/debian/libpcre2-8-0@10.46-1~deb13u2?arch=amd64&distro=debian-13.7"
    statement: >-
      Corretta in Debian (10.46-1~deb13u3) ma non ancora nell'immagine python:3.13-slim.
      Nessuna regex dell'utente arriva a PCRE2 nell'app. Si toglie al prossimo aggiornamento dell'immagine base.
    expired_at: 2026-10-17
```
Il `purl` (*package URL*) limita l'eccezione a quel pacchetto e a quella versione: si legge nel report JSON con
`--list-all-pkgs` (`Identifier.PURL`). Il vecchio formato `.trivyignore`, una riga per CVE, funziona ancora ma non ha
motivo né scadenza.

Le opzioni della CI in un file, [trivy-ci.yaml](esempio/trivy-ci.yaml):
```yaml
severity: [HIGH, CRITICAL]
exit-code: 1
ignorefile: .trivyignore.yaml
vulnerability:
  ignore-unfixed: true
scan:
  scanners: [vuln, secret]
```
```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 esempio:dopo   # exit=1: libpcre2-8-0 CVE-2026-103111
trivy image --config trivy-ci.yaml esempio:dopo                                    # exit=0: l'eccezione vale
```
Con `expired_at: 2026-10-01`, cioè un'eccezione scaduta, la stessa riga torna a dare exit code 1.

> **ATTENZIONE**: un file che si chiama `trivy.yaml` nella cartella corrente Trivy lo legge **da solo**, senza
> `--config`. Con un `trivy.yaml` nella cartella dell'esempio, `trivy image` (anche quello "senza eccezioni") usava già
> severità, exit code ed eccezioni del file, e `trivy config` mostrava 3 problemi invece di 5. Per questo qui si chiama
> `trivy-ci.yaml` e si passa in modo esplicito.

### 8. SBOM
L'SBOM (*Software Bill of Materials*) è l'elenco dei componenti di un'immagine, in un formato standard (CycloneDX o
SPDX). Si genera al build, si conserva con l'immagine, e si riscansiona quando escono CVE nuove senza avere l'immagine:
```bash
trivy image --format cyclonedx --output sbom.cdx.json esempio:dopo   # 95 componenti, circa 200 KB
trivy sbom --severity HIGH,CRITICAL sbom.cdx.json                    # Total: 45 (HIGH: 45, CRITICAL: 0)
```
Lo stesso SBOM può essere allegato all'immagine nel registry (`docker buildx build --sbom=true`, o `cosign attest`) e
letto da altri strumenti (Grype, Dependency-Track).

### 9. Manifest Kubernetes e Terraform
`trivy config` conosce anche Kubernetes (KSV-...), Helm, Terraform (AWS-..., AZU-..., GCP-...), CloudFormation e
Docker Compose. Passato sui laboratori di questa KB:
```bash
cd ../..                        # 11-container-e-automazione
trivy config 06-kubernetes
trivy config 09-terraform
```
| File | HIGH | MEDIUM | LOW |
|---|---|---|---|
| `06-kubernetes/01-deployment/deployment.yaml` | 3 | 4 | 11 |
| `06-kubernetes/06-ingress-gateway/app.yaml` | 6 | 10 | 22 |
| `06-kubernetes/04-app-propria/deployment.yaml` | 1 | 1 | 4 |
| `09-terraform/05-aws-ec2/main.tf` | 3 (+1 CRITICAL) | | |

I laboratori servono a imparare un concetto alla volta e non mettono le protezioni da produzione, quindi è normale.
Le regole più frequenti sono anche il riassunto di come si protegge un Pod:

| Regola | Cosa chiede |
|---|---|
| KSV-0118 (HIGH) | un `securityContext` (a livello di Pod), non quello di default che permette root |
| KSV-0014 (HIGH) | `readOnlyRootFilesystem: true` |
| KSV-0012 (MEDIUM) | `runAsNonRoot: true` |
| KSV-0001 (MEDIUM) | `allowPrivilegeEscalation: false` |
| KSV-0003 / KSV-0004 (LOW) | `capabilities: drop: ["ALL"]` |
| KSV-0011 / KSV-0018 (LOW) | `limits` di CPU e memoria |
| KSV-0030, KSV-0104 | `seccompProfile: type: RuntimeDefault` |
| KSV-0020 / KSV-0021 (LOW) | utente e gruppo con UID/GID sopra 10000 (non collidono con quelli del nodo) |
| KSV-0110 (LOW) | un namespace diverso da `default` |

`04-app-propria` ha già quasi tutto a livello di container. Aggiungendo il blocco a livello di Pod e un namespace,
Trivy non trova più niente (provato su una copia):
```yaml
metadata:
  name: mia-app
  namespace: produzione
spec:
  template:
    spec:
      securityContext:                   # a livello di Pod: vale per tutti i container
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
```
Per Terraform le quattro segnalazioni su `05-aws-ec2` sono SSH aperto a `0.0.0.0/0` (il default di
`ssh_allowed_cidr`; la regola HTTP sulla porta 80 invece non viene segnalata), uscita verso qualunque indirizzo,
disco non cifrato e IMDSv1 (AWS-0028: `metadata_options { http_tokens = "required" }`).
Un controllo si spegne per una risorsa sola con un commento sopra di lei, e il motivo accanto:
```hcl
#trivy:ignore:AWS-0104 uscita libera: la macchina scarica i pacchetti con apt
resource "aws_vpc_security_group_egress_rule" "tutto" {
```
Provato su una copia: da 4 segnalazioni a 3, sparisce la CRITICAL AWS-0104.

### 10. Il cluster
`trivy k8s` scansiona quello che gira davvero: le immagini dei Pod e la configurazione dei workload. Provato su un
cluster kind con il Deployment di [../06-kubernetes/01-deployment/](../06-kubernetes/01-deployment/):
```bash
trivy k8s --include-namespaces default --report summary --scanners vuln,misconfig
```
```
Workload Assessment
┌───────────┬────────────────┬──────────────────────┬────────────────────┐
│ Namespace │    Resource    │   Vulnerabilities    │ Misconfigurations  │
│           │                ├───┬────┬────┬────┬───┼───┬───┬───┬────┬───┤
│           │                │ C │ H  │ M  │ L  │ U │ C │ H │ M │ L  │ U │
├───────────┼────────────────┼───┼────┼────┼────┼───┼───┼───┼───┼────┼───┤
│ default   │ Deployment/web │ 2 │ 26 │ 32 │ 23 │   │   │ 3 │ 4 │ 11 │   │
└───────────┴────────────────┴───┴────┴────┴────┴───┴───┴───┴───┴────┴───┘
```
`nginx:1.26-alpine` (il laboratorio la usa apposta, per poi aggiornarla alla 1.27) ha 2 CRITICAL; le
configurazioni sono le stesse di `trivy config`. Trivy usa il kubeconfig come `kubectl` (`KUBECONFIG`, `--context`).
Dal container, con kind, serve il kubeconfig "interno" (`kind get kubeconfig --internal`) e `--network kind`.
Per un controllo continuo c'è il **Trivy Operator**: gira nel cluster e scrive i risultati come risorse
(`VulnerabilityReport`, `ConfigAuditReport`), che Prometheus può leggere e su cui si può mettere un alert.

## Nelle pipeline

Le pipeline `07-ci-app` di [Jenkins](../07-jenkins/pipeline/07-ci-app.jenkinsfile) e di
[GitLab](../10-gitlab-ci/pipeline/07-ci-app.gitlab-ci.yml) hanno tutte e due Hadolint prima del build e Trivy dopo il
build, **prima** del push. Con la stessa regola: un CRITICAL correggibile ferma la pipeline, le HIGH correggibili
finiscono nel report dei test. In entrambi i laboratori i job girano in un Docker in Docker: Trivy è un container
lanciato in quel demone, che legge l'immagine appena costruita dal suo socket e tiene il database in un volume.

### Jenkins
```groovy
environment {
    TRIVY = 'aquasec/trivy:0.75.0@sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa'
}
stages {
    stage('Lint Dockerfile') {
        agent {
            docker {
                image 'hadolint/hadolint:v2.15.1-debian'   // la variante con la shell
                reuseNode true
            }
        }
        steps { sh 'hadolint --format junit --failure-threshold warning app/Dockerfile > hadolint.xml' }
        post { always { junit testResults: 'hadolint.xml', allowEmptyResults: true } }
    }
    // ... stage('Immagine') ...
    stage('Scansione immagine') {
        steps {
            sh '''
                TRIVY_RUN="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy $TRIVY"
                $TRIVY_RUN image --quiet --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed \\
                    --format template --template @/contrib/junit.tpl "$IMMAGINE" > trivy.xml
                $TRIVY_RUN image --quiet --scanners vuln,secret --severity CRITICAL --ignore-unfixed \\
                    --exit-code 1 "$IMMAGINE"
            '''
        }
        post { always { junit testResults: 'trivy.xml', allowEmptyResults: true } }
    }
}
```
- `allowEmptyResults`: con un Dockerfile pulito il report di Hadolint non ha test, e senza l'opzione lo step `junit`
  fallirebbe
- il report di Trivy come JUnit: ogni vulnerabilità è un test fallito, e il build diventa **UNSTABLE** (giallo):
  "c'è qualcosa da guardare" senza fermare niente. Il CRITICAL invece fa uscire `sh` con 1: **FAILURE** (rosso)

Risultati nel laboratorio ([../07-jenkins/](../07-jenkins/)):

| Build | Cosa cambia | Esito | Dettaglio |
|---|---|---|---|
| 1 | niente | UNSTABLE | 3 test pytest ok; 5 HIGH correggibili: `libpcre2-8-0` e quattro librerie del pip incluso nell'immagine. Scansione 24,9 s (primo download del database) |
| 2 | `FROM python:3.12.0-slim` | FAILURE | `Total: 10 (CRITICAL: 10)`, `ERROR: script returned exit code 1`; smoke test non eseguito; 84 HIGH e CRITICAL nel report |
| 3 | `CMD python app.py` | FAILURE | si ferma a *Lint Dockerfile*: nel report `DL3025 Use arguments JSON notation for CMD and ENTRYPOINT arguments` |
| 4 | di nuovo come la 1 | UNSTABLE | scansione 1,4 s: database già nel volume |

### GitLab CI
```yaml
variables:
  TRIVY: aquasec/trivy:0.75.0@sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa

lint-dockerfile:
  stage: test
  image: hadolint/hadolint:v2.15.1-debian
  script:
    - hadolint --format gitlab_codeclimate --no-fail app/Dockerfile > hadolint.json   # report per le MR
    - hadolint --failure-threshold warning app/Dockerfile                             # controllo, leggibile nel log
  artifacts:
    when: always
    reports:
      codequality: hadolint.json

immagine:
  stage: build
  image: docker:29-cli
  script:
    - docker build --pull --provenance=false -t "$IMMAGINE" app
    - TRIVY_RUN="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy $TRIVY"
    - $TRIVY_RUN image --quiet --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed
        --format template --template @/contrib/junit.tpl "$IMMAGINE" > trivy.xml
    - $TRIVY_RUN image --quiet --scanners vuln,secret --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMMAGINE"
    - docker push "$IMMAGINE"                    # solo se la scansione è passata
  artifacts:
    when: always
    reports:
      junit: trivy.xml
```
Risultati nel laboratorio ([../10-gitlab-ci/](../10-gitlab-ci/), `./configura.sh 07`):
- pipeline verde: `lint-dockerfile` 12,5 s, `test` 20,2 s, `immagine` 37,6 s, `smoke-test` 7,0 s. Nella scheda
  *Tests*: 8 test, 3 ok (pytest) e 5 falliti nella suite `immagine`, le stesse HIGH di Jenkins
- con `FROM python:3.12.0-slim` in un commit: `immagine` fallisce (`Total: 10 (CRITICAL: 10)`, `ERROR: Job failed:
  exit code 1`), `smoke-test` viene saltato, e nel Container Registry restano solo il tag del commit precedente e
  `latest`: l'immagine vulnerabile non è mai stata pubblicata

GitLab ha anche un job pronto, `include: - template: Jobs/Container-Scanning.gitlab-ci.yml`, che usa Trivy e produce
il report `container_scanning`. La sua visualizzazione nelle MR e nella dashboard di sicurezza è delle versioni a
pagamento; i report `junit` e `codequality` usati qui funzionano anche con GitLab CE.

### GitHub Actions
La forma sicura dopo marzo 2026: Action fissata allo **SHA del commit**, con la versione come commento (questo
blocco non è stato eseguito).
```yaml
- name: Trivy
  uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25   # v0.36.0 (release immutabile)
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    severity: CRITICAL
    ignore-unfixed: true
    exit-code: "1"
```
Oppure, senza Action di terzi, l'immagine con il digest in uno step `run:`, come nelle pipeline di Jenkins e GitLab:
è quello che fa l'esempio 07 di [../13-github-actions/](../13-github-actions/github-actions.md#una-ci-completa), provato
su GitHub (0 CRITICAL, report delle HIGH nel riepilogo dell'esecuzione).
Con `--format sarif --output trivy.sarif` e l'Action `github/codeql-action/upload-sarif` i risultati compaiono nella
scheda *Security* del repository.

## Buone pratiche
1. **immagine base piccola e aggiornata**: è da lì che arriva quasi tutto (614 vulnerabilità contro 167 nell'esempio).
   Ricostruire le immagini anche senza modifiche al codice, ogni settimana: la base cambia, le CVE escono tutti i giorni
2. strumenti della pipeline (Trivy compreso) con versione e **digest**, Action con lo **SHA**
3. Hadolint nell'editor e prima del build (veloce, non serve Docker); Trivy dopo il build e **prima del push**
4. blocco su CRITICAL correggibili, report su HIGH; nessun blocco su quello che non ha una correzione
5. eccezioni scritte in `.trivyignore.yaml`, con motivo e `expired_at`, riviste in merge request come il codice
6. niente strumenti di build nell'immagine finale (pip, compilatori, `curl`): multi-stage, o toglierli
7. segreti mai nel Dockerfile né nel contesto di build: `.dockerignore`, `RUN --mount=type=secret`, variabili a runtime
8. SBOM generato e conservato per ogni immagine rilasciata; scansioni periodiche delle immagini già in produzione
   (Trivy Operator, o il registry: Harbor e GitLab le fanno da soli)
9. cache del database in CI (volume, `cache:` di GitLab) o un mirror interno: senza, ogni job scarica 127 MB e alla
   lunga arriva il limite di richieste

## Altri strumenti che si incontrano

| Strumento | Cosa è |
|---|---|
| Grype + Syft (Anchore) | Syft genera l'SBOM, Grype cerca le vulnerabilità: l'alternativa open source più diffusa a Trivy |
| Docker Scout | integrato in Docker Desktop e Docker Hub (`docker scout cves immagine`) |
| Snyk | servizio commerciale: container, dipendenze, codice, IaC |
| Clair | scanner usato da Quay; Harbor oggi usa Trivy |
| Checkov, KICS | controlli di configurazione per Terraform, Kubernetes, Dockerfile (come `trivy config`) |
| kube-linter, Kubescape | controlli specifici per manifest e cluster Kubernetes |
| Dependency-Track | raccoglie gli SBOM di tutte le applicazioni e avvisa quando esce una CVE che le riguarda |

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `trivy image` esce con 0 anche con centinaia di CVE | il default di `--exit-code` è 0 | `--exit-code 1` con i filtri voluti |
| la pipeline non passa mai per CVE senza correzione | manca `--ignore-unfixed` | `--ignore-unfixed`, o bloccare solo le `CRITICAL` |
| risultati diversi dal previsto, filtri che "si applicano da soli" | un `trivy.yaml` nella cartella corrente viene letto in automatico | rinominarlo e passarlo con `--config` |
| CVE in librerie che l'app non installa (`urllib3`, `msgpack` in un'app Flask) | sono le copie dentro `pip/_vendor` | `pip uninstall -y pip` nell'immagine finale, o multi-stage |
| ogni job di CI scarica il database (127 MB) | cache non conservata fra i job | volume (`trivy-cache`), `cache:` di GitLab, `--cache-dir`, o un mirror con `--db-repository` |
| `TOOMANYREQUESTS` scaricando il database | limiti del registry | cache, mirror interno, `--skip-db-update` con un database aggiornato da un job separato |
| lo step `junit` di Jenkins fallisce con un Dockerfile pulito | il report di Hadolint non ha test | `allowEmptyResults: true` |
| il container Jenkins con l'immagine di Hadolint non parte o non trova `sh` | l'immagine base di Hadolint non ha la shell | `hadolint/hadolint:v2.15.1-debian` (o `-alpine`) |
| Hadolint non vede `.hadolint.yaml` | lanciato da un'altra cartella, o con il Dockerfile da stdin in un container senza la cartella montata | lanciarlo dalla cartella del progetto, o `--config percorso` |
| il digest copiato da Docker Hub non corrisponde a quello di `docker inspect` | è il digest di una sola architettura | `docker buildx imagetools inspect`: il digest dell'indice |
| un segreto trovato in un'immagine già pubblicata | era nel contesto di build o in `ENV` | revocarlo subito, poi correggere `.dockerignore` e il Dockerfile e ripubblicare |
| `Detected EOL OS` e exit code inatteso | `--exit-on-eol` con una base non più supportata | cambiare immagine base: non riceverà più correzioni |
