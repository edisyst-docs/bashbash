# 02 - ConfigMap e Secret

nginx ufficiale, senza nessuna modifica all'immagine: pagina, configurazione, variabili e password arrivano tutte dal cluster.

| File | Contenuto |
|---|---|
| [configmap.yaml](configmap.yaml) | `sito-env` (valori singoli → variabili d'ambiente) e `sito-file` (file interi → file nel container) |
| [secret.yaml](secret.yaml) | `sito-secret` con `DB_PASSWORD` |
| [deployment.yaml](deployment.yaml) | Deployment `sito` che usa tutti e tre, Service NodePort 30081 |

## 1. Creare e guardare
```bash
kubectl apply -f .
kubectl rollout status deploy/sito
curl localhost:30081                     # la pagina: è index.html della ConfigMap sito-file
curl localhost:30081/info                # ambiente: sviluppo / lingua: it / pod: sito-...
```
Da dove arriva ogni cosa:

| Nel container | Arriva da | Come |
|---|---|---|
| variabili `AMBIENTE`, `LINGUA` | ConfigMap `sito-env` | `envFrom`: tutte le chiavi diventano variabili |
| variabile `DB_PASSWORD` | Secret `sito-secret` | `env.valueFrom.secretKeyRef`: una chiave sola |
| `/usr/share/nginx/html/index.html` | ConfigMap `sito-file`, chiave `index.html` | volume con `items` |
| `/etc/nginx/templates/default.conf.template` | ConfigMap `sito-file` | volume; all'avvio nginx lo trasforma in `conf.d/default.conf` sostituendo le variabili |
| `/etc/segreti/DB_PASSWORD` | Secret `sito-secret` | volume, permessi `0400` |

```bash
kubectl exec deploy/sito -- printenv AMBIENTE LINGUA DB_PASSWORD
kubectl exec deploy/sito -- cat /etc/nginx/conf.d/default.conf   # ${AMBIENTE} già sostituito con "sviluppo"
kubectl exec deploy/sito -- ls -la /usr/share/nginx/html /etc/segreti
```
Nei volumi ogni chiave è un link simbolico a `..data/`, a sua volta un link a una cartella con la data: quando la ConfigMap
cambia, il kubelet scrive una cartella nuova e sposta `..data` in un colpo solo, così il container non legge mai un file a metà.

## 2. Cosa si aggiorna da solo, e cosa no
Si cambiano insieme la pagina e l'ambiente: in `configmap.yaml`, `AMBIENTE: produzione` e un titolo diverso in `index.html`.
```bash
kubectl apply -f configmap.yaml
while sleep 5; do curl -s localhost:30081 | grep h1; done   # dopo circa un minuto compare il titolo nuovo (CTRL+C per uscire)
curl localhost:30081/info                # ma qui c'è ancora "ambiente: sviluppo"
```
- i **file** montati da una ConfigMap si aggiornano da soli (nei test: 73 secondi), senza riavviare niente
- le **variabili d'ambiente** si leggono solo all'avvio del processo: restano quelle vecchie. Lo stesso vale per
  `default.conf`, generato una volta sola all'avvio del container

Per rileggerle bisogna ricreare i Pod:
```bash
kubectl rollout restart deploy/sito      # nuovi Pod a rotazione, senza interruzioni
curl localhost:30081/info                # ambiente: produzione
```
Per non doverselo ricordare: Kustomize genera ConfigMap con il nome che cambia a ogni modifica, e Helm si scrive
un'annotazione con l'impronta della configurazione nel template del Pod. In entrambi i casi cambia il Pod, e il rolling
update parte da solo (esempi in [../03-wordpress-mysql/](../03-wordpress-mysql/) e [../07-helm/](../07-helm/)).

## 3. Il Secret non è segreto
```bash
kubectl get secret sito-secret -o yaml                                   # data: DB_PASSWORD: Y2FtYmlhbWk=
kubectl get secret sito-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d  # cambiami
kubectl describe secret sito-secret                                      # questo invece mostra solo la lunghezza
```
Base64 è una codifica, non una cifratura: chiunque possa leggere il Secret ha la password. Per questo i permessi sui
Secret vanno dati con attenzione (RBAC) e `secret.yaml` in un progetto vero non va in git: il Secret si crea a parte.
```bash
kubectl create secret generic sito-secret --from-literal=DB_PASSWORD="$(openssl rand -base64 18)" \
    --dry-run=client -o yaml | kubectl apply -f -   # crea o aggiorna, senza file su disco
```

## 4. Creare ConfigMap dai file
Invece di scrivere il YAML a mano:
```bash
kubectl create configmap nginx-conf --from-file=default.conf --from-literal=AMBIENTE=prova --dry-run=client -o yaml
kubectl create configmap pagine --from-file=./html/          # una chiave per ogni file della cartella
kubectl create configmap env --from-env-file=app.env         # righe CHIAVE=valore
```

## Smontare
```bash
kubectl delete -f .
```

Torna a [../](../)
