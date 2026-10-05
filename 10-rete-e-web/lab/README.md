# Laboratorio dell'area 10

Una piccola rete con un router in mezzo, per provare `ip`, `traceroute`, `tcpdump`, `nmap`, i namespace e i web
server senza toccare la rete di casa. La descrive [compose.yaml](compose.yaml):
```
host 10.10.1.10 + host2 10.10.1.11 ---- rete "lan" ---- router ---- rete "dmz" ---- web 10.10.2.10
                                              10.10.1.254   10.10.2.254
```

| Container | Cosa è |
|---|---|
| `host` | dove si lavora: `lab.sh` entra qui. Ubuntu con systemd, nginx (80) e apache2 (8080). Può cambiare i propri IP, rotte e MTU e creare namespace (ha `NET_ADMIN` e `SYS_ADMIN`, ma non è `--privileged`) |
| `host2` | un secondo computer sulla stessa rete `lan` (`10.10.1.11`), con systemd: il DNS secondario di `06` e la seconda metà della coppia keepalived di `09` |
| `router` | inoltra i pacchetti tra le due reti: `traceroute -n web` mostra `10.10.1.254` come primo salto |
| `web` | un server nell'altra rete: ssh, nginx che risponde `risposta da web`, apache2 sulla 8080 |

I file di lavoro li genera [prepara.sh](prepara.sh).

## Avvio
Dalla radice della KB:
```bash
./lab.sh 10               # la prima volta costruisce l'immagine bashbash-systemd (qualche minuto)
traceroute -n web
```
All'uscita i tre container e le due reti vengono eliminati.

## Cosa si prova e dove

| Cartella | File pronti | Note |
|---|---|---|
| `01-indirizzi-e-configurazione/` | `cidr.sh` (la funzione del `.md`), `01-statico.yaml` | `ip addr add`, `ip link set eth0 mtu 1400`, `ip route add 10.8.0.0/24 via 10.10.1.254` funzionano sulla scheda `eth0` del container. `netplan`, `resolvectl` e `ifup` no: la rete la gestisce Docker. Attenzione a `ip addr flush dev eth0` e `ip link set eth0 down`: il container perde la rete (si rimedia uscendo e rilanciando) |
| `02-diagnostica/` | `host.txt`, `esclusi.txt` | nella rete del laboratorio: `traceroute`, `tracepath`, `mtr -rw -c 10 web`, `nc -zv web 20-25`, `nmap -sn 10.10.1.0/24 10.10.2.0/24`, `nmap -sV web`, `tcpdump -i any -nn port 80` mentre da un'altra finestra si fa `curl web`. `dig`, `whois` e `nslookup` verso internet funzionano se il PC è in rete |
| `03-namespace/` | `03-namespace.sh` | tutto il `.md`, compreso lo script con il bridge: `./03-namespace.sh up` |
| `04-apache-nginx/` | `mio_sito/index.html`, `mio_sito.nginx` (sito statico), `api.nginx` + `backend.py` (reverse proxy verso la 3000), `mio_sito.conf` (virtual host di apache2) | nel laboratorio apache2 ascolta sulla **8080**, perché la 80 è di nginx: il virtual host è già su `*:8080`. Niente PHP-FPM e niente `certbot` (serve un dominio vero) |

## Servizi di rete: 06, 07, 08, 09
Niente file da preparare: i servizi si installano con `apt` (serve internet, `--dns 192.168.65.7` se il DNS di Docker non risolve) sulla macchina che il `.md` indica.
Ogni macchina nasce pulita a ogni `./lab.sh 10`.

| `.md` | Dove | Cosa si prova | Da sapere nel laboratorio |
|---|---|---|---|
| `06-dns-server` | `dnsmasq` o `bind9` su `web`, secondario BIND su `host2`, client `host` | record, MX, PTR, cache, `AXFR`, serial e `NOTIFY` | `dnsmasq` va legato a `10.10.2.10` (`bind-interfaces`): `systemd-resolved` tiene già la 53 su `127.0.0.53`. Un solo DNS alla volta su `web` (`systemctl stop dnsmasq` prima di `named`) |
| `07-posta-postfix` | Postfix e Dovecot su `web`, Postfix su `host` | consegna via MX, coda, rimbalzi, relay negato, alias, IMAP a mano | prima il DNS di `06` e `/etc/resolv.conf` di `host` e `web` verso `10.10.2.10`; nel container il servizio non parte da solo: `systemctl start postfix` |
| `08-condivisioni-nfs-samba` | `nfs-kernel-server` e `samba` su `web`, client `host` | `exportfs`, mount NFSv3 e v4, `root_squash`, Samba con utenti e gruppi, `mount.cifs` | il disco di un container è `overlayfs` e **non si esporta**: serve un `tmpfs` (e per la v4 un bind mount, vedi il `.md`). `host` ha `CAP_DAC_READ_SEARCH` per `mount.cifs` |
| `09-alta-disponibilita-keepalived` | `keepalived` e nginx su `host` e `host2`, client `web` | VIP `10.10.1.100`, failover, preempt, `notify` | il VIP si prova da `web` (altra rete, via router); funziona il multicast VRRP sulla rete `lan` di Docker |

Non provato qui: il DHCP di `dnsmasq`, la cifratura (TLS, SPF, DKIM) di Postfix, i client Windows di Samba.

Da sapere:
- `dig web` non trova `web`: `dig` interroga solo il DNS e non legge `/etc/hosts`, dove Docker ha scritto il nome
  (`web` sta in un'altra rete, che il DNS di Docker non conosce). Il DNS di Docker inoltra la richiesta al resolver
  del PC, che risponde `127.0.0.1`. `getent hosts web` invece legge `/etc/hosts` come fanno i programmi e dà
  `10.10.2.10`. `dig router`, che sta sulla stessa rete, funziona.
- Per vedere `Address already in use` del `.md`: `systemctl stop nginx`, apache2 sulla 80
  (`sed -i 's/Listen 8080/Listen 80/' /etc/apache2/ports.conf` e `systemctl restart apache2`), poi `systemctl start nginx`.
- Il laboratorio dei bilanciatori ([05-load-balancer/](../05-load-balancer/)) è a parte: si avvia dal PC con compose.

Torna all'[indice dell'area](../README.md)
