# Monitoraggio e osservabilità: i concetti

> **Laboratorio**: `./lab.sh 12`. Cosa contiene: [lab/](lab/).

**Monitoraggio**: controllare valori noti (CPU, disco, il sito risponde?) e avvisare quando escono dai limiti.
**Osservabilità**: poter capire dall'esterno cosa succede dentro un sistema, anche per problemi che non si erano
previsti. Si regge su tre tipi di dati:

| | Cosa sono | Esempio | Strumenti |
|---|---|---|---|
| **metriche** | numeri nel tempo, con etichette | `node_cpu_seconds_total{mode="idle"}` ogni 15 s | Prometheus, Grafana |
| **log** | righe di testo con un orario | `GET /login 500 0.231s` | journald, Loki, Elasticsearch |
| **tracce** | il percorso di una richiesta fra più servizi | nginx 2 ms → app 180 ms → database 170 ms | OpenTelemetry, Tempo, Jaeger |

Le metriche costano poco (un numero per serie, ogni N secondi) e dicono **che** c'è un problema; log e tracce dicono
**perché**. Quest'area copre le metriche e gli alert; i log del singolo server con `journalctl` sono in
[../06-sistema/07-servizi.md](../06-sistema/07-servizi.md).

## Pull e push
- **pull** (Prometheus): il server di monitoraggio interroga a intervalli ogni bersaglio (`GET /metrics`). Se un
  bersaglio non risponde lo sa subito (`up == 0`); la lista dei bersagli sta in un posto solo
- **push** (Zabbix agent attivo, InfluxDB/Telegraf, StatsD, OpenTelemetry): sono i bersagli a mandare i dati.
  Comodo per job brevi e macchine dietro NAT; per Prometheus esiste il Pushgateway ([03-exporter.md](03-exporter.md))

## L'ecosistema Prometheus
```
 server  ── node_exporter :9100/metrics ──┐
 nginx   ── nginx-exporter :9113 ─────────┤  scrape (pull)
 app     ── /metrics (libreria client) ───┼──────────────> Prometheus ──query PromQL──> Grafana (dashboard)
 sito    ── blackbox_exporter :9115 ──────┘                 │  regole
                                                            ▼  ogni N secondi
                                                      Alertmanager ──> email, Slack, Teams, PagerDuty, webhook
```
- **Prometheus**: raccoglie (*scrape*), salva in un database di serie temporali (TSDB) su disco locale, risponde alle
  query in **PromQL**, valuta le regole di alert
- **exporter**: programmi che traducono lo stato di qualcosa (il sistema operativo, MySQL, nginx) nel formato testo
  di Prometheus. Le applicazioni scritte da noi espongono `/metrics` da sole con una libreria
- **Alertmanager**: riceve gli alert da Prometheus, li raggruppa, toglie i doppioni, li silenzia, li instrada
- **Grafana**: dashboard; legge da Prometheus (e da Loki, MySQL, Elasticsearch, ...)

Prometheus non è pensato per conservare dati per anni né per contare con precisione (fatture, accessi): per lo
storico lungo si usano Thanos, Mimir o VictoriaMetrics, che ricevono i dati con `remote_write`.

## Il formato delle metriche
```
# HELP node_filesystem_avail_bytes Filesystem space available to non-root users in bytes.
# TYPE node_filesystem_avail_bytes gauge
node_filesystem_avail_bytes{device="/dev/sda1",fstype="ext4",mountpoint="/"} 4.2346496e+10
```
Una **serie** è il nome della metrica più una combinazione di **etichette** (*label*): ogni combinazione diversa è una
serie diversa, con il suo spazio su disco e in memoria. Mai etichette con valori illimitati (id utente, URL completo,
indirizzo IP del client): è il problema della **cardinalità**, la causa più comune di un Prometheus che esaurisce la RAM.

I quattro tipi:

| Tipo | Cosa rappresenta | Esempio | Si usa con |
|---|---|---|---|
| **counter** | un totale che solo cresce (torna a 0 al riavvio) | `http_requests_total`, `node_cpu_seconds_total` | `rate()`, `increase()`: il valore nudo non dice niente |
| **gauge** | un valore che sale e scende | `node_memory_MemAvailable_bytes`, temperatura, coda | direttamente, `avg_over_time()`, `predict_linear()` |
| **histogram** | conteggi in fasce (*bucket*) `_bucket{le="0.5"}`, più `_sum` e `_count` | durata delle richieste | `histogram_quantile()`: percentili aggregabili fra server |
| **summary** | percentili già calcolati dal client | `go_gc_duration_seconds{quantile="0.75"}` | letto così com'è, non si può sommare fra istanze |

Convenzioni dei nomi: unità di base nel nome (`_seconds`, `_bytes`, mai millisecondi o megabyte), `_total` per i
counter, minuscole con `_`.

## Cosa misurare: metodi
- **USE** (risorse: CPU, memoria, disco, rete): **U**tilization (quanto è occupata), **S**aturation (quanto lavoro
  aspetta: load, swap, coda del disco), **E**rrors
- **RED** (servizi: un'API, un sito): **R**ate (richieste al secondo), **E**rrors (quante falliscono), **D**uration
  (quanto durano, come percentili)
- **i quattro segnali d'oro** di Google SRE: latenza, traffico, errori, saturazione. Sono RED più la saturazione

## SLI, SLO, SLA
- **SLI** (indicatore): una misura della qualità vista dall'utente. "Percentuale di richieste con risposta 2xx in meno di 300 ms"
- **SLO** (obiettivo): il valore che ci si impegna a tenere. "99,5% su 30 giorni"
- **SLA** (accordo): l'SLO scritto in un contratto, con penali. Sempre più largo dell'SLO interno
- **error budget**: 100% − SLO. Con 99,5% su 30 giorni si possono "spendere" 3 ore e 36 minuti di disservizio;
  finito il budget si rallentano i rilasci

| Disponibilità | Fermo al mese | Fermo all'anno |
|---|---|---|
| 99% | 7 h 18 min | 3 giorni 15 h |
| 99,5% | 3 h 36 min | 1 giorno 19 h |
| 99,9% | 43 min | 8 h 46 min |
| 99,99% | 4 min 23 s | 52 min |

## Alert che servono
Un alert deve chiedere un'azione a una persona. Regole pratiche:
- avvisare sui **sintomi** (il sito è lento, gli utenti ricevono errori) più che sulle cause (CPU all'80%: se il sito va
  bene non serve svegliare nessuno). Le cause vanno nelle dashboard
- ogni alert con una soglia **e una durata** (`for: 5m`): un picco di 10 secondi non è un problema
- `critical` solo per cose da sistemare subito, a qualunque ora; il resto `warning`, letto in orario di lavoro
- un alert che scatta spesso e viene ignorato insegna a ignorare tutti gli alert: va corretto o tolto
- nell'annotazione cosa fare (o il link a un *runbook*)

## Altri strumenti che si incontrano
| | Cosa è |
|---|---|
| Zabbix, Nagios, Icinga, Checkmk | monitoraggio "classico": agenti, check, template, molto diffusi on-premise |
| Netdata | agente con dashboard già pronte, installazione in un minuto, utile su un server singolo |
| VictoriaMetrics | compatibile con Prometheus, meno RAM e disco, storico lungo |
| Grafana Alloy | agente unico di Grafana per metriche, log e tracce (sostituisce Grafana Agent e Promtail) |
| OpenTelemetry | standard aperto per strumentare le applicazioni (metriche, log, tracce) e il suo Collector |
| Datadog, New Relic, Grafana Cloud | servizi a pagamento: niente da installare oltre l'agente |

Vedi anche: [02-prometheus.md](02-prometheus.md) per installare e configurare Prometheus.
