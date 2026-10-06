# bashbash

Knowledge base personale su bash, comandi da terminale Linux e scripting Windows.

Cartelle e file sono numerati nell'ordine in cui conviene studiarli: si parte da `01-basi/01-shell.md`
e si prosegue in ordine. Le cartelle `zz-` non sono tappe del percorso, sono materiale di supporto.
Ogni area e ogni cartella con materiale da studiare ha il proprio `README.md` con l'indice dei suoi file; le
sottocartelle di supporto (`app/`, `config/`, `master/`…) sono descritte nel README della cartella che le contiene.

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
6. [esercizi](03-testo-e-regex/06-esercizi.md) — 18 esercizi con verifica automatica su log, CSV, INI e `passwd`

### [04-processi/](04-processi/) — cosa gira e quanto consuma
1. [ps e kill](04-processi/01-ps-e-kill.md) — `ps`, `pgrep`, segnali, `lsof`
2. [jobs](04-processi/02-jobs.md) — `&`, `CTRL+Z`, `fg`, `bg`, `nohup`
3. [top e htop](04-processi/03-top-htop.md) — monitoraggio interattivo
4. [risorse](04-processi/04-risorse.md) — `free`, `du`, `df`, `nice`/`renice`, `/proc`
5. [debug e prestazioni](04-processi/05-debug-e-prestazioni.md) — `strace`, `ltrace`, `ulimit`, cgroup e OOM, `perf`, `vmstat`, `pidstat`

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
11. [backup](06-sistema/11-backup/) — backup con `restic`: snapshot, rotazione, ripristino, timer systemd
12. [storage avanzato](06-sistema/12-storage-avanzato.md) — LVM, RAID con `mdadm`, SMART, automount

### [07-windows/](07-windows/) — batch e PowerShell
1. [batch](07-windows/01-batch.md) — sintassi `.bat`, con esempi completi
2. [powershell](07-windows/02-powershell.md) — cmdlet per servizi, processi, rete
3. [esempi .bat](07-windows/03-esempi/) — script funzionanti: backup, clone Laravel, pulizia, menu
4. [powershell scripting](07-windows/04-powershell-scripting.md) — variabili, condizioni, cicli, funzioni con `param()`, errori
5. [WSL e winget](07-windows/05-wsl-e-winget.md) — gestione di WSL, interoperabilità, configurazione, `winget`
6. [CMD rete e sistema](07-windows/06-cmd-rete-e-sistema.md) — `ipconfig`, `tracert`, `netstat`, `netsh`, `tasklist`, `net`, `systeminfo`
7. [task scheduler](07-windows/07-task-scheduler.md) — `schtasks` e ScheduledTasks: azioni, trigger, codici di uscita
8. [scoop e chocolatey](07-windows/08-scoop-e-chocolatey.md) — altri gestori di pacchetti, a confronto con `winget`
9. [active directory](07-windows/09-active-directory.md) — dominio, utenti e gruppi, LDAP e Kerberos, join, GPO; con un controller di dominio Samba 4

### [08-remoto-e-sicurezza/](08-remoto-e-sicurezza/) — server remoti
1. [ssh](08-remoto-e-sicurezza/01-ssh.md) — chiavi, `~/.ssh/config`, `scp`, `sftp`, tunnel, multiplexing, WinSCP
2. [firewall e hardening](08-remoto-e-sicurezza/02-firewall-e-hardening.md) — `ufw`, sshd, `fail2ban`, aggiornamenti automatici
3. [gpg](08-remoto-e-sicurezza/03-gpg.md) — cifrare e firmare file, chiavi pubbliche e private
4. [vpn wireguard](08-remoto-e-sicurezza/04-vpn-wireguard.md) — tunnel cifrato fra macchine, `wg-quick`, `AllowedIPs`, NAT, `ufw route`
5. [sicurezza del sistema](08-remoto-e-sicurezza/05-sicurezza-sistema.md) — AppArmor, SELinux, `auditd`, `lynis`, ClamAV

### [09-strumenti/](09-strumenti/) — CLI di uso quotidiano
1. [jq e curl](09-strumenti/01-jq-e-curl.md) — API e JSON da terminale, download con `wget`
2. [git](09-strumenti/02-git.md) — storia, `stash`, `reflog`, `bisect`, hook
3. [mysql](09-strumenti/03-mysql.md) — `mysql`, `mysqldump`, ripristino, diagnostica
4. [php](09-strumenti/04-php.md) — installazione, esecuzione al volo, lint, server built-in, Composer
5. [python](09-strumenti/05-python.md) — snippet al volo, `venv`, `pip`, moduli della libreria standard
6. [postgresql](09-strumenti/06-postgresql.md) — `psql`, `pg_dump`/`pg_restore`, diagnostica, utente applicativo
7. [redis](09-strumenti/07-redis.md) — `redis-cli`, chiavi, strutture dati, monitoraggio
8. [make](09-strumenti/08-make.md) — `Makefile`, regole, variabili, `.PHONY`, regole a schema
9. [bats](09-strumenti/09-bats.md) — test degli script bash, `bats-assert`, finti comandi
10. [ricerca veloce](09-strumenti/10-ricerca-veloce.md) — `ripgrep`, `fd`, `fzf`, `bat`, `ncdu`
11. [rabbitmq](09-strumenti/11-rabbitmq.md) — code, exchange, ack, dead letter, API HTTP, `rabbitmqctl`
12. [kafka](09-strumenti/12-kafka.md) — topic, partizioni, offset, consumer group, `kcat`
13. [mongodb](09-strumenti/13-mongodb.md) — `mongosh`, `find`, `aggregate`, indici, utenti, `mongodump`

### [10-rete-e-web/](10-rete-e-web/) — reti e web server
1. [indirizzi e configurazione](10-rete-e-web/01-indirizzi-e-configurazione.md) — CIDR e subnet, `ip addr`/`ip route`, netplan, da `ifconfig` a `ip`
2. [diagnostica](10-rete-e-web/02-diagnostica.md) — `traceroute`, `mtr`, `dig +trace`, `whois`, `tcpdump`, `nc`, `nmap`
3. [namespace](10-rete-e-web/03-namespace.md) — laboratorio: più host su una sola macchina con `ip netns`
4. [apache e nginx](10-rete-e-web/04-apache-nginx.md) — siti, moduli, virtual host, Laravel con PHP-FPM, reverse proxy, HTTPS con `certbot`
5. [load balancer](10-rete-e-web/05-load-balancer/) — laboratorio Docker con HAProxy, Nginx, Caddy, Envoy, Traefik
6. [server dns](10-rete-e-web/06-dns-server.md) — `dnsmasq` e BIND, zone, secondario, `rndc`
7. [posta](10-rete-e-web/07-posta-postfix.md) — Postfix e Dovecot, coda, rimbalzi, alias, IMAP
8. [condivisioni](10-rete-e-web/08-condivisioni-nfs-samba.md) — NFS e Samba, `exports`, `root_squash`, `mount.cifs`
9. [alta disponibilità](10-rete-e-web/09-alta-disponibilita-keepalived.md) — `keepalived`, IP virtuale e failover

### [11-container-e-automazione/](11-container-e-automazione/) — container, orchestrazione, CI/CD e infrastruttura come codice
1. [docker](11-container-e-automazione/01-docker.md) — CLI: `run`, `exec`, `logs`, immagini, pulizia, porte, policy riavvio
2. [dockerfile](11-container-e-automazione/02-dockerfile/) — istruzioni, layer, cache, multi-stage; esempi nginx / python / flask / node
3. [volumi e reti](11-container-e-automazione/03-volumi-e-reti.md) — volumi, bind mount, bridge, host, DNS interno, NAT
4. [compose](11-container-e-automazione/04-compose/) — `compose.yaml`, healthcheck, init DB; lab php+mysql, phpmyadmin, postgres
5. [swarm](11-container-e-automazione/05-swarm/) — cluster, servizi, repliche, aggiornamenti a rotazione, stack
6. [kubernetes](11-container-e-automazione/06-kubernetes/) — cluster locale con kind, `kubectl`, Deployment, Service, ConfigMap, storage, probe, autoscaling, Ingress e Gateway, Helm, NetworkPolicy, cert-manager, CRD e operatori; 10 laboratori
7. [jenkins](11-container-e-automazione/07-jenkins/) — laboratorio configurato da codice, Jenkinsfile Declarative, 9 pipeline di esempio, API REST e CLI
8. [ansible](11-container-e-automazione/08-ansible/) — inventory, playbook, moduli; laboratorio Docker master→slave
9. [terraform](11-container-e-automazione/09-terraform/) — infrastruttura come codice: HCL, moduli, stato, import; esempi Docker, AWS, Kubernetes
10. [gitlab ci](11-container-e-automazione/10-gitlab-ci/) — `.gitlab-ci.yml`, runner, rules, needs, variabili protette, registry, ambienti; laboratorio GitLab CE e `gitlab-ci-local`, 9 pipeline di esempio
11. [argo cd](11-container-e-automazione/11-argocd/) — GitOps: Application, sync automatica, self-heal, rollback con `git revert`, Kustomize e Helm, hook, app of apps, ApplicationSet; laboratorio su kind con registry e Gitea locali
12. [trivy e hadolint](11-container-e-automazione/12-trivy-hadolint/) — lint dei Dockerfile, CVE e segreti nelle immagini, configurazione Kubernetes e Terraform, SBOM; stage nelle pipeline Jenkins e GitLab
13. [github actions](11-container-e-automazione/13-github-actions/) — workflow, matrix, artefatti e cache, servizi, ambienti, segreti e OIDC, riuso, sicurezza, `act`; nove esempi eseguibili e la CI della KB

### [12-osservabilita/](12-osservabilita/) — metriche, log e alert
Sapere come stanno server e servizi prima che se ne accorgano gli utenti.

1. [concetti](12-osservabilita/01-concetti.md) — metriche, log, tracce; pull e push; USE, RED, SLI/SLO
2. [prometheus](12-osservabilita/02-prometheus.md) — installazione, `prometheus.yml`, service discovery, relabeling, API, `promtool`
3. [exporter](12-osservabilita/03-exporter.md) — node_exporter, textfile collector dagli script, blackbox, nginx, database, `/metrics` nelle app
4. [promql](12-osservabilita/04-promql.md) — `rate`, aggregazioni, `group_left`, percentili, query di tutti i giorni
5. [alerting](12-osservabilita/05-alerting.md) — regole e unit test, Alertmanager, inibizioni, silenzi con `amtool`
6. [grafana](12-osservabilita/06-grafana.md) — dashboard, variabili, provisioning da codice, API
7. [loki](12-osservabilita/07-loki.md) — log centralizzati con Loki e Grafana Alloy, LogQL, logcli, alert sui log
8. [tracing](12-osservabilita/08-tracing.md) — OpenTelemetry, Alloy come collector, Tempo e TraceQL, Jaeger, strumentare in Python, campionamento

## Supporto (fuori dal percorso)

- **[zz-esempi/](zz-esempi/)** — script completi e funzionanti: la [rubrica](zz-esempi/rubrica/) interattiva e gli [esercizi](zz-esempi/esercizi/) di scripting
- **[zz-risorse/](zz-risorse/)** — [link utili](zz-risorse/link-utili.md), [sintassi Mermaid](zz-risorse/mermaid.md), PDF e cheat sheet di riferimento

## Laboratori: provare i comandi

**Prerequisiti:** Docker Desktop installato e avviato. Nient'altro.

**Allestimento (una tantum):** la prima volta `./lab.sh <area>` costruisce l'immagine Docker (~1 min); le volte successive parte in pochi secondi.

**Flusso di studio:**
1. Apri il `.md` dell'argomento (es. `02-file-e-permessi/02-find.md`)
2. In un secondo terminale, dalla radice della KB: `./lab.sh 02`
3. Sei in `~/lab` come root — il file è già lì: `cd 02-find`
4. Prova i comandi seguendo il `.md`; puoi rovinare tutto, il container è usa-e-getta
5. `exit` → container e file spariscono; riaprilo per ripartire da zero

---

Le aree 01, 02, 03, 04, 05, 06, 07, 08, 09, 10 e 12, e la cartella `zz-esempi`, hanno una cartella `lab/` con uno script `prepara.sh` che genera tutti i
file che servono ai comandi dei `.md`: una sottocartella per ogni `.md`, con i nomi di file usati negli esempi.
`lab.sh` lo lancia dentro un container Ubuntu 24.04 usa-e-getta (serve Docker). Se l'area ha bisogno di
servizi c'è anche un `lab/compose.yaml`:

| Area | Cosa avvia |
|---|---|
| 04 | un container con limiti veri (256 MB di RAM senza swap, 1 CPU) e `strace`/`perf` abilitati, per OOM killer, throttling e processi appesi |
| 06 | un container con **systemd** come PID 1: `systemctl`, `journalctl`, timer, cron, ssh, nginx, apache2 |
| 07 | un controller di dominio Active Directory (Samba 4, `lab.test`) e un PC con `samba-tool`, `ldapsearch` e `kinit` per amministrarlo ed entrarci |
| 08 | un PC e tre server ssh (`produzione`, `staging`, `db-interno` solo via `ProxyJump`) con ufw e fail2ban; indirizzi fissi e WireGuard per la VPN |
| 09 | MySQL 9.7 con un database popolato, un'API finta su `http://api`, RabbitMQ, Kafka (un broker) e MongoDB, e un progetto di esempio per `make`, `bats` e gli strumenti di ricerca |
| 10 | una rete con un router in mezzo (host, host2, router, web) per `traceroute`, `tcpdump`, `nmap`, namespace, web server, DNS, posta, NFS/Samba e keepalived |
| 12 | Prometheus, Alertmanager, Grafana, Loki, Tempo, Jaeger, Alloy (anche come Collector OpenTelemetry), gli exporter e un server con systemd da monitorare; email degli alert in Mailpit |

I container con systemd non sono `--privileged` e non vedono i dischi della macchina: hanno solo le capability
che servono (`SYS_ADMIN` per systemd, `NET_ADMIN` per rete e firewall) e AppArmor disattivato, perché systemd deve
rendere scrivibile il proprio cgroup. Funzionano con Docker Desktop e su Linux; la CI del repository li avvia tutti a
ogni push ([.github/workflows/kb.yml](.github/workflows/kb.yml)).
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

> **Limitazioni:** in questa shell semplice `systemctl`, `ufw`, `fail2ban` e `ip netns` non funzionano: servono systemd
> e alcune capability. Li hanno i laboratori delle aree 06, 08, 10 e 12 (`./lab.sh 06`). Restano fuori da tutti i
> laboratori il `mount` di partizioni vere e lo swap, che richiederebbero `--privileged`: con quello il container
> vedrebbe i dischi della macchina.

## CI del repository

A ogni push e pull request GitHub Actions esegue [.github/workflows/kb.yml](.github/workflows/kb.yml) (la guida è
in [11-container-e-automazione/13-github-actions/](11-container-e-automazione/13-github-actions/)):

| Job | Cosa controlla |
|---|---|
| `shellcheck` | tutti gli script `.sh` dei laboratori e dell'area 11; restano fuori `05-scripting/*.sh` e gli script di `zz-esempi/esercizi/` e `zz-esempi/rubrica/`, che sono esempi da studiare (alcuni sbagliati apposta); `zz-esempi/lab/` invece è controllato, e il job del laboratorio `zz-esempi` lancia anche `verifica.sh` |
| `hadolint` | tutti i file chiamati `Dockerfile`; blocca da `warning` in su e manda il report completo a *Security > Code scanning* |
| `link` | i link relativi nei `.md` ([.github/scripts/controlla-link.py](.github/scripts/controlla-link.py)): ogni file o cartella indicata deve esistere |
| `laboratorio` | per le aree 02, 03, 04, 05, 06, 08, 09, 10 e 12 lancia `./lab.sh <area>` su Ubuntu 24.04 ed esegue un comando nel laboratorio |

Il resto di `.github/` sono gli esempi della guida: i nove workflow `esempio-*.yml`, l'Action composita
[python-app](.github/actions/python-app/) e il problem matcher di shellcheck. [.hadolint.yaml](.hadolint.yaml) è la
configurazione di Hadolint per tutto il repository (ignora `DL3008`, le versioni fisse in `apt-get install`).
Prima di una pull request si può fare lo stesso controllo in locale: `python3 .github/scripts/controlla-link.py`.

## Trovare un comando
Se non ricordi in che file sta un comando, `grep` (o `rg`, vedi [09-strumenti/10-ricerca-veloce.md](09-strumenti/10-ricerca-veloce.md)) sui `.md` dalla radice della KB. Tre ricerche, dalla più larga alla più mirata
(i risultati sono quelli di questa versione della KB):
```bash
grep -rlw "rsync" --include="*.md" .                          # -l: solo i FILE che ne parlano (12); -w: parola intera
# ./02-file-e-permessi/07-diff-e-rsync.md
# ./02-file-e-permessi/README.md
# ./02-file-e-permessi/lab/README.md
# ...
grep -rnE '^(sudo )?journalctl ' --include="*.md" .           # le righe di CODICE che cominciano per il comando: gli esempi veri (24)
# ./06-sistema/07-servizi.md:36:journalctl -u nginx                # tutti i log del servizio nginx
# ./06-sistema/07-servizi.md:37:journalctl -u nginx -f             # in tempo reale, come tail -f
grep -rnE '^#{1,3} .*\bcron\b' --include="*.md" .             # i TITOLI che nominano l'argomento
# ./01-basi/09-file-di-avvio.md:81:## Perché cron e gli script non vedono i miei alias
# ./06-sistema/07-servizi.md:75:### Timer systemd: alternativa a cron
# ./07-windows/07-task-scheduler.md:1:# Task Scheduler: `cron` di Windows
```
- Senza `-w` la ricerca di `cron` trova anche `sincronizzazione`, e `tar ` finisce dentro `start ` e `restart ` (18 file): per i nomi corti servono `-w` o `btarb`.
- La ricerca dei titoli prende anche i commenti `# ...` dentro i blocchi di codice (nel secondo esempio di `cron`: `# cron usa /bin/sh di default`): i titoli veri sono quelli con `##`.
- Il segnaposto `nome_comando` dei [comandi base](01-basi/04-comandi-base.md) non è un comando: cercarlo trova la sintassi, non un esempio.
- Dentro un laboratorio la KB è in `/kb` (sola lettura): `grep -rlw rsync --include="*.md" /kb`. *(Non provato dalla shell del laboratorio: gli esempi sopra sono stati eseguiti dalla radice del repository.)*

## Convenzioni
- Cartelle e file numerati nell'ordine di studio; il prefisso `zz-` marca il materiale di supporto.
- File e cartelle in minuscolo, parole separate da trattino.
- Ogni area e ogni cartella con materiale da studiare ha un `README.md` con l'indice dei suoi file e, in fondo, un
  link per tornare indietro (`Torna a` per le sottocartelle; area precedente, prossima e indice per le aree).
  Le sottocartelle di supporto sono descritte nel README del padre.
- In `05-scripting/` e `04-processi/` lo script di prova porta lo stesso numero del `.md` che lo spiega.
- La cartella `lab/` di un'area contiene `prepara.sh` (genera i file del laboratorio, una sottocartella per `.md`), `README.md` (cosa contiene) ed eventualmente `materiale/` (file non generabili) e `compose.yaml` (servizi: o un servizio `shell` che `lab.sh` avvia, o una riga `x-lab-entra: NOME` con il servizio in cui entrare).
- Ogni comando ha il suo commento inline sulla stessa riga, allineato.
- `UGUALE` indica una forma alternativa che fa esattamente la stessa cosa del comando sopra.
- Gli script `.sh` sono in LF, i `.bat` e i `.ps1` in CRLF: lo forza il `.gitattributes`.
