# nslookup: interrogare il DNS, anche su Windows

> **Laboratorio**: `./lab.sh 10`, con il DNS di prova su `web` descritto in [12-dig.md](12-dig.md#il-dns-di-prova). Dettagli in [lab/](lab/).

`nslookup` fa la stessa cosa di `dig` ([12-dig.md](12-dig.md)), con un output **più breve e già interpretato**. Perde dettagli (flag, sezioni, TTL, `status`), ma ha un vantaggio decisivo: **c'è su Windows**, con la stessa sintassi, e ha una modalità interattiva.
Su Linux fa parte di `dnsutils` (`bind-utils` su RHEL). Gli esempi sono stati eseguiti nel laboratorio dell'area 10 (nslookup 9.18.39) e, dove indicato, su Windows 11.

Nel laboratorio il client usa il DNS di prova e la riga `search`:
```bash
printf 'nameserver 10.10.2.10\nsearch lab.test\n' > /etc/resolv.conf
```

## Sintassi
```
nslookup [-opzione ...] [nome] [server]
```
Il **server** è l'ultimo argomento (senza `@`, al contrario di `dig`). Senza nome parte la modalità interattiva.
```bash
nslookup web.lab.test                 # chiede al server di /etc/resolv.conf
nslookup web.lab.test 10.10.2.10      # chiede a questo server
nslookup web.lab.test 10.10.2.10
# Server:		10.10.2.10
# Address:	10.10.2.10#53
#
# Name:	web.lab.test
# Address: 10.10.2.10
# Name:	web.lab.test
# Address: fd00:10:2::10
```
Le prime due righe dicono **a chi è stata fatta la domanda** (come `SERVER:` di dig); poi le risposte. `nslookup` chiede di default **sia `A` sia `AAAA`**, per questo i due indirizzi. Il TTL, il flag `aa` e il `status` non si vedono.

### Autorevole o no
Se la risposta non viene dal server che ha la zona (cioè non ha il flag `aa`), compare:
```
Non-authoritative answer:
Name:	example.com
Address: 104.20.23.154
```
**Non è un errore**: dice solo che il server l'ha presa da una cache o da un altro. Una risposta per la zona di BIND (`web.lab.test`) non lo ha, perché BIND è autorevole per `lab.test`. Su Windows lo stesso avviso è `Risposta da un server non autorevole:` (nella lingua del sistema), **prima** delle righe `Server` e `Address`.

## Il tipo di record: `-type` (o `-query`)
```bash
nslookup -type=MX lab.test               # lab.test	mail exchanger = 10 web.lab.test.   (e il 20 backup.lab.test.)
nslookup -type=NS lab.test               # lab.test	nameserver = ns1.lab.test.
nslookup -type=TXT lab.test              # lab.test	text = "v=spf1 mx -all"
nslookup -type=AAAA web.lab.test         # Name: web.lab.test / Address: fd00:10:2::10
nslookup -type=SRV _http._tcp.lab.test   # _http._tcp.lab.test	service = 10 5 80 web.lab.test.
nslookup -type=CNAME www.lab.test        # www.lab.test	canonical name = web.lab.test.
nslookup -type=PTR 20.2.10.10.in-addr.arpa     # 20.2.10.10.in-addr.arpa	name = backup.lab.test.
nslookup -query=TXT lab.test             # -query è un sinonimo di -type
nslookup -type=SOA lab.test
# lab.test
# 	origin = ns1.lab.test
# 	mail addr = admin.lab.test        <- il primo punto è la @: admin@lab.test
# 	serial = 2026110601
# 	refresh = 3600
# 	retry = 900
# 	expire = 604800
# 	minimum = 300
```
`-type=ANY` dà SOA, NS, MX e TXT, ma non gli `A` degli altri nomi (come in dig). Su Windows `-querytype=NS` e `-type=NS` sono sinonimi.

La stringa che nslookup stampa per ogni tipo è sempre uguale e si può filtrare:
```bash
nslookup -type=MX lab.test | grep -i 'mail exchanger'
# lab.test	mail exchanger = 20 backup.lab.test.
# lab.test	mail exchanger = 10 web.lab.test.
```
> **NOTA**: i record `MX` sono stampati nell'ordine in cui arrivano, non per priorità: il numero più **basso** vince.

## Reverse DNS
Basta passare l'**indirizzo**: nslookup capisce che è un IP e chiede il `PTR` (senza `-x`, che è di dig):
```bash
nslookup 10.10.2.10
# 10.2.10.10.in-addr.arpa	name = web.lab.test.
nslookup 8.8.8.8 1.1.1.1
# 8.8.8.8.in-addr.arpa	name = dns.google.
#
# Authoritative answers can be found from:
```
Quella riga `Authoritative answers can be found from:` seguita dal nulla è un **difetto noto** di questa versione quando il resolver non manda i `NS`: si ignora. Su Windows il reverse dice `Nome:    dns.google` / `Address:  8.8.8.8`.

## Errori ed exit code
```bash
nslookup nonesiste.lab.test
# Server:		10.10.2.10
# Address:	10.10.2.10#53
#
# ** server can't find nonesiste.lab.test: NXDOMAIN          <- exit code 1
nslookup web.lab.test 10.10.2.99
# ;; communications error to 10.10.2.99#53: timed out         <- ripetuto 3 volte
# ;; no servers could be reached                              <- exit code 1
nslookup -timeout=1 -retry=1 web.lab.test 10.10.2.99          # -timeout: secondi di attesa; -retry: tentativi in più. Qui una sola prova
nslookup -port=5353 -timeout=1 -retry=1 web.lab.test 10.10.2.10
# ;; communications error to 10.10.2.10#5353: connection refused
```
Differenza con `dig`: **`nslookup` esce con 1 quando il nome non esiste**, `dig` con 0. Quindi in uno script `nslookup nome >/dev/null && echo esiste` funziona senza leggere l'output.
Il messaggio è lo stesso per qualunque tipo (`-type=MX nonesiste.lab.test` dà ancora `NXDOMAIN`). Il nome che **esiste ma non ha quel tipo** (il caso *NODATA*) dà un messaggio diverso e **exit code 0**:
```bash
nslookup -type=MX web.lab.test
# *** Can't find web.lab.test: No answer
```
`dig` lo mostra meglio, come `NOERROR` con `ANSWER: 0` e il `SOA` in `AUTHORITY`.

> **ATTENZIONE**: su **Windows** l'exit code è **0** anche per `Non-existent domain` e per i timeout (provato in PowerShell con `$LASTEXITCODE`): in uno script Windows si legge l'output (`Select-String`), non il codice.

## Opzioni
Sono prefissate da `-` e valgono per tutta la riga.

| Opzione | Effetto |
|---|---|
| `-type=T` / `-query=T` | tipo di record |
| `-class=CH` | classe (`IN` di default, `CH` per `version.bind`) |
| `-port=N` | porta del server |
| `-timeout=N` | secondi di attesa per tentativo |
| `-retry=N` | numero di ritentativi |
| `-debug` | mostra anche la risposta grezza (vedi sotto) |
| `-vc` | usa TCP invece di UDP |
| `-norecurse` / `-recurse` | spegne / accende la ricorsione |
| `-domain=lab.test` | il dominio aggiunto ai nomi corti (come `search`) |
| `-nosearch` / `-search` | usa o no la lista di ricerca |

Il nome corto **funziona**, a differenza di `dig`: nslookup applica la riga `search` di `/etc/resolv.conf`:
```bash
nslookup web                          # Name: web.lab.test  Address: 10.10.2.10  (e l'AAAA)
nslookup -domain=lab.test web         # lo stesso, con il dominio dato a mano (senza toccare resolv.conf)
nslookup -nosearch web                # nessun indirizzo: chiede "web." alla radice (nel lab: ** server can't find web: SERVFAIL, dopo un timeout)
nslookup -vc web.lab.test             # stessa risposta, via TCP (la porta 53 TCP deve essere aperta)
nslookup -class=CH -type=TXT version.bind 10.10.2.10    # version.bind	text = "9.18.39-0ubuntu0.24.04.9-Ubuntu"
```
`-debug` stampa, per **ogni** domanda (qui due: A e AAAA), il pacchetto di risposta con TTL e sezioni: l'unico modo di vederli con nslookup.
```bash
nslookup -debug web.lab.test
# ------------
#     QUESTIONS:
# 	web.lab.test, type = A, class = IN
#     ANSWERS:
#     ->  web.lab.test
# 	internet address = 10.10.2.10
# 	ttl = 3600
#     AUTHORITY RECORDS:
#     ADDITIONAL RECORDS:
# ------------
# Name:	web.lab.test
# Address: 10.10.2.10
# ------------      (poi lo stesso per AAAA)
```
Su Windows `-debug` mostra anche l'intestazione (`opcode`, `rcode`, flag `response, want recursion, recursion avail.`) e il TTL con la durata leggibile (`ttl = 1050 (17 mins 30 secs)`).

## Modalità interattiva
Senza argomenti, `nslookup` apre un prompt. Si cambiano server e opzioni e si fanno più domande, che restano sotto lo stesso server:
```
$ nslookup
> server 10.10.2.10        cambia il server per le domande successive
Default server: 10.10.2.10
Address: 10.10.2.10#53
> set type=MX              cambia il tipo di record
> lab.test
lab.test	mail exchanger = 10 web.lab.test.
lab.test	mail exchanger = 20 backup.lab.test.
> set type=PTR
> 10.10.2.20
20.2.10.10.in-addr.arpa	name = backup.lab.test.
> set debug                 come -debug
> exit
```
Funziona anche dalla pipe (utile per provare o negli script): `printf 'server 10.10.2.10\nset type=MX\nlab.test\nexit\n' | nslookup`.

I comandi del prompt:

| Comando | Effetto |
|---|---|
| `server NOME` / `lserver NOME` | cambia il server (con `lserver` si chiede il nome al server **iniziale**, non a quello attuale) |
| `set type=T` (o `set querytype=T`) | tipo di record |
| `set class=CH` | classe |
| `set [no]debug`, `set [no]d2` | risposta grezza; `d2` anche la domanda |
| `set [no]recurse`, `set [no]search`, `set [no]vc` | ricorsione, lista di ricerca, TCP |
| `set domain=X`, `set timeout=N`, `set retry=N`, `set port=N` | come le opzioni a riga di comando |
| `set all` | mostra tutte le impostazioni |
| `exit` | esce |

```
> set all
Default server: 10.10.2.10
Address: 10.10.2.10#53

Set options:
  novc			nodebug		nod2
  search		recurse
  timeout = 0		retry = 3	port = 53	ndots = 1
  querytype = A       	class = IN
  srchlist = lab.test
```
> **NOTA**: nel `nslookup` di Linux (BIND 9.18) il comando `ls -d dominio` per elencare la zona **non esiste** (`The 'ls' command is not implemented.`). Su Windows c'era, ma i server veri rifiutano quasi sempre; la via è `dig AXFR` ([12-dig.md](12-dig.md)).

## Su Windows
`nslookup.exe` c'è da sempre: stessa sintassi, ma l'output è **nella lingua del sistema** e l'ordine diverso:
```
C:\> nslookup example.com 1.1.1.1
Risposta da un server non autorevole:
Server:  one.one.one.one
Address:  1.1.1.1

Nome:    example.com
Addresses:  2606:4700:10::6814:179a
	  2606:4700:10::ac42:93f3
	  104.20.23.154
	  172.66.147.243
```
- il **nome del server** è ricavato con un reverse DNS (`one.one.one.one`); se il reverse non si ottiene appare `Server:  UnKnown` (visto con un server che non rispondeva)
- gli indirizzi sono raggruppati sotto `Addresses:`, **IPv6 prima**
- l'avviso di non autorevolezza sta in cima
- il tipo MX di un dominio con *null MX* (`example.com`) dà `MX preference = 0, mail exchanger = (root)`: il dominio dichiara di **non ricevere posta**
- `nslookup -type=NS ...` e `-querytype=NS` sono equivalenti
- `set all` e `server` funzionano nel prompt; **ma** collegando un file con `nslookup < file` da PowerShell il testo può partire con un segno invisibile (BOM) e il primo comando è `Unrecognized command`: scrivere il file senza BOM

## Quando usare nslookup e quando dig
| | `nslookup` | `dig` |
|---|---|---|
| dove c'è | Linux, macOS, **Windows** | Linux e macOS (su Windows: BIND o WSL) |
| output | breve, interpretato | completo: flag, TTL, sezioni, tempi |
| exit code per `NXDOMAIN` | 1 (su Windows 0) | 0 |
| nome corto con `search` | sì | solo con `+search` |
| `/etc/hosts` | non lo legge | non lo legge |
| `+trace`, DNSSEC, `AXFR`, più domande | no | sì |
| interattivo | sì | no (c'è `-f file`) |

Nessuno dei due passa da `/etc/hosts`: per la risoluzione "dei programmi" resta `getent hosts nome` (Linux) o `ping`/`Resolve-DnsName` (Windows).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `** server can't find X: NXDOMAIN` | il nome non esiste su **quel** server (anche se per i programmi sì: `/etc/hosts`) | `getent hosts X`; riprovare con un altro server |
| `Non-authoritative answer:` | risposta da cache o da un server non autorevole | normale; per l'autorevole chiedere al `NS` della zona |
| `;; no servers could be reached` | server giù o firewall; exit code 1 | `-timeout=1 -retry=1` per fare in fretta; `nc -zvu server 53` |
| `Server:  UnKnown` (Windows) | nessun nome inverso per il server DNS (o server che non risponde) | se la risposta c'è è irrilevante; altrimenti `-timeout`, altro server |
| con `nslookup nome` funziona e con `dig nome` no | `dig` non applica `search` | `dig +search nome` o nome completo |
| due indirizzi dove ne aspettavo uno | `nslookup` chiede anche `AAAA` | `-type=A` |
| `*** Invalid option: srchlist=a/b` | la lista di ricerca con `/` non è accettata in questa versione | `set domain=...` |
| `ls` non funziona | non implementato | `dig AXFR` |

Torna all'[indice dell'area](README.md)
