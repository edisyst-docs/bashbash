# PromQL

> **Laboratorio**: `./lab.sh 12`, poi `cd 04-promql`. Cosa contiene: [lab/](lab/).

Il linguaggio delle query di Prometheus: lo usano l'interfaccia (*Query*), Grafana, le regole di alert e l'API.
Nel laboratorio `query.txt` ha una query per riga da provare con `./api.sh 'QUERY'` o nella scheda *Query* di
http://localhost:9090 (con *Graph* si vede l'andamento). `./traffico.sh 120` manda richieste a nginx, così le query
su nginx hanno qualcosa da mostrare.
Documentazione: https://prometheus.io/docs/prometheus/latest/querying/basics/

## Tipi di risultato
| Tipo | Cos'è | Esempio |
|---|---|---|
| **instant vector** | un valore per serie, all'istante della query | `up` |
| **range vector** | per ogni serie, i campioni di una finestra di tempo | `up[5m]` |
| **scalar** | un numero | `time()`, `42` |

Un grafico è una sequenza di instant vector, uno per ogni punto. Un range vector non si può disegnare: si passa a
una funzione (`rate`, `avg_over_time`...) che lo riduce a un instant vector.

## Selettori
```promql
node_load1                                     # tutte le serie con quel nome
node_load1{instance="server:9100"}             # = uguale
node_cpu_seconds_total{mode!="idle"}           # != diverso
node_filesystem_avail_bytes{mountpoint=~"/|/dati"}       # =~ regex (sempre ancorata: deve combaciare tutta)
node_network_receive_bytes_total{device!~"lo|veth.*"}    # !~ regex negata
{job="node", __name__=~"node_memory_.*_bytes"}           # il nome è l'etichetta __name__
node_load1 offset 1h                           # il valore di un'ora fa
node_load1 @ 1790940000                        # il valore a un istante preciso (Unix time)
```

## Counter: rate, irate, increase
Un counter cresce sempre e torna a 0 quando il processo riparte; da solo non dice niente. Si guarda quanto cresce:
```promql
rate(nginx_http_requests_total[5m])            # al secondo, media sugli ultimi 5 minuti
irate(nginx_http_requests_total[5m])           # al secondo, solo dagli ultimi due campioni: picchi, più nervoso
increase(nginx_http_requests_total[1h])        # quanto è cresciuto in un'ora (= rate * 3600)
```
Tutte e tre gestiscono da sole i riavvii (il counter che torna a 0). Regole:
- la finestra deve contenere almeno 4 campioni: con `scrape_interval: 15s` almeno `[1m]`. In Grafana si usa
  `$__rate_interval`, che sceglie lei
- prima `rate`, poi `sum`: `sum(rate(x[5m]))`, mai `rate(sum(x)[5m])` (la somma nasconde i riavvii)
- `rate` su un gauge non ha senso: per un gauge che cresce si usa `deriv()` o `delta()`

## Operatori
```promql
node_memory_MemAvailable_bytes / 1024 / 1024                   # aritmetica: + - * / % ^
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes    # fra due vettori: serie con le stesse etichette
node_load1 > 2                                 # filtro: restano solo le serie sopra 2, con il loro valore
node_load1 > bool 2                            # niente filtro: 1 o 0 per ogni serie
up == 0
a and b      a or b      a unless b            # insiemi: serie di a che hanno (o non hanno) una gemella in b
```
Quando le etichette dei due lati non coincidono, si dice su quali accoppiare:
```promql
# load per core: a sinistra ci sono job e host, a destra solo instance
node_load1 / on (instance) count by (instance) (node_cpu_seconds_total{mode="idle"})
# ignoring: accoppia ignorando quelle etichette
rate(errori_total[5m]) / ignoring (codice) group_left rate(richieste_total[5m])
```
`group_left` / `group_right` servono quando un lato ha più serie per ogni serie dell'altro (molti a uno). Uso tipico:
portare un'etichetta "informativa" su un'altra metrica:
```promql
node_load1 * on (instance) group_left (nodename) node_uname_info     # node_uname_info vale 1: aggiunge nodename
```

## Aggregazioni
```promql
sum(rate(nginx_http_requests_total[5m]))                 # un numero solo
sum by (job) (up)                                        # una serie per job
avg without (cpu) (rate(node_cpu_seconds_total[1m]))     # toglie l'etichetta cpu, tiene le altre
count by (job) (up == 1)                                 # quanti bersagli su per job
max by (instance) (node_filesystem_size_bytes)
topk(3, rate(prometheus_http_requests_total[5m]))        # le 3 serie più alte
bottomk(1, node_filesystem_avail_bytes)
count_values("versione", node_exporter_build_info)        # quante istanze per versione
quantile(0.9, rate(node_cpu_seconds_total{mode="user"}[5m]))
```
`by` tiene solo le etichette elencate, `without` toglie quelle elencate e tiene il resto.

## Funzioni
```promql
avg_over_time(node_load1[10m])                 # media, max, min, sum, count di un range: *_over_time
max_over_time(probe_duration_seconds[1h])
quantile_over_time(0.95, probe_duration_seconds[1h])
predict_linear(node_filesystem_avail_bytes[6h], 24*3600)  # il valore fra 24 ore, se continua così (regressione lineare)
deriv(node_filesystem_avail_bytes[1h])         # di quanto cambia al secondo un gauge
changes(node_boot_time_seconds[1d])            # quante volte è cambiato: qui, riavvii in un giorno
resets(node_cpu_seconds_total[1d])             # quante volte un counter è tornato a 0
time() - node_boot_time_seconds                # uptime in secondi
time() - backup_ultimo_successo_timestamp_seconds        # età dell'ultimo backup
absent(up{job="node"})                         # 1 se NON esiste nessuna serie: per accorgersi di ciò che manca
absent_over_time(backup_ultimo_successo_timestamp_seconds[1d])
clamp_min(x, 0)  clamp_max(x, 1)  abs(x)  round(x, 0.1)  ceil(x)  floor(x)
label_replace(up, "host", "$1", "instance", "([^:]+):.*")  # nuova etichetta host presa da instance con una regex
sort_desc(sum by (job) (scrape_samples_scraped))
```

### Istogrammi e percentili
Un histogram espone counter per fasce cumulative: `_bucket{le="0.1"}` conta le richieste durate ≤ 0,1 s,
`le="+Inf"` le conta tutte.
```promql
# il 95° percentile della durata delle richieste all'API di Prometheus negli ultimi 5 minuti
histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
# per handler: "le" va sempre tenuto nel by
histogram_quantile(0.95, sum by (le, handler) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
# durata media
rate(prometheus_http_request_duration_seconds_sum[5m]) / rate(prometheus_http_request_duration_seconds_count[5m])
# quota di richieste sotto 0,1 s (un SLI)
sum(rate(prometheus_http_request_duration_seconds_bucket{le="0.1"}[5m])) / sum(rate(prometheus_http_request_duration_seconds_count[5m]))
```
Il percentile è una stima: interpola dentro la fascia, quindi è preciso quanto lo sono i bucket.
La media nasconde i casi lenti: per la latenza si guardano p50, p95, p99.

## Query di tutti i giorni
```promql
# CPU usata in %, per server
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))
# CPU per modo: alto iowait = disco lento, alto steal = l'hypervisor toglie CPU alla VM
sum by (mode) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))
# memoria usata in % (MemAvailable, non MemFree: la cache del disco si libera quando serve)
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
# swap usato
node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes
# disco pieno in %, senza i filesystem finti
100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes)
# inode
1 - node_filesystem_files_free / node_filesystem_files
# fra quante ore si riempie (negativo = si sta svuotando)
node_filesystem_avail_bytes / -deriv(node_filesystem_avail_bytes[6h]) / 3600
# disco occupato (come %util di iostat)
rate(node_disk_io_time_seconds_total[5m])
# traffico di rete in Mbit/s
rate(node_network_receive_bytes_total{device!="lo"}[5m]) * 8 / 1e6
# errori HTTP 5xx in % (con un exporter o un'app che ha l'etichetta status)
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
# unit systemd fallite
node_systemd_unit_state{state="failed"} == 1
# giorni alla scadenza del certificato
(probe_ssl_earliest_cert_expiry - time()) / 86400
# server riavviati nell'ultima ora
changes(node_boot_time_seconds[1h]) > 0
# bersagli giù
up == 0
```

## Recording rule
Una query costosa o usata in molti posti si fa calcolare a Prometheus a ogni `evaluation_interval` e si salva come
serie nuova. Le dashboard diventano più veloci e gli alert più leggibili.
[lab/config/prometheus/regole/registrazione.yml](lab/config/prometheus/regole/registrazione.yml):
```yaml
groups:
  - name: registrazione
    rules:
      - record: instance:node_cpu_utilizzo:ratio      # convenzione: livello:metrica:operazioni
        expr: 1 - avg by (instance, host) (rate(node_cpu_seconds_total{mode="idle"}[1m]))
```
```bash
./api.sh 'instance:node_cpu_utilizzo:ratio'
```
