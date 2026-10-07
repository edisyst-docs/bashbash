# Scenari guidati: il sito non risponde, e ora?

> **Laboratorio**: `./lab.sh 10`, poi `cd 11-scenari`. Qui non si prova un comando: **c'è un guasto vero** sul container `host`, da diagnosticare e riparare (vedi [lab/](lab/)).

Gli [esercizi](10-esercizi.md) dicono cosa fare; qui c'è solo un **sintomo**, come lo racconta un collega, e la causa va trovata. Sono otto guasti diversi su `host`, uno per volta:
nginx che non parte, una porta occupata, una rotta mancante o sbagliata, un nome che punta altrove, un reverse proxy che dà `502`, un firewall che lascia passare il `ping` ma non il web, una cartella senza permessi.
Gli strumenti sono quelli di [01](01-indirizzi-e-configurazione.md), [02](02-diagnostica.md) e [04](04-apache-nginx.md), più `systemctl`/`journalctl` di [06-sistema](../06-sistema/07-servizi.md) e i permessi di [02-file](../02-file-e-permessi/08-permessi.md).

## Come si lavora
```bash
cd ~/lab/11-scenari
./scenari.sh guasta 3          # porta il sistema in salute, lo rompe come lo scenario 3 e stampa il "ticket" (il sintomo)
# ...diagnosi e riparazione, con quello che vuoi...
./scenari.sh controlla         # dice se il sintomo è sparito; non rivela la causa
./scenari.sh ripristina        # toglie ogni guasto (anche se ti sei perso)
```
- `controlla` guarda **il sintomo**, non il comando che hai usato: vale qualunque riparazione che funzioni davvero. Dice anche cosa deve essere ancora vero (per esempio, in 2, che **apache2 continui a rispondere** sulla 8080: spegnerlo non vale).
- `scenari.sh` **non va aperto** prima di aver provato: contiene i guasti. Ogni scenario ha un suggerimento e la soluzione, nascosti.
- Il sito di cui si parla è `http://localhost:8090/` (nginx, risponde `benvenuti in azienda`); il server `web` è quello della rete (`curl http://web/` risponde `risposta da web`); `http://localhost:8091/` è un reverse proxy di nginx verso `web`.
- Gli scenari si fanno in qualunque ordine. Se un tentativo peggiora le cose: `./scenari.sh guasta N` riparte da zero.

## Il metodo: dal basso verso l'alto
Quando "il sito non risponde", la causa sta in uno di questi livelli. Si controlla **dal basso**, e ci si ferma al primo che non va:

| Livello | Domanda | Comando |
|---|---|---|
| nome | il nome diventa l'indirizzo giusto? | `getent hosts NOME` (non `dig`: non legge `/etc/hosts`) |
| rotta | i pacchetti partono dalla strada giusta? | `ip route get INDIRIZZO` |
| raggiungibilità | la macchina risponde? | `ping -c1 -W1 INDIRIZZO` |
| porta | la porta è aperta, o filtrata? | `nc -zv -w2 INDIRIZZO PORTA` (`refused` = chiusa, `timed out` = filtrata) |
| servizio | il processo c'è e ascolta? | `systemctl status`, `ss -ltnp`, `journalctl -u` |
| applicazione | cosa risponde davvero? | `curl -si URL` e il log (`/var/log/nginx/error.log`) |

`curl` che **resta appeso** (codice 28 con `-m`) e `curl` che **rifiuta subito** (codice 7) sono due problemi diversi: il primo è quasi sempre rete o firewall, il secondo è un servizio spento o sulla porta sbagliata.

---

## 1. Il sito non risponde più dopo una modifica
**Ticket**: *Il sito aziendale (`http://localhost:8090/`) non risponde più dopo l'ultima modifica alla sua configurazione.*

<details><summary>da dove cominciare</summary>

`curl` rifiuta subito la connessione: il livello è il servizio. Guarda se nginx è attivo e cosa dice quando lo si controlla.
</details>
<details><summary>soluzione</summary>

```bash
curl -s localhost:8090; echo "curl: $?"         # 7: connessione rifiutata, non c'è nessuno in ascolto
# curl: 7
systemctl status nginx --no-pager | head -6      # il servizio è caduto all'avvio
# × nginx.service - A high performance web server and a reverse proxy server
#      Active: failed (Result: exit-code) since ...
#     Process: 275 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=1/FAILURE)
nginx -t                                         # la configurazione ha un errore, e dice dove
# 2026/10/07 05:08:23 [emerg] 286#286: unexpected "}" in /etc/nginx/conf.d/azienda.conf:4
# nginx: configuration file /etc/nginx/nginx.conf test failed
```
Alla riga 4 c'è la `}` perché la riga **prima** (`root /var/www/azienda`) non finisce con `;`: l'errore si vede dove nginx si accorge, non dove è stato fatto. Si corregge e si controlla **prima** di riavviare:
```bash
sed -i 's#^    root /var/www/azienda$#    root /var/www/azienda;#' /etc/nginx/conf.d/azienda.conf
nginx -t && systemctl restart nginx
curl -s localhost:8090
# benvenuti in azienda
```
L'`ExecStartPre` del servizio esegue `nginx -t` a ogni avvio: con un file rotto nginx **non parte**, e con lui cade anche la `8091` e la `80`. Con `nginx -s reload` e lo stesso file rotto, invece, il reload viene **rifiutato** (`[emerg] unexpected "}"`) e nginx continua a servire la configurazione di prima (provato: la `8091` risponde ancora): per questo conviene `nginx -t && systemctl reload nginx`.
</details>

## 2. Nginx non parte: qualcuno ha spostato il sito
**Ticket**: *Il sito aziendale (`http://localhost:8090/`) non risponde. Qualcuno ha spostato il sito e riavviato nginx.*

<details><summary>da dove cominciare</summary>

Ancora `curl` rifiutato. Stavolta `nginx -t` dà **ok**: la sintassi è giusta. Cerca nel registro del servizio perché non parte, e guarda chi ascolta su cosa.
</details>
<details><summary>soluzione</summary>

```bash
systemctl status nginx --no-pager | head -8      # ExecStartPre (il test) ok, ExecStart fallito: il guaio è dopo la sintassi
#     Process: 373 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
#     Process: 375 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=1/FAILURE)
nginx -t                                         # la sintassi è giusta: -t non prova ad aprire le porte
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
journalctl -u nginx --no-pager | grep -m1 "bind()"
# Oct 07 05:08:59 host nginx[278]: nginx: [emerg] bind() to 0.0.0.0:8080 failed (98: Address already in use)
ss -ltnp | grep -E ':(80|8080|8090) '            # chi tiene la 8080?
# LISTEN 0      511          0.0.0.0:8080       0.0.0.0:*    users:(("apache2",pid=114,fd=3))
grep -n listen /etc/nginx/conf.d/*.conf          # e perché nginx la voleva?
# /etc/nginx/conf.d/azienda.conf:2:    listen 8080;
# /etc/nginx/conf.d/proxy.conf:2:    listen 8091;
```
Il sito è stato messo per sbaglio sulla `8080`, dove ascolta apache2. Si riporta il sito sulla `8090`: **non** si spegne apache, che ha il suo lavoro (e `controlla` lo verifica).
```bash
sed -i 's/listen 8080;/listen 8090;/' /etc/nginx/conf.d/azienda.conf
systemctl restart nginx
curl -s localhost:8090
# benvenuti in azienda
```
`nginx -t` controlla la sintassi, non lo **stato del sistema**: una porta occupata si scopre solo all'avvio, nel registro (`journalctl -u nginx`, `error.log`).
</details>

## 3. Il server web non si raggiunge: `curl` resta appeso
**Ticket**: *Da questo computer `curl http://web/` resta appeso: il server web, che prima rispondeva, sembra sparito.*

<details><summary>da dove cominciare</summary>

Il nome si risolve? Se sì, da che strada escono i pacchetti verso quell'indirizzo? `ip route get` risponde proprio a questa domanda.
</details>
<details><summary>soluzione</summary>

```bash
curl -m 3 -s http://web/; echo "curl: $?"       # 28: tempo scaduto (non "rifiutato"): i pacchetti si perdono per strada
# curl: 28
ping -c1 -W1 web                                 # il nome si risolve (10.10.2.10) ma nessuno risponde
# PING web (10.10.2.10) 56(84) bytes of data.
# 1 packets transmitted, 0 received, 100% packet loss, time 0ms
ip route
# default via 10.10.1.1 dev eth0
# 10.10.1.0/24 dev eth0 proto kernel scope link src 10.10.1.10      <- manca la rotta per 10.10.2.0/24
ip route get 10.10.2.10                          # senza rotta specifica si va al gateway predefinito, che non conosce la dmz
# 10.10.2.10 via 10.10.1.1 dev eth0 src 10.10.1.10 uid 0
```
`web` sta in un'altra rete (la `dmz`): per arrivarci i pacchetti devono passare dal `router` (`10.10.1.254`). La rotta c'era e non c'è più: si rimette.
```bash
ip route add 10.10.2.0/24 via 10.10.1.254
curl -s http://web/
# risposta da web
```
Una rotta cambiata con `ip route` **non sopravvive a un riavvio**: in un sistema vero si mette nella configurazione (netplan, vedi [01](01-indirizzi-e-configurazione.md)).
</details>

## 4. Il server web non si raggiunge: "Destination Host Unreachable"
**Ticket**: *Da questo computer `curl http://web/` non arriva: il server web, che prima rispondeva, non è più raggiungibile.*

<details><summary>da dove cominciare</summary>

Sembra il 3, ma `ping` dice qualcosa di diverso. Leggi bene chi risponde e cosa dice; poi `ip route get` e `ip neigh`.
</details>
<details><summary>soluzione</summary>

```bash
curl -m 3 -s http://web/; echo "curl: $?"
# curl: 28
ping -c1 -W1 web                                 # stavolta c'è una risposta: ma è il nostro stesso host che dice "irraggiungibile"
# From host (10.10.1.10) icmp_seq=1 Destination Host Unreachable
ip route get 10.10.2.10                          # la rotta c'è, ma il prossimo salto è 10.10.1.99
# 10.10.2.10 via 10.10.1.99 dev eth0 src 10.10.1.10 uid 0
ip neigh | grep 10.10.1.99                       # e quel "router" non risponde nemmeno alla richiesta ARP
# 10.10.1.99 dev eth0  FAILED
```
La rotta per la `dmz` passa da `10.10.1.99`, un indirizzo che non esiste: l'ARP fallisce (`FAILED`) e il kernel non sa a chi consegnare. Il router vero è `10.10.1.254`. `ip route add` direbbe `File exists`: si **sostituisce**.
```bash
ip route replace 10.10.2.0/24 via 10.10.1.254
curl -s http://web/
# risposta da web
```
Differenza con il 3: lì la rotta mancava e i pacchetti finivano al gateway sbagliato **senza avviso**; qui la rotta c'è, e a dirlo è `Destination Host Unreachable` dall'host **locale**. Se l'errore viene da un altro indirizzo (come nello scenario 5, dal router), il pacchetto è arrivato fin lì.
</details>

## 5. "Il server è acceso, la rete funziona" (ma `curl` no)
**Ticket**: *`curl http://web/` non risponde più. Ma il collega giura che il server web è acceso e che la rete funziona.*

<details><summary>da dove cominciare</summary>

Prova a raggiungere il server **per indirizzo** invece che per nome (`10.10.2.10`). Se così va, il problema è prima della rete.
</details>
<details><summary>soluzione</summary>

```bash
curl -m 3 -s http://web/; echo "curl: $?"
# curl: 28
getent hosts web                                 # a che indirizzo punta il nome?
# 10.10.2.99      web
ping -c1 -W1 web                                 # a chi risponde "irraggiungibile"? al router: il pacchetto è arrivato fin lì
# From router (10.10.1.254) icmp_seq=1 Destination Host Unreachable
curl -s http://10.10.2.10/                       # per indirizzo il server risponde: rete e server sono a posto
# risposta da web
grep web /etc/hosts                              # il nome è scritto qui, con l'indirizzo sbagliato
# 10.10.2.99 web
```
Il collega aveva ragione: il guasto è in `/etc/hosts`, che dice `10.10.2.99` invece di `10.10.2.10`. Il router ha provato a consegnare e nessuno ha risposto. Si corregge **sul posto** (nel container `/etc/hosts` è montato da Docker e `sed -i` non può sostituirlo):
```bash
t=$(mktemp); sed 's/^10\.10\.2\.99\([[:space:]]\+web\)$/10.10.2.10\1/' /etc/hosts > $t; cat $t > /etc/hosts
curl -s http://web/
# risposta da web
```
Il nome e la rete sono due problemi diversi: `dig web` qui non avrebbe detto nulla (non legge `/etc/hosts`), `getent hosts` sì. Se **aggiungi** la riga giusta in fondo senza togliere quella sbagliata, non cambia nulla: per ogni nome vale la **prima** riga che combacia (e `controlla` lo verifica).
</details>

## 6. Il reverse proxy risponde `502`
**Ticket**: *Il sito sulla 8091 (`http://localhost:8091/`) è un inoltro verso il server web, e ora risponde con un errore invece della pagina.*

<details><summary>da dove cominciare</summary>

`curl -si` mostra il codice. Un `502` è nginx che **ha ricevuto** la richiesta ma non ha ottenuto risposta da quello a cui l'ha girata: il log degli errori dice a chi, e su quale porta.
</details>
<details><summary>soluzione</summary>

```bash
curl -si localhost:8091 | head -2
# HTTP/1.1 502 Bad Gateway
# Server: nginx/1.24.0 (Ubuntu)
tail -1 /var/log/nginx/error.log                 # il log nomina l'upstream con l'indirizzo e la porta
# ... connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: , request: "GET / HTTP/1.1", upstream: "http://10.10.2.10:81/", host: "localhost:8091"
nc -zv -w2 web 81                                # la porta 81 di web è chiusa
# nc: connect to web (10.10.2.10) port 81 (tcp) failed: Connection refused
nc -zv -w2 web 80                                # la 80 è aperta
# Connection to web (10.10.2.10) 80 port [tcp/http] succeeded!
grep proxy_pass /etc/nginx/conf.d/proxy.conf
#         proxy_pass http://web:81/;
```
Il `proxy_pass` punta alla porta `81`, che su `web` non ascolta nessuno. La rete e `web` sono a posto (il `502` è proprio la prova che nginx parte e risponde). Si corregge e si **ricarica**:
```bash
sed -i 's#proxy_pass http://web:81/;#proxy_pass http://web/;#' /etc/nginx/conf.d/proxy.conf
nginx -t && nginx -s reload
curl -s localhost:8091
# risposta da web
```
`502` = nginx non ha ottenuto risposta dall'upstream; `504` = non l'ha ottenuta **in tempo** (sarebbe stato il caso di un firewall come nel 7); `403` = l'ha rifiutata lui (scenario 8). Un'altra "soluzione" che risponde ma con la pagina sbagliata (per esempio un `proxy_pass` verso il proprio sito sulla 8090) non passa il controllo.
</details>

## 7. "Ma il ping funziona!"
**Ticket**: *`curl http://web/` resta appeso. Il collega dice: "ma se faccio ping va tutto!"*

<details><summary>da dove cominciare</summary>

Il `ping` prova che la macchina c'è e la rotta è giusta, non che la **porta** sia raggiungibile. Prova la porta 80 e, per confronto, un'altra porta di `web` (la 22 è aperta). Poi guarda le regole del firewall di questo computer.
</details>
<details><summary>soluzione</summary>

```bash
curl -m 3 -s http://web/; echo "curl: $?"       # appeso: tempo scaduto
# curl: 28
ping -c1 -W1 web                                 # la rete e la macchina vanno
# 64 bytes from web (10.10.2.10): icmp_seq=1 ttl=63 time=0.077 ms
nc -zv -w2 web 22                                # un'altra porta di web risponde...
# Connection to web (10.10.2.10) 22 port [tcp/ssh] succeeded!
nc -zv -w2 web 80                                # ...la 80 no, e non dice "rifiutata" ma "scaduta": qualcuno butta i pacchetti
# nc: connect to web (10.10.2.10) port 80 (tcp) timed out: Operation now in progress
iptables -S OUTPUT                               # le regole del firewall in uscita
# -P OUTPUT ACCEPT
# -A OUTPUT -d 10.10.2.10/32 -p tcp -m tcp --dport 80 -j DROP
```
Una regola `DROP` butta i pacchetti verso la porta 80 di `web`: niente risposta (`timed out`), a differenza di `REJECT` (`Connection refused`, subito). Si toglie la regola, con la stessa riga di `-A` ma `-D`:
```bash
iptables -D OUTPUT -d 10.10.2.10 -p tcp --dport 80 -j DROP
curl -s http://web/
# risposta da web
```
**Aggiungere** una regola `ACCEPT` in fondo non serve: le regole si leggono **in ordine** e vince la prima che combacia, il `DROP`. Con più regole conviene `iptables -L OUTPUT -n -v --line-numbers` e `iptables -D OUTPUT NUMERO`.
</details>

## 8. La home page dà `403 Forbidden`
**Ticket**: *Il sito aziendale (`http://localhost:8090/`) risponde, ma con un errore invece della home page.*

<details><summary>da dove cominciare</summary>

Il codice di stato dice già di che tipo è: nginx risponde (il servizio c'è) ma **rifiuta**. Il log degli errori dice cosa non ha potuto fare e perché; poi guarda i permessi lungo tutto il percorso del file (`namei -l`), e **con quale utente** gira nginx.
</details>
<details><summary>soluzione</summary>

```bash
curl -si localhost:8090 | head -1
# HTTP/1.1 403 Forbidden
tail -1 /var/log/nginx/error.log
# ... "/var/www/azienda/index.html" is forbidden (13: Permission denied), client: 127.0.0.1, ...
namei -l /var/www/azienda/index.html             # i permessi di OGNI componente del percorso
# drwxr-xr-x root   root    /
# drwxr-xr-x root   root    var
# drwxr-xr-x root   root    www
# drwx------ nobody nogroup azienda
# -rw-r--r-- root   root    index.html
ps -o user= -C nginx | sort | uniq -c            # chi esegue nginx? i processi che servono le richieste non sono root
#       1 root
#      16 www-data
```
Il file è leggibile da tutti (`-rw-r--r--`), ma la **cartella** `azienda` è `drwx------` e appartiene a `nobody`: per attraversarla serve il permesso di esecuzione (`x`), e chi serve le richieste è `www-data`, che non è né il proprietario né nel gruppo. `Permission denied` (13) nel log lo dice. Si ripristina proprietario e permessi della cartella:
```bash
chown root:root /var/www/azienda; chmod 755 /var/www/azienda
curl -s localhost:8090
# benvenuti in azienda
```
Un `chmod` sul **file** non serve (era già a posto): per leggere un file bisogna poter **attraversare** ogni cartella del percorso. È il permesso `x` sulle directory di [02-file/08-permessi](../02-file-e-permessi/08-permessi.md). (`chmod -R 777` risolverebbe, ma regala la cartella a tutti.)
</details>

---

## Riepilogo: come si riconosce
| Sintomo | Livello | Prima mossa |
|---|---|---|
| `curl` rifiutato (codice 7) | servizio | `systemctl status`, `nginx -t`, `journalctl -u` (1, 2) |
| `curl` appeso (codice 28), `ping` muto | rotta | `ip route get` (3), `ip neigh` (4) |
| il nome non va, l'indirizzo sì | nome | `getent hosts`, `/etc/hosts` (5) |
| `502` | servizio a monte | `error.log`, `nc -zv` sulla porta dell'upstream (6) |
| `ping` ok, `curl` appeso | firewall | `nc -zv` su due porte, `iptables -S` (7) |
| `403` | permessi | `error.log`, `namei -l`, utente di nginx (8) |

## Non provato
- Gli scenari agiscono solo su `host`: i guasti dei server (`web`, `host2`) o del `router` non ci sono.
- Il guasto del 7 (`iptables`) è con `iptables-nft` del container: con `nftables` puro o `ufw` i comandi per vederlo e toglierlo sono diversi (`nft list ruleset`, `ufw status`).
- Il tempo per risolvere uno scenario non è stato misurato su una persona.

Torna all'[indice dell'area](README.md)
