# Laboratorio: più host su una sola macchina con i network namespace

> **Laboratorio**: `./lab.sh 10`, poi `cd 03-namespace`. Cosa contiene: [lab/](lab/).

Per far comunicare due o più "host" con IP diversi senza macchine virtuali si usano i **network namespace**:
una funzionalità del kernel che dà a un gruppo di processi un ambiente di rete tutto suo (interfacce, IP,
tabella di routing, regole firewall). È lo stesso meccanismo su cui si basano i container Docker.

Funziona su qualunque Ubuntu, compresa WSL. Serve root. Dentro il container del `Dockerfile` della KB funziona
solo con `NET_ADMIN` e `SYS_ADMIN` (o `--privileged`): il laboratorio dell'area li ha già, vedi [lab/](lab/).

## Due host collegati da un cavo
```bash
sudo ip netns exec host_1 ping 192.168.100.2 # prima di iniziare: errore, host_1 non esiste ancora
```

### 1. Creare i namespace (i due "computer")
```bash
sudo ip netns add host_1
sudo ip netns add host_2
ip netns list                     # UGUALE a "ip netns": verifica la creazione
```

### 2. Creare una veth pair (il "cavo")
Una veth pair sono due interfacce virtuali gemelle: quello che entra da una esce dall'altra, come un cavo con due estremità.
```bash
sudo ip link add veth_1 type veth peer name veth_2
ip link show type veth            # le due interfacce, per ora nel namespace principale
```

### 3. Collegare un capo a ciascun host
```bash
sudo ip link set veth_1 netns host_1
sudo ip link set veth_2 netns host_2
ip link show type veth                     # nel namespace principale non ci sono più
sudo ip netns exec host_1 ip link list     # veth_1 ora è dentro host_1
sudo ip netns exec host_2 ip link list     # veth_2 dentro host_2
```
`ip netns exec NOME comando` esegue `comando` dentro il namespace: vede solo la rete di quel namespace.

### 4. Assegnare gli IP e accendere le interfacce
```bash
sudo ip netns exec host_1 ip addr add 192.168.100.1/24 dev veth_1
sudo ip netns exec host_2 ip addr add 192.168.100.2/24 dev veth_2

sudo ip netns exec host_1 ip link set veth_1 up
sudo ip netns exec host_2 ip link set veth_2 up
sudo ip netns exec host_1 ip link set lo up   # anche il loopback, spento di default in un namespace nuovo
sudo ip netns exec host_2 ip link set lo up

sudo ip netns exec host_1 ip -br addr         # verifica: veth_1 UP con 192.168.100.1/24
sudo ip netns exec host_2 ip -br addr
```

### 5. Provare la connessione
```bash
sudo ip netns exec host_1 ping -c3 192.168.100.2       # host_1 raggiunge host_2
sudo ip netns exec host_2 ping -c3 192.168.100.1       # e viceversa
sudo ip netns exec host_1 ip neigh                     # host_1 ha imparato il MAC di host_2 via ARP
sudo ip netns exec host_1 nmap -sn 192.168.100.0/24    # ping scan DALL'INTERNO di host_1 (dal namespace principale quella rete non esiste)
```
Ora si possono provare tutti i comandi di [02-diagnostica.md](02-diagnostica.md). Per esempio un server e un client:
```bash
sudo -v                                               # chiede subito la password: un sudo in background non può chiederla
sudo ip netns exec host_2 python3 -m http.server 8000 & # un web server dentro host_2
sudo ip netns exec host_1 curl -s 192.168.100.2:8000 | head -5 # host_1 lo raggiunge
sudo ip netns exec host_2 ss -tlnp                     # dentro host_2 si vede la porta 8000 in ascolto...
ss -tlnp | grep 8000                                   # ...nel namespace principale no
kill %1                                                # ferma il web server
```

### 6. Smontare tutto
```bash
sudo ip netns exec host_1 ip link delete veth_1  # basta eliminare un capo: l'altro sparisce con lui
sudo ip netns del host_1
sudo ip netns del host_2
ip netns list                                    # vuoto
```

## Tre host su uno switch (script)
Con più di due host serve uno "switch": un **bridge** Linux a cui si collega un capo di ogni cavo.
Lo script [03-namespace.sh](03-namespace.sh) crea tre host (`192.168.100.1`, `.2`, `.3`) collegati al bridge `br_lab`:
```bash
sudo ./03-namespace.sh up         # crea namespace, cavi e switch
sudo ./03-namespace.sh test       # host_1 prova a raggiungere gli altri due
sudo ip netns exec host_3 bash    # una shell "dentro" host_3: ogni comando di rete vede solo la sua rete (exit per uscire)
sudo ./03-namespace.sh down       # elimina tutto
```
> **NOTA**: se sulla macchina gira Docker, il traffico che attraversa un bridge può passare dalle regole iptables
> (modulo `br_netfilter`) e venire bloccato dalla policy `DROP` di Docker sulla catena `FORWARD`. Se i ping
> non passano: `sudo iptables -I FORWARD -i br_lab -o br_lab -j ACCEPT`.
