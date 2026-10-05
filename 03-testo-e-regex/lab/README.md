# Laboratorio dell'area 03

Testi, log e CSV su cui provare `head`, `sort`, `awk`, `grep`, `sed` e le regex.
Li genera [prepara.sh](prepara.sh); nel repository c'è solo [materiale/divina_commedia.txt](materiale/),
l'unico file che non si può ricreare con uno script.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 03                 # shell usa-e-getta dentro ~/lab, con i file già pronti
cd 02-grep                  # una cartella per ogni .md dell'area
grep -i errore logfile.txt
```
Tutto quello che si modifica (`sed -i`, `split`, ...) sparisce all'uscita. Per ripartire da zero senza uscire:
```bash
bash /kb/03-testo-e-regex/lab/prepara.sh && cd ~/lab
```

## Cosa contiene

| Cartella | File pronti | Note |
|---|---|---|
| `01-stampa-e-taglia/` | `file` (righe "numero parola:colore" con doppioni e una riga di 150 caratteri), `ciao`, `addio`, `file_5000`, `divina_commedia.txt`, `phonebook` (con un nome ripetuto), `file.csv` (separato da `;`), `vendite.csv` (da `,` con intestazione), `ids.txt` + `dati.csv`, `access.log`, `storage/logs/laravel.log`, `t.txt`, `video.mp4` (12 MB casuali, per `split -b`) | `access.log` ha 200 richieste di 5 IP con status 200, 302, 404, 500, 503 |
| `02-grep/` | `logfile.txt` e `logfile` (uguali: una riga per ogni esempio del `.md`), `regexfile`, `file` `file1` `file2`, `script.md`, `laravel.log`, `log`, `access.log`, `app.log`, tre `.php`, `app/` `vendor/` `node_modules/` con dei `dd(`, `.env` con `APP_DEBUG=true`, `sito/` con `vecchio.dominio.it` | l'esempio su `/etc/php/8.3/fpm/php.ini` richiede PHP installato: nel container non c'è |
| `03-regex/` | `crontab`, `contatti.txt`, `file.txt` (nomi `.html`), `utenti.txt` (email valide e no), `testo.txt` (Linux/linux, Ciao/ciao, colour/color, scopo) | per i pattern della sezione ESEMPI: `grep -o 'PATTERN' testo.txt` |
| `04-sed/` | `config` (commenti, "pattern", "ciao", "uno", "tre", blocco `Inizio`...`Fine`), `file.txt`, `altrofile.txt`, `geek.txt`, `.env`, `script.sh` con fine riga CRLF, `file` con spazi in coda e righe vuote, `laravel.log`, `log.json`, `progetto/` (repository git con `OldClass`) | dopo la sostituzione in `progetto/`, `git diff --stat` mostra i file toccati |
| `05-vim/` | `testo.txt` (i primi 120 versi della Divina Commedia) | `vim testo.txt` |
| `06-esercizi/` | `access.log`, `vendite.csv`, `contatti.txt`, `app.ini`, `passwd.txt`, `note.txt`, `verifica.sh`, `risposte/` | le risposte si scrivono in `risposte/NN.sh` e `./verifica.sh [N]` le confronta con la soluzione di riferimento ([soluzioni.sh](soluzioni.sh), che `verifica.sh` legge da `/kb`); i file originali non si modificano |

Torna all'[indice dell'area](../README.md)
