# Esercizi: indirizzi, rotte, diagnostica e nginx

> **Laboratorio**: `./lab.sh 10`, poi `cd 10-esercizi`. Gli esercizi agiscono sulla **rete vera** del container `host` (indirizzi, rotte, MTU, namespace, nginx, `/etc/hosts`): è usa-e-getta (vedi [lab/](lab/)).

Sedici esercizi sui comandi dell'area: [indirizzi](01-indirizzi-e-configurazione.md), [diagnostica](02-diagnostica.md), [namespace](03-namespace.md) e [nginx](04-apache-nginx.md). Alcuni **calcolano o interrogano** la rete (stampano un risultato),
altri la **cambiano** (un IP, una rotta, un virtual host): `verifica.sh` guarda **lo stato** che ne risulta. Le soluzioni sono nascoste in fondo a ogni esercizio.
(I servizi di [06](06-dns-server.md), [07](07-posta-postfix.md), [08](08-condivisioni-nfs-samba.md) e [09](09-alta-disponibilita-keepalived.md) si installano con `apt`, che chiede internet: non fanno parte degli esercizi automatici.)

## Come si lavora
Ogni risposta è uno script `risposte/NN.sh` (due cifre) con **uno o più comandi**, eseguito come root sul container `host`:
```bash
cd ~/lab/10-esercizi
echo "echo \$((2 ** (32 - 27) - 2))" > risposte/02.sh          # la risposta all'esercizio 2
./verifica.sh 2
#   02  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                                  # tutti (circa 15 secondi): quelli senza risposta sono "da fare"
```
Per ogni esercizio `verifica.sh` **riporta la rete allo stato di partenza**, esegue la tua risposta, legge lo **stato** (gli indirizzi di `eth0`, la rotta, la risposta di nginx...) e **rimette tutto com'era**; poi fa lo stesso con la soluzione di riferimento
e confronta. Negli esercizi di calcolo e di diagnostica (1-3, 9-14) confronta l'**output**, negli altri lo **stato**: conta il risultato, non il comando.
```
  05  SBAGLIATO
        2c2
        < 1400
        ---
        > 1500
        (< atteso, > ottenuto)
```
> **Attenzione**: `verifica.sh` aggiunge e toglie indirizzi, rotte, namespace e file di nginx **del container**: serve root e il container `host` del laboratorio 10 (10.10.1.10), e si rifiuta altrove.
> Se un esercizio lascia qualcosa, `bash /kb/10-rete-e-web/lab/soluzioni.sh pulisci N` lo toglie.

La rete del laboratorio: `host` 10.10.1.10 e `host2` 10.10.1.11 nella `lan`, il `router` (10.10.1.254 / 10.10.2.254) in mezzo, `web` 10.10.2.10 nella `dmz` (nginx che risponde `risposta da web`, apache2 sulla 8080, ssh):
```
host 10.10.1.10 + host2 10.10.1.11 ---- lan ---- router ---- dmz ---- web 10.10.2.10
                                       10.10.1.254  10.10.2.254
```

## Indirizzi e subnet ([01-indirizzi-e-configurazione.md](01-indirizzi-e-configurazione.md))
**1.** L'**indirizzo di rete** e il **broadcast** di `192.168.37.130/26`, uno per riga e **senza** `/26` (due righe).
<details><summary>soluzione</summary>

```bash
ipcalc 192.168.37.130/26 | awk '/^Network:/ {split($2, a, "/"); print a[1]} /^Broadcast:/ {print $2}'
# 192.168.37.128
# 192.168.37.191
```
Una `/26` ha blocchi da 64 indirizzi (256 / 4): `130` cade nel blocco `128-191`. Il primo (`.128`) è la rete, l'ultimo (`.191`) il broadcast; gli host utilizzabili sono `.129`-`.190`. `ipcalc` stampa anche tutto in binario.
</details>

**2.** Quanti **host utilizzabili** ha una rete `/27`? (un numero)
<details><summary>soluzione</summary>

```bash
echo $(( 2 ** (32 - 27) - 2 ))
# 30
```
Restano 5 bit per gli host: 2⁵ = 32 indirizzi, meno 2 (la rete e il broadcast).
</details>

**3.** La **maschera decimale** di `10.0.0.0/22`. (un indirizzo)
<details><summary>soluzione</summary>

```bash
ipcalc 10.0.0.0/22 | awk '/^Netmask:/ {print $2}'
# 255.255.252.0
```
22 bit a 1: i primi due byte sono `255`, il terzo ha 6 bit a 1 (`11111100` = 252).
</details>

**4.** Aggiungi a `eth0` un **secondo indirizzo** `10.10.1.50/24` (senza togliere il primo). *(Cambia la rete.)*
<details><summary>soluzione</summary>

```bash
ip addr add 10.10.1.50/24 dev eth0
ip -4 -o addr show dev eth0 | awk '{print $4}'
# 10.10.1.10/24
# 10.10.1.50/24
```
L'indirizzo aggiunto con `ip` vale **fino al riavvio**: per renderlo permanente si scrive nella configurazione di rete (netplan, ecc.). Con `/16` al posto di `/24` cambierebbe la maschera, e quindi la rete raggiungibile.
</details>

**5.** Imposta l'**MTU** di `eth0` a `1400`. *(Cambia la rete.)*
<details><summary>soluzione</summary>

```bash
ip link set dev eth0 mtu 1400
cat /sys/class/net/eth0/mtu
# 1400
```
Era `1500`, il valore predefinito di Ethernet. Un MTU più piccolo si usa dentro tunnel e VPN (che aggiungono intestazioni): `tracepath` ([02-diagnostica.md](02-diagnostica.md)) mostra l'MTU del percorso, e il comando si trova anche in [01-indirizzi-e-configurazione.md](01-indirizzi-e-configurazione.md).
</details>

**6.** Aggiungi la **rotta** per `10.8.0.0/24` che passa dal router `10.10.1.254`. *(Cambia la rete.)*
<details><summary>soluzione</summary>

```bash
ip route add 10.8.0.0/24 via 10.10.1.254
ip route show 10.8.0.0/24
# 10.8.0.0/24 via 10.10.1.254 dev eth0
```
Il gateway deve essere **raggiungibile direttamente** (nella stessa rete di `eth0`): `10.10.1.254` lo è, per un indirizzo di un'altra rete `ip` risponde `Error: Nexthop has invalid gateway.` (provato con `10.20.30.40`).
</details>

**14.** Qual è il **gateway predefinito** di `host`? (solo l'indirizzo)
<details><summary>soluzione</summary>

```bash
ip route show default | awk '{print $3}'
# 10.10.1.1
```
La riga è `default via 10.10.1.1 dev eth0`: la terza parola. È il gateway di Docker, **non** il router del laboratorio: `web` si raggiunge con una rotta più specifica (`10.10.2.0/24 via 10.10.1.254`), che vince sulla `default` perché è più precisa.
</details>

## Namespace ([03-namespace.md](03-namespace.md))
**7.** Crea il **namespace** `prova` con una coppia **veth**: `v0` resta nell'host con `10.99.0.1/24`, `v1` va nel namespace con `10.99.0.2/24`; entrambe attive. Dal namespace si deve poter fare **ping** a `10.99.0.1`. *(Cambia la rete.)*
<details><summary>soluzione</summary>

```bash
ip netns add prova
ip link add v0 type veth peer name v1                    # un "cavo" virtuale con due estremità
ip link set v1 netns prova                               # una va nel namespace
ip addr add 10.99.0.1/24 dev v0;  ip link set v0 up
ip netns exec prova ip addr add 10.99.0.2/24 dev v1;  ip netns exec prova ip link set v1 up
ip netns exec prova ping -c1 -W1 10.99.0.1
# 1 packets transmitted, 1 received, 0% packet loss
```
Un namespace ha **la sua** rete (interfacce, rotte, porte): `ip netns exec prova COMANDO` lancia un comando là dentro (anche `ip -n prova ...`). Una coppia `veth` è un cavo: i pacchetti che entrano da un'estremità escono dall'altra. Per togliere tutto: `ip netns del prova` (porta via `v1`, e quindi anche `v0`).
</details>

## `/etc/hosts` ([02-diagnostica.md](02-diagnostica.md))
**8.** Fai in modo che il nome **`sito.lab`** risolva a `10.10.2.10`, **senza** DNS. *(Cambia la rete: `getent hosts sito.lab`.)*
<details><summary>soluzione</summary>

```bash
echo "10.10.2.10 sito.lab" >> /etc/hosts
getent hosts sito.lab
# 10.10.2.10      sito.lab
```
`getent hosts` passa dalla stessa risoluzione dei programmi (file `/etc/hosts` poi DNS, secondo `nsswitch.conf`): `dig` e `nslookup` **non** leggono `/etc/hosts`.
Nel container `/etc/hosts` è un file **montato da Docker**: per toglierla `sed -i` fallisce con `sed: cannot rename /etc/sedXXXX: Device or resource busy`, perché sostituisce il file; si riscrive il contenuto sul posto (`grep -v sito.lab /etc/hosts > /tmp/h; cat /tmp/h > /etc/hosts`).
</details>

## Diagnostica ([02-diagnostica.md](02-diagnostica.md))
**9.** Qual è il **primo salto** (il router) per arrivare a `web`? (solo l'indirizzo)
<details><summary>soluzione</summary>

```bash
traceroute -n web | awk 'NR == 2 {print $2}'
# 10.10.1.254
```
`traceroute -n` non risolve i nomi (più veloce). La prima riga è l'intestazione, la seconda è il salto 1: la seconda colonna è l'indirizzo.
Attenzione: oltre al primo salto l'output **non è stabile** nel laboratorio: in una prova il salto successivo comparve come `* * *` per cinque righe e il numero di righe passò da 2 a 7 (la causa non è stata indagata). Per questo non c'è un esercizio sul numero di salti.
</details>

**10.** Quali **porte TCP fra la 20 e la 25** sono aperte su `web`? (i numeri, uno per riga)
<details><summary>soluzione</summary>

```bash
nc -zv -w1 web 20-25 2>&1 | grep succeeded | awk '{print $5}'
# 22
nc -zv -w1 web 20-25
# nc: connect to web (10.10.2.10) port 20 (tcp) failed: Connection refused
# ...
# Connection to web (10.10.2.10) 22 port [tcp/ssh] succeeded!
```
`nc -z` prova la connessione senza inviare dati, `-v` stampa l'esito, `-w1` al massimo un secondo per porta. Su `web` c'è solo ssh: le altre rispondono `Connection refused` (nessuno ascolta); un firewall che scarta i pacchetti darebbe invece un **timeout** ([02-diagnostica.md](02-diagnostica.md)).
</details>

**11.** Il **corpo** della risposta HTTP di `http://web/`. (una riga)
<details><summary>soluzione</summary>

```bash
curl -s http://web/
# risposta da web
```
</details>

**12.** Il **codice di stato HTTP** che `http://web/nonesiste` restituisce. (un numero)
<details><summary>soluzione</summary>

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://web/nonesiste
# 404
```
`-s` toglie la barra di avanzamento, `-o /dev/null` scarta il corpo, `-w` stampa un campo scelto. Per la prima riga di stato: `curl -sI URL | head -1`. Vedi [../09-strumenti/01-jq-e-curl.md](../09-strumenti/01-jq-e-curl.md).
</details>

**13.** Con `nmap -sn` (solo «chi risponde», senza scansione delle porte), **quanti host** rispondono nell'intervallo `10.10.1.10-12`? (un numero)
<details><summary>soluzione</summary>

```bash
nmap -sn 10.10.1.10-12 | sed -n 's/.*(\([0-9]*\) hosts\? up).*/\1/p'
# 2
nmap -sn 10.10.1.10-12
# Nmap scan report for host (10.10.1.10)
# Host is up.
# Nmap scan report for lab-10-host2-1.lab-10_lan (10.10.1.11)
# Host is up (0.000024s latency).
# MAC Address: 0E:4F:55:F8:2A:FC (Unknown)
# Nmap done: 3 IP addresses (2 hosts up) scanned in 1.31 seconds
```
`.10` è `host` stesso, `.11` è `host2`, `.12` non esiste. L'intervallo è piccolo apposta: `nmap -sn 10.10.1.0/24` scandisce 256 indirizzi e nel laboratorio impiega circa 15 secondi, per lo più ad aspettare gli indirizzi che non rispondono.
</details>

## nginx ([04-apache-nginx.md](04-apache-nginx.md))
**15.** Crea un **virtual host** di nginx sulla porta **8081** che serve la cartella `/var/www/miosito`, con un `index.html` che contiene `ciao dal sito`, e **ricarica** nginx. *(Cambia la rete: `curl localhost:8081`.)*
<details><summary>soluzione</summary>

```bash
mkdir -p /var/www/miosito
echo "ciao dal sito" > /var/www/miosito/index.html
cat > /etc/nginx/conf.d/miosito.conf << 'EOF'
server {
    listen 8081;
    root /var/www/miosito;
}
EOF
nginx -t && systemctl reload nginx            # prima si controlla la sintassi, poi si ricarica
curl -s http://localhost:8081/
# ciao dal sito
```
La configurazione può stare in `conf.d/` o in `sites-available/` con un collegamento in `sites-enabled/`: tutte e due sono incluse da `nginx.conf`. **Senza il reload** la porta 8081 non esiste: nginx legge i file solo all'avvio e a `reload`, e `curl` dà `Connection refused` (codice 7).
</details>

**16.** Un **reverse proxy**: nginx in ascolto sulla porta **8082** che inoltra tutto a `http://web/`. *(Cambia la rete: `curl localhost:8082` deve rispondere come `web`.)*
<details><summary>soluzione</summary>

```bash
cat > /etc/nginx/conf.d/proxy.conf << 'EOF'
server {
    listen 8082;
    location / {
        proxy_pass http://web/;
    }
}
EOF
nginx -t && systemctl reload nginx
curl -s http://localhost:8082/
# risposta da web
```
`proxy_pass` inoltra la richiesta al server indicato e restituisce la sua risposta. Un indirizzo (`http://10.10.2.10`) funziona come il nome. Con più `server` dietro un `upstream { ... }` diventa un **load balancer** ([05-load-balancer/](05-load-balancer/)).
</details>

## Se non sai da dove cominciare
| Devi... | Comando |
|---|---|
| calcolare rete, broadcast, maschera | `ipcalc INDIRIZZO/PREFISSO`; ospiti = 2^(32-prefisso) − 2 |
| vedere o cambiare indirizzi, MTU, rotte | `ip addr`, `ip link set dev eth0 mtu N`, `ip route add RETE via GW` |
| un namespace con la sua rete | `ip netns add`, `ip link add ... type veth peer name ...`, `ip netns exec NS COMANDO` |
| un nome senza DNS | una riga in `/etc/hosts`, verificata con `getent hosts` |
| il percorso e dove si ferma | `traceroute -n HOST`, `mtr -rw HOST` |
| una porta è aperta? | `nc -zv -w1 HOST PORTE`, `ss -ltn` (in locale) |
| HTTP da riga di comando | `curl -s URL`, `-I` (intestazioni), `-w '%{http_code}'` |
| chi risponde in una rete | `nmap -sn RETE` |
| un sito o un proxy con nginx | un `server { listen PORTA; ... }` in `conf.d/`, `nginx -t`, `systemctl reload nginx` |

Torna all'[indice dell'area](README.md)
