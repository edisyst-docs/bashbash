# 12 - Osservabilità

Metriche e alert con lo stack più diffuso: Prometheus raccoglie, gli exporter espongono, Alertmanager avvisa,
Grafana mostra. I comandi per guardare un server "a mano" (`top`, `free`, `df`, `journalctl`) sono in
[../04-processi/](../04-processi/) e [../06-sistema/](../06-sistema/).

| # | File | Contenuto |
|---|---|---|
| 01 | [concetti](01-concetti.md) | Metriche, log e tracce; pull e push; tipi di metriche e cardinalità; USE, RED, SLI/SLO ed error budget; alert che servono |
| 02 | [prometheus](02-prometheus.md) | Installazione con systemd e Docker, `prometheus.yml`, service discovery, relabeling, API HTTP, `promtool`, backup, federazione e `remote_write` |
| 03 | [exporter](03-exporter.md) | node_exporter e collector, textfile collector dagli script bash, blackbox, nginx, MySQL e PostgreSQL, cAdvisor, `/metrics` nelle applicazioni, Pushgateway |
| 04 | [promql](04-promql.md) | Selettori, `rate`/`increase`, operatori e `on`/`group_left`, aggregazioni, funzioni, percentili, query di tutti i giorni, recording rule |
| 05 | [alerting](05-alerting.md) | Regole di alert e test con `promtool`, Alertmanager: route, raggruppamento, inibizioni, silenzi con `amtool`, receiver, API |
| 06 | [grafana](06-grafana.md) | Installazione, dashboard e variabili, dashboard pronte, provisioning da codice, API e backup |
| 07 | [loki](07-loki.md) | Log centralizzati con Loki e Promtail: architettura, `loki.yml`, `promtail.yml`, pipeline, LogQL, logcli, alert sui log, confronto con ELK |

**Laboratorio**: `./lab.sh 12` dalla radice della KB avvia Prometheus, Alertmanager, Grafana, Loki, Promtail, gli exporter e un
server con systemd da monitorare (e rompere). Dettagli in [lab/](lab/).

Area precedente: [../11-container-e-automazione/](../11-container-e-automazione/) · Torna all'[indice](../README.md)
