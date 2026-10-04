# Terraform

Infrastructure as Code: descrivo in file `.tf` le risorse che voglio (server, reti, DNS, container, oggetti Kubernetes)
e Terraform le crea, le modifica o le distrugge per far coincidere la realtà con i file.
I file si versionano con git come il codice, si rivedono in una pull request e si applicano sempre allo stesso modo.

- **provider**: il plugin che sa parlare con un servizio (AWS, Docker, Kubernetes, Cloudflare, GitHub...). Si scarica dal
  [registry](https://registry.terraform.io/) con `terraform init`
- **risorsa** (`resource`): una cosa da creare e gestire: un'istanza, un container, un record DNS
- **data source** (`data`): una cosa che esiste già e che leggo soltanto (l'immagine Ubuntu più recente, una rete esistente)
- **stato**: il file in cui Terraform ricorda cosa ha creato, per sapere cosa cambiare la volta dopo
- **piano**: l'elenco delle modifiche necessarie, calcolato confrontando file, stato e realtà. Si legge prima di applicarlo

Terraform e [Ansible](../08-ansible/ansible.md) si usano spesso insieme: Terraform **crea** l'infrastruttura (dichiarativo:
descrivo il risultato), Ansible **configura** le macchine (una sequenza di task). Terraform 1.6+ è sotto licenza BUSL;
**OpenTofu** (`tofu`) è il fork open source della Linux Foundation, con gli stessi file e comandi quasi identici.

Documentazione: https://developer.hashicorp.com/terraform/docs · linguaggio: https://developer.hashicorp.com/terraform/language ·
provider e moduli: https://registry.terraform.io/

## Installazione
```bash
winget install Hashicorp.Terraform                   # Windows
sudo snap install terraform --classic                # Ubuntu (oppure il repository apt di HashiCorp)
brew install hashicorp/tap/terraform                 # macOS
terraform -version
terraform -install-autocomplete                      # completamento con TAB in bash/zsh
```
Senza installarlo, con Docker: l'immagine ufficiale ha `terraform` come entrypoint, quindi si passa direttamente il sottocomando.
```bash
docker run --rm -it -v "$(pwd):/workspace" -w /workspace hashicorp/terraform:latest init  # monta la cartella corrente
docker run --rm -it -v "$(pwd):/workspace" -w /workspace hashicorp/terraform:latest plan
```
In PowerShell `"${PWD}:/workspace"`. Per gestire Docker dall'interno del container (esempi `01`-`04`) serve
anche montare il socket: `-v /var/run/docker.sock:/var/run/docker.sock`.

## Il ciclo di lavoro
Tutti i comandi si lanciano nella cartella che contiene i file `.tf`: Terraform li legge tutti insieme,
il nome dei file non conta.
```bash
terraform init                    # scarica provider e moduli (in .terraform/) e crea .terraform.lock.hcl. Da rifare se cambiano
terraform init -upgrade           # aggiorna i provider all'ultima versione ammessa dai vincoli
terraform fmt                     # formatta i file .tf (-recursive per le sottocartelle, -check nelle pipeline)
terraform validate                # controlla sintassi e riferimenti, senza contattare il cloud
terraform plan                    # mostra cosa FAREBBE: + crea, ~ modifica, - distrugge, -/+ ricrea. Non tocca nulla
terraform plan -out=piano.tfplan  # salva il piano...
terraform apply piano.tfplan      # ...e applica esattamente quello, senza ridomandare
terraform apply                   # piano + conferma interattiva (bisogna scrivere "yes") + esecuzione
terraform apply -auto-approve     # senza conferma: solo in automazione, dopo aver controllato il piano
terraform apply -var "instance_name=MiaIstanza"      # sovrascrive una variabile solo per questa esecuzione
terraform apply -var-file=produzione.tfvars          # un file di variabili diverso da terraform.tfvars
terraform apply -replace=docker_container.web        # ricrea una risorsa anche se non è cambiata (era "taint")
terraform apply -target=module.blog                  # solo una risorsa o un modulo: per emergenze, non per abitudine
terraform plan -destroy           # cosa distruggerebbe destroy
terraform destroy                 # distrugge TUTTE le risorse gestite da questa configurazione (chiede conferma)
terraform console                 # prova espressioni e funzioni con i valori veri: echo 'keys(var.web)' | terraform console
terraform graph -format=mermaid   # il grafo delle dipendenze in Mermaid (1.16+; senza -format: DOT per Graphviz)
terraform providers               # quali provider servono e a chi
```
I simboli del piano:

| Simbolo | Significato | Esempio |
|---|---|---|
| `+` | crea | una risorsa nuova nel file |
| `~` | modifica sul posto | un'etichetta cambiata |
| `-` | distrugge | una risorsa tolta dal file |
| `-/+` | distrugge e ricrea (`# forces replacement` accanto all'attributo responsabile) | una porta cambiata su un container |

## I file di una configurazione
Convenzione (Terraform legge comunque tutti i `.tf` della cartella):

| File | Contenuto | In git |
|---|---|---|
| `main.tf` | blocco `terraform` con i provider richiesti, `provider`, `resource`, `data` | sì |
| `variables.tf` | le variabili, con tipo, descrizione e default | sì |
| `outputs.tf` | i valori da restituire dopo l'apply | sì |
| `terraform.tfvars` | i valori delle variabili per questo ambiente: letto in automatico | dipende (no se contiene segreti) |
| `.terraform.lock.hcl` | versioni e hash esatti dei provider scaricati | **sì**: tutti usano gli stessi provider |
| `.terraform/` | provider e moduli scaricati (anche centinaia di MB) | no |
| `terraform.tfstate` | lo stato | **no**: contiene segreti in chiaro |

I blocchi principali:
```hcl
terraform {
  required_version = ">= 1.6"                  # versione minima di Terraform
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"           # dove si trova nel registry
      version = "~> 4.0"                       # ~> 4.0 = qualunque 4.x, mai la 5
    }
  }
}

provider "aws" { region = var.region }         # con quale servizio parlare e come autenticarsi

resource "aws_instance" "app_server" {         # tipo di risorsa e nome locale: insieme sono l'indirizzo aws_instance.app_server
  ami           = data.aws_ami.ubuntu.id       # riferimento a un data source
  instance_type = var.instance_type            # riferimento a una variabile
}

data "aws_ami" "ubuntu" { ... }                # una cosa che esiste già e che leggo soltanto
variable "region" { default = "eu-central-1" } # un parametro
locals { nome = "web-${var.region}" }          # un valore calcolato, usato come local.nome
output "ip" { value = aws_instance.app_server.public_ip } # un valore restituito
module "sito" { source = "./modules/sito" }    # un gruppo di risorse riusabile
```
Vincoli di versione: `= 1.2.0` esatta, `>= 1.2` almeno, `~> 1.2` qualunque 1.x dalla 1.2, `~> 1.2.0` qualunque 1.2.x.

## Il linguaggio (HCL)
### Tipi
| Tipo | Esempio |
|---|---|
| `string`, `number`, `bool` | `"web"`, `8080`, `true` |
| `list(string)` | `["web1", "web2"]`: ordinata, si accede con `[0]` |
| `set(string)` | come una lista, ma senza ordine né duplicati |
| `map(string)` | `{ web1 = "Primo", web2 = "Secondo" }`: chiavi stringa, valori dello stesso tipo |
| `object({...})` | `{ porta = 8092, colore = "#fff" }`: campi con nome e tipo propri |
| `tuple([...])` | una lista con un tipo per posizione |

```hcl
variable "ambienti" {
  type = map(object({
    porta  = number
    colore = optional(string, "#2f855a")       # campo facoltativo, con default
  }))
}
```

### Variabili
```hcl
variable "porta" {
  description = "Porta del PC su cui risponde il bilanciatore"
  type        = number                         # senza tipo, un -var arriva come stringa
  default     = 8090                           # senza default la variabile è obbligatoria: Terraform la chiede
  sensitive   = false                          # true: il valore non compare nel piano né nei log
  nullable    = false

  validation {                                 # controllata prima del piano, con un messaggio chiaro
    condition     = var.porta >= 1024 && var.porta <= 65535
    error_message = "Usare una porta fra 1024 e 65535."
  }
}
```
Da dove arrivano i valori, dal più debole al più forte: `default` in `variables.tf` < variabili d'ambiente
`TF_VAR_nome` < `terraform.tfvars` < file `*.auto.tfvars` < `-var` e `-var-file` sulla riga di comando
(fra questi due vince l'ultimo scritto).
```bash
export TF_VAR_porta=9000                             # utile in CI e per i segreti, che così non finiscono nei file
terraform plan -var 'web={web1="a",web2="b"}'        # mappe e liste si scrivono in sintassi HCL, tra apici
```

### Espressioni
```hcl
"web-${var.nome}"                                    # interpolazione
local.ambiente == "prod" ? 3 : 1                     # condizionale
[for s in var.server : upper(s)]                     # for: da lista a lista        -> ["WEB1", "WEB2"]
[for s in var.server : s if s != "web2"]             # con filtro
{ for k, v in var.porte : v => k }                   # da mappa a mappa, invertita   -> { "80" = "http" }
{ for nome, c in docker_container.web : nome => c.network_data[0].ip_address }  # dagli attributi delle risorse
aws_instance.web[*].public_ip                        # splat: lo stesso attributo di tutte le istanze (con count)
<<-EOF                                               # heredoc: testo su più righe, ${...} compresi
  #!/bin/bash
  echo "${var.nome}"
EOF
```
Funzioni utili (si provano in `terraform console`):

| Funzione | Esempio | Risultato |
|---|---|---|
| `format` | `format("%s-%03d", "web", 7)` | `"web-007"` |
| `join` / `split` | `join(", ", ["a", "b"])` | `"a, b"` |
| `length` | `length(var.server)` | `3` |
| `keys` / `values` | `keys({ http = 80, https = 443 })` | `["http", "https"]` |
| `lookup` | `lookup(var.porte, "ftp", 21)` | `21` (il default se la chiave manca) |
| `merge` / `concat` | `merge(var.porte, { ssh = 22 })` | mappa con tre chiavi |
| `contains` | `contains(var.server, "web2")` | `true` |
| `try` / `can` | `try(var.porte.ftp, 21)`, `can(regex("^[a-z]+$", x))` | un default se l'espressione fallisce; `true`/`false` |
| `coalesce` | `coalesce("", "default")` | `"default"`: il primo non vuoto |
| `cidrsubnet` | `cidrsubnet("10.0.0.0/16", 8, 2)` | `"10.0.2.0/24"`: sottoreti senza calcoli a mano |
| `file` / `templatefile` | `templatefile("haproxy.cfg.tftpl", { server = ["web1"] })` | il contenuto del file, con le variabili sostituite |
| `jsonencode` / `yamlencode` | `jsonencode({ porte = [80] })` | `"{\"porte\":[80]}"` |
| `sha256` | `sha256(file("pagina.html"))` | un'impronta: cambia se cambia il file |

I **template** (`.tftpl`) usano `${variabile}` e le direttive `%{ for }` / `%{ if }`; la `~` toglie l'a capo:
```
backend http_back
%{ for nome in server ~}
    server ${nome} ${nome}:80 check
%{ endfor ~}
```

### count e for_each
Per creare più copie di una risorsa (o di un modulo):
```hcl
resource "docker_container" "web" {
  count = 3                                   # web[0], web[1], web[2]
  name  = "web-${count.index}"
}

resource "docker_container" "web" {
  for_each = var.web                          # mappa o set di stringhe: web["web1"], web["web2"]
  name     = each.key                         # la chiave
  # each.value: il valore (per un set, uguale alla chiave)
}
```
Con `count` le istanze sono identificate dalla **posizione**: togliendo il primo elemento di una lista di tre, tutti gli
altri scalano di un posto e Terraform ricrea tutto quello che segue. Con `for_each` sono identificate dalla **chiave**:
```
# con count, togliendo "web1" da ["web1", "web2", "web3"]:
  # terraform_data.con_count[0] must be replaced
  # terraform_data.con_count[1] must be replaced
  # terraform_data.con_count[2] will be destroyed
# con for_each, lo stesso cambiamento:
  # terraform_data.con_for_each["web1"] will be destroyed
```
Regola pratica: `count` per "N copie identiche" o per accendere/spegnere una risorsa (`count = var.abilita ? 1 : 0`),
`for_each` per tutto il resto.

### Blocchi dynamic
Generano blocchi annidati ripetuti, come `ports` o `labels`, da una collezione:
```hcl
dynamic "labels" {
  for_each = local.etichette                  # una mappa
  content {
    label = labels.key                        # il nome del blocco fa da iteratore
    value = labels.value
  }
}
```

### Dipendenze e lifecycle
Terraform ricava l'ordine dai riferimenti: se il container usa `docker_image.nginx.image_id`, crea prima l'immagine; se
non c'è nessun riferimento, crea le risorse in parallelo (10 alla volta, `-parallelism=N`). Quando la dipendenza esiste
ma non si vede nel codice, la si dichiara:
```hcl
resource "docker_container" "lb" {
  # ...
  depends_on = [docker_container.web]         # HAProxy risolve i nomi dei web server all'avvio: prima loro

  lifecycle {
    create_before_destroy = true              # nelle sostituzioni crea il nuovo prima di distruggere il vecchio
    prevent_destroy       = true              # errore se un piano vuole distruggerla (database, bucket)
    ignore_changes        = [tags]            # non riportare indietro le modifiche fatte a mano a questi attributi
    replace_triggered_by  = [docker_container.web] # ricreala quando cambia un'altra risorsa
    # destroy = false                         # (1.16+) quando andrebbe distrutta (anche con destroy) la toglie solo dallo stato
    precondition {
      condition     = var.porta != 8404
      error_message = "La 8404 è delle statistiche."
    }
  }
}
```

### Data source
```hcl
data "aws_ami" "ubuntu" {                     # l'Ubuntu 24.04 più recente, invece di un ID scritto a mano
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
# uso: data.aws_ami.ubuntu.id
```

## Provider
- l'autenticazione si prende di solito dall'ambiente, non dai file: `~/.aws/credentials` o `AWS_ACCESS_KEY_ID`,
  `~/.kube/config`, il demone Docker locale. Credenziali scritte in un `.tf` finiscono in git
- `.terraform.lock.hcl` fissa versione e hash di ogni provider: si committa, e `init -upgrade` lo aggiorna di proposito
- più configurazioni dello stesso provider con `alias`:
```hcl
provider "aws" { region = "eu-central-1" }
provider "aws" {
  alias  = "usa"
  region = "us-east-1"
}
resource "aws_acm_certificate" "cdn" {
  provider = aws.usa                           # CloudFront vuole i certificati in us-east-1
  # ...
}
```

## Moduli
Un modulo è una cartella di file `.tf`: le sue `variable` sono gli input, i suoi `output` quello che restituisce. Anche la
cartella in cui si lancia `terraform` è un modulo, la **radice**. Esempio completo in [03-moduli/](03-moduli/).
```hcl
module "blog" {
  source   = "./modules/sito"                  # locale
  nome     = "blog"                            # le variabili del modulo
  porta    = 8091
}
# uso degli output: module.blog.url

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"    # dal registry pubblico
  version = "~> 6.0"                           # per i moduli del registry la versione va sempre fissata
  # ...
}
# altre sorgenti: "git::https://github.com/org/repo.git//cartella?ref=v1.2.0"
```
- dopo aver aggiunto o cambiato un `module` serve `terraform init` (li scarica in `.terraform/modules/`)
- un modulo dichiara in `required_providers` quali provider usa; le versioni le fissa la radice
- `for_each` e `count` funzionano anche sui moduli: `module.ambiente["sviluppo"]`

## Lo stato
Dopo `apply` Terraform scrive `terraform.tfstate`: la mappa fra gli indirizzi dei file (`docker_container.web`) e gli
oggetti reali (ID, IP, attributi). Al `plan` successivo rilegge la realtà (*refresh*), la confronta con lo stato e con i
file, e calcola cosa cambiare. Tutti i comandi qui sotto sono provati nel laboratorio [04-stato/](04-stato/).
```bash
terraform state list                           # le risorse che Terraform gestisce
terraform state show docker_container.web      # tutti gli attributi di una risorsa (-json dalla 1.16)
terraform show                                 # tutto lo stato in forma leggibile
terraform show -json | jq '.values.root_module.resources[].address'
terraform output                               # i valori dei blocchi output
terraform output -raw url                      # un solo valore senza virgolette: da usare negli script
ssh ubuntu@$(terraform output -raw instance_public_ip) # es. collegarsi al server appena creato
terraform state mv docker_container.web docker_container.sito  # rinominare nello stato (meglio il blocco moved)
terraform state rm docker_container.web        # dimenticare una risorsa senza distruggerla (meglio il blocco removed)
terraform plan -refresh-only                   # solo le differenze fra stato e realtà (drift), senza toccare nulla
terraform apply -refresh-only                  # accetta la realtà com'è e aggiorna lo stato
terraform force-unlock ID                      # toglie un lock rimasto appeso (l'ID è nel messaggio di errore)
```
> **ATTENZIONE**: `terraform.tfstate` contiene dati sensibili in chiaro (password generate, chiavi, IP) e **non va in git**:
> sta nel `.gitignore` insieme alla cartella `.terraform/`. Il file `.terraform.lock.hcl` invece si versiona.

### Blocchi moved, import, removed
Le operazioni sullo stato si possono scrivere nei file, così passano dalla revisione del codice e valgono per tutti:
```hcl
moved {                                        # ho rinominato la risorsa: non distruggere e ricreare, sposta nello stato
  from = docker_container.web
  to   = docker_container.sito
}

import {                                       # adotta un oggetto creato a mano (con docker run, dalla console del cloud)
  to = docker_container.importato
  id = "b25b59e4b542..."                       # l'ID che il provider si aspetta: per Docker l'ID completo del container
}

removed {                                      # smetti di gestirla senza distruggerla
  from = docker_container.importato
  lifecycle {
    destroy = false
  }
}
```
Con `terraform plan -generate-config-out=generato.tf` Terraform scrive anche il blocco `resource` per gli oggetti da
importare: va sempre riletto, perché spesso contiene attributi che causerebbero una sostituzione.

### Stato remoto
Da soli basta il file locale. In squadra lo stato va in un **backend remoto**, con il **lock**: impedisce che due `apply`
contemporanei lo corrompano.
```hcl
terraform {
  backend "s3" {
    bucket       = "nome-del-mio-bucket-terraform"
    key          = "progetto/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true                         # lock nativo di S3 (1.10+): la tabella DynamoDB non serve più
  }
}
```
Altri backend: `azurerm`, `gcs`, `http`, `pg` (PostgreSQL), HCP Terraform (`cloud {}`). Dopo aver aggiunto o cambiato il
backend, `terraform init -migrate-state` sposta lo stato esistente nel nuovo.

### Workspace
Stati separati per la stessa configurazione, nello stesso backend: `terraform.workspace` contiene il nome di quello attivo.
```bash
terraform workspace new prova                  # crea e seleziona (stato in terraform.tfstate.d/prova/)
terraform workspace list
terraform workspace select default
terraform workspace delete prova               # solo se il suo stato è vuoto (prima destroy)
```
Comodi per copie temporanee (una per branch, una per prova). Per ambienti veri e diversi fra loro (sviluppo e produzione,
magari su account diversi) si preferiscono cartelle separate che chiamano gli stessi moduli: ognuna ha il suo backend,
e un errore in una non può toccare l'altra.

## Terraform in una pipeline
```bash
export TF_IN_AUTOMATION=1                      # messaggi adatti a un log, senza suggerimenti per l'uso interattivo
terraform fmt -check -recursive                # fallisce se qualcuno non ha formattato
terraform init -input=false
terraform validate
terraform plan -input=false -out=piano.tfplan -detailed-exitcode
# exit code: 0 = nessuna modifica, 1 = errore, 2 = ci sono modifiche
terraform show -no-color piano.tfplan > piano.txt   # da allegare alla pull request o far approvare
terraform apply -input=false piano.tfplan      # applica ESATTAMENTE il piano approvato
```
Lo schema tipico: `plan` a ogni pull request, `apply` del piano salvato dopo l'approvazione (in Jenkins con uno step
`input`, vedi [../07-jenkins/jenkins.md](../07-jenkins/jenkins.md)). Il piano salvato contiene segreti come lo stato:
va trattato allo stesso modo.

## Problemi comuni
| Messaggio o sintomo | Causa | Cosa fare |
|---|---|---|
| `Error acquiring the state lock` | un altro `apply` in corso, o uno interrotto | aspettare; se è appeso davvero `terraform force-unlock ID` |
| `Inconsistent dependency lock file` | provider nel file diversi da quelli del lock | `terraform init` (o `init -upgrade` se il vincolo è cambiato) |
| `Invalid value for variable` | una `validation` non passa | il messaggio dice quale e perché |
| una risorsa viene ricreata a ogni plan | un attributo che il provider normalizza, o cambiato fuori da Terraform | `# forces replacement` nel piano; eventualmente `ignore_changes` |
| il piano vuole distruggere tutto | directory o workspace sbagliati, stato mancante | `terraform workspace show`, `terraform state list` |
| `Cycle: ...` | due risorse che si riferiscono a vicenda | spezzare il ciclo, spesso con una risorsa separata (es. regole di un security group) |

Log dettagliati: `TF_LOG=DEBUG terraform plan` (livelli `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`), su file con `TF_LOG_PATH=tf.log`.

## Esempi in questa cartella
Ogni cartella ha il suo README con i passi e la spiegazione. Gli esempi `01`-`04` e `06` sono gratuiti e in locale.

| Cartella | Cosa mostra | Serve |
|---|---|---|
| [01-docker-nginx/](01-docker-nginx/) | la prima risorsa: `init`, `plan`, `apply`, `destroy`, dipendenze implicite | Docker |
| [02-webfarm/](02-webfarm/) | variabili con validazione, `for_each`, `dynamic`, `templatefile`, `depends_on`, `replace_triggered_by`, output con `for` | Docker |
| [03-moduli/](03-moduli/) | un modulo locale chiamato più volte, `for_each` su un modulo, tipi `object` con `optional` | Docker |
| [04-stato/](04-stato/) | drift, `-refresh-only`, `-replace`, `moved`, `import` con generazione della configurazione, `removed`, workspace | Docker |
| [05-aws-ec2/](05-aws-ec2/) | un server vero su AWS: AMI da data source, chiave SSH, security group, `user_data`, backend S3 | account AWS |
| [06-kubernetes/](06-kubernetes/) | oggetti Kubernetes nel cluster kind con il provider `kubernetes` | il cluster di [../06-kubernetes/](../06-kubernetes/) |
