# 10 - Rete e web

Reti IP più a fondo, diagnostica, web server e bilanciatori di carico.
I comandi di rete di base (`ip -br a`, `ss`, `dig +short`, `curl -I`) sono in [../06-sistema/06-rete-e-host.md](../06-sistema/06-rete-e-host.md).

| # | File | Contenuto |
|---|---|---|
| 01 | [indirizzi e configurazione](01-indirizzi-e-configurazione.md) | CIDR e subnet, `ip addr`/`ip route`, netplan, DNS locale, da `ifconfig`/`route`/`netstat` a `ip`/`ss` |
| 02 | [diagnostica](02-diagnostica.md) | `traceroute`, `mtr`, `dig +trace`, `nslookup`, `whois`, `iftop`, `tcpdump`, `nc`, `nmap` |
| 03 | [namespace](03-namespace.md) | Laboratorio: più host su una sola macchina con `ip netns` e le veth pair |
| 03 | [03-namespace.sh](03-namespace.sh) | Script che crea e smonta tre host collegati a un bridge |
| 04 | [apache e nginx](04-apache-nginx.md) | Siti e moduli, verifica e reload, virtual host, Laravel con PHP-FPM, reverse proxy, HTTPS con `certbot` |
| 05 | [load balancer](05-load-balancer/) | Laboratorio Docker: HAProxy dietro HAProxy, Nginx, Caddy, Envoy o Traefik |
| 06 | [server dns](06-dns-server.md) | `dnsmasq` e BIND: record, MX, zone inversa, cache, secondario con `AXFR`, serial e `NOTIFY`, `rndc` |
| 07 | [posta](07-posta-postfix.md) | Postfix e Dovecot: MX, `main.cf` e `postconf`, coda, rimbalzi, relay, alias, IMAP; conversazioni SMTP e IMAP a mano |
| 08 | [condivisioni](08-condivisioni-nfs-samba.md) | NFS (`exports`, v3 e v4, `root_squash`) e Samba (utenti, gruppi, `mount.cifs`) |
| 09 | [alta disponibilità](09-alta-disponibilita-keepalived.md) | `keepalived` e VRRP: IP virtuale, controllo del servizio, failover e preempt |
| 10 | [esercizi](10-esercizi.md) | 16 esercizi su una rete vera (`ipcalc`, `ip addr/route/link`, namespace con `veth`, `traceroute`, `nc`, `curl`, `nmap`, nginx): `verifica.sh` guarda lo stato dopo |
| 11 | [scenari guidati](11-scenari.md) | 8 guasti veri da diagnosticare e riparare (nginx che non parte, porta occupata, rotta, nome, `502`, firewall, `403`): `scenari.sh controlla` guarda se il sintomo è sparito |

**Laboratorio**: `./lab.sh 10` dalla radice della KB avvia una piccola rete (host, host2, router, web) in cui provare
`ip`, `traceroute`, `tcpdump`, `nmap`, i namespace, nginx e apache2. Dettagli in [lab/](lab/).

Area precedente: [../09-strumenti/](../09-strumenti/) · Prossima: [../11-container-e-automazione/](../11-container-e-automazione/) · Torna all'[indice](../README.md)
