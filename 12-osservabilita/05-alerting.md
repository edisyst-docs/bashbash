# Alert: regole e Alertmanager

> **Laboratorio**: `./lab.sh 12`, poi `cd 05-alerting`. Cosa contiene: [lab/](lab/).

Il lavoro è diviso in due:
- **Prometheus** valuta le regole di alert ogni `evaluation_interval` e manda ad Alertmanager quelle che scattano
- **Alertmanager** decide cosa farne: le raggruppa, toglie i doppioni, applica silenzi e inibizioni, le instrada al
  destinatario giusto (email, Slack, Teams, PagerDuty, webhook) e manda il messaggio "risolto"

```
regola vera ──for: 1m──> firing ──> Alertmanager ──route──> receiver ──> email / chat
     │                                    │
  pending                         group_wait, inhibit, silence
```

## Regole di alert
Le regole del laboratorio: [lab/config/prometheus/regole/](lab/config/prometheus/regole/).
```yaml
groups:
  - name: server
    rules:
      - alert: DiscoQuasiPieno
        expr: 1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes > 0.85
        for: 10m                           # la condizione deve restare vera 10 minuti
        keep_firing_for: 5m                # resta firing 5 minuti dopo essere tornata falsa (evita lo sfarfallio)
        labels:
          severity: warning                # etichette aggiunte all'alert: le usa Alertmanager per instradare
          squadra: sistemi
        annotations:                       # testo per chi legge: non servono a instradare
          summary: "{{ $labels.mountpoint }} su {{ $labels.instance }} pieno al {{ $value | humanizePercentage }}"
          description: "Liberare spazio o allargare il disco. Spazio libero: {{ with printf `node_filesystem_avail_bytes{instance='%s',mountpoint='%s'}` $labels.instance $labels.mountpoint | query }}{{ . | first | value | humanize1024 }}B{{ end }}"
          runbook_url: https://wiki.example.com/runbook/disco-pieno
```
Ogni serie restituita da `expr` diventa un alert distinto, con le sue etichette. Stati:
- **inactive**: `expr` non restituisce niente
- **pending**: restituisce qualcosa, ma da meno di `for`
- **firing**: vero da più di `for`; Prometheus lo manda ad Alertmanager e lo ripete finché resta vero

Nei template: `$labels.NOME`, `$value`, e funzioni come `humanize` (1.2k), `humanize1024` (1.2Ki),
`humanizePercentage` (0.83 → 83%), `humanizeDuration` (3600 → 1h 0m 0s), `humanizeTimestamp`.

Prometheus crea da solo la serie `ALERTS{alertname, alertstate}` per ogni alert pending o firing: si può interrogare
e mettere in una dashboard.

### Alert che servono quasi sempre
```yaml
- alert: IstanzaGiu
  expr: up == 0
  for: 2m
- alert: BersagliMancanti                  # il job è sparito del tutto: "up == 0" non può scattare
  expr: absent(up{job="node"})
  for: 5m
- alert: DiscoSiRiempira                   # predizione invece di soglia fissa: avvisa prima
  expr: predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[6h], 24*3600) < 0
  for: 30m
- alert: MemoriaScarsa
  expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
  for: 5m
- alert: UnitFallita
  expr: node_systemd_unit_state{state="failed"} == 1
- alert: RiavvioRichiesto
  expr: riavvio_richiesto == 1             # dal textfile collector, vedi 03-exporter.md
  for: 7d
- alert: CertificatoInScadenza
  expr: probe_ssl_earliest_cert_expiry - time() < 14 * 86400
- alert: BackupVecchio
  expr: time() - backup_ultimo_successo_timestamp_seconds > 26 * 3600
- alert: TroppiErrori                      # sintomo visto dagli utenti: più del 5% di 5xx
  expr: sum by (job) (rate(http_requests_total{status=~"5.."}[5m])) / sum by (job) (rate(http_requests_total[5m])) > 0.05
  for: 5m
```
Raccolta di regole pronte per quasi ogni exporter: https://samber.github.io/awesome-prometheus-alerts/

### Controllare e provare le regole
```bash
promtool check rules /etc/monitoring/prometheus/regole/*.yml
promtool test rules test-regole.yml            # unit test: serie finte e alert attesi
```
[`test-regole.yml`](lab/prepara.sh) nel laboratorio: una serie `up` che va a 0 dopo 30 secondi e un backup fatto
all'istante 0; si verifica che `IstanzaGiu` sia ancora pending a 40 s e firing a 70 s, e che `BackupVecchio` scatti a 3 minuti.
```yaml
rule_files: [/etc/monitoring/prometheus/regole/registrazione.yml, /etc/monitoring/prometheus/regole/server.yml]
evaluation_interval: 10s
tests:
  - interval: 10s
    input_series:
      - series: 'up{job="node", instance="server:9100", host="server"}'
        values: '1 1 1 0 0 0 0 0 0 0'          # anche '1x2 0x6' (1 ripetuto: 1 1 1, poi 0 ...) o '0+10x5' (0 10 20 ...)
    alert_rule_test:
      - eval_time: 70s
        alertname: IstanzaGiu
        exp_alerts:
          - exp_labels: {severity: critical, job: node, instance: "server:9100", host: server}
```
Cambiando una soglia o un'annotazione il test fallisce e mostra la differenza: è il modo di modificare le regole in
CI senza sorprese (un job `promtool test rules` nella pipeline del repository delle regole).

## Alertmanager
Un binario come Prometheus, porta **9093**. Versione del laboratorio: 0.34.
Configurazione del laboratorio: [lab/config/alertmanager/alertmanager.yml](lab/config/alertmanager/alertmanager.yml).
```yaml
global:
  smtp_smarthost: smtp.example.com:587
  smtp_from: alertmanager@example.com
  smtp_auth_username: alertmanager@example.com
  smtp_auth_password_file: /etc/alertmanager/smtp.pass
  resolve_timeout: 5m

route:                                     # l'albero di instradamento: si parte dalla radice
  receiver: squadra                        # default
  group_by: [alertname, instance]          # alert con questi valori uguali finiscono nello stesso messaggio
  group_wait: 30s                          # aspetta prima del primo messaggio di un gruppo nuovo
  group_interval: 5m                       # aspetta prima di mandare novità di un gruppo già notificato
  repeat_interval: 4h                      # ripete un alert ancora attivo
  routes:                                  # la prima che combacia vince (continue: true per andare avanti)
    - matchers: [severity="critical"]
      receiver: reperibile
      repeat_interval: 1h
    - matchers: [squadra="database"]
      receiver: dba
    - matchers: [alertname=~"Backup.*"]
      receiver: squadra
      active_time_intervals: [orario-ufficio]   # solo in questi orari; fuori aspetta

time_intervals:
  - name: orario-ufficio
    time_intervals:
      - weekdays: [monday:friday]
        times: [{start_time: "08:30", end_time: "18:00"}]
        location: Europe/Rome

inhibit_rules:                             # se c'è l'alert sorgente, gli alert bersaglio non vengono notificati
  - source_matchers: [alertname="IstanzaGiu"]
    target_matchers: [severity="warning"]
    equal: [instance]                      # solo se hanno lo stesso valore di instance

receivers:
  - name: squadra
    email_configs:
      - to: sistemi@example.com
        send_resolved: true
  - name: reperibile
    webhook_configs:
      - url: http://ntfy.example.com/alert   # qualunque servizio che accetta un POST JSON
    slack_configs:
      - api_url_file: /etc/alertmanager/slack.url
        channel: '#allarmi'
        title: '{{ .CommonLabels.alertname }} ({{ .Status }})'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ "\n" }}{{ end }}'
  - name: dba
    msteamsv2_configs:
      - webhook_url_file: /etc/alertmanager/teams.url
```
Altri receiver: `telegram_configs`, `pagerduty_configs`, `opsgenie_configs`, `discord_configs`, `pushover_configs`,
`sns_configs`. Le password vanno nei `*_file`, non nel file di configurazione che finisce in git.

```bash
amtool check-config alertmanager.yml
amtool config routes test --config.file=alertmanager.yml severity=critical alertname=X   # a chi arriverebbe
curl -X POST http://localhost:9093/-/reload    # oppure systemctl reload alertmanager (SIGHUP)
```

### Silenzi
Un silenzio zittisce gli alert che combaciano per un certo tempo: manutenzione programmata, problema già noto.
Si crea dall'interfaccia (*New Silence*) o con amtool:
```bash
amtool --alertmanager.url=http://localhost:9093 alert query   # oppure l'indirizzo in /etc/amtool/config.yml
amtool alert query                             # alert attivi; nel laboratorio l'indirizzo è già in /etc/amtool/config.yml
amtool alert query severity=critical
amtool silence add alertname=CpuAlta host=server --duration=2h --comment="ricompilo il kernel"
amtool silence add 'alertname=~"Disco.*"' --duration=30m --comment="pulizia" --author=edo
amtool silence query                           # silenzi attivi, con l'ID
amtool silence expire ID                       # toglie un silenzio
amtool silence query -q | xargs -r amtool silence expire   # li toglie tutti
```
Durante un deploy si può creare il silenzio dalla pipeline con l'API (`POST /api/v2/silences`) e toglierlo alla fine.

### API
```bash
A=http://localhost:9093
curl -s $A/api/v2/alerts | jq -r '.[] | "\(.status.state)\t\(.labels.alertname)\t\(.labels.instance)"'
curl -s $A/api/v2/silences | jq
curl -s $A/api/v2/status | jq .config.original -r     # la configurazione caricata
# un alert finto, per provare l'instradamento e i receiver senza aspettare un guasto
curl -s -XPOST $A/api/v2/alerts -H 'Content-Type: application/json' -d '[{
  "labels": {"alertname": "Prova", "severity": "critical", "host": "server"},
  "annotations": {"summary": "alert di prova da curl"}
}]'
```
UGUALE: `amtool alert add alertname=Prova severity=critical host=server --annotation='summary="alert di prova"'`
(con spazi, il valore va fra doppi apici dentro gli apici singoli).

### Alta disponibilità
Più Alertmanager in cluster (`--cluster.peer=am2:9094`) condividono silenzi e notifiche già mandate. Ogni Prometheus
li elenca **tutti** in `alerting.alertmanagers`: non si mette un bilanciatore davanti.

## Nel laboratorio
`./scenari.sh` provoca un guasto alla volta (da tester chiede la password per `sudo`). Gli alert si seguono in
Prometheus (*Alerts*: pending, poi firing), in Alertmanager (http://localhost:9093) e le email in Mailpit
(http://localhost:8025): `squadra@lab.local` per i warning, `reperibile@lab.local` con oggetto `[URGENTE]` per i critical.

| Scenario | Cosa fa | Cosa si vede |
|---|---|---|
| `nginx` | `systemctl stop nginx` | dopo ~40 s `SitoNonRaggiungibile` (critical) e `NginxGiu` (warning); in Alertmanager NginxGiu è *suppressed* dall'inibizione e arriva una sola email |
| `exporter` | ferma node_exporter | `IstanzaGiu` per `job="node"`; le altre regole sul server smettono di avere dati |
| `cpu` | `stress-ng` per 150 s su tutti i core | `CpuAlta` pending, firing dopo 1 minuto, poi risolto |
| `disco` | file da 56 MB in `/dati` (64 MB) | `DiscoQuasiPieno` dopo 30 s |
| `riempi` | `/dati` cresce di 1 MB ogni 3 s | `DiscoSiRiempira` (critical) per `predict_linear`, prima che il disco sia pieno |
| `unit` | un servizio che esce con codice 3 | `UnitFallita` con `name="lavoro-notturno.service"`; `systemctl --failed` |
| `backup` | `backup.sh` riuscito ora | dopo 2 minuti `BackupVecchio` |
| `pulisci` | rimette tutto a posto | gli alert si risolvono, arrivano le email `RESOLVED` |

Esercizi:
```bash
./scenari.sh nginx
amtool alert query                             # SitoNonRaggiungibile (NginxGiu è inibito)
amtool silence add alertname=SitoNonRaggiungibile --duration=10m --comment=prova
./scenari.sh pulisci

# soglia diversa: CpuAlta al 50% invece che all'80%
vim /etc/monitoring/prometheus/regole/server.yml
promtool check rules /etc/monitoring/prometheus/regole/server.yml && curl -X POST http://prometheus:9090/-/reload
promtool test rules test-regole.yml            # i test passano ancora?

# un receiver nuovo per gli alert dei backup
vim /etc/monitoring/alertmanager/alertmanager.yml
amtool check-config /etc/monitoring/alertmanager/alertmanager.yml && curl -X POST http://alertmanager:9093/-/reload
```
Le modifiche restano nel volume finché il laboratorio è acceso; all'uscita si riparte dai file della KB.
