# VPN con WireGuard

> **Laboratorio**: `./lab.sh 08`, poi `cd 04-vpn-wireguard`. Cosa contiene: [lab/](lab/).

Un tunnel SSH ([01-ssh.md](01-ssh.md)) porta **una** porta, o con `-D` il traffico di **una** applicazione. Una **VPN** (*virtual private
network*) crea invece un'interfaccia di rete in più, cifrata, che collega due macchine come se fossero sulla stessa rete: funzionano
`ping`, `ssh`, database e qualsiasi programma, senza configurarli uno per uno. **WireGuard** è la VPN più semplice da configurare: sta nel
kernel Linux da 5.6, usa un solo protocollo UDP, e la configurazione di un lato sono una decina di righe.

| | tunnel SSH (`-L`, `-D`) | WireGuard | OpenVPN |
|---|---|---|---|
| cosa instrada | una porta, o un proxy SOCKS | **tutta la rete**, per qualunque programma | tutta la rete |
| installazione | niente (c'è `sshd`) | un pacchetto, e il kernel | un pacchetto, più certificati |
| configurazione | una riga di comando | un file da ~10 righe per lato | file più lunghi, di solito una CA |
| uso tipico | l'accesso di un momento a un database | collegare PC e server, o due sedi | VPN aziendali con molti utenti e certificati |

Gli esempi sotto sono stati eseguiti nel laboratorio dell'area 08. Di OpenVPN qui non c'è niente: è citato solo per confronto.

## Come funziona
- non ci sono "server" e "client" nel protocollo: ci sono **peer** che si parlano. Chi ha un indirizzo raggiungibile (`Endpoint`) ascolta, chi sta
  dietro un NAT o cambia indirizzo si collega a lui
- ogni peer ha una coppia di chiavi: la **privata** non lascia mai la macchina, la **pubblica** si dà agli altri (si comporta come le chiavi SSH)
- ogni peer ha un **indirizzo VPN** (qui `10.8.0.1`, `10.8.0.2`...) nella sua interfaccia `wg0`
- **`AllowedIPs`** fa due cose insieme: è la *tabella di instradamento* (verso quali indirizzi mando il traffico dentro il tunnel verso questo peer) e il
  *filtro in ingresso* (da quali indirizzi accetto pacchetti da lui)
- l'**handshake** avviene da solo, al primo pacchetto, e si rinnova ogni pochi minuti. Un tunnel senza traffico non invia nulla

## Il laboratorio
`./lab.sh 08` ha già le reti giuste: il `client` (il "PC") vede `produzione`, ma **non** `db-interno`, che sta solo sulla rete interna.
L'obiettivo è raggiungere `db-interno` dal client attraverso una VPN verso `produzione`.

| Macchina | Rete esterna | Rete interna | Ruolo |
|---|---|---|---|
| `client` | `10.20.1.5` | | il peer che si collega |
| `produzione` | `10.20.1.10` | `10.20.2.10` | il peer con `Endpoint`, anche router verso la rete interna |
| `staging` | `10.20.1.30` | | non serve qui |
| `db-interno` | | `10.20.2.20` | un nginx che risponde `risposta da db-interno` |
| VPN | | | `10.8.0.0/24`: `produzione` è `10.8.0.1`, il `client` è `10.8.0.2` |

Nel laboratorio lavori come `root` sul client; su `produzione` si entra con `ssh edoardo@produzione` (password `edoardo`, ha `sudo`).
```bash
ping -c1 -W1 10.20.2.20          # prima della VPN: 1 packets transmitted, 0 received, 100% packet loss
```

## Installazione e chiavi
```bash
sudo apt install wireguard-tools          # i comandi wg e wg-quick; il modulo è già nel kernel di Ubuntu
wg --version                              # wireguard-tools v1.0.20210914
```
Le chiavi si generano su **ogni** macchina, dove devono restare (le private):
```bash
umask 077                                 # i file nuovi saranno leggibili solo dal proprietario
mkdir -p /etc/wireguard && cd /etc/wireguard
wg genkey | tee server.key | wg pubkey > server.pub          # la privata in server.key, la pubblica in server.pub
ls -l
# -rw------- 1 root root 45 Oct  5 12:15 server.key
# -rw------- 1 root root 45 Oct  5 12:15 server.pub
cat server.pub                            # KqPUAiPqNGw7Mcm+Kgj55VbhRP84qUdRrUl5WUv5cik=   <- questa si può comunicare
```
Sul client lo stesso, con `client.key` e `client.pub`. **Si scambiano solo le chiavi pubbliche**, per un canale qualsiasi (anche una chat): sono
pubbliche. Una chiave privata che finisce in un repository o in una mail va rigenerata.

## Il peer che ascolta (produzione)
Prima di tutto `produzione` deve **inoltrare** pacchetti fra la VPN e la rete interna: è un router (nel laboratorio lo imposta già il compose; su un server vero
`sysctl -w net.ipv4.ip_forward=1`, e in `/etc/sysctl.d/` per renderlo permanente).
```bash
sysctl net.ipv4.ip_forward                # net.ipv4.ip_forward = 1
```
`/etc/wireguard/wg0.conf` (il nome del file è il nome dell'interfaccia):
```ini
[Interface]
Address = 10.8.0.1/24                     # l'indirizzo di produzione dentro la VPN
ListenPort = 51820                        # porta UDP su cui ascolta
PrivateKey = <contenuto di server.key>
# i pacchetti del client verso la rete interna escono con l'indirizzo di produzione (NAT): db-interno non conosce 10.8.0.0/24
PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -o wg0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 ! -o wg0 -j MASQUERADE

[Peer]
# client
PublicKey = <contenuto di client.pub>
AllowedIPs = 10.8.0.2/32                  # da questo peer accetto solo pacchetti con quell'indirizzo VPN
```
```bash
chmod 600 /etc/wireguard/wg0.conf         # contiene la chiave privata
wg-quick up wg0
# [#] ip link add wg0 type wireguard
# [#] wg setconf wg0 /dev/fd/63
# [#] ip -4 address add 10.8.0.1/24 dev wg0
# [#] ip link set mtu 1420 up dev wg0
# [#] iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -o wg0 -j MASQUERADE
wg show
# interface: wg0
#   public key: KqPUAiPqNGw7Mcm+Kgj55VbhRP84qUdRrUl5WUv5cik=
#   private key: (hidden)
#   listening port: 51820
# peer: UF8PJbgUzmbauA5RX/ytXcNr8/uUV7If/9TNlXPkJHY=
#   allowed ips: 10.8.0.2/32
```
`wg-quick` è lo script che legge il `.conf` e fa i comandi `ip` al posto tuo (li stampa con `[#]`). Il peer non ha ancora un `endpoint` né un
`handshake`: il client non si è ancora fatto vivo.

## Il peer che si collega (client)
```ini
[Interface]
Address = 10.8.0.2/24
PrivateKey = <contenuto di client.key>

[Peer]
# produzione
PublicKey = <contenuto di server.pub>
Endpoint = produzione:51820               # dove trovarlo: nome o IP, e porta UDP
AllowedIPs = 10.8.0.0/24, 10.20.2.0/24    # verso la VPN e verso la rete interna di produzione: il traffico a questi indirizzi va nel tunnel
PersistentKeepalive = 25                  # un pacchetto ogni 25 s: tiene aperto il NAT. Serve a chi sta dietro un router
```
```bash
chmod 600 /etc/wireguard/wg0.conf
wg-quick up wg0
# [#] ip link add wg0 type wireguard
# [#] wg setconf wg0 /dev/fd/63
# [#] ip -4 address add 10.8.0.2/24 dev wg0
# [#] ip link set mtu 1420 up dev wg0
# [#] ip -4 route add 10.20.2.0/24 dev wg0                  <- da AllowedIPs: la rotta verso la rete interna passa per wg0
wg show
# peer: KqPUAiPqNGw7Mcm+Kgj55VbhRP84qUdRrUl5WUv5cik=
#   endpoint: 10.20.1.10:51820
#   allowed ips: 10.8.0.0/24, 10.20.2.0/24
#   latest handshake: Now
#   transfer: 92 B received, 180 B sent
#   persistent keepalive: every 25 seconds
```
`latest handshake: Now` è la prova che i due peer si sono trovati e le chiavi sono giuste. Ora funziona:
```bash
ping -c2 10.8.0.1                         # 2 received: l'altro capo del tunnel
ping -c2 10.20.2.20                       # 2 received: db-interno, che prima non si raggiungeva
curl http://10.20.2.20/                   # risposta da db-interno
wg show wg0 | grep -E 'handshake|transfer'
#   latest handshake: 3 seconds ago
#   transfer: 1.21 KiB received, 1.30 KiB sent
```

> **ATTENZIONE**: un'inversione tipica. `Address` sull'interfaccia è l'indirizzo **del peer stesso**, `AllowedIPs` nel `[Peer]` è l'indirizzo **dell'altro**. Se il
> `PublicKey` di un peer è vuoto (la variabile non è stata riempita), `wg-quick` risponde `Line unrecognized: `PublicKey='` / `Configuration parsing error`.

### I pacchetti sono davvero cifrati?
`tcpdump` su `produzione` guarda lo stesso traffico da due lati: sull'interfaccia fisica (cosa vede la rete) e dentro il tunnel:
```bash
tcpdump -ni eth0 -c 3 udp port 51820      # FUORI dal tunnel: solo UDP verso la 51820, il contenuto è illeggibile
# 12:14:08.616205 IP 10.20.1.5.34857 > 10.20.1.10.51820: UDP, length 128
# 12:14:08.616341 IP 10.20.1.10.51820 > 10.20.1.5.34857: UDP, length 128
tcpdump -ni wg0 -c 2 icmp                 # DENTRO: il traffico in chiaro, com'era
# 12:14:08.616233 IP 10.8.0.2 > 10.20.2.20: ICMP echo request, id 7, seq 1, length 64
# 12:14:08.616293 IP 10.20.2.20 > 10.8.0.2: ICMP echo reply, id 7, seq 1, length 64
```
Chi sta in mezzo vede solo pacchetti UDP da 128 byte fra due indirizzi: non sa che dentro c'è un `ping` verso `db-interno`.

## Avviarlo da solo: systemd
```bash
wg-quick down wg0
systemctl enable --now wg-quick@wg0       # una unit per ogni interfaccia: legge /etc/wireguard/wg0.conf
systemctl is-active wg-quick@wg0          # active
```
Dopo un riavvio dell'interfaccia il primo pacchetto può andare perso, finché non si rifà l'handshake: nel laboratorio il primo `ping` subito dopo
non ha risposto, il tunnel era di nuovo vivo qualche secondo dopo (`latest handshake: 13 seconds ago`). Con `PersistentKeepalive` succede da solo.

## Il firewall
Due regole, entrambe da non dimenticare:
```bash
ufw allow 51820/udp                       # la porta di WireGuard deve poter ricevere (e già sshd: ufw allow OpenSSH)
ufw route allow in on wg0 to 10.20.2.0/24 # E il router deve lasciar passare i pacchetti della VPN verso la rete interna
```
La seconda è la dimenticanza più frequente. `ufw` ha una policy a parte per i pacchetti **inoltrati** (non diretti al server stesso), e per default è `deny`:
```bash
ufw status verbose | grep -i default
# Default: deny (incoming), allow (outgoing), deny (routed)         <- "routed" sono i pacchetti inoltrati
curl -s --max-time 3 http://10.20.2.20/    # dal client: nessuna risposta (rc=28), pur con handshake attivo e il ping al peer funzionante
ufw route allow in on wg0 to 10.20.2.0/24
ufw status | tail -3                       # 10.20.2.0/24               ALLOW FWD   Anywhere on wg0
curl -s --max-time 3 http://10.20.2.20/    # risposta da db-interno
```
Il sintomo ingannevole: il tunnel è su, l'handshake c'è, il ping a `10.8.0.1` risponde (è diretto a `produzione`), ma le connessioni verso la rete interna scadono.
(Il `ping` verso `db-interno` può funzionare lo stesso: `ufw` lascia passare gli ICMP inoltrati. Per la prova serve una connessione TCP.)

## Più client, e togliere un accesso
Ogni client è un `[Peer]` in più sul server, con il **suo** indirizzo VPN:
```ini
[Peer]
# portatile di Anna
PublicKey = <la sua chiave pubblica>
AllowedIPs = 10.8.0.3/32
```
Senza riavviare il tunnel (e senza interrompere gli altri):
```bash
wg set wg0 peer <PUBKEY-DI-ANNA> allowed-ips 10.8.0.3/32     # aggiunge un peer a caldo (non scrive il file!)
wg-quick save wg0                                            # scrive nel .conf lo stato attuale (il peer aggiunto compare come nuova sezione [Peer])
wg set wg0 peer <PUBKEY-DI-ANNA> remove                      # lo toglie: da questo momento non entra più
```
Prova della revoca, con il client in `ping` sul server: dopo il `remove` sul server, `ping -c2 -W1 10.8.0.1` dal client risponde `2 packets transmitted,
0 received, 100% packet loss`. L'handshake non può più riuscire: il server non conosce più quella chiave. Perdere un portatile non richiede di cambiare
niente agli altri: si toglie il suo peer.

### Una chiave in più: la preshared key
Opzionale, aggiunge uno strato di cifratura simmetrica (utile in prospettiva contro attacchi quantistici). Si genera una volta e si mette **uguale** nei due `[Peer]`:
```bash
wg genpsk                                                  # 44 caratteri base64
wg set wg0 peer <PUBKEY-DELL-ALTRO> preshared-key <(wg genpsk)    # a caldo; per il file: PresharedKey = ... nel [Peer]
wg show wg0 | grep -E 'preshared|handshake'
#   preshared key: (hidden)
#   latest handshake: 16 seconds ago
```
`wg showconf wg0` stampa la configurazione attuale, **con le chiavi private**: non va incollata in una chat.

## Tutto il traffico nel tunnel
Con `AllowedIPs = 0.0.0.0/0` sul client, **ogni** pacchetto passa dalla VPN (VPN "full tunnel", come per una rete pubblica o un hotel). Con gli indirizzi
della sola rete interna (come sopra) è uno **split tunnel**: solo quel traffico passa dal peer.
```bash
sed -i 's|^AllowedIPs = .*|AllowedIPs = 0.0.0.0/0|' /etc/wireguard/wg0.conf
wg-quick down wg0; wg-quick up wg0
# [#] wg set wg0 fwmark 51820
# [#] ip -4 rule add not fwmark 51820 table 51820
# [#] ip -4 rule add table main suppress_prefixlength 0
# [#] ip -4 route add 0.0.0.0/0 dev wg0 table 51820
# [#] sysctl -q net.ipv4.conf.all.src_valid_mark=1
ip route get 8.8.8.8                       # 8.8.8.8 dev wg0 table 51820 src 10.8.0.2   <- prima: via 10.20.1.1 dev eth0
wg-quick down wg0
ip route get 8.8.8.8                       # 8.8.8.8 via 10.20.1.1 dev eth0 src 10.20.1.5   <- tutto com'era
```
`wg-quick` non tocca la rotta predefinita: usa una **tabella di routing separata** (51820) e una regola che esclude i pacchetti di WireGuard stesso (`fwmark`), per non farli
rientrare nel tunnel. In un container vedi `sysctl: setting key "net.ipv4.conf.all.src_valid_mark", ignoring: Read-only file system`: `/proc/sys` è in sola lettura, il
messaggio dice "ignoring" e il tunnel funziona lo stesso. Perché internet passi davvero dal peer, questo deve a sua volta fare NAT verso l'uscita (`MASQUERADE` su `eth0`)
e inoltrare: nel laboratorio non c'è internet, quindi ho provato solo la rotta e il traffico verso `db-interno`.

Sul client Linux con `systemd-resolved` si può aggiungere `DNS = 10.8.0.1` all'`[Interface]`, che `wg-quick` imposta con `resolvconf` (non provato qui: nel container non c'è).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `wg show` non mostra `latest handshake` | i peer non si trovano: chiave sbagliata, porta chiusa, `Endpoint` errato | controllare che le **pubbliche** siano quelle giuste (incrociate), `ufw allow 51820/udp`, `tcpdump -ni eth0 udp port 51820` sul server: se non arriva niente è la rete, se arriva ed è senza risposta sono le chiavi |
| handshake ok, ma il `ping` al peer fallisce | `AllowedIPs` non include l'indirizzo VPN dell'altro | controllare i due `AllowedIPs` e `ip route` |
| ping al peer ok, ma la rete oltre di lui no | manca `ip_forward`, NAT o la regola `ufw route` | `sysctl net.ipv4.ip_forward`, il `MASQUERADE`, `ufw route allow in on wg0 ...` |
| `Line unrecognized: ...` o `Configuration parsing error` | chiave vuota o riga fuori da `[Interface]`/`[Peer]` | aprire il `.conf`: ogni valore deve essere pieno |
| `RTNETLINK answers: Operation not supported` | il kernel non ha WireGuard | `modprobe wireguard`, oppure il kernel è troppo vecchio (< 5.6): usare `wireguard-go` |
| `RTNETLINK answers: Operation not permitted` in un container | manca `CAP_NET_ADMIN` | `cap_add: [NET_ADMIN]` (il compose del laboratorio lo ha) |
| funziona e dopo un po' smette (dietro un NAT) | il router chiude la sessione UDP inattiva | `PersistentKeepalive = 25` sul peer dietro NAT |
| pagine lente o che si bloccano a metà | MTU troppo alta (di default 1420) | `MTU = 1380` nell'`[Interface]` e riprovare |
| due client con lo stesso indirizzo VPN | lo stesso `AllowedIPs` su due peer: `wg show wg0 allowed-ips` mostra `(none)` per il primo e l'indirizzo solo per l'ultimo | un indirizzo VPN diverso per ogni peer |
