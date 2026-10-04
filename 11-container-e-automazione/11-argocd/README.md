# 11 - Argo CD

| File | Contenuto |
|---|---|
| [argocd.md](argocd.md) | GitOps, architettura, il laboratorio passo passo (11 passi), installazione, Application e tipi di sorgente, stati, sync: opzioni, `ignoreDifferences`, onde e hook, retry; ApplicationSet, AppProject e RBAC, credenziali dei repository, segreti, webhook, CI che aggiorna git, più cluster, CLI, notifiche, confronto con Flux, problemi comuni |
| [laboratorio.sh](laboratorio.sh) | `crea` / `stato` / `elimina`: cluster kind, registry, Gitea, Argo CD e il repository `gitops` |
| [kind-argocd.yaml](kind-argocd.yaml) | Cluster kind `argocd`: un control plane e un worker, porte 30090-30093 e 30443 |
| [compose.yaml](compose.yaml) | Registry 3.1 e Gitea 28 sulla rete Docker `kind` |
| [argocd/](argocd/) | Argo CD 3.5.3 installato con Kustomize: NodePort 30443, riconciliazione ogni 60 s |
| [repo/](repo/) | Il contenuto iniziale del repository `gitops`: `sito/` (YAML), `mia-app/` (Kustomize, dev e prod), `apps/` (app of apps) |
| [applicazioni/](applicazioni/) | Le Application da applicare a mano: la prima (`sito.yaml`) e la radice dell'app of apps (`root.yaml`) |

```bash
./laboratorio.sh crea      # poi https://localhost:30443, admin / laboratorio
kubectl apply -f applicazioni/sito.yaml && argocd app sync sito && curl localhost:30090
./laboratorio.sh elimina
```

Torna a [../](../)
