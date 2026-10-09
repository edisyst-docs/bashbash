# Firewall e hardening di base

> **Laboratorio**: `./lab.sh 08`, poi `cd 02-firewall-e-hardening`. Cosa contiene: [lab/](lab/).

Le prime cose da fare su un server Ubuntu/Debian appena creato ed esposto su internet.

> **ATTENZIONE**: lavorando via SSH, un errore su firewall o sshd può chiudere fuori anche te.
> Tieni sempre aperta una **seconda sessione SSH** già autenticata mentre fai le modifiche, e verifica
> di riuscire a entrare con una terza **prima** di chiudere le altre. Se il provider offre una console web, sappi dov'è.

## ufw: firewall semplice
`ufw` (Uncomplicated Firewall) è un'interfaccia semplificata per le regole del kernel (nftables/iptables).
```bash
sudo ufw status verbose           # stato e regole attive
sudo ufw default deny incoming    # policy: blocca tutto ciò che entra...
sudo ufw default allow outgoing   # ...e lascia uscire tutto
sudo ufw allow OpenSSH            # PRIMA di attivarlo: apri SSH, altrimenti ti chiudi fuori
sudo ufw allow 2222/tcp           # UGUALE se SSH è su una porta diversa
sudo ufw allow 'Nginx Full'       # 80 e 443 (i profili delle app sono in /etc/ufw/applications.d/)
sudo ufw enable                   # attiva il firewall (e lo riattiva al riavvio)
```

```bash
sudo ufw allow from 203.0.113.50 to any port 3306 proto tcp # MySQL raggiungibile SOLO da un IP specifico
sudo ufw allow from 10.0.0.0/24                             # tutta la rete interna
sudo ufw deny from 198.51.100.7                             # blocca un IP
sudo ufw allow http                                         # UGUALE a "allow 80/tcp": i nomi dei servizi vengono da /etc/services
sudo ufw allow 5000:6000/tcp                                # un intervallo di porte (con gli intervalli il protocollo è obbligatorio)
sudo ufw allow in on eth0 to any port 80                    # solo il traffico che entra da quell'interfaccia (es. la rete interna)
sudo ufw limit OpenSSH                                      # rate limit: blocca un IP che apre più di 6 connessioni in 30 secondi
sudo ufw status numbered                                    # regole numerate...
sudo ufw delete 3                                           # ...per eliminarle per numero
sudo ufw app list                                           # profili disponibili
sudo ufw route allow in on wg0 to 10.20.2.0/24                 # pacchetti INOLTRATI (la policy "routed" è deny): serve a un router o a un peer VPN, vedi 04-vpn-wireguard.md
sudo ufw disable                                            # disattiva (le regole restano salvate)
```
> **ATTENZIONE**: Docker scrive le sue regole direttamente nel firewall del kernel e **scavalca ufw**:
> una porta pubblicata con `-p 3306:3306` è raggiungibile da internet anche se ufw la blocca.
> Pubblicare le porte solo su localhost (`-p 127.0.0.1:3306:3306`) quando non servono dall'esterno.

### ufw per chi parte da zero
Come ragiona ufw, in tre punti:
1. **Policy di default**: cosa succede ai pacchetti che nessuna regola nomina. Tre direzioni: `incoming` (verso il server), `outgoing` (dal server), `routed` (inoltrati). Per un server: `deny incoming`, `allow outgoing`.
2. **Regole**: eccezioni alla policy (`allow 80/tcp` apre la porta 80). Si valutano **dall'alto in basso e vince la prima che corrisponde**: una `deny` messa sotto una `allow` più larga non serve a niente.
3. **Attivo o no**: finché non fai `ufw enable` le regole sono solo scritte, non applicate. `ufw status` dice `inactive` se è spento.

`allow` accetta, `deny` scarta in silenzio (chi si connette aspetta il timeout), `reject` risponde subito "rifiutato" (utile in rete interna, dove vuoi un errore veloce). In uscita: `ufw deny out 25/tcp`.

### Commenti sulle regole
```bash
sudo ufw allow OpenSSH comment 'ssh admin'                                       # un commento per ricordare PERCHÉ la regola esiste
sudo ufw allow 80/tcp comment 'sito web'
sudo ufw allow from 10.20.1.5 to any port 3306 proto tcp comment 'mysql dal client'
sudo ufw status numbered
#      To                         Action      From
#      --                         ------      ----
# [ 1] OpenSSH                    ALLOW IN    Anywhere                   # ssh admin
# [ 2] 80/tcp                     ALLOW IN    Anywhere                   # sito web
# [ 3] 3306/tcp                   ALLOW IN    10.20.1.5                  # mysql dal client
# [ 4] OpenSSH (v6)               ALLOW IN    Anywhere (v6)              # ssh admin
# [ 5] 80/tcp (v6)                ALLOW IN    Anywhere (v6)              # sito web
```
Ogni regola compare due volte, `(v6)` è la copia per IPv6 (ufw la crea da sola se in `/etc/default/ufw` c'è `IPV6=yes`, il predefinito di Ubuntu).
Il commento è solo un'etichetta per te: non cambia come il firewall decide. In `status verbose` e `show added` si vede; si può mettere solo quando si **crea** la regola, per cambiarlo si cancella e si rifà.

### Vedere cosa hai configurato: `show added`, `show listening`
```bash
sudo ufw show added                    # le regole come le hai DIGITATE (anche se il firewall è spento): comode da copiare su un altro server
# Added user rules (see 'ufw status' for running firewall):
# ufw allow OpenSSH comment 'ssh admin'
# ufw allow 80/tcp comment 'sito web'
# ufw allow from 10.20.1.5 to any port 3306 proto tcp comment 'mysql dal client'
sudo ufw show listening                # cosa è in ascolto e QUALE regola lo copre: trova a colpo d'occhio i servizi senza regola
# tcp:
#   22 * (sshd)
#    [ 1] allow OpenSSH
#
#   80 * (nginx)
#    [ 2] allow 80/tcp comment 'sito web'
#
#   8080 * (apache2)                    <- in ascolto, nessuna regola: con deny incoming è chiusa dall'esterno
sudo ufw app info OpenSSH              # cosa apre un profilo (qui 22/tcp) prima di usarlo
sudo ufw --dry-run allow 8080/tcp      # mostra le regole iptables che ne uscirebbero SENZA applicare niente
```
Regole **in mezzo** e cancellazione:
```bash
sudo ufw insert 1 deny from 198.51.100.7 comment 'noto scanner' # in posizione 1: prima di tutte le altre (con "allow" in coda non basterebbe, vince la prima)
sudo ufw delete allow 80/tcp                                    # ripetendo la regola (senza commento) si tolgono insieme la versione v4 e la v6: meglio del numero
sudo ufw --force delete 2                                       # per numero, senza conferma (negli script). Toglie UNA riga sola: la copia (v6) resta e va tolta a parte; i numeri cambiano a ogni cancellazione, rifai "status numbered"
sudo ufw reload                                                 # rilegge le regole da /etc/ufw/*.rules senza spegnere il firewall
```

### Log del firewall: `ufw logging`
```bash
sudo ufw logging medium                # off | low | medium | high | full (predefinito: low)
sudo ufw status verbose | grep Logging # Logging: on (medium)
sudo tail -f /var/log/ufw.log          # su un server vero: una riga per ogni pacchetto bloccato
# ... [UFW BLOCK] IN=eth0 OUT= SRC=198.51.100.7 DST=203.0.113.10 ... PROTO=TCP SPT=51234 DPT=8080 ...
sudo journalctl -k | grep 'UFW BLOCK'  # lo stesso dal journal del kernel, se /var/log/ufw.log non esiste
```
| Livello | Cosa scrive |
|---|---|
| `low` | i pacchetti **bloccati** che non corrispondono a nessuna regola, più quelli che escono dalle regole `limit` |
| `medium` | in più i pacchetti **permessi** che non rientrano nella policy di default (es. accettati da una regola), le nuove connessioni e i pacchetti non validi |
| `high` | tutti i pacchetti, con limite di frequenza (può riempire il disco) |
| `full` | come `high`, **senza** limite |

Come leggere una riga: `SRC` chi manda, `DST` il tuo IP, `DPT` la porta che cercava, `PROTO` il protocollo. Tante righe con `DPT=22` e `SRC` sempre diversi: scansione o tentativi di accesso a SSH (qui aiuta [fail2ban](#fail2ban-bloccare-i-tentativi-di-accesso-ripetuti)).
`low` va bene sempre; `medium` o più solo per capire perché qualcosa non passa, poi si torna a `low`, e `ufw logging off` spegne tutto.
> **NOTA**: nel laboratorio (container) `ufw logging` si imposta e `status verbose` lo mostra, ma **non** compare nessuna riga `[UFW BLOCK]`: un container non vede il log del kernel. Il formato delle righe sopra viene dalla documentazione di ufw e non l'ho riprodotto qui. Su un server o una VM vera funziona.

### Ricominciare da zero: `ufw reset`
```bash
sudo ufw --force reset                 # cancella TUTTE le regole e SPEGNE il firewall (--force: senza chiedere conferma)
# Backing up 'user.rules' to '/etc/ufw/user.rules.20261009_163757'     <- prima salva una copia di ogni file di regole
# ...
sudo ufw status                        # Status: inactive
```
> **ATTENZIONE**: dopo `reset` il firewall è **spento**, quindi il server è aperto a tutto finché non rifai `default`, `allow OpenSSH` e `enable` (in questo ordine: se fai `enable` con `deny incoming` e senza `allow OpenSSH`, ti chiudi fuori via SSH). Prima di resettare salva le regole con `sudo ufw show added > regole-ufw.txt`; per ripristinarle, rilancia quelle righe (`ufw allow ...`) con `sudo`.

Ricetta di un server nuovo, da incollare (con SSH sulla 22: se la porta è diversa cambia `allow`):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH comment 'ssh'
sudo ufw allow 80/tcp comment 'http'
sudo ufw allow 443/tcp comment 'https'
sudo ufw --force enable
sudo ufw status verbose                # controlla: Status: active, Default: deny (incoming)
sudo ufw show listening                # nessun servizio in ascolto senza una regola che lo giustifichi
```

## Hardening di SSH
Le modifiche vanno in un file dentro `/etc/ssh/sshd_config.d/`, così non si toccano i file del pacchetto.
File `/etc/ssh/sshd_config.d/10-hardening.conf`:
```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
AllowUsers deploy edoardo
```
```bash
sudo sshd -t                        # verifica la sintassi: NESSUN output = tutto ok
sudo sshd -T | grep -Ei 'permitroot|passwordauth|allowusers' # configurazione EFFETTIVA dopo aver combinato tutti i file
# permitrootlogin without-password        <- nel laboratorio, su `produzione` (valori predefiniti di Ubuntu: nessun AllowUsers, quindi nessuna riga)
# passwordauthentication yes
sudo systemctl reload ssh           # applica senza chiudere le sessioni aperte
```
> **NOTA**: in sshd, per ogni opzione **vince il primo valore letto**. I file in `sshd_config.d/` vengono
> inclusi all'inizio di `sshd_config` in ordine alfabetico: per questo il prefisso numerico basso (`10-`).
> Su Ubuntu recenti un file `50-cloud-init.conf` può rimettere `PasswordAuthentication yes`: `sshd -T` lo rivela.
> Provato nel laboratorio: con `50-cloud-init.conf` (`PasswordAuthentication yes`) e `10-hardening.conf` (`PasswordAuthentication no`) `sshd -T` stampa `passwordauthentication no`; tolto il `10-`, torna `yes`. (Il file `50-cloud-init.conf` l'ho creato io per la prova: il laboratorio non ha cloud-init.)
>
> **Prima** di disattivare le password verifica di entrare con la chiave: vedi [01-ssh.md](01-ssh.md).

Cambiare porta SSH (riduce il rumore nei log, non è una vera protezione):
```bash
echo 'Port 2222' | sudo tee /etc/ssh/sshd_config.d/05-porta.conf
sudo ufw allow 2222/tcp                                   # prima apri la nuova porta
sudo systemctl daemon-reload                              # Ubuntu >= 22.10 usa ssh.socket: la porta la legge systemd
if systemctl is-active --quiet ssh.socket; then          # Ubuntu recenti: la porta è gestita dal socket di systemd
    sudo systemctl restart ssh.socket
else
    sudo systemctl restart ssh                            # Debian e Ubuntu meno recenti
fi
ss -tlnp | grep sshd                                      # verifica che ascolti sulla nuova porta, poi prova a entrare
sudo ufw delete allow OpenSSH                             # solo DOPO aver verificato: chiudi la 22
```

## fail2ban: bloccare i tentativi di accesso ripetuti
Legge i log e banna temporaneamente (via firewall) gli IP che sbagliano l'accesso troppe volte.
```bash
sudo apt install fail2ban
```
File `/etc/fail2ban/jail.local` (mai modificare `jail.conf`, viene sovrascritto dagli aggiornamenti):
```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
# IP che non vanno mai bannati: localhost e il mio ufficio
ignoreip = 127.0.0.1/8 ::1 203.0.113.50
# Debian 12+ non ha /var/log/auth.log di default: legge dal journal di systemd
backend  = systemd

[sshd]
enabled = true
port    = ssh,2222
```
```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status                   # jail attive
sudo fail2ban-client status sshd              # IP bannati e contatori della jail sshd
sudo fail2ban-client set sshd unbanip 198.51.100.7 # sblocca un IP (es. me stesso)
sudo tail -f /var/log/fail2ban.log            # ban e unban in tempo reale
```

## Aggiornamenti di sicurezza automatici
```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # attiva l'installazione automatica degli aggiornamenti di sicurezza
sudo unattended-upgrade --dry-run --debug         # simula e mostra cosa verrebbe installato
cat /var/log/unattended-upgrades/unattended-upgrades.log # storico
[ -f /var/run/reboot-required ] && echo "serve un riavvio" # alcuni aggiornamenti (kernel) richiedono il reboot
```

## Controlli rapidi
```bash
ss -tulpn                                   # cosa è in ascolto e su quale interfaccia: 0.0.0.0 = aperto verso l'esterno
sudo lastb | head -20                       # ultimi login falliti
journalctl -u ssh --since today | grep -c 'Failed password' # tentativi con password falliti oggi
journalctl _COMM=sudo --since today | grep COMMAND     # comandi lanciati con sudo oggi
find / -xdev -perm -4000 -type f 2>/dev/null # eseguibili setuid: confrontali nel tempo, uno nuovo è sospetto
awk -F: '$3 == 0 {print $1}' /etc/passwd    # utenti con UID 0: deve esserci solo root
sudo apt list --upgradable 2>/dev/null | grep -i security # aggiornamenti di sicurezza in sospeso
```

Per vedere **cosa è stato toccato** (`auditd`), limitare i programmi (AppArmor, SELinux), avere un punteggio di configurazione (`lynis`) o cercare file infetti (ClamAV): [05-sicurezza-sistema.md](05-sicurezza-sistema.md).

## Checklist per un server nuovo
1. `apt update && apt full-upgrade`, poi `unattended-upgrades`
2. utente non root con sudo e chiave SSH (vedi [../06-sistema/02-utenti.md](../06-sistema/02-utenti.md))
3. verificato l'accesso con la chiave: disattivati login root e password in sshd
4. `ufw` con solo SSH, 80 e 443 aperti
5. `fail2ban` sulla jail sshd
6. servizi interni (MySQL, Redis) in ascolto solo su `127.0.0.1`: `bind-address = 127.0.0.1`
7. `timedatectl set-timezone` e NTP attivo (log con orari coerenti)
8. backup automatici **testati con un ripristino vero** (vedi [../06-sistema/09-crontab.md](../06-sistema/09-crontab.md))
