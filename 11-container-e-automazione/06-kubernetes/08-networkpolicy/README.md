# 08 - NetworkPolicy

Di default in Kubernetes **ogni Pod parla con ogni Pod**, in qualunque namespace. Una **NetworkPolicy** è il firewall fra i Pod: dice quali connessioni sono permesse,
scegliendo i Pod con le etichette (non con gli indirizzi, che cambiano a ogni riavvio).

| File | Contenuto |
|---|---|
| [app.yaml](app.yaml) | Namespace `shop` con tre livelli: `web`, `api`, `db` (`traefik/whoami`, un Service ciascuno) |
| [01-nega-tutto.yaml](01-nega-tutto.yaml) | *Default deny*: nessuno entra in nessun Pod del namespace |
| [02-consenti.yaml](02-consenti.yaml) | Si apre solo `web` → `api` → `db` |
| [03-egress.yaml](03-egress.yaml) | Policy di uscita per `api` (solo `db` e DNS). **Non è applicata da kindnet**, vedi sotto |
| [04-namespace.yaml](04-namespace.yaml) | Ingresso a `web` da un altro namespace (`namespaceSelector`) |

Serve un CNI che applichi le policy: **kindnet**, quello di kind, applica quelle di **ingresso**; Calico e Cilium anche quelle di uscita. Con un CNI che non le supporta
`kubectl apply` riesce lo stesso e non cambia niente: la policy resta scritta e non fa nulla.

## Preparazione
```bash
kubectl apply -f app.yaml
kubectl -n shop rollout status deploy/web deploy/api deploy/db
```
Per provare una connessione serve un Pod "client" con l'**etichetta del chiamante**, perché le policy guardano chi chiama. Una funzione per la shell (usa `curl` in un Pod usa-e-getta):
```bash
prova() {     # prova ETICHETTA DESTINAZIONE [NAMESPACE]   es.: prova web api
  kubectl -n "${3:-shop}" run "p-$RANDOM" --rm -i --restart=Never -q --labels="app=$1" \
      --image=curlimages/curl:8.11.1 --command -- sh -c "curl -sS -m 3 -o /dev/null http://$2 2>&1 && echo ok || echo bloccato" 2>&1 | tail -1
}
```
In Git Bash su Windows anteporre `MSYS_NO_PATHCONV=1` a `kubectl` se un percorso viene alterato.

## 1. Senza policy è tutto aperto
```bash
prova web api        # ok
prova web db         # ok   <- il frontend raggiunge il database: è quello che vogliamo evitare
prova intruso db     # ok   <- e lo raggiunge anche un Pod qualunque
```

## 2. Default deny
```bash
kubectl apply -f 01-nega-tutto.yaml
prova web api        # bloccato
prova api db         # bloccato
```
`podSelector: {}` sceglie **tutti** i Pod del namespace, `policyTypes: [Ingress]` senza regole `ingress` significa "non entra nessuno". Il blocco è un **timeout** (3 secondi), non un
"connection refused": i pacchetti vengono scartati in silenzio, ed è per questo che un errore di policy si riconosce da una richiesta che resta appesa.

## 3. Aprire solo il percorso giusto
```bash
kubectl apply -f 02-consenti.yaml
prova web api        # ok
prova api db         # ok
prova web db         # bloccato   <- il frontend non arriva più ai dati
prova intruso api    # bloccato
prova web web        # bloccato   <- anche fra Pod dello stesso tipo: "tutti" include se stessi
kubectl -n shop get netpol
# NAME            POD-SELECTOR   AGE
# api-da-web      app=api        29s
# db-da-api       app=db         29s
# nega-ingresso   <none>         48s
```
Le policy **si sommano**: una connessione passa se **almeno una** policy che seleziona il Pod di destinazione la permette. Non esistono regole di divieto e non conta l'ordine:
si parte da "tutto chiuso" e si aggiunge.
```bash
kubectl -n shop describe netpol db-da-api         # in parole: "Allowing ingress traffic: To Port: 80/TCP From: PodSelector: app=api"
```

## 4. Altri namespace
Un `from` con `namespaceSelector` guarda le etichette del **namespace** (da Kubernetes 1.21 ogni namespace ha `kubernetes.io/metadata.name` con il proprio nome).
```bash
kubectl create namespace monitoring
kubectl apply -f 04-namespace.yaml
prova prometheus web.shop monitoring    # ok       <- Pod "prometheus" nel namespace monitoring
prova altro web.shop monitoring         # bloccato <- stesso namespace, etichetta diversa
prova prometheus web                    # bloccato <- etichetta giusta, ma nel namespace shop
```
Un trabocchetto di sintassi: `namespaceSelector` e `podSelector` **nello stesso elemento** di `from` valgono in **AND** (Pod con quell'etichetta *e* in quel namespace), come qui;
in **due elementi separati** (due trattini) valgono in **OR** (qualunque Pod di quel namespace, oppure qualunque Pod con quell'etichetta nel namespace della policy): una riga sbagliata
apre molto di più di quello che si voleva.

## 5. L'uscita (egress) e il DNS
[03-egress.yaml](03-egress.yaml) limita i Pod `api` a parlare con `db` e con CoreDNS. La regola DNS è obbligatoria: senza, i Pod non risolvono nessun nome (`db`, `web.shop`...) e
sembra che "non funzioni niente". Su un CNI che applica l'egress la regola `to: kube-dns` sulla 53 UDP e TCP è la prima da scrivere.

**Con kindnet l'egress non viene applicato.** Provato con la policy 03 attiva e un Pod di lunga durata con l'etichetta `app=api`:
```bash
kubectl -n shop exec cl -- curl -sS -m 4 -o /dev/null -w '%{http_code}\n' http://libero.default    # 200: un Service in un altro namespace
kubectl -n shop run x --rm -i --restart=Never --labels=app=api --image=curlimages/curl:8.11.1 -- curl -s -o /dev/null -w '%{http_code}\n' http://example.com   # 200: internet
```
Entrambi passano, anche se la policy dice solo `db` e DNS. Se un `api` non dovesse poter uscire, in un cluster kind questo test non lo dimostrerebbe: serve Calico o Cilium
(non provati qui).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| la policy c'è ma il traffico passa | il CNI non applica le policy (o solo l'ingresso) | `kubectl get pods -n kube-system`: quale CNI? Calico/Cilium per l'egress |
| dopo il default deny non funziona più niente, nemmeno il DNS | policy di egress senza la regola per CoreDNS | aprire UDP e TCP 53 verso `k8s-app: kube-dns` in `kube-system` |
| una policy per `web` apre anche `db` | `podSelector` troppo largo, o `from` con due trattini (OR) invece di uno (AND) | `kubectl describe netpol`: legge le regole in parole |
| la connessione si blocca, ma i Pod sono sani | nessuna policy permette *quel* chiamante | `kubectl get pod --show-labels` sul chiamante e confrontare con il `from` |
| `Ingress` o `LoadBalancer` smettono di arrivare ai Pod dopo il default deny | il traffico arriva dal controller, che sta in un altro namespace | aggiungere un `from` con il `namespaceSelector` del controller |

## Pulizia
```bash
kubectl delete namespace shop monitoring
```

Torna a [../](../)
