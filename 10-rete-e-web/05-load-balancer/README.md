# 05 - Load balancer

| File | Contenuto |
|---|---|
| [load-balancer.md](load-balancer.md) | Il laboratorio: bilanciatore primario -> HAProxy -> 3 web server, a mano e con compose |
| [compose.yaml](compose.yaml) | Tutto il laboratorio, con un profilo per ogni bilanciatore primario |
| [haproxy.cfg](haproxy.cfg) | HAProxy secondario: `roundrobin` fra i web server, pagina di statistiche |
| [haproxy-primario.cfg](haproxy-primario.cfg) | HAProxy come primario |
| [nginx.conf](nginx.conf) | Nginx come primario |
| [Caddyfile](Caddyfile) | Caddy come primario |
| [envoy.yaml](envoy.yaml) | Envoy come primario (API v3) |
| [traefik.yml](traefik.yml), [traefik-dinamico.yml](traefik-dinamico.yml) | Traefik come primario |

```bash
docker compose --profile haproxy up -d   # poi http://localhost:8000 (oppure: nginx, caddy, envoy, traefik, uno alla volta)
docker compose --profile "*" down        # pulizia, qualunque profilo sia attivo
```
Serve Docker; le porte 8000, 8080-8083 e 8404 del PC devono essere libere.

Torna a [../](../)
