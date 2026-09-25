# SSH

Accesso remoto cifrato a un server, trasferimento di file e tunnel.

## Collegarsi
```bash
ssh utente@server                 # collegamento sulla porta 22
ssh -p 2222 utente@server         # porta diversa
ssh utente@server 'df -h; uptime' # esegue i comandi sul server e torna subito indietro
ssh -t utente@server 'sudo htop'  # -t forza un terminale: serve per i comandi interattivi (sudo, htop, vim)
ssh -v utente@server              # verbose: mostra ogni passo della connessione (-vv, -vvv ancora di più). Primo passo del debug
exit                              # oppure CTRL+D: chiude la sessione
```
> **TRUCCO**: se la sessione si blocca (rete caduta), premere in sequenza `INVIO`, `~`, `.` la chiude subito.

## Chiavi SSH
Al posto della password: una chiave **privata** resta sul mio PC, la **pubblica** va sul server.
```bash
ssh-keygen -t ed25519 -C "edoardo@pc-ufficio"   # genera la coppia: ~/.ssh/id_ed25519 (privata) e ~/.ssh/id_ed25519.pub (pubblica)
                                                # -C è solo un commento per riconoscerla; la passphrase è FORTEMENTE consigliata
ssh-copy-id utente@server                       # copia la chiave pubblica in ~/.ssh/authorized_keys del server
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 2222 utente@server # UGUALE, scegliendo chiave e porta

cat ~/.ssh/id_ed25519.pub | ssh utente@server 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
                                                # UGUALE senza ssh-copy-id (es. da Git Bash su Windows, dove può mancare)

ssh-keygen -lf ~/.ssh/id_ed25519.pub            # impronta (fingerprint) della chiave
ssh-keygen -p -f ~/.ssh/id_ed25519              # cambia o aggiunge la passphrase a una chiave esistente
ssh-keygen -R server                            # rimuove il server da known_hosts (dopo una reinstallazione: "REMOTE HOST IDENTIFICATION HAS CHANGED")
```
> **ATTENZIONE**: la chiave privata non va mai copiata su un server, allegata o messa in un repository.
> Permessi obbligatori: `~/.ssh` 700, chiave privata 600. Con permessi più larghi ssh la rifiuta.

## ssh-agent: inserire la passphrase una volta sola
```bash
eval "$(ssh-agent -s)"            # avvia l'agent ed esporta le variabili che servono a ssh per trovarlo
ssh-add ~/.ssh/id_ed25519         # carica la chiave: chiede la passphrase una volta
ssh-add -l                        # chiavi caricate
ssh-add -t 4h ~/.ssh/id_ed25519   # la chiave resta caricata solo 4 ore
ssh -A utente@bastion             # agent forwarding: dal bastion posso usare le MIE chiavi verso altri server
```
> **ATTENZIONE**: con `-A` chi è root sul server intermedio può usare le tue chiavi finché sei collegato.
> Usarlo solo su macchine fidate; per saltare tra server meglio `ProxyJump` (sotto).

## ~/.ssh/config: alias e impostazioni per ogni server
Evita di ricordare utenti, porte, chiavi e IP.
```
Host produzione
    HostName 203.0.113.10
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519_lavoro
    IdentitiesOnly yes

Host staging
    HostName staging.example.com
    User deploy

# server raggiungibile solo passando da un bastion
Host db-interno
    HostName 10.0.0.5
    User admin
    ProxyJump produzione

# impostazioni valide per tutti gli host: vanno in FONDO, perché per ogni opzione vince la prima occorrenza trovata
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
```
```bash
ssh produzione                    # invece di: ssh -p 2222 -i ~/.ssh/id_ed25519_lavoro deploy@203.0.113.10
scp file.sql db-interno:/tmp/     # gli alias valgono anche per scp, rsync, git
ssh -G produzione                 # mostra la configurazione finale che ssh userebbe per quell'host
```
`ServerAliveInterval` manda un segnale ogni 60 secondi: evita le disconnessioni per inattività.
`IdentitiesOnly yes` usa solo la chiave indicata. Senza, ssh le prova tutte e alcuni server chiudono dopo troppi tentativi.

## Copiare file
```bash
scp file.txt utente@server:/tmp/              # da locale a remoto
scp utente@server:/var/log/app.log .          # da remoto a locale
scp -r cartella/ utente@server:/tmp/          # cartella intera
scp -P 2222 file.txt utente@server:/tmp/      # porta: -P MAIUSCOLA (in ssh è -p minuscola)
sftp utente@server                            # sessione interattiva: ls, cd, get, put, lcd, lls
```
Per cartelle grandi o copie ripetute meglio `rsync`, che trasferisce solo le differenze:
vedi [../02-file-e-permessi/07-diff-e-rsync.md](../02-file-e-permessi/07-diff-e-rsync.md).

## Tunnel (port forwarding)
```bash
ssh -L 3307:127.0.0.1:3306 produzione -N   # LOCAL: la porta 3307 del mio PC porta al MySQL del server (in ascolto solo su 127.0.0.1)
                                           # poi mi collego con HeidiSQL/DBeaver a 127.0.0.1:3307. -N: nessuna shell, solo tunnel
ssh -L 8080:10.0.0.5:80 produzione -N      # UGUALE verso una terza macchina raggiungibile solo dal server
ssh -R 9000:127.0.0.1:8000 server -N       # REMOTE: la porta 9000 del SERVER porta al mio localhost:8000 (mostrare in giro un sito di sviluppo)
ssh -D 1080 produzione -N                  # DYNAMIC: proxy SOCKS sulla 1080, il browser naviga "come se fosse" il server
ssh -fNL 3307:127.0.0.1:3306 produzione    # -f: va in background dopo l'autenticazione
```

## Esempi pratici
```bash
for h in web1 web2 db1; do                  # lo stesso comando su più server
    echo "== $h"; ssh -n "$h" 'uptime; df -h / | tail -1'  # -n: ssh non legge lo stdin (vedi il problema dei cicli while read)
done

ssh produzione 'mysqldump --single-transaction app | gzip' > app_$(date +%F).sql.gz # dump remoto salvato in locale, senza file sul server
ssh produzione 'tail -f /var/www/app/storage/logs/laravel.log' | grep --line-buffered ERROR # seguo il log remoto filtrando in locale
diff <(ssh web1 cat /etc/nginx/nginx.conf) <(ssh web2 cat /etc/nginx/nginx.conf) # confronto configurazioni tra server

ssh produzione 'bash -s' < script_locale.sh          # esegue sul server uno script che ho solo in locale
ssh produzione 'bash -s -- arg1 arg2' < script.sh    # UGUALE passandogli degli argomenti ($1, $2 nello script)
```

### Riuso della connessione (multiplexing)
La prima connessione resta aperta e le successive la riusano: niente nuova autenticazione, molto più veloce
(utile con Ansible, rsync ripetuti, git). In `~/.ssh/config`:
```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```
```bash
ssh -O check produzione           # la connessione master è attiva?
ssh -O exit produzione            # la chiude
```

Vedi anche: [02-firewall-e-hardening.md](02-firewall-e-hardening.md) per mettere in sicurezza il server SSH.
