# gitops

Il repository che Argo CD tiene sincronizzato con il cluster del laboratorio. Ogni cartella è un'applicazione:

| Cartella | Cosa è | Application |
|---|---|---|
| `sito/` | manifest YAML semplici: nginx con un messaggio | `sito` |
| `mia-app/` | Kustomize: una base e due overlay, `dev` e `prod` | `mia-app-dev`, `mia-app-prod` (ApplicationSet) |
| `chart-sito/` | un chart Helm: **non sta in questa cartella**, `laboratorio.sh` lo copia da [../../06-kubernetes/07-helm/sito](../../06-kubernetes/07-helm/sito/) nel repository `gitops` | `chart-sito` |
| `apps/` | le definizioni delle Application stesse (app of apps) | `root` |

Torna a [../](../)
