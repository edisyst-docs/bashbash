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

Area precedente: [../09-strumenti/](../09-strumenti/) · Torna all'[indice](../README.md)
