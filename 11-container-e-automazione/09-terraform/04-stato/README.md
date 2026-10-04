# 04 - Lo stato: drift, rinomine, import, workspace

Laboratorio da seguire passo passo, su un solo container nginx. Mostra cosa succede quando la realtà e i file non
coincidono, e come si sistemano le cose senza distruggere niente.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | Un'immagine e un container; nome e porta dipendono dal workspace (`terraform.workspace`) |

```bash
terraform init
terraform apply                   # container stato-default su http://localhost:8095
```

## 1. Guardare lo stato
```bash
terraform state list                        # docker_container.web, docker_image.nginx
terraform state show docker_container.web   # tutti gli attributi: id, name, image, ports...
terraform show                              # tutto lo stato, leggibile
terraform output -raw url                   # http://localhost:8095, senza virgolette
```
Lo stato sta in `terraform.tfstate`, un JSON. Ogni `apply` salva la versione precedente in `terraform.tfstate.backup`.

## 2. Drift: qualcuno cambia le cose a mano
```bash
docker rm -f stato-default
terraform plan                    # docker_container.web will be created
terraform plan -refresh-only      # docker_container.web has been deleted: SOLO il confronto con la realtà
terraform apply                   # lo ricrea
```
`plan` rilegge la realtà (*refresh*), vede che il container non c'è più e propone di ricrearlo: i file vincono.
`-refresh-only` mostra solo cosa è cambiato fuori da Terraform, e `apply -refresh-only` aggiornerebbe lo stato
accettando la realtà, senza toccare l'infrastruttura.

Un container fermato:
```bash
docker stop stato-default
terraform plan
```
```
  # docker_container.web must be replaced
      ~ must_run = false -> true
```
Il provider Docker 4.x si accorge che il container non gira (`must_run` è `true` di default) e lo sostituisce con uno acceso.

## 3. Ricreare di proposito
```bash
terraform apply -replace=docker_container.web   # docker_container.web will be replaced, as requested
```
Per un oggetto "rovinato" che la configurazione non vede come diverso. Sostituisce il vecchio `terraform taint`.

## 4. Rinominare una risorsa: moved
In `main.tf` rinominare `resource "docker_container" "web"` in `resource "docker_container" "sito"`:
```bash
terraform plan
```
```
  # docker_container.sito will be created
  # docker_container.web will be destroyed
  # (because docker_container.web is not in configuration)
```
Per Terraform un indirizzo nuovo è una risorsa nuova: distruggerebbe e ricreerebbe il container. Si aggiunge in `main.tf`:
```hcl
moved {
  from = docker_container.web
  to   = docker_container.sito
}
```
```bash
terraform plan                    # docker_container.web has moved to docker_container.sito / Plan: 0 to add, 0 to change, 0 to destroy
terraform apply
```
Lo stesso da riga di comando è `terraform state mv docker_container.web docker_container.sito`, ma il blocco `moved`
sta nel codice: passa dalla revisione e vale per chiunque applichi la configurazione (anche per chi usa il modulo).
Dopo che tutti hanno applicato, il blocco si può togliere.

## 5. Importare un oggetto creato a mano
Un container nato fuori da Terraform:
```bash
docker run -d --name importato -p 8098:80 nginx:1.27-alpine
ID=$(docker inspect -f '{{.Id}}' importato)
cat > import.tf <<EOF
import {
  to = docker_container.importato
  id = "$ID"
}
EOF
terraform plan -generate-config-out=generato.tf   # scrive il blocco resource in generato.tf
```
Terraform ha letto il container e scritto la sua configurazione in `generato.tf` (decine di righe, molte a `null`), ma il piano dice:
```
  # Warning: this will destroy the imported resource
Plan: 1 to import, 1 to add, 0 to change, 1 to destroy.
```
La configurazione generata va **sempre** riletta. Il motivo si trova nel piano:
```bash
terraform plan | grep "forces replacement"
#   + env = (known after apply) # forces replacement
```
Il provider legge fra le variabili d'ambiente anche quelle dell'immagine, che nel file generato mancano. Si dice a
Terraform di ignorarle, aggiungendo all'inizio del blocco `resource` in `generato.tf`:
```hcl
  lifecycle {
    ignore_changes = [env]
  }
```
```bash
terraform plan                    # Plan: 1 to import, 0 to add, 1 to change, 0 to destroy
terraform apply
docker inspect -f '{{.Id}}' importato   # lo stesso ID di prima: adottato, non ricreato
```
Il `change` riguarda solo impostazioni interne del provider (`must_run`, `start`...) che non esistono nel container.
Dopo l'import il blocco `import` si può cancellare, e il contenuto di `generato.tf` va ripulito e spostato in `main.tf`.

## 6. Smettere di gestire senza distruggere: removed
Il container `importato` deve continuare a vivere, ma fuori da Terraform. Si cancellano `import.tf` e `generato.tf`
e si scrive `rimosso.tf`:
```hcl
removed {
  from = docker_container.importato

  lifecycle {
    destroy = false
  }
}
```
```bash
terraform plan                    # docker_container.importato will no longer be managed by Terraform, but will not be destroyed
terraform apply
docker ps --filter name=importato # è ancora lì
rm rimosso.tf
docker rm -f importato
```
L'equivalente da riga di comando è `terraform state rm docker_container.importato`.
Senza il blocco `removed`, cancellare la risorsa dal file vorrebbe dire distruggerla.

## 7. Workspace
(Se al punto 4 la risorsa è diventata `sito`, va bene lo stesso: i workspace funzionano uguale.)
```bash
terraform workspace new prova     # crea e seleziona il workspace "prova", con uno stato vuoto
terraform apply                   # un SECONDO container: stato-prova su http://localhost:8096
docker ps --filter name=stato     # stato-default e stato-prova
terraform workspace list          # default, * prova
find . -name "*.tfstate"          # ./terraform.tfstate e ./terraform.tfstate.d/prova/terraform.tfstate
terraform destroy                 # distrugge solo quello del workspace attivo
terraform workspace select default
terraform workspace delete prova
```
Nei file `terraform.workspace` vale `default` o `prova`: qui sceglie nome e porta, così le due copie non si scontrano.

## Smontare
```bash
terraform destroy
```

Torna a [../](../)
