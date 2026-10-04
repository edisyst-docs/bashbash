# 01 - Il primo apply: un container nginx

Un container Nginx gestito da Terraform, con il provider Docker. Gratis e in locale: serve solo Docker in esecuzione.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | Provider `kreuzwerker/docker`, un'immagine e un container che la usa |
| [.terraform.lock.hcl](.terraform.lock.hcl) | Versione e hash del provider: `init` scarica esattamente quella |

## Il ciclo completo
```bash
terraform init                    # scarica il provider in .terraform/
terraform plan                    # 2 to add: l'immagine e il container
terraform apply                   # rimostra il piano e chiede "yes"
curl localhost:8000               # la pagina di benvenuto di nginx (o http://localhost:8000 nel browser)
docker ps                         # il container "tutorial" creato da Terraform
terraform state list              # docker_container.nginx, docker_image.nginx
terraform destroy                 # elimina container e immagine
```
Il provider senza parametri usa il Docker locale, come la CLI: il socket `/var/run/docker.sock` su Linux, la named pipe
di Docker Desktop su Windows. Per un Docker remoto: `provider "docker" { host = "ssh://utente@server" }`.

## L'ordine delle operazioni
Il container usa `docker_image.nginx.image_id`: questo riferimento è una **dipendenza implicita**, e Terraform crea
prima l'immagine e poi il container (e in `destroy` fa il contrario). Nell'output di `apply` si vede l'ordine:
```
docker_image.nginx: Creating...
docker_image.nginx: Creation complete after 0s
docker_container.nginx: Creating...
```

## Una modifica che ricrea
Cambiare `external = 8000` in `8001` e rilanciare il piano:
```bash
terraform plan
```
```
  # docker_container.nginx must be replaced
-/+ resource "docker_container" "nginx" {
```
Un container Docker non può cambiare le porte pubblicate mentre esiste: il provider lo sa, e il piano dice
`-/+` (distruggi e ricrea), con `# forces replacement` accanto all'attributo responsabile. Leggere sempre il piano
prima di dire "yes": su un database, `-/+` vuol dire perdere i dati.

## Cambiare le cose a mano
```bash
terraform apply
docker rm -f tutorial             # qualcuno lo cancella fuori da Terraform
terraform plan                    # docker_container.nginx will be created: Terraform se ne accorge e lo ricrea
```
Terraform confronta lo stato con la realtà a ogni `plan`: quello che è stato cambiato a mano (il **drift**) torna come
dicono i file. Altri esperimenti sullo stato in [../04-stato/](../04-stato/).

Torna a [../](../)
