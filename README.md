# bashbash

Knowledge base personale su bash, comandi da terminale Linux e scripting Windows.

Cartelle e file sono numerati nell'ordine in cui conviene studiarli: si parte da `01-basi/01-shell.md`
e si prosegue in ordine. Le cartelle `zz-` non sono tappe del percorso, sono materiale di supporto.
Ogni cartella ha il proprio `README.md` con l'indice dei suoi file.

## Percorso di studio

### [01-basi/](01-basi/) — la shell interattiva
Come muoversi nel terminale, trovare i comandi, concatenarli.

1. [shell](01-basi/01-shell.md) — quale shell sto usando, sottoshell, `exec`
2. [shortcut](01-basi/02-shortcut.md) — scorciatoie da tastiera
3. [help e manuali](01-basi/03-help-e-manuali.md) — `man`, `info`, `help`, `apropos`, `$PATH`
4. [comandi base](01-basi/04-comandi-base.md) — `ls`, `stat`, `mv`, `pwd`, `echo`
5. [alias](01-basi/05-alias.md) — `alias`, `type`, `unalias`
6. [history](01-basi/06-history.md) — `history`, `!!`, `!$`, `fc`
7. [concatenazioni](01-basi/07-concatenazioni.md) — `&&`, `||`, `;`, `{}`, `()`
8. [pipeline](01-basi/08-pipeline.md) — `|`, `|&`, `xargs`, `cat`
9. [file di avvio](01-basi/09-file-di-avvio.md) — `.bashrc`, `.profile`, login e non-login, `PATH`, `PS1`

### [02-file-e-permessi/](02-file-e-permessi/) — operare sui file
Creare, cercare, trasferire file e decidere chi può farlo.

1. [file base](02-file-e-permessi/01-file-base.md) — `touch`, `cp`, `rm`, `mkdir`, `wc`, `tree`
2. [find](02-file-e-permessi/02-find.md) — `find`, `-exec`, `locate`
3. [archivi e compressione](02-file-e-permessi/03-archivi-compressione.md) — `tar`, `gzip`, `xz`
4. [link](02-file-e-permessi/04-link.md) — link simbolici, hard link, inode
5. [redirezioni](02-file-e-permessi/05-redirezioni.md) — `>`, `2>`, `tee`, here-doc, file descriptor
6. [dd](02-file-e-permessi/06-dd.md) — copia a basso livello di file e partizioni
7. [diff e rsync](02-file-e-permessi/07-diff-e-rsync.md) — `diff`, `patch`, `rsync`
8. [permessi](02-file-e-permessi/08-permessi.md) — notazione ottale, `chmod`, bit speciali, `umask`
9. [proprietari](02-file-e-permessi/09-proprietari.md) — `chown`, `chgrp`, gruppi condivisi

### [03-testo-e-regex/](03-testo-e-regex/) — cercare e trasformare testo
Gli strumenti che userai dentro ogni script.

1. [stampa e taglia](03-testo-e-regex/01-stampa-e-taglia.md) — `head`, `tail`, `sort`, `cut`, `awk`, `tr`, `split`
2. [grep](03-testo-e-regex/02-grep.md) — ricerca in file e pipeline
3. [regex](03-testo-e-regex/03-regex.md) — BRE ed ERE
4. [sed](03-testo-e-regex/04-sed.md) — stream editor, gruppi di cattura
5. [vim](03-testo-e-regex/05-vim.md) — i 4 modi e i comandi di ciascuno

### [04-processi/](04-processi/) — cosa gira e quanto consuma
1. [ps e kill](04-processi/01-ps-e-kill.md) — `ps`, `pgrep`, segnali, `lsof`
2. [jobs](04-processi/02-jobs.md) — `&`, `CTRL+Z`, `fg`, `bg`, `nohup`
3. [top e htop](04-processi/03-top-htop.md) — monitoraggio interattivo
4. [risorse](04-processi/04-risorse.md) — `free`, `du`, `df`, `nice`/`renice`, `/proc`

### [05-scripting/](05-scripting/) — scrivere script bash
Ogni argomento ha il suo `.md` e, dove esiste, lo script di prova con lo stesso numero.

1. [basi scripting](05-scripting/01-basi-scripting.md) — i 4 modi di lanciare uno script, scheletro di script robusto
2. [variabili](05-scripting/02-variabili.md) — `declare`, `export`, `unset`
3. [parametri](05-scripting/03-parametri.md) — `$0`, `$1`, `$#`, `$@`, `$?`, parsing opzioni, `getopts`
4. [condizioni](05-scripting/04-condizioni.md) — `test`, `if`, `case`
5. [cicli](05-scripting/05-cicli.md) — `while`, `until`, `for`, `select`
6. [array](05-scripting/06-array.md) — indicizzati e associativi
7. [input e read](05-scripting/07-input-read.md) — `read` e `IFS`
8. [espansioni](05-scripting/08-espansioni.md) — le 9 espansioni, nel loro ordine
9. [altro interprete](05-scripting/09-altro-interprete.md) — shebang
10. [quoting](05-scripting/10-quoting.md) — apici singoli, doppi, `$'...'`, `printf`
11. [funzioni](05-scripting/11-funzioni.md) — argomenti, valori di ritorno, `local`, librerie
12. [trap e debug](05-scripting/12-trap-e-debug.md) — `trap`, `set -Eeuo pipefail`, `bash -x`, `shellcheck`

### [06-sistema/](06-sistema/) — amministrazione della macchina
1. [filesystem](06-sistema/01-filesystem.md) — la struttura di Debian/Ubuntu, cartella per cartella
2. [utenti](06-sistema/02-utenti.md) — `id`, `adduser`, `passwd`, `su`, `sudo`, `runuser`
3. [pacchetti apt](06-sistema/03-pacchetti-apt.md) — `apt`, `apt-get`, `apt-cache`, `dpkg`, `apt-mark`
4. [dischi](06-sistema/04-dischi.md) — `mount`, `lsblk`, `blkid`, `fstab`, swap
5. [data e ora](06-sistema/05-data-e-ora.md) — `date`, `cal`, `uptime`, timezone
6. [rete e host](06-sistema/06-rete-e-host.md) — `hostname`, `ip`, `ss`, `dig`, `curl`, diagnostica di rete
7. [servizi](06-sistema/07-servizi.md) — `systemctl`, `journalctl`, unit e timer systemd, `shutdown`
8. [tmux](06-sistema/08-tmux.md) — sessioni, finestre, pane
9. [crontab](06-sistema/09-crontab.md) — schedulare comandi ricorrenti, backup con rotazione
10. [logrotate](06-sistema/10-logrotate/) — rotazione dei log, con script e configurazione

### [07-windows/](07-windows/) — batch e PowerShell
1. [batch](07-windows/01-batch.md) — sintassi `.bat`, con esempi completi
2. [powershell](07-windows/02-powershell.md) — cmdlet per servizi, processi, rete
3. [esempi .bat](07-windows/03-esempi/) — script funzionanti: backup, clone Laravel, pulizia, menu
4. [powershell scripting](07-windows/04-powershell-scripting.md) — variabili, condizioni, cicli, funzioni con `param()`, errori
5. [WSL e winget](07-windows/05-wsl-e-winget.md) — gestione di WSL, interoperabilità, configurazione, `winget`
6. [CMD rete e sistema](07-windows/06-cmd-rete-e-sistema.md) — `ipconfig`, `tracert`, `netstat`, `netsh`, `tasklist`, `net`, `systeminfo`

### [08-remoto-e-sicurezza/](08-remoto-e-sicurezza/) — server remoti
1. [ssh](08-remoto-e-sicurezza/01-ssh.md) — chiavi, `~/.ssh/config`, `scp`, `sftp`, tunnel, multiplexing, WinSCP
2. [firewall e hardening](08-remoto-e-sicurezza/02-firewall-e-hardening.md) — `ufw`, sshd, `fail2ban`, aggiornamenti automatici
3. [gpg](08-remoto-e-sicurezza/03-gpg.md) — cifrare e firmare file, chiavi pubbliche e private

### [09-strumenti/](09-strumenti/) — CLI di uso quotidiano
1. [jq e curl](09-strumenti/01-jq-e-curl.md) — API e JSON da terminale, download con `wget`
2. [git](09-strumenti/02-git.md) — storia, `stash`, `reflog`, `bisect`, hook
3. [mysql](09-strumenti/03-mysql.md) — `mysql`, `mysqldump`, ripristino, diagnostica

### [10-rete-e-web/](10-rete-e-web/) — reti e web server
1. [indirizzi e configurazione](10-rete-e-web/01-indirizzi-e-configurazione.md) — CIDR e subnet, `ip addr`/`ip route`, netplan, da `ifconfig` a `ip`
2. [diagnostica](10-rete-e-web/02-diagnostica.md) — `traceroute`, `mtr`, `dig +trace`, `whois`, `tcpdump`, `nc`, `nmap`
3. [namespace](10-rete-e-web/03-namespace.md) — laboratorio: più host su una sola macchina con `ip netns`
4. [apache e nginx](10-rete-e-web/04-apache-nginx.md) — siti, moduli, virtual host, Laravel con PHP-FPM, reverse proxy, HTTPS con `certbot`
5. [load balancer](10-rete-e-web/05-load-balancer/) — laboratorio Docker con HAProxy, Nginx, Caddy, Envoy, Traefik

### [11-container-e-automazione/](11-container-e-automazione/) — container, orchestrazione, CI/CD e infrastruttura come codice
1. [docker](11-container-e-automazione/01-docker.md) — CLI: `run`, `exec`, `logs`, immagini, pulizia, porte, policy riavvio
2. [dockerfile](11-container-e-automazione/02-dockerfile/) — istruzioni, layer, cache, multi-stage; esempi nginx / python / flask / node
3. [volumi e reti](11-container-e-automazione/03-volumi-e-reti.md) — volumi, bind mount, bridge, host, DNS interno, NAT
4. [compose](11-container-e-automazione/04-compose/) — `compose.yaml`, healthcheck, init DB; lab php+mysql, phpmyadmin, postgres
5. [swarm](11-container-e-automazione/05-swarm/) — cluster, servizi, repliche, aggiornamenti a rotazione, stack
6. [kubernetes](11-container-e-automazione/06-kubernetes/) — cluster locale con kind, `kubectl`, Deployment, Service, ConfigMap, storage, probe, autoscaling, Ingress e Gateway, Helm; 7 laboratori
7. [jenkins](11-container-e-automazione/07-jenkins/) — laboratorio configurato da codice, Jenkinsfile Declarative, 9 pipeline di esempio, API REST e CLI
8. [ansible](11-container-e-automazione/08-ansible/) — inventory, playbook, moduli; laboratorio Docker master→slave
9. [terraform](11-container-e-automazione/09-terraform/) — infrastruttura come codice: HCL, moduli, stato, import; esempi Docker, AWS, Kubernetes

## Supporto (fuori dal percorso)

- **[zz-esempi/](zz-esempi/)** — script completi e funzionanti: la [rubrica](zz-esempi/rubrica/) interattiva e gli [esercizi](zz-esempi/esercizi/) di scripting
- **[zz-risorse/](zz-risorse/)** — [link utili](zz-risorse/link-utili.md), [sintassi Mermaid](zz-risorse/mermaid.md), PDF e cheat sheet di riferimento

## Laboratori: provare i comandi

Le aree 02, 03 e 05 hanno una cartella `lab/` con uno script `prepara.sh` che genera tutti i file che
servono ai comandi dei `.md`: una sottocartella per ogni `.md`, con i nomi di file usati negli esempi.
`lab.sh` lo lancia dentro un container Ubuntu 24.04 usa-e-getta (serve Docker):
```bash
./lab.sh 03               # shell come root in ~/lab, con i file dell'area 03 già pronti
cd 02-grep                # la cartella del .md che sto studiando
grep -i errore logfile.txt

./lab.sh 02 --tester      # UGUALE ma come utente tester (password: tester): per vedere i "Permission denied"
./lab.sh 05 -- 'cd 03-parametri && ./opzioni.sh -n a.txt' # esegue un comando nel laboratorio ed esce
./lab.sh 02 --build       # ricostruisce l'immagine (dopo una modifica al Dockerfile)
```
- La KB è montata in `/kb` in **sola lettura**: nessun esercizio può modificare il repository.
- All'uscita il container sparisce con tutto quello che è stato creato o rovinato. Per ripartire da zero
  senza uscire: `bash /kb/<area>/lab/prepara.sh && cd ~/lab`.
- I file non stanno nel repository perché permessi, link simbolici, bit speciali e date di modifica
  non sopravvivono a git (su Windows i link diventano file di testo). Nel repo resta solo il materiale
  non generabile, in `lab/materiale/`.
- Su Linux si può fare a meno di Docker: `bash 03-testo-e-regex/lab/prepara.sh ~/lab-03`. Lo script
  cancella e ricrea solo una cartella creata da lui (riconosce il file `.lab-bashbash`).
- Se Git Bash su Windows risponde `the input device is not a TTY` (succede nella finestra mintty),
  aprire Git Bash dentro Windows Terminal o nel terminale di VS Code.

## Ambiente di test Ubuntu

Per provare i comandi senza toccare la macchina host, c'è un `Dockerfile` con Ubuntu 24.04 e tutti gli strumenti della KB.
`lab.sh` lo costruisce da solo la prima volta; a mano:

**Build (una tantum):**
```bash
docker build -t bashbash .
```

**Avviare una shell:**
```bash
# monta la KB in /kb, entra come root
docker run --rm -it -v "$(pwd):/kb" bashbash

# oppure come utente tester (password: tester) — utile per testare permessi e sudo
docker run --rm -it -v "$(pwd):/kb" bashbash su - tester
```

**Eseguire un singolo comando:**
```bash
docker run --rm -v "$(pwd):/kb" bashbash bash -c "ls -la /kb"
```

> **Limitazioni:** `systemctl`, `ufw` (come firewall attivo), `mount` di partizioni, `fail2ban` e `ip netns` richiedono init/privilegio che non funzionano in container standard. Per il resto la KB funziona normalmente.

## Trovare un comando
Se non ricordi in che file sta un comando:
```bash
grep -rn "nome_comando" --include="*.md" .
```

## Convenzioni
- Cartelle e file numerati nell'ordine di studio; il prefisso `zz-` marca il materiale di supporto.
- File e cartelle in minuscolo, parole separate da trattino.
- Ogni cartella ha un `README.md` con l'indice dei suoi file.
- In `05-scripting/` e `04-processi/` lo script di prova porta lo stesso numero del `.md` che lo spiega.
- La cartella `lab/` di un'area contiene `prepara.sh` (genera i file del laboratorio, una sottocartella per `.md`), `README.md` (cosa contiene) ed eventualmente `materiale/` (file non generabili).
- Ogni comando ha il suo commento inline sulla stessa riga, allineato.
- `UGUALE` indica una forma alternativa che fa esattamente la stessa cosa del comando sopra.
- Gli script `.sh` sono in LF, i `.bat` e i `.ps1` in CRLF: lo forza il `.gitattributes`.
