# 02 - Una web farm: variabili, for_each, template

N web server nginx dietro un HAProxy, su una rete Docker dedicata. Quanti server ci sono e cosa dicono lo decide una
variabile: aggiungere un server è aggiungere una riga. Lo stesso schema del laboratorio
[../../../10-rete-e-web/05-load-balancer/](../../../10-rete-e-web/05-load-balancer/), descritto con Terraform.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | Rete, immagini, web server con `for_each`, bilanciatore con la configurazione generata |
| [variables.tf](variables.tf) | `progetto`, `web` (mappa nome → messaggio), porte, versione di nginx; con `validation` |
| [terraform.tfvars](terraform.tfvars) | I valori di questo ambiente: due server, il terzo commentato |
| [outputs.tf](outputs.tf) | URL e una mappa nome → IP costruita con un'espressione `for` |
| [haproxy.cfg.tftpl](haproxy.cfg.tftpl) | Template della configurazione di HAProxy: una riga `server` per ogni web server |

## 1. Creare
```bash
terraform init
terraform apply
```
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:
statistiche = "http://localhost:8404/stats"
url = "http://localhost:8090"
web_server = {
  "web1" = "172.20.0.3"
  "web2" = "172.20.0.2"
}
```
```bash
for i in 1 2 3 4; do curl -s localhost:8090; done   # web1, web2, web1, web2: il round robin
docker ps --filter label=progetto=webfarm           # le label le mette il blocco dynamic "labels"
docker exec webfarm-lb cat /usr/local/etc/haproxy/haproxy.cfg   # la configurazione generata dal template
```
Nel file generato, il ciclo `%{ for nome in server ~}` del template è diventato:
```
backend http_back
    balance roundrobin
    server web1 web1:80 check
    server web2 web2:80 check
```

## 2. Cosa c'è da notare in main.tf
- **`for_each = var.web`**: un container per ogni elemento della mappa; dentro, `each.key` è il nome (`web1`) e
  `each.value` il messaggio. Gli indirizzi sono `docker_container.web["web1"]`, `docker_container.web["web2"]`
- **`dynamic "labels"`**: genera un blocco `labels { ... }` per ogni elemento di `local.etichette`
- **`templatefile()`**: legge `haproxy.cfg.tftpl` e sostituisce le variabili; il risultato va nel container con `upload`
- **`depends_on`**: HAProxy risolve i nomi `web1`, `web2` una volta sola, all'avvio, quindi deve partire dopo i web
  server. Terraform non può dedurlo: nel template ci sono solo dei nomi, nessun riferimento alle risorse
- **`replace_triggered_by`**: se un web server viene ricreato cambia IP, e HAProxy (che conosce solo il vecchio) va
  ricreato con lui. L'alternativa senza Terraform è far risolvere i nomi a HAProxy di continuo, con il blocco
  `resolvers` usato nel laboratorio del load balancer

## 3. Aggiungere un server
In `terraform.tfvars` togliere il commento a `web3`, poi:
```bash
terraform plan
```
```
  # docker_container.lb must be replaced
  # docker_container.web["web3"] will be created
Plan: 2 to add, 0 to change, 1 to destroy.
```
Solo il server nuovo e il bilanciatore (la sua configurazione cambia: una riga `server` in più). `web1` e `web2` non
vengono toccati. Dopo `terraform apply`, il giro di `curl` risponde da tre server.

Togliere un server tocca solo quello (e il bilanciatore):
```
  # docker_container.web["web2"] will be destroyed
  # (because key ["web2"] is not in for_each map)
```
Con `count` invece di `for_each` le istanze sarebbero numerate per posizione, e togliere il primo farebbe ricreare
tutti gli altri: vedi [../terraform.md](../terraform.md), *count e for_each*.

## 4. Cambiare un messaggio
Cambiare il testo di `web1` in `terraform.tfvars`:
```
  # docker_container.lb will be replaced due to changes in replace_triggered_by
  # docker_container.web["web1"] must be replaced
```
Il contenuto di `upload` non si può cambiare in un container esistente: `web1` va ricreato, e `replace_triggered_by`
porta con sé il bilanciatore.

## 5. Le variabili si difendono
```bash
terraform plan -var porta=80
```
```
Error: Invalid value for variable
  on variables.tf line 32:
  32: variable "porta" {
Usare una porta fra 1024 e 65535.
```
La `validation` blocca il valore prima di calcolare il piano. Altre prove:
```bash
terraform plan -var 'web={}'                              # Da 1 a 5 web server.
terraform plan -var progetto=Web_Farm                     # Solo lettere minuscole, cifre e trattini...
terraform plan -var 'web={a="uno",b="due",c="tre"}'       # tre server con nomi diversi: ricrea tutto (tutte chiavi nuove)
```

## 6. Esplorare con console e output
```bash
echo 'keys(var.web)' | terraform console
echo '{ for k, v in var.web : upper(k) => length(v) }' | terraform console
echo 'docker_container.web["web2"].name' | terraform console   # "webfarm-web2": attributi delle risorse create
terraform output -json web_server                            # {"web1":"172.20.0.3","web2":"172.20.0.2"}
terraform graph -format=mermaid                              # il grafo delle dipendenze, da incollare in un .md
```

## Smontare
```bash
terraform destroy
```
Le immagini restano (`keep_locally = true`): le usano anche gli altri esempi.

Torna a [../](../)
