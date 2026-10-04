# 06 - Terraform e Kubernetes

Il sito del [laboratorio Kubernetes 01](../../06-kubernetes/01-deployment/), descritto in HCL invece che in YAML:
namespace, ConfigMap, Deployment e Service creati con il provider `hashicorp/kubernetes` nel cluster kind.

| File | Contenuto |
|---|---|
| [main.tf](main.tf) | Provider configurato dal kubeconfig; `kubernetes_namespace_v1`, `_config_map_v1`, `_deployment_v1`, `_service_v1` |
| [variables.tf](variables.tf) | Contesto del kubeconfig, namespace, repliche, versione di nginx, messaggio della pagina |
| [outputs.tf](outputs.tf) | URL e comando kubectl |

## Creare
Serve il cluster dei laboratori, che porta anche la 30086 su `localhost`:
```bash
kind create cluster --config ../../06-kubernetes/kind-cluster.yaml   # se non c'è già
terraform init
terraform apply
curl localhost:30086              # <h1>Creato da Terraform</h1>
kubectl -n terraform get all
```
Il provider usa le stesse credenziali di kubectl: `config_path = "~/.kube/config"` e `config_context = "kind-lab"`.
Le risorse hanno il suffisso `_v1`, come le versioni delle API di Kubernetes: dalla versione 3 del provider quelle
senza suffisso sono deprecate. `kubernetes_deployment_v1` aspetta la fine del rollout prima di dare l'apply per concluso.

## Drift: kubectl contro Terraform
```bash
kubectl -n terraform scale deploy web --replicas=5
terraform plan
```
```
  # kubernetes_deployment_v1.web will be updated in-place
          ~ replicas = "5" -> "2"
```
Chi gestisce una risorsa deve essere uno solo: se la gestisce Terraform, le modifiche fatte con kubectl vengono
annullate al prossimo apply. Con un HPA le repliche le decide lui, e nel Deployment si aggiunge
`lifecycle { ignore_changes = [spec[0].replicas] }`.

## Cambiare la pagina
```bash
terraform apply -var messaggio="Aggiornato da Terraform"
curl localhost:30086              # <h1>Aggiornato da Terraform</h1>
kubectl -n terraform get rs       # un ReplicaSet nuovo: i Pod sono stati sostituiti
```
Cambiano la ConfigMap e l'annotazione `checksum/pagina` nel template del Pod (`sha256()` del contenuto): il template
è diverso, e parte il rolling update. È lo stesso trucco del [chart Helm](../../06-kubernetes/07-helm/).

## Terraform, Helm o kubectl?
- **Terraform** è comodo per ciò che sta *intorno* alle applicazioni e va creato insieme all'infrastruttura: il cluster
  stesso (EKS, GKE, AKS), namespace, quote, permessi, i componenti di base installati con il provider `helm`
- le **applicazioni**, che cambiano a ogni rilascio, di solito si gestiscono con manifest, Kustomize o Helm applicati
  da una pipeline (vedi [../../07-jenkins/](../../07-jenkins/)) o da uno strumento GitOps (Argo CD, Flux: vedi
  [../../11-argocd/](../../11-argocd/))

## Smontare
```bash
terraform destroy                 # cancella il namespace, e con lui tutto quello che contiene
```

Torna a [../](../)
