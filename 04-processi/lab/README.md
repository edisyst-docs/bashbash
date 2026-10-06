# Laboratorio dell'area 04

I primi quattro `.md` agiscono sul sistema (`ps`, `top`, `free`...) e si provano in qualunque shell. Il quinto,
[05-debug-e-prestazioni](../05-debug-e-prestazioni.md), ha bisogno di programmi che si comportano male in modo prevedibile e di un
container con **limiti veri**: li descrive [compose.yaml](compose.yaml), li crea [prepara.sh](prepara.sh).

| Limite | Valore | Perché |
|---|---|---|
| RAM | 256 MB, senza swap | far intervenire l'OOM killer con `mangia-ram.py` |
| CPU | 1 | far frenare due processi che ne vorrebbero due (`cpu.stat`) |
| processi | 200 | `pids.max` |
| `CAP_SYS_ADMIN` | sì | serve a `perf` (senza: `No permission to enable task-clock event`) |
| `CAP_SYS_PTRACE` | sì | serve a `strace -p` su processi che non sono figli della shell |

## Avvio
Dalla radice della KB:
```bash
./lab.sh 04               # la prima volta costruisce l'immagine (qualche minuto)
cd 05-debug-e-prestazioni
cat /sys/fs/cgroup/memory.max
```
All'uscita il container viene eliminato.

## Cosa si prova e dove

| Cartella | File pronti | Note |
|---|---|---|
| `01-ps-e-kill/`, `03-top-htop/`, `04-risorse/` | nessuno | si lavora sul container |
| `02-jobs/` | `02-contatore.sh` | il contatore infinito degli esempi |
| `05-debug-e-prestazioni/` | `cerca-config.sh`, `bloccato.sh`, `apri-file.py`, `mangia-ram.py`, `calcola.py`, `scrive-lento.sh`, `cpu.sh` | uno per ogni sezione del `.md`: la configurazione "persa" (`strace`), il processo appeso (`strace -p`), `EMFILE` (`ulimit`), l'OOM (cgroup), la funzione lenta (`perf`, `cProfile`), il disco lento (`strace -T`), il throttling della CPU |
| `06-esercizi/` | `palestra/` (`lavora.sh`), `risposte/`, `verifica.sh`; i processi dello scenario li avvia [scenario.sh](scenario.sh) | le risposte sono script in `risposte/NN.sh`; `./verifica.sh [N]` riavvia lo scenario (`worker`, `ostinato`, `padre`/`figlio`, `ascolto`, `lento`, `fermo`, `scrittore`) a ogni esercizio, esegue la risposta e la soluzione di [soluzioni.sh](soluzioni.sh) e confronta stato e output |

Da sapere:
- `vmstat`, `mpstat`, `iostat` e `free` mostrano la macchina (o la VM di Docker), non i limiti del container: per quelli
  si leggono i file in `/sys/fs/cgroup/`
- `mangia-ram.py` finisce con `Killed` e codice 137: è voluto
- `systemd-analyze`, `systemd-run` e `systemd-cgtop` richiedono systemd: si provano nel laboratorio dell'area 06 (`./lab.sh 06`)
- `perf record` su programmi senza simboli (come `sort`) mostra indirizzi invece di nomi: vedi il `.md`

Torna all'[indice dell'area](../README.md)
