# 06 - Kubernetes

| File | Contenuto |
|---|---|
| [kubernetes.md](kubernetes.md) | Concetti e architettura, cluster locale con kind, manifest, tutti i comandi `kubectl`, workload, Service, Ingress e Gateway, ConfigMap e Secret, storage, probe e risorse, RBAC, Kustomize, Helm, risoluzione dei problemi |
| [kind-cluster.yaml](kind-cluster.yaml) | Il cluster dei laboratori: 1 control plane + 2 worker, porte 30080-30085 su `localhost` |
| [01-deployment/](01-deployment/) | nginx replicato: bilanciamento, self-healing, scalare, rolling update, rollback |
| [02-config/](02-config/) | ConfigMap e Secret come variabili e come file |
| [03-wordpress-mysql/](03-wordpress-mysql/) | StatefulSet con volume persistente, Kustomize, WordPress replicato |
| [04-app-propria/](04-app-propria/) | La propria immagine: probe, risorse, aggiornamento senza errori, autoscaling |
| [05-job-cronjob/](05-job-cronjob/) | Job paralleli con indice, CronJob, script bash |
| [06-ingress-gateway/](06-ingress-gateway/) | LoadBalancer, Ingress e Gateway API con cloud-provider-kind, rilascio canary |
| [07-helm/](07-helm/) | Un chart scritto a mano, release, upgrade, rollback, chart pubblici |

```bash
kind create cluster --config kind-cluster.yaml   # prima di tutto
kind delete cluster --name lab                   # alla fine
```

Torna a [../](../)
