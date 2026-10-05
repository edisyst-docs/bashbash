# Sicurezza del sistema: AppArmor, SELinux, auditd, lynis, ClamAV

> **Laboratorio**: `./lab.sh 08`, poi `ssh edoardo@staging`. Cosa funziona nel container e cosa no: [lab/](lab/).

[02-firewall-e-hardening.md](02-firewall-e-hardening.md) chiude le porte e mette in sicurezza `sshd`. Qui si guarda **dentro** la macchina, con quattro strumenti
che rispondono a quattro domande diverse:

| Domanda | Strumento | Cosa fa |
|---|---|---|
| "Anche se il programma è compromesso, cosa può toccare?" | **AppArmor** (Ubuntu, Debian, SUSE) / **SELinux** (RHEL, Fedora) | *Mandatory Access Control*: un profilo dice a ogni programma quali file e risorse può usare, e vale anche per `root` |
| "Chi ha toccato quel file, e quando?" | **auditd** | registra gli eventi del kernel (accessi a file, comandi eseguiti) in un log |
| "Il server è configurato bene?" | **lynis** | controlla la configurazione, dà un punteggio e una lista di cose da migliorare |
| "Ci sono file infetti?" | **ClamAV** | antivirus: utile dove passano file di altri (upload, posta, condivisioni) |

Gli esempi con AppArmor e auditd sono stati eseguiti su Ubuntu 24.04 (kernel 6.17), `lynis` e ClamAV nel laboratorio. **SELinux non è stato provato**: Ubuntu non
lo ha attivo, e lì si è verificato solo che `getenforce` risponde `Disabled`; i comandi sono quelli standard di RHEL e sono segnati come tali.

## Perché non basta `chmod`
I permessi Unix ([../03-permessi/](../02-file-e-permessi/08-permessi.md)) sono *discrezionali*: chi possiede un file decide chi lo legge, e `root` ignora tutto. Se `nginx` ha una falla e
un attaccante ottiene una shell con i suoi privilegi, può leggere tutto ciò che `nginx` può leggere. Un sistema **MAC** aggiunge una seconda regola, decisa dall'amministratore
e non dal proprietario: "`nginx` legge `/var/www` e `/etc/nginx`, e nient'altro, nemmeno se è root". Le due regole si sommano: l'accesso passa solo se le approvano entrambe.

## AppArmor (Ubuntu, Debian)
È attivo di default su Ubuntu. Funziona per **percorso**: un profilo è legato a un eseguibile (`/usr/sbin/mysqld`) e dice cosa quel processo può fare.
```bash
sudo aa-status                              # i profili caricati e in quale modo
# apparmor module is loaded.
# 123 profiles are loaded.
# 28 profiles are in enforce mode.
#    /usr/bin/man
#    /usr/sbin/mysqld ...
cat /sys/module/apparmor/parameters/enabled # Y
ls /etc/apparmor.d                          # un file per profilo: usr.sbin.mysqld, usr.bin.man...
sudo apt install apparmor-utils             # aa-complain, aa-enforce, aa-logprof, aa-unconfined
```
Due modi per ogni profilo:
- **enforce**: quello che il profilo non permette viene **negato** e registrato
- **complain**: viene **permesso** e registrato soltanto. Serve per scrivere un profilo nuovo senza rompere il programma

### Un profilo da zero
Per vedere l'effetto si usa una copia di `cat`, così il profilo non tocca quello di sistema:
```bash
sudo cp /usr/bin/cat /usr/local/bin/mycat
sudo tee /etc/apparmor.d/usr.local.bin.mycat <<'EOF'
abi <abi/4.0>,
include <tunables/global>

/usr/local/bin/mycat {
  include <abstractions/base>      # le librerie e i file che ogni programma usa
  /etc/hostname r,                 # può leggere questo
  /etc/passwd r,                   # e questo
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.mycat      # carica (o ricarica) il profilo nel kernel
sudo aa-status | grep mycat                                      #    /usr/local/bin/mycat
```
Il nome del file segue il percorso dell'eseguibile con i punti al posto delle `/`: è una convenzione, non un obbligo.

Ora il programma fa solo quello che il profilo dice, **anche come `root`**:
```bash
sudo /usr/local/bin/mycat /etc/hostname      # runnervm8df0l
sudo /usr/local/bin/mycat /etc/shadow        # /usr/local/bin/mycat: /etc/shadow: Permission denied
sudo cat /etc/shadow | head -1               # root:*:...   <- il vero cat non ha profilo: legge
```
Il rifiuto si legge nel log. Con `auditd` attivo finisce in `/var/log/audit/audit.log`, altrimenti nel journal del kernel (`journalctl -k`):
```bash
sudo ausearch --input-logs -m AVC | tail -2         # --input-logs: vedi il trabocchetto in auditd
# type=AVC msg=audit(...): apparmor="DENIED" operation="open" class="file" profile="/usr/local/bin/mycat" name="/etc/shadow" pid=3024 comm="mycat" requested_mask="r" denied_mask="r" fsuid=0 ouid=0
```
`operation` è cosa voleva fare, `name` su cosa, `requested_mask` il tipo di accesso (`r` lettura, `w` scrittura, `x` esecuzione).

### Complain, enforce e rimuovere
```bash
sudo aa-complain /usr/local/bin/mycat        # permette e registra (apparmor="ALLOWED")
sudo aa-enforce  /usr/local/bin/mycat        # di nuovo nega
sudo aa-disable  /usr/local/bin/mycat        # spegne il profilo: il programma torna libero
sudo aa-logprof                              # legge i rifiuti dal log e propone le righe da aggiungere al profilo
sudo aa-genprof /usr/local/bin/mycat         # crea un profilo: lo si usa il programma in un altro terminale, poi si sceglie cosa permettere
```
Su un runner di GitHub Actions `aa-complain` e `aa-enforce` si sono fermati con `ERROR: Profile for /opt/microsoft/msedge/msedge exists in ...`:
c'erano due profili per lo stesso eseguibile, un caso di quella macchina. Lo stesso risultato si ottiene con il parser, e così è stato provato:
```bash
sudo apparmor_parser -r -C /etc/apparmor.d/usr.local.bin.mycat     # carica in complain: mycat /etc/shadow ora legge (root:*...)
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.mycat        # carica in enforce
sudo apparmor_parser -R /etc/apparmor.d/usr.local.bin.mycat        # toglie il profilo dal kernel: mycat /etc/shadow legge di nuovo
```
Un file in `/etc/apparmor.d/` resta e viene ricaricato al riavvio; `-R` toglie solo il profilo caricato ora.

Altro che torna utile:
- `sudo aa-unconfined` elenca i processi con una porta aperta e **senza** profilo: sono quelli da guardare per primi
- `cat /proc/self/attr/current` dice il profilo del proprio processo (`unconfined` per una shell)
- i container Docker hanno il profilo `docker-default`: è per questo che i server del laboratorio 08 (con systemd) usano `security_opt: ["apparmor:unconfined"]`,
  perché il profilo vieterebbe il `remount` del cgroup. È una scelta da laboratorio: su un server vero un container senza profilo ha un confine in meno
- `/etc/apparmor.d/local/` è il posto per le aggiunte a un profilo di sistema, che resistono agli aggiornamenti del pacchetto

## SELinux (RHEL, Fedora, Rocky, Alma)
> Non provato: Ubuntu usa AppArmor. Su Ubuntu `getenforce` risponde `Disabled`, `sestatus` mostra `SELinux status: disabled` e `ls -Z /etc/passwd` dà `? /etc/passwd`
> (nessuna etichetta). I comandi sotto sono quelli standard delle distribuzioni RHEL: vanno provati su una macchina di quella famiglia.

SELinux ragiona per **etichette** (*context*) su file, processi e porte, non per percorsi: `utente:ruolo:tipo:livello`. Quello che conta è il **tipo**:
`httpd_t` per il processo di Apache, `httpd_sys_content_t` per i file che può servire. La regola è del tipo "`httpd_t` può leggere `httpd_sys_content_t`".
```bash
getenforce                         # Enforcing | Permissive | Disabled
sudo setenforce 0                  # Permissive fino al riavvio: logga e non blocca (come "complain")
sudo setenforce 1                  # di nuovo Enforcing
sudo vi /etc/selinux/config        # SELINUX=enforcing|permissive|disabled: vale dal riavvio
ls -Z /var/www/html                # unconfined_u:object_r:httpd_sys_content_t:s0 index.html
ps -eZ | grep httpd                # system_u:system_r:httpd_t:s0 1234 ? nginx...
```
Il problema più comune è un file con l'etichetta sbagliata: copiato o spostato da un'altra parte (con `mv` l'etichetta resta quella di prima), Apache riceve `403` anche con i permessi giusti.
```bash
sudo ausearch -m AVC -ts recent    # i rifiuti: avc: denied { read } for ... scontext=...httpd_t tcontext=...user_home_t
sudo restorecon -Rv /var/www/html  # rimette le etichette previste dal sistema per quel percorso
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/sito(/.*)?"   # dice al sistema che /srv/sito è contenuto web
sudo restorecon -Rv /srv/sito                                        # e lo applica (semanage da solo non cambia i file)
sudo semanage port -a -t http_port_t -p tcp 8888                     # permette ad Apache una porta non standard
sudo setsebool -P httpd_can_network_connect on                       # un "interruttore" (boolean); -P lo rende permanente
getsebool -a | grep httpd
sudo dnf install policycoreutils-python-utils setroubleshoot-server  # semanage, audit2why, sealert
sudo ausearch -m AVC -ts recent | audit2why                          # spiega il rifiuto e suggerisce il boolean o il comando
```
**Non si disattiva SELinux** per risolvere un `403`: `setenforce 0` per capire se è lui il colpevole (se l'errore sparisce, lo è), poi si corregge l'etichetta o il boolean e si riattiva.

| | AppArmor | SELinux |
|---|---|---|
| lega le regole a | percorso del file eseguibile | etichetta (tipo) di processi, file, porte |
| curva di apprendimento | bassa: un profilo è un file di testo leggibile | alta, ma copre più cose (porte, utenti, ruoli) |
| quando sbaglia | `apparmor="DENIED"` nel log | `avc: denied` nel log |
| "modalità prova" | `aa-complain` | `setenforce 0` (Permissive) |
| distribuzioni | Ubuntu, Debian, SUSE | RHEL, Fedora, Rocky, Alma |

## auditd: chi ha fatto cosa
`auditd` riceve gli eventi dal sottosistema *audit* del kernel e li scrive in `/var/log/audit/audit.log`. Non blocca niente: **registra**. Serve a ricostruire dopo un
incidente (o una modifica sospetta) chi ha toccato un file o lanciato un comando.
```bash
sudo apt install auditd                    # RHEL: già installato (audit)
sudo systemctl enable --now auditd
sudo auditctl -s                           # enabled 1, pid ...: il kernel sta registrando
```
> **Nei container non funziona**: l'audit è del kernel, uno solo per tutta la macchina, e il container non può configurarlo (`auditctl: Error sending status request (Operation not permitted)`,
> anche con `CAP_AUDIT_CONTROL`). Per questo gli esempi sotto non sono nel laboratorio.

### Regole
Due tipi: `-w` (*watch*) su un file o una cartella, e `-a` su una chiamata di sistema.
```bash
sudo auditctl -w /etc/passwd -p wa -k passwd           # -p: w scrittura, a cambio attributi (r lettura, x esecuzione); -k: un'etichetta per cercare
sudo auditctl -w /etc/ssh/sshd_config -p r -k sshd-letto
sudo auditctl -a always,exit -F arch=b64 -S execve -F path=/usr/bin/whoami -k whoami    # ogni esecuzione di whoami
sudo auditctl -l                                       # le regole attive
# -w /etc/passwd -p wa -k passwd
# -w /etc/ssh/sshd_config -p r -k sshd-letto
# -a always,exit -F arch=b64 -S execve -F path=/usr/bin/whoami -F key=whoami
sudo auditctl -W /etc/passwd -p wa -k passwd           # toglie una regola (le stesse opzioni con -W)
sudo auditctl -D                                       # le toglie tutte
```
Le regole di `auditctl` **spariscono al riavvio**. Quelle permanenti stanno in `/etc/audit/rules.d/*.rules`, caricate da `augenrules`:
```bash
sudo tee /etc/audit/rules.d/50-kb.rules <<'EOF'
-w /etc/passwd -p wa -k passwd
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root-cmd
EOF
sudo augenrules --load                                 # ricostruisce /etc/audit/audit.rules e le carica
sudo auditctl -l
# -w /etc/passwd -p wa -k passwd
# -w /etc/sudoers -p wa -k sudoers
# -w /etc/sudoers.d -p wa -k sudoers
# -a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -F key=root-cmd
```
L'ultima regola registra ogni comando eseguito da root da parte di un utente che ha fatto il login (`auid` è l'utente **originale**, anche dopo `sudo`): è la domanda "chi era
davvero?" a cui `who` e il log di `sudo` rispondono solo in parte. `auid!=unset` esclude i processi senza login (servizi).

### Cercare gli eventi
```bash
sudo useradd -m prova
sudo ausearch --input-logs -k passwd -i | tail -9
# type=PROCTITLE msg=audit(10/05/26 13:46:01.613:174) : proctitle=useradd -m prova
# type=PATH msg=audit(...) : item=4 name=/etc/passwd inode=89100 ... nametype=CREATE
# type=PATH msg=audit(...) : item=3 name=/etc/passwd inode=89949 ... nametype=DELETE
# type=SYSCALL msg=audit(...) : arch=x86_64 syscall=rename success=yes exit=0 ... auid=unset uid=root ... comm="useradd" exe="/usr/sbin/useradd" key=passwd
```
Un evento è un gruppo di righe con lo stesso numero (`:174`): `PROCTITLE` il comando, `PATH` il file, `SYSCALL` il chi (`uid`, `auid`, `exe`) e la chiamata. Qui `useradd`
ha **riscritto** `/etc/passwd` con un `rename`, e per questo la regola `-w` l'ha visto.

| Opzione | Cosa fa |
|---|---|
| `-k chiave` | solo gli eventi di quella regola |
| `-i` | traduce numeri in nomi (`uid=root`, `syscall=rename`, date leggibili) |
| `-m TIPO` | per tipo: `AVC`, `USER_CMD` (un `sudo`), `USER_LOGIN`, `SYSCALL`... |
| `-ts recent` / `today` / `10:30` | da quando |
| `-ui UID` / `-ua AUID` | per utente (effettivo / originale) |
| `-x /usr/bin/whoami` | per eseguibile |

> **Trabocchetto**: `ausearch` e `aureport` leggono **da stdin** se non sono collegati a un terminale (da `cron`, da un workflow, con `< /dev/null`): `ausearch -k passwd`
> dà allora `<no matches>` anche con eventi nel log. Negli script si aggiunge sempre **`--input-logs`**.

Il riepilogo con `aureport`:
```bash
sudo aureport --input-logs --summary | head -8
# Summary Report
# Range of time in logs: 10/05/26 13:45:59.048 - 10/05/26 13:47:21.592
# Number of changes in configuration: 6
# Number of changes to accounts, groups, or roles: 3
# Number of logins: 0
sudo aureport --input-logs -k --summary
# 3  passwd
# 2  sshd-letto
# 2  whoami
sudo aureport --input-logs -f -i --summary      # i file più toccati
sudo aureport --input-logs -x --summary         # gli eseguibili
sudo aureport --input-logs --auth -i            # gli accessi (login, sudo, su), riusciti e no
```

### Il log e la configurazione
- `/etc/audit/auditd.conf`: `max_log_file` (MB), `max_log_file_action = ROTATE`, `num_logs`, `flush = INCREMENTAL_ASYNC` (scrive ogni 50 eventi, quindi gli ultimi possono comparire con
  qualche secondo di ritardo; `SYNC` scrive subito, più lento)
- il log cresce: una regola come `-S execve` su tutto lo riempie in fretta. Si scrivono regole **precise** (un file, un utente, un percorso), non "tutto"
- `sudo auditctl -e 2` rende le regole **immutabili** fino al riavvio: `auditctl -w ...` risponde `The audit system is in immutable mode, no rule changes allowed`, e anche chi ottiene root non
  può spegnere l'audit. In genere è l'ultima riga del file delle regole (`-e 2`); si cambiano solo riavviando

## lynis: il controllo della configurazione
`lynis` legge il sistema (non lo modifica) e produce un elenco di avvisi e suggerimenti, con un punteggio finale, l'*hardening index*.
```bash
sudo apt install lynis                       # Ubuntu 24.04: 3.0.9; per l'ultima versione c'è il repository del progetto
sudo lynis audit system --quick --no-colors  # --quick: senza le pause tra una sezione e l'altra
#   Hardening index : 62 [############        ]
#   Tests performed : 268
#   Warnings (2):  Suggestions (55):
```
Il report completo è in `/var/log/lynis-report.dat`, il dettaglio di ogni test in `/var/log/lynis.log`:
```bash
grep '^warning\[\]'    /var/log/lynis-report.dat         # cosa è sbagliato
# warning[]=NETW-2705|Couldn't find 2 responsive nameservers|-|-|
# warning[]=FIRE-4512|iptables module(s) loaded, but no rules active|-|-|
grep '^suggestion\[\]' /var/log/lynis-report.dat | head -3
# suggestion[]=DEB-0280|Install libpam-tmpdir to set $TMP and $TMPDIR for PAM sessions|-|-|
# suggestion[]=DEB-0811|Install apt-listchanges to display any significant changes prior to any upgrade via APT.|-|-|
sudo lynis show details SSH-7440                         # il perché di un controllo (qui: AllowUsers non impostato)
sudo lynis audit system --tests-from-group ssh --quick   # solo un gruppo di test
```
Il punteggio sale applicando i suggerimenti. Nel laboratorio, su `staging`, con le righe di hardening di `sshd` del file [02-firewall-e-hardening.md](02-firewall-e-hardening.md)
(`PermitRootLogin no`, `AllowTcpForwarding no`, `ClientAliveCountMax 2`, `MaxAuthTries 3`, `X11Forwarding no`, `AllowUsers deploy edoardo`) l'indice è passato da **62 a 66**: un controllo
non vale come garanzia, ma dice **dove guardare**.

Da sapere:
- molti suggerimenti non si applicano a ogni server (`DEB-0280` non serve a un container): non si insegue il 100%. Per escludere un test: `skip-test=DEB-0280` in `/etc/lynis/custom.prf`
- nel container i due avvisi sopra (`nameservers`, `iptables`) sono del laboratorio, non del sistema
- `lynis` segnala che la sua versione ha più di 4 mesi (`LYNIS`): è il pacchetto della distribuzione, non un errore del server
- si lancia ogni tanto (o da un timer systemd) e si confrontano gli indici: se cala dopo una modifica, la modifica ha peggiorato qualcosa

## ClamAV: antivirus per file
Su un server Linux il malware raramente "si esegue da solo": il caso vero è il server che **tiene o inoltra file di altri** (upload del sito, allegati di posta, cartelle Samba). Lì ClamAV ha senso.
```bash
sudo apt install clamav clamav-daemon        # clamscan (a richiesta) e clamd (demone), con le firme in /var/lib/clamav
# l'installazione scarica le firme (~110 MB: main.cvd, daily.cvd, bytecode.cvd) con freshclam
freshclam --version                          # ClamAV 1.5.4/28144/...: motore/versione delle firme
```
`clamav-freshclam` aggiorna le firme da solo (`Checks 24` in `freshclam.conf`: 24 controlli al giorno); per una prova manuale: `sudo systemctl stop clamav-freshclam && sudo freshclam`.

### Provarlo senza un virus: EICAR
Il file di prova **EICAR** non è un virus, ma una stringa che ogni antivirus riconosce. Si crea al momento (committarlo nel repository farebbe scattare l'antivirus del PC):
```bash
mkdir -p /srv/prova && cd /srv/prova
printf %s 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar.txt
echo ciao > ok.txt
clamscan -r /srv/prova
# /srv/prova/eicar.txt: Eicar-Test-Signature FOUND
# /srv/prova/ok.txt: OK
#
# ----------- SCAN SUMMARY -----------
# Known viruses: 3628118
# Engine version: 1.5.4
# Scanned files: 2
# Infected files: 1
# Time: 7.113 sec (0 m 7 s)
echo $?                                      # 1 = trovato un file infetto, 0 = pulito, 2 = errore
```
| Opzione di `clamscan` | Cosa fa |
|---|---|
| `-r` | ricorsivo |
| `-i` | mostra solo i file infetti |
| `--move=/var/quarantena` | sposta l'infetto (la cartella deve esistere: `action_setup: Failed to get realpath of /var/quarantena`) |
| `--remove` | **cancella** l'infetto (`Removed.`): rischioso su falsi positivi, meglio `--move` |
| `--log=/var/log/clamscan.log` | scrive anche in un file |
| `--exclude-dir='^/srv/prova/ok'` | esclude i percorsi che corrispondono alla regex |

### clamd e clamdscan: costo di avvio contro memoria
`clamscan` carica **ogni volta** tutte le firme: quasi 7 secondi anche per due file. Con `clamd` le firme restano in memoria e `clamdscan` risponde subito, a prezzo della RAM:
```bash
sudo systemctl start clamav-daemon           # alla prima partenza carica le firme: aspettare che esista il socket
ls /var/run/clamav/clamd.ctl
ps -o rss,cmd -C clamd                       # 995492 /usr/sbin/clamd --foreground=true   <- circa 1 GB
clamdscan --fdpass /srv/prova                # --fdpass: passa il file a clamd, che gira come utente clamav e potrebbe non leggerlo
# /srv/prova/eicar.txt: Eicar-Test-Signature FOUND
```
**Quasi 1 GB di RAM** solo per tenere pronto il demone: su un server piccolo si usa `clamscan` da un timer (di notte) e non `clamd`. Su un server di posta o con molti upload, `clamd` conviene.

### Una scansione notturna
Come per il backup ([../06-sistema/11-backup/](../06-sistema/11-backup/)), si usa un timer o `cron` con un percorso preciso, una quarantena e un log:
```bash
sudo mkdir -p /var/quarantena
# /etc/cron.d/clamscan  (cron ha un PATH minimo: percorsi assoluti)
30 3 * * * root /usr/bin/clamscan -ri --move=/var/quarantena --log=/var/log/clamscan.log /srv/uploads /home
```
Poi si guarda il log (`grep FOUND /var/log/clamscan.log`) o si manda una mail. Un antivirus che nessuno legge non protegge.

Limiti: ClamAV trova **malware noto** (e firme per webshell PHP e documenti con macro), non un attacco nuovo né una configurazione sbagliata. È un livello in più, non il sostituto di AppArmor, aggiornamenti e firewall.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| un programma funziona da solo e non da servizio, o dà `Permission denied` con permessi giusti | AppArmor (o SELinux) lo nega | `sudo ausearch --input-logs -m AVC`, oppure `journalctl -k \| grep DENIED`; si estende il profilo (`aa-logprof`) o si usa `complain` per capire |
| dopo una modifica a un profilo non cambia niente | non è stato ricaricato | `sudo apparmor_parser -r /etc/apparmor.d/...` |
| in `/var/log/audit/audit.log` mancano gli ultimi eventi | `flush = INCREMENTAL_ASYNC`: scrive ogni 50 | qualche secondo, oppure `flush = SYNC` in `auditd.conf` |
| `ausearch` non trova nulla da script, a mano sì | stdin non è un terminale | `ausearch --input-logs ...` |
| `auditctl: Error sending status request (Operation not permitted)` | in un container, o senza root | l'audit è del kernel: va fatto sulla macchina |
| `The audit system is in immutable mode, no rule changes allowed` | è stato impostato `-e 2` | riavviare; per cambiare regole, togliere `-e 2` dal file |
| il disco si riempie per `/var/log/audit` | regole troppo larghe | restringerle; `max_log_file` e `num_logs` limitano lo spazio |
| `403` con permessi giusti su RHEL | etichetta SELinux sbagliata | `ausearch -m AVC`, `restorecon -Rv`, `semanage fcontext` |
| `clamscan` ci mette secondi anche per un file | carica tutte le firme a ogni avvio | normale; per molti scan `clamd` + `clamdscan` |
| `clamdscan`: `Can't open file or directory` | `clamd` (utente `clamav`) non legge il file | `clamdscan --fdpass` |
| `lynis` dà "Couldn't find 2 responsive nameservers" in un container | il laboratorio, non il sistema | ignorare |
