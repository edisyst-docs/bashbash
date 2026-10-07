# Scenari guidati: il monitoraggio non dice la verità

> **Laboratorio**: `./lab.sh 12`, poi `cd 09-scenari`. Qui non si prova un comando: **c'è un guasto vero** nello stack di osservabilità (Prometheus, Alertmanager, Loki, Grafana, nginx, node_exporter), da diagnosticare e riparare (vedi [lab/](lab/)). Serve circa 1 GB di RAM, come per il resto dell'area.

Nelle pagine dell'area si impara come funziona ogni pezzo; qui si impara a capire **quando non funziona**. Il caso peggiore del monitoraggio non è il server che cade, è il monitoraggio che **non te lo dice**: un target spento, un alert che non scatta mai, un numero che non vuol dire quello che sembra, un avviso che arriva alla persona sbagliata, i log che si fermano.
Otto problemi, uno per volta, con il solo sintomo: [Prometheus](02-prometheus.md), le [regole](05-alerting.md), [PromQL](04-promql.md), [Alertmanager](05-alerting.md), [Loki](07-loki.md), [Grafana](06-grafana.md) e il [textfile collector](03-exporter.md).

## Come si lavora
```bash
cd ~/lab/09-scenari
./scenari.sh guasta 4          # riporta tutto in salute, rompe come lo scenario 4 e stampa il "ticket" (il sintomo)
# ...diagnosi e riparazione, con quello che vuoi...
./scenari.sh controlla         # dice se il sintomo è sparito; non rivela la causa
./scenari.sh ripristina        # toglie ogni guasto (anche se ti sei perso)
```
- `controlla` guarda **il sintomo**, non il comando che hai usato, e lo fa **dal vero**: manda un alert e guarda se arriva l'email in Mailpit, fa una richiesta a nginx e cerca la riga in Loki. Per questo certi controlli aspettano fino a 30 secondi.
- `scenari.sh` **non va aperto** prima di aver provato: contiene i guasti. Ogni scenario ha un suggerimento e la soluzione, nascosti. (Non è lo `scenari.sh` di `05-alerting/`, che serve a **provocare** un alert: qui il guasto è nel monitoraggio.)
- La configurazione di Prometheus e Alertmanager è in `/etc/monitoring/`, da ricaricare con `curl -X POST http://prometheus:9090/-/reload` e `... http://alertmanager:9093/-/reload`. I file degli scenari 3 e 8 stanno in `~/lab/09-scenari/lavoro/`.
- Ogni `guasta N` riparte da una base sana: ricopia la configurazione originale, toglie ogni file di prova e svuota Mailpit.
- Per abbreviare: `P=http://prometheus:9090` e `q() { curl -s $P/api/v1/query --data-urlencode "query=$1"; }`.

## Il metodo: dove si ferma il dato
Il dato attraversa una catena, e ogni anello può perderlo. Si guarda **anello per anello, a partire dalla sorgente**:

| Anello | Domanda | Dove si guarda |
|---|---|---|
| sorgente | il servizio produce il dato? | `curl localhost:9100/metrics`, `wc -l /var/log/nginx/access.log` |
| raccolta | Prometheus / Alloy lo prende? | `up`, `http://prometheus:9090/api/v1/targets` (`lastError`), la query vuota `[]` |
| calcolo | la regola o la query dicono quello che penso? | provare **la sua espressione da sola** nell'API, e `promtool check` |
| allarme | Alertmanager lo riceve e lo instrada? | `/api/v1/alerts`, `amtool config routes test`, `amtool check-config` |
| destinatario | arriva a chi deve? | Mailpit (`http://mailpit:8025`), Grafana, Loki |

Due trucchi che valgono per quasi tutto: **provare l'espressione in pezzi** (togli un filtro, o una funzione, e guarda cosa torna) e **tenere separati "il comando riesce" e "il risultato è giusto"** (`promtool` dice che la sintassi è valida, non che la metrica esiste).

---

## 1. Il target è DOWN
**Ticket**: *In Prometheus il target del job `node` risulta DOWN (`up` vale 0) e i grafici di CPU e memoria della dashboard Server sono fermi.*

<details><summary>da dove cominciare</summary>

L'API dei target (`/api/v1/targets`) dice a quale indirizzo Prometheus sta andando e perché fallisce (`lastError`). Poi prova la stessa porta con `nc`.
</details>
<details><summary>soluzione</summary>

```bash
q 'up{job="node"}' | jq -c '.data.result[]|{instance:.metric.instance,valore:.value[1]}'
# {"instance":"server:9101","valore":"0"}
curl -s $P/api/v1/targets | jq -c '.data.activeTargets[]|select(.labels.job=="node")|{scrapeUrl,health,lastError}'
# {"scrapeUrl":"http://server:9101/metrics","health":"down","lastError":"Get \"http://server:9101/metrics\": dial tcp 172.21.0.11:9101: connect: connection refused"}
nc -zv -w2 server 9101; nc -zv -w2 server 9100
# nc: connect to server (172.21.0.11) port 9101 (tcp) failed: Connection refused
# Connection to server (172.21.0.11) 9100 port [tcp/*] succeeded!
```
Il target punta alla porta `9101`, dove non ascolta nessuno; node_exporter è sulla `9100`. `connection refused` è la firma: il server c'è, la porta no. Si corregge la configurazione, si controlla, si ricarica:
```bash
sed -i 's/server:9101/server:9100/' /etc/monitoring/prometheus/prometheus.yml
promtool check config /etc/monitoring/prometheus/prometheus.yml | head -3
# Checking /etc/monitoring/prometheus/prometheus.yml
#   SUCCESS: 3 rule files found
#  SUCCESS: /etc/monitoring/prometheus/prometheus.yml is valid prometheus config file syntax
curl -s -X POST $P/-/reload
# dopo circa 10 secondi (uno scrape):
q 'up{job="node"}' | jq -c '.data.result[0].value[1]'
# "1"
```
`promtool check config` dice che il file è **valido** anche con la porta sbagliata: controlla la sintassi, non se il target esiste. Ricaricare senza correggere non basta (e `controlla` lo verifica). Se `up` è 0 per un target, **la prima mossa** è sempre `lastError` dell'API dei target.
</details>

## 2. L'alert che non scatta mai
**Ticket**: */dati è pieno quasi all'80% (df lo conferma), ma l'alert `DatiQuasiPieno` non scatta mai.*

<details><summary>da dove cominciare</summary>

La regola è in `/etc/monitoring/prometheus/regole/zz-dati.yml`. Prova **l'espressione da sola** nell'API: se la parte a sinistra del `<` non restituisce niente, la regola non ha mai nulla da confrontare.
</details>
<details><summary>soluzione</summary>

```bash
df -h /dati | tail -1
# tmpfs            64M   50M   14M  79% /dati
q 'node_filesystem_avail_byte{mountpoint="/dati"}' | jq -c '.data.result'
# []                                             <- nessuna serie: la metrica non esiste con questo nome
q 'node_filesystem_avail_bytes{mountpoint="/dati"}' | jq -c '.data.result[]|.value[1]'
# "67108864"
promtool check rules /etc/monitoring/prometheus/regole/zz-dati.yml
# Checking /etc/monitoring/prometheus/regole/zz-dati.yml
#   SUCCESS: 1 rules found
```
La regola usa `node_filesystem_avail_byte`, senza la **s** finale: la metrica vera è `node_filesystem_avail_bytes`. Una query su una metrica che non esiste **non dà errore**: dà un insieme vuoto, e una regola il cui lato sinistro è vuoto **non scatta mai**, in silenzio. `promtool check rules` non se ne accorge: controlla la sintassi, non i nomi.
```bash
sed -i 's/avail_byte{/avail_bytes{/' /etc/monitoring/prometheus/regole/zz-dati.yml
curl -s -X POST $P/-/reload
# dopo circa 10 secondi (una valutazione):
curl -s $P/api/v1/alerts | jq -c '.data.alerts[]|select(.labels.alertname=="DatiQuasiPieno")|{state,value}'
# {"state":"firing","value":"2.1875e-01"}
```
La soluzione sbagliata più comoda è **liberare il disco**: l'alert starebbe zitto per un buon motivo, ma la regola resterebbe rotta (`controlla` vuole l'alert `firing` con `/dati` ancora pieno). Un alert non si considera provato finché non si è visto scattare almeno una volta. Vedi `absent()` in [04-promql](04-promql.md), che serve proprio a segnalare una metrica che sparisce.
</details>

## 3. Un numero che sale e basta
**Ticket**: *`lavoro/richieste.sh` dovrebbe stampare le richieste al secondo di nginx, ma stampa un numero grande che non fa che salire.*

<details><summary>da dove cominciare</summary>

`nginx_http_requests_total` è un **contatore**: conta tutte le richieste dall'avvio e non scende mai. Per sapere quante ne arrivano al secondo serve la funzione che ne calcola la **velocità**.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/09-scenari/lavoro
bash richieste.sh
# 73                                             <- il totale dall'avvio di nginx, non una velocità
q 'rate(nginx_http_requests_total[1m])' | jq -r '.data.result[0].value[1]'
# 1.3801264742551222                             <- richieste al secondo, mediate sull'ultimo minuto
sed -i 's/query=nginx_http_requests_total/query=rate(nginx_http_requests_total[1m])/' richieste.sh
bash richieste.sh
# 1.3803831563227127
```
Un contatore si legge **sempre** con `rate()` (al secondo) o `increase()` (in un intervallo): il valore grezzo non dice niente di "adesso", e dopo un riavvio del servizio torna a 0. `increase(...[5m])` dà le richieste **in cinque minuti**, non al secondo, e `controlla` lo respinge. Vedi `rate` in [04-promql](04-promql.md).
</details>

## 4. L'alert critico va alla persona sbagliata
**Ticket**: *Un alert con `severity=critical` è arrivato a `squadra@lab.local` invece che al reperibile (`reperibile@lab.local`).*

<details><summary>da dove cominciare</summary>

Alertmanager ha uno strumento per **chiedere a una configurazione dove manderebbe un alert** con certe etichette: `amtool config routes test`. Usalo con `severity=critical`, e guarda l'albero delle rotte.
</details>
<details><summary>soluzione</summary>

```bash
amtool config routes test --config.file=/etc/monitoring/alertmanager/alertmanager.yml severity=critical
# squadra                                        <- dovrebbe essere "reperibile"
amtool config routes show --config.file=/etc/monitoring/alertmanager/alertmanager.yml
# Routing tree:
# .
# └── default-route  receiver: squadra
#     └── {severity="critico"}  receiver: reperibile
```
(L'avviso `--config.file flag overrides the --alertmanager.url` è omesso.) La rotta per il reperibile aspetta `severity="critico"`, ma gli alert hanno `severity="critical"`: non combacia, e l'alert cade nella rotta predefinita, `squadra`. Un matcher è un confronto **esatto**, una lettera di differenza basta. Si corregge, si ricarica, si riprova:
```bash
sed -i 's/severity="critico"/severity="critical"/' /etc/monitoring/alertmanager/alertmanager.yml
curl -s -X POST http://alertmanager:9093/-/reload
amtool config routes test --config.file=/etc/monitoring/alertmanager/alertmanager.yml severity=critical
# reperibile
```
`amtool config routes test` legge il **file**: dice cosa succederebbe con quella configurazione, non cosa sta facendo Alertmanager adesso (quella è l'ultima caricata). Per questo `controlla` fa la prova vera: manda un alert `critical` e aspetta l'email del reperibile in Mailpit. Vedi le rotte in [05-alerting](05-alerting.md).
</details>

## 5. "Ho ricaricato, ma non è cambiato niente"
**Ticket**: *Ho cambiato l'indirizzo di `squadra` in `nuova-squadra@lab.local` in `alertmanager.yml` e ricaricato Alertmanager, ma le email degli alert warning vanno ancora a `squadra@lab.local`.*

<details><summary>da dove cominciare</summary>

Guarda la **risposta** del ricaricamento (`curl -s -X POST -w '%{http_code}' .../-/reload`), non solo che il comando sia partito. E controlla il file con lo strumento giusto.
</details>
<details><summary>soluzione</summary>

```bash
curl -s -X POST -w ' (HTTP %{http_code})\n' http://alertmanager:9093/-/reload
# failed to reload config: yaml: line 35: could not find expected ':'
#  (HTTP 500)
amtool check-config /etc/monitoring/alertmanager/alertmanager.yml
# Checking '/etc/monitoring/alertmanager/alertmanager.yml'  FAILED: yaml: line 35: could not find expected ':'
grep -n 'send_resolved' /etc/monitoring/alertmanager/alertmanager.yml
# 34:        send_resolved true                       # manda anche il messaggio "risolto"      <- manca il ":"
# 38:        send_resolved: true
```
Il ricaricamento **ha fallito** (HTTP 500) e Alertmanager continua a usare la configurazione **di prima**, quella con il vecchio indirizzo: è il comportamento giusto (meglio la vecchia che nessuna), ma se non si legge la risposta sembra che sia andato tutto bene. All'origine c'è una riga con `send_resolved true` senza i due punti, nell'indirizzo cambiato. Si corregge e **si controlla prima di ricaricare**:
```bash
sed -i 's/send_resolved true  /send_resolved: true  /' /etc/monitoring/alertmanager/alertmanager.yml
amtool check-config /etc/monitoring/alertmanager/alertmanager.yml | head -3
# Checking '/etc/monitoring/alertmanager/alertmanager.yml'  SUCCESS
# Found:
#  - global config
curl -s -X POST -w '(HTTP %{http_code})\n' http://alertmanager:9093/-/reload
# (HTTP 200)
```
`controlla` manda un alert `warning` e cerca l'email a `nuova-squadra@lab.local` in Mailpit. Il riflesso da prendere: **`amtool check-config` prima, `reload` dopo, e leggere sempre il codice HTTP**. Vale uguale per Prometheus (`promtool check config`).
</details>

## 6. I log di nginx non arrivano più in Loki
**Ticket**: *Le richieste a nginx non compaiono più in Loki (`{job="nginx"}`): il grafico dei log si è fermato, ma il sito risponde.*

<details><summary>da dove cominciare</summary>

Risali la catena dalla **sorgente**: nginx scrive ancora il file di log (`wc -l /var/log/nginx/access.log` prima e dopo una richiesta)? Se il file non cresce, Loki non c'entra.
</details>
<details><summary>soluzione</summary>

```bash
curl -s -o /dev/null -A prova http://localhost/; sleep 6
curl -s -G http://loki:3100/loki/api/v1/query_range --data-urlencode 'query={job="nginx"} |= "prova"' \
     --data-urlencode "start=$(date -d '-3 min' +%s)000000000" | jq -c '.data.result|length'
# 0                                              <- Loki non ha niente
wc -l /var/log/nginx/access.log; curl -s -o /dev/null http://localhost/; wc -l /var/log/nginx/access.log
# 78 /var/log/nginx/access.log
# 78 /var/log/nginx/access.log                   <- il file non cresce: nginx non scrive il log
nginx -T 2>/dev/null | grep -n 'access_log'
# 41:	access_log /var/log/nginx/access.log;
# 196:access_log off;                               <- una riga in più, in un file incluso più in basso
```
Il guasto è **prima** di Loki: nginx non scrive più l'access log, per un `access_log off;` in un file incluso (`nginx -T` mostra la configurazione completa, con tutti i file). Alloy e Loki non hanno niente da leggere. Si toglie la riga e si ricarica:
```bash
rm /etc/nginx/conf.d/zz-scenario.conf
nginx -t 2>&1 | tail -1
# nginx: configuration file /etc/nginx/nginx.conf test is successful
nginx -s reload; sleep 2
wc -l /var/log/nginx/access.log; curl -s -o /dev/null http://localhost/; wc -l /var/log/nginx/access.log
# 78 /var/log/nginx/access.log
# 79 /var/log/nginx/access.log
```
Le nuove righe arrivano in Loki in pochi secondi. Riavviare nginx (`systemctl restart nginx`) non basta: la riga è ancora nella configurazione. Il reload è **asincrono**: i vecchi processi servono ancora per un istante, per questo si aspetta un attimo prima di riprovare. Vedi Alloy e `loki.source.file` in [07-loki](07-loki.md).
</details>

## 7. Una data source di Grafana che non risponde
**Ticket**: *In Grafana la data source "Prometheus (prod)" (uid `prometheus-prod`) non funziona: i pannelli che la usano mostrano errori.*

<details><summary>da dove cominciare</summary>

Grafana ha un'API anche per **provare** una data source (`/api/datasources/uid/UID/health`, utente `admin` / `laboratorio`). Il messaggio dice a quale indirizzo sta provando a collegarsi.
</details>
<details><summary>soluzione</summary>

```bash
G="-u admin:laboratorio http://grafana:3000/api"
curl -s $G/datasources/uid/prometheus-prod/health | jq -c .
# {"message":"Post \"http://prometheus:9091/api/v1/query\": dial tcp 172.21.0.10:9091: connect: connection refused - There was an error returned querying the Prometheus API.","status":"ERROR"}
curl -s $G/datasources/uid/prometheus-prod | jq -c '{name,url}'
# {"name":"Prometheus (prod)","url":"http://prometheus:9091"}
```
La data source punta alla porta `9091`; Prometheus risponde sulla `9090`. Anche qui `connection refused`: il nome c'è, la porta no. Si aggiorna l'URL con l'API (`PUT`):
```bash
curl -s $G/datasources/uid/prometheus-prod -X PUT -H 'content-type: application/json' \
     -d '{"name":"Prometheus (prod)","uid":"prometheus-prod","type":"prometheus","access":"proxy","url":"http://prometheus:9090"}' | jq -c .message
# "Datasource updated"
curl -s $G/datasources/uid/prometheus-prod/health | jq -c .status
# "OK"
```
(Dopo una modifica Grafana può impiegare qualche secondo ad accorgersene: in una prova, un `health` fatto subito dopo il `PUT` mostrava ancora l'errore vecchio, in un'altra era subito `OK`. `controlla` aspetta fino a 12 secondi.) Cancellare la data source non è una riparazione: i pannelli non avrebbero più niente a cui chiedere. Questa data source è stata aggiunta apposta con l'API; le altre (Prometheus, Loki, Tempo) vengono da file di provisioning (vedi [06-grafana](06-grafana.md)): se si possano modificare dall'API non è stato provato.
</details>

## 8. La metrica che non compare
**Ticket**: *`lavoro/scrivi-metrica.sh` scrive la metrica `ordini_totale` per node_exporter, ma in Prometheus la metrica non compare.*

<details><summary>da dove cominciare</summary>

node_exporter legge i file `.prom` del *textfile collector*. Guarda se **dice qualcosa** quando non riesce: una metrica di sé stesso (`node_textfile_scrape_error`) e il suo log (`journalctl -u node_exporter`).
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/09-scenari/lavoro
bash scrivi-metrica.sh; cat /var/lib/node_exporter/textfile/ordini.prom
# # TYPE ordini_totale counter
# ordini_totale{stato=pagato} 42
curl -s localhost:9100/metrics | grep -E 'ordini_totale|^node_textfile_scrape_error'
# node_textfile_scrape_error 1                    <- il collector ha fallito, e non c'è nessuna riga ordini_totale
journalctl -u node_exporter --no-pager -n 3 | cut -c1-200
# ... level=ERROR source=textfile.go:242 msg="failed to collect textfile data" collector=textfile file=ordini.prom err="failed to pars...
```
Il file non è nel formato di Prometheus: il valore di un'etichetta va **tra virgolette** (`stato="pagato"`), e `stato=pagato` non è valido. Con un file sbagliato il collector scarta il file **intero** e alza `node_textfile_scrape_error`: la metrica non compare, senza altri segni. Si corregge lo script e lo si rilancia:
```bash
sed -i 's/{stato=pagato}/{stato="pagato"}/' scrivi-metrica.sh
bash scrivi-metrica.sh
curl -s localhost:9100/metrics | grep -E 'ordini_totale|^node_textfile_scrape_error'
# node_textfile_scrape_error 0
# # HELP ordini_totale Metric read from /var/lib/node_exporter/textfile/ordini.prom
# # TYPE ordini_totale counter
# ordini_totale{stato="pagato"} 42
```
Cambiare il valore (`42` in `43`) non serve: il guasto è l'etichetta. `node_textfile_scrape_error` è la prima cosa da guardare quando una metrica del textfile non compare: conviene anche un alert su di essa. Vedi il textfile collector in [03-exporter](03-exporter.md).
</details>

---

## Riepilogo: come si riconosce
| Sintomo | Anello | Prima mossa |
|---|---|---|
| `up` vale 0 | raccolta | `/api/v1/targets` → `lastError` (1) |
| un alert non scatta mai | calcolo | l'espressione da sola nell'API: vuota = metrica che non esiste (2) |
| un contatore che sale e basta | calcolo | `rate()` / `increase()` (3) |
| l'alert va alla persona sbagliata | allarme | `amtool config routes test` (4) |
| "ho ricaricato ma non cambia" | allarme | il codice HTTP del reload, `amtool check-config` (5) |
| i log si fermano | sorgente | il file di log cresce? `nginx -T` (6) |
| Grafana: pannelli con errori | destinatario | `/api/datasources/uid/UID/health` (7) |
| una metrica non compare | sorgente | `node_textfile_scrape_error`, il log di node_exporter (8) |

## Non provato
- Gli scenari agiscono su **Prometheus, Alertmanager, Loki, Grafana, nginx e node_exporter**: non c'è uno scenario sulle **tracce** (Tempo, Jaeger, Alloy come collector OTLP), né su Alloy o Loki stessi (le loro configurazioni non sono modificabili dal `server`).
- Gli scenari 4 e 5 sono provati con l'email in Mailpit; `controlla` usa l'API di Mailpit (`/api/v1/messages`).
- Le soglie e le durate sono quelle basse del laboratorio (`for: 0s`, valutazione ogni 10 secondi): in produzione servono minuti per vedere scattare un alert.
- Il tempo per risolvere uno scenario non è stato misurato su una persona.

Torna all'[indice dell'area](README.md)
