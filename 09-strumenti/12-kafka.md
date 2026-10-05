# Kafka: un log di eventi

> **Laboratorio**: `./lab.sh 09`, poi `cd 12-kafka`. File pronto: `ordini.txt` (da [lab/materiale/](lab/materiale/)). Il broker è l'host `kafka`, porta `9092`; `~/.config/kcat.conf` contiene già l'indirizzo.

**Apache Kafka** è un **log distribuito di eventi**. Chi produce **aggiunge** messaggi in fondo a un *topic*; chi consuma li **legge** partendo dalla posizione che preferisce. A differenza di una coda ([11-rabbitmq.md](11-rabbitmq.md)) il messaggio **non sparisce
quando è stato letto**: resta per un tempo stabilito (o per sempre), e più consumatori indipendenti possono leggerlo, anche da capo. È la base di molte pipeline di dati: log, eventi di un'applicazione, sincronizzazione tra servizi.
Gli esempi sono stati eseguiti con Kafka 4.3.1 (modalità **KRaft**, senza ZooKeeper) e `kcat` 1.7.1 nel laboratorio.

## Gli strumenti
| Strumento | Dove | Per cosa |
|---|---|---|
| `kcat` (ex `kafkacat`) | pacchetto `kcat`, nella shell del laboratorio | produrre, consumare, elencare i topic; l'equivalente di `curl` per Kafka |
| `kafka-topics.sh`, `kafka-configs.sh`, `kafka-consumer-groups.sh`... | **dentro il container** del broker, in `/opt/kafka/bin` | amministrazione: topic, configurazioni, gruppi |

Le utility `kafka-*.sh` sono in Java e stanno solo nell'immagine di Kafka. Da un **secondo terminale dell'host** (il laboratorio resta aperto nel primo), dalla radice della KB:
```bash
kafka() { docker compose -f 09-strumenti/lab/compose.yaml exec kafka "/opt/kafka/bin/$1" "${@:2}"; }
kafka kafka-topics.sh --bootstrap-server kafka:9092 --list
```
Gli esempi sotto scrivono `kafka kafka-topics.sh ...` e omettono `--bootstrap-server kafka:9092` per brevità: va messo sempre.

## Come funziona
```
producer --> TOPIC (partizione 0: m0 m1 m2 m3 ...)  --> consumer del gruppo A (legge dall'offset X)
                  (partizione 1: m0 m1 ...)          --> consumer del gruppo B (legge dall'offset Y)
```
- Un **topic** è diviso in **partizioni**. Ogni partizione è un log ordinato: i messaggi hanno un numero progressivo, l'**offset** (0, 1, 2...). L'ordine è garantito **solo dentro una partizione**.
- Il messaggio ha una **chiave** (facoltativa) e un valore. **La stessa chiave va sempre nella stessa partizione**: è il modo per avere in ordine tutti gli eventi di uno stesso cliente o ordine.
- Un **consumer group** è un insieme di consumer che si dividono le partizioni di un topic: ogni partizione è letta da **un solo** consumer del gruppo. Per ogni gruppo Kafka ricorda l'offset raggiunto (*committed offset*). Due gruppi diversi leggono
  **ciascuno tutti** i messaggi, indipendenti.
- **Retention**: i messaggi si cancellano per tempo (`retention.ms`, di default 7 giorni) o per dimensione, **non** perché letti.
- **Replica**: ogni partizione può avere copie su altri broker (`replication-factor`). Il laboratorio ha **un solo broker**, quindi il fattore è 1.

## Metadati
```bash
kcat -L
# Metadata for all topics (from broker 1: kafka:9092/1):
#  1 brokers:
#   broker 1 at kafka:9092 (controller)
#  0 topics:
```
Il broker è anche il *controller* (KRaft: un nodo può essere tutti e due). Con `-L -t log` si vede un topic solo; con `-L -J` tutto in JSON, comodo con `jq`.

## Produrre
Un topic che non esiste viene **creato al primo messaggio**, con il numero di partizioni di `num.partitions` (nel laboratorio 3):
```bash
printf 'uno\ndue\ntre\n' | kcat -P -t log          # -P produce: una riga di stdin = un messaggio
kcat -L -t log
# Metadata for log (from broker 1: kafka:9092/1):
#  1 brokers:
#   broker 1 at kafka:9092 (controller)
#  1 topics:
#   topic "log" with 3 partitions:
#     partition 0, leader 1, replicas: 1, isrs: 1
#     partition 1, leader 1, replicas: 1, isrs: 1
#     partition 2, leader 1, replicas: 1, isrs: 1
```
`isrs` sono le repliche **in sync**: con un solo broker c'è solo la 1. Con la **chiave** (`-K:` separa chiave e valore sulla riga) i messaggi si distribuiscono per chiave:
```bash
cat ordini.txt
# anna:ordine 1
# bruno:ordine 2
# ...
kcat -P -t chiavi -K: < ordini.txt
kcat -C -t chiavi -e -q -f '%k -> %s  (partizione %p, offset %o)\n'
# anna -> ordine 1  (partizione 0, offset 0)
# bruno -> ordine 2  (partizione 0, offset 1)
# anna -> ordine 3  (partizione 0, offset 2)
# bruno -> ordine 5  (partizione 0, offset 3)
# anna -> ordine 6  (partizione 0, offset 4)
# carla -> ordine 4  (partizione 1, offset 0)
```
`anna` e `bruno` stanno nella partizione 0, **in ordine** (1, 3, 6 per `anna`), `carla` nella 1. Senza chiave nessuna regola vale: `kcat` mette un gruppo di messaggi nella **stessa** partizione, scelta a caso, e tre messaggi
di `log` sono finiti insieme in una (la 2 in questa esecuzione, la 0 in un'altra). Per scegliere: `kcat -P -t log -p 0`. Altre opzioni: `-H nome=valore` aggiunge **header**, `-z gzip` comprime, `-l FILE` legge i messaggi da un file.

## Consumare
```bash
kcat -C -t log -e                       # -C consuma; -e: esce quando arriva in fondo
# % Reached end of topic log [0] at offset 0
# % Reached end of topic log [1] at offset 0
# % Reached end of topic log [2] at offset 3: exiting
# uno
# due
# tre
```
I messaggi `% ...` vanno su **stderr**: con `-q` spariscono. Senza `-e` `kcat` resta in attesa di nuovi messaggi (come `tail -f`). Il formato di uscita è `-f`:

| Segnaposto | Contenuto |
|---|---|
| `%s`, `%S` | il valore e la sua lunghezza |
| `%k` | la chiave |
| `%p`, `%o` | partizione e offset |
| `%T` | il timestamp in millisecondi |
| `%h` | gli header (`nome=valore,...`) |
| `%t` | il topic |

```bash
kcat -C -t log -e -q -f 'p=%p o=%o k=%k v=%s\n'
# p=2 o=0 k= v=uno
# p=2 o=1 k= v=due
# p=2 o=2 k= v=tre
kcat -C -t log -c 1 -J -e -q          # -J: una riga JSON per messaggio
# {"topic":"log","partition":2,"offset":0,"tstype":"create","ts":1791220299549,"broker":1,"key":null,"payload":"uno"}
echo 'con header' | kcat -P -t h -p 0 -H origine=lab -H versione=2
kcat -C -t h -e -q -f '%s | %h\n'
# con header | origine=lab,versione=2
kcat -C -t chiavi -e -q -f '%k\n' | sort | uniq -c       # quanti messaggi per chiave
#       3 anna
#       2 bruno
#       1 carla
```

### Da dove si comincia a leggere
```bash
kcat -C -t chiavi -p 0 -o 2 -c 1 -e -q -f '%k %s\n'      # -o 2: dall'offset 2, un messaggio (-p 0: una partizione)
# anna ordine 3
kcat -C -t chiavi -p 0 -o -2 -e -q -f '%k %s\n'          # -o -2: gli ultimi 2
# bruno ordine 5
# anna ordine 6
kcat -Q -t chiavi:0:0                                    # a quale offset corrisponde il timestamp 0 (l'inizio)?
# chiavi [0] offset 0
```
`-o` accetta anche `beginning`, `end`, `stored` (l'offset del gruppo) e `s@MILLISECONDI` (dal momento in cui è stato scritto): leggere **da una certa ora** è uno dei grandi vantaggi di un log.

## Gruppi di consumer e offset
`kcat -G GRUPPO topic` usa un **consumer group**: Kafka ricorda fin dove è arrivato, e una seconda esecuzione **continua da lì**.
```bash
printf 'm1\nm2\nm3\nm4\nm5\n' | kcat -P -t coda -p 0
kcat -G g2 -X auto.offset.reset=earliest coda -c 2 -e -q -f '%p/%o %s\n'
# 0/0 m1
# 0/1 m2
kcat -G g2 -X auto.offset.reset=earliest coda -c 2 -e -q -f '%p/%o %s\n'
# 0/2 m3
# 0/3 m4
```
**Un gruppo nuovo parte dalla fine** del topic (`auto.offset.reset=latest`): senza `-X auto.offset.reset=earliest` la prima esecuzione non stampa niente. Questo è l'errore più comune. Quando l'offset
del gruppo è già salvato, `auto.offset.reset` non conta più: si riparte da lì.

Lo stato dei gruppi, con il **ritardo** (*lag*: messaggi scritti e non ancora letti):
```bash
kafka kafka-consumer-groups.sh --bootstrap-server kafka:9092 --list
# g1
# g2
kafka kafka-consumer-groups.sh --bootstrap-server kafka:9092 --describe --group g2
# Consumer group 'g2' has no active members.
#
# GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
# g2              coda            0          4               5               1               -               -               -
# g2              log             2          2               4               2               -               -               -
```
`CURRENT-OFFSET` è il prossimo da leggere, `LOG-END-OFFSET` l'ultimo scritto + 1. Un **lag** che cresce vuol dire che i consumer non reggono il ritmo. Con il gruppo **attivo** compaiono `CONSUMER-ID`, `HOST` e `CLIENT-ID`.
(L'esempio ha anche la riga di `log` perché il gruppo `g2` era già stato usato lì.)

### Riportare indietro un gruppo
Per rielaborare dei messaggi basta spostare l'offset: con il gruppo **fermo**.
```bash
kafka kafka-consumer-groups.sh --bootstrap-server kafka:9092 --group g2 --reset-offsets --to-earliest --topic coda --dry-run
# GROUP           TOPIC           PARTITION  NEW-OFFSET
# g2              coda            0          0
# g2              coda            2          0
# g2              coda            1          0
kafka kafka-consumer-groups.sh --bootstrap-server kafka:9092 --group g2 --reset-offsets --to-offset 1 --topic coda:0 --execute
# g2              coda            0          1
```
`--dry-run` mostra cosa succederebbe, `--execute` lo fa. Le varianti: `--to-earliest`, `--to-latest`, `--to-offset N`, `--shift-by N`, `--to-datetime 2026-10-05T10:00:00.000`, `--by-duration PT1H`.
`--topic coda:0` limita a una partizione. `--shift-by` fallisce con `Cannot shift offset for partition coda-1 since there is no current committed offset` sulle partizioni dove il gruppo non ha mai salvato un offset.

## Topic e configurazione
```bash
kafka kafka-topics.sh --bootstrap-server kafka:9092 --create --topic pagamenti --partitions 2 --replication-factor 1 --config retention.ms=3600000
# Created topic pagamenti.
kafka kafka-topics.sh --bootstrap-server kafka:9092 --list
# __consumer_offsets
# chiavi
# coda
# h
# log
# pagamenti
kafka kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic pagamenti
# Topic: pagamenti	TopicId: VWzfW5lOQPyolw0Ss0yhOw	PartitionCount: 2	ReplicationFactor: 1	Configs: min.insync.replicas=1,retention.ms=3600000
# 	Topic: pagamenti	Partition: 0	Leader: 1	Replicas: 1	Isr: 1	Elr: 	LastKnownElr: 
# 	Topic: pagamenti	Partition: 1	Leader: 1	Replicas: 1	Isr: 1	Elr: 	LastKnownElr: 
```
`__consumer_offsets` è un topic **interno**: è lì che Kafka salva gli offset dei gruppi. I limiti, con l'errore esatto:
```bash
kafka kafka-topics.sh ... --create --topic pagamenti --partitions 2
# Error while executing topic command : Topic 'pagamenti' already exists.
kafka kafka-topics.sh ... --create --topic troppi --replication-factor 3
# Error while executing topic command : Unable to replicate the partition 3 time(s): The target replication factor of 3 cannot be reached because only 1 broker(s) are registered or ...
kafka kafka-topics.sh ... --alter --topic pagamenti --partitions 4          # le partizioni si possono solo AUMENTARE
kafka kafka-topics.sh ... --alter --topic pagamenti --partitions 1
# Error while executing topic command : The topic pagamenti currently has 4 partition(s); 1 would not be an increase.
```
Aumentare le partizioni **cambia la partizione di una chiave**: l'ordine dei messaggi già scritti con quella chiave non è più garantito rispetto ai nuovi. Per questo il numero si sceglie con cura **all'inizio**.
```bash
kafka kafka-configs.sh --bootstrap-server kafka:9092 --entity-type topics --entity-name pagamenti --alter --add-config retention.ms=60000,max.message.bytes=2048
# Completed updating config for topic pagamenti.
kafka kafka-configs.sh --bootstrap-server kafka:9092 --entity-type topics --entity-name pagamenti --describe
# Dynamic configs for topic pagamenti are:
#   max.message.bytes=2048 sensitive=false synonyms={DYNAMIC_TOPIC_CONFIG:max.message.bytes=2048, DEFAULT_CONFIG:message.max.bytes=1048588}
#   retention.ms=60000 sensitive=false synonyms={DYNAMIC_TOPIC_CONFIG:retention.ms=60000}
kafka kafka-topics.sh --bootstrap-server kafka:9092 --delete --topic pagamenti
```
Le configurazioni di uso comune: `retention.ms` (quanto conservare, `-1` per sempre), `retention.bytes`, `max.message.bytes`, `cleanup.policy` (`delete` o `compact`), `min.insync.replicas`.

### Compattazione
Con `cleanup.policy=compact` Kafka non cancella per età, ma tiene **l'ultimo valore per ogni chiave**: il topic diventa lo "stato attuale", per esempio il profilo di ogni utente.
```bash
kafka kafka-topics.sh --bootstrap-server kafka:9092 --create --topic profili --partitions 1 \
      --config cleanup.policy=compact --config segment.ms=1000 --config min.cleanable.dirty.ratio=0.01 --config delete.retention.ms=100
# anna:v1 bruno:v1 anna:v2 anna:v3 bruno:v2   poi dopo 3 secondi: carla:v1 anna:v4   e dopo altri 3: bruno:v3
kcat -C -t profili -e -q -f '%k=%s o=%o\n'          # subito: ci sono tutti e 8, offset da 0 a 7
kcat -C -t profili -e -q -f '%k=%s o=%o\n'          # dopo circa un minuto
# bruno=v2 o=4
# carla=v1 o=5
# anna=v4 o=6
# bruno=v3 o=7
```
Spariti i valori vecchi di `anna` (da v1 a v3) e il primo di `bruno`, **gli offset rimasti non cambiano**. La compattazione non tocca il segmento attivo (l'ultimo), e il suo ritmo dipende da `segment.ms` e dal *cleaner*: i valori
sopra servono solo a vederla in un minuto, in produzione sono molto più alti. `bruno=v2` è rimasto anche se `v3` è più recente: il *cleaner* lavora solo sui segmenti già chiusi, e `v3` era ancora nel segmento attivo (spiegazione coerente con la documentazione di Kafka, non verificata nei log). È un esempio **dipendente dal tempo**: in un'altra esecuzione l'esito può cambiare.

## Altre utility
```bash
kafka kafka-get-offsets.sh --bootstrap-server kafka:9092 --topic chiavi         # l'offset finale di ogni partizione
# chiavi:0:5
# chiavi:1:1
# chiavi:2:0
kafka kafka-log-dirs.sh --bootstrap-server kafka:9092 --describe --topic-list chiavi    # dimensioni su disco, in JSON
# ..."partitions":[{"partition":"chiavi-2","size":0,...},{"partition":"chiavi-1","size":81,...},{"partition":"chiavi-0","size":158,...}]...
kafka kafka-metadata-quorum.sh --bootstrap-server kafka:9092 describe --status          # il controller KRaft
# ClusterId:              5L6g3nShT-eMCtK--X86sw
# LeaderId:               1
# CurrentVoters:          [{"id": 1, "endpoints": ["CONTROLLER://kafka:9093"]}]
kafka kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic log --group lettori --from-beginning --max-messages 10   # come kcat -G, e salva l'offset
```
Il **broker** con tutta la sua configurazione (`KAFKA_*` in [lab/compose.yaml](lab/compose.yaml)) occupa circa 400 MB di memoria nel laboratorio, con la JVM limitata a 512 MB (`KAFKA_HEAP_OPTS`).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `kcat -G` non stampa niente | gruppo nuovo: parte dalla **fine** del topic | `-X auto.offset.reset=earliest` |
| `Failed to resolve 'nonesiste:9092'` / `Broker transport failure (Are the brokers reachable?)` | host sbagliato o broker spento | `-b host:porta`, o `~/.config/kcat.conf` con `bootstrap.servers` |
| connessione riuscita, poi `Connection refused` verso un altro indirizzo | l'**advertised listener** del broker non è raggiungibile dal client: Kafka risponde con il *suo* indirizzo | `KAFKA_ADVERTISED_LISTENERS` con un nome che il client risolve |
| `Unknown topic or partition` | il topic non esiste (e la creazione automatica è spenta, o il topic è stato cancellato) | `kafka-topics.sh --create` |
| `Unable to replicate the partition 3 time(s)` | replication factor più alto del numero di broker | un fattore uguale o inferiore ai broker |
| i messaggi non sono in ordine | l'ordine vale **solo dentro una partizione** | stessa chiave per gli eventi da tenere in ordine |
| `Cannot shift offset ... no current committed offset` | `--shift-by` su una partizione senza offset salvato | `--to-offset`, `--to-earliest` |
| `--reset-offsets --execute` rifiuta | il gruppo ha consumer attivi | fermarli prima |
| il lag cresce | i consumer sono più lenti dei producer | più consumer nel gruppo (al massimo uno per partizione), o più partizioni |

**Non provato** nel laboratorio: più broker (replica vera, `min.insync.replicas`, elezione del leader), il problema degli *advertised listener* da fuori Docker, SASL e TLS, Schema Registry e Avro, Kafka Connect e Kafka Streams, le transazioni; e le opzioni `kcat -z`, `-l`, `-o s@...`, `kafka-consumer-groups --to-datetime` e `--by-duration`, riprese dal loro aiuto in linea.

Torna all'[indice dell'area](README.md)
