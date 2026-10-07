# Scenari guidati: lo script non fa quello che dovrebbe

> **Laboratorio**: `./lab.sh 09`, poi `cd 14-scenari`. Qui non si prova un comando: **c'è un problema vero** (uno script, un permesso, un indice, un repository, una coda...) da capire e riparare (vedi [lab/](lab/)).

Gli strumenti dell'area si imparano uno alla volta; nel lavoro si incontrano quando **qualcosa non torna**: un file vuoto, un conteggio sbagliato, un errore di permessi, una query lenta, un commit sparito, un messaggio che non arriva. Qui c'è solo il **sintomo**, come lo racconterebbe un collega, e la causa va trovata.
Otto problemi diversi, uno per volta: [`curl` e `jq`](01-jq-e-curl.md) (due), [MySQL](03-mysql.md) (due), [git](02-git.md) (due), [RabbitMQ](11-rabbitmq.md) e [Kafka](12-kafka.md).

## Come si lavora
```bash
cd ~/lab/14-scenari
./scenari.sh guasta 3          # azzera tutto, prepara lo scenario 3 in lavoro/ e stampa il "ticket" (il sintomo)
cd lavoro                      # ...diagnosi e riparazione, con quello che vuoi...
~/lab/14-scenari/scenari.sh controlla      # dice se è risolto; non rivela la causa (da qualunque cartella)
~/lab/14-scenari/scenari.sh ripristina    # toglie ogni guasto (anche se ti sei perso)
```
- `controlla` guarda **l'effetto**, non il comando che hai usato: vale qualunque riparazione che funzioni davvero, e a volte chiede anche che la soluzione **non sia troppo larga** (in 3 niente `ALL PRIVILEGES`).
- `scenari.sh` **non va aperto** prima di aver provato: contiene i guasti. Ogni scenario ha un suggerimento e la soluzione, nascosti.
- I file dello scenario stanno in `~/lab/14-scenari/lavoro/`: si **modificano** lì (script, repository). Ogni `guasta N` li ricrea da zero.
- Dalla shell si arriva a tutto: MySQL come `root` (`mysql app_db`, le credenziali sono in `~/.my.cnf`), `curl` e `jq` verso `http://api`, `amqp-publish` e l'API di RabbitMQ (`lab` / `lab`), `kcat` verso `kafka:9092`, `git`.
- Gli scenari si fanno in qualunque ordine. Se un tentativo peggiora le cose: `./scenari.sh guasta N` riparte da zero.

## Il metodo: guardare cosa succede davvero
Prima di cambiare qualcosa, **un solo dato in più** per volta. Domande che valgono quasi sempre:

| Domanda | Come si risponde |
|---|---|
| lo script **dice** qualcosa, o tace? | il codice di uscita (`echo $?`) e lo `stderr`: un comando può fallire in silenzio, o riuscire senza fare nulla |
| cosa vede **lo strumento**, non il mio script? | rifare **a mano** il comando che lo script lancia, passo per passo (`curl -si`, `jq length`, `git status`) |
| **dove** si ferma il dato? | un pezzo per volta lungo il percorso: client → servizio → archivio |
| quante volte lo vedo, e quante dovrei? | confrontare un numero con uno che conosco (10 utenti, 15 elementi, 5 messaggi) |
| il servizio mi racconta **perché**? | il messaggio d'errore per intero, i permessi (`SHOW GRANTS`), il piano (`EXPLAIN`), il registro (`git reflog`), le associazioni (l'API di RabbitMQ) |

---

## 1. Lo script non stampa niente
**Ticket**: *Lo script `lavoro/scarica.sh` dovrebbe stampare quanti utenti ha l'API (sono 10), ma non stampa niente.*

<details><summary>da dove cominciare</summary>

Guarda cosa contiene `utenti.json` dopo averlo lanciato, e rifai a mano il `curl` che lo riempie, con `-i` per vedere anche le intestazioni.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/14-scenari/lavoro
bash scarica.sh; echo rc=$?                      # nessun errore e nessun output: il guasto è silenzioso
# rc=0
ls -l utenti.json                                # il file esiste... ed è vuoto
# -rw-r--r-- 1 root root 0 Oct  7 06:17 utenti.json
curl -si http://api/redirect | head -5           # cosa risponde davvero l'indirizzo dello script?
# HTTP/1.0 301 Moved Permanently
# Location: /users
```
L'indirizzo dello script è un **reindirizzamento** (`301`, corpo vuoto, `Location: /users`): `curl` **non lo segue** se non glielo si chiede, `utenti.json` resta vuoto, e `jq length` su un file vuoto non stampa niente **e non fallisce**. Si può puntare all'indirizzo giusto, o dire a `curl` di seguire (`-L`):
```bash
sed -i 's#http://api/redirect#http://api/users#' scarica.sh
bash scarica.sh
# 10
```
Un `echo 10` al posto dello script darebbe il numero giusto, ma `controlla` rifà il lavoro: cancella `utenti.json`, rilancia lo script e guarda che il file sia stato **riscritto** con i 10 utenti. Vedi `-L` e `-f` in [01-jq-e-curl](01-jq-e-curl.md): con `-f` un errore HTTP sarebbe stato visibile.
</details>

## 2. Il conteggio è 5 invece di 15
**Ticket**: *Lo script `lavoro/conta-items.sh` dovrebbe stampare il numero di elementi in tutto (le pagine sono più d'una), ma stampa 5.*

<details><summary>da dove cominciare</summary>

Guarda **una pagina per volta** quello che risponde l'API `/items?page=N`, finché non finiscono. Come fa lo script a sapere quando fermarsi?
</details>
<details><summary>soluzione</summary>

```bash
bash conta-items.sh
# 5
for p in 1 2 3 4; do echo -n "pagina $p: "; curl -s "http://api/items?page=$p" | jq -c 'length'; done
# pagina 1: 5
# pagina 2: 5
# pagina 3: 5
# pagina 4: 0                                    <- dopo l'ultima pagina l'API risponde con una lista vuota
```
L'API è **paginata**: 5 elementi per pagina, e `[]` quando le pagine sono finite. Lo script legge solo la prima. Serve un ciclo che si ferma alla prima pagina vuota:
```bash
tot=0; p=1
while :; do
    k=$(curl -s "http://api/items?page=$p" | jq length)
    (( k )) || break                             # lista vuota: finito
    tot=$((tot + k)); p=$((p + 1))
done
echo "$tot"
# 15
```
Cambiare `page=1` in `page=2` darebbe ancora 5. Un `15` scritto a mano non è una soluzione: se domani gli elementi diventano 17 il numero è sbagliato (e la fine delle pagine non è `3`, è "una pagina vuota"). Vedi la paginazione in [01-jq-e-curl](01-jq-e-curl.md).
</details>

## 3. "SELECT command denied"
**Ticket**: *Lo script `lavoro/report.sh` (utente `report`) dà un errore invece di contare gli ordini.*

<details><summary>da dove cominciare</summary>

L'errore dice **cosa** non si può fare e **a chi**. Guarda cosa ha il permesso di fare l'utente `report` (`SHOW GRANTS FOR ...`), da `root`.
</details>
<details><summary>soluzione</summary>

```bash
bash report.sh
# ERROR 1142 (42000) at line 1: SELECT command denied to user 'report'@'172.21.0.7' for table 'orders'
mysql -N -e "SHOW GRANTS FOR 'report'@'%'"       # da root (~/.my.cnf)
# GRANT USAGE ON *.* TO `report`@`%`
# GRANT SELECT ON `app_db`.`users` TO `report`@`%`
```
L'utente `report` può leggere `users`, ma non `orders`: manca un permesso, e l'errore nominava proprio la tabella. Si dà **solo quello che serve** (una lettura, su quella tabella):
```bash
mysql -e "GRANT SELECT ON app_db.orders TO 'report'@'%'"
bash report.sh
# 3000
```
`GRANT ALL PRIVILEGES ON app_db.* TO report` farebbe funzionare lo script, ma regala a un utente di sola lettura la scrittura e la cancellazione di **tutto**: `controlla` lo respinge (niente `ALL`, niente `INSERT`/`UPDATE`/`DELETE`). Vedi gli utenti applicativi in [03-mysql](03-mysql.md).
</details>

## 4. Una query lenta
**Ticket**: *`lavoro/cerca-log.sh` funziona, ma in produzione (con 20 milioni di righe in `logs`, non 20 mila) ci mette minuti. Va resa veloce.*

<details><summary>da dove cominciare</summary>

Non serve cronometrare: `EXPLAIN` dice **come** MySQL eseguirebbe la query. Prova la forma `EXPLAIN FORMAT=TRADITIONAL` e guarda le colonne `type`, `key` e `rows`.
</details>
<details><summary>soluzione</summary>

```bash
mysql app_db -e "EXPLAIN SELECT COUNT(*) FROM logs WHERE created_at >= '2026-09-14 10:00:00' AND created_at < '2026-09-14 11:00:00'\G" | head -3
# *************************** 1. row ***************************
# EXPLAIN: -> Aggregate: count(0)  (cost=2559 rows=1)
#     -> Filter: ((`logs`.created_at >= TIMESTAMP'2026-09-14 10:00:00') and (`logs`.created_at < ...
```
In MySQL 9 il `EXPLAIN` predefinito è un **albero** di testo; per la tabella classica serve `FORMAT=TRADITIONAL`:
```bash
mysql app_db -e "EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) FROM logs WHERE created_at >= '2026-09-14 10:00:00' AND created_at < '2026-09-14 11:00:00'"
# id  select_type  table  partitions  type  possible_keys  key   key_len  ref   rows   filtered  Extra
# 1   SIMPLE       logs   NULL        ALL   NULL           NULL  NULL     NULL  20053  11.11     Using where
mysql app_db -e 'SHOW INDEX FROM logs' | cut -f1-5
# Table  Non_unique  Key_name  Seq_in_index  Column_name
# logs   0           PRIMARY   1             id
```
`type = ALL` e `key = NULL`: MySQL **legge tutte le righe** (`rows` = 20053) per trovarne 60. Sulla colonna `created_at` non c'è nessun indice (c'è solo la chiave primaria): con 20 milioni di righe sarebbero 20 milioni di letture. Si crea l'indice e si rilegge il piano:
```bash
mysql app_db -e 'CREATE INDEX idx_logs_created_at ON logs (created_at)'
mysql app_db -e "EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) FROM logs WHERE created_at >= '2026-09-14 10:00:00' AND created_at < '2026-09-14 11:00:00'"
# 1  SIMPLE  logs  NULL  range  idx_logs_created_at  idx_logs_created_at  5  NULL  60  100.00  Using where; Using index
```
Ora `type = range`, usa l'indice, e `rows` è 60 (quanti ne servono). `ANALYZE TABLE` aggiorna le statistiche ma **non crea** indici, e `controlla` lo verifica. Un indice costa: spazio e tempo a ogni scrittura (vedi [03-mysql](03-mysql.md)): se ne crea uno per le ricerche che si fanno davvero.
</details>

## 5. Il commit è sparito
**Ticket**: *Nel repository `lavoro/progetto` hai fatto il commit "lavoro importante: fattura", poi un `git reset --hard` e ora non c'è più: né nel log, né il file `fattura.txt`.*

<details><summary>da dove cominciare</summary>

Git non butta via i commit subito: `git log` mostra solo quelli raggiungibili dal ramo, ma c'è un **registro di tutti gli spostamenti** di `HEAD`.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/14-scenari/lavoro/progetto
git log --oneline                                # il commit non c'è
# b8dc5d5 aggiunto il listino
# 40fc2b8 prima bozza
git reflog                                       # il registro degli spostamenti di HEAD
# b8dc5d5 HEAD@{0}: reset: moving to HEAD~1
# a7208e6 HEAD@{1}: commit: lavoro importante: fattura           <- è ancora qui
# b8dc5d5 HEAD@{2}: commit: aggiunto il listino
# 40fc2b8 HEAD@{3}: commit (initial): prima bozza
git reset --hard 'HEAD@{1}'                      # si torna a com'era prima del reset
# HEAD is now at a7208e6 lavoro importante: fattura
ls
# fattura.txt  listino.txt  note.txt
```
Il `reset --hard` ha spostato il ramo indietro di un commit, ma **non ha cancellato** il commit: il `reflog` lo ricorda e `git reset --hard HEAD@{1}` (o direttamente l'hash, `a7208e6`) riporta il ramo lì. I commit non più raggiungibili vengono eliminati da git solo dopo un po' di tempo (per il `reflog`, 90 giorni di predefinito: dalla documentazione di git, non provato qui). `git checkout .` non serve: ripristina i file modificati, non fa tornare un commit. Vedi `reflog` in [02-git](02-git.md).
</details>

## 6. Il merge è rimasto a metà
**Ticket**: *In `lavoro/app` un `git merge feature` è finito con un conflitto: `config.txt` è pieno di segni strani e il merge non è concluso. Servono sia il `timeout` sia il `debug`.*

<details><summary>da dove cominciare</summary>

`git status` dice cosa è rimasto da fare. Apri `config.txt`: i segni `<<<<<<<`, `=======` e `>>>>>>>` separano le **due versioni** della stessa riga; il file va riscritto come lo vuoi tu.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/14-scenari/lavoro/app
git status | head -8
# On branch main
# You have unmerged paths.
#   (fix conflicts and run "git commit")
#   (use "git merge --abort" to abort the merge)
# Unmerged paths:
#   (use "git add <file>..." to mark resolution)
# 	both modified:   config.txt
cat config.txt
# <<<<<<< HEAD
# colore=verde
# porta=80
# timeout=30
# =======
# colore=rosso
# porta=80
# debug=true
# >>>>>>> feature
```
Le due versioni cambiano la **stessa riga** (`colore`) e git non può scegliere al posto tuo; le altre righe (`timeout=30` da `main`, `debug=true` da `feature`) le tiene entrambe solo se le tieni tu. Si riscrive il file **senza segni**, con il colore che si vuole e le due righe nuove, poi si conclude:
```bash
printf 'colore=verde\nporta=80\ntimeout=30\ndebug=true\n' > config.txt
git add config.txt                               # "ho risolto questo file"
git commit -m 'merge feature'                    # conclude il merge
git log --oneline --graph
# *   f28b72a merge feature
# |\
# | * dc51c31 debug acceso, colore rosso
# * | a0a8ea0 timeout a 30, colore verde
# |/
# * c926152 configurazione iniziale
```
`git merge --abort` fa sparire il conflitto, ma anche il merge: `timeout` e `debug` non starebbero insieme, e `controlla` chiede un commit di merge con tutti e due. Se togli solo i segni e dimentichi `git add` e `git commit`, il merge resta aperto (`git status` lo dice; non provato qui).
</details>

## 7. Un messaggio che non arriva
**Ticket**: *`lavoro/invia.sh` pubblica un ordine senza nessun errore, ma la coda `da-spedire` resta vuota.*

<details><summary>da dove cominciare</summary>

In RabbitMQ chi pubblica non parla con la coda, ma con un **exchange**, che smista secondo le **associazioni** (binding) e la routing key. Guarda con l'API che associazioni ha l'exchange `ordini`, e confrontale con quello che manda lo script.
</details>
<details><summary>soluzione</summary>

```bash
bash invia.sh; echo rc=$?                        # nessun errore: la pubblicazione all'exchange riesce sempre
# rc=0
curl -s -u lab:lab http://rabbitmq:15672/api/queues/%2F/da-spedire | jq -c '{messages,messages_ready}'
# {"messages":0,"messages_ready":0}              (le statistiche si aggiornano ogni 5 secondi circa)
curl -s -u lab:lab http://rabbitmq:15672/api/exchanges/%2F/ordini/bindings/source | jq -c '.[]|{routing_key,destination}'
# {"routing_key":"nuovo","destination":"da-spedire"}              <- l'exchange smista verso la coda solo la chiave "nuovo"
curl -s -u lab:lab http://rabbitmq:15672/api/exchanges/%2F/ordini | jq -c '{type,message_stats}'
# {"type":"direct","message_stats":{"publish_in":1,"publish_in_details":{"rate":0.0}}}        <- è arrivato 1 messaggio, ma non ne è uscito nessuno
cat invia.sh | tail -1
# amqp-publish --url=amqp://lab:lab@rabbitmq -e ordini -r nuovi -b "ordine $RANDOM"             <- lo script manda "nuovi"
```
L'exchange `ordini` è di tipo `direct`: consegna alla coda solo se la routing key **combacia esattamente** con l'associazione. Lo script manda `nuovi`, l'associazione è `nuovo`: nessuna coda corrisponde e il messaggio viene **scartato in silenzio** (`publish_in: 1` e nessun `publish_out`). Si corregge la chiave (o si aggiunge un'associazione per `nuovi`, ma qui è lo script a sbagliare):
```bash
sed -i 's/-r nuovi /-r nuovo /' invia.sh
bash invia.sh; sleep 6
curl -s -u lab:lab http://rabbitmq:15672/api/queues/%2F/da-spedire | jq -c '{messages,messages_ready}'
# {"messages":1,"messages_ready":1}
```
Un'altra chiave sbagliata (`nuov`) non basta: `controlla` svuota la coda, lancia `invia.sh` e aspetta di vederci **un** messaggio (per questo ci mette qualche secondo). Vedi exchange e binding in [11-rabbitmq](11-rabbitmq.md).
</details>

## 8. Il consumer non vede niente
**Ticket**: *`lavoro/leggi.sh` dovrebbe stampare gli eventi del topic `eventi-NNNNNNNNNN` (ci sono 5 messaggi), ma non stampa niente.* (Il numero del topic cambia a ogni `guasta` ed è scritto nel ticket.)

<details><summary>da dove cominciare</summary>

Il topic non è vuoto: guarda le opzioni di `kcat` nello script. **Da dove** comincia a leggere?
</details>
<details><summary>soluzione</summary>

```bash
cat leggi.sh | tail -1
# kcat -b kafka:9092 -C -t eventi-1791353829 -o end -e -q          <- -o end: parte dalla fine
bash leggi.sh; echo rc=$?
# rc=0
kcat -b kafka:9092 -L -t eventi-1791353829 | head -4             # il topic c'è
# Metadata for eventi-1791353829 (from broker 1: kafka:9092/1):
#  1 brokers:
#   broker 1 at kafka:9092 (controller)
#  1 topics:
kcat -b kafka:9092 -C -t eventi-1791353829 -e -q -f '%o %s\n' -o beginning       # leggendo dall'inizio ci sono, con i loro offset
# 0 avvio
# 1 login anna
# 2 login bruno
# 3 ordine 1
# 4 spegnimento
```
Il topic ha 5 messaggi (offset da 0 a 4), ma lo script legge con `-o end`: **parte dopo l'ultimo** e, con `-e`, esce subito perché non c'è altro. Kafka **non cancella** i messaggi quando vengono letti: ogni consumer decide da quale **offset** partire. Si legge dall'inizio:
```bash
sed -i 's/-o end/-o beginning/' leggi.sh
bash leggi.sh
# avvio
# login anna
# login bruno
# ordine 1
# spegnimento
```
Leggere solo l'ultimo messaggio (`-o -1`) ne darebbe uno e basta. Per un consumer **di gruppo** il punto di partenza lo decide anche `auto.offset.reset` (`earliest` o `latest`), quando il gruppo non ha ancora un offset salvato: non provato qui. Vedi offset e gruppi in [12-kafka](12-kafka.md).
</details>

---

## Riepilogo: come si riconosce
| Sintomo | Dove guardare | Prima mossa |
|---|---|---|
| script che riesce ma non stampa niente | il file intermedio, la risposta vera | `ls -l`, `curl -si` (1) |
| conteggio troppo basso | l'API è paginata | una pagina per volta fino a `[]` (2) |
| `SELECT command denied` | i permessi dell'utente | `SHOW GRANTS FOR` (3) |
| query lenta | il piano, non il cronometro | `EXPLAIN FORMAT=TRADITIONAL`: `type`, `key`, `rows` (4) |
| commit sparito dopo un `reset` | il registro di `HEAD` | `git reflog` (5) |
| merge a metà | i segni di conflitto | `git status`, riscrivere, `git add`, `git commit` (6) |
| messaggio pubblicato che non arriva | exchange, binding, routing key | l'API di RabbitMQ: `bindings`, `message_stats` (7) |
| il consumer non vede i messaggi | l'offset di partenza | `kcat -o beginning` (8) |

## Non provato
- Gli scenari agiscono su **MySQL, API, git, RabbitMQ e Kafka**: mancano MongoDB, Redis, PostgreSQL, `make` e `bats`.
- I dati sono piccoli (20 mila righe, 15 elementi, 5 messaggi): quello che con 20 milioni di righe conta davvero (il tempo) qui si **vede** solo dal piano di `EXPLAIN`.
- `auto.offset.reset` e i consumer di gruppo di Kafka non sono in uno scenario; la scadenza del `reflog` di git (90 giorni) è dalla documentazione.
- Il tempo per risolvere uno scenario non è stato misurato su una persona.

Torna all'[indice dell'area](README.md)
