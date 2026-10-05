# 09 - cert-manager: certificati TLS automatici

Un certificato TLS scade, e quasi sempre se ne accorge qualcuno quando il sito smette di funzionare. **cert-manager** è un controller che chiede i certificati, li salva in un
Secret e li **rinnova prima della scadenza**. Si dichiara cosa serve (un `Certificate`) e da chi farselo firmare (un `Issuer`); il resto lo fa lui.

| File | Contenuto |
|---|---|
| [issuer.yaml](issuer.yaml) | Una CA di laboratorio: `ClusterIssuer selfsigned` → `Certificate ca-lab` → `ClusterIssuer ca-lab` |
| [sito.yaml](sito.yaml) | Namespace `tls`, un `Certificate` per `sito.example.com` e un nginx che serve HTTPS con il Secret che ne risulta |
| [breve.yaml](breve.yaml) | Un certificato di un'ora che si rinnova dopo un minuto, per vedere il rinnovo |
| [ingress.yaml](ingress.yaml) | Un Ingress con l'annotazione `cert-manager.io/cluster-issuer`: il certificato se lo crea da solo |

| Oggetto | Cosa è |
|---|---|
| `Issuer` / `ClusterIssuer` | chi firma i certificati: di un namespace / di tutto il cluster. Tipi: `selfSigned`, `ca`, `acme` (Let's Encrypt), `vault` |
| `Certificate` | cosa si vuole: nomi (`dnsNames`), durata, in quale Secret scriverlo, da quale emittente |
| `CertificateRequest`, `Order`, `Challenge` | gli oggetti che cert-manager crea da solo per ottenere il certificato: si guardano per capire dove si è bloccato |

## Installazione
```bash
V=$(gh api repos/cert-manager/cert-manager/releases/latest --jq .tag_name)    # v1.21.2 (o la versione che serve: https://github.com/cert-manager/cert-manager/releases)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$V/cert-manager.yaml
kubectl -n cert-manager rollout status deploy/cert-manager deploy/cert-manager-webhook deploy/cert-manager-cainjector
```
Con Helm è `helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true` (la strada per la produzione; qui è stato provato il manifest).
Sono tre Deployment (il controller, il webhook che valida gli oggetti, il cainjector) e le CRD `certificates`, `issuers`, `clusterissuers`... (vedi [../10-operator-crd/](../10-operator-crd/)).
Subito dopo l'installazione il webhook può non essere pronto: un `apply` immediato di un `ClusterIssuer` può fallire con `failed calling webhook`; basta ripetere dopo il `rollout status`.

## 1. La CA del laboratorio
Un certificato lo firma sempre qualcuno. Prima si crea una CA, in tre passi, tutti dichiarati in [issuer.yaml](issuer.yaml):
```bash
kubectl apply -f issuer.yaml
kubectl get clusterissuer
# NAME         READY   AGE
# ca-lab       True    5s
# selfsigned   True    6s
kubectl -n cert-manager get certificate ca-lab        # READY True, SECRET ca-lab-tls
```
`selfSigned` firma un certificato con la propria chiave: serve solo a creare il certificato della CA (`isCA: true`). Poi il `ClusterIssuer ca-lab` usa quel Secret per firmare
tutto il resto. `ca-lab-tls` sta nel namespace `cert-manager` perché è lì che un `ClusterIssuer` cerca il Secret della CA.

## 2. Un certificato per un sito
```bash
kubectl apply -f sito.yaml
kubectl -n tls get certificate
# NAME   READY   SECRET     AGE
# sito   True    sito-tls   5s
kubectl -n tls get secret sito-tls
# NAME       TYPE                DATA   AGE
# sito-tls   kubernetes.io/tls   3      5s          <- tls.crt, tls.key, ca.crt
```
In pochi secondi: `Certificate` → `CertificateRequest` → firma della CA → Secret. Il Pod nginx monta il Secret in `/certs` e parte solo quando esiste. Si guarda cosa c'è nel certificato:
```bash
kubectl -n tls get secret sito-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -dates -ext subjectAltName
# issuer=CN=ca-lab
# notBefore=Oct  5 14:07:22 2026 GMT
# notAfter=Jan  3 14:07:22 2027 GMT                 <- 90 giorni: duration: 2160h
# X509v3 Subject Alternative Name: critical
#     DNS:sito.example.com
```
E si prova l'HTTPS, fidandosi della CA (`ca.crt` è nel Secret):
```bash
kubectl -n tls get secret sito-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl -n tls port-forward svc/sito 8443:443 &
curl --cacert ca.crt --resolve sito.example.com:8443:127.0.0.1 https://sito.example.com:8443/
# HTTPS ok da sito-64dc6f8c88-g78jk
curl --resolve sito.example.com:8443:127.0.0.1 https://sito.example.com:8443/
# curl: (60) SSL certificate problem: unable to get local issuer certificate     <- senza la CA il browser avvisa
```
`--resolve` fa credere a `curl` che `sito.example.com` sia `127.0.0.1`, così il nome del certificato corrisponde. Su Windows `curl.exe` usa Schannel e con una CA privata
dice `the revocation status is unknown`: serve anche `--ssl-no-revoke`. `openssl s_client -connect 127.0.0.1:8443 -servername sito.example.com -CAfile ca.crt` dà `Verify return code: 0 (ok)`.

## 3. Il rinnovo
`duration` dice quanto dura, `renewBefore` quanto prima della scadenza rinnovare. Con 90 giorni e 30 di anticipo, il rinnovo scatta al 60° giorno (`Renewal Time` in `kubectl describe certificate`).
Per vederlo senza aspettare, [breve.yaml](breve.yaml) dura 1 ora (il minimo) e rinnova dopo un minuto:
```bash
kubectl apply -f breve.yaml
kubectl -n tls get certificate breve -o jsonpath='rev={.status.revision} renewal={.status.renewalTime}{"\n"}'
# rev=1 renewal=2026-10-05T14:08:55Z
# (dopo un minuto)
# rev=2 renewal=2026-10-05T14:09:55Z       <- nuovo certificato, nuova data di rinnovo, e di nuovo ogni minuto
```
Cose da sapere:
- il rinnovo **cambia il Secret**; i file montati nel Pod si aggiornano da soli dopo qualche decina di secondi, ma **un'applicazione che legge il certificato solo all'avvio** (nginx, per
  esempio) continua a usare quello vecchio finché non la si ricarica (`nginx -s reload`, o un riavvio del Deployment, o uno strumento come Reloader). Non provato qui sul Pod nginx
- se si **cancella il Secret**, cert-manager lo rigenera da solo in pochi secondi (`kubectl -n tls delete secret sito-tls`, poi `get secret`: di nuovo lì)
- se si **cancella il `Certificate`**, il Secret **resta**: di default cert-manager non lo elimina (`kubectl delete -f breve.yaml` lascia `breve-tls`)
- `privateKey.rotationPolicy: Always` genera una chiave nuova a ogni rinnovo (il default `Never` la riusa)

## 4. Da un Ingress
Con l'annotazione `cert-manager.io/cluster-issuer` un Ingress con `tls:` si procura il certificato senza scrivere un `Certificate` (componente *ingress-shim*):
```bash
kubectl apply -f ingress.yaml
kubectl -n tls get certificate
# NAME           READY   SECRET         AGE
# ingresso-tls   True    ingresso-tls   2m20s        <- creato da cert-manager, ha il nome del Secret
# sito           True    sito-tls       2m53s
```
Il certificato si ottiene anche senza un controller Ingress nel cluster: l'Ingress qui è solo la dichiarazione. Per portare il traffico serve poi un Ingress controller ([../06-ingress-gateway/](../06-ingress-gateway/)).

## 5. Quando non si emette
```bash
kubectl -n tls get certificate                       # READY False
kubectl -n tls describe certificate rotto            # gli eventi: Issuing, Generated, Requested
kubectl -n tls get certificaterequest                # APPROVED True, READY False
kubectl -n tls get certificaterequest rotto-1 -o jsonpath='{.status.conditions[*].message}'
# Certificate request has been approved by cert-manager.io Referenced "ClusterIssuer" not found: clusterissuer.cert-manager.io "non-esiste" not found
```
La causa vera è quasi sempre nel `CertificateRequest` (e per Let's Encrypt in `Order` e `Challenge`), non nel `Certificate`, che dice solo "False".

## 6. Let's Encrypt (non provato)
Per certificati veri serve un emittente `acme` e un dominio pubblico: Let's Encrypt deve poter raggiungere il cluster per verificarlo. Qui non si può provare (nessun dominio, nessun IP pubblico),
quindi quello che segue è lo schema standard e **non è stato eseguito**:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: letsencrypt-staging }
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory    # prima in staging: ha limiti molto più larghi
    email: nome@example.com
    privateKeySecretRef: { name: letsencrypt-staging-account }
    solvers:
      - http01:
          ingress: { ingressClassName: nginx }       # la verifica passa da un Ingress sulla porta 80
```
`http01` richiede la porta 80 raggiungibile da internet; per un certificato `*.example.com` serve `dns01`. Si prova sempre sull'URL di *staging* (i certificati non sono fidati dai browser,
ma i limiti di richieste sono larghi) e solo dopo si passa a `https://acme-v02.api.letsencrypt.org/directory`.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `failed calling webhook "webhook.cert-manager.io"` subito dopo l'installazione | il webhook non è ancora pronto | `kubectl -n cert-manager rollout status deploy/cert-manager-webhook`, poi ripetere |
| `Certificate` `READY False` | un gradino della catena ha fallito | `describe certificate`, poi `get certificaterequest -o yaml`; per ACME anche `get order,challenge` |
| `Referenced "ClusterIssuer" not found` | `issuerRef` sbagliato (nome o `kind`) | `kubectl get clusterissuer,issuer -A` |
| il Pod resta in `ContainerCreating` con `secret "sito-tls" not found` | il certificato non è ancora emesso | normale per qualche secondo; se resta, vedere sopra |
| il browser avvisa "certificato non attendibile" | la CA è privata | è atteso con `ca`/`selfSigned`: installare `ca.crt` fra le CA fidate, oppure usare Let's Encrypt |
| il certificato è rinnovato ma il sito mostra quello vecchio | l'applicazione non ricarica il file | ricaricarla o riavviare il Deployment |

## Pulizia
```bash
kubectl delete namespace tls
kubectl delete -f issuer.yaml
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/$V/cert-manager.yaml
```

Torna a [../](../)
