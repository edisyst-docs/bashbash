# Kubernetes

Orchestratore di container: come [Swarm](../05-swarm/swarm.md) gestisce container su più macchine come un'unica
risorsa, ma è lo standard di fatto (ogni cloud lo offre già pronto: EKS, GKE, AKS) e ha molti più oggetti e opzioni.
Si lavora in modo **dichiarativo**: si descrive in YAML lo stato desiderato ("3 repliche di nginx:1.27 dietro la porta 80")
e i **controller** di Kubernetes confrontano di continuo lo stato reale con quello desiderato e correggono le differenze.
Muore un Pod? Ne creano un altro. Cambia l'immagine nel file? Sostituiscono i Pod pochi alla volta.

- **cluster**: un insieme di **nodi** (le macchine) coordinati da un **control plane**
- **Pod**: l'unità minima, uno o più container che condividono rete (stesso IP, si parlano su `localhost`) e volumi.
  È usa e getta: quando muore non risorge, ne nasce un altro con un altro nome e un altro IP
- **Deployment**: mantiene N copie (repliche) di un Pod e ne gestisce gli aggiornamenti
- **Service**: un nome DNS e un IP stabili davanti a un gruppo di Pod, con bilanciamento fra loro
- **namespace**: una cartella logica per separare gli oggetti (per progetto, per ambiente, per team)
- **label**: coppie `chiave=valore` sugli oggetti; i **selector** le usano per collegarli (un Service trova i suoi Pod per label)
- **kubectl**: la CLI, un client dell'API del cluster

Documentazione: https://kubernetes.io/docs/ · kubectl: https://kubernetes.io/docs/reference/kubectl/quick-reference/ ·
kind: https://kind.sigs.k8s.io/

Da Docker e Swarm a Kubernetes:

| Docker / Swarm | Kubernetes |
|---|---|
| container | container dentro un **Pod** |
| `docker service create --replicas 3` | **Deployment** con `replicas: 3` |
| porta pubblicata, routing mesh | **Service** (ClusterIP, NodePort, LoadBalancer), **Ingress**, **Gateway** |
| DNS interno con il nome del servizio | DNS `servizio.namespace.svc.cluster.local` |
| volume con nome | **PersistentVolumeClaim** |
| `-e`, `--env-file` | **ConfigMap** |
| `docker secret` | **Secret** |
| `HEALTHCHECK` | **probe**: liveness, readiness, startup |
| `docker stack deploy -c stack.yaml` | `kubectl apply -f cartella/`, Kustomize, Helm |
| manager e worker | control plane e nodi worker |

## Architettura
```
  kubectl ──HTTPS──> kube-apiserver ────> etcd (lo stato del cluster)
                       ▲         ▲
        kube-scheduler ┘         └ kube-controller-manager
        (sceglie il nodo)          (Deployment, ReplicaSet, Job, nodi...)
 ───────────────────────────────────────────────────────────────────────────
  nodo 1: kubelet + kube-proxy + containerd     nodo 2: kubelet + kube-proxy + containerd
```
- **kube-apiserver**: l'unica porta d'ingresso. kubectl, nodi e controller passano tutti da lui, via API REST
- **etcd**: il database chiave-valore con lo stato del cluster. È la cosa di cui fare il backup
- **kube-scheduler**: decide su quale nodo va ogni Pod nuovo (risorse libere, vincoli, affinità)
- **kube-controller-manager**: i cicli di controllo che riconciliano stato desiderato e stato reale
- su ogni nodo: il **kubelet** avvia i container dei Pod assegnati al nodo e ne riporta lo stato; **kube-proxy** scrive
  le regole di rete dei Service; il **container runtime** (containerd) fa girare i container. Docker come runtime non si
  usa più dalla 1.24, ma le immagini costruite con `docker build` funzionano uguali: sono immagini OCI

## Un cluster in locale
| Strumento | Come funziona | Quando |
|---|---|---|
| **kind** | ogni nodo è un container Docker | laboratori e CI: più nodi, si crea e si distrugge in un minuto. **Usato qui** |
| Docker Desktop | *Settings > Kubernetes > Enable Kubernetes* | è già installato, basta un clic |
| minikube | una VM o un container, con addon pronti (ingress, dashboard, metrics) | alternativa molto diffusa |
| k3d / k3s | k3s è una distribuzione leggera, usata anche in produzione su macchine piccole | Raspberry, edge |

```bash
winget install Kubernetes.kind         # Windows; kubectl arriva con Docker Desktop (altrimenti: winget install Kubernetes.kubectl)
brew install kind kubectl              # macOS
# Linux: binari singoli
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64 && sudo install kind /usr/local/bin/
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install kubectl /usr/local/bin/
kind version && kubectl version --client
```

Il cluster dei laboratori è descritto in [kind-cluster.yaml](kind-cluster.yaml): un control plane, due worker, e le
porte 30080-30085 dei nodi portate su `localhost` (servono ai Service NodePort).
```bash
kind create cluster --config kind-cluster.yaml   # circa un minuto; crea anche il contesto kubectl "kind-lab"
kind get clusters
kubectl cluster-info                             # indirizzo dell'API server
kubectl get nodes -o wide                        # i tre nodi con versione, IP, runtime
docker ps                                        # ...che sono container: lab-control-plane, lab-worker, lab-worker2
kind load docker-image mia-app:1.0 --name lab    # copia un'immagine locale nei nodi: non vedono le immagini di Docker
kind delete cluster --name lab                   # elimina tutto
```

### kubeconfig e contesti
kubectl legge indirizzo del cluster e credenziali da `~/.kube/config` (o dai file elencati nella variabile `KUBECONFIG`).
Un **contesto** è la terna cluster + utente + namespace di default: kind aggiunge `kind-lab` e lo rende attivo.
```bash
kubectl config get-contexts                      # tutti i contesti; * = quello attivo
kubectl config current-context
kubectl config use-context docker-desktop        # passare a un altro cluster
kubectl config set-context --current --namespace=wordpress # namespace di default del contesto attivo
kubectl --context kind-lab get pods              # un solo comando su un altro contesto
```
> **ATTENZIONE**: con più cluster configurati (laboratorio e produzione) controllare sempre il contesto attivo prima di
> `apply` e `delete`. Molti lo mettono nel prompt (`PS1`, vedi [../../01-basi/09-file-di-avvio.md](../../01-basi/09-file-di-avvio.md)).

## I manifest YAML
Ogni oggetto ha le stesse quattro parti:
```yaml
apiVersion: apps/v1          # gruppo/versione dell'API; solo "v1" per gli oggetti di base (Pod, Service, ConfigMap)
kind: Deployment             # il tipo di oggetto
metadata:
  name: web                  # unico per tipo all'interno del namespace
  namespace: default
  labels:                    # etichette: servono a selezionare
    app: web
  annotations:               # note libere, per strumenti e persone
    kubernetes.io/change-cause: "nginx 1.27"
spec:                        # lo stato DESIDERATO: lo scrivo io
  replicas: 3
status: {}                   # lo stato REALE: lo scrive Kubernetes, nei file non si mette
```
- più oggetti nello stesso file, separati da `---`
- `kubectl explain deployment.spec.strategy` documenta ogni campo, dal terminale
- non si parte da un foglio bianco: `--dry-run=client -o yaml` stampa lo scheletro senza creare niente

```bash
kubectl create deployment web --image=nginx:1.27-alpine --replicas=3 --port=80 --dry-run=client -o yaml > deployment.yaml
kubectl expose deployment web --port=80 --type=NodePort --dry-run=client -o yaml > service.yaml # (il Deployment deve esistere)
kubectl create configmap cfg --from-literal=AMBIENTE=prod --from-file=nginx.conf --dry-run=client -o yaml
kubectl create secret generic db --from-literal=PASSWORD=segreta --dry-run=client -o yaml
kubectl create job prova --image=busybox:1.37 --dry-run=client -o yaml -- echo ciao
kubectl create cronjob notte --image=busybox:1.37 --schedule="0 3 * * *" --dry-run=client -o yaml -- date
```

### Imperativo o dichiarativo
| Imperativo: un comando, una modifica | Dichiarativo: il file è la verità |
|---|---|
| `kubectl create`, `scale`, `set image`, `edit`, `rollout undo` | `kubectl apply -f` |
| comodo per provare e nelle emergenze | ripetibile, versionato in git, rivedibile in una pull request |
| il file non ne sa niente: al prossimo `apply` si torna a quello che dice il file | `kubectl diff -f` mostra cosa cambierebbe, prima di farlo |

## kubectl: i comandi
Nomi di tipo abbreviati: `po` pod, `deploy`, `rs`, `sts` statefulset, `svc`, `cm` configmap, `ns` namespace, `pvc`,
`no` node (`kubectl api-resources` li elenca tutti). Un oggetto si indica con `tipo/nome` o `tipo nome`.
```bash
# leggere
kubectl get pods                                  # Pod del namespace corrente
kubectl get pods -o wide                          # + IP e nodo di ciascuno
kubectl get pods -A                               # di tutti i namespace (--all-namespaces)
kubectl get pods -n kube-system                   # di un namespace preciso
kubectl get pods -l app=web                       # solo quelli con la label (-l app!=web, -l 'app in (web,api)')
kubectl get pods --show-labels
kubectl get pods -w                               # resta in ascolto e stampa ogni cambiamento (CTRL+C per uscire)
kubectl get deploy,rs,pods,svc                    # più tipi insieme
kubectl get all                                   # i tipi più comuni (non tutti: mancano ConfigMap, Secret, PVC...)
kubectl get pod web-5d9f98888b-4l6ql -o yaml      # l'oggetto completo, status compreso
kubectl get pods -o name                          # pod/nome, uno per riga: comodo nei cicli for
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
kubectl get pods -o custom-columns=NOME:.metadata.name,NODO:.spec.nodeName,IP:.status.podIP
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl describe pod web-5d9f98888b-4l6ql         # dettagli leggibili + EVENTI in fondo: la prima cosa da guardare
kubectl describe node lab-worker                  # risorse allocate e Pod del nodo
kubectl events --for deployment/web               # solo gli eventi di un oggetto
kubectl get events -A --sort-by=.lastTimestamp    # gli ultimi eventi del cluster
kubectl explain pod.spec.containers.resources     # documentazione di un campo
kubectl api-resources                             # tutti i tipi, con abbreviazione e gruppo API

# log e shell
kubectl logs web-5d9f98888b-4l6ql                 # stdout/stderr del container
kubectl logs -f --tail=50 deploy/web              # di un Pod del Deployment, in diretta
kubectl logs -l app=web --prefix                  # di tutti i Pod con la label, ogni riga con il nome del Pod
kubectl logs web-5d9f98888b-4l6ql --previous      # del container PRIMA dell'ultimo riavvio: perché è andato in crash
kubectl logs web-5d9f98888b-4l6ql -c nginx        # di un container preciso, se il Pod ne ha più di uno
kubectl exec -it deploy/web -- sh                 # shell in un Pod; "--" separa le opzioni di kubectl dal comando
kubectl exec deploy/web -- nginx -v               # un singolo comando
kubectl cp file.txt web-5d9f98888b-4l6ql:/tmp/    # copia nel Pod (serve tar nell'immagine); su Windows solo percorsi relativi
kubectl port-forward svc/web 8080:80              # localhost:8080 -> Service web:80, finché il comando resta aperto
kubectl port-forward pod/mysql-0 3306:3306        # anche verso un Pod: per collegare HeidiSQL o DBeaver
kubectl run tmp --rm -it --image=busybox:1.37 --restart=Never -- sh   # Pod usa e getta per provare rete e DNS da dentro
kubectl debug -it web-5d9f98888b-4l6ql --image=busybox:1.37 --target=nginx # container di debug nel Pod: vede i processi di nginx

# creare, modificare, cancellare
kubectl apply -f deployment.yaml                  # crea o aggiorna
kubectl apply -f cartella/                        # tutti i .yaml della cartella
kubectl apply -k cartella/                        # con Kustomize (kustomization.yaml)
kubectl diff -f cartella/                         # cosa cambierebbe: exit 1 se ci sono differenze, 0 se no
kubectl delete -f cartella/                       # cancella quello che i file descrivono
kubectl delete pod web-5d9f98888b-4l6ql           # il Deployment ne ricrea subito un altro
kubectl delete deploy web                         # Deployment, e a cascata ReplicaSet e Pod
kubectl edit deploy web                           # apre l'oggetto nell'editor ($KUBE_EDITOR o $EDITOR): salvando si applica
kubectl label pod web-5d9f98888b-4l6ql tier=frontend # aggiunge una label; "tier-" la toglie
kubectl annotate deploy web kubernetes.io/change-cause="nginx 1.27" # la nota che compare in rollout history

# deployment
kubectl scale deploy web --replicas=5
kubectl set image deploy/web nginx=nginx:1.27-alpine  # container=immagine: parte un rolling update
kubectl rollout status deploy/web                 # aspetta la fine dell'aggiornamento (exit 1 se fallisce o va in timeout)
kubectl rollout history deploy/web                # le revisioni
kubectl rollout undo deploy/web                   # torna alla revisione precedente
kubectl rollout undo deploy/web --to-revision=2
kubectl rollout restart deploy/web                # ricrea i Pod a rotazione (es. per rileggere le variabili di una ConfigMap)
kubectl wait --for=condition=Ready pod -l app=web --timeout=60s # negli script: aspetta una condizione

# nodi e permessi
kubectl top nodes                                 # CPU e RAM in uso (serve metrics-server, vedi 04-app-propria)
kubectl top pods -A --sort-by=memory
kubectl cordon lab-worker                         # niente nuovi Pod sul nodo
kubectl drain lab-worker --ignore-daemonsets --delete-emptydir-data # sposta altrove i Pod: si può spegnere il nodo
kubectl uncordon lab-worker                       # il nodo torna disponibile
kubectl auth can-i delete pods                    # posso farlo? (RBAC)
kubectl auth can-i list secrets --as=system:serviceaccount:default:ci # ...e un altro utente?
```
Per scrivere meno, in `~/.bashrc`:
```bash
alias k=kubectl
source <(kubectl completion bash)                 # completamento con TAB di comandi, tipi e nomi degli oggetti
complete -o default -F __start_kubectl k          # anche per l'alias
```

## Workload: chi fa girare i Pod
I Pod non si creano quasi mai a mano: li crea un controller, che li ricrea quando muoiono.

| Oggetto | Cosa garantisce | Esempio |
|---|---|---|
| **Deployment** | N repliche intercambiabili, aggiornamenti a rotazione, rollback | web server, API ([01](01-deployment/), [04](04-app-propria/)) |
| ReplicaSet | N repliche identiche. Lo crea il Deployment, uno per ogni versione | non si scrive a mano |
| **StatefulSet** | repliche con nome stabile (`mysql-0`, `mysql-1`), avvio in ordine, un volume per replica | database ([03](03-wordpress-mysql/)) |
| **DaemonSet** | un Pod su ogni nodo | agenti di log e monitoraggio, kube-proxy |
| **Job** | un lavoro eseguito fino al completamento, con ritentativi | import, migrazioni, elaborazioni ([05](05-job-cronjob/)) |
| **CronJob** | un Job a orari fissi | backup notturno ([05](05-job-cronjob/)) |

### Il Pod da vicino
Questi campi valgono ovunque ci sia un Pod: nel `template` di un Deployment, di un Job, di uno StatefulSet.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: prova
  labels:
    app: prova
spec:
  initContainers:                      # partono prima dei container, uno alla volta, e devono finire con successo
    - name: attendi-db
      image: busybox:1.37
      command: ["sh", "-c", "until nc -z -w 2 mysql 3306; do echo attendo mysql; sleep 2; done"]
  containers:
    - name: app
      image: nginx:1.27-alpine
      command: ["nginx"]               # sostituisce l'ENTRYPOINT dell'immagine
      args: ["-g", "daemon off;"]      # sostituisce il CMD
      ports:
        - containerPort: 80            # documentativo, come EXPOSE
      env:
        - name: AMBIENTE
          value: produzione
  restartPolicy: Always                # Always (default), OnFailure, Never: cosa fare quando un container esce
```

Gli stati che si vedono in `kubectl get pods`, e dove guardare:

| Stato | Significato | Dove guardare |
|---|---|---|
| `Pending` | non ancora su un nodo: risorse insufficienti, volume legato a un altro nodo, nodi non disponibili | `describe pod`, evento `FailedScheduling` |
| `ContainerCreating` | immagine in download, volumi in montaggio | `describe pod` |
| `Running` | almeno un container gira; pronto solo se READY è `1/1` | colonna READY |
| `Completed` | i container sono usciti con codice 0 (tipico dei Job) | |
| `CrashLoopBackOff` | il container parte e muore; Kubernetes ritenta aspettando sempre di più (di default fino a 5 minuti) | `logs --previous` |
| `ErrImagePull`, `ImagePullBackOff` | immagine o tag inesistenti, registry privato senza credenziali | `describe pod` |
| `CreateContainerConfigError` | manca una ConfigMap o un Secret citato nel Pod | `describe pod` |
| `OOMKilled` (in *Last State*) | ha superato il limite di memoria ed è stato ucciso | `describe pod`, alzare `limits.memory` |
| `Terminating` | in spegnimento: preStop, poi SIGTERM, dopo il grace period SIGKILL | |

## Service e rete
Ogni Pod ha il suo IP e raggiunge qualunque altro Pod del cluster senza NAT: la rete dei Pod è piatta, la realizza un
plugin CNI (kindnet in kind; Calico, Cilium, Flannel altrove). Gli IP dei Pod però cambiano a ogni ricreazione: davanti
si mette un **Service**, che ha un IP virtuale stabile e un nome DNS e inoltra ai Pod **pronti** che corrispondono al selector.

| Tipo | Raggiungibile da | Uso |
|---|---|---|
| `ClusterIP` (default) | solo dall'interno del cluster | comunicazione fra servizi: app → database |
| `NodePort` | + dall'esterno su `IP-di-un-nodo:30000-32767` | laboratori, bilanciatori esterni propri |
| `LoadBalancer` | + da un bilanciatore del cloud, con un IP pubblico | esporre un servizio in produzione ([06](06-ingress-gateway/)) |
| headless (`clusterIP: None`) | il nome DNS restituisce direttamente gli IP dei Pod | StatefulSet, database ([03](03-wordpress-mysql/)) |
| `ExternalName` | un alias DNS verso un nome esterno | un database gestito fuori dal cluster |

```yaml
  ports:
    - port: 80              # la porta del Service
      targetPort: 8000      # la porta del container (anche per nome: "http")
      nodePort: 30080       # solo NodePort/LoadBalancer; se manca ne viene scelta una libera
```
Il DNS del cluster risolve `web` (stesso namespace), `web.altro-namespace` e il nome completo
`web.altro-namespace.svc.cluster.local`; i Pod di uno StatefulSet hanno anche un nome proprio, `mysql-0.mysql`.
```bash
kubectl get endpointslices -l kubernetes.io/service-name=web  # quali Pod stanno dietro al Service: vuoto = selector sbagliato o Pod non pronti
kubectl run tmp --rm -i --restart=Never --image=busybox:1.37 -- wget -qO- http://web  # provarlo da dentro
```
`kubectl get endpoints` funziona ancora ma è deprecato dalla 1.33: si usano gli EndpointSlice.
Un Service senza Pod pronti rifiuta le connessioni: da fuori si vede un `Connection refused`.

### Ingress e Gateway API
Un **Ingress** è un punto di ingresso HTTP unico per molti Service: smista le richieste per nome host e percorso e
termina l'HTTPS. È solo una regola: a realizzarla serve un **Ingress controller**, che Kubernetes non include
(Traefik, HAProxy, Contour, quelli dei cloud...).
> **NOTA**: ingress-nginx, il controller più usato, è stato ritirato: nessun aggiornamento, neanche di sicurezza, da marzo 2026.
> L'API Ingress resta e altri controller la implementano, ma per i progetti nuovi la strada è la **Gateway API**.

La **Gateway API** (`Gateway` + `HTTPRoute`) è il successore: separa chi gestisce il punto di ingresso da chi scrive le
regole e ha funzioni che Ingress non ha, come la suddivisione del traffico a pesi (rilasci canary) e l'instradamento per header.
Entrambi sono nel laboratorio [06-ingress-gateway/](06-ingress-gateway/).

Una **NetworkPolicy** è il firewall fra i Pod ("solo i Pod app=wordpress possono aprire la 3306 di mysql"): funziona se il
plugin CNI la supporta.

## Configurazione: ConfigMap e Secret
Configurazione fuori dall'immagine: la stessa immagine va in sviluppo e in produzione, cambia solo la ConfigMap.
Laboratorio completo: [02-config/](02-config/).

| Come si usa | Sintassi nel container | Se la ConfigMap cambia |
|---|---|---|
| una chiave come variabile | `env[].valueFrom.configMapKeyRef` | niente, fino al riavvio del Pod |
| tutte le chiavi come variabili | `envFrom[].configMapRef` | niente, fino al riavvio del Pod |
| ogni chiave come file | `volumes[].configMap` + `volumeMounts` | il file si aggiorna da solo in circa un minuto (non con `subPath`) |

I **Secret** si usano allo stesso modo (`secretKeyRef`, `secretRef`, `volumes[].secret`).
> **ATTENZIONE**: un Secret è solo codificato in base64, non cifrato: chi può leggerlo con kubectl vede la password
> (`kubectl get secret db -o jsonpath='{.data.PASSWORD}' | base64 -d`). Protezioni vere: permessi RBAC stretti,
> cifratura di etcd, e in git mai i Secret in chiaro (Sealed Secrets, SOPS, External Secrets con Vault o i secret manager dei cloud).

Tipi di Secret con un comando dedicato:
```bash
kubectl create secret tls sito-tls --cert=cert.pem --key=chiave.pem       # certificato per Ingress/Gateway HTTPS
kubectl create secret docker-registry registro --docker-server=ghcr.io \
    --docker-username=utente --docker-password="$TOKEN"                   # per immagini private...
# ...che il Pod usa con: spec.imagePullSecrets: [{name: registro}]
```

## Storage
Il filesystem di un container sparisce con lui. I volumi si dichiarano nel Pod (`volumes`) e si montano nei container (`volumeMounts`):

| Volume | Vita | Uso |
|---|---|---|
| `emptyDir` | quella del Pod | file temporanei condivisi fra i container dello stesso Pod |
| `configMap`, `secret` | quella dell'oggetto | file di configurazione |
| `hostPath` | quella del nodo | una cartella del nodo: da evitare, lega il Pod alla macchina |
| `persistentVolumeClaim` | indipendente dal Pod | dati da conservare: database, upload |

- **PersistentVolumeClaim** (PVC): la richiesta, "mi serve 1 Gi scrivibile"
- **PersistentVolume** (PV): il disco vero che soddisfa la richiesta
- **StorageClass**: come creare i PV al volo (tipo di disco del cloud). kind ha `standard`, una cartella sul nodo

Modi di accesso: `ReadWriteOnce` (un nodo alla volta, il caso comune), `ReadOnlyMany`, `ReadWriteMany` (più nodi insieme:
serve uno storage di rete, NFS o i file system dei cloud), `ReadWriteOncePod`.
```bash
kubectl get storageclass
kubectl get pvc,pv                                # la richiesta, il volume che la soddisfa e il loro legame
```
Con la `reclaimPolicy: Delete` (il default dei volumi creati al volo) cancellare la PVC cancella anche i dati.
Un volume locale lega il Pod al suo nodo: se il nodo non c'è, il Pod resta `Pending` (vedi [03-wordpress-mysql/](03-wordpress-mysql/)).

## Probe, risorse e spegnimento
Esempio completo in [04-app-propria/](04-app-propria/).

| Probe | Se fallisce | A cosa serve |
|---|---|---|
| `startupProbe` | riavvia il container; finché non passa, le altre due aspettano | applicazioni lente ad avviarsi |
| `readinessProbe` | toglie il Pod dal Service, **senza** riavviarlo | niente traffico finché non è pronto, o se ha perso una dipendenza |
| `livenessProbe` | riavvia il container | processo bloccato che non si riprende da solo |

Tipi: `httpGet` (successo = codice 200-399), `tcpSocket`, `exec` (successo = exit 0), `grpc`. Parametri: `initialDelaySeconds`,
`periodSeconds` (10), `timeoutSeconds` (1), `failureThreshold` (3).
> **ATTENZIONE**: la liveness non deve dipendere dal database. Se il DB è giù, riavviare l'applicazione non lo aggiusta e
> manda in crash a catena tutte le repliche: quello è compito della readiness.

**Risorse**, per ogni container:
- `requests`: quanto lo scheduler riserva sul nodo. Un Pod che chiede più di quanto è libero resta `Pending`
- `limits`: il tetto. Oltre il limite di CPU il container viene rallentato; oltre quello di memoria viene ucciso (`OOMKilled`)
- unità: CPU in core (`500m` = mezzo core), memoria in `Mi`/`Gi`
- classi di QoS: `Guaranteed` (requests = limits), `Burstable`, `BestEffort` (niente: i primi a essere sfrattati se il nodo è pieno)

**Spegnimento di un Pod** (aggiornamento, scale down, drain):
1. il Pod passa a `Terminating` e **in parallelo** viene tolto dagli EndpointSlice dei Service
2. parte l'hook `preStop`, se c'è
3. il processo principale (PID 1) riceve SIGTERM
4. dopo `terminationGracePeriodSeconds` (30 s) arriva SIGKILL

Siccome 1 e 3 avvengono insieme, per qualche istante il Pod può ricevere richieste già chiuso: un `preStop` che aspetta
qualche secondo le evita. E il PID 1 di un container ignora SIGTERM se non lo gestisce esplicitamente: senza gestore,
il container aspetta sempre tutto il grace period e poi viene ucciso.

**Autoscaling**: un HorizontalPodAutoscaler aggiunge e toglie repliche seguendo CPU o memoria (in % delle requests).
Serve metrics-server. Sale in fretta, scende con prudenza: aspetta 5 minuti di carico basso.
```bash
kubectl autoscale deploy mia-app --min=3 --max=8 --cpu=50%   # UGUALE a hpa.yaml di 04-app-propria
kubectl get hpa -w
```

## Namespace e permessi
Namespace sempre presenti: `default`, `kube-system` (i componenti del cluster), `kube-public`, `kube-node-lease`.
```bash
kubectl create namespace prova
kubectl get ns
kubectl delete namespace prova                   # ATTENZIONE: cancella TUTTO quello che contiene, volumi compresi
```
Una **ResourceQuota** limita quanto può consumare un namespace (CPU, memoria, numero di oggetti); una **LimitRange**
assegna requests e limits di default ai container che non li dichiarano.

**RBAC**: ogni Pod gira con un'identità, un **ServiceAccount** (di default `default`). I permessi sono **Role** (verbi sui
tipi di oggetto, in un namespace) o **ClusterRole** (in tutto il cluster), assegnati con **RoleBinding** o **ClusterRoleBinding**.
Esempio: un account per la CI che può solo leggere Pod e log.
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: lettore-pod
rules:
  - apiGroups: [""]                    # "" = il gruppo di base (Pod, Service, ConfigMap...)
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-legge-pod
subjects:
  - kind: ServiceAccount
    name: ci
    namespace: default
roleRef:
  kind: Role
  name: lettore-pod
  apiGroup: rbac.authorization.k8s.io
```
```bash
kubectl auth can-i list pods --as=system:serviceaccount:default:ci    # yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:ci  # no
kubectl create token ci --duration=1h                                 # un token temporaneo per usarlo da fuori (es. da Jenkins)
```

## Kustomize e Helm
Due modi di gestire gli stessi manifest in più ambienti (sviluppo, produzione) senza copiarli.

**Kustomize** è dentro kubectl (`apply -k`) e non usa template: parte da file YAML normali (la *base*) e li modifica con
*overlay*. Il laboratorio [03-wordpress-mysql/](03-wordpress-mysql/) lo usa per namespace e Secret. Struttura tipica:
```
base/                  deployment.yaml  service.yaml  kustomization.yaml (resources: [deployment.yaml, service.yaml])
overlays/produzione/   kustomization.yaml
```
```yaml
# overlays/produzione/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: produzione
namePrefix: prod-                      # prod-web; anche i riferimenti fra oggetti vengono aggiornati
replicas:
  - name: web
    count: 5
images:
  - name: nginx                        # ovunque ci sia l'immagine nginx...
    newTag: 1.27-alpine                # ...cambia il tag
labels:
  - pairs:
      ambiente: produzione
```
```bash
kubectl kustomize overlays/produzione  # stampa il risultato senza applicarlo
kubectl apply -k overlays/produzione
```

**Helm** è il gestore di pacchetti: un **chart** è un pacchetto di template con dei valori di default; installarlo crea una
**release**, di cui Helm tiene la storia per gli aggiornamenti e i rollback. È il modo standard per installare software
di terzi (database, monitoraggio, controller). Chart scritto a mano e comandi in [07-helm/](07-helm/).

## Risolvere i problemi
| Sintomo | Comando | Causa tipica |
|---|---|---|
| il Pod non parte | `kubectl describe pod NOME` (eventi in fondo) | immagine sbagliata, risorse insufficienti, ConfigMap o Secret mancanti |
| `CrashLoopBackOff` | `kubectl logs NOME --previous` | errore dell'applicazione all'avvio, variabile mancante, liveness troppo severa |
| il Service non risponde | `kubectl get endpointslices -l kubernetes.io/service-name=SVC` | selector che non corrisponde alle label, Pod non pronti, `targetPort` sbagliata |
| il nome non si risolve | `kubectl run tmp --rm -it --image=busybox:1.37 --restart=Never -- nslookup SVC` | namespace diverso: serve `svc.namespace` |
| il rollout non finisce | `kubectl rollout status deploy/X`, `kubectl get pods` | la nuova versione non diventa pronta: `kubectl rollout undo` |
| `Pending` per sempre | `kubectl describe pod NOME` → `FailedScheduling` | requests troppo alte, PVC non soddisfatta, nodo del volume non disponibile |
| `OOMKilled` | `kubectl describe pod NOME` → *Last State* | limite di memoria troppo basso, o una perdita di memoria |

## Laboratori
Prima di tutto il cluster: `kind create cluster --config kind-cluster.yaml`. Ogni laboratorio ha il suo README con i passi
e la spiegazione di quello che succede; si possono tenere attivi tutti insieme, usano porte diverse.

| Cartella | Cosa mostra | Porta |
|---|---|---|
| [01-deployment/](01-deployment/) | Deployment e Service: bilanciamento, self-healing, scalare, rolling update, rollback | 30080 |
| [02-config/](02-config/) | ConfigMap e Secret come variabili e come file; cosa si aggiorna da solo e cosa no | 30081 |
| [03-wordpress-mysql/](03-wordpress-mysql/) | StatefulSet con volume persistente, Secret generati da Kustomize, repliche e cookie | 30082 |
| [04-app-propria/](04-app-propria/) | la propria immagine nel cluster, probe, risorse, rolling update senza errori, autoscaling | 30083 |
| [05-job-cronjob/](05-job-cronjob/) | Job paralleli con indice e CronJob, con script bash in una ConfigMap | — |
| [06-ingress-gateway/](06-ingress-gateway/) | LoadBalancer, Ingress e Gateway API con cloud-provider-kind; rilascio canary | 8088, variabile |
| [07-helm/](07-helm/) | un chart scritto a mano, release dev e prod, upgrade e rollback, un chart pubblico | 30084, 30085 |

Alla fine: `kind delete cluster --name lab` elimina il cluster e tutto quello che contiene.
