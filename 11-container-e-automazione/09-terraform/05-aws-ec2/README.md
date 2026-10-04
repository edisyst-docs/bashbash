# 05 - Un server su AWS

Un'istanza EC2 Ubuntu con nginx, raggiungibile in HTTP da tutti e in SSH solo dal proprio IP.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | Provider AWS 6.x con `default_tags`, AMI cercata con un data source, chiave SSH, security group e regole, istanza con `user_data`; backend S3 commentato |
| [variables.tf](variables.tf) | Regione, tipo e nome dell'istanza, chiave pubblica, IP ammessi in SSH |
| [terraform.tfvars](terraform.tfvars) | I valori di questo ambiente |
| [outputs.tf](outputs.tf) | ID, IP pubblico, URL e comando SSH |

Oltre all'istanza, Terraform crea:
- `aws_key_pair`: carica su AWS la mia chiave pubblica (`~/.ssh/id_ed25519.pub`, vedi [../../../08-remoto-e-sicurezza/01-ssh.md](../../../08-remoto-e-sicurezza/01-ssh.md))
- `aws_security_group` con tre regole separate: SSH dal mio IP, HTTP da tutti, tutto in uscita. Senza, AWS blocca
  tutto il traffico in ingresso
- nell'istanza, `user_data`: uno script che cloud-init esegue come root al primo avvio, qui installa nginx

## Prima di iniziare
- un account AWS e le credenziali configurate: `aws configure` (AWS CLI) scrive `~/.aws/credentials`, che il provider
  legge con `profile = "default"`
- la regione di default è Francoforte (`eu-central-1`). Milano (`eu-south-1`) è una regione *opt-in*: va attivata prima
  nella console dell'account
- una chiave SSH: `ssh-keygen -t ed25519`

> **ATTENZIONE**: le risorse cloud si pagano finché esistono (i crediti gratuiti dei nuovi account coprono una piccola
> istanza per un po', non per sempre). Dopo la prova: `terraform destroy`.

## I comandi
```bash
terraform init
terraform plan                                       # nessun costo: mostra solo cosa creerebbe
terraform apply -var "ssh_allowed_cidr=$(curl -s ifconfig.me)/32"   # SSH aperto solo al mio IP
terraform output url                                 # dopo un minuto (cloud-init deve finire) la pagina di nginx
ssh ubuntu@$(terraform output -raw instance_public_ip)   # l'utente delle immagini Ubuntu è "ubuntu"
sudo cloud-init status --wait                        # (sull'istanza) aspetta la fine di user_data
terraform destroy
```
`terraform.tfvars` sovrascrive i default di `variables.tf`, che vengono usati in `main.tf` come `var.nome`:
per cambiare dimensione o nome dell'istanza si modifica `terraform.tfvars`, non `main.tf`.

## Cose da notare
- **`data "aws_ami"`**: l'ID di un'AMI cambia per regione e a ogni aggiornamento; il data source cerca la più recente
  di Canonical (`owners`) con quel nome. Quando Canonical pubblica un'immagine nuova, il `plan` successivo vuole
  ricreare l'istanza: in produzione si fissa l'AMI, o si usa `ignore_changes = [ami]`
- **`user_data_replace_on_change = true`**: `user_data` gira solo al primo avvio, quindi se lo cambio l'istanza va ricreata
- **`default_tags`**: `Progetto` e `GestitoDa` finiscono su ogni risorsa che li supporta, senza ripeterli
- **regole del security group come risorse separate** (`aws_vpc_security_group_ingress_rule`): si aggiungono e tolgono
  senza toccare il gruppo, ed evitano i conflitti fra regole scritte dentro e fuori dal gruppo
- **backend S3** (commentato in `main.tf`): per lavorare in più persone lo stato va in un bucket, con `use_lockfile = true`
  per il lock. Il bucket si crea una volta a mano (o con una configurazione Terraform separata), con il versioning attivo

Torna a [../](../)
