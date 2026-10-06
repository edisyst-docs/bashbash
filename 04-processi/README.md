# 04 - Processi

Vedere cosa gira, fermarlo, metterlo in background, misurare quante risorse consuma.

| # | File | Contenuto |
|---|---|---|
| 01 | [ps e kill](01-ps-e-kill.md) | `ps`, `pgrep`, `kill`, `pkill`, `killall`, segnali, `lsof` |
| 02 | [jobs](02-jobs.md) | Foreground e background: `&`, `CTRL+Z`, `jobs`, `fg`, `bg`, `nohup` |
| 03 | [top e htop](03-top-htop.md) | `top` e `htop`, con i comandi interattivi |
| 04 | [risorse](04-risorse.md) | `lshw`, `lscpu`, `free`, `du`, `df`, `watch`, `nice`/`renice`, `/proc` |
| 05 | [debug e prestazioni](05-debug-e-prestazioni.md) | `vmstat`, `iostat`, `pidstat`, `strace`, `ltrace`, `/proc/PID`, `ulimit`, cgroup e OOM killer, `perf`, `systemd-analyze` |
| 06 | [esercizi](06-esercizi.md) | 16 esercizi su processi vivi (`pgrep`, `ps`, `ss`, `kill`, `renice`, `/proc`, `trap`): lo scenario si avvia da solo e `verifica.sh` guarda lo stato dopo |

**Script**: [02-contatore.sh](02-contatore.sh) — contatore infinito usato negli esempi di `02-jobs.md`.

**Laboratorio**: `./lab.sh 04` dalla radice della KB apre un container con 256 MB di RAM, una CPU e gli script che si
comportano male (processo appeso, file aperti, memoria che finisce, funzione lenta). Dettagli in [lab/](lab/).

Area precedente: [../03-testo-e-regex/](../03-testo-e-regex/) · Prossima: [../05-scripting/](../05-scripting/) · Torna all'[indice](../README.md)
