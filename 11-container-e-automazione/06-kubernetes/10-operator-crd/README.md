# 10 - CRD e operatori

Kubernetes conosce `Deployment`, `Service`, `ConfigMap`... Una **CustomResourceDefinition** (CRD) gli insegna un tipo **nuovo**, per esempio `Sito` o `Database`, che poi si crea, si legge e si cancella
con `kubectl` come gli altri. Un **operatore** è il programma che dà un significato a quel tipo: guarda le risorse, e crea o corregge gli oggetti veri (Deployment, Secret, volumi)
perché la realtà corrisponda a quello che è stato chiesto. Così si codifica nel cluster il lavoro di un amministratore: "un Database con 3 repliche e un backup" diventa un file YAML.

È lo stesso schema di cert-manager ([../09-cert-manager/](../09-cert-manager/): `Certificate` e `Issuer` sono CRD) e di Argo CD ([../../11-argocd/](../../11-argocd/): `Application`).

| File | Contenuto |
|---|---|
| [crd.yaml](crd.yaml) | Il tipo `Sito` (gruppo `lab.example.com`): campi, validazione, valori di default, colonne di `kubectl get` |
| [sito.yaml](sito.yaml) | Una risorsa `Sito` |
| [operatore.sh](operatore.sh) | Un operatore minimo in bash: per ogni `Sito` crea una ConfigMap e un Deployment e scrive lo stato |

## 1. Il CRD
```bash
kubectl apply -f crd.yaml
kubectl get crd siti.lab.example.com
kubectl api-resources --api-group=lab.example.com
# NAME   SHORTNAMES   APIVERSION           NAMESPACED   KIND
# siti   st           lab.example.com/v1   true         Sito
```
Il nome del CRD è sempre `<plurale>.<gruppo>`. Il `schema` (OpenAPI v3) dice quali campi esistono e **li valida il server**, prima che l'oggetto venga salvato:
```bash
kubectl apply -f - <<'EOF'
apiVersion: lab.example.com/v1
kind: Sito
metadata: { name: cattivo }
spec: { titolo: "<script>", repliche: 9 }
EOF
# The Sito "cattivo" is invalid:
# * spec.titolo: Invalid value: "<script>": spec.titolo in body should match '^[A-Za-z0-9 ]{1,40}$'
# * spec.repliche: Invalid value: 9: spec.repliche in body should be less than or equal to 5
```
Senza `titolo` si ottiene `spec.titolo: Required value`; con `titolo` e senza `repliche` l'oggetto viene salvato con `repliche: 2`, il `default` dello schema.

Si crea una risorsa come qualunque altra:
```bash
kubectl apply -f sito.yaml
kubectl get siti                  # e anche: kubectl get st
# NAME      REPLICHE   PRONTE   TITOLO                    AGE
# vetrina   2                   Benvenuti nella vetrina   0s
kubectl get pods                  # No resources found: il CRD descrive i dati, non fa niente da solo
```
`PRONTE` è vuoto e non ci sono Pod: **nessuno sta ascoltando**. Un CRD senza operatore è una tabella in un database.

## 2. L'operatore
[operatore.sh](operatore.sh) è un ciclo di **riconciliazione**: ogni pochi secondi legge i `Sito`, confronta quello che è stato chiesto (`.spec`) con quello che c'è e corregge la differenza.
```bash
INTERVALLO=3 bash operatore.sh        # in un altro terminale; Ctrl+C per fermarlo
# 16:12:05 default/vetrina: 0/2 pronte
# 16:12:09 default/vetrina: 1/2 pronte
# 16:12:12 default/vetrina: 2/2 pronte
kubectl get siti
# NAME      REPLICHE   PRONTE   TITOLO                    AGE
# vetrina   2          2/2      Benvenuti nella vetrina   31s
```
Per ogni `Sito` lo script fa tre cose:
- applica una **ConfigMap** con la pagina e un **Deployment** nginx con `replicas` uguale a `.spec.repliche`
- mette in entrambi una **ownerReference** verso il `Sito`: Kubernetes sa che gli "appartengono"
- scrive in `.status.pronte` quanti Pod sono pronti, con `kubectl patch --subresource=status` (lo `status` si scrive a parte: è una risposta dell'operatore, non una richiesta dell'utente)

Cosa si vede:
```bash
kubectl patch sito vetrina --type=merge -p '{"spec":{"repliche":4,"titolo":"Nuovo titolo"}}'
kubectl get siti                                  # dopo pochi secondi: REPLICHE 4, PRONTE 4/4, TITOLO Nuovo titolo
kubectl scale deploy vetrina --replicas=1         # qualcuno cambia a mano il Deployment...
kubectl get deploy vetrina                        # ...e al giro dopo l'operatore lo riporta a 4/4 (derivazione corretta)
kubectl exec deploy/vetrina -- wget -qO- localhost  # <h1>Nuovo titolo</h1>   (la ConfigMap montata si aggiorna da sola)
kubectl delete sito vetrina
kubectl get deploy,pods                           # vuoti: l'ownerReference fa eliminare tutto dal garbage collector, senza codice nostro
```
Questa è l'idea centrale: **stato desiderato** (la risorsa) contro **stato reale** (Deployment e Pod), e un controller che li avvicina per sempre. I controller di Kubernetes (Deployment,
ReplicaSet, Job) funzionano così; un operatore è un controller scritto da noi per un tipo nostro.

## Cosa manca a questo operatore (e agli operatori veri)
| Questo script | Un operatore vero |
|---|---|
| ricontrolla tutto ogni 3 secondi (polling) | si iscrive agli eventi dell'API (*watch*): reagisce subito e non carica il cluster |
| gira sul PC con le credenziali di chi lo lancia | è un Deployment nel cluster con un **ServiceAccount** e un Role (RBAC) con i soli permessi che servono |
| se un `Sito` viene cancellato non può fare pulizie speciali | usa i **finalizer** per fare cose prima della cancellazione (un backup, un DNS da togliere) |
| un solo `kubectl apply` per tutto | gestisce errori e *retry*, e scrive nello `status` anche le *conditions* (`Ready`, `Degraded`) |
| bash | Go (**Kubebuilder**, **Operator SDK**), Python (**kopf**), Java; più operatori già pronti su operatorhub.io (PostgreSQL, Redis, Kafka, Prometheus) |

Gli operatori già pronti si installano come qualsiasi applicazione (manifest o Helm, vedi [../07-helm/](../07-helm/)) e portano i loro CRD: dopo, `kubectl get` mostra i tipi nuovi.
```bash
kubectl get crd                                   # tutti i tipi aggiunti al cluster: con cert-manager installato ci sono certificates.cert-manager.io, issuers...
kubectl explain sito.spec                         # la documentazione dei campi, presa dallo schema del CRD
```

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `no matches for kind "Sito" in version "lab.example.com/v1"` | il CRD non è stato creato (o `apiVersion` sbagliata) | `kubectl apply -f crd.yaml`, `kubectl api-resources --api-group=lab.example.com` |
| `The Sito ... is invalid: ... Required value / should match` | la validazione dello schema | leggere il campo indicato nel messaggio |
| `kubectl get siti` mostra la risorsa ma non succede niente | non c'è nessun operatore in esecuzione | avviarlo e guardarne il log |
| i Pod restano dopo aver cancellato il `Sito` | manca la `ownerReference` (o il `uid` è sbagliato) | `kubectl get deploy X -o jsonpath='{.metadata.ownerReferences}'` |
| cancellando un CRD spariscono tutte le sue risorse | è così: il CRD è la definizione | ATTENZIONE: `kubectl delete crd` cancella **tutti** gli oggetti di quel tipo |

## Pulizia
```bash
kubectl delete -f sito.yaml --ignore-not-found
kubectl delete -f crd.yaml
```

Torna a [../](../)
