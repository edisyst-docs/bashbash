# 03 - WordPress e MySQL

La stessa applicazione dello [stack swarm](../../05-swarm/wordpress-stack.yaml), in Kubernetes: un database con i dati
su un volume persistente e un web server replicato.

| File | Contenuto |
|---|---|
| [kustomization.yaml](kustomization.yaml) | Namespace `wordpress` per tutto, Secret generati (password e chiavi dei cookie) |
| [namespace.yaml](namespace.yaml) | Il namespace |
| [mysql.yaml](mysql.yaml) | StatefulSet `mysql` con `volumeClaimTemplates`, Service headless |
| [wordpress.yaml](wordpress.yaml) | Deployment `wordpress` a 2 repliche, Service NodePort 30082 |

## 1. Creare tutto
```bash
kubectl kustomize .                      # il risultato finale, senza applicarlo: namespace ovunque, Secret con suffisso
kubectl apply -k .
kubectl -n wordpress rollout status sts/mysql     # il primo avvio di MySQL dura 30-60 secondi
kubectl -n wordpress rollout status deploy/wordpress
kubectl get all,pvc,secret -n wordpress
```
Poi http://localhost:30082 e l'installazione guidata di WordPress.

Cosa ha fatto **Kustomize**:
- ha messo tutte le risorse nel namespace `wordpress` (i file non lo dicono)
- ha generato i Secret `db-credenziali-hkfmbd292h` e `wordpress-chiavi-...`: il suffisso è l'impronta del contenuto
- ha riscritto i riferimenti (`secretKeyRef: db-credenziali`) con il nome completo. Se si cambia una password nel
  `kustomization.yaml` cambia il nome del Secret, quindi il template dei Pod, e i Pod ripartono da soli

## 2. Il database: StatefulSet e volume
```bash
kubectl -n wordpress get pvc,pv          # dati-mysql-0: 1Gi, Bound, StorageClass standard
kubectl -n wordpress exec mysql-0 -- sh -c 'mysql -uwordpress -p"$MYSQL_PASSWORD" wordpress -e "show tables"'
```
- lo StatefulSet chiama i Pod `mysql-0`, `mysql-1`... sempre con lo stesso nome, e per ogni replica crea una PVC
  dal `volumeClaimTemplates`: `dati-mysql-0`. Se il Pod muore, quello nuovo si chiama ancora `mysql-0` e rimonta **la stessa** PVC
- il Service `mysql` è **headless** (`clusterIP: None`): `mysql` risolve direttamente l'IP del Pod
- una replica sola: due MySQL con due volumi sarebbero due database separati, non un cluster (per quello servono
  operatori come MySQL Operator o CloudNativePG per PostgreSQL)

La prova, dopo aver completato l'installazione di WordPress:
```bash
kubectl -n wordpress delete pod mysql-0
kubectl -n wordpress get pods -w         # mysql-0 torna, le due repliche di wordpress diventano 0/1 e poi di nuovo 1/1
```
Il sito è ancora lì, con gli stessi contenuti. Mentre MySQL riparte, la readiness probe di WordPress fallisce (senza
database risponde 500): entrambe le repliche escono dal Service, che senza Pod pronti **rifiuta** le connessioni.
Il browser vede un errore di connessione per qualche secondo, poi tutto torna.

### Il volume è legato al nodo
In kind lo storage è una cartella sul nodo dove il Pod è partito la prima volta: il PV porta con sé quel nodo.
```bash
kubectl get pv -o jsonpath='{.items[0].spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}'
kubectl cordon lab-worker                # (il nodo stampato sopra) niente nuovi Pod lì
kubectl -n wordpress delete pod mysql-0
kubectl -n wordpress get pod mysql-0     # Pending
kubectl -n wordpress describe pod mysql-0 | tail -3
```
```
0/3 nodes are available: 1 node(s) didn't match PersistentVolume's node affinity, 1 node(s) had untolerated taint(s),
1 node(s) were unschedulable.
```
Il Pod non può andare sull'altro worker perché lì i suoi dati non ci sono. `kubectl uncordon lab-worker` e riparte.
In un cloud il volume è un disco di rete che si stacca da un nodo e si attacca a un altro, e questo problema non c'è
(entro la stessa zona).

## 3. WordPress replicato
Due repliche dietro lo stesso Service: le richieste arrivano a caso all'una o all'altra.
```bash
kubectl -n wordpress logs -l app=wordpress --prefix -f   # ogni riga di log con il Pod che l'ha servita
```
Perché funzioni davvero servono due accorgimenti, che valgono per qualunque applicazione web replicata:
- **stesse chiavi dei cookie su ogni replica**: WordPress firma i cookie di login con delle chiavi che, se non gliele si
  passa, ogni container genera a caso. Il login fatto sulla replica A non varrebbe sulla B, e l'utente verrebbe buttato
  fuori a caso. Per questo il Secret `wordpress-chiavi` le passa uguali a tutte (`envFrom`)
- **file caricati condivisi**: immagini e plugin caricati dall'interfaccia finiscono nel filesystem della replica che ha
  ricevuto la richiesta. Qui non sono condivisi: serve un volume `ReadWriteMany` (NFS, file system di rete del cloud)
  o un plugin che salvi gli upload su uno storage a oggetti (S3)

## Smontare
```bash
kubectl delete -k .                      # ATTENZIONE: elimina il namespace, la PVC e quindi il database
```

Torna a [../](../)
