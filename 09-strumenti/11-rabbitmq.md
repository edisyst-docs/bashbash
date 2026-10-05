# RabbitMQ: code di messaggi

> **Laboratorio**: `./lab.sh 09`, poi `cd 11-rabbitmq`. File pronti: `lavori.txt`, `worker.sh` (da [lab/materiale/](lab/materiale/)). Il broker è l'host `rabbitmq`, utente `lab`, password `lab`.

**RabbitMQ** è un *message broker*: un'applicazione (il **producer**) non chiama direttamente un'altra, ma lascia un messaggio nel broker, e un'altra (il **consumer**) lo ritira quando può. Serve a sganciare chi produce
il lavoro da chi lo fa: l'invio di un'email, il ridimensionamento di una foto, la fatturazione. Se il consumer è fermo o lento, i messaggi aspettano in una **coda**. Parla il protocollo **AMQP 0-9-1** sulla porta `5672`;
la porta `15672` ha l'interfaccia di gestione e una **API HTTP**. Gli esempi sono stati eseguiti con RabbitMQ 4.3.6 (Erlang 27) nel laboratorio.

Per il confronto con **Kafka** vedi [12-kafka.md](12-kafka.md): RabbitMQ **toglie** il messaggio dalla coda quando è stato elaborato, Kafka lo **conserva** in un log che si può rileggere.

## Gli strumenti
Nell'immagine del laboratorio non c'è un `rabbitmqadmin`: si lavora con tre cose che si trovano anche su un server vero.

| Strumento | Dove | Per cosa |
|---|---|---|
| `amqp-publish`, `amqp-get`, `amqp-consume`, `amqp-declare-queue`, `amqp-delete-queue` | pacchetto `amqp-tools`, nella shell del laboratorio | mandare e ricevere messaggi da riga di comando |
| API HTTP `http://rabbitmq:15672/api` | `curl` e `jq` ([01-jq-e-curl.md](01-jq-e-curl.md)) | tutto il resto: code, exchange, utenti, statistiche |
| `rabbitmqctl`, `rabbitmq-diagnostics` | **dentro il container** del broker | amministrazione del nodo |

```bash
curl -s -u lab:lab http://rabbitmq:15672/api/overview | jq '{rabbitmq_version, erlang_version, node}'
# {
#   "rabbitmq_version": "4.3.6",
#   "erlang_version": "27.3.4.18",
#   "node": "rabbit@rabbitmq"
# }
curl -s -u lab:lab http://rabbitmq:15672/api/whoami
# {"name":"lab","tags":["administrator"],"is_internal_user":true}
```
Gli `amqp-*` vogliono l'indirizzo con `--url` a ogni comando (la variabile `AMQP_URL` **non** è letta: senza `--url` provano `localhost:5672`). Conviene metterlo in una variabile della shell:
```bash
U=amqp://lab:lab@rabbitmq          # amqp://UTENTE:PASSWORD@HOST[:PORTA]/VHOST
```
Per `rabbitmqctl` serve entrare nel container: da un **secondo terminale dell'host** (il laboratorio resta aperto nel primo), dalla radice della KB:
```bash
docker compose -f 09-strumenti/lab/compose.yaml exec rabbitmq rabbitmqctl list_queues name messages consumers
```

## Come funziona
```
producer --> EXCHANGE --(binding: routing key)--> CODA --> consumer
```
- Il producer pubblica su un **exchange**, con una **routing key** (una stringa, per esempio `ordine.pagato`).
- L'exchange smista il messaggio verso le **code** collegate con un **binding**: dipende dal tipo di exchange.
- Il consumer legge da una **coda**, e deve **confermare** (*ack*) ogni messaggio. Solo allora il broker lo cancella.
- L'exchange senza nome (`""`, il *default exchange*) è speciale: consegna alla coda che ha **lo stesso nome della routing key**. È quello che usa `amqp-publish -r lavori` senza `-e`.

## Una coda e i suoi messaggi
```bash
amqp-declare-queue --url=$U -q lavori -d          # -d: durevole, sopravvive a un riavvio del broker
# lavori
while read -r l; do amqp-publish --url=$U -r lavori -b "$l"; done < lavori.txt     # 5 messaggi
```
Le statistiche delle code (messaggi, consumer) l'API le aggiorna **ogni 5 secondi**: appena dopo l'invio i contatori possono essere ancora `null`.
```bash
curl -s -u lab:lab http://rabbitmq:15672/api/queues/%2F/lavori | jq -c '{name, messages, messages_ready, consumers, durable, state}'
# {"name":"lavori","messages":5,"messages_ready":5,"consumers":0,"durable":true,"state":"running"}
```
`%2F` è il vhost `/` scritto come URL (vedi [vhost e utenti](#vhost-e-utenti)). `messages_ready` sono quelli in attesa; `messages_unacknowledged` quelli consegnati a un consumer che non li ha ancora confermati.

### Ritirare un messaggio
```bash
amqp-get --url=$U -q lavori          # ne ritira UNO e lo conferma: sparisce dalla coda
# ridimensiona foto1.jpg
```
`amqp-get` stampa il corpo **senza andare a capo**. Per **guardare senza consumare** si usa l'API con `ack_requeue_true`: i messaggi vengono rimessi in coda:
```bash
curl -s -u lab:lab -H content-type:application/json -X POST \
     -d '{"count":2,"ackmode":"ack_requeue_true","encoding":"auto"}' \
     http://rabbitmq:15672/api/queues/%2F/lavori/get | jq -c '.[]|{payload,redelivered,message_count}'
# {"payload":"ridimensiona foto2.jpg","redelivered":false,"message_count":3}
# {"payload":"invia-email anna@example.com","redelivered":false,"message_count":2}
```
`message_count` è quanti ne restano dopo questo. Per **svuotare** una coda: `curl -X DELETE .../api/queues/%2F/lavori/contents` (risponde `204`); per cancellarla: `amqp-delete-queue --url=$U -q lavori`
(stampa quanti messaggi c'erano).

## Un consumer: `amqp-consume` e l'ack
`amqp-consume` lancia un comando **per ogni messaggio**, con il corpo sullo **stdin**. Il comando decide l'esito con il suo codice d'uscita: `0` = ack, il messaggio sparisce; diverso da 0 = nessun ack, il messaggio **resta in coda**.
```bash
cat worker.sh
# read -r lavoro
# echo "elaboro: $lavoro"
# [[ $lavoro == fattura* ]] && { echo "errore su: $lavoro" >&2; exit 1; }
# exit 0
amqp-consume --url=$U -q lavori -c 4 ./worker.sh          # -c 4: si ferma dopo 4 messaggi
# elaboro: ridimensiona foto2.jpg
# elaboro: invia-email anna@example.com
# elaboro: invia-email bruno@example.com
# elaboro: fattura 2026-0042
# errore su: fattura 2026-0042
curl -s -u lab:lab http://rabbitmq:15672/api/queues/%2F/lavori | jq -c '{messages,messages_ready,messages_unacknowledged}'
# {"messages":1,"messages_ready":1,"messages_unacknowledged":0}
```
Quattro messaggi letti, **tre confermati**: il quarto, il cui worker è uscito con 1, è tornato in coda. Il codice d'uscita di `amqp-consume` resta `0`.

- `-p N` (*prefetch*) limita i messaggi consegnati e non ancora confermati: con `-p 1` il consumer ne tiene **uno alla volta**. Con un worker lento e `-p 1` la coda mostra `messages_unacknowledged: 1`, e gli altri
  restano `messages_ready` per gli altri consumer
- `-A` (`--no-ack`) conferma subito, **alla consegna**: se il comando fallisce il messaggio è perso, e con `-c 1` anche i messaggi già arrivati al client e non ancora elaborati (provato: due messaggi in coda, `amqp-consume -A -c 1 false`, e la coda era vuota)
- il comando riceve **un messaggio alla volta**: per un parametro del comando, non si può usare l'opzione `-c` di `sh -c` (la prenderebbe `amqp-consume`): meglio uno script, come `worker.sh`
- un consumer che **cade** con un messaggio non confermato (provato con `kill` su un `amqp-consume` lento) lo fa tornare in coda con `redelivered: true`: per questo un consumer deve essere **idempotente**, perché lo stesso messaggio
  può arrivare due volte (*at-least-once*)

## Exchange e routing
Un exchange `topic` smista per **schema** della routing key: `*` vale una parola, `#` zero o più.
```bash
A='curl -s -u lab:lab -H content-type:application/json'; H=http://rabbitmq:15672/api
amqp-declare-queue --url=$U -q ordini -d
amqp-declare-queue --url=$U -q fatture -d
$A -X PUT  -d '{"type":"topic","durable":true}'  $H/exchanges/%2F/eventi -w '%{http_code}\n'                      # 201
$A -X POST -d '{"routing_key":"ordine.*"}'       $H/bindings/%2F/e/eventi/q/ordini -w '%{http_code}\n'            # 201
$A -X POST -d '{"routing_key":"*.pagato"}'       $H/bindings/%2F/e/eventi/q/fatture -w '%{http_code}\n'           # 201
for k in ordine.creato ordine.pagato fattura.pagato spedizione.partita; do
    amqp-publish --url=$U -e eventi -r $k -b "evento $k"
done
curl -s -u lab:lab $H/queues/%2F | jq -c '.[]|{name,messages}'
# {"name":"fatture","messages":2}
# {"name":"lavori","messages":1}
# {"name":"ordini","messages":2}
amqp-consume --url=$U -q ordini -c 2 cat ; echo
# evento ordine.creatoevento ordine.pagato
amqp-consume --url=$U -q fatture -c 2 cat ; echo
# evento ordine.pagatoevento fattura.pagato
```
`ordine.pagato` è finito in **entrambe** le code (corrisponde a tutti e due gli schemi), `spedizione.partita` **in nessuna**: un messaggio che non corrisponde a nessun binding viene **scartato** senza errore. I corpi sono
attaccati perché i messaggi non hanno un a capo.

| Tipo | Come smista |
|---|---|
| `direct` | alla coda il cui binding ha **esattamente** quella routing key |
| `fanout` | a **tutte** le code collegate, ignorando la routing key (un evento per molti ascoltatori) |
| `topic` | per schema con `*` e `#` |
| `headers` | secondo gli header del messaggio, non la routing key |

## Errori tipici
```bash
amqp-publish --url=$U -e nonesiste -r x -b y
# closing channel: server channel error 404, message: NOT_FOUND - no exchange 'nonesiste' in vhost '/'
amqp-publish --url=amqp://lab:sbagliata@rabbitmq -r x -b y
# logging in to AMQP server: server connection error 403, message: ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN. ...
amqp-declare-queue --url=$U -q transitoria
# queue.declare: server connection error 541, message: INTERNAL_ERROR - Feature `transient_nonexcl_queues` is deprecated.
# By default, this feature is not permitted anymore.
```
Tutti e tre escono con `1`. L'ultimo è una novità di RabbitMQ 4: una coda **non durevole e non esclusiva** non si può più creare. Si dichiara con `-d` (durevole), oppure con `amqp-consume -x` (esclusiva: vive finché dura il consumer).
Un messaggio pubblicato senza `-p` è *transient*: dopo un riavvio del broker (`docker restart`) in una coda durevole è rimasto **solo** quello pubblicato con `amqp-publish -p`.

## TTL, lunghezza massima e dead letter
Una coda può scartare i messaggi vecchi o in eccesso, e mandarli a un **dead letter exchange** invece di perderli: è il modo per non buttare via un lavoro che non è stato eseguito in tempo.
```bash
$A -X PUT  -d '{"type":"fanout","durable":true}' $H/exchanges/%2F/morti -w '%{http_code}\n'      # exchange dei "morti"
$A -X PUT  -d '{"durable":true}'                 $H/queues/%2F/scartati -w '%{http_code}\n'
$A -X POST -d '{}'                               $H/bindings/%2F/e/morti/q/scartati -w '%{http_code}\n'
$A -X PUT  -d '{"durable":true,"arguments":{"x-message-ttl":2000,"x-dead-letter-exchange":"morti","x-max-length":3,"x-overflow":"drop-head"}}' \
           $H/queues/%2F/breve -w '%{http_code}\n'
for i in 1 2 3 4 5; do amqp-publish --url=$U -r breve -b "m$i"; done
sleep 8
$A $H/queues/%2F | jq -c '.[]|select(.name=="breve" or .name=="scartati")|{name,messages}'
# {"name":"breve","messages":0}
# {"name":"scartati","messages":5}
$A -X POST -d '{"count":5,"ackmode":"ack_requeue_true","encoding":"auto"}' $H/queues/%2F/scartati/get \
   | jq -c '.[]|{payload, reason: .properties.headers["x-death"][0].reason}'
# {"payload":"m1","reason":"maxlen"}
# {"payload":"m2","reason":"maxlen"}
# {"payload":"m3","reason":"expired"}
# {"payload":"m4","reason":"expired"}
# {"payload":"m5","reason":"expired"}
```
La coda `breve` tiene al massimo 3 messaggi (`x-max-length`, con `drop-head`: butta i **più vecchi**) e ciascuno vive 2 secondi (`x-message-ttl`). `m1` e `m2` sono usciti per lunghezza, gli altri per scadenza, e sono finiti in
`scartati` con l'header `x-death` che dice **perché**. La stessa strada si usa per un messaggio rifiutato dal consumer (`basic.nack` senza rimetterlo in coda).

## vhost e utenti
Un **vhost** è uno spazio separato dentro lo stesso broker: code, exchange e permessi propri (`/` è quello predefinito). Si usa uno per ambiente o per applicazione, con un utente che vede solo il suo.
```bash
$A -X PUT $H/vhosts/prod -w '%{http_code}\n'                                                                       # 201
$A -X PUT -d '{"password":"s3gr3ta","tags":""}' $H/users/servizio -w '%{http_code}\n'                              # 201
$A -X PUT -d '{"configure":"^coda-.*","write":".*","read":"^coda-.*"}' $H/permissions/prod/servizio -w '%{http_code}\n'   # 201
S=amqp://servizio:s3gr3ta@rabbitmq/prod
amqp-declare-queue --url=$S -q coda-uno -d
# coda-uno
amqp-declare-queue --url=$S -q altra -d
# queue.declare: server channel error 403, message: ACCESS_REFUSED - configure access to queue 'altra' in vhost 'prod' refused for user 'servizio'
```
I tre permessi sono **espressioni regolari** sui nomi: *configure* (creare e cancellare), *write* (pubblicare) e *read* (consumare, e collegare le code). L'utente `servizio` può creare solo le code che cominciano per `coda-`.
`tags: ""` = nessun accesso all'interfaccia di gestione (`administrator` ne dà tutti i diritti: è quello di `lab`).

## `rabbitmqctl` e diagnostica
Dal secondo terminale dell'host (con l'alias `rmq='docker compose -f 09-strumenti/lab/compose.yaml exec rabbitmq'`):
```bash
rmq rabbitmqctl list_queues name messages consumers
# name	messages	consumers
# ordini	0	0
# fatture	0	0
# lavori	1	0
rmq rabbitmqctl list_exchanges name type          # amq.direct, amq.fanout, amq.topic... più "eventi topic" e "morti fanout"
rmq rabbitmqctl list_bindings source_name destination_name routing_key
# source_name	destination_name	routing_key
# 	ordini	ordini                 <- l'exchange senza nome ha un binding implicito per ogni coda
# eventi	fatture	*.pagato
# eventi	ordini	ordine.*
rmq rabbitmqctl list_users                        # lab  [administrator]
rmq rabbitmqctl list_vhosts                       # prod, /
rmq rabbitmqctl list_permissions -p prod          # servizio  ^coda-.*  .*  ^coda-.*
rmq rabbitmq-diagnostics check_running
# RabbitMQ on node rabbit@rabbitmq is fully booted and running
rmq rabbitmq-plugins list -e                      # rabbitmq_management, rabbitmq_prometheus (e i plugin da cui dipendono)
rmq rabbitmqctl status                            # versione, memoria, plugin attivi, limiti
```
(Gli output di `list_queues` e `list_bindings` sono quelli dopo gli esempi di questa pagina.)

## Monitoraggio
Il plugin `rabbitmq_prometheus` è già attivo: le metriche sono in formato Prometheus sulla porta `15692` (vedi [../12-osservabilita/](../12-osservabilita/)).
```bash
curl -s http://rabbitmq:15692/metrics | grep -E '^rabbitmq_(queue_messages_ready|connections|channels) '
# rabbitmq_queue_messages_ready 6
# rabbitmq_connections 0
# rabbitmq_channels 0
curl -s http://rabbitmq:15692/metrics | grep -c '^rabbitmq_'      # 293 righe di metriche
```
Le cose da tenere d'occhio: i messaggi **pronti** che crescono (i consumer non stanno al passo), i **non confermati** fermi (un consumer bloccato), le connessioni, l'uso di memoria e disco (sopra una soglia il broker
**blocca i producer**).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `INTERNAL_ERROR - Feature transient_nonexcl_queues is deprecated` | coda non durevole e non esclusiva, non più ammessa in RabbitMQ 4 | `amqp-declare-queue -d`, oppure una coda esclusiva (`amqp-consume -x`) |
| `ACCESS_REFUSED - Login was refused` | utente o password sbagliati (o utente senza permessi sul vhost) | `rabbitmqctl list_users`, `list_permissions -p VHOST` |
| `ACCESS_REFUSED - configure access to queue ... refused` | l'espressione *configure* dell'utente non corrisponde al nome | `PUT /api/permissions/VHOST/UTENTE` |
| `NOT_FOUND - no exchange 'x' in vhost '/'` | l'exchange non esiste | dichiararlo, o pubblicare sul default (senza `-e`) |
| un messaggio pubblicato non arriva a nessuno | nessun binding corrisponde alla routing key: viene scartato senza errore | `list_bindings`, o un exchange *alternate* |
| i contatori delle code sono `null` | le statistiche si aggiornano ogni 5 secondi | aspettare qualche secondo |
| i messaggi tornano in coda ogni volta | il consumer esce con un errore (o cade) prima dell'ack | correggere il consumer, e usare una coda dei morti |
| `curl: (7) Failed to connect ... 15672` | dall'host le porte del laboratorio non sono pubblicate | si usa dalla shell del laboratorio, o si aggiunge `ports:` al servizio |

**Non provato** nel laboratorio: l'interfaccia web di gestione (`http://localhost:15672` sull'host, richiede la pubblicazione della porta), il cluster di più nodi e le *quorum queue*, TLS, le *stream*.

Torna all'[indice dell'area](README.md)
