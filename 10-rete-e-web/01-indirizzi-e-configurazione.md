# Indirizzi IP e configurazione di rete

> **Laboratorio**: `./lab.sh 10`, poi `cd 01-indirizzi-e-configurazione`. Cosa contiene: [lab/](lab/).

Come si legge un indirizzo con la sua subnet, come si configura un'interfaccia a mano e in modo permanente,
e a cosa corrispondono i vecchi comandi `ifconfig`, `route`, `netstat`.

Per i comandi di tutti i giorni (`ip -br a`, `ss -tulpn`, `dig +short`) vedi prima
[../06-sistema/06-rete-e-host.md](../06-sistema/06-rete-e-host.md).

## Notazione CIDR e subnet
Un indirizzo IPv4 sono 32 bit. Il numero dopo la `/` dice quanti bit, da sinistra, identificano la **rete**:
i bit restanti identificano l'**host** dentro quella rete.

`192.168.1.10/24` significa:
- netmask `255.255.255.0` (24 bit a 1)
- rete `192.168.1.0`: il primo indirizzo, identifica la rete stessa
- broadcast `192.168.1.255`: l'ultimo indirizzo, "tutti gli host della rete"
- host utilizzabili: da `192.168.1.1` a `192.168.1.254`, cioè 254

`192.168.1.10/23` significa:
- netmask `255.255.254.0` (23 bit a 1: il terzo ottetto ha 7 bit di rete e 1 di host)
- rete `192.168.0.0`, broadcast `192.168.1.255`
- host utilizzabili: da `192.168.0.1` a `192.168.1.254`, cioè 510

Host utilizzabili = 2^(32 - prefisso) - 2 (si tolgono l'indirizzo di rete e quello di broadcast).

| Prefisso | Netmask | Host utilizzabili | Uso tipico |
|---|---|---|---|
| `/8`  | `255.0.0.0`       | 16.777.214 | reti private enormi (`10.0.0.0/8`) |
| `/16` | `255.255.0.0`     | 65.534     | rete di un'azienda, VPC cloud |
| `/23` | `255.255.254.0`   | 510        | due /24 unite |
| `/24` | `255.255.255.0`   | 254        | la rete di casa o di un ufficio |
| `/26` | `255.255.255.192` | 62         | una subnet piccola |
| `/30` | `255.255.255.252` | 2          | collegamento punto-punto tra due router |
| `/32` | `255.255.255.255` | 1 (l'host stesso) | un singolo IP nelle regole firewall |

Indirizzi da riconoscere a colpo d'occhio:

| Intervallo | Significato |
|---|---|
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | privati (RFC 1918): non instradati su internet |
| `127.0.0.0/8` | loopback, la macchina stessa (`127.0.0.1` = localhost) |
| `169.254.0.0/16` | link-local: l'interfaccia non ha ottenuto un IP dal DHCP |
| `0.0.0.0` | "tutte le interfacce" per un servizio in ascolto; "nessuna rotta specifica" nelle tabelle di routing |

```bash
ipcalc 192.168.1.10/23        # calcola rete, broadcast, primo e ultimo host (sudo apt install ipcalc)
```

Senza `ipcalc`, la stessa aritmetica in bash con gli operatori sui bit:
```bash
cidr() {                                          # uso: cidr 192.168.1.10/23
    local ip=${1%/*} bits=${1#*/} a b c d
    IFS=. read -r a b c d <<< "$ip"
    local n=$(( (a << 24) | (b << 16) | (c << 8) | d ))            # l'IP come un unico intero a 32 bit
    local mask=$(( bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF ))
    local rete=$(( n & mask ))                                      # AND con la netmask: azzera i bit di host
    local bcast=$(( rete | (~mask & 0xFFFFFFFF) ))                  # OR con la netmask invertita: bit di host tutti a 1
    local x
    for x in mask rete bcast; do
        printf '%-10s %d.%d.%d.%d\n' "$x" $(( ${!x} >> 24 & 255 )) $(( ${!x} >> 16 & 255 )) $(( ${!x} >> 8 & 255 )) $(( ${!x} & 255 ))
    done
    echo "host       $(( bits >= 31 ? 2 ** (32 - bits) : 2 ** (32 - bits) - 2 ))"
}
```
`${!x}` è l'espansione indiretta: il valore della variabile il cui nome è contenuto in `x`
(vedi [../05-scripting/08-espansioni.md](../05-scripting/08-espansioni.md)).

## Configurare a mano con ip
Le modifiche fatte con `ip` sono **immediate ma non permanenti**: spariscono al riavvio (o quando il gestore
di rete riconfigura l'interfaccia). Servono per test e diagnosi; per renderle permanenti vedi netplan più sotto.
```bash
ip -4 address                                   # solo gli indirizzi IPv4 (ip -6 per gli IPv6)
ip address show dev eth0                        # una sola interfaccia

sudo ip addr add 192.168.1.10/24 dev eth0       # aggiunge un IP all'interfaccia (se ne possono avere più di uno)
sudo ip addr del 192.168.1.10/24 dev eth0       # lo rimuove
sudo ip addr flush dev eth0                     # rimuove TUTTI gli IP dell'interfaccia (via SSH ti chiudi fuori)

sudo ip link set eth0 down                      # disattiva l'interfaccia
sudo ip link set eth0 up                        # la riattiva
sudo ip link set eth0 address 00:1a:2b:3c:4d:5e # cambia il MAC address (in genere va fatto con l'interfaccia down)
sudo ip link set eth0 mtu 1400                  # cambia l'MTU (utile con VPN e tunnel che frammentano i pacchetti)

sudo ip route add 10.8.0.0/24 via 192.168.1.1   # rotta statica: la rete 10.8.0.0/24 si raggiunge passando dal gateway 192.168.1.1
sudo ip route add default via 192.168.1.1       # imposta il default gateway
sudo ip route del 10.8.0.0/24                   # rimuove la rotta
ip rule                                         # regole di policy routing (quale tabella usare in base a sorgente, mark...)
```

## Configurazione permanente
**Ubuntu** usa netplan: file YAML in `/etc/netplan/` che vengono tradotti per systemd-networkd o NetworkManager.
File `/etc/netplan/01-statico.yaml`:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.1.10/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```
```bash
sudo chmod 600 /etc/netplan/01-statico.yaml # netplan avvisa se il file è leggibile da tutti
sudo netplan try                            # applica e torna indietro da solo dopo 120 secondi se non confermi: salva da errori via SSH
sudo netplan apply                          # applica definitivamente
```

**Debian** (installazione classica, pacchetto `ifupdown`) usa `/etc/network/interfaces`:
```
auto eth0
iface eth0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
```
```bash
sudo ifdown eth0 && sudo ifup eth0          # rilegge la configurazione di eth0 (ifup/ifdown esistono solo con ifupdown)
```

## DNS locale
```bash
cat /etc/resolv.conf              # i nameserver usati. Su Ubuntu c'è 127.0.0.53: è systemd-resolved, un intermediario locale
resolvectl status                 # i DNS REALI dietro 127.0.0.53, per ogni interfaccia
resolvectl flush-caches           # svuota la cache DNS locale (come ipconfig /flushdns su Windows)
cat /etc/hosts                    # risoluzioni fisse: vincono sul DNS (es. "10.0.0.5  staging.example.com" per i test)
curl -s https://ifconfig.me; echo # il mio IP PUBBLICO, cioè come mi vede internet (diverso dall'IP della mia interfaccia se sono dietro NAT)
```

## Dai vecchi comandi net-tools a iproute2
`ifconfig`, `route`, `netstat` e `arp` (pacchetto `net-tools`) non sono più installati di default. Si trovano ancora
in guide e script vecchi: questa è la corrispondenza.

| Vecchio | Nuovo | Cosa fa |
|---|---|---|
| `ifconfig -a` | `ip a` | tutte le interfacce, anche quelle spente |
| `ifconfig eth0 192.168.1.10 netmask 255.255.255.0` | `ip addr add 192.168.1.10/24 dev eth0` | assegna IP e netmask |
| `ifconfig eth0 broadcast 192.168.1.255` | `ip addr add 192.168.1.10/24 broadcast 192.168.1.255 dev eth0` | broadcast esplicito (con `ip` di solito non serve: `brd +` lo calcola) |
| `ifconfig eth0 hw ether 00:1A:2B:3C:4D:5E` | `ip link set eth0 address 00:1a:2b:3c:4d:5e` | cambia il MAC |
| `ifconfig wlan0 down` / `up` | `ip link set wlan0 down` / `up` | disattiva / attiva |
| `route -n` | `ip route` | tabella di routing |
| `route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1` | `ip route add 192.168.1.0/24 via 192.168.1.1` | rotta statica |
| `route add default gw 192.168.1.1` | `ip route add default via 192.168.1.1` | default gateway |
| `route del -net 192.168.1.0 netmask 255.255.255.0` | `ip route del 192.168.1.0/24` | rimuove la rotta |
| `arp -a` | `ip neigh` | tabella ARP (IP e MAC dei vicini) |
| `netstat -tulpn` | `ss -tulpn` | porte in ascolto con il processo |
| `netstat -r` | `ip route` | tabella di routing |
| `netstat -i` | `ip -s link` | statistiche (pacchetti, errori) per interfaccia |
| `netstat -s` | `nstat -a` | contatori dei protocolli (TCP, UDP, ICMP) |
