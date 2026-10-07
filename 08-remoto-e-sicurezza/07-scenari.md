# Scenari guidati: non riesco a entrare, e ora?

> **Laboratorio**: `./lab.sh 08`, poi `cd 07-scenari`. Qui non si prova un comando: **c'è un guasto vero** fra il `client` e i tre server, da diagnosticare e riparare (vedi [lab/](lab/)).

Gli [esercizi](06-esercizi.md) dicono cosa fare; qui c'è solo un **sintomo**, come lo racconta un collega, e la causa va trovata. Sono otto guasti diversi, uno per volta:
una chiave con i permessi sbagliati, una porta sbagliata nel `config`, l'avviso di "attacco" per una chiave del server cambiata, una cartella `.ssh` troppo aperta **sul server**, un `ProxyJump` che punta al posto sbagliato,
un firewall che blocca il sito ma non ssh, un client **bannato** da `fail2ban` e un messaggio cifrato che non si apre. Gli strumenti sono quelli di [ssh](01-ssh.md), [firewall e hardening](02-firewall-e-hardening.md) e [gpg](03-gpg.md).

## Come si lavora
```bash
cd ~/lab/07-scenari
./scenari.sh guasta 4          # porta tutto in salute, rompe come lo scenario 4 e stampa il "ticket" (il sintomo)
# ...diagnosi e riparazione, con quello che vuoi...
./scenari.sh controlla         # dice se il sintomo è sparito; non rivela la causa
./scenari.sh ripristina        # toglie ogni guasto (anche se ti sei perso)
```
- `controlla` guarda **il sintomo**, non il comando che hai usato: vale qualunque riparazione che funzioni davvero. Entra con la chiave, in `BatchMode` (niente password) e con la verifica della chiave del server **attiva**: aggirare un avviso con `StrictHostKeyChecking=no` non vale.
- `scenari.sh` **non va aperto** prima di aver provato: contiene i guasti. Ogni scenario ha un suggerimento e la soluzione, nascosti.
- Ogni `guasta N` riparte da una base sana: una **chiave nuova** dello studente (`~/.ssh/id_ed25519`), autorizzata per l'utente `deploy` sui tre server, un `~/.ssh/config` con `produzione`, `staging` e `db-interno` (via `ProxyJump produzione`) e i server già in `known_hosts`. Si lavora da `client`, come `deploy`.
- Ai server si può accedere anche con le **password** del laboratorio: `deploy` / `deploy` (senza sudo) ed `edoardo` / `edoardo` (con sudo). Servono quando la chiave non entra: sono la porta di servizio. `ssh -o PreferredAuthentications=password edoardo@produzione` le forza.
- Il banco di prova tocca i server con una sua chiave (in `/root/.scenari`), che non interferisce con la tua.
- Gli scenari si fanno in qualunque ordine. Ogni `guasta N` richiede qualche secondo (prepara tre server). Se un tentativo peggiora le cose: `./scenari.sh guasta N` riparte da zero.

## Il metodo: da `ssh -v` ai log del server
Quando "non riesco a entrare", si guarda **in che punto** la conversazione si ferma. `ssh -v` (e `-vv`, `-vvv`) la racconta passo passo:

| Fino a dove arriva | Cosa dice | Dove cercare |
|---|---|---|
| non si connette (`Connection refused`, `timed out`) | rete, porta o firewall | `ssh -G HOST` (host e porta che `ssh` usa davvero), `nc -zv -w2 HOST PORTA`, un altro percorso (`ssh -J ...`) |
| si connette ma si rifiuta (`REMOTE HOST IDENTIFICATION HAS CHANGED`) | la chiave del **server** non è quella nota | `known_hosts`, `ssh-keygen -lf`, `ssh-keyscan` |
| il server c'è ma chiede la password / `Permission denied (publickey...)` | la tua chiave non viene accettata | **client**: chiave, permessi, `-v` ("Offering public key"); **server**: `journalctl -u ssh`, permessi di `~/.ssh` |
| si entra, ma un servizio no | firewall o servizio | `ufw status`, `ss -ltn`, `nc -zv` sulla porta |

Tre regole che valgono sempre: **leggi il messaggio per intero** (spesso dice cosa non va), **`ssh -G`** mostra la configurazione che `ssh` applica davvero (utile quando il `config` è lungo), e **il log del server** (`journalctl -u ssh`) sa sempre qualcosa che il client non può sapere.

---

## 1. Oggi chiede la password
**Ticket**: *`ssh produzione` ieri entrava da solo con la chiave. Oggi chiede la password.*

<details><summary>da dove cominciare</summary>

Rilancia con `ssh -v` e leggi **tutto**, prima ancora di arrivare alla richiesta della password. Qualcosa sulla chiave non va.
</details>
<details><summary>soluzione</summary>

```bash
ssh produzione true                              # avviso a tutto schermo, poi la richiesta della password
# @         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
# Permissions 0644 for '/root/.ssh/id_ed25519' are too open.
# This private key will be ignored.
# Load key "/root/.ssh/id_ed25519": bad permissions
# deploy@produzione: Permission denied (publickey,password).
ls -l ~/.ssh/id_ed25519
# -rw-r--r-- 1 root root 399 Oct  7 05:47 /root/.ssh/id_ed25519
```
La chiave privata è leggibile da tutti (`0644`): `ssh` la **ignora** (non si fida di una chiave che altri potrebbero aver letto) e passa al metodo dopo, la password. Il messaggio c'era già, prima della richiesta. Si restringe il permesso:
```bash
chmod 600 ~/.ssh/id_ed25519
ssh -o BatchMode=yes produzione hostname
# produzione
```
`ssh` accetta **solo** `600` (o `400`): `640`, dove il gruppo può leggere, non basta, e `controlla` lo verifica. Cartella `~/.ssh` a `700`, `authorized_keys` a `600`: sono i permessi di [02-file/08-permessi](../02-file-e-permessi/08-permessi.md) applicati alle chiavi.
</details>

## 2. `Connection refused`, ma il server è acceso
**Ticket**: *`ssh produzione` risponde "Connection refused", ma il server è acceso e gli altri colleghi ci entrano.*

<details><summary>da dove cominciare</summary>

`ssh -G produzione` dice a **quale porta** sta provando davvero. Poi confrontala con quella su cui il server ascolta.
</details>
<details><summary>soluzione</summary>

```bash
ssh -o BatchMode=yes produzione true
# ssh: connect to host produzione port 2222: Connection refused       <- porta 2222: non è quella di ssh
ssh -G produzione | grep -E '^(hostname|port|user) '    # la configurazione effettiva: host, porta e utente che ssh userà
# user deploy
# hostname produzione
# port 2222
grep -n -A3 'Host produzione' ~/.ssh/config
# 1:Host produzione
# 2-    Port 2222
# 3-    HostName produzione
# 4-    User deploy
nc -zv -w2 produzione 22; nc -zv -w2 produzione 2222    # il server ascolta sulla 22, non sulla 2222
# Connection to produzione (10.20.1.10) 22 port [tcp/ssh] succeeded!
# nc: connect to produzione (10.20.1.10) port 2222 (tcp) failed: Connection refused
```
Nel `config` c'è una riga `Port 2222` di troppo (un'altra volta, per un altro server). `refused` dice che la macchina c'è e risponde, ma su quella porta **non ascolta nessuno**: se il server fosse spento o filtrato sarebbe stato `timed out` (come nello scenario 7). Si toglie la riga:
```bash
sed -i '/^    Port 2222$/d' ~/.ssh/config
ssh -o BatchMode=yes produzione hostname
# produzione
```
Provare `ssh -p 22 produzione` a mano **funziona**, ma lascia il `config` rotto: `controlla` prova `ssh produzione` e basta.
</details>

## 3. "SOMEONE IS DOING SOMETHING NASTY"
**Ticket**: *`ssh produzione` si rifiuta di collegarsi e parla di un attacco. Ieri funzionava.*

<details><summary>da dove cominciare</summary>

Non è un errore da aggirare: `ssh` dice che la chiave che il server presenta **non è quella che conosci**. Confronta le due impronte, quella memorizzata e quella che il server offre adesso, e poi decidi.
</details>
<details><summary>soluzione</summary>

```bash
ssh -o BatchMode=yes produzione true
# @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
# IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
# The fingerprint for the ED25519 key sent by the remote host is
# SHA256:3bbi4ViqWNnoWU/2GcCjBj6NlaNmGyxou63z7F9BgS0.
# Offending ED25519 key in /root/.ssh/known_hosts:3
ssh-keygen -lf ~/.ssh/known_hosts -F produzione          # l'impronta che avevi memorizzato
# produzione ED25519 SHA256:EZosIv+3hC34C4QQkeE6amWnh4/0jwf9lu6OPwYwe6E
ssh-keyscan -t ed25519 produzione 2>/dev/null | ssh-keygen -lf -      # quella che il server offre adesso
# 256 SHA256:3bbi4ViqWNnoWU/2GcCjBj6NlaNmGyxou63z7F9BgS0 produzione (ED25519)
```
(Le impronte cambiano a ogni avvio del laboratorio.) Sono **diverse**. Può essere un attacco (qualcuno si finge il server) o un'innocente reinstallazione del server: **non si decide a occhio**. In un caso vero si confronta l'impronta con quella che dà **chi amministra il server** (o la console del provider), non con quella offerta dal server stesso. Quando è confermata, si toglie la riga vecchia e si impara la nuova:
```bash
ssh-keygen -R produzione                       # toglie la voce vecchia (e salva known_hosts.old)
ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes produzione hostname     # oppure: ssh produzione e rispondere "yes" dopo aver confrontato l'impronta
# Warning: Permanently added 'produzione' (ED25519) to the list of known hosts.
# produzione
```
`StrictHostKeyChecking=no` (o `UserKnownHostsFile=/dev/null`) fa entrare lo stesso, **ma ignora l'avviso**, e `controlla` non lo accetta: disattiva proprio il controllo che ti protegge dall'attacco di cui l'avviso parla.
</details>

## 4. Chiede la password, e sul client è tutto a posto
**Ticket**: *`ssh produzione` chiede la password da stamattina, ma la chiave non è cambiata e sul tuo computer non hai toccato nulla.*

<details><summary>da dove cominciare</summary>

Sul client la chiave c'è e viene offerta (`ssh -v`): se il server la rifiuta, il motivo sta **sul server**, nel suo log. Entra con la password (la porta di servizio: `deploy` / `deploy`) e guarda i permessi di `~/.ssh`; per il log di sshd serve `sudo`, quindi `edoardo`.
</details>
<details><summary>soluzione</summary>

```bash
ssh -v -o BatchMode=yes produzione true 2>&1 | grep -iE 'offering|authentications|denied'
# debug1: Authentications that can continue: publickey,password
# debug1: Offering public key: /root/.ssh/id_ed25519 ED25519 SHA256:ZKrLknSqfQOiBi2jbDI1NIPb9TSOWgq4fUflHzHgWmM
# debug1: Authentications that can continue: publickey,password          <- l'ha offerta e il server non l'ha accettata, senza dire perché
# deploy@produzione: Permission denied (publickey,password).
```
Il client ha fatto il suo: ha offerto la chiave giusta. Il server non dice perché la rifiuta (è una scelta di sicurezza: non spiegare a chi è fuori). Il motivo sta nel suo **log**, accessibile con `edoardo` (che ha `sudo`):
```bash
ssh -o PreferredAuthentications=password edoardo@produzione 'sudo journalctl -u ssh --no-pager | grep -i refused | tail -2'
# Oct 07 05:28:50 produzione sshd[602]: Authentication refused: bad ownership or modes for directory /home/deploy/.ssh
ssh -o PreferredAuthentications=password deploy@produzione 'ls -ld ~/.ssh'          # password: deploy
# drwxrwxrwx 2 deploy deploy 4096 Oct  7 05:28 /home/deploy/.ssh
```
`sshd` con `StrictModes` (predefinito) rifiuta le chiavi autorizzate se la cartella `~/.ssh` può essere **modificata da altri**: chiunque potrebbe aggiungerne una. La cartella è `777`: si riporta a `700`.
```bash
ssh -o PreferredAuthentications=password deploy@produzione 'chmod 700 ~/.ssh'
ssh -o BatchMode=yes produzione hostname
# produzione
```
Riscrivere la chiave con `ssh-copy-id` non serve: la chiave era già lì e giusta, a essere sbagliato era il permesso della cartella (e `controlla` lo verifica).
</details>

## 5. Il database dietro il bastion non si apre
**Ticket**: *`ssh db-interno` (il database, dietro il bastion) non si apre più. Il collega dice che ieri ci entrava.*

<details><summary>da dove cominciare</summary>

`db-interno` si raggiunge solo **attraverso** un altro server (`ProxyJump`). Guarda con `ssh -G` quale, e chiediti se quel server vede il database.
</details>
<details><summary>soluzione</summary>

```bash
ssh -o BatchMode=yes db-interno hostname
# channel 0: open failed: connect failed: Name or service not known
# stdio forwarding failed
ssh -G db-interno | grep -E '^(hostname|user|proxyjump) '
# user deploy
# hostname db-interno
# proxyjump staging                              <- il salto passa da staging
ssh staging 'getent hosts db-interno; echo rc=$?'      # staging conosce db-interno?
# rc=2                                           <- no: non lo risolve
ssh produzione 'getent hosts db-interno'               # produzione sì (è sulla rete interna)
# 10.20.2.20      db-interno
```
`db-interno` sta solo sulla rete interna, e solo `produzione` è su **entrambe** le reti: il salto deve passare da lì. Nel `config` il `ProxyJump` punta a `staging`, che non lo vede: `open failed ... Name or service not known` è l'errore del **salto**, non del database (il nome viene risolto dal server di mezzo). Si corregge:
```bash
sed -i 's/^    ProxyJump staging$/    ProxyJump produzione/' ~/.ssh/config
ssh -o BatchMode=yes db-interno hostname
# db-interno
```
Togliere del tutto il `ProxyJump` non è una soluzione: dal client `db-interno` non si raggiunge direttamente (non è nemmeno nella sua rete).
</details>

## 6. Il sito non risponde, ssh sì
**Ticket**: *Il sito su staging (`http://staging/`) non risponde più da questo computer. Via ssh, però, ci si entra.*

<details><summary>da dove cominciare</summary>

Prova due porte di `staging`, la 22 e la 80, con `nc -zv`. Poi entra e guarda il firewall (serve `sudo`: `edoardo`).
</details>
<details><summary>soluzione</summary>

```bash
curl -m 4 -s http://staging/; echo "curl: $?"    # tempo scaduto
# curl: 28
nc -zv -w2 staging 22; nc -zv -w2 staging 80
# Connection to staging (10.20.1.30) 22 port [tcp/ssh] succeeded!
# nc: connect to staging (10.20.1.30) port 80 (tcp) timed out: Operation now in progress      <- non "rifiutata": filtrata
ssh -o PreferredAuthentications=password edoardo@staging 'sudo ufw status verbose'            # password: edoardo
# Status: active
# Default: deny (incoming), allow (outgoing), deny (routed)
# To                         Action      From
# 22/tcp                     ALLOW IN    Anywhere
# 22/tcp (v6)                ALLOW IN    Anywhere (v6)
```
`ufw` è attivo con la politica **deny** in ingresso e una sola regola, per la 22: ssh passa, il web (la 80) no. `timed out` (e non `refused`) è la firma di un firewall che butta i pacchetti. Si apre la porta:
```bash
ssh -o PreferredAuthentications=password edoardo@staging 'sudo ufw allow 80/tcp'
# Rule added
# Rule added (v6)
curl -s http://staging/
# risposta da staging
```
Aprire una porta **diversa** (per esempio la 8080) non serve: il sito è sulla 80. E `ufw disable` risolverebbe lasciando il server senza firewall: si apre solo ciò che serve, come in [02-firewall-e-hardening](02-firewall-e-hardening.md).
</details>

## 7. Il client è bannato
**Ticket**: *`ssh produzione` va in timeout da stamattina. Il server è acceso, e un collega da un altro computer ci entra.*

<details><summary>da dove cominciare</summary>

Se un altro computer entra e questo no, la differenza è **chi sei tu** per il server. Prova la porta 22 di `produzione` da qui e **da un altro server** (con `ssh staging 'nc ...'`), poi cerca un modo per entrare passando da lì e leggi lo stato di `fail2ban`.
</details>
<details><summary>soluzione</summary>

```bash
ssh -o BatchMode=yes produzione true
# ssh: connect to host produzione port 22: Connection refused          <- il server c'è, ma dice di no (a noi)
nc -zv -w2 produzione 22; ssh staging 'nc -zv -w2 produzione 22'       # da qui no, da staging sì
# nc: connect to produzione (10.20.1.10) port 22 (tcp) failed: Connection refused
# Connection to produzione (10.20.1.10) 22 port [tcp/ssh] succeeded!
```
La porta è aperta, ma **per questo client** è chiusa: è la firma di un **ban** (`fail2ban` mette l'indirizzo di chi ha sbagliato troppe volte in un elenco del firewall, e il server lo respinge). Per toglierlo bisogna entrare su `produzione`, e il modo è **passare da un altro server** (un salto da `staging`, che non è bannato). Prima, quale indirizzo ha questo client?
```bash
ip -4 -br a show eth0
# eth0@if74        UP             10.20.1.5/24
ssh -J staging produzione hostname                                     # il salto da staging entra: per produzione l'origine è staging
# produzione
ssh -o PreferredAuthentications=password -J staging edoardo@produzione 'sudo fail2ban-client status sshd'     # password: edoardo
# |- Currently banned:	1
# `- Banned IP list:	10.20.1.5                                      <- è il nostro indirizzo
ssh -o PreferredAuthentications=password -J staging edoardo@produzione 'sudo nft list ruleset | grep -B3 -A1 10.20.1.5'      # e nel firewall (qui fail2ban usa nftables)
# table inet f2b-table {
#     set addr-set-sshd {
#         type ipv4_addr
#         elements = { 10.20.1.5 }
#     }
ssh -o PreferredAuthentications=password -J staging edoardo@produzione 'sudo fail2ban-client set sshd unbanip 10.20.1.5'
# 1
ssh -o BatchMode=yes produzione hostname
# produzione
```
(Dell'output di `fail2ban-client status` sono riportate solo le righe che contano.) Riavviare `sshd` (`systemctl restart ssh`) non toglie il ban, che sta nel firewall (la tabella `f2b-table` di nftables), e `controlla` lo verifica. In un caso vero, prima di togliere il ban conviene chiedersi **perché** è scattato: password sbagliate, uno script che riprova in continuazione? Altrimenti si viene bannati di nuovo. E da sapere: `ssh -J` serve proprio a **tenere una via d'uscita** quando un server non risponde.
</details>

## 8. Il messaggio cifrato non si apre
**Ticket**: *Un collega ti ha mandato un messaggio cifrato (`~/lab/07-scenari/messaggio.txt.gpg`) e questo computer non riesce a leggerlo.*

<details><summary>da dove cominciare</summary>

`gpg -d` dice **a quale chiave** il messaggio è cifrato e cosa manca. Nella cartella dello scenario c'è un altro file, che ha a che fare con questo.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/07-scenari; ls
# la-mia-chiave.asc  messaggio.txt.gpg  scenari.sh
gpg -d messaggio.txt.gpg
# gpg: encrypted with ECDH key, ID FBE60A18325A3411
# gpg: public key decryption failed: No secret key
# gpg: decryption failed: No secret key
```
Il messaggio è cifrato per la **tua** chiave pubblica, e per leggerlo serve la **chiave privata** corrispondente: questo computer ha un portachiavi vuoto (`~/.gnupg` nuovo). La chiave privata è nel file di backup `la-mia-chiave.asc`: si **importa**.
```bash
gpg --import la-mia-chiave.asc
# gpg: key 4649CA278249BF0F: public key "Studente <studente@example.com>" imported
# gpg: key 4649CA278249BF0F: secret key imported
# gpg: Total number processed: 1
gpg -d messaggio.txt.gpg
# gpg: encrypted with cv25519 key, ID FBE60A18325A3411, created 2026-10-07
#       "Studente <studente@example.com>"
# il codice del cassetto è 4721
```
(Gli ID cambiano a ogni avvio.) Generare una **chiave nuova** non serve: il messaggio è cifrato per quella vecchia, e solo la sua parte privata lo apre. È anche la ragione per cui una chiave privata si **salva** (e si protegge con una passphrase): senza, i messaggi cifrati per quella chiave sono persi. Vedi [03-gpg](03-gpg.md).
</details>

---

## Riepilogo: come si riconosce
| Sintomo | Dove guardare | Prima mossa |
|---|---|---|
| avviso `UNPROTECTED PRIVATE KEY FILE`, poi password | permessi della chiave sul **client** | `ls -l`, `chmod 600` (1) |
| `Connection refused` su una porta strana | il `config` del client | `ssh -G HOST` (2) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | `known_hosts` | confrontare le impronte, `ssh-keygen -R` (3) |
| chiede la password, la chiave è giusta | il **server**: permessi e log | `journalctl -u ssh`, `ls -ld ~/.ssh` (4) |
| `open failed ... Name or service not known` | il salto (`ProxyJump`) | `ssh -G`, chi vede la destinazione (5) |
| `timed out` su una porta, un'altra va | firewall | `nc -zv` su due porte, `ufw status` (6) |
| `Connection refused` solo da questo client | ban di `fail2ban` | passare da un altro server, `fail2ban-client` (7) |
| `No secret key` | portachiavi senza la chiave privata | `gpg --import` del backup (8) |

## Non provato
- Il banco di prova passa **sempre** da `staging` per arrivare a `produzione`: i guasti dei server (`fail2ban` che non parte, `sshd` fermo) non ci sono, perché dal client non si ripareranno.
- `StrictModes` è provato con la cartella `~/.ssh` a `777`; non con `authorized_keys` o la home con permessi sbagliati (sshd li controlla allo stesso modo: non provato).
- `ufw` è provato solo come in questo laboratorio (`iptables-nft` nel container) e `fail2ban` con l'azione `nftables` (quella predefinita qui): con l'azione `iptables` il ban si vede con `iptables -S`, non provato.
- WireGuard non ha uno scenario: un tunnel che non fa il handshake richiede due estremi configurati.
- Il tempo per risolvere uno scenario non è stato misurato su una persona.

Torna all'[indice dell'area](README.md)
