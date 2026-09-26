# Terraform

Infrastructure as Code: descrivo in file `.tf` le risorse che voglio (server, reti, DNS, container) e Terraform
le crea, le modifica o le distrugge per far coincidere la realtà con i file.
I file si versionano con git come il codice.

## Installazione
```bash
winget install Hashicorp.Terraform                   # Windows
sudo snap install terraform --classic                # Ubuntu (oppure il repository apt di HashiCorp)
terraform -version
```
Senza installarlo, con Docker: l'immagine ufficiale ha `terraform` come entrypoint, quindi si passa direttamente il sottocomando.
```bash
docker run --rm -it -v "$(pwd):/workspace" -w /workspace hashicorp/terraform:latest init  # monta la cartella corrente
docker run --rm -it -v "$(pwd):/workspace" -w /workspace hashicorp/terraform:latest plan
```
In PowerShell `"${PWD}:/workspace"`. Per gestire Docker dall'interno del container (esempio `docker-nginx`) serve
anche montare il socket: `-v /var/run/docker.sock:/var/run/docker.sock`.

## Il ciclo di lavoro
Tutti i comandi si lanciano nella cartella che contiene i file `.tf`: Terraform li legge tutti insieme,
il nome dei file non conta.
```bash
terraform init                    # scarica i provider dichiarati (in .terraform/) e crea .terraform.lock.hcl. Da rifare se cambio provider
terraform fmt                     # formatta i file .tf (-recursive per le sottocartelle)
terraform validate                # controlla sintassi e riferimenti, senza contattare il cloud
terraform plan                    # mostra cosa FAREBBE: + crea, ~ modifica, - distrugge, -/+ ricrea. Non tocca nulla
terraform plan -out=piano.tfplan  # salva il piano...
terraform apply piano.tfplan      # ...e applica esattamente quello, senza ridomandare
terraform apply                   # piano + conferma interattiva (bisogna scrivere "yes") + esecuzione
terraform apply -var "instance_name=MiaIstanzaCustom" # sovrascrive una variabile solo per questa esecuzione
terraform apply -var-file=produzione.tfvars           # un file di variabili diverso da terraform.tfvars
terraform destroy                 # distrugge TUTTE le risorse gestite da questa configurazione (chiede conferma)
```

## Lo stato
Dopo `apply` Terraform scrive `terraform.tfstate`: la mappa tra le risorse dei file e quelle reali (ID, IP...).
Al `plan` successivo confronta file, stato e realtà per capire cosa cambiare.
```bash
terraform state list                           # le risorse che Terraform gestisce
terraform state show aws_instance.app_server   # tutti gli attributi di una risorsa
terraform show                                 # tutto lo stato in forma leggibile
terraform output                               # i valori dichiarati nei blocchi output
terraform output -raw instance_public_ip       # un solo valore senza virgolette: da usare negli script
ssh ubuntu@$(terraform output -raw instance_public_ip) # es. collegarsi al server appena creato
```
> **ATTENZIONE**: `terraform.tfstate` contiene dati sensibili in chiaro (password, chiavi) e **non va messo in git**:
> va nel `.gitignore` insieme alla cartella `.terraform/`. Il file `.terraform.lock.hcl` invece si versiona.
> Quando più persone lavorano sulla stessa infrastruttura, lo stato va in un **backend remoto** (es. un bucket S3)
> con il **lock**: impedisce che due `apply` contemporanei lo corrompano.

## Struttura dei file
Convenzione (Terraform legge comunque tutti i `.tf` della cartella):

| File | Contenuto |
|---|---|
| `main.tf` | blocco `terraform` con i provider richiesti, `provider`, `resource`, `data` |
| `variables.tf` | le variabili con tipo, descrizione e default |
| `outputs.tf` | i valori da restituire dopo l'apply |
| `terraform.tfvars` | i valori delle variabili per questo ambiente: letto in automatico |

I blocchi principali:
```hcl
provider "aws" { region = var.region }       # con quale servizio parlare e come autenticarsi

resource "aws_instance" "app_server" {       # una risorsa da creare: tipo e nome locale
  ami           = data.aws_ami.ubuntu.id     # riferimento a un data source
  instance_type = var.instance_type          # riferimento a una variabile
}

data "aws_ami" "ubuntu" { ... }              # una cosa che esiste già e che leggo soltanto

variable "region" { default = "eu-south-1" } # un parametro
output "ip" { value = aws_instance.app_server.public_ip } # un valore restituito
```
Terraform ricava l'ordine di creazione dai riferimenti tra risorse: se il container usa `docker_image.nginx.image_id`,
crea prima l'immagine.

Precedenza delle variabili, dalla più debole alla più forte: `default` in `variables.tf` < variabili d'ambiente
`TF_VAR_nome` < `terraform.tfvars` < `-var-file` < `-var`.

## Esempi in questa cartella
### [docker-nginx/](docker-nginx/): gratis e in locale
Un container Nginx gestito da Terraform, con il provider Docker. Serve solo Docker in esecuzione.
```bash
cd docker-nginx
terraform init
terraform apply                   # poi http://localhost:8000
docker ps                         # il container "tutorial" creato da Terraform
terraform destroy                 # lo elimina
```
Provare a cambiare `external = 8000` in `8001` e rilanciare `terraform plan`: mostra che il container va ricreato (`-/+`).

### [aws-ec2/](aws-ec2/): un server su AWS
Un'istanza EC2 Ubuntu. Serve un account AWS con le credenziali configurate (`aws configure`).
> **ATTENZIONE**: le risorse cloud si pagano finché esistono. Dopo la prova: `terraform destroy`.

```bash
cd aws-ec2
terraform init
terraform plan                    # nessun costo: mostra solo cosa creerebbe
terraform apply
terraform output instance_public_ip
terraform destroy
```
`terraform.tfvars` sovrascrive i default di `variables.tf`, che vengono usati in `main.tf` come `var.nome`:
per cambiare dimensione o nome dell'istanza si modifica `terraform.tfvars`, non `main.tf`.
