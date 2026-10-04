# 01 - Deployment e Service

Tre repliche di nginx dietro un Service: il laboratorio di base per vedere come Kubernetes mantiene lo stato desiderato.

| File | Contenuto |
|---|---|
| [deployment.yaml](deployment.yaml) | Deployment `web`: 3 repliche di `nginx:1.26-alpine`, strategia di aggiornamento, readiness probe |
| [service.yaml](service.yaml) | Service `web` di tipo NodePort sulla porta 30080 |
| [nginx-config.yaml](nginx-config.yaml) | ConfigMap con la configurazione di nginx: ogni risposta dice quale Pod l'ha servita |

Serve il cluster del laboratorio: `kind create cluster --config ../kind-cluster.yaml`. I comandi vanno lanciati in questa cartella.

## 1. Creare tutto
```bash
kubectl apply -f .                       # tutti i file della cartella, nell'ordine che serve
kubectl rollout status deploy/web        # aspetta che le 3 repliche siano pronte
kubectl get deploy,rs,pods,svc -o wide
```
Si vede la catena: il **Deployment** `web` ha creato un **ReplicaSet** (`web-5d9f98888b`, il suffisso è l'impronta del
template) che ha creato tre **Pod** (`web-5d9f98888b-4l6ql`...), distribuiti sui due worker. Ogni Pod ha il suo IP
(`10.244.x.x`), il Service ne ha uno virtuale e stabile (`10.96.x.x`) più la porta `80:30080`.

## 2. Il bilanciamento
```bash
for i in $(seq 30); do curl -s localhost:30080; done | sort | uniq -c
```
```
     10 pod web-5d9f98888b-4l6ql - nginx 1.26.3
      8 pod web-5d9f98888b-4v68n - nginx 1.26.3
     12 pod web-5d9f98888b-gjssw - nginx 1.26.3
```
Il percorso: `localhost:30080` → porta 30080 del container `lab-control-plane` (la mappa `kind-cluster.yaml`) → kube-proxy,
che sceglie a caso uno dei Pod **pronti**, su qualunque nodo sia. La scelta è per connessione: con poche richieste può
capitare di vedere sempre lo stesso Pod.

Dall'interno del cluster il Service si raggiunge per nome, grazie al DNS:
```bash
kubectl run tmp --rm -i --restart=Never --image=busybox:1.37 -- wget -qO- http://web
kubectl get endpointslices -l kubernetes.io/service-name=web   # gli IP dei Pod dietro al Service
```
Senza NodePort, dal PC si arriva a un Service con `kubectl port-forward svc/web 8080:80` (poi http://localhost:8080).

## 3. Self-healing
```bash
kubectl delete pod web-5d9f98888b-4l6ql  # (il nome di uno dei Pod)
kubectl get pods                         # uno Terminating e uno nuovo già in ContainerCreating
```
Il ReplicaSet vede 2 Pod invece di 3 e ne crea subito un altro: nessuno lo ha chiesto, è lo stato desiderato.

Se si ferma un nodo intero (`docker stop lab-worker`) è più lento: il nodo diventa `NotReady` in meno di un minuto, ma i
suoi Pod vengono ricreati altrove solo dopo 5 minuti, la tolleranza di default per un nodo irraggiungibile (si vede in
`kubectl get pod NOME -o yaml`, sotto `tolerations`: `tolerationSeconds: 300`). Un nodo che sparisce per un attimo non
fa spostare tutto. `docker start lab-worker` lo rimette in servizio.

## 4. Scalare
```bash
kubectl scale deploy web --replicas=5
kubectl get pods -o wide                 # 5 Pod, divisi fra lab-worker e lab-worker2
kubectl apply -f .                       # torna a 3: il file dice replicas: 3
```
`scale` è **imperativo**: modifica il cluster ma non il file, e il prossimo `apply` riporta tutto a quello che dice il file.
Per rendere la modifica permanente si cambia `replicas` in `deployment.yaml`.

## 5. Rolling update
In un secondo terminale, una richiesta ogni quarto di secondo:
```bash
while true; do curl -s -m 1 localhost:30080 || echo ERRORE; sleep 0.25; done
```
Nel primo, l'aggiornamento a nginx 1.27:
```bash
kubectl annotate deploy web kubernetes.io/change-cause="nginx 1.26"          # nota per la revisione attuale
kubectl set image deploy/web nginx=nginx:1.27-alpine                          # container=immagine
kubectl annotate deploy web kubernetes.io/change-cause="nginx 1.27" --overwrite
kubectl rollout status deploy/web
kubectl get rs                           # il ReplicaSet nuovo ha 3 Pod, quello vecchio 0 (resta per il rollback)
```
Il Deployment crea un secondo ReplicaSet e sposta i Pod dal vecchio al nuovo uno alla volta, come dice la strategia:
`maxSurge: 1` (al massimo 4 Pod insieme), `maxUnavailable: 0` (mai meno di 3 pronti). Un Pod nuovo riceve traffico solo
quando la readiness probe risponde. Nel secondo terminale le risposte passano da `nginx 1.26.3` a `nginx 1.27.5`.

Può comparire un `ERRORE` isolato mentre un Pod vecchio si spegne: viene tolto dal Service e fermato *nello stesso momento*,
e per un istante riceve ancora richieste. In [../04-app-propria/](../04-app-propria/) la soluzione (`preStop`), con zero errori.

## 6. Storia e rollback
```bash
kubectl rollout history deploy/web
```
```
REVISION  CHANGE-CAUSE
1         nginx 1.26
2         nginx 1.27
```
```bash
kubectl rollout undo deploy/web          # torna a 1.26 (la revisione 1 diventa la 3)
curl -s localhost:30080
```
`rollout undo` avvisa che l'annotazione di `kubectl apply` non viene aggiornata: è pensato per le emergenze. Nel flusso
normale si corregge il file (in git) e si rilancia `apply`.

## 7. Il modo dichiarativo
Si cambia il file, si guarda la differenza, si applica:
```bash
sed -i 's/replicas: 3/replicas: 4/' deployment.yaml
kubectl diff -f .                        # le righe che cambierebbero; exit 1 se ci sono differenze, 0 se no
kubectl apply -f .
git checkout deployment.yaml             # rimette il file com'era
```
`kubectl diff` su Windows ha bisogno di un programma `diff` nel `PATH` (Git Bash ce l'ha).

## Smontare
```bash
kubectl delete -f .
```

Torna a [../](../)
