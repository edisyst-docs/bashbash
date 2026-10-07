# Laboratorio dell'area 12

Un server da monitorare e tutto lo stack intorno, descritto da [compose.yaml](compose.yaml):
```
 server (si entra qui) ─┬─ node_exporter :9100  <─────────────── prometheus :9090 ──> alertmanager :9093 ──> mailpit :8025
  systemd, nginx :80    ├─ stub_status :8000 <── nginx-exporter <──┤      ▲                (email)
  /dati da 64 MB        ├─ :80, :22  <────────── blackbox  <───────┘      └── grafana :3000
  /var/log ─────────────└────────────────────────── alloy :12345 ──push──> loki :3100 <──── grafana
                                                  alloy :4318 (OTLP) ──> tempo :3200 <──── grafana  (e jaeger :16686)
```

| Container | Cosa è |
|---|---|
| `server` | Ubuntu con systemd (immagine `bashbash-osservabilita`, stadio del [Dockerfile](../../Dockerfile)): node_exporter installato come servizio, nginx, ssh, `stress-ng`, `promtool` e `amtool`. `/dati` è un tmpfs da 64 MB da riempire |
| `prometheus` | legge tutti gli altri ogni 10 s, valuta le regole in [config/prometheus/regole/](config/prometheus/regole/) |
| `alertmanager` | instrada gli alert: warning a `squadra@lab.local`, critical a `reperibile@lab.local` |
| `blackbox` | controlla da fuori `http://server/`, `http://grafana:3000/api/health` e `server:22` |
| `nginx-exporter` | traduce lo `stub_status` di nginx in metriche |
| `loki` | riceve e salva i log mandati da Alloy; configurazione in [config/loki/](config/loki/) |
| `alloy` | legge journal e log nginx dal server e li manda a Loki; è anche il Collector OpenTelemetry: riceve le tracce (OTLP, `:4317` e `:4318`) e le manda a Tempo e a Jaeger; configurazione in [config/alloy/](config/alloy/) |
| `tempo` | conserva le tracce e le cerca con TraceQL; configurazione in [config/tempo/](config/tempo/) |
| `jaeger` | interfaccia e API per cercare le tracce (archivio in memoria) |
| `grafana` | data source e dashboard *Server* caricate da [config/grafana/](config/grafana/); data source Loki, Prometheus e Tempo |
| `mailpit` | un finto server di posta: raccoglie le email degli alert e le mostra nel browser |
| `config` | parte, copia [config/](config/) nel volume condiviso e termina |

La configurazione di Prometheus e Alertmanager sta in un volume montato sul server in `/etc/monitoring`: si modifica
da lì e si ricarica con `curl -X POST http://prometheus:9090/-/reload` (o `alertmanager:9093`). La KB resta intatta;
all'uscita il volume sparisce e si riparte dai file di [config/](config/).

## Avvio
Dalla radice della KB:
```bash
./lab.sh 12               # la prima volta costruisce l'immagine e scarica le altre (qualche minuto)
cd 05-alerting && ./scenari.sh nginx
```
Dal browser del PC:

| Indirizzo | Cosa |
|---|---|
| http://localhost:9090 | Prometheus: *Query*, *Alerts*, *Status > Target health* |
| http://localhost:9093 | Alertmanager: alert, raggruppamenti, silenzi |
| http://localhost:3000 | Grafana, `admin` / `laboratorio` (senza login si guarda soltanto): *Dashboards > Laboratorio > Server* |
| http://localhost:3100 | Loki: `curl localhost:3100/ready`, `curl localhost:3100/loki/api/v1/labels` |
| http://localhost:3200 | Tempo: `curl localhost:3200/ready`, `curl localhost:3200/api/search/tags` |
| http://localhost:16686 | Jaeger: interfaccia web, API su `/api/v3/services` |
| localhost:4317, :4318 | OTLP (gRPC e HTTP) di Alloy: ci si manda le tracce dal PC |
| http://localhost:12345 | Alloy: grafo dei componenti e loro stato |
| http://localhost:8025 | Mailpit: le email degli alert |

Per spegnere tutto basta uscire dalla shell: container e volumi vengono eliminati.
Le porte devono essere libere sul PC: se una è occupata `lab.sh` si ferma con `port is already allocated`.
Servono circa 1 GB di RAM.

## Cosa si prova e dove

[prepara.sh](prepara.sh) gira sul `server` (lo lancia `lab.sh`) e crea in `~/lab` una cartella per ogni `.md` dell'area, con gli script
elencati qui sotto. Per ripartire da zero senza uscire: `bash /kb/12-osservabilita/lab/prepara.sh && cd ~/lab`.

| Cartella | File pronti | Note |
|---|---|---|
| `01-concetti/` | nessuno | si guarda `curl -s localhost:9100/metrics \| less` per vedere il formato |
| `02-prometheus/` | `config` (link a `/etc/monitoring`), `api.sh` | `./api.sh 'QUERY'` interroga l'API e stampa una serie per riga |
| `03-exporter/` | `backup.sh` | backup finto che scrive le sue metriche nel textfile collector; `./backup.sh rotto` fallisce |
| `04-promql/` | `query.txt`, `api.sh`, `traffico.sh` | `./traffico.sh 120 30`: 30 richieste al secondo a nginx per 2 minuti, poi le query su nginx |
| `05-alerting/` | `scenari.sh`, `test-regole.yml`, `backup.sh` | un guasto alla volta (tabella in [05-alerting.md](../05-alerting.md)); `promtool test rules test-regole.yml` |
| `06-grafana/` | nessuno | si lavora dal browser; API con `curl -u admin:laboratorio http://grafana:3000/api/...` |
| `07-loki/` | `query.sh`, `push.sh`, `config` (link) | `./query.sh '{job="nginx"}'`; `./push.sh "messaggio"`; `logcli labels` |
| `08-tracing/` | `traccia.sh`, `app.py` | `./traccia.sh ok|lenta|errore` manda una traccia di tre servizi ad Alloy (`:4318`); `app.py` è un'app Python strumentata (serve `python3-venv` e `pip install opentelemetry-sdk opentelemetry-exporter-otlp-proto-http`) |

Da sapere:
- node_exporter nel container vede CPU e memoria del PC (o della VM di Docker Desktop): `./scenari.sh cpu` carica
  davvero tutti i core per due minuti e mezzo, e la RAM mostrata è quella della macchina
- i filesystem montati da Docker (`/kb`, `/etc/hosts`, `/etc/monitoring`) sono dischi del PC: le regole sul disco
  li escludono, conta `/dati`
- soglie e durate sono basse apposta (CPU 80% per 1 minuto, backup vecchio dopo 2 minuti) per vedere gli alert
  scattare subito; in produzione si alzano
- nel compose `dns_search: .` toglie il dominio di ricerca del PC: in una rete aziendale `server` potrebbe diventare
  `server.azienda.local` e risolversi verso una macchina vera

## 09-scenari
`09-scenari/` ha `scenari.sh`, che lancia [scenari.sh](scenari.sh) (qui in `lab/`, con i guasti dentro; non è lo `scenari.sh` di `05-alerting/`, che provoca alert): `./scenari.sh guasta N` riporta tutto in salute (ricopia la configurazione di Prometheus e Alertmanager da [config/](config/), toglie i file di prova, svuota Mailpit) e rompe come lo scenario N (8 in tutto) stampando il sintomo; `controlla` dice se è sparito, **provandolo dal vero** (un alert di prova e l'email in Mailpit, una richiesta a nginx e la riga in Loki, un'interrogazione a Grafana); `ripristina` toglie ogni guasto.
I guasti: la porta sbagliata di un target, un nome di metrica con una lettera di meno in una regola, uno script che legge un contatore senza `rate()`, un matcher di Alertmanager con una lettera di differenza, un `alertmanager.yml` con un errore di YAML (il reload fallisce con HTTP 500), `access_log off` in nginx, una data source Grafana con la porta sbagliata, un file `.prom` con l'etichetta senza virgolette. Le riparazioni di riferimento e i tentativi che non bastano (ricaricare senza correggere, liberare il disco, `increase()` al posto di `rate()`, riavviare nginx, cancellare la data source...) sono in [scenari-soluzioni.sh](scenari-soluzioni.sh); [scenari-autotest.sh](scenari-autotest.sh) rompe, prova le scorciatoie e ripara ogni scenario (circa 6 minuti: i controlli veri aspettano fino a 30 secondi), e deve dire che tutti i controlli sono ok (lo lancia la CI).
Da sapere, trovato provando: `nginx -s reload` è asincrono, e una richiesta subito dopo può essere servita ancora dai vecchi processi (con `access_log off` finisce nel log); dopo un `PUT` a una data source Grafana l'esito di `health` può restare quello vecchio per qualche secondo.

Torna all'[indice dell'area](../README.md)
