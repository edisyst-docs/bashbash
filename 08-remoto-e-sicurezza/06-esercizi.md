# Esercizi: ssh, tunnel, firewall, GPG e WireGuard

> **Laboratorio**: `./lab.sh 08`, poi `cd 06-esercizi`. Si lavora dal `client`, che vede tre server veri (`produzione`, `staging`, `db-interno`, con sshd, ufw e fail2ban) (vedi [lab/](lab/)).

Ventidue esercizi su [ssh](01-ssh.md), [firewall e ufw](02-firewall-e-hardening.md), [GPG](03-gpg.md) e [WireGuard](04-vpn-wireguard.md). Qui si **parla con altre macchine**: si apre una connessione, si costruisce un tunnel, si cambia una regola del firewall di un server,
e `verifica.sh` guarda **il risultato**. Le soluzioni sono nascoste in fondo a ogni esercizio.

## Come si lavora
Ogni risposta è uno script `risposte/NN.sh` (due cifre) con **uno o più comandi**, eseguito come root sul `client` dentro una **copia nuova della palestra** (`script.sh`, `segreto.txt`, `documento.txt`):
```bash
cd ~/lab/06-esercizi
echo "ssh deploy@produzione hostname" > risposte/04.sh        # la risposta all'esercizio 4
./verifica.sh 4
#   04  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                                  # tutti (circa 25 secondi): quelli senza risposta sono "da fare"
```
Per le risposte **senza password** `verifica.sh` prepara da solo l'ambiente: crea la chiave `.chiave-esercizi` e la autorizza una volta sola (con la password `deploy` / `edoardo`) per `deploy` ed `edoardo` sui tre server, avvia un **`ssh-agent`** che la tiene
e aggiunge una configurazione temporanea che non chiede conferma al primo contatto con un server (`StrictHostKeyChecking accept-new`). Per provare **a mano** gli stessi comandi, dopo aver lanciato `./verifica.sh 4` una volta:
```bash
eval "$(ssh-agent -s)"; ssh-add .chiave-esercizi            # ora "ssh deploy@produzione" non chiede la password
ssh -o StrictHostKeyChecking=accept-new deploy@produzione hostname
```
Il GPG di ogni prova è **vuoto e separato** (`GNUPGHOME` temporaneo): non si tocca il portachiavi vero. Per ogni esercizio `verifica.sh` esegue la tua risposta e legge **lo stato** che l'esercizio chiede (un file, un tunnel aperto, una regola di `ufw`, l'interfaccia `wg0`),
ripulisce, e poi fa lo stesso con la soluzione di riferimento. Negli esercizi che **stampano** un risultato (4, 5, 6, 11) si confronta l'output; negli altri lo stato:
```
  08  SBAGLIATO
        2c2
        < Server: nginx
        ---
        > Server: Apache
        (< atteso, > ottenuto)
```
> **Attenzione**: `verifica.sh` aggiunge e toglie regole di `ufw` su `staging`, apre tunnel e crea `wg0` sul client: si lancia solo nel laboratorio 08 (si rifiuta se `produzione` non si risolve). Dopo un'interruzione: `bash /kb/08-remoto-e-sicurezza/lab/soluzioni.sh pulisci N`.

## Chiavi e configurazione ssh ([01-ssh.md](01-ssh.md))
**1.** Nella cartella corrente, genera la coppia di chiavi **ed25519** `chiave` / `chiave.pub`, **senza passphrase**, con il commento `esercizio`. *(Cambia i file: si controllano tipo, commento e permessi.)*
<details><summary>soluzione</summary>

```bash
ssh-keygen -q -t ed25519 -N '' -C esercizio -f chiave
ssh-keygen -lf chiave.pub | awk '{print $1, $NF}'
# 256 (ED25519)
awk '{print $3}' chiave.pub; stat -c %a chiave
# esercizio
# 600
```
`-N ''` è la passphrase vuota (per le chiavi di un **servizio**; per una persona meglio una passphrase). La chiave **privata** ha permessi `600`: `ssh` la rifiuta se leggibile da altri (`UNPROTECTED PRIVATE KEY FILE`).
</details>

**2.** Scrivi un file `config` (nella cartella corrente) con l'alias **`prod`**: nome reale `produzione`, utente `deploy`. *(Si controlla con `ssh -F config -G prod`: nessuna connessione.)*
<details><summary>soluzione</summary>

```bash
cat > config << 'EOF'
Host prod
    HostName produzione
    User deploy
EOF
ssh -F config -G prod | grep -E '^(hostname|user) '
# user deploy
# hostname produzione
```
`ssh -G` stampa la configurazione **effettiva** per quel nome, **senza collegarsi**: è il modo di controllare un `config` ([01-ssh.md](01-ssh.md)). `-F config` usa un file diverso da `~/.ssh/config`. Le parole chiave non distinguono le maiuscole (`Hostname` va bene).
</details>

**3.** Nello stesso modo, l'alias **`db`**: host `db-interno`, utente `deploy`, che si raggiunge **passando da `deploy@produzione`** (`ProxyJump`).
<details><summary>soluzione</summary>

```bash
cat > config << 'EOF'
Host db
    HostName db-interno
    User deploy
    ProxyJump deploy@produzione
EOF
ssh -F config -G db | grep -E '^(hostname|user|proxyjump) '
# user deploy
# hostname db-interno
# proxyjump deploy@produzione
```
`db-interno` sta solo nella rete interna: dal client **non si risolve nemmeno il nome**, ci si arriva solo attraverso `produzione`, che vede entrambe le reti.
</details>

## Comandi remoti e file ([01-ssh.md](01-ssh.md))
**4.** Esegui `hostname` su `produzione` come `deploy` e stampa il risultato. (una parola)
<details><summary>soluzione</summary>

```bash
ssh deploy@produzione hostname
# produzione
```
Il comando dopo l'host viene eseguito **sul server** e `ssh` esce con il suo codice d'uscita.
</details>

**5.** Lo stesso su `db-interno`, **passando da `produzione`**. (una parola)
<details><summary>soluzione</summary>

```bash
ssh -J deploy@produzione deploy@db-interno hostname
# db-interno
```
`-J` apre prima la connessione a `produzione` e da lì raggiunge `db-interno`. Attenzione: `-i CHIAVE` vale **solo per l'ultima** macchina: con `ssh -i chiave -J ...` il salto non usa la chiave e dà `deploy@produzione: Permission denied`. Per questo qui si usa l'agente (o un `IdentityFile` nel `config`).
</details>

**6.** Esegui sul server `produzione` lo script **locale** `script.sh` (senza copiarlo): deve stampare `ciao da produzione`. (una riga)
<details><summary>soluzione</summary>

```bash
ssh deploy@produzione 'bash -s' < script.sh
# ciao da produzione
cat script.sh | ssh deploy@produzione bash -s        # UGUALE
```
`bash -s` legge i comandi dallo **stdin**, che `ssh` collega al file locale: lo script gira sul server e `$(hostname)` è quello del server. Utile per script che si usano una volta sola.
</details>

**7.** Scarica con `scp` il file `/var/log/app/app.log` di **`staging`** nella cartella corrente. *(Cambia i file: ogni server ha il suo, con `NOMESERVER riga di log N`.)*
<details><summary>soluzione</summary>

```bash
scp deploy@staging:/var/log/app/app.log .
head -1 app.log; wc -l < app.log
# staging riga di log 1
# 50
```
Il formato è `utente@host:percorso destinazione`; `.` è la cartella corrente. Con `produzione` al posto di `staging` il file è uguale per dimensione ma la prima riga dice `produzione`: per questo il controllo la guarda.
</details>

## Tunnel ([01-ssh.md](01-ssh.md))
**8.** Apri un tunnel **locale**: la porta `8081` del client deve arrivare alla porta **80 di `db-interno`** passando da `produzione`; il comando deve **tornare subito** (tunnel in background). *(Cambia il sistema: `curl localhost:8081`.)*
<details><summary>soluzione</summary>

```bash
ssh -fNL 8081:db-interno:80 deploy@produzione
curl -s localhost:8081
# risposta da db-interno
```
`-L 8081:db-interno:80`: ciò che arriva alla 8081 locale esce da `produzione` verso `db-interno:80`; `db-interno` lo risolve **`produzione`**, non il client. `-N` non esegue comandi, `-f` manda in background dopo l'autenticazione. Si chiude con `pkill -f 'ssh.*8081'`.
`db-interno` ha **anche** un apache2 sulla porta `8080`: il controllo guarda l'intestazione `Server:` (`nginx` o `Apache`) e distingue le due porte, che altrimenti rispondono con lo stesso testo.
</details>

**9.** Apri un **proxy SOCKS** sulla porta `1080` del client attraverso `produzione`, in background. *(Cambia il sistema: `curl --socks5-hostname localhost:1080 http://db-interno/`.)*
<details><summary>soluzione</summary>

```bash
ssh -fND 1080 deploy@produzione
curl -s --socks5-hostname localhost:1080 http://db-interno/
# risposta da db-interno
```
`-D` apre un proxy SOCKS **dinamico**: ogni connessione passa da `produzione`, qualunque sia la destinazione. `--socks5-hostname` fa risolvere il **nome** al proxy, cioè a `produzione`, che conosce `db-interno`. Provato con `--socks5` (senza `-hostname`): `curl` risolve il nome dal client e fallisce con codice 97 (errore SOCKS).
</details>

## Firewall e fail2ban ([02-firewall-e-hardening.md](02-firewall-e-hardening.md))
**10.** Su **`staging`** aggiungi la regola `ufw` che **consente la porta 8080/tcp**. (Come `edoardo`, che ha `sudo`; password `edoardo`.) *(Cambia il sistema: `ufw show added`.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw allow 8080/tcp"
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added"
# ufw allow 8080/tcp
```
`sudo -S` legge la password dallo stdin (vale solo per il laboratorio: su un server vero non si scrive una password in un comando, resterebbe nella cronologia). `ufw show added` elenca le regole **aggiunte**, anche se il firewall non è attivo; `ufw status` mostra invece quelle in vigore: nel laboratorio il firewall è **inattivo** (`Status: inactive`), anche dopo aver aggiunto la regola.
Su un server vero, prima di attivare `ufw` si **consente ssh** (`ufw allow OpenSSH`), per non chiudersi fuori.
</details>

**11.** Quanti **IP sono bannati adesso** dal jail `sshd` di fail2ban su `produzione`? (un numero)
<details><summary>soluzione</summary>

```bash
ssh edoardo@produzione "echo edoardo | sudo -S -p '' fail2ban-client status sshd" | awk '/Currently banned/ {print $NF}'
# 0
```
L'output di `fail2ban-client status sshd` ha **due** righe che cominciano per `Currently` (`Currently failed` e `Currently banned`): un `grep Currently` le prenderebbe tutte e due. Sbagliare riga è l'errore tipico di questo esercizio.
</details>

## GPG ([03-gpg.md](03-gpg.md))
Tutti gli esercizi GPG girano con un portachiavi **vuoto** e temporaneo. In `--batch` la passphrase si passa con `--pinentry-mode loopback`.

**12.** Genera una coppia di chiavi per **`Mario Rossi <mario@example.com>`**, **senza passphrase**, senza scadenza. *(Cambia lo stato: `gpg --list-keys`.)*
<details><summary>soluzione</summary>

```bash
gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "Mario Rossi <mario@example.com>" default default never
gpg --list-keys --with-colons | awk -F: '/^uid/ {print $10}'
# Mario Rossi <mario@example.com>
```
`--quick-gen-key UID ALGO USO SCADENZA`: `default default never` sceglie i valori predefiniti e nessuna scadenza. Un file di parametri con `gpg --batch --gen-key` e `%no-protection` fa lo stesso.
</details>

**13.** **Cifra** `segreto.txt` con una passphrase **simmetrica** (`lab`), ottenendo `segreto.txt.gpg`. *(Cambia i file: si decifra con la stessa passphrase.)*
<details><summary>soluzione</summary>

```bash
gpg --batch --pinentry-mode loopback --passphrase lab -c segreto.txt        # -c = --symmetric
gpg --batch --pinentry-mode loopback --passphrase lab -d segreto.txt.gpg
# dati riservati
```
La cifratura simmetrica non usa chiavi: chi conosce la passphrase decifra. `-d` decifra sullo stdout.
</details>

**14.** Con la chiave già presente nel portachiavi, fai una **firma staccata** di `documento.txt` (`documento.txt.sig`). *(Cambia i file: `gpg --verify` deve dire `Good signature`.)*
<details><summary>soluzione</summary>

```bash
gpg --batch --pinentry-mode loopback --passphrase '' --detach-sign documento.txt        # o -b
gpg --verify documento.txt.sig documento.txt 2>&1 | grep -c 'Good signature'
# 1
```
La firma staccata sta in un file a parte e **non cambia** il documento: chi lo riceve controlla con `gpg --verify FIRMA FILE`. Se il documento cambia, anche di un carattere, la verifica dà `BAD signature`.
</details>

## WireGuard ([04-vpn-wireguard.md](04-vpn-wireguard.md))
**15.** Genera una coppia di chiavi WireGuard: la **privata** in `priv` e la **pubblica** in `pub`. *(Cambia i file: la pubblica deve derivare dalla privata.)*
<details><summary>soluzione</summary>

```bash
wg genkey | tee priv | wg pubkey > pub
wc -c < priv; wc -c < pub
# 45
# 45
wg pubkey < priv | cmp -s - pub && echo coerenti
# coerenti
```
Una chiave WireGuard è di 32 byte in base64: 44 caratteri più l'a capo = 45. La pubblica si **calcola** dalla privata (`wg pubkey`): la privata non si condivide mai.
</details>

**16.** Crea l'interfaccia **`wg0`** WireGuard con la chiave privata `priv`, **porta `51820`** e indirizzo **`10.200.0.1/24`**, e **accendila**. *(Cambia il sistema: `wg show wg0`.)*
<details><summary>soluzione</summary>

```bash
wg genkey > priv
ip link add wg0 type wireguard
wg set wg0 private-key priv listen-port 51820
ip addr add 10.200.0.1/24 dev wg0
ip link set wg0 up
wg show wg0 listen-port; ip -4 -o addr show wg0 | awk '{print $4}'
# 51820
# 10.200.0.1/24
```
`wg genkey > priv` stampa `Warning: writing to world accessible file. Consider setting the umask to 077`: la chiave privata andrebbe creata con `umask 077` (o `chmod 600`). Il client ha `CAP_NET_ADMIN`, perciò può creare `wg0`; senza peer l'interfaccia è accesa ma non scambia traffico. Si toglie con `ip link del wg0`.
</details>

## ufw in pratica ([02-firewall-e-hardening.md](02-firewall-e-hardening.md))
Tutti su **`staging`**, come `edoardo` (`sudo` con password `edoardo`, come nell'esercizio 10). Il firewall del laboratorio è **inattivo**: le regole si aggiungono e si leggono con `ufw show added`, ma non bloccano niente.
Ogni prova riparte da `staging` senza regole.

**17.** Consenti l'accesso alla porta **3306/tcp** (MySQL) **solo dal `client`** (`10.20.1.5`), con il commento `mysql dal client`. *(Cambia il sistema: `ufw show added`; la regola deve essere scritta nella forma `from ... to any port ... proto tcp`.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw allow from 10.20.1.5 to any port 3306 proto tcp comment 'mysql dal client'"
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added"
# ufw allow from 10.20.1.5 to any port 3306 proto tcp comment 'mysql dal client'
```
`ufw allow 3306/tcp` aprirebbe la porta a **tutti**: con `from IP` si limita a chi serve. Il commento si può dare solo **creando** la regola. Gli apici interni (`'mysql dal client'`) devono arrivare fino al server: per questo stanno dentro le virgolette doppie del comando remoto.
</details>

**18.** Blocca l'IP **`198.51.100.7`** con il commento `scanner`. *(Cambia il sistema: `ufw show added`.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw deny from 198.51.100.7 comment scanner"
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added"
# ufw deny from 198.51.100.7 comment 'scanner'
```
`deny` scarta i pacchetti in silenzio (chi si connette aspetta il timeout); `reject` risponderebbe subito «rifiutato». Un comando senza commento è un errore comune: il controllo guarda anche quello.
</details>

**19.** Su `staging` c'è già la regola `allow 80/tcp`. Aggiungi `deny from 198.51.100.7` **come prima regola** (prima di quella sulla 80). *(Cambia il sistema: `ufw show added` elenca le regole nell'ordine in cui vengono valutate.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw insert 1 deny from 198.51.100.7"
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added"
# ufw deny from 198.51.100.7
# ufw allow 80/tcp
```
Le regole si valutano dall'alto e **vince la prima che corrisponde**. Un normale `ufw deny from ...` si **accoda** in fondo: con una `allow` più larga sopra (per esempio «tutti sulla 80») l'IP da bloccare passerebbe lo stesso. `insert 1` la mette in cima. Con un `deny` accodato il controllo vede l'ordine sbagliato.
</details>

**20.** Su `staging` ci sono le regole `allow 8080/tcp` e `allow 9090/tcp`. **Togli solo la 8080**. *(Cambia il sistema: `ufw show added`.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw delete allow 8080/tcp"
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added"
# ufw allow 9090/tcp
```
`ufw delete` vuole la **stessa regola** che l'ha creata, con `delete` davanti: toglie insieme la versione IPv4 e quella IPv6 `(v6)`. Con il firewall attivo si può anche cancellare **per numero** (`ufw status numbered`, poi `ufw --force delete N`): ma toglie una riga sola e i numeri cambiano a ogni cancellazione.
</details>

**21.** Su `staging` ci sono alcune regole. **Salva** nel file `regole-ufw.txt` (cartella corrente, sul `client`) i comandi `ufw ...` che le ricreerebbero, uno per riga (la lista da cui ripartire dopo un `ufw reset`). *(Cambia i file: si legge `regole-ufw.txt`.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw show added" | grep '^ufw' > regole-ufw.txt
cat regole-ufw.txt
# ufw allow OpenSSH comment 'ssh'
# ufw allow 80/tcp
# ufw allow 443/tcp
```
`ufw show added` scrive già le regole come **comandi**, con il commento: si possono rilanciare così come sono (con `sudo`). Il `grep '^ufw'` toglie la riga di intestazione `Added user rules (...)`.
</details>

**22.** **Senza applicare niente**, stampa la regola `iptables` **IPv4** che nascerebbe da `ufw allow 8443/tcp`. *(Output di una riga; poi si controlla anche che la 8443 **non** sia stata aggiunta.)*
<details><summary>soluzione</summary>

```bash
ssh edoardo@staging "echo edoardo | sudo -S -p '' ufw --dry-run allow 8443/tcp" | grep 'ufw-user-input.*8443'
# -A ufw-user-input -p tcp --dport 8443 -j ACCEPT
```
`--dry-run` stampa **tutte** le regole `iptables` che ne uscirebbero, più la copia IPv6 (`ufw6-user-input`): il `grep` tiene la riga IPv4. Senza `--dry-run` la regola verrebbe aggiunta davvero e il controllo se ne accorge (`ufw show added | grep -c 8443` deve dare `0`).
</details>

## Se non sai da dove cominciare
| Devi... | Comando |
|---|---|
| una chiave ssh | `ssh-keygen -t ed25519 -C commento -f FILE`, e `ssh-copy-id` per autorizzarla |
| controllare un `config` senza collegarsi | `ssh -F config -G ALIAS` |
| un comando o uno script su un server | `ssh utente@host comando`, `ssh host 'bash -s' < script.sh` |
| passare da un server | `ssh -J utente@salto utente@destinazione`, o `ProxyJump` nel config |
| portare una porta | `ssh -fNL PORTA-LOCALE:HOST:PORTA utente@server` (locale), `-R` (inversa), `-D PORTA` (SOCKS) |
| un file avanti e indietro | `scp utente@host:percorso .` |
| regole del firewall | `ufw allow PORTA/tcp`, `ufw allow from IP to any port N proto tcp`, `ufw insert 1 ...`, `ufw delete allow ...`, `ufw show added`, `ufw --dry-run ...` |
| bannati | `fail2ban-client status JAIL` |
| GPG senza tastiera | `--batch --pinentry-mode loopback --passphrase ...`, `-c` (simmetrica), `-b` (firma staccata), `--verify` |
| WireGuard | `wg genkey`, `wg pubkey`, `ip link add wg0 type wireguard`, `wg set`, `wg show` |

Torna all'[indice dell'area](README.md)
