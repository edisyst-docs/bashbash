# 03 - Moduli

Un modulo è una cartella di file `.tf` riusabile, come una funzione: le sue variabili sono i parametri, i suoi output il
valore di ritorno. Qui il modulo `sito` (un container nginx con una pagina generata) viene usato tre volte.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | La radice: l'immagine nginx, una chiamata `module "blog"` e una `module "ambiente"` con `for_each` |
| [variables.tf](variables.tf) | `ambienti`: mappa di `object` con un campo `optional` |
| [outputs.tf](outputs.tf) | Gli URL, letti dagli output dei moduli |
| [modules/sito/](modules/sito/) | Il modulo: `main.tf`, `variables.tf` (input, con una `validation`), `outputs.tf`, il template `pagina.html.tftpl` |

## 1. Creare
```bash
terraform init                    # oltre al provider "installa" i moduli: - ambiente in modules\sito, - blog in modules\sito
terraform apply
```
```
ambienti = {
  "produzione" = "http://localhost:8093"
  "sviluppo" = "http://localhost:8092"
}
blog = "http://localhost:8091"
```
Tre siti con titolo e colore diversi, dallo stesso codice. Gli indirizzi nello stato dicono da dove viene ogni risorsa:
```bash
terraform state list
```
```
docker_image.nginx
module.ambiente["produzione"].docker_container.sito
module.ambiente["sviluppo"].docker_container.sito
module.blog.docker_container.sito
```

## 2. Come è fatto il modulo
- la **radice** passa i valori: `nome`, `porta`, `titolo`, `immagine`. `colore` ha un default nel modulo, quindi è facoltativo
- il modulo li usa come `var.nome`, `var.porta`... e non vede nient'altro della radice: tutto quello che gli serve
  arriva dalle variabili (anche l'immagine, creata una volta sola dalla radice e passata a tutti)
- `path.module` è la cartella del modulo: `templatefile("${path.module}/pagina.html.tftpl", ...)` trova il template
  ovunque il modulo venga chiamato
- il modulo dichiara in `required_providers` che usa `kreuzwerker/docker`, senza versione: la fissa la radice
- la radice legge i risultati come `module.blog.url` e, con `for_each`, `module.ambiente["sviluppo"].url`
- la `validation` sulla porta sta nel modulo: protegge chiunque lo usi
```bash
terraform plan -var 'ambienti={prova={porta=80}}'
```
```
Error: Invalid value for variable
  on main.tf line 38, in module "ambiente":
  38:   porta    = each.value.porta
    │ var.porta is 80
```

## 3. Un ambiente in più
`for_each` sul modulo: aggiungere un ambiente è aggiungere un elemento alla mappa.
```bash
terraform plan -var 'ambienti={sviluppo={porta=8092},produzione={porta=8093,colore="#c53030"},collaudo={porta=8094}}'
```
```
  # module.ambiente["collaudo"].docker_container.sito will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```
`collaudo` non specifica `colore`: `optional(string, "#2f855a")` in `variables.tf` gli dà il verde.

## 4. Lavorare su un modulo solo
```bash
terraform plan -target=module.blog   # considera solo quel modulo (e ciò da cui dipende)
```
Terraform avvisa `Resource targeting is in effect`: serve per riparare un problema preciso, non come abitudine,
perché il resto della configurazione non viene controllato.

## Moduli dal registry
Gli stessi concetti valgono per i moduli pubblicati: https://registry.terraform.io/browse/modules. Si chiamano con
`source = "terraform-aws-modules/vpc/aws"` e `version = "~> 6.0"`, e `terraform init` li scarica in `.terraform/modules/`.
Prima di usarne uno si leggono i suoi input e output nella pagina del registry.

## Smontare
```bash
terraform destroy
```

Torna a [../](../)
