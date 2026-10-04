# 07 - Helm

Helm è il gestore di pacchetti di Kubernetes. Un **chart** è una cartella di template YAML con dei valori di default;
installarlo crea una **release**, un'istanza con un nome, di cui Helm conserva ogni revisione per aggiornarla e tornare indietro.

| File | Contenuto |
|---|---|
| [sito/Chart.yaml](sito/Chart.yaml) | Nome e versione del chart |
| [sito/values.yaml](sito/values.yaml) | Valori di default: repliche, immagine, titolo, colore, nodePort |
| [sito/templates/](sito/templates/) | ConfigMap con la pagina, Deployment, Service, `_helpers.tpl` con le label, `NOTES.txt` |
| [values-prod.yaml](values-prod.yaml) | I valori che cambiano per la release di produzione |

```bash
winget install Helm.Helm                 # Windows; brew install helm su macOS; su Linux lo script di get.helm.sh
helm version                             # qui Helm 4
```

## 1. Il linguaggio dei template
Go template, con le funzioni di Sprig:
```yaml
name: {{ .Release.Name }}-pagina                         # oggetti predefiniti: .Release, .Chart, .Values, .Capabilities
replicas: {{ .Values.repliche }}                         # un valore da values.yaml, -f o --set
image: "{{ .Values.immagine.repository }}:{{ .Values.immagine.tag }}"
version: {{ .Chart.AppVersion | quote }}                 # pipeline: il valore passa alla funzione quote
type: {{ if .Values.service.nodePort }}NodePort{{ else }}ClusterIP{{ end }}
{{- with .Values.service.nodePort }}                     # with: entra nel blocco solo se il valore non è vuoto; dentro, "." è il valore
nodePort: {{ . }}
{{- end }}
labels:
  {{- include "sito.labels" . | nindent 4 }}             # un blocco di _helpers.tpl, indentato di 4 spazi su una riga nuova
checksum/pagina: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```
- `{{-` e `-}}` tolgono gli spazi e l'a capo prima o dopo: servono a non lasciare righe vuote nel YAML
- l'annotazione `checksum/pagina` contiene l'impronta della ConfigMap: se cambia la pagina cambia il template del Pod,
  e parte un rolling update. Senza, i Pod continuerebbero a servire la pagina vecchia per un minuto (vedi [../02-config/](../02-config/))

## 2. Verificare prima di installare
```bash
helm lint ./sito                         # errori di sintassi e buone pratiche
helm template dev ./sito                 # i manifest che produrrebbe, senza toccare il cluster
helm template dev ./sito -f values-prod.yaml --show-only templates/deployment.yaml
helm template x ./sito --set service.nodePort=0 --show-only templates/service.yaml   # type: ClusterIP, niente nodePort
```

## 3. Due release dallo stesso chart
```bash
helm install dev ./sito --wait                        # 2 repliche, http://localhost:30084, blu
helm install prod ./sito -f values-prod.yaml --wait   # 3 repliche, http://localhost:30085, rosso
helm list
kubectl get pods -l app.kubernetes.io/name=sito       # dev-... e prod-...
```
Stesso chart, due installazioni indipendenti: il nome della release fa da prefisso a tutti gli oggetti.
Dopo l'installazione Helm stampa `NOTES.txt`, con l'URL da aprire. La storia di ogni release sta in un Secret del
namespace (`kubectl get secret -l owner=helm`).

Precedenza dei valori, dalla più debole: `values.yaml` del chart < `-f file.yaml` (in ordine, vince l'ultimo) < `--set`.

## 4. Aggiornare e tornare indietro
```bash
helm upgrade dev ./sito --set titolo="Titolo cambiato" --wait   # revisione 2: la ConfigMap cambia, i Pod ripartono
helm upgrade dev ./sito --reuse-values --set repliche=4 --wait  # revisione 3: tiene il titolo e cambia le repliche
helm get values dev                      # i valori passati a mano (USER-SUPPLIED VALUES)
helm get values dev --all                # tutti i valori, default compresi
helm get manifest dev                    # i manifest installati
helm history dev
helm rollback dev 1 --wait               # torna alla revisione 1: diventa la revisione 4
```
```
REVISION  STATUS      DESCRIPTION
1         superseded  Install complete
2         superseded  Upgrade complete
3         superseded  Upgrade complete
4         deployed    Rollback to 1
```
> **ATTENZIONE**: se all'upgrade si passa anche un solo valore, senza `--reuse-values` Helm riparte dai default del
> chart più i valori di *quel* comando: un `--set` dato all'upgrade precedente si perde (se non se ne passa nessuno,
> invece, riusa i precedenti). Per non doverci pensare i valori si tengono in un file (`values-prod.yaml`) versionato
> in git, e si passa sempre quello.

Cosa cambierebbe un upgrade, senza plugin:
```bash
helm template dev ./sito --set colore=green | kubectl diff -f -
```
Nelle pipeline si usa un comando solo, che installa o aggiorna:
```bash
helm upgrade --install prod ./sito -f values-prod.yaml --wait --rollback-on-failure --timeout 5m
```
`--rollback-on-failure` (in Helm 3 si chiamava `--atomic`): se le risorse non diventano pronte entro il timeout, torna
alla revisione precedente. Altre differenze di Helm 4: applica i manifest con il server-side apply, `--wait` accetta una
strategia (da solo vale `watcher`), `helm list -a` non c'è più (`-A` = tutti i namespace).

## 5. Un chart pubblico
I chart si distribuiscono in repository HTTP (`helm repo add`) o, sempre più spesso, in registry OCI come le immagini.
Si cercano su https://artifacthub.io/. Qui podinfo, una piccola applicazione di esempio:
```bash
helm show chart oci://ghcr.io/stefanprodan/charts/podinfo    # nome e versione
helm show values oci://ghcr.io/stefanprodan/charts/podinfo   # TUTTI i valori configurabili, con i default
helm install podinfo oci://ghcr.io/stefanprodan/charts/podinfo \
    --set replicaCount=2 --set ui.message="Installato con Helm" --wait
kubectl port-forward svc/podinfo 9898:9898   # poi http://localhost:9898, o in un altro terminale:
curl -s localhost:9898                       # JSON con hostname, versione, "message": "Installato con Helm"
```
Con un repository classico:
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update                         # aggiorna l'indice dei chart
helm search repo podinfo --versions      # versioni disponibili
helm install podinfo podinfo/podinfo --version 6.15.0   # in produzione sempre una versione fissa
helm pull podinfo/podinfo --untar        # scarica il chart per leggerne i template
```

## Smontare
```bash
helm uninstall dev prod podinfo
```
Un chart nuovo con la struttura completa (Ingress, HPA, ServiceAccount, test) si genera con `helm create nome`:
è un buon punto di partenza, ma è molto più lungo di questo.

Torna a [../](../)
