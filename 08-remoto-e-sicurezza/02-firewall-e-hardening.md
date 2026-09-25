# Firewall e hardening di base

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
sudo ufw limit OpenSSH                                      # rate limit: blocca un IP che apre più di 6 connessioni in 30 secondi
sudo ufw status numbered                                    # regole numerate...
sudo ufw delete 3                                           # ...per eliminarle per numero
sudo ufw app list                                           # profili disponibili
sudo ufw disable                                            # disattiva (le regole restano salvate)
```
> **ATTENZIONE**: Docker scrive le sue regole direttamente nel firewall del kernel e **scavalca ufw**:
> una porta pubblicata con `-p 3306:3306` è raggiungibile da internet anche se ufw la blocca.
> Pubblicare le porte solo su localhost (`-p 127.0.0.1:3306:3306`) quando non servono dall'esterno.

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
sudo systemctl reload ssh           # applica senza chiudere le sessioni aperte
```
> **NOTA**: in sshd, per ogni opzione **vince il primo valore letto**. I file in `sshd_config.d/` vengono
> inclusi all'inizio di `sshd_config` in ordine alfabetico: per questo il prefisso numerico basso (`10-`).
> Su Ubuntu recenti un file `50-cloud-init.conf` può rimettere `PasswordAuthentication yes`: `sshd -T` lo rivela.
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

## Checklist per un server nuovo
1. `apt update && apt full-upgrade`, poi `unattended-upgrades`
2. utente non root con sudo e chiave SSH (vedi [../06-sistema/02-utenti.md](../06-sistema/02-utenti.md))
3. verificato l'accesso con la chiave: disattivati login root e password in sshd
4. `ufw` con solo SSH, 80 e 443 aperti
5. `fail2ban` sulla jail sshd
6. servizi interni (MySQL, Redis) in ascolto solo su `127.0.0.1`: `bind-address = 127.0.0.1`
7. `timedatectl set-timezone` e NTP attivo (log con orari coerenti)
8. backup automatici **testati con un ripristino vero** (vedi [../06-sistema/09-crontab.md](../06-sistema/09-crontab.md))
