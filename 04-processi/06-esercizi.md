# Esercizi: processi, segnali e risorse

> **Laboratorio**: `./lab.sh 04`, poi `cd 06-esercizi`. `verifica.sh` avvia da solo i processi su cui si lavora (lo **scenario**) e controlla le risposte (vedi [lab/](lab/)).

Sedici esercizi sui comandi di quest'area ([ps e kill](01-ps-e-kill.md), [job](02-jobs.md), [top](03-top-htop.md), [risorse](04-risorse.md), [debug](05-debug-e-prestazioni.md)). I processi sono **vivi**: si trovano, si contano, si fermano, si cambiano di priorità, e `verifica.sh`
guarda **che cosa è successo dopo**. Le soluzioni sono nascoste in fondo a ogni esercizio.

## Come si lavora
Ogni risposta è uno script `risposte/NN.sh` (due cifre) con **uno o più comandi**. Prima di provare, si ha bisogno dello scenario: ci pensa `verifica.sh`, ma per fare pratica a mano si avvia con
```bash
cd ~/lab/06-esercizi
bash /kb/04-processi/lab/scenario.sh start          # avvia i processi (in meno di un secondo)
ps -eo pid,ppid,ni,stat,comm,args | grep -E '/tmp/sc|worker'      # eccoli
bash /kb/04-processi/lab/scenario.sh stop           # li spegne e toglie /tmp/sc
```
```bash
echo "pgrep -c -x worker" > risposte/01.sh          # la risposta all'esercizio 1
./verifica.sh 1
#   01  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                       # tutti (circa 25 secondi): quelli senza risposta sono "da fare"
```
Per ogni esercizio `verifica.sh` **riavvia lo scenario**, esegue la tua risposta, aspetta mezzo secondo e guarda lo **stato** dei processi (quanti `worker` restano, qual è il `nice` di `lento`...) e, dove serve, quello che lo script ha **stampato**.
Poi fa lo stesso con la soluzione di riferimento e confronta. Quindi si può ritentare: ogni prova riparte da processi nuovi. I **PID cambiano a ogni avvio**: gli esercizi chiedono nomi, numeri e stati, mai PID.

## Lo scenario
| Processo (nome in `ps`) | Cos'è |
|---|---|
| `worker` (3 volte) | `sleep 600`: tre lavoratori uguali |
| `ostinato` | uno script con `trap "" TERM`: **ignora SIGTERM** |
| `padre` e `figlio` | `padre` è uno script che avvia `figlio` (`sleep 600`) in background |
| `ascolto` | `nc` in ascolto sulla porta TCP 9999 |
| `lento` | `sleep 600` avviato con `nice -n 10` |
| `fermo` | `sleep 600` **fermato** con `SIGSTOP` |
| `scrittore` | uno script che tiene aperto `/tmp/sc/dati.log` in scrittura |

I nomi sono veri nomi di processo (il campo `COMM` di `ps`): in `/tmp/sc` ci sono collegamenti simbolici a `sleep` e `nc` con questi nomi, perciò `pgrep worker` e `ps -C worker` funzionano come per un programma vero.

## Trovare e contare
**1.** Quanti processi si chiamano `worker`? (un numero)
<details><summary>soluzione</summary>

```bash
pgrep -c -x worker              # -x: il nome intero, non una parte (con "pgrep worker" altri nomi simili comparirebbero)
# 3
ps -C worker --no-headers | wc -l       # UGUALE
```
</details>

**4.** Qual è il **nome del processo padre** di `figlio`? (solo il nome)
<details><summary>soluzione</summary>

```bash
ps -o comm= -p "$(ps -o ppid= -C figlio | tr -d ' ')"
# padre
```
`-C figlio` sceglie per nome, `-o ppid=` stampa solo il PID del padre (il `=` toglie l'intestazione), e un secondo `ps -p` ne chiede il nome. In `ps --forest` ([01-ps-e-kill.md](01-ps-e-kill.md)) si vede la stessa parentela.
</details>

**5.** Su quale **porta TCP** è in ascolto il processo `ascolto`? (solo il numero)
<details><summary>soluzione</summary>

```bash
ss -ltnpH | grep '"ascolto"' | awk '{print $4}' | sed 's/.*://'
# 9999
```
`ss -ltnp`: sockets **l**istening, **t**cp, **n**umerici, con il **p**rocesso (serve root per i processi altrui). La quarta colonna è `0.0.0.0:9999`: `sed` toglie tutto fino all'ultimo `:`. `-H` toglie l'intestazione.
</details>

**10.** La **riga di comando** con cui è partito `figlio`, leggendola da `/proc`. (una riga)
<details><summary>soluzione</summary>

```bash
tr '\0' ' ' < "/proc/$(pgrep -x figlio)/cmdline" | sed 's/ $//'; echo
# /tmp/sc/figlio 600
cat "/proc/$(pgrep -x figlio)/cmdline" | xargs -0        # UGUALE
```
In `/proc/PID/cmdline` gli argomenti sono separati da un **byte NUL**, non da spazi: per questo `tr '\0' ' '`. Vedi [05-debug-e-prestazioni.md](05-debug-e-prestazioni.md).
</details>

**11.** Quale **file** tiene aperto in scrittura il processo `scrittore`? (il percorso)
<details><summary>soluzione</summary>

```bash
lsof -p "$(pgrep -x scrittore)" | awk '$4 ~ /w/ && $NF ~ /dati.log/ {print $NF}'
# /tmp/sc/dati.log
ls -l "/proc/$(pgrep -x scrittore)/fd" | grep dati.log          # senza lsof: i descrittori sono collegamenti
```
La colonna `FD` di `lsof` ha un numero e la modalità: `3w` = descrittore 3, scrittura. Altri esempi in [01-ps-e-kill.md](01-ps-e-kill.md).
</details>

## Segnali e stati
**2.** Termina tutti i `worker` con il segnale **SIGTERM** (quello che chiede di chiudersi). *(Cambia i processi: alla fine non ne devono restare.)*
<details><summary>soluzione</summary>

```bash
pkill -TERM -x worker           # oppure: kill $(pgrep -x worker)
pgrep -c -x worker              # per controllare
# 0
```
`SIGTERM` (15) è il predefinito di `kill`: il processo può gestirlo e chiudere con garbo ([01-ps-e-kill.md](01-ps-e-kill.md)).
</details>

**3.** `ostinato` **ignora SIGTERM**: toglilo di mezzo comunque. *(Cambia i processi.)*
<details><summary>soluzione</summary>

```bash
kill -TERM "$(pgrep -x ostinato)"       # non succede niente: ci prova, ma il processo lo ignora
pgrep -c -x ostinato                    # 1
pkill -KILL -x ostinato                 # SIGKILL (9): non si può né gestire né ignorare
pgrep -c -x ostinato                    # 0
```
Si prova prima con `SIGTERM`, e **solo se non basta** con `SIGKILL`: quest'ultimo non lascia al processo il tempo di ripulire (file temporanei, lock).
</details>

**8.** Qual è lo **stato** (la lettera) del processo `fermo`? (un carattere)
<details><summary>soluzione</summary>

```bash
ps -o stat= -C fermo | cut -c1
# T
grep State "/proc/$(pgrep -x fermo)/status"       # State: T (stopped)
```
Gli stati: `R` in esecuzione, `S` dorme, `D` attesa di I/O non interrompibile, `T` fermo (`SIGSTOP`, o `Ctrl+Z`), `Z` zombie. Le lettere dopo la prima (`Ts`, `Ss`, `SNs`) sono dettagli (leader di sessione, `N` = nice positivo).
</details>

**9.** **Fai ripartire** `fermo` senza ucciderlo. *(Cambia i processi: dopo deve dormire, `S`, non essere fermo.)*
<details><summary>soluzione</summary>

```bash
pkill -CONT -x fermo            # oppure: kill -CONT $(pgrep -x fermo)
ps -o stat= -C fermo | cut -c1
# S
```
`SIGCONT` è l'inverso di `SIGSTOP`: lo stesso che fa `fg` (o `bg`) in una shell interattiva dopo `Ctrl+Z` ([02-jobs.md](02-jobs.md)). Con `SIGKILL` il processo sparirebbe invece di riprendere.
</details>

**16.** I **nomi** dei processi attualmente **fermi** (stato `T`), uno per riga.
<details><summary>soluzione</summary>

```bash
ps -eo stat=,comm= | awk '$1 ~ /^T/ {print $2}'
# fermo
```
</details>

## Priorità
**6.** Qual è il valore di **nice** di `lento`? (solo il numero)
<details><summary>soluzione</summary>

```bash
ps -o ni= -C lento | tr -d ' '
# 10
ps -o nice= -p "$(pgrep -x lento)"        # UGUALE (con spazi davanti: ps allinea le colonne)
```
</details>

**7.** Porta il nice di `lento` a **15**. *(Cambia i processi.)*
<details><summary>soluzione</summary>

```bash
renice -n 15 -p "$(pgrep -x lento)"
# 730 (process ID) old priority 10, new priority 15
ps -o ni= -C lento
# 15
```
Un utente normale può solo **alzare** il nice (rendere un proprio processo più "gentile"); abbassarlo serve root (da [04-risorse.md](04-risorse.md); nel laboratorio si è root, quindi come utente normale **non provato**).
</details>

## Script, job e limiti
**12.** `tutti.sh`: lancia **in parallelo** `./lavora.sh A`, `./lavora.sh B` e `./lavora.sh C` (ognuno impiega un secondo e scrive il file `NOME.out`) e stampa `tutti finiti` **solo quando hanno finito tutti e tre**. *(Alla fine i tre file `.out` devono esserci.)*
<details><summary>soluzione</summary>

```bash
./lavora.sh A &
./lavora.sh B &
./lavora.sh C &
wait
echo "tutti finiti"
```
`&` mette in background, `wait` aspetta **tutti** i figli ([02-jobs.md](02-jobs.md), sezione sul parallelo). Senza `wait` lo script stampa subito, esce, e i file compaiono dopo: `verifica.sh` guarda mezzo secondo dopo la fine dello script e non li trova.
</details>

**13.** `servizio.sh`: stampa `avviato` e poi resta in attesa. Quando riceve **SIGTERM** stampa `pulizia` ed esce con codice **0**. `verifica.sh` lo avvia, dopo un secondo gli manda il segnale e guarda output e codice.
<details><summary>soluzione</summary>

```bash
trap 'echo pulizia; exit 0' TERM
echo avviato
while :; do sleep 0.2; done
```
Senza `trap`, SIGTERM uccide lo script e il codice d'uscita è **143** (128 + 15) senza nessuna pulizia. Il ciclo con `sleep` breve fa arrivare il segnale subito: provato: con un solo `sleep 4` la `trap` parte dopo **4,0 secondi** dall'avvio invece che dopo 1,0, perché bash la esegue solo quando il comando in primo piano è finito. Altri usi: [../05-scripting/12-trap-e-debug.md](../05-scripting/12-trap-e-debug.md).
</details>

**14.** Il limite **soft** di **file aperti** della shell (`ulimit`). (un numero)
<details><summary>soluzione</summary>

```bash
ulimit -Sn
# 1048576
```
`-S` soft (quello che si applica), `-H` hard (il tetto che un utente non può superare); `-n` file aperti. Il valore dipende dal sistema (qui Docker). Vedi [05-debug-e-prestazioni.md](05-debug-e-prestazioni.md).
</details>

**15.** Il **limite di memoria del container** in MB, leggendolo dal cgroup. (un numero)
<details><summary>soluzione</summary>

```bash
echo $(( $(cat /sys/fs/cgroup/memory.max) / 1024 / 1024 ))
# 256
```
`memory.max` è in byte (`268435456`); nel laboratorio il [compose.yaml](lab/compose.yaml) fissa 256 MB. Senza limite il file contiene la parola `max` e l'operazione dà errore. `free` e `top` mostrano la memoria della **macchina**, non questo limite: vedi [05-debug-e-prestazioni.md](05-debug-e-prestazioni.md), sezione sul cgroup.
</details>

## Se non sai da dove cominciare
| Devi... | Strumento |
|---|---|
| trovare un processo per nome | `pgrep -x nome`, `ps -C nome`, `pidof nome` |
| contare / elencare con colonne scelte | `pgrep -c`, `ps -eo pid,ppid,ni,stat,comm` (il `=` toglie l'intestazione: `-o ppid=`) |
| padre, figli | `ps -o ppid= -p PID`, `ps --forest` |
| mandare un segnale | `kill -TERM PID`, `pkill -KILL -x nome`, `kill -STOP/-CONT` |
| porte e file aperti | `ss -ltnp`, `lsof -p PID`, `/proc/PID/fd` |
| leggere un processo da /proc | `/proc/PID/cmdline`, `/status`, `/limits` |
| priorità | `nice -n 10 comando`, `renice -n 15 -p PID` |
| lavori in parallelo in uno script | `comando &` e `wait` |
| ripulire alla chiusura | `trap '...' TERM EXIT` |

Torna all'[indice dell'area](README.md)
