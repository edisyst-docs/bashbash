# Debug e prestazioni

> **Laboratorio**: `./lab.sh 04`, poi `cd 05-debug-e-prestazioni`. Cosa contiene: [lab/](lab/).

I comandi delle pagine precedenti dicono *cosa* gira e quanto consuma. Qui si risponde a "**perché** questo programma è lento,
è fermo, non trova un file, muore?". Si va dal generale al particolare, e ogni strumento restringe il campo del precedente:

1. **dove si perde tempo**: CPU, memoria, disco o attesa? (`top`, `vmstat`, `iostat`, `pidstat`)
2. **che cosa fa il processo**: quali file apre, a cosa è appeso? (`strace`, `/proc/PID`, `lsof`)
3. **quali limiti ha**: sono finiti i file aperti, la memoria, la CPU assegnata? (`ulimit`, cgroup)
4. **in quale funzione sta il tempo**: `perf`, `cProfile`

Gli esempi sono stati eseguiti nel laboratorio dell'area 04: un container con 256 MB di RAM senza swap, 1 CPU e 200 processi al
massimo, scelti apposta per far scattare i limiti.

## Dove si perde il tempo: sysstat e vmstat
```bash
vmstat 1 3                  # memoria, swap, I/O, CPU: una riga al secondo, tre volte
# procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
#  1  0      0 13309328 313944 2084492    0    0  4550  9788 8955    9  2  2 96  1  0  0
iostat -dx 1                # dischi: operazioni al secondo, utilizzo (%util), attesa (await)
mpstat -P ALL 1             # una riga per ogni CPU: un core al 100% con gli altri a 0 è un programma a un solo thread
pidstat -u 1 5              # CPU per processo, una riga al secondo (-r memoria, -d disco, -w cambi di contesto)
```
Come si leggono le colonne di `vmstat`:

| Colonna | Significa | Allarme se |
|---|---|---|
| `r` | processi in coda per la CPU | stabilmente maggiore del numero di CPU |
| `b` | processi bloccati in attesa di I/O | sempre maggiore di 0 |
| `si`/`so` | pagine lette/scritte nello swap | non zero in continuazione: la RAM è finita |
| `us`/`sy` | CPU in programmi / nel kernel | `sy` alto: troppe chiamate di sistema o I/O |
| `wa` | CPU ferma ad aspettare il disco | alto con `us` basso: il collo di bottiglia è il disco |
| `st` | tempo rubato dall'hypervisor | alto su una VM: l'host è saturo |

> **ATTENZIONE**: in un container `vmstat`, `mpstat`, `iostat` e `free` mostrano la **macchina** (o la VM di Docker), non i limiti
> del container: nel laboratorio `mpstat` vede 16 CPU anche se il container ne può usare una. I limiti veri si leggono nei
> cgroup (vedi sotto).

Con `pidstat` si vede la CPU **per processo**. Due `cpu.sh` (un ciclo infinito ciascuno) in un container limitato a una CPU:
```bash
./cpu.sh & ./cpu.sh &
pidstat -u 1 2
# Average:      UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
# Average:        0        42   50.00    0.00    0.00   49.50   50.00     -  bash
# Average:        0        43   50.00    0.00    0.00   50.50   50.00     -  bash
```
Ciascuno usa solo il 50% e `%wait` è circa 50: il processo *vorrebbe* girare ma è in attesa. Con una CPU sola per due
processi è normale; se capita senza un limite esplicito, la macchina è satura.

## strace: cosa chiede il processo al kernel
Un programma comunica con il mondo solo tramite **chiamate di sistema** (*syscall*): `openat` per aprire un file, `read`, `write`,
`connect`, `execve`... `strace` le mostra una per una, con argomenti e risultato. È il modo più rapido per capire cosa fa un
programma di cui non si ha il sorgente.

```bash
strace ls /nonesiste                       # stampa ogni syscall sullo stderr
strace -o /tmp/ls.trace ls /nonesiste      # su file: l'output del programma non si mescola
strace -f comando                          # segue anche i processi figli (-f: fork): quasi sempre serve
strace -e trace=openat,stat comando        # solo certe syscall
strace -e trace=file comando               # una classe: file, process, network, memory, signal, desc, ipc
strace -p 1234                             # si attacca a un processo già in esecuzione (Ctrl+C per staccarsi)
strace -c comando                          # conteggio e tempo per syscall, invece dell'elenco
strace -T comando                          # a fianco di ogni syscall, quanto è durata
strace -tt comando                         # l'ora precisa di ogni syscall
strace -s 200 comando                      # non tronca le stringhe a 32 caratteri
```

### "Non trova la configurazione"
Il caso più comune: un programma si comporta in modo strano e non dice perché. [cerca-config.sh](lab/prepara.sh) cerca la
configurazione in tre posti e, se non la trova, usa i default **senza avvisare**:
```bash
./cerca-config.sh
# uso i valori di default
strace -f -e trace=file ./cerca-config.sh 2>&1 | grep -E 'ini|miaapp'
# faccessat2(AT_FDCWD, "./config.ini", R_OK, AT_EACCESS) = -1 ENOENT (No such file or directory)
# faccessat2(AT_FDCWD, "/root/.miaapp.ini", R_OK, AT_EACCESS) = -1 ENOENT (No such file or directory)
# faccessat2(AT_FDCWD, "/etc/miaapp/config.ini", R_OK, AT_EACCESS) = -1 ENOENT (No such file or directory)
```
Ecco i percorsi cercati, nell'ordine, e `ENOENT` (*no such entry*) per ognuno. Gli errori più utili da riconoscere:

| Errore | Significa |
|---|---|
| `ENOENT` | il file o la cartella non esiste |
| `EACCES` | permesso negato (permessi o proprietario: [../02-file-e-permessi/08-permessi.md](../02-file-e-permessi/08-permessi.md)) |
| `EMFILE` | il processo ha troppi file aperti (`ulimit -n`) |
| `ECONNREFUSED` | nessuno ascolta su quella porta |
| `ETIMEDOUT` | nessuna risposta in tempo |
| `EAGAIN` | riprova: la risorsa non è pronta |

Non serve il nome della classe giusta a memoria: `-e trace=file` prende tutte le syscall che hanno un percorso come argomento
(`openat`, `stat`, `faccessat2`, `execve`...). Un `-e trace=openat` da solo qui non avrebbe trovato nulla, perché bash controlla un
file con `faccessat2`, non con `openat`.

### Conteggio: dove va il tempo di sistema
```bash
strace -c -f ./cerca-config.sh
# % time     seconds  usecs/call     calls    errors syscall
# ------ ----------- ----------- --------- --------- ----------------
#  28.57    0.001064          16        65        29 openat
#  15.33    0.000571          12        46           mmap
#  11.84    0.000441          11        38           close
#  11.49    0.000428          11        38           fstat
#   4.30    0.000160          10        16         3 newfstatat
```
`errors` conta le syscall fallite: 29 `openat` su 65 sono andate male. Non sempre è un problema (il caricamento delle librerie
prova diversi percorsi), ma un numero enorme di errori su un solo file spiega spesso un programma lento.

### Attaccarsi a un processo che non risponde
[bloccato.sh](lab/prepara.sh) aspetta una riga da una FIFO in cui nessuno scrive:
```bash
./bloccato.sh &
# PID 35: aspetto dati da /tmp/coda...
strace -p 35
# strace: Process 35 attached
# openat(AT_FDCWD, "/tmp/coda", O_RDONLY
```
È fermo dentro `openat` su `/tmp/coda`: un `open` su una FIFO aspetta che qualcuno la apra dall'altra parte. Ora si ha il
colpevole. Per sbloccarlo basta scrivere nella coda: `echo ciao > /tmp/coda`.

Senza strace, due righe di `/proc` dicono già molto:
```bash
cat /proc/35/wchan; echo        # in quale funzione del kernel è fermo: wait_for_partner
grep State /proc/35/status      # State: S (sleeping)
ls -l /proc/35/fd               # i file aperti: 0 -> /dev/null, 1 -> pipe:[25025], 255 -> .../bloccato.sh
```
Uno stato `D` (*uninterruptible sleep*) è un processo bloccato in attesa di I/O, di solito disco o NFS: non si può uccidere
nemmeno con `kill -9` finché l'I/O non finisce.

> **ATTENZIONE**: attaccarsi a un processo che non è un proprio figlio richiede `root` **e** il permesso di ptrace. Su Ubuntu
> `kernel.yama.ptrace_scope` vale 1: senza `CAP_SYS_PTRACE` si ottiene `strace: attach: ptrace(PTRACE_SEIZE, 41): Operation not
> permitted`. Nel laboratorio il compose lo concede. Dal vivo, `sudo strace -p`, oppure
> `sudo sysctl kernel.yama.ptrace_scope=0` (temporaneo, e abbassa la sicurezza).

> **ATTENZIONE**: `strace` rallenta molto il processo (ogni syscall passa dal debugger). Su un servizio in produzione si usa
> per pochi secondi, con `-e trace=` mirato e `-p`, mai per ore.

### Syscall lente
```bash
strace -f -T -e trace=write ./scrive-lento.sh
# [pid    53] write(1, "\0\0\0\0\0\0\0\0..."..., 4096) = 4096 <0.001894>
# [pid    53] write(1, "\0\0\0\0\0\0\0\0..."..., 4096) = 4096 <0.001619>
# 819200 bytes (819 kB, 800 KiB) copied, 1.32153 s, 620 kB/s
```
Con `oflag=dsync` ogni scrittura da 4 KB aspetta il disco: `-T` mostra circa 1,6-1,9 ms ciascuna, e 200 scritture fanno 1,3
secondi. È questo il significato di "il disco è lento": non il throughput, il tempo di attesa **per operazione**.

## ltrace: le chiamate alle librerie
`ltrace` fa per le **librerie condivise** (libc e simili) ciò che `strace` fa per il kernel. Funziona solo su programmi compilati:
su uno script risponde `"./cerca-config.sh" is not an ELF file`.
```bash
ltrace -c grep -c zzz /etc/hostname     # conteggio delle chiamate di libreria
# % time     seconds  usecs/call     calls      function
#  25.20    0.030871         120       257 mbrtowc
#  17.14    0.020998         162       129 setlocale
#  14.25    0.017463         121       144 strlen
ltrace -e getenv env                     # solo le chiamate a getenv: quali variabili legge un programma
```
Per i programmi in Python, Java o Node dice poco (vede l'interprete): lì servono i loro strumenti (vedi `cProfile` più sotto).

## /proc/PID: l'identikit di un processo
`/proc/PID/` (vedi [04-risorse.md](04-risorse.md)) ha una cartella per ogni processo:
```bash
cat /proc/35/status | grep -E 'Name|State|Threads|VmRSS'    # nome, stato, thread, memoria residua (RSS)
cat /proc/35/limits                                         # i limiti del processo, uno per riga
cat /proc/35/io                                             # byte letti e scritti (rchar, wchar), numero di read e write
ls -l /proc/35/cwd /proc/35/exe                             # cartella corrente ed eseguibile
tr '\0' '\n' < /proc/35/environ                             # le variabili d'ambiente con cui è partito
cat /proc/35/cmdline | tr '\0' ' '                          # la riga di comando completa
lsof -p 35                                                  # file e socket aperti, più leggibile di /proc/35/fd
```

## ulimit: i limiti di un processo
Ogni processo ha dei **limiti** sulle risorse (file aperti, processi, memoria...), per impedire che uno solo si prenda tutto.
Ognuno ha un valore *soft* (quello in uso, che il processo può alzare) e uno *hard* (il tetto, che solo root alza).
```bash
ulimit -a                 # tutti i limiti della shell
ulimit -n                 # file aperti (soft):  1048576
ulimit -Hn                # file aperti (hard):  1048576
ulimit -u                 # processi per utente
ulimit -c unlimited       # abilita i core dump (il file con lo stato di un processo che crasha)
ulimit -s                 # dimensione dello stack
```
Cosa succede quando il limite è troppo basso. [apri-file.py](lab/prepara.sh) apre file senza chiuderli:
```bash
./apri-file.py                         # 20000 file aperti: nessun limite raggiunto (con il limite predefinito, oltre un milione, si fermerebbe prima la RAM)
(ulimit -n 64; ./apri-file.py)         # le parentesi: il limite vale solo per la sottoshell, la shell resta com'era
# fermato dopo 61 file aperti: EMFILE - Too many open files
```
61, non 64: stdin, stdout e stderr ne occupano tre. L'errore `Too many open files` (`EMFILE`) compare in produzione quando un server
perde i file (non chiude le connessioni) o ha troppi client: lo si vede con `ls /proc/PID/fd | wc -l` che si avvicina al limite in
`/proc/PID/limits`.

Cambiare il limite di un processo **già in esecuzione**, senza riavviarlo:
```bash
prlimit --pid 35 --nofile                  # lo mostra:  NOFILE ... 1048576 1048576 files
prlimit --pid 35 --nofile=128:256          # soft:hard
prlimit --pid 35 --nofile                  # NOFILE ... 128 256 files
```
Dove si impostano i limiti in modo permanente:

| Contesto | Dove |
|---|---|
| sessioni di login (ssh, console) | `/etc/security/limits.conf` o `/etc/security/limits.d/*.conf`: `deploy  soft  nofile  65536` |
| servizi systemd | nella unit: `LimitNOFILE=65536` (i `limits.conf` **non** valgono per i servizi) |
| container | `docker run --ulimit nofile=65536:65536`, `ulimits:` nel compose |

Nel laboratorio 06, `systemctl show nginx -p LimitNOFILE -p TasksMax` risponde `LimitNOFILE=1048576` e `TasksMax=14999`.

## cgroup: i limiti di un gruppo di processi
I **cgroup** (*control groups*) sono il meccanismo del kernel con cui si limita e si misura un *gruppo* di processi: ne sono fatti
i container e i servizi systemd. I limiti non stanno nel processo ma nel gruppo, e valgono per tutti i suoi membri insieme.
Si leggono come file in `/sys/fs/cgroup/` (cgroup v2, quello di Ubuntu 24.04):
```bash
cat /sys/fs/cgroup/memory.max     # 268435456        256 MB di RAM per il gruppo
cat /sys/fs/cgroup/memory.swap.max  # 0              nessuno swap
cat /sys/fs/cgroup/cpu.max        # 100000 100000    quota e periodo in microsecondi: 100000/100000 = una CPU intera
cat /sys/fs/cgroup/pids.max       # 200              processi massimi
cat /sys/fs/cgroup/memory.events  # contatori: low high max oom oom_kill
cat /sys/fs/cgroup/cpu.stat       # tempo di CPU e quante volte il gruppo è stato frenato
```
Ecco i valori del laboratorio. Come si legge un `cpu.max` diverso: `50000 100000` è mezza CPU, `200000 100000` sono due.

### La memoria finita: l'OOM killer
[mangia-ram.py](lab/prepara.sh) occupa 20 MB al secondo:
```bash
cat /sys/fs/cgroup/memory.events | tr '\n' ' '
# low 0 high 0 max 0 oom 0 oom_kill 0 oom_group_kill 0
./mangia-ram.py | tail -2
# 200 MB occupati
# 220 MB occupati
echo "exit=${PIPESTATUS[0]}"            # exit=137
cat /sys/fs/cgroup/memory.events | tr '\n' ' '
# low 0 high 0 max 19 oom 1 oom_kill 1 oom_group_kill 0
```
Il processo muore a 220-240 MB (il resto del limite lo occupa il container) con codice **137** = 128 + 9, cioè ucciso dal segnale
`SIGKILL`: è l'**OOM killer** del kernel. Non lascia messaggi nell'output del programma: lo si riconosce da `exit=137`, da
`oom_kill` che sale in `memory.events` e, sull'host, da `dmesg | grep -i 'out of memory'` o `journalctl -k`. Nei container si
vede come `OOMKilled: true` in `docker inspect` e come `OOMKilled` in Kubernetes.

### La CPU frenata: il throttling
Con una CPU di quota, due cicli infiniti non possono usarne più di una in totale:
```bash
grep -E 'nr_periods|nr_throttled|throttled_usec' /sys/fs/cgroup/cpu.stat
# nr_periods 89
# nr_throttled 63
# throttled_usec 6234979
```
In 89 periodi da 100 ms il gruppo è stato fermato 63 volte, per un totale di 6,2 secondi di CPU negata. Un'applicazione lenta
"senza motivo" in Kubernetes ha spesso un `cpu limit` troppo basso: `nr_throttled` in crescita lo prova, mentre `top` mostra un
carico apparentemente basso.

### I cgroup dei servizi systemd (laboratorio 06)
systemd mette ogni servizio nel suo cgroup, e `systemd-run` ne crea uno al volo con limiti propri:
```bash
systemd-run --wait --collect -p MemoryMax=64M -p MemorySwapMax=0 --unit=mangia python3 -c 'b=[]
while True: b.append(bytearray(10*1024*1024))'
# Running as unit: mangia.service; invocation ID: 96125b57...
# Finished with result: oom-kill
# Main processes terminated with: code=killed/status=KILL
# Memory peak: 64.0M

systemd-run --wait --collect -p CPUQuota=20% --unit=cpu20 bash -c 'timeout 5 bash -c "while :; do :; done"'
# Service runtime: 5.021s
# CPU time consumed: 1.020s              20% di 5 secondi
```
Si osserva un servizio in esecuzione:
```bash
systemctl show nginx -p ControlGroup -p MemoryCurrent -p TasksCurrent
# ControlGroup=/system.slice/nginx.service
# MemoryCurrent=13660160
# TasksCurrent=17
systemd-cgtop -n 1 -b --depth 2           # i cgroup ordinati per CPU e memoria, come top ma per servizi
```
In una unit i limiti si scrivono nello stesso modo: `MemoryMax=`, `CPUQuota=`, `TasksMax=`, `LimitNOFILE=`.

### Quanto ci mette ad avviarsi: systemd-analyze
```bash
systemd-analyze                         # Startup finished in 438ms (userspace)
systemd-analyze blame                   # le unit dalla più lenta: 79ms ldconfig.service, 76ms systemd-resolved.service ...
systemd-analyze critical-chain          # la catena che ha impiegato di più (quella da accorciare)
# graphical.target @425ms
# └─multi-user.target @425ms
#   └─rsyslog.service @364ms +60ms
systemd-analyze verify /etc/systemd/system/prova.service        # controlla una unit prima di avviarla
# prova.service: Command /usr/bin/nonesiste is not executable: No such file or directory
systemd-analyze security nginx.service  # punteggio di esposizione di un servizio
# → Overall exposure level for nginx.service: 9.6 UNSAFE 😨
```
`security` elenca le opzioni di hardening non usate (`ProtectSystem=`, `PrivateTmp=`, `NoNewPrivileges=`...) con il loro peso.

## perf: in quale funzione sta il tempo
`strace` guarda i confini fra programma e kernel; `perf` campiona il processore e dice in **quali funzioni** il programma passa il
tempo, anche dentro il codice.
```bash
perf stat python3 calcola.py                    # contatori: quanti cicli, istruzioni, cambi di contesto
#  1411.89 msec task-clock                       #    0.999 CPUs utilized
#  1 context-switches
perf stat -e task-clock,cycles,instructions,page-faults sort -n /tmp/num.txt > /dev/null
#  968.95 msec task-clock                       #    1.013 CPUs utilized
#  3941772964      cycles                       #    4.068 GHz
#  9026777494      instructions                 #    2.29  insn per cycle
#  49769           page-faults
```
Le **istruzioni per ciclo** (IPC) dicono se la CPU lavora o aspetta: sotto 1 di solito aspetta la memoria, sopra 2 lavora bene.
`page-faults` alti sono accessi a memoria non ancora mappata.

```bash
perf record -F 999 -o /tmp/p.data python3 calcola.py          # campiona 999 volte al secondo
perf report -i /tmp/p.data --stdio --no-children --sort comm,dso,symbol | head
# 56.90%  python3  python3.12  [.] _PyEval_EvalFrameDefault
#  9.75%  python3  python3.12  [.] PyLong_FromLong
#  5.37%  python3  python3.12  [.] PyNumber_Remainder
```
`perf record -g` registra anche la catena delle chiamate (`perf report` la mostra ad albero). `perf top` è il `top` delle funzioni.

Per un programma in Python `perf` vede l'**interprete**, non le funzioni dello script: `_PyEval_EvalFrameDefault` è il ciclo che
esegue il bytecode. Per sapere quale funzione *dello script* è lenta serve il profilatore del linguaggio:
```bash
python3 -m cProfile -s tottime calcola.py | head -9
#          2642484 function calls in 1.843 seconds
#    ncalls  tottime  percall  cumtime  percall filename:lineno(function)
#   2400000    1.562    0.000    1.562    0.000 calcola.py:3(primo)
#    242320    0.266    0.000    1.828    0.000 calcola.py:12(<genexpr>)
```
`primo()` è chiamata 2,4 milioni di volte e occupa 1,56 secondi su 1,84: ecco dove ottimizzare. `perf` è lo strumento giusto per
programmi compilati (C, Go, Rust) che conservano i simboli, e per vedere il peso del **kernel** e delle librerie.

Qualche limite di `perf` che si incontra subito:
- permessi: con `kernel.perf_event_paranoid=2` (il predefinito, nel laboratorio 2) un utente normale può misurare solo i propri
  processi in user space; per tutto il resto serve `root`. In un container serve anche `CAP_SYS_ADMIN` (o `CAP_PERFMON`): senza,
  `Error: No permission to enable task-clock event`
- su un programma senza simboli (binario "stripped", come `sort` di Ubuntu) `perf report` mostra indirizzi (`0x000000000000c96c`)
  invece dei nomi delle funzioni
- su una VM i contatori hardware (`cycles`, `instructions`) possono non esistere: `<not supported>`. Con WSL2 esistono
- i nomi delle funzioni del kernel richiedono `kptr_restrict=0` o root; in un container compare `Kernel address maps were restricted`
- il pacchetto `linux-tools-generic` cerca `perf` per la versione **esatta** del kernel dell'host (`WARNING: perf not found for kernel
  6.6.87.2-microsoft`): in un container si lancia il binario direttamente (`/usr/lib/linux-tools/*/perf`), come fa il Dockerfile

## Una scaletta per "è lento"
| Sintomo | Primo comando | Se conferma |
|---|---|---|
| load alto, `us` alto | `top`, `pidstat -u 1` | `perf record` o `cProfile` sul processo in testa |
| load alto, `wa` alto | `iostat -dx 1`, `pidstat -d 1` | `strace -f -T -e trace=file` sul processo che scrive |
| `r` in coda ma CPU non satura (container) | `cat /sys/fs/cgroup/cpu.stat` | `nr_throttled` cresce: alzare il limite |
| processo muore senza messaggi | `echo $?` | 137: OOM (`memory.events`); 139: `SIGSEGV` (crash, `ulimit -c unlimited`) |
| `Too many open files` | `ls /proc/PID/fd \| wc -l` | confrontare con `/proc/PID/limits`; `prlimit` o `LimitNOFILE=` |
| non fa nulla, non risponde | `grep State /proc/PID/status` | `S` + `strace -p`: a quale syscall è fermo; `D`: I/O o NFS bloccato |
| "non trova il file" ma il file c'è | `strace -f -e trace=file` | il percorso reale cercato, `ENOENT` o `EACCES` |
| avvio lento di un servizio | `systemd-analyze blame` | `critical-chain` |

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `strace: attach: ptrace(PTRACE_SEIZE, N): Operation not permitted` | non sei root, o `ptrace_scope=1` e il processo non è tuo figlio | `sudo strace -p`; in un container aggiungere `CAP_SYS_PTRACE` |
| `strace` non mostra le syscall dei figli | manca `-f` | `strace -f` |
| `strace -e trace=openat` non trova il file cercato | quel programma usa un'altra syscall (`stat`, `faccessat2`, `access`) | `-e trace=file` |
| `ltrace: ... is not an ELF file` | è uno script | `ltrace` si usa su programmi compilati; per gli script `strace -f` |
| `perf` risponde `No permission to enable task-clock event` | `perf_event_paranoid` o container senza `CAP_SYS_ADMIN` | `sudo perf`, oppure `sysctl kernel.perf_event_paranoid=1` |
| `ulimit -n 65536` dà `Operation not permitted` | supera il limite *hard* | lo alza solo root, o `limits.conf` |
| ho alzato `limits.conf` ma il servizio ha ancora il vecchio limite | `limits.conf` vale per le sessioni di login, non per systemd | `LimitNOFILE=` nella unit e `systemctl daemon-reload && systemctl restart` |
| `free` e `top` in un container mostrano la RAM dell'host | leggono `/proc`, non il cgroup | `cat /sys/fs/cgroup/memory.max` e `memory.current` |
