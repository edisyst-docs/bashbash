# Argo CD

Argo CD fa il **deploy continuo con GitOps**: un repository git descrive cosa deve girare nel cluster, e un
controller *dentro* il cluster lo confronta di continuo con quello che gira davvero e lo riallinea. Nessuna pipeline
fa `kubectl apply`. La pipeline (Jenkins, GitLab CI) costruisce e pubblica l'immagine, poi cambia un file in git;
il resto lo fa Argo CD.

```
 push (pipeline che fa il deploy)                 pull (GitOps)

 CI ──kubectl apply──> cluster                    CI ──git push──> repo manifest <──git fetch── Argo CD ─┐
 (la CI ha le credenziali del cluster)                                              (nel cluster)  apply │
                                                                                         cluster <───────┘
```

- **Application**: la risorsa (una CRD) che dice "questa cartella di questo repository, a questa revisione, va in
  questo cluster e in questo namespace". È l'unità di Argo CD
- **sorgente**: la cartella in git. Può contenere YAML semplici, un `kustomization.yaml` o un chart Helm: Argo CD
  riconosce il tipo da solo
- **destinazione**: cluster e namespace. Lo stesso Argo CD può gestire molti cluster
- **sync**: applicare al cluster lo stato descritto in git. *Manuale* (pulsante o CLI) o *automatica*
- **sync status**: `Synced` se cluster e git sono uguali, `OutOfSync` se no
- **health status**: lo stato delle risorse (`Healthy`, `Progressing`, `Degraded`, `Missing`...)
- **refresh**: rileggere git e rifare il confronto. Di default ogni 3 minuti circa, subito con un webhook
- **AppProject**: un gruppo di Application, con i limiti su quali repository e quali destinazioni possono usare
- **ApplicationSet**: un modello che genera molte Application (una per ambiente, per cluster, per cartella)

I principi di GitOps (https://opengitops.dev): stato desiderato **dichiarativo**, **versionato** in git (storia,
revisione, rollback = `git revert`), **scaricato** dall'agente (*pull*), **riconciliato** di continuo (le modifiche
a mano vengono notate e, se si vuole, annullate).

Documentazione: https://argo-cd.readthedocs.io · riferimento dei campi:
https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/

Versioni del laboratorio: Argo CD 3.5.3, kind 0.33 (Kubernetes 1.37), Gitea 28.0, registry 3.1 (ottobre 2026).

## Architettura

```
                         ┌────────────────────────────── namespace argocd ──────────────────────────────┐
 browser, argocd CLI ───>│ argocd-server        API, interfaccia web, webhook, login                    │
 webhook da git ────────>│      │                                                                       │
                         │      ▼                                                                       │
 repository git <────────│ argocd-repo-server   clona i repository, genera i manifest (kustomize, helm)  │
                         │      ▲                                                                       │
                         │ argocd-application-controller   confronta, sync, health  ───────────────────────> cluster
                         │ argocd-applicationset-controller   genera le Application dagli ApplicationSet│
                         │ argocd-redis   cache        argocd-dex-server   SSO                           │
                         │ argocd-notifications-controller   avvisi su Slack, email, webhook...         │
                         └──────────────────────────────────────────────────────────────────────────────┘
```

| Componente | Cosa fa |
|---|---|
| `argocd-server` | API gRPC e REST, interfaccia web, riceve i webhook. Non tocca il cluster da solo |
| `argocd-repo-server` | clona i repository e genera i manifest finali (`kustomize build`, `helm template`). Non ha credenziali del cluster |
| `argocd-application-controller` | uno StatefulSet: confronta git e cluster, fa le sync, calcola lo stato di salute |
| `argocd-applicationset-controller` | trasforma gli ApplicationSet in Application |
| `argocd-redis` | cache dei manifest generati e dello stato: si può perdere senza danni |
| `argocd-dex-server` | login con GitHub, GitLab, LDAP, OIDC... (facoltativo) |
| `argocd-notifications-controller` | avvisi sugli eventi delle Application (facoltativo) |

Tutta la configurazione sta in risorse Kubernetes nel namespace `argocd`: ConfigMap (`argocd-cm`, `argocd-rbac-cm`,
`argocd-cmd-params-cm`), Secret (`argocd-secret`, i repository) e le CRD `Application`, `ApplicationSet`, `AppProject`.
Quindi anche Argo CD si può descrivere in git.

## Il laboratorio

```
 PC ──git push──> gitea :3001 ──webhook──> argocd-server :30443
  │                  ▲                         │ refresh
  │                  └──git fetch── argocd-repo-server ◄── argocd-application-controller ──apply──┐
  └──docker push──> registry :5001                                                               ▼
                         ▲                                                         cluster kind "argocd"
                         └──────────────────── pull dei nodi (localhost:5001) ◄── sito, mia-app dev/prod, vetrina
```

| File | Contenuto |
|---|---|
| [laboratorio.sh](laboratorio.sh) | `crea`, `stato`, `elimina`: tutto il laboratorio con un comando |
| [kind-argocd.yaml](kind-argocd.yaml) | cluster kind `argocd`: un control plane, un worker, porte 30090-30093 e 30443 su localhost |
| [compose.yaml](compose.yaml) | registry e Gitea sulla rete Docker `kind`, raggiungibili per nome dai Pod |
| [argocd/](argocd/) | Argo CD installato con Kustomize: manifest ufficiali di una versione precisa + due modifiche |
| [repo/](repo/) | il contenuto iniziale del repository `gitops` (vedi la tabella sotto) |
| [applicazioni/](applicazioni/) | le due Application da applicare a mano: `sito.yaml` e `root.yaml` |

Il repository `gitops` su Gitea, che `laboratorio.sh crea` riempie con [repo/](repo/) e con il chart di
[../06-kubernetes/07-helm/sito/](../06-kubernetes/07-helm/sito/):

| Cartella | Tipo | Application | Porta |
|---|---|---|---|
| `sito/` | YAML semplici: nginx con un messaggio | `sito` | http://localhost:30090 |
| `mia-app/base/`, `mia-app/overlays/{dev,prod}/` | Kustomize: l'app di [../06-kubernetes/04-app-propria/](../06-kubernetes/04-app-propria/) | `mia-app-dev`, `mia-app-prod` | :30091, :30092 |
| `chart-sito/` | chart Helm | `chart-sito` (release `vetrina`) | :30093 |
| `apps/` | le Application stesse (app of apps) | `root` | |

```bash
./laboratorio.sh crea          # circa 90 secondi; rilanciabile
./laboratorio.sh stato
./laboratorio.sh elimina       # alla fine: cluster, container, volumi e la cartella gitops/
```
Servono Docker, `kind`, `kubectl`, `argocd`, `git` e `curl`. La CLI `argocd` si scarica dalle release
(https://github.com/argoproj/argo-cd/releases: `argocd-linux-amd64`, `argocd-windows-amd64.exe`...).

| Indirizzo | Cosa | Credenziali |
|---|---|---|
| https://localhost:30443 | Argo CD (certificato autofirmato: accettarlo) | `admin` / `laboratorio` |
| http://localhost:3001 | Gitea, il repository `lab/gitops` | `lab` / `laboratorio` |
| `localhost:5001` | il registry: `docker push localhost:5001/...` | nessuna |

Dentro il cluster il repository si chiama `http://gitea:3000/lab/gitops.git` e il registry `registry:5000`: i
container stanno sulla rete Docker `kind`, la stessa dei nodi, e i Pod risolvono i loro nomi. Per le immagini i nodi
usano lo stesso nome del PC, `localhost:5001`: `laboratorio.sh` scrive in ogni nodo
`/etc/containerd/certs.d/localhost:5001/hosts.toml`, che dice a containerd di andare su `http://registry:5000`
(il metodo documentato da kind, https://kind.sigs.k8s.io/docs/user/local-registry/).

La copia di lavoro del repository è in `gitops/`, fuori dalla KB (è in `.gitignore`): lì si modifica e si fa push.
`kind create cluster` cambia il contesto di `kubectl` in `kind-argocd`; se si usa anche il cluster dei laboratori
di Kubernetes: `kubectl config use-context kind-argocd`.

### 1. La prima Application
[applicazioni/sito.yaml](applicazioni/sito.yaml) dice ad Argo CD: la cartella `sito/` del ramo `main`, nel
namespace `sito` di questo cluster. Senza sync automatica.
```bash
kubectl apply -f applicazioni/sito.yaml
argocd app list
```
```
NAME         CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                              PATH  TARGET
argocd/sito  https://kubernetes.default.svc  sito       default  OutOfSync  Missing  Manual      <none>      http://gitea:3000/lab/gitops.git  sito  main
```
Argo CD ha letto git, ha visto tre risorse che nel cluster non ci sono (`Missing`) e lo segnala (`OutOfSync`).
Non applica niente da solo:
```bash
argocd app get sito
```
```
Sync Policy:        Manual
Sync Status:        OutOfSync from main (e9db2ac)
Health Status:      Missing

GROUP  KIND        NAMESPACE  NAME        STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   sito       sito-nginx  OutOfSync  Missing
       Service     sito       sito        OutOfSync  Missing
apps   Deployment  sito       sito        OutOfSync  Missing
```
Si sincronizza con il pulsante *Sync* nell'interfaccia o dalla CLI:
```bash
argocd app sync sito
argocd app wait sito --health        # aspetta Synced + Healthy
curl localhost:30090                 # sito versione 1 - pod sito-54595bf8b-zp5pp
```
```
GROUP  KIND        NAMESPACE  NAME        STATUS   HEALTH       HOOK  MESSAGE
       Namespace              sito        Running  Synced             namespace/sito created
       ConfigMap   sito       sito-nginx  Synced                      configmap/sito-nginx created
       Service     sito       sito        Synced   Healthy            service/sito created
apps   Deployment  sito       sito        Synced   Progressing        deployment.apps/sito created
```
Il namespace lo crea l'opzione `CreateNamespace=true`. Nell'interfaccia (https://localhost:30443) l'Application
mostra l'albero: Deployment → ReplicaSet → Pod, Service → EndpointSlice, con lo stato di ognuno.

### 2. Git è la fonte di verità
Una modifica si fa in git, non nel cluster:
```bash
cd gitops
sed -i 's/value: "sito versione 1"/value: "sito versione 2"/; s/replicas: 2/replicas: 4/' sito/deployment.yaml
git commit -am "sito: versione 2, quattro repliche" && git push
```
Il push fa partire il webhook di Gitea verso Argo CD: dopo circa un secondo l'app è `OutOfSync`. Cosa cambierebbe:
```bash
argocd app diff sito                 # exit code 1 se ci sono differenze, come diff
```
```
===== apps/Deployment sito/sito ======
132c132
<   replicas: 2
---
>   replicas: 4
150c150
<           value: sito versione 1
---
>           value: sito versione 2
```
In un secondo terminale `while true; do curl -s -m 1 localhost:30090 || echo ERRORE; sleep 0.25; done`, poi
`argocd app sync sito`. Su 60 richieste durante l'aggiornamento: 5 `versione 1`, 55 `versione 2`, nessun errore
(rolling update con readiness probe). La storia delle sync:
```bash
argocd app history sito
```
```
ID      DATE                            REVISION
0       2026-10-03 16:45:08 +0200 CEST  main (e9db2ac)
1       2026-10-03 16:47:27 +0200 CEST  main (07233f8)
```
Il messaggio sta in una variabile d'ambiente del Deployment e non nella ConfigMap per un motivo: cambiare una
ConfigMap non riavvia i Pod, cambiare il template del Pod sì.

### 3. Sync automatica, self-heal e prune
```bash
argocd app set sito --sync-policy automated --self-heal --auto-prune
```
- **automated**: a ogni commit nuovo Argo CD fa la sync da solo
- **self-heal**: se qualcuno cambia il cluster a mano, Argo CD rimette quello che c'è in git
- **prune**: se una risorsa sparisce da git, Argo CD la cancella dal cluster (senza prune la segnala e la lascia)

Self-heal:
```bash
kubectl -n sito scale deploy sito --replicas=1
kubectl -n sito get deploy sito      # dopo un secondo: di nuovo 4/4
kubectl -n sito delete svc sito      # dopo tre secondi il Service c'è di nuovo
```
Dagli eventi dell'Application (`kubectl -n argocd get events --field-selector involvedObject.name=sito`):
```
Normal   OperationStarted     application/sito   Initiated automated sync to '07233f8cb03d1a4ede52c161e296b75bc31c562c'
Normal   ResourceUpdated      application/sito   Updated sync status: Synced -> OutOfSync
Normal   OperationCompleted   application/sito   Partial sync operation to 07233f8cb03d1a4ede52c161e296b75bc31c562c succeeded
Normal   ResourceUpdated      application/sito   Updated sync status: OutOfSync -> Synced
```
Prune: un file nuovo in git crea una risorsa, toglierlo la cancella.
```bash
cat > sito/pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: sito
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: sito
EOF
git add sito/pdb.yaml && git commit -m "sito: PodDisruptionBudget" && git push
kubectl -n sito get pdb                       # sito   2   N/A   2   4s
git rm sito/pdb.yaml && git commit -m "sito: via il PodDisruptionBudget" && git push
kubectl -n sito get pdb                       # No resources found in sito namespace.
argocd app get sito                           # PodDisruptionBudget sito: pruned
```

### 4. Rollback
Un commit sbagliato:
```bash
sed -i 's/value: "sito versione 2"/value: "sito versione 3 (sbagliata)"/' sito/deployment.yaml
git commit -am "sito: versione 3" && git push
curl localhost:30090                          # sito versione 3 (sbagliata) - pod ...
```
Argo CD ha il suo rollback (`argocd app rollback sito <ID>`, pulsante *History and rollback*), ma con la sync
automatica non funziona, e ha senso: git direbbe una cosa e il cluster un'altra, e alla sync successiva il cluster
tornerebbe com'è in git.
```
rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled
```
Il rollback GitOps è un commit che annulla l'altro:
```bash
git revert --no-edit HEAD && git push
curl localhost:30090                          # sito versione 2 - pod sito-766bb56fb7-k8xdx
```
Il ReplicaSet è lo stesso di prima (`766bb56fb7`, l'hash del template del Pod): Kubernetes riusa quello vecchio. In git
restano sia l'errore sia la correzione, con autore e data. `argocd app rollback` serve con la sync manuale, per
un'emergenza: subito dopo l'app è `OutOfSync` finché git non viene allineato.

### 5. Le immagini nel registry
L'app di [../06-kubernetes/04-app-propria/](../06-kubernetes/04-app-propria/), questa volta pubblicata come in un
cluster vero invece di `kind load`:
```bash
docker build -t localhost:5001/mia-app:1.0 ../06-kubernetes/04-app-propria/app/
docker build -t localhost:5001/mia-app:2.0 --build-arg VERSIONE=2.0 ../06-kubernetes/04-app-propria/app/
docker push localhost:5001/mia-app:1.0
docker push localhost:5001/mia-app:2.0
curl localhost:5001/v2/_catalog               # {"repositories":["mia-app"]}
curl localhost:5001/v2/mia-app/tags/list      # {"name":"mia-app","tags":["1.0","2.0"]}
```
I comandi vanno dati dalla cartella del laboratorio (`11-argocd/`), non da `gitops/`.

### 6. App of apps
Finora l'Application `sito` è stata creata con `kubectl apply` e cambiata con `argocd app set`: modifiche fuori
da git. Il passo successivo è mettere in git anche le Application. [applicazioni/root.yaml](applicazioni/root.yaml)
è un'Application che punta alla cartella `apps/` del repository, dove ci sono:

| File | Crea |
|---|---|
| [apps/sito.yaml](repo/apps/sito.yaml) | l'Application `sito`, ora con `automated`, `selfHeal` e `prune` scritti nel file |
| [apps/mia-app.yaml](repo/apps/mia-app.yaml) | un **ApplicationSet**: un'Application per ogni cartella in `mia-app/overlays/` |
| [apps/chart-sito.yaml](repo/apps/chart-sito.yaml) | l'Application `chart-sito`, sorgente Helm con valori propri |

```bash
kubectl apply -f applicazioni/root.yaml       # l'ultimo kubectl apply: d'ora in poi solo git
argocd app list
```
```
NAME                 CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                              PATH                   TARGET
argocd/chart-sito    https://kubernetes.default.svc  vetrina    default  Synced  Healthy  Auto-Prune  <none>      http://gitea:3000/lab/gitops.git  chart-sito             main
argocd/mia-app-dev   https://kubernetes.default.svc  dev        default  Synced  Healthy  Auto-Prune  <none>      http://gitea:3000/lab/gitops.git  mia-app/overlays/dev   main
argocd/mia-app-prod  https://kubernetes.default.svc  prod       default  Synced  Healthy  Auto-Prune  <none>      http://gitea:3000/lab/gitops.git  mia-app/overlays/prod  main
argocd/root          https://kubernetes.default.svc  argocd     default  Synced  Healthy  Auto-Prune  <none>      http://gitea:3000/lab/gitops.git  apps                   main
argocd/sito          https://kubernetes.default.svc  sito       default  Synced  Healthy  Auto-Prune  <none>      http://gitea:3000/lab/gitops.git  sito                   main
```
```bash
argocd app get root
```
```
GROUP        KIND            NAMESPACE  NAME        STATUS  HEALTH   HOOK  MESSAGE
argoproj.io  Application     argocd     chart-sito  Synced                 application.argoproj.io/chart-sito created
argoproj.io  ApplicationSet  argocd     mia-app     Synced  Healthy        applicationset.argoproj.io/mia-app created
argoproj.io  Application     argocd     sito        Synced                 application.argoproj.io/sito configured
```
`sito` è *configured*: l'Application creata a mano è stata presa in carico dalla root e riscritta come dice git.
```bash
curl localhost:30091                          # versione 1.0 - pod mia-app-68c5cbdf5b-jx6hp    (dev)
curl localhost:30092                          # versione 1.0 - pod mia-app-68c5cbdf5b-x74tq    (prod, 3 repliche)
curl localhost:30093                          # pagina HTML: <h1>Pubblicato da Argo CD</h1>
```
Ripartire da zero, o ricostruire il cluster dopo un disastro, ora è: installare Argo CD, applicare `root.yaml`.

### 7. Promuovere una versione: dev, poi prod
Ogni overlay sceglie il tag dell'immagine con `images:` di Kustomize:
```bash
cd gitops
sed -i 's/newTag: "1.0"/newTag: "2.0"/' mia-app/overlays/dev/kustomization.yaml
git commit -am "dev: mia-app 2.0" && git push
```
Prima del Deployment parte il Job [migrazione](repo/mia-app/base/migrazione.yaml), un **hook PreSync** (come una
migrazione del database). Lo stato dell'operazione, letto ogni due secondi:
```
16:50:44 Synced     Healthy     Succeeded | successfully synced (all tasks run)
16:50:46 OutOfSync  Healthy     Running   |
16:50:48 OutOfSync  Healthy     Running   | waiting for deletion of hook batch/Job/migrazione
16:50:50 OutOfSync  Healthy     Running   | waiting for completion of hook batch/Job/migrazione
16:50:56 Synced     Progressing Succeeded | successfully synced (all tasks run)
16:51:04 Synced     Healthy     Succeeded | successfully synced (all tasks run)
```
```bash
kubectl -n dev logs job/migrazione            # migrazione del database per la versione 2.0 / migrazione completata
curl localhost:30091                          # versione 2.0 - pod mia-app-65c5b755c-fwwxh
```
Quando dev va bene, stessa modifica in `overlays/prod/kustomization.yaml`. Con le richieste continue su
localhost:30092 durante l'aggiornamento: 75 `versione 1.0`, 225 `versione 2.0`, nessun errore su 300 (3 repliche,
`maxUnavailable: 0`, `preStop` di 5 secondi).

La "promozione" è un commit che cambia una riga: si rivede in una merge request, si approva, resta nella storia.
È quello che fa una pipeline di CI dopo il build (vedi [La CI aggiorna git](#la-ci-aggiorna-git-argo-cd-fa-il-deploy)).

### 8. Helm come sorgente
[apps/chart-sito.yaml](repo/apps/chart-sito.yaml) usa il chart in `chart-sito/` con valori propri
(`helm.valuesObject`). Cambiarli è un commit sull'Application, in `apps/`: lo applica la root, poi `chart-sito`
fa la sync.
```bash
# in apps/chart-sito.yaml, sotto valuesObject:  titolo: Valori cambiati in git   e   repliche: 3
git commit -am "chart-sito: titolo nuovo, 3 repliche" && git push
curl -s localhost:30093 | grep '<h1>'         # <h1>Valori cambiati in git</h1>
kubectl -n vetrina get deploy                 # vetrina   3/3
helm list -A                                  # vuoto
```
Argo CD non fa `helm install`: genera i manifest con l'equivalente di `helm template` e li applica come gli altri.
Le risorse hanno le etichette di Helm (`app.kubernetes.io/managed-by: Helm`), ma non c'è nessuna release:
storia e rollback stanno in Argo CD. Gli hook di Helm (`helm.sh/hook`) vengono tradotti in hook di Argo CD.

### 9. Una versione che non esiste
```bash
sed -i 's/newTag: "2.0"/newTag: "2.1"/' mia-app/overlays/dev/kustomization.yaml
git commit -am "dev: mia-app 2.1" && git push
```
Il tag `2.1` non è nel registry. Il primo a usarlo è l'hook PreSync: il suo Pod va in `ErrImagePull`, e dopo 60 secondi
(`activeDeadlineSeconds` del Job) l'hook fallisce. La sync si ferma lì: **il Deployment non viene toccato** e dev
continua a rispondere `versione 2.0`. Argo CD 3 ritenta da solo le sync automatiche fallite, fino a 5 volte, con
attese crescenti:
```
16:57:15 OutOfSync Healthy Running | waiting for completion of hook batch/Job/migrazione
16:58:15 OutOfSync Healthy Running | one or more synchronization tasks completed unsuccessfully. Retrying attempt #1 at 2:58PM.
16:59:28 OutOfSync Healthy Running | one or more synchronization tasks completed unsuccessfully. Retrying attempt #2 at 2:59PM.
17:01:00 OutOfSync Healthy Running | one or more synchronization tasks completed unsuccessfully. Retrying attempt #3 at 3:01PM.
```
Senza `activeDeadlineSeconds` il Job resterebbe in attesa dell'immagine per sempre, e la sync con lui. Correzione:
```bash
git revert --no-edit HEAD && git push         # l'app torna Synced: git di nuovo uguale al cluster...
argocd app terminate-op mia-app-dev           # ...ma i tentativi sulla revisione vecchia continuano: si fermano così
```
```
Synced Healthy Failed | Operation terminated (retried 5 times).
```
Senza hook l'immagine sbagliata arriva al Deployment. Provato su `sito` con `image: nginx:9.9-alpine`: la sync
riesce (`Synced`: il cluster è uguale a git), ma la salute resta `Progressing`:
```
Synced Progressing  Deployment: Waiting for rollout to finish: 1 out of 2 new replicas have been updated...
```
```
NAME                    READY   STATUS         RESTARTS   AGE
sito-766cdcd4c7-nj82q   0/1     ErrImagePull   0          62s
sito-7dd76bfc6f-bvpr2   1/1     Running        0          9m52s
sito-7dd76bfc6f-jsnml   1/1     Running        0          9m53s
```
Il Pod nuovo non parte e quelli vecchi restano su (rolling update: si toglie un Pod vecchio solo quando uno nuovo è
pronto), quindi il sito continua a rispondere. Dopo `progressDeadlineSeconds` (default 600 s) il Deployment
diventa `Degraded`, e così l'app. Anche qui la correzione è `git revert`.

### 10. Un ambiente nuovo senza toccare Argo CD
L'ApplicationSet genera un'Application per ogni cartella in `mia-app/overlays/`. Una cartella nuova:
```bash
mkdir mia-app/overlays/staging
cat > mia-app/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: staging
resources:
  - ../../base
images:
  - name: localhost:5001/mia-app
    newTag: "2.0"
EOF
git add . && git commit -m "staging: nuovo ambiente" && git push
argocd app list -o name                       # dopo pochi secondi c'è anche argocd/mia-app-staging
kubectl -n staging get pods
```
Togliere la cartella da git cancella l'Application e, grazie al finalizer, anche le sue risorse:
```bash
git rm -r mia-app/overlays/staging && git commit -m "staging: via" && git push
```
Nel laboratorio sono serviti 3 secondi per creare l'Application e 6 per cancellarla. Il generatore git di per sé
ricontrolla ogni 3 minuti (`requeueAfter` nei log del controller). Qui è più veloce perché il webhook aggiorna
`mia-app-dev` e `mia-app-prod`, e quando un'Application generata cambia stato l'ApplicationSet viene ricalcolato.

### 11. Repository privato
Il repository finora è pubblico. Reso privato (su Gitea: *Settings > Visibility*, o
`curl -u lab:laboratorio -X PATCH -H 'Content-Type: application/json' -d '{"private":true}' localhost:3001/api/v1/repos/lab/gitops`),
Argo CD non lo legge più:
```bash
argocd app get sito --hard-refresh
```
```
Sync Status:        Unknown
ComparisonError  Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = failed to list refs: authentication required: Unauthorized
```
Le credenziali sono un Secret nel namespace `argocd` con l'etichetta `argocd.argoproj.io/secret-type`. Con un token
di sola lettura (Gitea: *Settings > Applications > Generate token*, permesso *repository: read*):
```bash
TOKEN=$(curl -s -u lab:laboratorio -H 'Content-Type: application/json' \
    -d '{"name":"argocd","scopes":["read:repository"]}' \
    localhost:3001/api/v1/users/lab/tokens | sed -E 's/.*"sha1":"([^"]+)".*/\1/')
kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea-lab
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds   # credenziali per tutti i repository sotto url
stringData:
  type: git
  url: http://gitea:3000/lab
  username: lab
  password: $TOKEN
EOF
argocd app get sito --hard-refresh | grep 'Sync Status'    # Synced to main (099d0c4)
argocd repocreds list
```
Con lo stesso token un `git push` risponde `403`: Argo CD legge, non scrive. Nella realtà questo Secret non si
scrive a mano in git (vedi [Segreti](#segreti-e-gitops)).

### Pulizia
```bash
./laboratorio.sh elimina
```

## Installazione

### Manifest ufficiali
```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
```
`--server-side` è obbligatorio: con l'apply normale kubectl salva l'intero oggetto in un'annotazione, e la CRD degli
ApplicationSet è troppo grande:
```
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes
```
Varianti nella stessa cartella `manifests/`:

| File | Cosa installa |
|---|---|
| `install.yaml` | tutto, una replica per componente: va bene per cominciare e per i laboratori |
| `ha/install.yaml` | alta affidabilità: più repliche, Redis HA. Serve un cluster con almeno 3 nodi |
| `namespace-install.yaml` | senza CRD né ClusterRole, permessi solo nel proprio namespace: per cluster condivisi (le CRD le installa un amministratore, da `manifests/crds/`) |
| `core-install.yaml` | senza interfaccia web, API, Dex e notifiche: solo i controller (*Argo CD core*) |
| `*-with-hydrator.yaml` | le stesse più il *Source Hydrator*, che scrive in git i manifest già generati |

Con Helm c'è il chart della comunità `argo/argo-cd` (https://argoproj.github.io/argo-helm). Con Kustomize, come nel
laboratorio, si tiene la versione nel file e le modifiche come patch ([argocd/kustomization.yaml](argocd/kustomization.yaml)):
```yaml
namespace: argocd
resources:
  - namespace.yaml
  - https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
patches:
  - path: argocd-server-service.yaml             # NodePort 30443
  - path: argocd-cm.yaml                         # timeout.reconciliation
```
```bash
kubectl apply -k argocd/ --server-side --force-conflicts
```
Questa cartella può diventare a sua volta un'Application: Argo CD che gestisce se stesso, e l'aggiornamento di versione
diventa un commit che cambia `v3.5.3` nell'URL.

### Primo accesso
```bash
argocd admin initial-password -n argocd       # la password generata di admin (Secret argocd-initial-admin-secret)
kubectl port-forward svc/argocd-server -n argocd 8080:443   # se il Service non è esposto
argocd login localhost:8080 --username admin --insecure     # --insecure: certificato autofirmato
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret # dopo il cambio non serve più
```
In produzione `argocd-server` si espone con un Ingress o un Gateway e un certificato vero, e il login passa da SSO
(Dex o un provider OIDC); l'utente `admin` si disabilita (`admin.enabled: "false"` in `argocd-cm`).

## Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mia-app
  namespace: argocd                    # il namespace di Argo CD, non quello dell'applicazione
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # cancellare l'Application cancella anche le risorse
spec:
  project: default
  source:
    repoURL: https://github.com/azienda/gitops.git
    targetRevision: main               # ramo, tag (v1.2.0), commit, o HEAD
    path: mia-app/overlays/prod
  destination:
    server: https://kubernetes.default.svc     # oppure name: produzione (un cluster registrato)
    namespace: prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff: {duration: 5s, factor: 2, maxDuration: 3m}
  ignoreDifferences: []                # vedi sotto
  revisionHistoryLimit: 10             # quante sync tenere nella storia
```

### Tipi di sorgente
Argo CD guarda la cartella e sceglie: `Chart.yaml` → Helm, `kustomization.yaml` → Kustomize, altrimenti YAML/JSON
semplici (*directory*). Il tipo scelto si legge in `status.sourceType`.

```yaml
# directory: tutti i .yaml/.yml/.json della cartella
source:
  path: manifest
  directory:
    recurse: true                      # anche le sottocartelle
    exclude: "{test/*,*.bak.yaml}"

# Kustomize: le stesse cose di kustomization.yaml, scritte nell'Application
source:
  path: mia-app/base
  kustomize:
    images: ["localhost:5001/mia-app:2.0"]
    namePrefix: prova-
    commonLabels: {squadra: web}

# Helm: chart in una cartella di git, o in un repository di chart
source:
  path: chart-sito
  helm:
    releaseName: vetrina
    valueFiles: [values-prod.yaml]     # file nella cartella del chart
    valuesObject:                      # valori scritti qui, vincono sui file
      repliche: 3
    parameters:                        # come --set
      - name: service.nodePort
        value: "30093"
source:                                # chart da un repository Helm: chart al posto di path
  repoURL: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  targetRevision: 91.9.0               # la versione del chart
```

**Più sorgenti** (`sources:` al posto di `source:`): il caso tipico è un chart pubblico con i valori nel proprio
repository. Una sorgente con `ref:` non genera manifest, rende disponibili i suoi file come `$nome`:
```yaml
spec:
  sources:
    - repoURL: http://gitea:3000/lab/gitops.git
      targetRevision: main
      path: chart-sito
      helm:
        valueFiles:
          - $valori/valori/prova.yaml          # file preso dalla seconda sorgente
    - repoURL: http://gitea:3000/lab/gitops.git
      targetRevision: main
      ref: valori
```
Provata nel laboratorio: il Deployment `multi` è partito con il titolo e le repliche di `valori/prova.yaml`.

### Stati
| Sync status | Significato |
|---|---|
| `Synced` | il cluster è uguale a git |
| `OutOfSync` | qualcosa è diverso: risorsa mancante, campo cambiato, risorsa in più da potare |
| `Unknown` | Argo CD non riesce a generare i manifest (repository irraggiungibile, YAML o chart rotto): si legge in *Conditions* |

| Health status | Significato |
|---|---|
| `Healthy` | tutto bene: Deployment con le repliche aggiornate e pronte, Job completato, Service con endpoint... |
| `Progressing` | sta arrivando: rollout in corso, Pod che partono |
| `Degraded` | rotto: rollout oltre `progressDeadlineSeconds`, Job fallito, Pod in `CrashLoopBackOff` |
| `Suspended` | in pausa: CronJob sospeso, rollout in pausa |
| `Missing` | in git ma non nel cluster |

Lo stato dell'Application è il peggiore fra quelli delle sue risorse. Per le CRD senza un controllo predefinito si
scrivono controlli di salute in Lua in `argocd-cm` (`resource.customizations.health.<gruppo>_<tipo>`).

## Sync

### Opzioni
In `spec.syncPolicy.syncOptions`, o su una singola risorsa con l'annotazione `argocd.argoproj.io/sync-options`:

| Opzione | Cosa fa |
|---|---|
| `CreateNamespace=true` | crea il namespace di destinazione. Non lo cancella quando si cancella l'Application |
| `PruneLast=true` | cancella le risorse tolte da git alla fine, dopo che le nuove sono sane |
| `ApplyOutOfSyncOnly=true` | applica solo le risorse diverse (utile con migliaia di risorse) |
| `ServerSideApply=true` | `kubectl apply --server-side`: per oggetti grandi (CRD) e campi gestiti da altri |
| `Replace=true` | `kubectl replace`/`create` invece di `apply` (distruttivo: usarlo su una risorsa sola) |
| `RespectIgnoreDifferences=true` | durante la sync non sovrascrive i campi in `ignoreDifferences` |
| `Prune=false` (annotazione) | questa risorsa non viene mai potata |
| `Delete=false` (annotazione) | questa risorsa resta anche cancellando l'Application (un PersistentVolumeClaim, un namespace) |

### ignoreDifferences
Alcuni campi li cambia qualcun altro: le repliche un HorizontalPodAutoscaler, i `caBundle` dei webhook un operatore.
Senza istruzioni, con `selfHeal` Argo CD e l'altro si contendono il campo all'infinito.
```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
  syncPolicy:
    syncOptions:
      - RespectIgnoreDifferences=true
```
Provato su `sito`: dopo `kubectl scale --replicas=2` l'app resta `Synced`, e anche dopo una sync per un'altra
modifica le repliche restano 2. Per un HPA, ancora più semplice: togliere `replicas` dal Deployment in git.

### Onde e hook
Le risorse di una sync si applicano in ordine di **onda** (*sync wave*, un numero, default 0). Argo CD passa all'onda
successiva solo quando quella prima è sana. Dentro un'onda l'ordine è per tipo: namespace, ConfigMap e Secret,
Service, workload...
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"         # prima di tutto il resto
```
Gli **hook** sono risorse (quasi sempre Job) che girano in una fase precisa e non fanno parte dello stato normale:

| Hook | Quando |
|---|---|
| `PreSync` | prima di applicare le risorse: migrazioni, controlli, backup |
| `Sync` | dopo i `PreSync`, insieme all'applicazione delle risorse |
| `PostSync` | dopo che tutto è `Healthy`: test di fumo, notifiche |
| `SyncFail` | se la sync fallisce: pulizia, avvisi |
| `PreDelete`, `PostDelete` | prima e dopo la cancellazione dell'Application |
| `Skip` | la risorsa non viene applicata |

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded   # o BeforeHookCreation, HookFailed
```
`hook-delete-policy`: `BeforeHookCreation` cancella il Job precedente prima di crearne uno nuovo (senza, il secondo
`create` fallirebbe perché il nome esiste già); `HookSucceeded` lo cancella se è riuscito.
Provato: ConfigMap con onda `-1` creata alle 15:10:46, Deployment con onda `1` alle 15:10:48, Job `PostSync` partito
quando il Deployment era pronto e cancellato a fine sync.

### Retry
Una sync automatica fallita viene ritentata: in Argo CD 3 il default è `limit: 5` anche se `retry` non è scritto
nell'Application (lo si legge in `status.operationState.operation.retry`). Una sync manuale no, se non si passa
`--retry-limit`. Un'operazione in corso, compresi i tentativi, si ferma con `argocd app terminate-op`.

### Cancellare un'Application
- con il finalizer `resources-finalizer.argocd.argoproj.io` (o `argocd app delete --cascade`): Argo CD cancella le
  risorse, poi l'Application. Senza: resta tutto nel cluster, non più gestito
- il namespace creato da `CreateNamespace=true` resta: provato con `argocd app delete onde --cascade`, il namespace
  `onde` era ancora `Active` un minuto dopo
- nell'app of apps il finalizer sulle figlie fa sì che togliere un file da `apps/` porti via anche le risorse

## ApplicationSet

Un modello di Application più uno o più **generatori** che producono i parametri:

| Generatore | Una Application per ogni... |
|---|---|
| `list` | elemento di una lista scritta nel file |
| `clusters` | cluster registrato in Argo CD (filtrabile per etichette) |
| `git` `directories` | cartella del repository che corrisponde a un percorso (il laboratorio: `mia-app/overlays/*`) |
| `git` `files` | file JSON/YAML trovato nel repository: i suoi campi diventano parametri |
| `matrix` | combinazione di due generatori (ogni cluster × ogni app) |
| `merge` | unione di generatori con chiave comune (default + eccezioni) |
| `scmProvider` | repository di un'organizzazione GitHub/GitLab/Gitea |
| `pullRequest` | merge request aperta: ambienti di anteprima che spariscono alla chiusura |

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: sito-per-cluster
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]        # parametro sbagliato = errore, non stringa vuota
  generators:
    - list:
        elements:
          - {cluster: staging, url: https://10.0.0.10:6443, repliche: "1"}
          - {cluster: produzione, url: https://10.0.0.20:6443, repliche: "3"}
  template:
    metadata:
      name: "sito-{{ .cluster }}"
    spec:
      project: default
      source:
        repoURL: https://github.com/azienda/gitops.git
        targetRevision: main
        path: sito
        kustomize:
          patches:
            - target: {kind: Deployment, name: sito}
              patch: |-
                - op: replace
                  path: /spec/replicas
                  value: {{ .repliche }}
      destination:
        server: "{{ .url }}"
        namespace: sito
```
Le Application generate appartengono all'ApplicationSet: modificate a mano tornano come il modello, cancellate
vengono ricreate. Se un elemento sparisce dal generatore, la sua Application viene cancellata
(`spec.syncPolicy.preserveResourcesOnDeletion: true` per lasciare le risorse nel cluster).

## Progetti e permessi

### AppProject
Il progetto `default` permette tutto. Per più squadre si crea un progetto per squadra:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: squadra-web
  namespace: argocd
spec:
  description: le applicazioni della squadra web
  sourceRepos:
    - http://gitea:3000/lab/*                    # da quali repository
  destinations:
    - server: https://kubernetes.default.svc
      namespace: web-*                           # in quali namespace
  clusterResourceWhitelist: []                   # nessuna risorsa di cluster (ClusterRole, CRD, Namespace...)
  namespaceResourceBlacklist:
    - group: ""
      kind: ResourceQuota                        # le quote le decidono gli amministratori
```
Provato nel laboratorio. Un'Application verso il namespace `sito` viene rifiutata alla creazione:
```
application spec for prova-progetto is invalid: InvalidSpecError: application destination server 'https://kubernetes.default.svc' and namespace 'sito' do not match any of the allowed destinations in project 'squadra-web'
```
e una verso `web-sito` con `CreateNamespace=true` si crea, ma la sync fallisce: il namespace è una risorsa di cluster.
```
one or more synchronization tasks are not valid: resource :Namespace is not permitted in project squadra-web
```
(o si aggiunge `{group: "", kind: Namespace}` a `clusterResourceWhitelist`, o i namespace li crea un amministratore).
Un progetto ha anche **ruoli** con token propri (per una pipeline che può solo fare `sync` delle sue app) e
**finestre di sync** (`syncWindows`: niente deploy automatici il venerdì pomeriggio).

### Utenti e RBAC
Utenti locali in `argocd-cm` (`accounts.alice: login`), o meglio SSO con Dex/OIDC; i permessi in `argocd-rbac-cm`:
```yaml
data:
  policy.default: role:readonly                  # chi non ha un ruolo vede soltanto
  policy.csv: |
    p, role:sviluppo, applications, get,  squadra-web/*, allow
    p, role:sviluppo, applications, sync, squadra-web/*, allow
    g, azienda:squadra-web, role:sviluppo        # un gruppo dell'SSO riceve il ruolo
```
Formato: `p, soggetto, risorsa, azione, progetto/oggetto, allow|deny`. Si controlla prima di applicarla, con le
righe di `policy.csv` in un file:
```bash
argocd admin settings rbac can role:sviluppo sync applications squadra-web/sito --policy-file policy.csv     # Yes
argocd admin settings rbac can role:sviluppo delete applications squadra-web/sito --policy-file policy.csv   # No
argocd admin settings rbac can azienda:squadra-web sync applications squadra-web/sito --policy-file policy.csv # Yes
```
Senza `--policy-file` legge `argocd-rbac-cm` dal cluster (`--namespace argocd`).

## Repository e credenziali

| Secret con etichetta `argocd.argoproj.io/secret-type` | Per cosa |
|---|---|
| `repository` | un repository preciso (`url` completo) |
| `repo-creds` | un modello: vale per tutti i repository il cui URL comincia con `url` |
| `cluster` | un cluster di destinazione (lo crea `argocd cluster add`) |

Campi: `type` (`git`, `helm`, `oci`), `url`, poi `username` + `password` (token), oppure `sshPrivateKey` per gli
URL `git@...`, oppure `githubAppID` + `githubAppPrivateKey` per una GitHub App. Il token va con i permessi minimi:
lettura. Le stesse cose da CLI:
```bash
argocd repo add http://gitea:3000/lab/gitops.git --username lab --password "$TOKEN"
argocd repocreds add http://gitea:3000/lab --username lab --password "$TOKEN"
argocd repo add git@github.com:azienda/gitops.git --ssh-private-key-path ~/.ssh/argocd
argocd repo list
```

## Segreti e GitOps
In git ci va tutto lo stato, ma un Secret Kubernetes è solo codificato in base64: in chiaro per chiunque legga il
repository. Le soluzioni usate:

| Strumento | Come funziona |
|---|---|
| **Sealed Secrets** | si cifra con la chiave pubblica del controller (`kubeseal`); in git va il `SealedSecret`, il controller nel cluster lo decifra in Secret |
| **SOPS** | cifra i valori dei file YAML con age, GPG o un KMS cloud; Argo CD li decifra con un plugin (KSOPS) |
| **External Secrets Operator** | in git c'è solo il riferimento (`ExternalSecret`); l'operatore legge il valore da Vault, AWS Secrets Manager, Azure Key Vault... e crea il Secret |

Con External Secrets il segreto non passa mai da git né da Argo CD: è la scelta più comune quando c'è già un secret
manager. Vedi anche [../06-kubernetes/kubernetes.md](../06-kubernetes/kubernetes.md) per i Secret.

## Webhook e tempi
Argo CD rilegge ogni repository ogni `timeout.reconciliation` (default 120 s più fino a 60 s casuali, in
`argocd-cm`; nel laboratorio 60 s). Un webhook dal server git verso `https://<argocd>/api/webhook` fa il refresh
subito; sono supportati GitHub, GitLab, Bitbucket, Azure DevOps e Gogs/Gitea. Con un segreto condiviso
(`webhook.github.secret`, `webhook.gitlab.secret`... in `argocd-secret`) Argo CD scarta le chiamate non firmate.

Argo CD aggiorna le Application il cui `repoURL` ha lo **stesso host** dell'URL annunciato nel webhook (la porta può
cambiare). Nel laboratorio è servito impostare `ROOT_URL=http://gitea:3000/` in Gitea: con
`http://localhost:3001/` il webhook arrivava (`Webhook handler completed`), ma nessuna Application corrispondeva e il
refresh avveniva solo al giro successivo, dopo 34 secondi. Con l'host giusto: circa un secondo.

## La CI aggiorna git, Argo CD fa il deploy
La pipeline non ha le credenziali del cluster: ha un token che può scrivere nel repository dei manifest. Dopo il build
e il push dell'immagine, cambia il tag e fa commit. Con GitLab CI ([../10-gitlab-ci/gitlab-ci.md](../10-gitlab-ci/gitlab-ci.md)):
```yaml
aggiorna-manifest:
  stage: deploy
  image: alpine/git:2.54.0
  needs: [build]                                 # dopo il build e il push dell'immagine
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  script:
    - git clone "https://ci:${GITOPS_TOKEN}@gitlab.example.com/infra/gitops.git"
    - cd gitops
    - sed -i "s/newTag: .*/newTag: \"$CI_COMMIT_SHORT_SHA\"/" mia-app/overlays/dev/kustomization.yaml
    - git -c user.name=ci -c user.email=ci@example.com commit -am "dev: mia-app $CI_COMMIT_SHORT_SHA"
    - git push
```
Lo script è stato provato nel laboratorio, in un container `alpine/git` sulla rete `kind` con un token Gitea di
scrittura: commit `dev: mia-app 1.0` su Gitea, e dopo circa 30 secondi (hook, readiness, `preStop`) dev rispondeva
`versione 1.0`. `GITOPS_TOKEN` è una variabile CI/CD *masked* e *protected*. Con `kustomize` nell'immagine, al
posto di `sed`: `kustomize edit set image localhost:5001/mia-app:$CI_COMMIT_SHORT_SHA`.

Per prod, invece del push diretto, la pipeline apre una merge request sul repository dei manifest: la promozione
passa da una revisione. Alternativa senza commit della CI: **Argo CD Image Updater**
(https://argocd-image-updater.readthedocs.io), che guarda il registry e aggiorna lui il tag (scrivendo in git o
nei parametri dell'Application).

Due repository, codice e manifest, sono la scelta più comune: i permessi sono separati, e un commit dei manifest
non fa ripartire la CI del codice.

## Più cluster
```bash
argocd cluster add kind-staging --name staging   # dal contesto di kubeconfig: crea un ServiceAccount nel cluster
argocd cluster list
```
Nell'Application `destination.name: staging` al posto di `server`. Il modello opposto, un Argo CD in ogni cluster,
è più isolato ma da gestire tante volte.

## La CLI

| Comando | Cosa fa |
|---|---|
| `argocd login localhost:30443 --username admin --insecure` | login, salva il token in `~/.config/argocd/config` |
| `argocd app list` | tutte le Application con sync e health |
| `argocd app get sito` | dettaglio e risorse; `--refresh`, `--hard-refresh` (rigenera anche i manifest) |
| `argocd app diff sito` | differenze fra git e cluster; exit code 1 se ce ne sono |
| `argocd app sync sito` | sync; `--dry-run`, `--prune`, `--resource apps:Deployment:sito`, `--revision <commit>` |
| `argocd app wait sito --health` | aspetta `Synced` e `Healthy` (anche `--delete` dopo una cancellazione) |
| `argocd app history sito` | le sync fatte, con ID e revisione |
| `argocd app rollback sito 1` | torna alla sync con ID 1 (solo con la sync manuale) |
| `argocd app set sito --sync-policy automated --self-heal --auto-prune` | cambia l'Application |
| `argocd app create onde --repo URL --path onde --dest-server https://kubernetes.default.svc --dest-namespace onde` | crea un'Application |
| `argocd app delete sito --cascade -y` | cancella l'Application e le sue risorse |
| `argocd app terminate-op sito` | ferma l'operazione in corso (anche i tentativi) |
| `argocd app resources sito` | le risorse gestite, con `ORPHANED` |
| `argocd app manifests sito --source git` | i manifest generati da git (`--source live`: quelli nel cluster) |
| `argocd app logs mia-app-dev --kind Deployment --name mia-app` | log dei Pod di una risorsa |
| `argocd appset list`, `argocd appset get mia-app` | gli ApplicationSet |
| `argocd proj list`, `argocd repo list`, `argocd repocreds list`, `argocd cluster list` | progetti, repository, credenziali, cluster |
| `argocd account list`, `argocd account update-password` | utenti |
| `argocd admin initial-password -n argocd` | la password iniziale (usa kubeconfig, non il login) |

Tutto quello che fa la CLI passa dall'API: `curl -sk https://localhost:30443/api/v1/applications -H "Authorization: Bearer $TOKEN"`,
con un token da `argocd account generate-token` (per un utente con la capacità `apiKey`).

## Notifiche
`argocd-notifications-controller` manda avvisi agli eventi delle Application: trigger (`on-sync-failed`,
`on-health-degraded`, `on-deployed`...), template del messaggio e servizi (Slack, Teams, email, webhook, GitHub).
Si configurano in `argocd-notifications-cm` e `argocd-notifications-secret`; un'Application si iscrive con
un'annotazione:
```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-failed.slack: canale-deploy
```
Il catalogo dei trigger e dei template pronti: https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/catalog/

## Argo CD e Flux a confronto

| | Argo CD | Flux |
|---|---|---|
| modello | Application (sorgente + destinazione insieme) | risorse separate: `GitRepository`, `Kustomization`, `HelmRelease` |
| interfaccia web | sì, con albero delle risorse, diff, log | no di base (interfacce di terze parti) |
| multi-cluster | un Argo CD centrale per molti cluster | di solito un Flux per cluster |
| Helm | `helm template` + apply: niente release | `helm install/upgrade` veri, con le release |
| permessi | AppProject + RBAC propri + SSO | quelli di Kubernetes (ServiceAccount per Kustomization) |
| aggiornamento immagini | Image Updater (progetto a parte) | controller ufficiali facoltativi (`ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation`) |
| quando sceglierlo | più squadre, interfaccia per chi non usa kubectl, molti cluster da un punto | tutto da riga di comando e in git, cluster autonomi |

## Buone pratiche
1. repository dei manifest separato da quello del codice; protezione del ramo e merge request per prod
2. versioni fisse: `targetRevision` su un ramo per gli ambienti di prova, su tag o commit per prod; immagini con tag
   immutabili (il commit), mai `latest` (Argo CD non vede che `latest` è cambiato)
3. app of apps o ApplicationSet fin dall'inizio: nessuna Application creata a mano che non sia in git
4. `automated` con `selfHeal` e `prune`; `PruneLast` e `Prune=false` sulle risorse con dati (PVC)
5. un AppProject per squadra, mai tutto in `default`; credenziali di sola lettura sui repository
6. nessun Secret in chiaro in git: External Secrets, Sealed Secrets o SOPS
7. hook `PreSync` con `activeDeadlineSeconds`; readiness probe e `maxUnavailable: 0` perché `Healthy` voglia dire
   davvero "funziona"
8. webhook dal server git, con il segreto; `timeout.reconciliation` lasciato al default
9. Argo CD stesso descritto in git (Kustomize o Helm), aggiornato con un commit come le altre app

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `metadata.annotations: Too long: may not be more than 262144 bytes` all'installazione | `kubectl apply` senza `--server-side` | `kubectl apply --server-side --force-conflicts` |
| `failed to list refs: authentication required` | repository privato senza credenziali | Secret `repository` o `repo-creds` con un token di lettura |
| l'app resta `OutOfSync` per 2-3 minuti dopo il push | nessun webhook, o webhook con un host diverso dal `repoURL` | webhook verso `/api/webhook`; stesso host nel server git (in Gitea `ROOT_URL`) e nell'Application |
| `rollback cannot be initiated when auto-sync is enabled` | rollback di Argo CD con `automated` | `git revert`; oppure togliere `automated`, rollback, poi correggere git |
| sync ferma su `waiting for completion of hook batch/Job/...` | il Job dell'hook non finisce (immagine inesistente, attesa infinita) | `activeDeadlineSeconds` nel Job; `argocd app terminate-op` |
| l'app torna `Synced` ma i tentativi continuano (`Retrying attempt #N`) | i retry valgono per la revisione vecchia | `argocd app terminate-op` |
| `OutOfSync` che non va mai via | un campo cambiato da un altro controller (HPA, operatore, webhook che aggiunge default) | `ignoreDifferences` + `RespectIgnoreDifferences=true` |
| `do not match any of the allowed destinations in project` | destinazione fuori dall'AppProject | correggere `destination` o le `destinations` del progetto |
| `resource :Namespace is not permitted in project` | `CreateNamespace=true` in un progetto senza risorse di cluster | `Namespace` in `clusterResourceWhitelist`, o namespace creati da un amministratore |
| il namespace resta dopo `argocd app delete --cascade` | `CreateNamespace` non lo considera una risorsa gestita | cancellarlo a mano, o metterlo in git come risorsa |
| `Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name` | avviso di Kubernetes sul nome del finalizer | innocuo: è il nome ufficiale (la variante `.../background` fa la cancellazione in background) |
| NodePort casuale nonostante la patch di Kustomize | patch strategica sulle porte del Service senza `protocol` | `protocol: TCP` nella patch: kustomize unisce le porte su `port` + `protocol` |
| `ErrImagePull` su `localhost:5001/...` in kind | il nodo cerca il registry su se stesso | `hosts.toml` in `/etc/containerd/certs.d/localhost:5001/` che punta al container del registry |
| `helm list` non mostra le app di Argo CD | Argo CD usa `helm template`, non crea release | normale: storia e rollback in Argo CD |
