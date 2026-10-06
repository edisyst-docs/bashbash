# Laboratorio dell'area 05

Script e file su cui provare i comandi e i costrutti di quest'area. Li genera [prepara.sh](prepara.sh),
che copia anche gli script di esempio dell'area (`02-variabili.sh`, `04-condizioni1.sh`, ...) nella
cartella del `.md` che li spiega, già eseguibili.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 05               # shell usa-e-getta dentro ~/lab, come root
./lab.sh 05 --tester      # UGUALE ma come utente tester: serve per l'esempio di PS4 (vedi 12-trap-e-debug.md)
cd 03-parametri
./opzioni.sh -e prod -n a.txt "con spazio.txt"
```
Tutto sparisce all'uscita. Per ripartire da zero senza uscire:
```bash
bash /kb/05-scripting/lab/prepara.sh && cd ~/lab
```

## Cosa contiene

| Cartella | File pronti | Per provare |
|---|---|---|
| `01-basi-scripting/` | `s.sh`, `s1.sh`, `s2.sh`, `s3.sh` **non eseguibili**, `scheletro.sh`, `cartella/` | `./s1.sh` dà `Permission denied` finché non si fa `chmod 744 s1.sh`; `. s1.sh` e poi `echo $a`; `./scheletro.sh cartella` |
| `02-variabili/` | `02-variabili.sh`, `.env`, `backup.sh` (usa `DB_HOST` con default) | `DB_HOST=10.0.0.5 ./backup.sh`, `set -a; source .env; set +a` |
| `03-parametri/` | `opzioni.sh` e `opzioni-getopts.sh` (i due parser del `.md`, completi), `a.txt`, `b.txt`, `con spazio.txt` | opzioni corte, lunghe, raggruppate, errate |
| `04-condizioni/` | `04-condizioni1.sh`, `04-condizioni2.sh`, `cartellau/`, `s.sh`, `link1` (link a `s.sh`), `vuoto.txt`, `vecchio.txt` e `nuovo.txt` | test sui file, `-nt`, `=~` con `BASH_REMATCH` |
| `05-cicli/` | `05-cicli1.sh`, `05-select.sh`, `esempi/` (cartelle per `select`), `elenco.txt` (spazi e backslash), `foto/` con `.JPG` (uno con spazi), `log/`, `src/*.php` | lettura riga per riga, `select`, rinomina di massa, `find -print0` |
| `06-array/` | `06-array.sh`, `elenco.txt`, `access.log`, `src/*.php` | `mapfile`, conteggio con array associativo |
| `07-input-read/` | `07-read1.sh`, `07-read2.sh`, `utenti.csv` | `read`, `IFS`, CSV con intestazione |
| `08-espansioni/` | file con spazi nel nome, `dir1/` e `dir2/` | rinomina con `${f// /_}`, `diff <(ls dir1) <(ls dir2)` |
| `09-altro-interprete/` | `09-altro_interprete.sh`, `s4.sh` (shebang python3) | lo shebang `/c/Python311/python` di Git Bash su Linux fallisce: `required file not found` |
| `10-quoting/` | `uno.txt`, `due.txt`, `leggimi.md`, `note.md`, `src/` con una cartella `cache dir`, `dst/` | glob con e senza virgolette, `rsync "${opzioni[@]}"`, tabella con `printf` |
| `11-funzioni/` | `lib.sh` (la libreria del `.md`), `esempi/`, `app.conf`, `img/*.jpg` | `source lib.sh`, `albero esempi`, `export -f` con `xargs` |
| `12-trap-e-debug/` | `script.sh` (con difetti per `bash -x` e `shellcheck`), `trap-err.sh`, `lock.sh`, `interrompi.sh`, `dati1..5.csv` | `./lock.sh &` e poi di nuovo `./lock.sh`; `./interrompi.sh` e CTRL+C a metà |
| `13-esercizi/` | `palestra/` (`testo.txt`, `con spazio.txt`, `dati.csv`, `parole.txt`, `misto/`, `flaky.sh`...), `risposte/`, `verifica.sh` | le risposte sono **script** in `risposte/NN.sh`; `./verifica.sh [N]` li lancia su più casi ([casi.txt](casi.txt)) in una copia nuova della palestra e li confronta con [soluzioni/](soluzioni/): output, codice d'uscita, presenza di stderr, file lasciati in `TMPDIR` |

Gli esempi che parlano di server, MySQL, `systemctl` o API esterne (`curl https://api.example.com`)
restano da provare su una macchina vera.

Torna all'[indice dell'area](../README.md)
