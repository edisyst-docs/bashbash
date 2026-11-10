# dig: interrogare il DNS

> **Laboratorio**: `./lab.sh 10`. Il DNS di prova sta su `web` (BIND, come in [06-dns-server.md](06-dns-server.md)) e si interroga da `host`. Dettagli in [lab/](lab/).

`dig` (*domain information groper*) fa **una domanda al DNS e mostra la risposta com'è**, senza interpretarla: sezioni, flag, TTL, quale server ha risposto. Per questo è lo strumento di chi diagnostica; `nslookup` ([13-nslookup.md](13-nslookup.md)) è la stessa cosa in forma più sintetica, `host` ancora di più.
Qui sotto c'è tutto quello che serve per usarlo bene. Le query minime (`dig +short`, `dig -x`) sono già in [../06-sistema/06-rete-e-host.md](../06-sistema/06-rete-e-host.md).

Gli esempi sono stati eseguiti nel laboratorio dell'area 10 (Ubuntu 24.04, `dig` 9.18.39). Le query verso internet (`example.com`, `1.1.1.1`) danno indirizzi e TTL che **cambiano**: contano la forma e i campi, non i numeri.

```bash
sudo apt install dnsutils            # dig, nslookup, host (su Fedora/RHEL: bind-utils)
```

## Quale strumento per quale domanda

| Domanda | Strumento | Perché |
|---|---|---|
| "cosa risponde il DNS, e perché?" | `dig` | mostra flag (`aa`, `ra`), TTL, sezioni, `status`, server interrogato |
| "che indirizzo ha questo nome, **per i miei programmi**?" | `getent hosts nome` | passa da `/etc/hosts` e `nsswitch.conf` come `ping` e `curl`; `dig` e `nslookup` non li leggono |
| una risposta rapida a mano | `host nome` | una riga per record |
| lo stesso comando su Windows | `nslookup` | `dig` non c'è di serie |

## Il DNS di prova
Le risposte di questa pagina vengono da una zona `lab.test` servita da BIND su `web` (`10.10.2.10`). Si prepara come in [06-dns-server.md](06-dns-server.md) (BIND su `web`, `named.conf.options` con `forwarders`), con **due differenze**: `allow-transfer { 10.10.1.0/24; };` nella zona (così `AXFR` si prova da `host`) e questa zona, con più tipi di record:
```
$TTL 1h
@	IN	SOA	ns1.lab.test. admin.lab.test. ( 2026110601 1h 15m 1w 5m )
	IN	NS	ns1.lab.test.
	IN	MX	10 web.lab.test.
	IN	MX	20 backup.lab.test.
	IN	TXT	"v=spf1 mx -all"
ns1	IN	A	10.10.2.10
web	IN	A	10.10.2.10
web	IN	AAAA	fd00:10:2::10
backup	IN	A	10.10.2.20
host	IN	A	10.10.1.10
www	IN	CNAME	web
api	300 IN	A	10.10.2.31         ; due indirizzi per lo stesso nome (round robin)
api	300 IN	A	10.10.2.32
_http._tcp	IN	SRV	10 5 80 web.lab.test.
```
La zona inversa `2.10.10.in-addr.arpa` ha `10` → `web.lab.test.` e `20` → `backup.lab.test.`.
Negli esempi `S=@10.10.2.10` è il server di prova; i comandi sono scritti per esteso.

## Sintassi
```
dig [@server] [nome] [tipo] [classe] [+opzioni] [-opzioni]
```
```bash
dig @10.10.2.10 web.lab.test A          # server, nome, tipo
dig web.lab.test                        # senza @: usa i nameserver di /etc/resolv.conf. Senza tipo: A
dig @10.10.2.10 -q lab.test -t MX       # -q e -t dicono nome e tipo in modo esplicito (utile negli script)
dig -h                                  # riepilogo di tutte le opzioni; man dig per i dettagli
```
Le parole **senza trattino né `+`** sono riconosciute da `dig` per quello che sono: `MX`, `AXFR`, `IN` e `CH` sono tipo e classe, qualunque altra è il nome. Il **tipo** può stare in qualunque posizione, anche prima del nome.
Le opzioni `+nome` si **disattivano** con `+nonome` (`+short` / `+noshort`) e alcune hanno un valore (`+time=3`).

> **ATTENZIONE**: l'**ordine** delle opzioni `+` conta, perché sono eseguite da sinistra a destra. `+noall` spegne tutto, quindi va **prima** di quello che si vuole vedere:
> ```bash
> dig @10.10.2.10 web.lab.test +stats +noall       # non stampa NIENTE: +noall ha spento anche +stats
> dig @10.10.2.10 web.lab.test +noall +stats       # Query time: 0 msec / SERVER: 10.10.2.10#53(10.10.2.10) (UDP) / WHEN / MSG SIZE
> ```

## Leggere la risposta completa
```bash
dig @10.10.2.10 web.lab.test
```
```
; <<>> DiG 9.18.39-0ubuntu0.24.04.7-Ubuntu <<>> @10.10.2.10 web.lab.test
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 26311
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 76307e6238b55077... (good)
;; QUESTION SECTION:
;web.lab.test.			IN	A

;; ANSWER SECTION:
web.lab.test.		3600	IN	A	10.10.2.10

;; Query time: 0 msec
;; SERVER: 10.10.2.10#53(10.10.2.10) (UDP)
;; WHEN: Fri Nov 06 16:50:01 UTC 2026
;; MSG SIZE  rcvd: 85
```

| Parte | Cosa dice |
|---|---|
| `status: NOERROR` | l'esito (tabella sotto) |
| `flags: qr aa rd ra` | `qr` è una risposta; **`aa`** *authoritative answer*: viene dal server che ha la zona, non da una cache; `rd` il client ha chiesto la ricorsione; `ra` il server la offre. Altri: `tc` troncata (si riprova in TCP), `ad` DNSSEC verificato |
| `QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1` | quanti record in ogni sezione (l'`ADDITIONAL` qui è il record `OPT` di EDNS) |
| `QUESTION SECTION` | la domanda **come l'ha mandata dig**: se il nome è diverso da quello che credevi (un punto in più, una `search` applicata) lo vedi qui |
| `ANSWER SECTION` | `nome  TTL  classe  tipo  dato`. Il TTL è in secondi |
| `AUTHORITY SECTION` | in una risposta negativa il `SOA` della zona; in un rinvio i `NS` a cui rivolgersi |
| `ADDITIONAL SECTION` | record utili che il server aggiunge di sua iniziativa (gli indirizzi dei `NS` o dei server `MX`) |
| `Query time`, `SERVER` | quanto ha impiegato e **chi ha risposto davvero** (e se in UDP o TCP) |

Gli esiti (`status`) che si incontrano:

| `status` | Significa | Tipico |
|---|---|---|
| `NOERROR` | domanda capita, risposta data (anche vuota: vedi sotto) | tutto bene |
| `NXDOMAIN` | il **nome non esiste** | refuso, record mancante, zona sbagliata |
| `SERVFAIL` | il server non è riuscito a rispondere | zona non caricata, `forwarder` non raggiungibile, DNSSEC fallito |
| `REFUSED` | il server **non vuole** rispondere a questo client | `allow-query` / `allow-recursion` |

> **ATTENZIONE**: `NOERROR` con `ANSWER: 0` (il caso *NODATA*) vuol dire che **il nome esiste ma non ha quel tipo di record**. Non è `NXDOMAIN`:
> ```bash
> dig @10.10.2.10 web.lab.test MX | grep -E 'status|flags'
> # ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 60279
> # ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1      <- ANSWER: 0, e il SOA in AUTHORITY
> ```
> Con `+short` le due cose (e perfino un `SERVFAIL`) sono **tutte uguali: nessun output**. Per distinguerle servono i commenti (`+noall +comments`).

## Scegliere cosa stampare
Di default `dig` stampa tutto. Le opzioni di visualizzazione si combinano; la ricetta di tutti i giorni è `+noall +answer`.
```bash
dig @10.10.2.10 web.lab.test +short                 # solo il dato: 10.10.2.10
dig @10.10.2.10 web.lab.test +short +identify       # 10.10.2.10 from server 10.10.2.10 in 0 ms.   <- aggiunge chi ha risposto e in quanto tempo
dig @10.10.2.10 web.lab.test +noall +answer         # solo ANSWER, con TTL e tipo: web.lab.test.  3600  IN  A  10.10.2.10
dig @10.10.2.10 web.lab.test +noall +question +answer +stats   # la domanda, la risposta e la riga dei tempi
dig @10.10.2.10 web.lab.test +noall +answer +cmd    # +noall spegne anche la riga "; <<>> DiG ..."; +cmd la riaccende
dig @10.10.2.10 web.lab.test +noall +answer +nottlid      # senza TTL:  web.lab.test.  IN  A  10.10.2.10
dig google.com +noall +answer +ttlunits             # TTL leggibili: google.com.  1m15s  IN  A  192.178.194.101
dig @10.10.2.10 nonesiste.lab.test +noall +authority      # il SOA che accompagna un NXDOMAIN, con il TTL negativo (300)
dig @10.10.2.10 lab.test NS +noall +answer +additional    # i NS e, in ADDITIONAL, il loro indirizzo (ns1.lab.test. A 10.10.2.10)
dig @10.10.2.10 web.lab.test +qr +noall +question +answer # +qr stampa anche la domanda inviata (la riga ;web.lab.test. IN A compare due volte)
```
Il SOA è più leggibile in forma estesa (`+multiline`), con i commenti sul significato dei numeri:
```bash
dig @10.10.2.10 lab.test SOA +multiline +noall +answer
# lab.test.		3600 IN	SOA ns1.lab.test. admin.lab.test. (
# 				2026110601 ; serial
# 				3600       ; refresh (1 hour)
# 				900        ; retry (15 minutes)
# 				604800     ; expire (1 week)
# 				300        ; minimum (5 minutes)
# 				)
```
`+yaml` dà tutta la risposta in YAML (`dig +yaml @10.10.2.10 web.lab.test`): utile per far leggere il risultato a un altro programma.

## I tipi di record
```bash
dig @10.10.2.10 web.lab.test A +short               # 10.10.2.10                  indirizzo IPv4
dig @10.10.2.10 web.lab.test AAAA +short            # fd00:10:2::10               indirizzo IPv6
dig @10.10.2.10 lab.test MX +short                  # 20 backup.lab.test. / 10 web.lab.test.   (priorità e server: il numero BASSO vince)
dig @10.10.2.10 lab.test NS +short                  # ns1.lab.test.               i server autoritativi della zona
dig @10.10.2.10 lab.test TXT +short                 # "v=spf1 mx -all"            testo libero: SPF, verifiche di dominio, DKIM
dig @10.10.2.10 lab.test SOA +short                 # ns1.lab.test. admin.lab.test. 2026110601 3600 900 604800 300
dig @10.10.2.10 _http._tcp.lab.test SRV +short      # 10 5 80 web.lab.test.       priorità, peso, porta, host
dig @10.10.2.10 www.lab.test +noall +answer         # prima il CNAME (www → web.lab.test.), poi l'A del nome canonico
dig @10.10.2.10 lab.test TYPE15 +noall +answer      # TYPEnn: un tipo per numero (15 = MX), per quelli che dig non conosce per nome
```
Gli ordini delle risposte con più record **non sono stabili**: `dig +short MX lab.test` può stampare prima il 20 o prima il 10 (e `api.lab.test` alterna `.31` e `.32`, il *round robin* che distribuisce i client). Chi deve prendere il primo ordina: `dig +short MX lab.test | sort -n | head -1` → `10 web.lab.test.`

`CNAME` è un alias: **un nome con un CNAME non può avere altri record**, e la risposta contiene tutta la catena fino all'indirizzo. Chiedere il tipo `CNAME` di un nome che non lo è dà una risposta vuota:
```bash
dig @10.10.2.10 +noall +answer CNAME www.lab.test   # www.lab.test.  3600  IN  CNAME  web.lab.test.
dig @10.10.2.10 +noall +answer CNAME web.lab.test   # (vuoto: web è un A, non un alias)
```

`ANY` doveva dare "tutto": molti server oggi rispondono in modo ridotto o rifiutano (RFC 8482). BIND qui ha dato SOA, NS, MX e TXT, **ma non gli `A` e `AAAA` degli altri nomi**: per un elenco completo serve `AXFR`.
```bash
dig @10.10.2.10 ANY lab.test +noall +answer
# lab.test.  3600  IN  SOA  ns1.lab.test. admin.lab.test. 2026110601 3600 900 604800 300
# lab.test.  3600  IN  NS   ns1.lab.test.
# lab.test.  3600  IN  MX   10 web.lab.test.
# lab.test.  3600  IN  MX   20 backup.lab.test.
# lab.test.  3600  IN  TXT  "v=spf1 mx -all"
```
Più tipi nella stessa riga non si possono mescolare: `dig +short lab.test MX TXT NS` avvisa (`;; Warning, extra type option`) e usa solo l'ultimo. Per più domande si usa un file o più nomi (vedi sotto).

## Reverse DNS: `-x`
`-x` fa il lavoro di scrivere l'indirizzo a rovescio sotto `in-addr.arpa` (o `ip6.arpa`) e chiede il `PTR`:
```bash
dig @10.10.2.10 -x 10.10.2.10 +noall +question +answer
# ;10.2.10.10.in-addr.arpa.	IN	PTR
# 10.2.10.10.in-addr.arpa. 3600	IN	PTR	web.lab.test.
dig @10.10.2.10 -x 10.10.2.20 +short                # backup.lab.test.
dig @8.8.8.8 -x 8.8.8.8 +short                      # dns.google.
dig @10.10.2.10 PTR 20.2.10.10.in-addr.arpa +short  # UGUALE a -x 10.10.2.20, scritto a mano
```
Il reverse è una zona **a parte** dal nome diretto, gestita da chi possiede l'indirizzo: non è detto che esista né che coincida. I server di posta lo controllano spesso (un IP senza PTR è un sospetto spammer).

## Quale server interrogare
```bash
dig example.com                          # i nameserver di /etc/resolv.conf: quello che usa la macchina
dig @1.1.1.1 example.com                 # uno preciso: se i due risultati differiscono, il problema è il DNS locale (cache, filtri, split-horizon)
dig @ns1.lab.test web.lab.test           # anche per nome (che dig risolve prima con il resolver locale)
dig -p 5353 @10.10.2.10 web.lab.test     # porta diversa dalla 53 (un DNS di prova, un resolver in un container)
dig -b 10.10.1.10 @10.10.2.10 web.lab.test   # indirizzo di origine (-b): da quale IP esce la domanda, se la macchina ne ha più d'uno
dig -4 @10.10.2.10 web.lab.test          # solo IPv4 (-6 solo IPv6)
```
Per vedere cosa fa **un confronto fra server** basta un ciclo:
```bash
for s in 10.10.2.10 1.1.1.1 8.8.8.8; do printf '%-12s ' $s; dig @$s +short example.com | sort | tr '\n' ' '; echo; done
# 10.10.2.10   104.20.23.154 172.66.147.243
# 1.1.1.1      104.20.23.154 172.66.147.243
# 8.8.8.8      104.20.23.154 172.66.147.243
for s in 10.10.2.10 1.1.1.1 8.8.8.8; do printf '%-12s ' $s; dig @$s example.com +noall +stats | grep -o 'Query time: .*'; done
# 10.10.2.10   Query time: 0 msec         <- dalla cache locale
# 1.1.1.1      Query time: 24 msec
# 8.8.8.8      Query time: 36 msec
```
Il `sort` serve perché l'ordine dei record cambia da una risposta all'altra.

### Quando non risponde
```bash
dig @10.10.2.99 web.lab.test +short +time=1 +tries=1
# ;; communications error to 10.10.2.99#53: timed out
# ; <<>> DiG ... <<>> @10.10.2.99 web.lab.test +short +time=1 +tries=1
# ;; no servers could be reached                                           <- exit code 9
dig @10.10.2.10 -p 5353 web.lab.test +short +time=1 +tries=1
# ;; communications error to 10.10.2.10#5353: connection refused           <- l'host c'è, ma niente ascolta su quella porta
```
`timed out` (nessuna risposta: server giù, firewall che scarta, indirizzo sbagliato) e `connection refused` (la macchina risponde, il servizio no) sono guasti diversi. Di default `dig` aspetta 5 secondi (`+time`) e prova 3 volte (`+tries`): per un controllo veloce `+time=1 +tries=1`.

Gli **exit code**: `0` se ha avuto una risposta (**anche `NXDOMAIN`**: l'esito del DNS non è un errore di dig), `9` nessuna risposta, `1` opzioni sbagliate, `10` errore interno. In uno script `dig ... +short` dà sempre 0 se il server risponde: per testare l'esistenza si guarda l'output.
```bash
dig @10.10.2.10 +short web.lab.test | grep -q . && echo risolve || echo vuoto    # risolve
dig @10.10.2.10 +short nonesiste.lab.test | grep -q . || echo "nonesiste: vuoto"
for n in web.lab.test nonesiste.lab.test; do printf '%-20s ' $n; dig @10.10.2.10 $n +noall +comments | grep -o 'status: [A-Z]*'; done
# web.lab.test         status: NOERROR
# nonesiste.lab.test   status: NXDOMAIN
```

## TCP e trasferimento di zona
Il DNS usa UDP sulla 53; passa a **TCP** quando la risposta non entra (flag `tc`) e per il trasferimento di zona.
```bash
dig @10.10.2.10 web.lab.test +tcp +noall +stats          # ... SERVER: 10.10.2.10#53(10.10.2.10) (TCP)    (+vc è lo stesso)
dig @10.10.2.10 lab.test AXFR                            # tutta la zona: serve un client in allow-transfer
dig @10.10.2.10 lab.test AXFR +noall +answer +stats | tail -4
# ;; Query time: 0 msec
# ;; SERVER: 10.10.2.10#53(10.10.2.10) (TCP)
# ;; XFR size: 15 records (messages 1, bytes 433)
```
Con `AXFR` si vedono **tutti** i nomi della zona, compresi quelli che nessuno ha mai cercato:
```bash
dig @10.10.2.10 lab.test AXFR +noall +answer | awk '$4=="A"{print $1, $5}'
# api.lab.test. 10.10.2.31 / api.lab.test. 10.10.2.32 / backup.lab.test. 10.10.2.20 / host.lab.test. 10.10.1.10 / ns1.lab.test. 10.10.2.10 / web.lab.test. 10.10.2.10
```
Per questo i server veri **non** lo concedono a tutti (`allow-transfer`): da un client non autorizzato `dig` stampa `; Transfer failed.`. Il tentativo verso un server dove non gira un DNS dà `connection refused`.
Il **serial** del SOA è il numero con cui i secondari decidono se riscaricare: `dig +short SOA lab.test @primario | awk '{print $3}'` e lo stesso verso il secondario devono dare lo stesso numero (vedi [06-dns-server.md](06-dns-server.md)).

## Ricorsione e cache
`rd` (*recursion desired*) è il default: si chiede al server di **cercare per noi** la risposta. `+norecurse` chiede solo quello che il server ha già, e permette di vedere cosa c'è **in cache**:
```bash
dig @10.10.2.10 example.com +norecurse +noall +answer +comments       # prima volta: nessuna risposta; AUTHORITY: 13 (i root server), flags: qr ra
dig @10.10.2.10 example.com +noall +answer                            # example.com.  44  IN  A  104.20.23.154 (la cerca e la tiene in cache)
dig @10.10.2.10 example.com +norecurse +noall +answer                 # ora risponde dalla cache: example.com.  42  IN  A  ...
```
Il **TTL che scende** è il segno che la risposta viene da una cache: ogni secondo che passa ne toglie uno. Una risposta autoritativa mostra sempre il TTL pieno della zona (`3600`).
```bash
for i in 1 2 3; do dig @10.10.2.10 google.com +noall +answer | head -1; sleep 1; done
# google.com.  241  IN  A  192.178.194.100
# google.com.  240  IN  A  192.178.194.113
# google.com.  239  IN  A  192.178.194.100       <- il TTL scende; l'indirizzo in testa cambia (round robin)
```
> **NOTA**: guardare cosa c'è nella cache di un resolver altrui (*cache snooping*) rivela cosa chiedono i suoi utenti: su un server che non è il proprio non si fa.

## `+trace`: chi risponde a ogni livello
`+trace` ricostruisce la risoluzione **da solo**, partendo dai root server e scendendo di livello (root → `.com` → i nameserver del dominio), senza usare le cache dei resolver:
```bash
dig example.com +trace +nodnssec +noall +answer
# .   518383  IN  NS  g.root-servers.net.
# ...                                                      (i 13 root server, ricevuti dal resolver locale)
# ;; Received 851 bytes from 10.10.2.10#53(10.10.2.10) in 0 ms
#
# ;; Received 836 bytes from 198.41.0.4#53(a.root-servers.net) in 28 ms
#
# ;; Received 359 bytes from 192.31.80.30#53(d.gtld-servers.net) in 32 ms
#
# example.com.  300  IN  A  172.66.147.243
# example.com.  300  IN  A  104.20.23.154
# ;; Received 72 bytes from 162.159.44.228#53(elliott.ns.cloudflare.com) in 24 ms
```
Si legge dal basso: la risposta finale l'ha data `elliott.ns.cloudflare.com` (l'autoritativo), a cui ha mandato il server `.com`, a cui ha mandato il root. È il modo per scoprire **una delega sbagliata**: i `NS` che il registrar dà alla zona genitore non sono quelli che servono davvero la zona.
`+trace +short` e `+trace +nodnssec` sono più leggibili: senza `+nodnssec` compaiono anche le firme (`RRSIG`), righe lunghissime.

> **ATTENZIONE**: `+trace` parte da **internet**. Su un nome privato come `lab.test` la traccia si ferma al primo passo con un `NXDOMAIN` dai root: non prova la zona di BIND. Per i nomi interni si interroga direttamente il server (`dig @10.10.2.10 ...`).

## `+search` e il nome corto
`dig` **non** usa la riga `search` di `/etc/resolv.conf` (né `ndots`), a differenza di `ping` e `getent`:
```bash
printf 'nameserver 10.10.2.10\nsearch lab.test\n' > /etc/resolv.conf
dig web +short                           # nessun indirizzo: ha chiesto il nome "web." alla radice (vuoto, o SERVFAIL/timeout se il forwarder non risponde)
dig web +search +short                   # 10.10.2.10                          <- +search aggiunge lab.test
dig web +search +showsearch +noall +answer       # web.lab.test.  3600  IN  A  10.10.2.10
```
Per questo "il nome si risolve con `ping` e non con `dig`" è un falso allarme. Per `dig` sempre il nome completo (o `+search`).

## DNSSEC
DNSSEC firma i record: un resolver che valida lo segnala col flag **`ad`** (*authenticated data*). `+dnssec` chiede anche le firme (`RRSIG`):
```bash
dig iana.org @1.1.1.1 +dnssec +noall +comments        # flags: qr rd ra ad;     <- "ad": il resolver ha verificato la firma
dig iana.org @1.1.1.1 +dnssec +noall +answer
# iana.org.  3492  IN  A      192.0.43.8
# iana.org.  3492  IN  RRSIG  A 13 2 3600 20261124075832 20261103091656 18221 iana.org. BYbwF6tP...
```
Se la validazione **fallisce**, il resolver risponde `SERVFAIL`, non con un dato "sospetto". `dnssec-failed.org` è un dominio creato apposta con la firma sbagliata:
```bash
dig dnssec-failed.org @1.1.1.1 +noall +comments
# ;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 40045
# ; EDE: 9 (DNSKEY Missing): (no SEP matching the DS found for dnssec-failed.org.)      <- l'errore esteso spiega perché
dig dnssec-failed.org @1.1.1.1 +cd +noall +answer     # dnssec-failed.org.  300  IN  A  96.99.227.255
```
`+cd` (*checking disabled*) dice al resolver di **non verificare**: se con `+cd` la risposta arriva e senza dà `SERVFAIL`, il problema è DNSSEC e non il server. È l'unico modo di aggirarlo per fare una diagnosi, **non** di fidarsi dell'indirizzo.

## Più domande in una volta
```bash
dig @10.10.2.10 +noall +answer web.lab.test lab.test MX         # due query: web.lab.test (A) e lab.test (MX)
# web.lab.test.  3600  IN  A   10.10.2.10
# lab.test.      3600  IN  MX  10 web.lab.test.
# lab.test.      3600  IN  MX  20 backup.lab.test.
```
Le opzioni scritte **prima** del primo nome valgono per tutte le domande; quelle scritte **dopo** un nome valgono solo per quella domanda. Con `web.lab.test lab.test MX +noall +answer` la prima domanda uscirebbe con la risposta completa e solo la seconda ridotta. Per molte domande c'è il **file** (`-f`), una per riga, con la stessa sintassi (le opzioni dopo `-f file` valgono per tutte):
```bash
printf 'web.lab.test A\nlab.test MX\n-x 10.10.2.20\nnonesiste.lab.test\n' > /tmp/q.txt
dig @10.10.2.10 -f /tmp/q.txt +noall +answer
# web.lab.test.             3600  IN  A    10.10.2.10
# lab.test.                 3600  IN  MX   20 backup.lab.test.
# lab.test.                 3600  IN  MX   10 web.lab.test.
# 20.2.10.10.in-addr.arpa.  3600  IN  PTR  backup.lab.test.        <- nonesiste.lab.test: niente righe
```

### `~/.digrc`
Le opzioni scritte in `~/.digrc` (una riga, solo `+opzioni` e `-opzioni`) valgono per **ogni** `dig`. Chi lavora sempre con `+noall +answer` lo mette lì:
```bash
echo '+noall +answer' > ~/.digrc
dig @10.10.2.10 web.lab.test                 # web.lab.test.  3600  IN  A  10.10.2.10        <- senza dire niente
dig @10.10.2.10 -r web.lab.test +short       # -r: ignora ~/.digrc
```
> **NOTA**: se un `dig` dentro uno script sembra "mangiare" parte dell'output, guardare `~/.digrc`: negli script conviene `dig -r`.

## Domande speciali: classe `CH`
La classe `CH` (*Chaos*) serve a chiedere informazioni **sul server**: quale software e quale versione (e, su molti, il nome della macchina):
```bash
dig @10.10.2.10 -c CH -t TXT version.bind +short     # "9.18.39-0ubuntu0.24.04.9-Ubuntu"
dig @10.10.2.10 -c CH -t TXT hostname.bind +short    # "web"
```
Utile per capire **quale** server ha risposto dietro un indirizzo condiviso (anycast, bilanciatore). In produzione quasi tutti rispondono con un valore finto o niente: `version "none";` in BIND, per non regalare la versione a chi cerca vulnerabilità.

## Ricette
```bash
dig +short myip.opendns.com @resolver1.opendns.com   # il mio indirizzo pubblico, come lo vede il resolver di OpenDNS
dig @10.10.2.10 +short MX lab.test | sort -n | awk '{print $2}' | while read h; do printf '%s -> ' $h; dig @10.10.2.10 +short $h; done
# web.lab.test. -> 10.10.2.10
# backup.lab.test. -> 10.10.2.20          <- i server di posta in ordine di priorità, ognuno con il suo indirizzo
dig @10.10.2.10 +short SOA lab.test | awk '{print $3}'       # 2026110601: il serial. Primario e secondario devono dare lo stesso
```

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `+short` non stampa niente | nome inesistente (`NXDOMAIN`), nome senza quel tipo (`NODATA`), `SERVFAIL`: tutti uguali con `+short` | `+noall +comments` e leggere `status` e `ANSWER:` |
| `;; communications error ...: timed out` / `no servers could be reached` | server giù, firewall che scarta, indirizzo sbagliato (exit code 9) | `nc -zvu server 53`, un altro server, `+time=1 +tries=1` per fare in fretta |
| `connection refused` | la macchina c'è, nessun DNS sulla porta | `ss -ulnp \| grep :53` sul server, `-p` giusta |
| `status: REFUSED` | il server non serve questo client | `allow-query`/`allow-recursion` ([06-dns-server.md](06-dns-server.md)) |
| `status: SERVFAIL` | zona non caricata, forwarder giù, DNSSEC non valido | `journalctl -u named`; `+cd` per escludere DNSSEC; `+trace` per i server veri |
| con `ping nome` funziona e con `dig nome` no | `dig` non usa `search` e non legge `/etc/hosts` | nome completo o `+search`; per la vista dei programmi `getent hosts nome` |
| `+stats +noall` non stampa i tempi | `+noall` dopo spegne tutto | `+noall +stats` |
| risposta diversa fra `dig` e `dig @1.1.1.1` | cache o filtro del resolver locale, split-horizon | `resolvectl status`, `+norecurse`, il TTL che scende |
| `;; Warning, extra type option` | più tipi nella stessa riga | una query per tipo, o `-f` |
| `Transfer failed` | il client non è in `allow-transfer`, o TCP 53 chiuso | `AXFR` solo dal secondario |

Torna all'[indice dell'area](README.md)
