# Laboratorio dell'area 01

Niente servizi: la shell basta. [prepara.sh](prepara.sh) crea in `~/lab` una cartella per ogni `.md` dell'area, con i file su cui provare gli esempi.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 01                 # shell usa-e-getta (Ubuntu 24.04, bash 5.2) dentro ~/lab
cd 04-comandi-base          # una cartella per ogni .md dell'area
ls [a,e]*
```
Tutto sparisce all'uscita. Per ripartire da zero senza uscire: `bash /kb/01-basi/lab/prepara.sh && cd ~/lab`.

## Cosa contiene

| Cartella | File pronti | Note |
|---|---|---|
| `01-shell/`, `02-shortcut/`, `03-help-e-manuali/`, `07-concatenazioni/` | nessuno | si lavora sul prompt. Le **scorciatoie** si premono sulla tastiera; in questo container `man`, `apropos` e `whatis` funzionano (l'immagine base di Ubuntu non ha i manuali: li rimette il [Dockerfile](../../Dockerfile)) |
| `04-comandi-base/` | `doc1.rar`, `doc22.rar`, `docA.rar`, `apple`, `eagle`, `zebra`, `testo`, `d1/sotto/file.txt`, `d2/` | per `ls [a,e]*`, `doc?.rar`, `mv testo{,.old}` |
| `05-alias/` | `bashrc-esempio` (collegamento a [../bashrc-esempio](../bashrc-esempio)) | `source bashrc-esempio` carica gli alias e le funzioni `mkcd`, `estrai`, `bak`, `cerca`, `pesanti` |
| `06-history/` | `comandi.txt`, `prova.sh` | `./prova.sh comandi.txt` esegue i comandi in una `bash -i`, dove `!!`, `!$`, `^a^b` si espandono; con un altro file: `./prova.sh MIOFILE` |
| `08-pipeline/` | `logs/app.log`, `logs/errori vecchi.log` (nome con spazio), `vecchio.bak`, `copia.bak`, `log_a`, `log_b`, `lista_file.txt`, `SCRIPT.md` | per `xargs` (con e senza `-0`), `cat -n`, `|&` |
| `09-file-di-avvio/` | `casa/` (home finta: `.profile`, `.bash_profile`, `.bash_login`, `.bashrc`, `.bash_logout`), `benv.sh`, `prova.sh` | `./prova.sh` mostra quali file legge bash in ogni modo di avvio; non tocca la home vera |

Da sapere:
- il container è root e **non** ha un server SSH né cron: gli esempi su `ssh host 'comando'` e su cron non si possono provare qui
- `sudo su -` e `chsh -s` degli esempi sono per una macchina vera: nel container si è già root e non c'è l'utente `morro`
- `exec ping ...` chiude la shell: provare con `(exec ping -c 2 8.8.8.8)`, e `ping` funziona solo se il PC ha la rete

Torna all'[indice dell'area](../README.md)
