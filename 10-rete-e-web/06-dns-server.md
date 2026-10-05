# Un server DNS: dnsmasq e BIND

> **Laboratorio**: `./lab.sh 10`. Il DNS lo si installa su `web` (primario) e su `host2` (secondario); si interroga da `host`. Dettagli in [lab/](lab/).

Finora il DNS è stato solo un client ([02-diagnostica.md](02-diagnostica.md): `dig`, `nslookup`). Qui si **risponde** alle richieste, in due modi:

| | dnsmasq | BIND 9 (`named`) |
|---|---|---|
| a cosa serve | una LAN o un laboratorio: nomi locali, cache, inoltro, e anche DHCP | un DNS autoritativo vero (zone, secondari) e/o un resolver |
| configurazione | un file con una direttiva per riga | `named.conf` e un **file di zona** per ogni dominio |
| zone e trasferimento verso un secondario | no | sì (`AXFR`/`IXFR`, `NOTIFY`) |
| quando | `host-record` e `address=/.../` bastano | un dominio proprio, più server, controllo fine |

Due ruoli diversi, che spesso lo stesso programma fa insieme:
- **autoritativo**: *conosce* le risposte per le proprie zone (`lab.test`) e le dà con il flag `aa`
- **resolver ricorsivo** (cache): non conosce la risposta, la **cerca** per conto del client (da un `forwarder` o dai root) e la tiene in cache per il suo TTL

Gli esempi sono stati eseguiti nel laboratorio dell'area 10 (Ubuntu 24.04: dnsmasq 2.91, BIND 9.18). Il DNS sta sulla porta **53**, UDP e TCP.

## dnsmasq
```bash
sudo apt install dnsmasq
```
Su Ubuntu, `systemd-resolved` ascolta già su `127.0.0.53:53` e `127.0.0.54:53`. `dnsmasq`, avviato così com'è, prova a legare la 53 su **tutte** le interfacce e **non parte**:
```
dnsmasq: failed to create listening socket for port 53: Address already in use
```
La soluzione è dirgli su quale indirizzo ascoltare, con `bind-interfaces`. La configurazione sta in `/etc/dnsmasq.d/*.conf`:
```bash
sudo tee /etc/dnsmasq.d/lab.conf <<'EOF'
listen-address=10.10.2.10        # solo questo indirizzo: 127.0.0.53 e :54 restano di systemd-resolved
bind-interfaces
no-resolv                        # non leggere /etc/resolv.conf (a volte punta a se stesso)
server=192.168.65.7              # il resolver a monte a cui inoltrare quello che non si conosce
domain=lab.test
local=/lab.test/                 # lab.test non si inoltra a monte: un nome sconosciuto dà NXDOMAIN
expand-hosts                     # i nomi corti di /etc/hosts diventano anche web.lab.test
host-record=web.lab.test,10.10.2.10        # A (e il PTR inverso, in automatico)
host-record=host.lab.test,10.10.1.10
address=/app.lab.test/10.10.2.10           # un nome (e i suoi sottodomini) verso un IP
cname=www.lab.test,web.lab.test
mx-host=lab.test,web.lab.test,10
txt-record=lab.test,"v=spf1 mx -all"
cache-size=1000
log-queries                      # una riga di log per richiesta: solo per le prove
EOF
dnsmasq --test                   # dnsmasq: syntax check OK.
sudo systemctl restart dnsmasq
```
Dal client:
```bash
dig @10.10.2.10 +short web.lab.test       # 10.10.2.10
dig @10.10.2.10 +short www.lab.test       # web.lab.test.  10.10.2.10     <- prima il CNAME, poi l'indirizzo
dig @10.10.2.10 +short app.lab.test       # 10.10.2.10
dig @10.10.2.10 +short MX lab.test        # 10 web.lab.test.
dig @10.10.2.10 +short TXT lab.test       # "v=spf1 mx -all"
dig @10.10.2.10 +short -x 10.10.2.10      # web.lab.test.
dig @10.10.2.10 nonesiste.lab.test | grep status     # status: NXDOMAIN   <- risposta subito, senza chiedere a monte
dig @10.10.2.10 +short example.com        # inoltrata a 192.168.65.7, poi in cache
```
Il log (`journalctl -u dnsmasq`) dice chi ha chiesto cosa e **da dove viene la risposta**:
```
query[A] nonesiste.lab.test from 10.10.1.10
config nonesiste.lab.test is NXDOMAIN        <- "config": viene dalla configurazione locale
query[A] example.com from 10.10.1.10
cached example.com is 104.20.23.154          <- "cached": dalla cache (la prima volta "forwarded")
```
`kill -USR1 $(pidof dnsmasq)` scrive nel log le statistiche: `cache size 1000, ...`, `queries forwarded 3, queries answered locally 5`.

### Usarlo come DNS del client
Su un client `systemd-resolved` si punta con `resolvectl dns eth0 10.10.2.10` (o dal netplan, [01-indirizzi-e-configurazione.md](01-indirizzi-e-configurazione.md)). Nel container, dove `/etc/resolv.conf`
è un file normale, basta scriverlo (e la riga `search` fa risolvere i nomi corti):
```bash
printf 'nameserver 10.10.2.10\nsearch lab.test\n' > /etc/resolv.conf
getent hosts web www                  # 10.10.2.10 web.lab.test / 10.10.2.10 web.lab.test www.lab.test
ping -c1 app                          # PING app.lab.test (10.10.2.10)
```
`dig` **non** usa la riga `search` (a meno di `+search`): `dig app` interroga il nome `app.` e non `app.lab.test`. `getent` e `ping` sì.

dnsmasq fa anche il **DHCP** (`dhcp-range=10.10.1.100,10.10.1.200,12h`, `dhcp-host=MAC,IP`) e vi lega i nomi dei client al DNS: è il motivo per cui lo montano molti router. Qui non è stato provato (in un container non c'è un broadcast della LAN da servire).

## BIND 9
```bash
sudo apt install bind9 bind9-utils bind9-dnsutils           # il servizio è named.service
named -v                                                    # BIND 9.18.39-0ubuntu0.24.04.7-Ubuntu
ls /etc/bind                                                # named.conf, named.conf.options, named.conf.local, zone predefinite
```
`named.conf` include due file da modificare: `named.conf.options` (comportamento del server) e `named.conf.local` (le proprie zone).

### Opzioni: chi può chiedere cosa
```bash
sudo tee /etc/bind/named.conf.options <<'EOF'
options {
	directory "/var/cache/bind";
	listen-on { 10.10.2.10; 127.0.0.1; };          // su quali indirizzi ascolta
	listen-on-v6 { none; };
	allow-query { 10.10.0.0/16; localhost; };      // chi può chiedere
	recursion yes;
	allow-recursion { 10.10.0.0/16; localhost; };  // chi può chiedere di CERCARE per suo conto
	forwarders { 192.168.65.7; };                  // a chi inoltrare quello che non conosce
	dnssec-validation no;                          // solo nel laboratorio, senza i root raggiungibili
};
EOF
```
> **ATTENZIONE**: un resolver ricorsivo aperto a tutta internet (`recursion yes` senza `allow-recursion`) viene usato per gli attacchi di amplificazione DDoS. Un server **autoritativo** per un dominio pubblico ha `recursion no`.

### La zona
Una zona è un file di record. In `named.conf.local` si dichiara, e nel file si scrivono i record:
```bash
sudo tee -a /etc/bind/named.conf.local <<'EOF'
zone "lab.test" {
	type primary;
	file "/etc/bind/zones/db.lab.test";
	allow-transfer { 10.10.1.11; };       // chi può scaricare tutta la zona: solo il secondario
	also-notify { 10.10.1.11; };          // a chi dire "è cambiata"
};
zone "2.10.10.in-addr.arpa" {             // la zona inversa: gli indirizzi 10.10.2.x, scritti al contrario
	type primary;
	file "/etc/bind/zones/db.10.10.2";
};
EOF
sudo mkdir /etc/bind/zones
sudo tee /etc/bind/zones/db.lab.test <<'EOF'
$TTL 1h
@	IN	SOA	ns1.lab.test. admin.lab.test. (
		2026100501	; serial: AAAAMMGGNN, da aumentare a ogni modifica
		1h		; refresh: ogni quanto il secondario controlla
		15m		; retry
		1w		; expire: dopo quanto il secondario smette di rispondere se non sente il primario
		5m )		; negative TTL
	IN	NS	ns1.lab.test.
	IN	NS	ns2.lab.test.
	IN	MX	10 web.lab.test.
ns1	IN	A	10.10.2.10
ns2	IN	A	10.10.1.11
web	IN	A	10.10.2.10
host	IN	A	10.10.1.10
www	IN	CNAME	web
EOF
sudo tee /etc/bind/zones/db.10.10.2 <<'EOF'
$TTL 1h
@	IN	SOA	ns1.lab.test. admin.lab.test. ( 2026100501 1h 15m 1w 5m )
	IN	NS	ns1.lab.test.
10	IN	PTR	web.lab.test.
EOF
sudo named-checkconf && echo conf-ok                                       # nessun output = ok
sudo named-checkzone lab.test /etc/bind/zones/db.lab.test                  # zone lab.test/IN: loaded serial 2026100501 / OK
sudo systemctl restart named
```
Le regole del file di zona, dove si sbaglia di più:
- **il punto finale**: `web.lab.test.` è un nome completo; `web` (o `web.lab.test` senza punto) ha **in coda il nome della zona**. `www CNAME web.lab.test` (senza punto) diventa `web.lab.test.lab.test.`;
  `named-checkzone` non lo segnala, perché è un record valido: `named-checkzone -D lab.test file | grep www` lo mostra
- **il `serial`** deve **aumentare** a ogni modifica: i secondari confrontano solo questo numero (vedi sotto). La forma `AAAAMMGGNN` permette dieci modifiche al giorno
- `@` è il nome della zona, un campo vuoto a inizio riga ripete il nome precedente
- il nome del server (`ns1.lab.test.`) deve avere un record `A` nella zona (qui sì)

Un errore nel file lo trova `named-checkzone` prima che si carichi:
```bash
named-checkzone lab.test /tmp/z
# dns_rdata_fromtext: /tmp/z:17: near '999.1.1.1': bad dotted quad
# zone lab.test/IN: loading from master file /tmp/z failed: bad dotted quad
# zone lab.test/IN: not loaded due to errors.
```
Dal client:
```bash
dig @10.10.2.10 +short web.lab.test       # 10.10.2.10
dig @10.10.2.10 +short www.lab.test       # web.lab.test.  10.10.2.10
dig @10.10.2.10 +short MX lab.test        # 10 web.lab.test.
dig @10.10.2.10 +short -x 10.10.2.10      # web.lab.test.
dig @10.10.2.10 nonesiste.lab.test | grep flags      # qr aa rd ra  + NXDOMAIN: "aa" = risposta autoritativa
dig @10.10.2.10 example.com | grep flags             # qr rd ra     <- niente "aa": l'ha cercata e inoltrata
dig @10.10.2.10 AXFR lab.test                        # "; Transfer failed.": il client non è il secondario
```

### Il secondario
Un secondo server con una **copia** della zona, che risponde anche se il primario è giù. Su `host2` (`10.10.1.11`):
```bash
sudo tee /etc/bind/named.conf.options <<'EOF'
options {
	directory "/var/cache/bind";
	listen-on { 10.10.1.11; 127.0.0.1; };
	listen-on-v6 { none; };
	recursion no;                         // un autoritativo non fa da resolver
	dnssec-validation no;
};
EOF
sudo tee -a /etc/bind/named.conf.local <<'EOF'
zone "lab.test" {
	type secondary;
	primaries { 10.10.2.10; };
	file "/var/cache/bind/db.lab.test";       // la copia: in /var/cache/bind, dove named può scrivere
};
EOF
sudo systemctl restart named
journalctl -u named | grep lab.test
# zone lab.test/IN: Transfer started.
# transfer of 'lab.test/IN' from 10.10.2.10#53: connected using 10.10.2.10#53
# zone lab.test/IN: transferred serial 2026100501
# transfer of 'lab.test/IN' from 10.10.2.10#53: Transfer completed: 1 messages, 10 records, 247 bytes
dig @127.0.0.1 +short SOA lab.test        # ns1.lab.test. admin.lab.test. 2026100501 3600 900 604800 300
```
Il trasferimento (`AXFR`) è una richiesta TCP della zona intera; `allow-transfer` la limita al secondario perché altrimenti chiunque scaricherebbe l'elenco di tutti gli host.
Adesso la modifica, e il motivo del `serial`:
```bash
# sul primario: un record nuovo, SENZA toccare il serial
echo "db	IN	A	10.10.2.50" | sudo tee -a /etc/bind/zones/db.lab.test
sudo rndc reload lab.test
dig @127.0.0.1 +short db.lab.test         # 10.10.2.50
# sul secondario:
dig @127.0.0.1 +short db.lab.test         # (vuoto)       <- non ha copiato niente: il serial è sempre 2026100501

# sul primario: serial +1
sudo sed -i 's/2026100501/2026100502/' /etc/bind/zones/db.lab.test
sudo rndc reload lab.test                 # BIND manda un NOTIFY al secondario
# sul secondario, un attimo dopo:
dig @127.0.0.1 +short db.lab.test         # 10.10.2.50
journalctl -u named | grep transferred    # zone lab.test/IN: transferred serial 2026100502
```
**Il caso più comune di "il secondario risponde con dati vecchi" è un serial non aumentato.** Il secondario non guarda il contenuto, solo se il numero è più alto del suo.

### `rndc` e la cache
`rndc` è il comando che controlla `named` (usa la chiave `/etc/bind/rndc.key`):
```bash
sudo rndc status                          # versione, boot time, numero di zone
sudo rndc reload                          # ricarica tutto  (rndc reload lab.test: una zona)
sudo rndc zonestatus lab.test             # type: primary, serial: 2026100502, last loaded...
sudo rndc flush                           # svuota la cache del resolver
```
Nella cache il TTL scende fino a zero e poi si richiede: `dig @127.0.0.1 example.com` mostra `129`, poi `127`, dopo due secondi.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `dnsmasq: failed to create listening socket for port 53: Address already in use` | `systemd-resolved` (127.0.0.53) o un altro DNS già sulla 53 | `listen-address=...` e `bind-interfaces`; `ss -tulnp \| grep :53` |
| `named` non parte dopo una modifica | errore di configurazione o di zona | `named-checkconf`, `named-checkzone`, `journalctl -u named` |
| `dig @server nome` risponde `REFUSED` | il client non è in `allow-query` (o `allow-recursion`) | aggiungere la rete del client |
| il secondario ha dati vecchi | `serial` non aumentato, o `allow-transfer` non include il secondario | alzare il serial, `rndc reload`; sul secondario `journalctl -u named \| grep transfer` |
| `Transfer failed` | `allow-transfer` o firewall (TCP 53 chiuso) | il trasferimento usa **TCP** 53, non solo UDP |
| un CNAME punta a `nome.zona.zona.` | manca il punto finale | scrivere `web.lab.test.` o solo `web` |
| il nome si risolve con `ping` e non con `dig` | `dig` non usa la riga `search` di `resolv.conf` | `dig +search nome` |
| dopo una correzione il client vede ancora il vecchio indirizzo | cache (TTL) del resolver o del client | aspettare il TTL, `rndc flush`, `resolvectl flush-caches` |

Torna all'[indice dell'area](README.md)
