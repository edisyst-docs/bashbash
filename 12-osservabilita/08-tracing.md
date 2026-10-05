# Tracing: OpenTelemetry, Tempo e Jaeger

> **Laboratorio**: `./lab.sh 12`, poi `cd 08-tracing`. File pronti: `traccia.sh`, `app.py` (vedi [lab/](lab/)).

Le metriche dicono **che** una richiesta è lenta, i log **cosa** è successo in un punto. Una **traccia** dice **dove**: segue una singola richiesta attraverso tutti i servizi che tocca e misura quanto tempo passa in ciascuno.
Su un sito con un frontend, un'API e un database, la traccia di `GET /ordini/42` mostra che i 2 secondi sono quasi tutti nella query SQL, e non nell'API.
Gli esempi sono stati eseguiti nel laboratorio con Grafana Alloy 1.20.1 (come OpenTelemetry Collector), Grafana Tempo 3.0.0, Jaeger 2.21.0 e l'SDK Python di OpenTelemetry 1.45.

## I concetti
```
frontend   GET /ordini/42 ─────────────────────────────────────────── 140 ms   <- span radice
  api        GET /ordini/{id} ─────────────────────────────────────── 135 ms
    api        SELECT ordini ───────── 60 ms                                    <- span figlio (db)
    api        POST /pagamenti/verifica ──── 40 ms
```
| Termine | Cosa è |
|---|---|
| **trace** (traccia) | l'insieme degli span di **una** richiesta, con un **trace ID** di 16 byte (32 cifre esadecimali) |
| **span** | una operazione con inizio, fine, nome, attributi, stato (`OK`/`ERROR`) e un **parent** (lo span che l'ha chiamata); quello senza parent è la radice |
| **attributi** | coppie chiave/valore sullo span (`http.route`, `db.system`, `db.statement`); quelli sul **servizio** (`service.name`) sono nella *resource* |
| **kind** | il ruolo: `SERVER` (riceve), `CLIENT` (chiama), `INTERNAL`, `PRODUCER`/`CONSUMER` (code di messaggi) |
| **event** | un punto nel tempo dentro uno span (`ordine creato`, un'eccezione) |
| **context propagation** | il passaggio del trace ID e dello span ID da un servizio al successivo, in un header HTTP: `traceparent: 00-<trace id>-<span id>-<flag>` ([W3C Trace Context](https://www.w3.org/TR/trace-context/)) |
| **sampling** | quali tracce tenere: una su dieci, o solo quelle lente e in errore |

**OpenTelemetry** (OTel) è lo standard per produrre e trasportare la telemetria, indipendente dal prodotto che la conserva: SDK per ogni linguaggio, il protocollo **OTLP** (gRPC sulla porta `4317`, HTTP sulla `4318`)
e il **Collector**. Un'applicazione strumentata con OTel può mandare le tracce a Tempo, a Jaeger o a un servizio a pagamento cambiando solo l'indirizzo.

## L'architettura del laboratorio
```
app / traccia.sh ──OTLP──> alloy :4318 ──batch──┬──> tempo :3200   (conserva, TraceQL)     <── Grafana (datasource Tempo)
                           (collector)          └──> jaeger :16686 (interfaccia, API)
```
- **Alloy** ([07-loki.md](07-loki.md) lo usa per i log) è anche un OpenTelemetry Collector: riceve OTLP, elabora e inoltra. Nel laboratorio un solo ricevitore, un `batch` e due esportatori, uno per destinazione.
- **Tempo** conserva le tracce e le cerca con il linguaggio **TraceQL**; conserva i blocchi in formato colonnare su un archivio a oggetti, senza un indice per attributo (la ricerca per ID è immediata, quella per attributi è più lenta). È il "Loki delle tracce".
- **Jaeger** è l'alternativa più diffusa: la sua interfaccia è la più usata per guardare una traccia. Qui riceve la stessa copia, per confrontare i due.
- In produzione l'applicazione manda spesso **direttamente** al Collector del suo nodo o del cluster, e il Collector ai prodotti: l'applicazione non conosce Tempo né Jaeger.

La configurazione di Alloy è in [lab/config/alloy/config.alloy](lab/config/alloy/config.alloy), in fondo:
```
otelcol.receiver.otlp "default" {
    grpc { endpoint = "0.0.0.0:4317" }
    http { endpoint = "0.0.0.0:4318" }
    output { traces = [otelcol.processor.batch.default.input] }
}
otelcol.processor.batch "default" {
    timeout = "2s"                                    // invia dopo 2 secondi anche se il lotto non è pieno
    output { traces = [otelcol.exporter.otlp.tempo.input, otelcol.exporter.otlp.jaeger.input] }
}
otelcol.exporter.otlp "tempo"  { client { endpoint = "tempo:4317"  tls { insecure = true } } }
otelcol.exporter.otlp "jaeger" { client { endpoint = "jaeger:4317" tls { insecure = true } } }
```
La stessa catena si legge in Alloy, `http://localhost:12345`, come grafo di componenti. Le metriche del collector sono su `http://alloy:12345/metrics`:
```bash
curl -s http://alloy:12345/metrics | grep -E '^otelcol_(receiver_accepted_spans|exporter_sent_spans)_total' | sed 's/{.*}/ /'
# otelcol_exporter_sent_spans_total  24            <- una riga per esportatore: tempo e jaeger
# otelcol_exporter_sent_spans_total  24
# otelcol_receiver_accepted_spans_total  24
curl -s http://tempo:3200/metrics | grep '^tempo_distributor_spans_received_total'
# tempo_distributor_spans_received_total{tenant="single-tenant"} 32        <- 24 da Alloy + 8 del test di campionamento (sotto), che andava a Tempo senza passare da qui
```
Se i due contatori di Alloy divergono, gli span si perdono tra collector e destinazione. Dal PC (porte pubblicate): Tempo `http://localhost:3200`, Jaeger `http://localhost:16686`, OTLP `localhost:4317` e `4318`.

## Mandare una traccia a mano
OTLP/HTTP accetta anche **JSON**: basta `curl`. `traccia.sh` costruisce una traccia di tre servizi (`frontend` → `api` → database) e la manda ad Alloy:
```bash
cd ~/lab/08-tracing
./traccia.sh ok
# OTLP: HTTP 200
# traccia: bae335f386520c98c6515f9a36b953df (ok, 140 ms)
./traccia.sh errore                  # la query fallisce: span in errore, risposta 500
# traccia: 2e5bf440a7ec041a44f529c87a77e5ef (errore, 110 ms)
./traccia.sh lenta                   # la query dura 2 secondi
# traccia: ddf8a938e62f4e34331beef1ef0314ce (lenta, 2080 ms)
```
Il cuore del messaggio (un solo span, dal corpo dello script):
```bash
curl -s -X POST http://alloy:4318/v1/traces -H 'Content-Type: application/json' -d '{
 "resourceSpans": [{
   "resource":   {"attributes": [{"key":"service.name","value":{"stringValue":"frontend"}}]},
   "scopeSpans": [{"spans": [{
       "traceId": "bae335f386520c98c6515f9a36b953df",       // 32 cifre esadecimali
       "spanId":  "1111111111111111",                       // 16 cifre
       "parentSpanId": "...",                               // assente nella radice
       "name": "GET /ordini/42", "kind": 2,                 // 1 internal, 2 server, 3 client
       "startTimeUnixNano": "1791221991000000000", "endTimeUnixNano": "1791221991140000000",
       "attributes": [{"key":"http.response.status_code","value":{"intValue":"200"}}],
       "status": {"code": 2, "message": "..."}              // 0 non impostato, 1 OK, 2 ERROR
   }]}]
 }]}'
# {"partialSuccess":{}}        <- risposta di un OTLP accettato (qui con l'HTTP 200)
```
(Il commento `//` non è JSON valido: nell'esempio reale non c'è.) Gli ID nel JSON vanno scritti in **esadecimale**; i timestamp sono in **nanosecondi** dall'epoca, come stringhe.

## Tempo: cercare e leggere
### Per ID
```bash
curl -s http://tempo:3200/api/traces/ddf8a938e62f4e34331beef1ef0314ce | jq -c '[.batches[]|{svc:(.resource.attributes[]|select(.key=="service.name")|.value.stringValue), spans:[.scopeSpans[].spans[]|.name]}]'
# [{"svc":"frontend","spans":["GET /ordini/42"]},{"svc":"api","spans":["GET /ordini/{id}","SELECT ordini","POST /pagamenti/verifica"]}]
curl -s http://tempo:3200/api/v2/traces/ddf8a938e62f4e34331beef1ef0314ce | jq -c 'keys'
# ["metrics","trace"]
```
La risposta di Tempo ha gli ID **in base64** (`"spanId":"ERERERERERE="`, per `1111111111111111`) e non in esadecimale: se si confrontano a occhio con quelli scritti dall'app sembrano diversi. Per decodificare:
`echo ERERERERERE= | base64 -d | od -An -tx1`. Per ID la traccia è **disponibile subito**.

### Con TraceQL
La **ricerca** è meno immediata: la traccia compare dopo un po' (**31 secondi** nel laboratorio, misurato con `{ trace:id = "..." }`). Fino ad allora la ricerca per ID risponde, quella per attributi no.
```bash
q() { curl -s -G http://tempo:3200/api/search --data-urlencode "q=$1" | jq -c '[.traces[]?|{traceID,rootServiceName,rootTraceName,durationMs}]'; }
q '{ duration > 1s }'
# [{"traceID":"ddf8a938e62f4e34331beef1ef0314ce","rootServiceName":"frontend","rootTraceName":"GET /ordini/42","durationMs":2080}]
q '{ status = error }'
# [{"traceID":"2e5bf440a7ec041a44f529c87a77e5ef","rootServiceName":"frontend","rootTraceName":"GET /ordini/42","durationMs":110}]
q '{ resource.service.name = "api" && span.db.system = "postgresql" }'      # tutte e tre
q '{ span.http.response.status_code >= 500 }'
```
TraceQL è come LogQL ([07-loki.md](07-loki.md)) e PromQL ([04-promql.md](04-promql.md)): le graffe contengono le **condizioni su uno span**, e un prefisso dice dove cercare:

| Scritto | Significato |
|---|---|
| `duration`, `name`, `status`, `kind` | proprietà dello **span** (`status = error`, `duration > 500ms`) |
| `span.db.system` | un **attributo dello span** |
| `resource.service.name` | un attributo della **risorsa** (il servizio) |
| `rootName`, `traceDuration` | proprietà della **traccia intera** |
| `{ A } >> { B }` | operatore strutturale: uno span B **discendente** di uno span A |
| `{ ... } \| count() > 2` | una pipeline: conta gli span che corrispondono |
| `{ ... } \| select(span.db.statement, duration)` | aggiunge colonne al risultato |
| `{ ... } \| rate()` | una **metrica** dalle tracce (richieste al secondo), con `/api/metrics/query_range` |

```bash
q '{ resource.service.name = "frontend" } >> { span.db.system = "postgresql" && duration > 1s }'
# la traccia lenta: solo se la query db LENTA è dentro una richiesta del frontend
q '{ span.db.system = "postgresql" } | count() > 0'          # 4 tracce
curl -s -G http://tempo:3200/api/search --data-urlencode 'q={ name =~ "SELECT.*" } | select(span.db.statement, duration)' | jq -c '.traces[0].spanSets[0].spans[0]|{name,durationNanos}'
# {"name":"SELECT ordini","durationNanos":"60000000"}
curl -s http://tempo:3200/api/search/tags | jq -c '.tagNames'
# ["db.statement","db.system","http.request.method","http.response.status_code","http.route","service.name"]
curl -s http://tempo:3200/api/search/tag/service.name/values | jq -c .tagValues
# ["api","frontend"]
curl -s -G http://tempo:3200/api/metrics/query_range --data-urlencode 'q={ resource.service.name = "frontend" } | rate()' \
     --data-urlencode "start=$(( $(date +%s) - 900 ))" --data-urlencode "end=$(date +%s)" --data-urlencode step=300 | jq -c '.series[0]|{labels, n:(.samples|length)}'
# {"labels":[{"key":"__name__","value":{"stringValue":"rate"}}],"n":4}
```
Le ricerche tornano anche `spanSets` (gli span che corrispondono) e la durata; `limit` mette un tetto alle tracce restituite. `curl http://tempo:3200/ready` risponde `ready` quando il servizio è pronto
(l'immagine è senza shell né `wget`: nel `compose.yaml` non c'è un healthcheck).

## Jaeger
Jaeger 2.x ha la sua API su `/api/v3` (il vecchio `/api/services` risponde 404):
```bash
curl -s http://jaeger:16686/api/v3/services | jq -c .
# {"services":["frontend","api","jaeger"]}                  <- "jaeger" è il servizio di Jaeger stesso
curl -s 'http://jaeger:16686/api/v3/operations?service=api' | jq -c .
# {"operations":[{"name":"GET /ordini/{id}","spanKind":"server"},{"name":"SELECT ordini","spanKind":"client"},{"name":"POST /pagamenti/verifica","spanKind":"client"}]}
curl -s -G http://jaeger:16686/api/v3/traces --data-urlencode 'query.service_name=api' --data-urlencode 'query.operation_name=SELECT ordini' \
     --data-urlencode "query.start_time_min=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)" --data-urlencode "query.start_time_max=$(date -u -d '+1 min' +%Y-%m-%dT%H:%M:%SZ)" \
     | jq -c '[.result.resourceSpans[]?|.scopeSpans[]?.spans[]?|.name]'
```
La ricerca di Jaeger è per **servizio**, operazione, tag e durata minima; è quella che si usa dall'interfaccia (`http://localhost:16686`, non aperta in questo laboratorio dal terminale). Il Jaeger del laboratorio usa la configurazione predefinita dell'immagine (archivio in
memoria: un riavvio, non provato, dovrebbe perdere le tracce).

| | Tempo | Jaeger |
|---|---|---|
| Ricerca | TraceQL su span, attributi, strutture | per servizio, operazione, tag, durata |
| Archivio | oggetti (S3, GCS, disco): molto economico, scala su grandi volumi | memoria, Cassandra, Elasticsearch/OpenSearch, ClickHouse |
| In Grafana | datasource nativo, collegato a Loki e Prometheus | datasource Jaeger |
| Interfaccia propria | no (si usa Grafana) | sì, con confronto fra tracce e grafo delle dipendenze |

## Strumentare un'applicazione (Python)
`app.py` ha due "servizi" (`ordini` e `magazzino`) in un solo processo, con la **propagazione del contesto** fra i due. Serve l'SDK:
```bash
apt install -y python3-venv                    # nel laboratorio: python3 -m venv non ha pip senza questo pacchetto
python3 -m venv /tmp/v
/tmp/v/bin/pip install opentelemetry-sdk opentelemetry-exporter-otlp-proto-http
/tmp/v/bin/python app.py
# header inviato: {'traceparent': '00-b939eef382bda3a9c6df2ff80982aa9a-924f3f7f5d7b89ca-03'}
# A1 traccia b939eef382bda3a9c6df2ff80982aa9a
# header inviato: {'traceparent': '00-fe6268a8796084d2d9975190a57f044a-feee4b1636bcd81e-03'}
# ZZ9 errore: ZZ9 esaurito
```
Le parti che servono (il resto è nel file):
```python
provider = TracerProvider(resource=Resource.create({"service.name": "ordini"}))
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint="http://alloy:4318/v1/traces")))
tracer = provider.get_tracer("ordini")

with tracer.start_as_current_span("POST /ordini", kind=trace.SpanKind.SERVER) as span:      # span radice
    span.set_attribute("sku", sku)
    with tracer.start_as_current_span("chiama magazzino", kind=trace.SpanKind.CLIENT):      # figlio: il parent è lo span corrente
        intestazioni = {}
        propagate.inject(intestazioni)                       # {"traceparent": "00-<trace id>-<span id>-03"}
        # requests.get(url, headers=intestazioni)            # il servizio chiamato riceve l'header...
ctx = propagate.extract(intestazioni)                        # ...e lo trasforma in un contesto
with tracer_magazzino.start_as_current_span("verifica giacenza", context=ctx, kind=trace.SpanKind.SERVER): ...
span.add_event("ordine creato")                              # un evento nello span
span.set_status(trace.Status(trace.StatusCode.ERROR, "esaurito"))
provider.shutdown()                                          # svuota il lotto prima che il processo esca
```
L'**ultima riga conta**: `BatchSpanProcessor` raggruppa gli span e li manda dopo qualche secondo; uno script che esce subito **perde** gli span in sospeso, se non chiama `shutdown()` (o `force_flush()`).
Come si presenta la traccia in Tempo (`/api/v2/traces/ID`, con i `parentSpanId` in base64 decodificati a mano):
```
ordini     POST /ordini          SERVER    (nessun parent)             evento: "ordine creato"
ordini     valida                INTERNAL  parent = POST /ordini
ordini     chiama magazzino      CLIENT    parent = POST /ordini
magazzino  verifica giacenza     SERVER    parent = chiama magazzino   <- il parent è nell'ALTRO servizio: la traccia attraversa il confine
```
Il caso `ZZ9` si cerca con `{ status = error && resource.service.name = "magazzino" }` (traccia di 56 ms con radice `POST /ordini`).

Per non scrivere tutto a mano esiste la **strumentazione automatica**: `opentelemetry-instrument python app.py` (pacchetto `opentelemetry-distro`) e gli agent per Java (`-javaagent:opentelemetry-javaagent.jar`),
Node.js, .NET; coprono Flask, Django, `requests`, i driver SQL e creano gli span e l'header `traceparent` da soli. (**Non provati** qui.)

## Campionamento
Tenere **tutte** le tracce di un sito con traffico costa molto spazio. Il campionamento *head* decide all'inizio (una su dieci, a caso); quello *tail* decide a traccia **completa**, e quindi può tenere
**tutte le lente e tutte quelle in errore**. Lo fa il Collector, nel componente `otelcol.processor.tail_sampling` di Alloy:
```
otelcol.processor.tail_sampling "default" {
    decision_wait = "5s"                                   // aspetta 5 secondi dal primo span prima di decidere
    policy { name = "errori"  type = "status_code"   status_code { status_codes = ["ERROR"] } }
    policy { name = "lente"   type = "latency"       latency { threshold_ms = 1000 } }
    policy { name = "resto"   type = "probabilistic" probabilistic { sampling_percentage = 10 } }
    output { traces = [otelcol.exporter.otlp.tempo.input] }
}
```
Una traccia è tenuta se **una qualunque** policy la sceglie. Provato (con `sampling_percentage = 0`, per vedere l'effetto) con un secondo Alloy: mandate tre `ok`, una `errore` e una `lenta`, in Tempo sono arrivate
**solo** `errore` e `lenta`; le tre `ok` danno 404. Tutti gli span di una traccia devono arrivare **allo stesso Collector** (con più repliche serve un bilanciamento per trace ID).

## In Grafana
`lab/config/grafana/provisioning/datasources/tempo.yml` crea il datasource **Tempo** accanto a Prometheus e Loki, e Grafana lo interroga:
```bash
curl -s -u admin:laboratorio http://grafana:3000/api/datasources | jq -c '.[]|{name,type,uid}'
# {"name":"Loki","type":"loki","uid":"loki"}
# {"name":"Prometheus","type":"prometheus","uid":"prometheus"}
# {"name":"Tempo","type":"tempo","uid":"tempo"}
curl -s -u admin:laboratorio -G http://grafana:3000/api/datasources/proxy/uid/tempo/api/search --data-urlencode 'q={ duration > 1s }' | jq -c '.traces|length'
# 1
```
In **Explore > Tempo** (`http://localhost:3000`) si incolla una query TraceQL e si apre la traccia come diagramma a cascata. Il datasource è configurato anche con il collegamento da ogni span ai **log di Loki**
(`tracesToLogsV2`) e con il grafo dei nodi; **l'aspetto dell'interfaccia e i collegamenti non sono stati provati** (nessun browser).
Il passo più utile in produzione è l'inverso: scrivere il **trace ID nei log** dell'applicazione. Allora da una riga di log in Loki si salta alla traccia, e da uno span lento ai suoi log.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| in Tempo la traccia c'è per ID ma la ricerca non la trova | la ricerca ha un ritardo (31 s nel laboratorio) | aspettare; per ID subito |
| gli ID in Tempo non corrispondono a quelli dell'app | l'API di Tempo li restituisce in **base64** | `base64 -d \| od -An -tx1` |
| `curl` dà `HTTP 200` ma in Tempo non c'è niente | il 200 dice solo che Alloy ha accettato gli span, non che siano arrivati | contatori `otelcol_receiver_accepted_spans_total` e `otelcol_exporter_sent_spans_total` |
| gli span della sola app che esce subito mancano | `BatchSpanProcessor` non ha fatto in tempo a inviare | `provider.shutdown()` / `force_flush()` prima di uscire |
| ogni servizio ha la sua traccia, non una unica | manca la propagazione di `traceparent` | `propagate.inject` nel chiamante e `extract` nel chiamato (o la strumentazione automatica) |
| `/api/services` dà `404` su Jaeger 2.x | la vecchia API non c'è | `/api/v3/services` |
| `failed parsing config ... field compactor not found in type app.Config` | Tempo 3.0 ha tolto `compactor:` dalla configurazione monolitica | togliere il blocco (dove si imposti ora la retention non è stato verificato) |
| span in errore non evidenziati | manca `status` con `code: 2` (o `StatusCode.ERROR`) | impostare lo stato nello span, non solo un attributo |
| il Collector perde tracce con più repliche | il tail sampling vede solo una parte degli span di una traccia | bilanciamento per trace ID verso un solo Collector |

**Non provato** nel laboratorio: l'interfaccia web di Jaeger e di Grafana (Explore, cascata, collegamento ai log), `tracesToLogsV2`, la strumentazione automatica e gli agent Java/Node/.NET, i **service graph** e le metriche
generate dalle tracce (`metrics-generator` di Tempo), l'esportazione di Alloy verso servizi esterni, TLS e autenticazione, l'archivio su S3.

Vedi anche: [01-concetti.md](01-concetti.md) per metriche, log e tracce a confronto, [07-loki.md](07-loki.md) per Alloy e i log.

Torna all'[indice dell'area](README.md)
