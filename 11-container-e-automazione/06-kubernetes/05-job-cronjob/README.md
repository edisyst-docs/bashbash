# 05 - Job e CronJob

Lavori che finiscono: un Job con più Pod in parallelo e un CronJob che controlla un sito ogni minuto.
Gli script sono bash, montati da una ConfigMap nell'immagine ufficiale `bash:5`.

| File | Contenuto |
|---|---|
| [script.yaml](script.yaml) | ConfigMap `script` con `elabora.sh` e `controllo.sh` |
| [job.yaml](job.yaml) | Job `elabora`: 5 blocchi, 2 Pod alla volta, ognuno con il suo indice |
| [cronjob.yaml](cronjob.yaml) | CronJob `controllo-sito`: ogni minuto `wget` sul Service del laboratorio 01 |

## 1. Job paralleli
```bash
kubectl apply -f script.yaml -f job.yaml
kubectl get pods -l job-name=elabora -w  # al massimo 2 Running insieme; quando uno finisce parte il successivo
kubectl wait --for=condition=complete job/elabora --timeout=120s
kubectl get job elabora                  # COMPLETIONS 5/5
kubectl logs -l job-name=elabora --prefix
```
```
[pod/elabora-0-dppbj/elabora] 20:45:54 blocco 0 (1-1000) su elabora-0
[pod/elabora-0-dppbj/elabora] 20:45:59 blocco 0: somma = 500500
[pod/elabora-1-q9nt5/elabora] 20:45:54 blocco 1 (1001-2000) su elabora-1
...
```
- `completions: 5` servono 5 esecuzioni riuscite; `parallelism: 2` ne girano 2 insieme
- `completionMode: Indexed` dà a ogni Pod la variabile `JOB_COMPLETION_INDEX` (0-4) e un hostname con l'indice:
  lo script la usa per scegliere la sua parte di lavoro. È il modo per dividere un'elaborazione grossa fra più Pod
- `restartPolicy: Never`: se lo script esce con errore il Pod resta `Error` (con i suoi log) e il Job ne crea un altro,
  fino a `backoffLimit`
- `ttlSecondsAfterFinished: 600`: dopo 10 minuti Job e Pod spariscono da soli

La ConfigMap è montata come file senza permesso di esecuzione: per questo il comando è `bash /script/elabora.sh`.
L'orario nei log è UTC: il fuso del container, non quello del PC.

## 2. CronJob
Il controllo cerca il Service `web` del [laboratorio 01](../01-deployment/): va tenuto attivo.
```bash
kubectl apply -f cronjob.yaml
kubectl get cronjob controllo-sito       # LAST SCHEDULE si aggiorna ogni minuto
kubectl get jobs -w                      # un Job nuovo al minuto: controllo-sito-29842367...
kubectl logs -l batch.kubernetes.io/job-name --prefix --tail=1
```
```
2026-09-27 20:47:00 OK http://web.default.svc.cluster.local -> pod web-5d9f98888b-kdttk - nginx 1.26.3
```
Il nome `web.default.svc.cluster.local` è quello completo del Service: `web` nel namespace `default`. Da un altro namespace
`web` da solo non si risolverebbe.

Ora il sito si rompe, e il controllo lo lancio a mano senza aspettare il minuto:
```bash
kubectl scale deploy web --replicas=0
kubectl create job --from=cronjob/controllo-sito manuale-1   # un Job subito, con lo stesso modello del CronJob
kubectl get pods -l batch.kubernetes.io/job-name=manuale-1    # 2 Pod in Error: primo tentativo + 1 (backoffLimit: 1)
kubectl logs -l batch.kubernetes.io/job-name=manuale-1 --prefix
kubectl get job manuale-1                # STATUS Failed
kubectl scale deploy web --replicas=3
```
```
wget: can't connect to remote host (10.96.193.47): Connection refused
2026-09-27 20:47:32 ERRORE: http://web.default.svc.cluster.local non risponde
```
Il Service esiste ma non ha Pod: rifiuta la connessione. Un sistema di monitoraggio guarderebbe i Job falliti
(`kube_job_status_failed` in Prometheus) e manderebbe un avviso.

Opzioni del CronJob:
- `schedule`: la sintassi di crontab, vedi [../../../06-sistema/09-crontab.md](../../../06-sistema/09-crontab.md);
  `timeZone` fissa il fuso con cui leggerla (senza, è quello del control plane, di solito UTC)
- `concurrencyPolicy: Forbid`: se il giro precedente non è finito, salta questo (`Replace` lo sostituisce, `Allow` li sovrappone)
- `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`: quanti Job finiti conservare, con i loro log
- `activeDeadlineSeconds`: tempo massimo di un Job, poi viene fermato e segnato come fallito
- sospendere senza cancellare: `kubectl patch cronjob controllo-sito -p '{"spec":{"suspend":true}}'`

## Smontare
```bash
kubectl delete -f .
```

Torna a [../](../)
