# Esercizi: amministrare un sistema

> **Laboratorio**: `./lab.sh 06`, poi `cd 13-esercizi`. Gli esercizi agiscono sul **sistema vero** del container (utenti, unit di systemd, mount, crontab): ha systemd come PID 1 ed è usa-e-getta (vedi [lab/](lab/)).

Diciotto esercizi sui comandi dell'area: [utenti](02-utenti.md), [pacchetti](03-pacchetti-apt.md), [dischi](04-dischi.md), [data e ora](05-data-e-ora.md), [rete](06-rete-e-host.md), [servizi e journal](07-servizi.md), [tmux](08-tmux.md),
[cron](09-crontab.md), [logrotate](10-logrotate/) e [storage](12-storage-avanzato.md). A differenza degli esercizi di testo, qui **si cambia la macchina**: si crea un utente, si scrive una unit, si monta un filesystem, e `verifica.sh` guarda **lo stato** che ne risulta.
Le soluzioni sono nascoste in fondo a ogni esercizio.

## Come si lavora
Ogni risposta è uno script `risposte/NN.sh` (due cifre) con **uno o più comandi**, da lanciare come root nel laboratorio. Si può provare anche a mano, e rifare:
```bash
cd ~/lab/13-esercizi
echo "useradd -m -s /bin/bash -G www-data deploy" > risposte/01.sh     # la risposta all'esercizio 1
./verifica.sh 1
#   01  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                                           # tutti (circa 20 secondi): quelli senza risposta sono "da fare"
```
Per ogni esercizio `verifica.sh`: **riporta il sistema allo stato di partenza** (toglie gli utenti, le unit e i mount degli esercizi), esegue la tua risposta, legge lo **stato** che l'esercizio chiede e **ripulisce**; poi fa lo stesso con la soluzione di riferimento e confronta.
Così le prove non si accumulano e **conta il risultato, non il comando**: `useradd -G` o `usermod -aG`, `date -d` in un modo o nell'altro, vanno bene tutti. Negli esercizi che **stampano** un risultato (4, 5, 6, 8, 9, 14) si confronta l'output; negli altri lo stato:
```
  07  SBAGLIATO
        2c2
        < tmpfs   16M
        ---
        > tmpfs    8M
        (< atteso, > ottenuto)
```
> **Attenzione**: `verifica.sh` crea e cancella **utenti, unit, mount e crontab del container**: serve root e systemd, e si lancia solo nel laboratorio 06 (si rifiuta altrove). Se un esercizio lascia qualcosa, `bash /kb/06-sistema/lab/soluzioni.sh pulisci N` lo toglie.

## Utenti e permessi ([02-utenti.md](02-utenti.md))
**1.** Crea l'utente `deploy` con home `/home/deploy`, shell `/bin/bash` e gruppo supplementare `www-data`. *(Cambia il sistema.)*
<details><summary>soluzione</summary>

```bash
useradd -m -s /bin/bash -G www-data deploy
getent passwd deploy | cut -d: -f1,6,7
# deploy:/home/deploy:/bin/bash
id -nG deploy
# deploy www-data
```
`-m` crea la home, `-s` la shell, `-G` i gruppi **supplementari**. Senza `-s` la shell predefinita di `useradd` sarebbe `/bin/sh`. `useradd` non chiede la password: l'account non è accessibile con password finché non si fa `passwd deploy`.
</details>

**2.** Crea il gruppo `sviluppo` con **GID 2000** e l'utente `anna` (con home) che ne fa parte. *(Cambia il sistema.)*
<details><summary>soluzione</summary>

```bash
groupadd -g 2000 sviluppo
useradd -m -G sviluppo anna          # oppure: useradd -m anna; usermod -aG sviluppo anna
getent group sviluppo
# sviluppo:x:2000:anna
```
L'ultimo campo di `/etc/group` è l'elenco dei membri **supplementari**; il gruppo *primario* di `anna` è un altro (`anna`, creato da `useradd`).
</details>

**3.** L'utente `deploy` (già creato) deve poter eseguire **solo** `systemctl restart nginx` come root, senza password. Scrivi la regola in `/etc/sudoers.d/deploy` con i permessi corretti `440`. *(Cambia il sistema.)*
<details><summary>soluzione</summary>

```bash
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx' > /etc/sudoers.d/deploy
chmod 440 /etc/sudoers.d/deploy
visudo -cf /etc/sudoers.d/deploy         # controlla la sintassi
# /etc/sudoers.d/deploy: parsed OK
sudo -l -U deploy
#     (root) NOPASSWD: /usr/bin/systemctl restart nginx
```
Un file di `sudoers.d` con la sintassi sbagliata può **bloccare sudo per tutti**: per questo si controlla sempre con `visudo -cf`. Provato: un file scrivibile da tutti (`666`) viene **ignorato** (`sudo: /etc/sudoers.d/deploy is world writable`, e `deploy` non può più usare sudo); con `644` funziona, ma `440` è la convenzione (solo root lo legge). Il percorso del comando deve essere **completo** ([02-utenti.md](02-utenti.md), utente di deploy).
</details>

## Pacchetti ([03-pacchetti-apt.md](03-pacchetti-apt.md))
**4.** Quale **pacchetto** contiene il file `/usr/bin/ls`? (solo il nome)
<details><summary>soluzione</summary>

```bash
dpkg -S /usr/bin/ls | cut -d: -f1
# coreutils
```
`dpkg -S` cerca fra i file dei pacchetti **installati**; `dpkg -L PACCHETTO` fa il contrario (elenca i file di un pacchetto).
</details>

**5.** Qual è la **versione installata** del pacchetto `nginx`? (solo la stringa della versione)
<details><summary>soluzione</summary>

```bash
dpkg-query -W -f='${Version}\n' nginx
# 1.24.0-2ubuntu7.18          (cambia con l'aggiornamento del pacchetto)
dpkg -s nginx | awk '/^Version/ {print $2}'        # UGUALE
```
</details>

**6.** I file in `/usr/sbin/` forniti dal pacchetto `cron`, uno per riga.
<details><summary>soluzione</summary>

```bash
dpkg -L cron | grep '^/usr/sbin/'
# /usr/sbin/cron
```
</details>

## Dischi e storage ([04-dischi.md](04-dischi.md), [12-storage-avanzato.md](12-storage-avanzato.md))
**7.** Monta un filesystem **tmpfs** da **16 MB** su `/mnt/dati` (crea la cartella se serve). *(Cambia il sistema.)*
<details><summary>soluzione</summary>

```bash
mkdir -p /mnt/dati
mount -t tmpfs -o size=16M tmpfs /mnt/dati
findmnt -no FSTYPE,SIZE /mnt/dati
# tmpfs   16M
```
Un tmpfs sta in RAM e sparisce allo smontaggio: è il modo di provare `mount` in un container, dove non ci sono dischi veri. `size=16m` e `size=16M` sono uguali. Per renderlo permanente servirebbe una riga in `/etc/fstab` ([04-dischi.md](04-dischi.md)).
</details>

**16.** Nella cartella corrente crea il file **`disco.img` da 8 MB** e formattalo **ext4** con l'etichetta `DATI`. *(Cambia i file: si controllano etichetta e dimensione.)*
<details><summary>soluzione</summary>

```bash
dd if=/dev/zero of=disco.img bs=1M count=8       # oppure: truncate -s 8M disco.img
mkfs.ext4 -q -L DATI disco.img
e2label disco.img; stat -c %s disco.img
# DATI
# 8388608
```
`mkfs.ext4` sa formattare anche un **file**: è il modo di provare un filesystem senza toccare un disco ([12-storage-avanzato.md](12-storage-avanzato.md)). `-L` imposta l'etichetta, `-q` toglie i messaggi.
</details>

## Data e ora ([05-data-e-ora.md](05-data-e-ora.md))
**8.** Che data sarà **30 giorni dopo il 2026-10-05**, nel formato `AAAA-MM-GG`?
<details><summary>soluzione</summary>

```bash
date -d '2026-10-05 +30 days' +%F
# 2026-11-04
```
`-d` accetta espressioni come `tomorrow`, `last friday`, `2026-10-05 +30 days`. `%F` equivale a `%Y-%m-%d`.
</details>

**9.** Che **giorno della settimana** (in inglese) era il 2026-10-05?
<details><summary>soluzione</summary>

```bash
LC_ALL=C date -d 2026-10-05 +%A
# Monday
```
Con la lingua del sistema (`LANG=it_IT.UTF-8`) uscirebbe `lunedì`: `LC_ALL=C` forza l'inglese.
</details>

**10.** Imposta il **fuso orario** `Europe/Rome`. *(Cambia il sistema: `date +%Z` deve dare `CEST`, in estate.)*
<details><summary>soluzione</summary>

```bash
timedatectl set-timezone Europe/Rome
readlink -f /etc/localtime        # /usr/share/zoneinfo/Europe/Rome
date +%Z
# CEST
```
Il fuso è un **collegamento** `/etc/localtime` verso un file di `/usr/share/zoneinfo`: `ln -sf` fa la stessa cosa a mano. `CEST` è l'ora legale (da marzo a ottobre), `CET` quella solare.
</details>

## Servizi, timer e journal ([07-servizi.md](07-servizi.md))
**11.** Crea il servizio `hello` (`/etc/systemd/system/hello.service`) che esegue `/bin/sleep infinity`, **abilitalo** all'avvio e **avvialo**. *(Cambia il sistema: `is-active` e `is-enabled`.)*
<details><summary>soluzione</summary>

```bash
cat > /etc/systemd/system/hello.service << 'EOF'
[Unit]
Description=Hello

[Service]
ExecStart=/bin/sleep infinity

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now hello            # enable + start in un colpo
systemctl is-active hello; systemctl is-enabled hello
# active
# enabled
```
Senza la sezione `[Install]` il servizio **parte ma non si abilita**: `is-enabled` direbbe `static`. `daemon-reload` fa rileggere le unit a systemd dopo ogni modifica. `systemctl is-active` esce con 0 solo se è attivo.
</details>

**12.** Con un **timer** systemd: un'unità `ciao.service` (oneshot) che scrive `ok` in `/tmp/ciao.txt`, e `ciao.timer` che la lancia **1 secondo dopo l'avvio del timer** (`OnActiveSec`). Avvia il timer. *(Cambia il sistema: dopo pochi secondi il file c'è.)*
<details><summary>soluzione</summary>

```bash
cat > /etc/systemd/system/ciao.service << 'EOF'
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo ok > /tmp/ciao.txt'
EOF
cat > /etc/systemd/system/ciao.timer << 'EOF'
[Timer]
OnActiveSec=1s

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl start ciao.timer
sleep 3; cat /tmp/ciao.txt
# ok
```
Il timer attiva **la service con lo stesso nome**. `OnActiveSec` conta dall'avvio del timer; per un'ora fissa del giorno si usa `OnCalendar=` (come in [07-servizi.md](07-servizi.md), «Timer systemd: alternativa a cron»).
</details>

**13.** Scrivi nel **journal** il messaggio `ciao dal journal` con tag `esercizio` e priorità **warning**. *(Cambia il sistema: si legge con `journalctl -t esercizio -p warning`.)*
<details><summary>soluzione</summary>

```bash
logger -t esercizio -p user.warning "ciao dal journal"
journalctl -t esercizio -p warning -o cat --no-pager
# ciao dal journal
```
`-t` è il tag (l'identificatore), `-p` la priorità; `journalctl -p warning` mostra i messaggi da `warning` in su (`warning`, `err`, `crit`...): un messaggio `info` **non** comparirebbe. `-o cat` stampa solo il testo.
</details>

## Rete ([06-rete-e-host.md](06-rete-e-host.md))
**14.** Quale **processo** è in ascolto sulla porta TCP **80**? (solo il nome)
<details><summary>soluzione</summary>

```bash
ss -ltnpH 'sport = :80' | grep -o '"[a-z0-9]*"' | head -1 | tr -d '"'
# nginx
ss -ltnp | grep ':80 '          # la riga intera: LISTEN ... users:(("nginx",pid=...,fd=5))
```
`ss -ltnp`: **l**istening, **t**cp, **n**umerico, con il **p**rocesso (serve root). `'sport = :80'` è un filtro di `ss`; compare due volte (IPv4 e IPv6), da qui il `head -1`.
</details>

## Cron, logrotate e tmux
**15.** Aggiungi al **crontab di root** una riga che esegue `/usr/local/bin/backup.sh` **ogni giorno alle 03:30**. *(Cambia il sistema: si legge con `crontab -l`.)*
<details><summary>soluzione</summary>

```bash
(crontab -l 2>/dev/null; echo '30 3 * * * /usr/local/bin/backup.sh') | crontab -
crontab -l
# 30 3 * * * /usr/local/bin/backup.sh
```
Il formato è `minuto ora giorno-del-mese mese giorno-della-settimana comando`: **minuto per primo** (`30 3`, non `3 30`). `crontab -e` apre un editor; da script si rilegge il crontab con `crontab -l` e lo si reinstalla con `crontab -`. `*/30 3 * * *` sarebbe «**ogni 30 minuti** durante l'ora delle 3», cioè alle 3:00 **e** alle 3:30 ([09-crontab.md](09-crontab.md)).
</details>

**17.** Avvia una sessione **tmux** chiamata `lavoro`, **staccata** (in background), che esegue `sleep 300`. *(Cambia il sistema: `tmux ls` la elenca.)*
<details><summary>soluzione</summary>

```bash
tmux new-session -d -s lavoro 'sleep 300'        # -d: detached; -s: il nome
tmux ls | cut -d: -f1
# lavoro
```
`tmux attach -t lavoro` ci si ricollega, `tmux kill-session -t lavoro` la chiude ([08-tmux.md](08-tmux.md)).
</details>

**18.** Scrivi `/etc/logrotate.d/miaapp` per il log `/var/log/miaapp.log` (già presente): rotazione **settimanale**, **4** copie conservate. *(Cambia il sistema: si controlla con `logrotate -d`.)*
<details><summary>soluzione</summary>

```bash
cat > /etc/logrotate.d/miaapp << 'EOF'
/var/log/miaapp.log {
    weekly
    rotate 4
    missingok
}
EOF
logrotate -d /etc/logrotate.d/miaapp 2>&1 | grep 'rotating pattern'
# rotating pattern: /var/log/miaapp.log  weekly (4 rotations)
```
`-d` (*debug*) mostra cosa farebbe **senza farlo** ([10-logrotate/](10-logrotate/)). `missingok` evita l'errore se il log non c'è; `compress` (non controllato qui) comprimerebbe le copie vecchie.
</details>

## Se non sai da dove cominciare
| Devi... | Comando |
|---|---|
| utenti e gruppi | `useradd -m -s SHELL -G GRUPPI`, `groupadd -g GID`, `usermod -aG`, `getent passwd/group`, `id -nG` |
| sudo limitato | un file in `/etc/sudoers.d/` con permessi `440`, e `visudo -cf FILE` |
| a quale pacchetto appartiene un file / cosa contiene | `dpkg -S FILE`, `dpkg -L PACCHETTO`, `dpkg-query -W -f='${Version}\n' PKG` |
| montare, formattare | `mount -t tmpfs -o size=16M tmpfs DIR`, `mkfs.ext4 -L ETICHETTA FILE-O-DISCO`, `findmnt`, `e2label` |
| date | `date -d 'ESPRESSIONE' +FORMATO`, `LC_ALL=C` per l'inglese, `timedatectl set-timezone` |
| un servizio | file `.service` in `/etc/systemd/system/`, `systemctl daemon-reload`, `enable --now`, `is-active`, `is-enabled` |
| un'attività pianificata | `crontab -l` / `crontab -`, oppure `.timer` + `.service` |
| log | `logger -t TAG -p user.warning "..."`, `journalctl -t TAG -p warning -o cat` |
| chi ascolta su una porta | `ss -ltnp` |

Torna all'[indice dell'area](README.md)
