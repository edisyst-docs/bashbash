# MongoDB da riga di comando

> **Laboratorio**: `./lab.sh 09`, poi `cd 13-mongodb`. File pronti: `nuovi.json`, `clienti.csv` (da [lab/materiale/](lab/materiale/)). Il server è l'host `mongo`; il database `app` ha già due collezioni, `utenti` e `ordini`
> ([lab/mongo-init/](lab/mongo-init/01-app.js)), e due utenti: `lab` / `lab` (amministratore) e `app` / `app` (legge e scrive solo nel database `app`).

**MongoDB** è un database a **documenti**: invece di righe in tabelle con colonne fisse, contiene documenti JSON (in realtà BSON, un JSON con più tipi) raggruppati in **collezioni**. Ogni documento può avere campi diversi,
contenere array e altri documenti, e ha un `_id` unico. Dove un database relazionale ([03-mysql.md](03-mysql.md), [06-postgresql.md](06-postgresql.md)) usa `JOIN` fra tabelle, qui si tende a **incorporare** i dati collegati nello stesso documento
(le righe di un ordine dentro l'ordine). Gli esempi sono stati eseguiti con MongoDB 8.0.32, `mongosh` 2.13.0 e gli strumenti `mongodump`, `mongorestore`, `mongoexport`, `mongoimport` 100.13.0 nel laboratorio.

| SQL | MongoDB |
|---|---|
| database | database |
| tabella | **collezione** |
| riga | **documento** |
| colonna | **campo** |
| `SELECT ... WHERE` | `find({filtro}, {proiezione})` |
| `GROUP BY` | `aggregate([{$group: ...}])` |
| indice | indice |

## Collegarsi con `mongosh`
`mongosh` è la shell: un interprete **JavaScript** collegato al database. Dal laboratorio si usa soprattutto con `--eval`, per un comando alla volta e per gli script (la sessione interattiva con il prompt si apre con il solo
indirizzo, ed è la stessa JavaScript; non è stata provata qui).
```bash
M='mongodb://app:app@mongo/app?authSource=app'          # mongodb://UTENTE:PASSWORD@HOST/DATABASE?authSource=DB-DELL-UTENTE
R='mongodb://lab:lab@mongo/?authSource=admin'
mongosh "$R" --quiet --eval 'db.version()'
# 8.0.32
mongosh "$R" --quiet --eval 'db.adminCommand({listDatabases:1}).databases.map(d => d.name)'
# [ 'admin', 'app', 'config', 'local' ]
mongosh "$M" --quiet --eval 'db.getCollectionNames()'
# [ 'ordini', 'utenti' ]
```
`--quiet` toglie le righe di benvenuto. Lo stesso, con le opzioni al posto dell'indirizzo: `mongosh --host mongo -u app -p app --authenticationDatabase app app` (l'ultimo `app` è il database).
In `--eval` il database corrente è `db`; con `db.getSiblingDB("altro")` si passa a un altro.

**L'utente vive in un database**, l'`authSource`: `lab` è in `admin`, `app` in `app`. Senza `authSource` si usa il database dell'indirizzo, e questo fa il pasticcio più comune:
```bash
mongosh "mongodb://app:app@mongo/app"  --quiet --eval 'db.utenti.countDocuments()'       # 7: l'utente è in app, e il database è app
mongosh "mongodb://lab:lab@mongo/app"  --quiet --eval 'db.utenti.countDocuments()'
# MongoServerError: Authentication failed.                                  <- lab è in admin, non in app
mongosh "mongodb://lab:lab@mongo/app?authSource=admin" --quiet --eval 'db.utenti.countDocuments()'    # 7
```
Senza credenziali ci si collega lo stesso, ma **ogni comando è rifiutato**:
```bash
mongosh mongodb://mongo --quiet --eval 'db.getSiblingDB("app").utenti.find().toArray()'
# MongoServerError: Command find requires authentication
```
(Un errore di password dà `MongoServerError: Authentication failed.`; un server spento `MongoNetworkError: connect ECONNREFUSED`; per non aspettare 30 secondi si aggiunge `?serverSelectionTimeoutMS=2000`.)

## Leggere: `find`
```bash
mongosh "$M" --quiet --eval 'db.utenti.find({citta:"Roma"}, {_id:0, nome:1, eta:1}).toArray()'
# [ { nome: 'Anna', eta: 31 }, { nome: 'Carla', eta: 28 } ]
```
`find(FILTRO, PROIEZIONE)`: il filtro è un documento; la proiezione dice quali campi tornare (`1` sì, `0` no: l'`_id` torna sempre se non lo si toglie). Senza `.toArray()` `mongosh --eval` stampa solo un cursore.
```bash
mongosh "$M" --quiet --eval 'db.utenti.find({eta:{$gte:40}}).sort({eta:-1}).limit(2).toArray()'
# [
#   { _id: 4, nome: 'Dario', citta: 'Torino', eta: 52, tag: [ 'ops' ] },
#   { _id: 2, nome: 'Bruno', citta: 'Milano', eta: 45, tag: [ 'dev' ] }
# ]
mongosh "$M" --quiet --eval 'db.utenti.find({tag:"dev"}, {nome:1}).toArray()'                  # un valore in un array: basta nominarlo
# [ { _id: 1, nome: 'Anna' }, { _id: 2, nome: 'Bruno' }, { _id: 5, nome: 'Elena' } ]
mongosh "$M" --quiet --eval 'db.utenti.find({$or:[{citta:"Torino"},{eta:{$lt:30}}]}, {_id:0,nome:1}).toArray()'
# [ { nome: 'Carla' }, { nome: 'Dario' } ]
mongosh "$M" --quiet --eval '[db.utenti.countDocuments({citta:"Milano"}), db.utenti.distinct("citta")]'
# [ 2, [ 'Milano', 'Roma', 'Torino' ] ]
```
Gli operatori cominciano con `$`:

| Operatore | Significato |
|---|---|
| `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` | confronti (`{eta:{$gte:40}}`; `{citta:"Roma"}` è `$eq`) |
| `$in`, `$nin` | il valore è (o non è) in un elenco |
| `$and`, `$or`, `$not` | logici (più campi nello stesso filtro sono già un `$and`) |
| `$exists` | il campo c'è: `{tag:{$exists:true}}` |
| `$regex` | espressione regolare: `{nome:{$regex:"^A"}}` |
| `$elemMatch` | un elemento dell'array che soddisfa più condizioni insieme |

`findOne(...)` torna un solo documento. Per avere **JSON vero** e passarlo a `jq` ([01-jq-e-curl.md](01-jq-e-curl.md)) c'è `--json`:
```bash
mongosh "$M" --quiet --json=relaxed --eval 'db.utenti.find({_id:1}).toArray()' | jq -c '.[0]'
# {"_id":1,"nome":"Anna","citta":"Roma","eta":31,"tag":["admin","dev"]}
```

## Aggregazioni
`aggregate` è una **pipeline**: una serie di fasi, e ciascuna lavora sul risultato della precedente.
```bash
mongosh "$M" --quiet --eval 'db.ordini.aggregate([
    {$match: {stato: "pagato"}},
    {$group: {_id: "$utente", totale: {$sum: "$totale"}, n: {$sum: 1}}},
    {$sort: {totale: -1}}
]).toArray()'
# [
#   { _id: 5, totale: 300, n: 1 },
#   { _id: 1, totale: 120.5, n: 1 },
#   { _id: 2, totale: 80, n: 1 }
# ]
```
`$match` filtra (come `WHERE`), `$group` raggruppa (`$utente` è il **valore** del campo `utente`) e `$sum` somma, `$sort` ordina. Un `JOIN` si ottiene con `$lookup`:
```bash
mongosh "$M" --quiet --eval 'db.ordini.aggregate([
    {$lookup: {from: "utenti", localField: "utente", foreignField: "_id", as: "u"}},
    {$unwind: "$u"},
    {$group: {_id: "$u.citta", totale: {$sum: "$totale"}}},
    {$sort: {_id: 1}}
]).toArray()'
# [ { _id: 'Milano', totale: 389.9 }, { _id: 'Roma', totale: 178.4 } ]
```
`$lookup` mette gli utenti corrispondenti in un array `u`; `$unwind` lo "srotola" (un documento per elemento). Gli utenti senza ordini (Torino) non compaiono. Le altre fasi di uso comune: `$project`, `$limit`, `$count`, `$addFields`.

## Scrivere
```bash
mongosh "$M" --quiet --eval 'db.utenti.insertOne({_id:6, nome:"Fabio", citta:"Roma", eta:60})'
# { acknowledged: true, insertedId: 6 }
mongosh "$M" --quiet --eval 'db.utenti.updateOne({_id:6}, {$set:{eta:61}, $push:{tag:"nuovo"}})'
# { acknowledged: true, insertedId: null, matchedCount: 1, modifiedCount: 1, upsertedCount: 0 }
mongosh "$M" --quiet --eval 'db.utenti.updateMany({citta:"Roma"}, {$inc:{eta:1}})'
# { acknowledged: true, insertedId: null, matchedCount: 3, modifiedCount: 3, upsertedCount: 0 }
mongosh "$M" --quiet --eval 'db.utenti.findOne({_id:6})'
# { _id: 6, nome: 'Fabio', citta: 'Roma', eta: 62, tag: [ 'nuovo' ] }
mongosh "$M" --quiet --eval 'db.utenti.deleteOne({_id:6})'
# { acknowledged: true, deletedCount: 1 }
mongosh "$M" --quiet --eval 'db.utenti.insertOne({_id:1, nome:"doppio"})'
# MongoServerError: E11000 duplicate key error collection: app.utenti index: _id_ dup key: { _id: 1 }
```
(Il risultato di `updateOne` è stato qui compattato su una riga.) **Un aggiornamento senza operatore** (`updateOne({_id:2}, {eta:99})`) è rifiutato con `MongoInvalidArgumentError: Update document requires atomic operators`: gli operatori `$set`, `$inc`, `$push`, `$unset` dicono *cosa* cambiare nel documento.
`$set` imposta, `$inc` somma, `$push` aggiunge a un array, `$unset` toglie un campo. Con `{upsert: true}` come terzo argomento il documento si crea se non esiste. `deleteMany({})` **svuota** la collezione: come `DELETE` senza `WHERE`.

## Indici
Senza indice, una ricerca legge **tutti** i documenti. `explain("executionStats")` dice come è stata eseguita:
```bash
mongosh "$M" --quiet --eval 'db.utenti.getIndexes().map(i => i.name)'
# [ '_id_', 'citta_1' ]
mongosh "$M" --quiet --eval 'var e=db.utenti.find({eta:{$gt:40}}).explain("executionStats"); ({stage:e.queryPlanner.winningPlan.stage, docsExamined:e.executionStats.totalDocsExamined})'
# { stage: 'COLLSCAN', docsExamined: 5 }
mongosh "$M" --quiet --eval 'db.utenti.createIndex({eta:1})'
# eta_1
mongosh "$M" --quiet --eval 'var e=db.utenti.find({eta:{$gt:40}}).explain("executionStats"); ({stage:e.queryPlanner.winningPlan.inputStage.stage, docsExamined:e.executionStats.totalDocsExamined, nReturned:e.executionStats.nReturned})'
# { stage: 'IXSCAN', docsExamined: 2, nReturned: 2 }
```
`COLLSCAN` = scansione dell'intera collezione (5 documenti letti per trovarne 2); `IXSCAN` = ha usato l'indice, e ha letto **solo i 2** documenti che servivano. L'indice `unique` rifiuta i doppioni:
```bash
mongosh "$M" --quiet --eval 'db.utenti.createIndex({nome:1}, {unique:true})'
# nome_1
mongosh "$M" --quiet --eval 'db.utenti.insertOne({_id:9, nome:"Anna"})'
# MongoServerError: E11000 duplicate key error collection: app.utenti index: nome_1 dup key: { nome: "Anna" }
mongosh "$M" --quiet --eval 'db.utenti.dropIndex("nome_1")'
# { nIndexesWas: 4, ok: 1 }
```
Ogni indice rende **più veloci le letture e più lente le scritture**, e occupa memoria: se ne creano solo per le ricerche che servono. Per un indice a più campi l'ordine conta (`{citta:1, eta:-1}` serve a cercare per `citta`, e per `citta` + `eta`).

## Utenti e ruoli
```bash
mongosh "$R" --quiet --eval 'db.getSiblingDB("app").getUsers().users.map(u => ({user:u.user, roles:u.roles}))'
# [ { user: 'app', roles: [ { role: 'readWrite', db: 'app' } ] } ]
mongosh "$M" --quiet --eval 'db.getSiblingDB("altro").x.insertOne({a:1})'
# MongoServerError: not authorized on altro to execute command { insert: "x", documents: [ ...
mongosh "$R" --quiet --eval 'db.getSiblingDB("app").createUser({user:"lettore", pwd:"l", roles:[{role:"read", db:"app"}]})'
# { ok: 1 }
mongosh "mongodb://lettore:l@mongo/app?authSource=app" --quiet --eval 'db.utenti.countDocuments()'
# 5
mongosh "mongodb://lettore:l@mongo/app?authSource=app" --quiet --eval 'db.utenti.insertOne({_id:50})'
# MongoServerError: not authorized on app to execute command { insert: "utenti", documents: [ ...
mongosh "$R" --quiet --eval 'db.getSiblingDB("app").dropUser("lettore")'
# { ok: 1 }
```
I ruoli di base: `read` e `readWrite` (su un database), `dbAdmin` (indici e statistiche, non i dati), `userAdmin` (gestire gli utenti), `root` (tutto: è quello di `lab`). L'applicazione deve usare un utente
`readWrite` sul **suo** database, mai `root`. Il server del laboratorio ha l'autenticazione attiva perché è partito con `MONGO_INITDB_ROOT_USERNAME`; un `mongod` avviato senza (provato con un container `mongo:8.0` a parte) **non chiede nessuna password**.

## Backup e ripristino
Gli strumenti del pacchetto *MongoDB Database Tools*:

| Comando | Cosa produce | Per cosa |
|---|---|---|
| `mongodump` / `mongorestore` | dump **binario** BSON (con gli indici) | il backup vero |
| `mongoexport` / `mongoimport` | JSON o CSV leggibile | passare dati ad altri sistemi, piccoli caricamenti |

```bash
mongodump --uri="$M" --out=dump
# writing app.ordini to dump/app/ordini.bson
# writing app.utenti to dump/app/utenti.bson
# done dumping app.ordini (6 documents)
# done dumping app.utenti (5 documents)
find dump -type f | sort
# dump/app/ordini.bson
# dump/app/ordini.metadata.json                  <- gli indici e le opzioni della collezione
# dump/app/prelude.json
# dump/app/utenti.bson
# dump/app/utenti.metadata.json
mongodump --uri="$M" --archive=app.gz --gzip        # un solo file compresso, comodo per `scp` e per [restic](../06-sistema/11-backup/)
```
Provato con un disastro: una collezione cancellata e dei documenti persi, poi il ripristino:
```bash
mongosh "$M" --quiet --eval 'db.ordini.drop(); db.utenti.deleteMany({citta:"Roma"}); db.utenti.countDocuments()'
# 3
mongorestore --uri="$M" --archive=app.gz --gzip --drop
# ... 11 document(s) restored successfully. 0 document(s) failed to restore.
mongosh "$M" --quiet --eval '[db.utenti.countDocuments(), db.ordini.countDocuments(), db.utenti.getIndexes().length]'
# [ 5, 6, 3 ]
```
Tornano 5 utenti, 6 ordini e **anche gli indici** (3: `_id_`, `citta_1`, `eta_1`). `--drop` cancella la collezione prima di ripristinarla: senza, i documenti già presenti fanno `E11000 duplicate key` e restano com'erano.
`mongodump` **non è un'istantanea coerente** se si scrive durante il dump (serve `--oplog` su un replica set); con `--db` e `--collection` si limita a una parte.

### Esportare e importare
```bash
mongoexport --uri="$M" -c utenti --query '{"citta":"Milano"}' --fields nome,eta
# {"_id":2,"nome":"Bruno","eta":45}
# {"_id":5,"nome":"Elena","eta":39}
mongoexport --uri="$M" -c utenti --type=csv --fields nome,citta,eta | head -3
# nome,citta,eta
# Anna,Roma,32
# Bruno,Milano,45
cat nuovi.json
# {"_id":10,"nome":"Gina","citta":"Bari","eta":33}
# {"_id":11,"nome":"Hugo","citta":"Bari","eta":47}
mongoimport --uri="$M" -c utenti nuovi.json
# ... 2 document(s) imported successfully. 0 document(s) failed to import.
mongoimport --uri="$M" -c utenti nuovi.json                      # di nuovo
# ... continuing through error: E11000 duplicate key error collection: app.utenti index: _id_ dup key: { _id: 11 }
# ... 0 document(s) imported successfully. 2 document(s) failed to import.
mongoimport --uri="$M" -c utenti --mode=upsert nuovi.json        # aggiorna se esiste, inserisce se no
mongoimport --uri="$M" -c clienti --type=csv --headerline clienti.csv        # CSV: la prima riga dà i nomi dei campi
# ... 2 document(s) imported successfully. 0 document(s) failed to import.
```
L'esportazione fa un documento JSON per riga (*JSON Lines*), come `nuovi.json`: si importa con `mongoimport` e si legge con `jq` ([01-jq-e-curl.md](01-jq-e-curl.md)). Con `--mode=upsert` su documenti identici a quelli già presenti il
conteggio è `0 imported`, perché non cambia nulla.

## Script e codici d'uscita
```bash
echo 'print(db.utenti.countDocuments({citta:"Bari"}))' > s.js
mongosh "$M" --quiet --file s.js
# 2
mongosh "$M" --quiet --eval 'throw new Error("boom")'; echo "rc=$?"
# Error: boom
# rc=1
mongosh "$M" --quiet --eval 'db.utenti.insertOne({_id:1})' > /dev/null 2>&1; echo "rc=$?"
# rc=1
```
Un errore del database o un'eccezione dà codice d'uscita **1**: negli script si controlla `$?` o si usa `set -e`. `--file` esegue un file `.js`; per stampare vanno bene `print()` e `console.log()`.

## Stato del server
```bash
mongosh "$R" --quiet --eval 'var s=db.serverStatus(); ({version:s.version, connections:s.connections.current, engine:s.storageEngine.name})'
# { version: '8.0.32', connections: 4, engine: 'wiredTiger' }
```
`db.serverStatus()` ha centinaia di contatori (connessioni, operazioni, memoria, cache di WiredTiger); `db.currentOp()` mostra le operazioni in corso, `db.getSiblingDB("app").utenti.stats()` le dimensioni di una collezione.
Il server del laboratorio occupa circa 200 MB di memoria.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `Authentication failed.` con la password giusta | l'utente è in un altro database: `authSource` sbagliato | `?authSource=admin` (per `root`) o il database dell'utente |
| `Command find requires authentication` | collegato senza credenziali | `mongodb://UTENTE:PASSWORD@host/...` |
| `not authorized on DB to execute command` | l'utente non ha il ruolo su quel database | `createUser` con il ruolo giusto, o `grantRolesToUser` |
| `MongoNetworkError: connect ECONNREFUSED` | server spento o host/porta sbagliati | controllare `mongod`; con `?serverSelectionTimeoutMS=2000` si fallisce subito |
| `E11000 duplicate key error` | un `_id` o un campo con indice `unique` già presente | un altro `_id`, o `--mode=upsert` / `updateOne({...}, {...}, {upsert:true})` |
| `--eval` stampa un cursore invece dei documenti | manca `.toArray()` | `db.coll.find(...).toArray()` |
| una query è lenta | nessun indice: `COLLSCAN` in `explain()` | `createIndex` sul campo del filtro |
| `mongosh` rifiuta un'opzione (`unrecognized option`) | opzione di un'altra shell o di una versione diversa | `mongosh --help` |

**Non provato** nel laboratorio: la sessione interattiva di `mongosh` (prompt, `show dbs`, `use`), i **replica set** e lo *sharding*, `mongodump --oplog`, le transazioni, gli indici di testo e geospaziali, TLS, MongoDB Atlas.

Torna all'[indice dell'area](README.md)
