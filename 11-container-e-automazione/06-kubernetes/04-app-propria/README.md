# 04 - La propria applicazione

Un'applicazione costruita con `docker build`, portata nel cluster e configurata come in produzione: probe, risorse,
spegnimento pulito, utente non root. Poi un aggiornamento senza nemmeno un errore, un rollout sbagliato e l'autoscaling.

| File | Contenuto |
|---|---|
| [app/app.py](app/app.py) | Server HTTP in Python (solo libreria standard): `/`, `/health`, `/ready`, `/cpu`, `/rompi` |
| [app/Dockerfile](app/Dockerfile) | `python:3.13-alpine`, versione passata con `--build-arg`, utente 1000 |
| [deployment.yaml](deployment.yaml) | 3 repliche con readiness e liveness probe, requests e limits, `preStop`, `securityContext` |
| [service.yaml](service.yaml) | NodePort 30083 |
| [hpa.yaml](hpa.yaml) | HorizontalPodAutoscaler: da 3 a 8 repliche al 50% di CPU |

## 1. L'immagine nel cluster
```bash
docker build -t mia-app:1.0 app/
docker build -t mia-app:2.0 --build-arg VERSIONE=2.0 app/
kind load docker-image mia-app:1.0 mia-app:2.0 --name lab
docker exec lab-worker crictl images | grep mia-app    # ora c'è dentro ogni nodo
```
I nodi di kind hanno il loro containerd e non vedono le immagini di Docker Desktop: `kind load` ve le copia. In un
cluster vero l'immagine va pubblicata su un registry (`docker push`) da cui i nodi la scaricano.
Nel Deployment `imagePullPolicy: IfNotPresent` dice di usare l'immagine già presente: con il tag `latest` il default
sarebbe `Always`, cioè cercarla ogni volta su Docker Hub, dove non esiste.

```bash
kubectl apply -f deployment.yaml -f service.yaml
kubectl rollout status deploy/mia-app
curl localhost:30083                     # versione 1.0 - pod mia-app-cddf4b9bb-57j47
```

## 2. Le probe
- **readiness** su `/ready`: l'app risponde 503 nei primi 3 secondi (simula il tempo di avvio: cache, connessioni).
  Finché non passa, il Pod è `0/1` e non riceve traffico
- **liveness** su `/health`: se fallisce 3 volte di fila, il container viene riavviato

Provare la liveness: `/rompi` fa rispondere 500 a `/health` sul Pod che riceve la richiesta.
```bash
curl localhost:30083/rompi               # mia-app-...-kvlhv rotta: la liveness probe la farà riavviare
kubectl get pods -w                      # dopo 15-20 secondi: RESTARTS 1 su quel Pod
kubectl get events --field-selector reason=Unhealthy
```
```
Liveness probe failed: HTTP probe failed with statuscode: 500
Readiness probe failed: HTTP probe failed with statuscode: 503
```
Tre fallimenti a 5 secondi di distanza, poi il riavvio (`Container app failed liveness probe, will be restarted`).
Il Pod resta lo stesso, riparte il container: il processo nuovo non è "rotto" e per 3 secondi la readiness risponde 503.

## 3. Aggiornamento senza errori
In un secondo terminale:
```bash
while true; do curl -s -m 2 localhost:30083 || echo ERRORE; sleep 0.1; done
```
Nel primo:
```bash
kubectl set image deploy/mia-app app=mia-app:2.0
kubectl rollout status deploy/mia-app
```
Nel secondo terminale le risposte si mescolano (`versione 1.0` e `versione 2.0`) e poi restano tutte `2.0`, senza
nessun `ERRORE`: nei test 300 richieste su 300. Rispetto al [laboratorio 01](../01-deployment/), qui lavorano insieme:
- `maxUnavailable: 0` + readiness: un Pod vecchio si spegne solo quando uno nuovo è pronto
- `preStop` con `sleep` di 5 secondi: quando un Pod va spento, Kubernetes lo toglie dal Service e intanto aspetta, così
  le richieste già instradate verso di lui trovano ancora la porta aperta
- il gestore di SIGTERM in `app.py`: il processo con PID 1 in un container **ignora** SIGTERM se non lo gestisce, e
  Kubernetes dovrebbe aspettare tutto il `terminationGracePeriodSeconds` prima di ucciderlo con SIGKILL

## 4. Un rollout che va male
```bash
kubectl set image deploy/mia-app app=mia-app:9.9       # un tag che non esiste
kubectl rollout status deploy/mia-app --timeout=30s    # error: timed out waiting for the condition (exit 1)
kubectl get pods                         # un Pod ImagePullBackOff, i 3 vecchi Running
curl localhost:30083                     # il servizio funziona ancora
```
Il Pod nuovo non diventa mai pronto, quindi per `maxUnavailable: 0` nessun Pod vecchio viene fermato: il danno è zero.
In una pipeline `rollout status` fallisce e fa fallire il deploy. Si torna indietro:
```bash
kubectl rollout undo deploy/mia-app
```
Senza intervento, dopo `progressDeadlineSeconds` (10 minuti) il Deployment segna la condizione `Progressing=False`,
ma non torna indietro da solo.

## 5. Risorse
```bash
kubectl describe node lab-worker | grep -A8 "Allocated resources"  # somma delle requests dei Pod sul nodo
```
Ogni replica **chiede** 50 millicore e 32 Mi (`requests`: lo scheduler li riserva) e non può superare 250 millicore e
64 Mi (`limits`). Sopra il limite di CPU il processo viene rallentato; sopra quello di memoria viene ucciso e il Pod mostra
`OOMKilled`. Il `securityContext` aggiunge: niente root (`runAsNonRoot`, e l'immagine usa `USER 1000`), filesystem in sola
lettura, nessuna capability di Linux.

## 6. Autoscaling
L'HPA legge l'uso di CPU da **metrics-server**, che kind non ha. Si installa, e siccome i kubelet di kind usano
certificati auto-firmati gli si dice di non verificarli (solo in laboratorio):
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deployment/metrics-server
kubectl top pods                         # dopo un minuto: CPU e memoria di ogni Pod
```
Poi l'HPA e un Pod che genera carico chiamando `/cpu` (0,2 secondi di calcolo a richiesta) senza sosta:
```bash
kubectl apply -f hpa.yaml
kubectl run carico --image=busybox:1.37 --restart=Never -- \
    /bin/sh -c "while true; do wget -q -O- http://mia-app/cpu >/dev/null; done"
kubectl get hpa mia-app -w
```
```
cpu: 2%/50%     3 8 3
cpu: 193%/50%   3 8 3
cpu: 194%/50%   3 8 6
cpu: 144%/50%   3 8 8
cpu: 73%/50%    3 8 8
```
La percentuale è rispetto alle **requests** (50m): al 193% l'HPA calcola `3 × 193 / 50 ≈ 12` repliche, limitate a
`maxReplicas: 8`. Ci arriva a gradini (qui 3, 6, 8): l'HPA ricalcola ogni 15 secondi e limita quanto si può crescere
a ogni passo (si configura nel campo `behavior`).
Tolto il carico, l'HPA aspetta 5 minuti di CPU bassa prima di scendere, per non oscillare:
```bash
kubectl delete pod carico
kubectl get hpa mia-app -w               # dopo circa 5 minuti torna a 3
```
Mentre c'è l'HPA, `replicas` lo decide lui: un `kubectl apply` del Deployment lo riporterebbe a 3 per un momento.
Per questo con l'HPA si toglie `replicas` dal file del Deployment.

## Smontare
```bash
kubectl delete -f .                      # Deployment, Service e HPA (metrics-server resta, serve a kubectl top)
```

Torna a [../](../)
