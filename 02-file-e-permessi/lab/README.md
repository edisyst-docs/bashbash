# Laboratorio dell'area 02

File e cartelle su cui provare i comandi di quest'area senza toccare niente di vero.
Non sono salvati nel repository: li genera [prepara.sh](prepara.sh), perché link simbolici,
permessi, bit speciali e date di modifica non sopravvivono a git (soprattutto su Windows).
Nel repository c'è solo [materiale/img.png](materiale/), l'immagine che `prepara.sh` copia in `01-file-base/` come
`immagine.png`: un file binario non si può ricreare con uno script.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 02            # shell come root dentro ~/lab, con i file già pronti
./lab.sh 02 --tester   # UGUALE ma come utente tester (password: tester): utile per vedere i "Permission denied"
```
Dentro il container c'è una cartella per ogni `.md` dell'area: si entra in quella del file che si sta studiando.
```bash
cd 07-diff-e-rsync
diff simile1.sh simile2.sh
```
Il container è usa-e-getta: all'uscita (`exit`) sparisce tutto e la KB, montata in `/kb` in sola
lettura, non può essere modificata. Per ripartire da zero senza uscire:
```bash
bash /kb/02-file-e-permessi/lab/prepara.sh && cd ~/lab
```
Senza Docker, su una macchina Linux, si può lanciare direttamente `bash lab/prepara.sh ~/lab-02`:
cancella e ricrea solo una cartella che ha creato lui (contiene il file `.lab-bashbash`).

## Cosa contiene

| Cartella | File pronti | Per provare |
|---|---|---|
| `01-file-base/` | `file`, `file1`, `file1.txt`, `file.txt`, `origine`, `crontab.md`, un PNG, un `.gz`, uno script, un link; cartelle `cartella/`, `prova1/`, `dir_1/`, `destinazione/`, `directory_vuota/`, `genitore/figlio/nipote/`, `directory_non_vuota/` | `file`, `wc`, `md5sum`, `cp`, `rmdir`, `rm -r`, `shred`, `tree` |
| `02-find/` | file `.txt` `.log` `.tmp` `.jpg` `.php` `.sh` (con e senza `x`), `vendor/` e `node_modules/`, duplicati, un file da 3 MB, cartelle vuote, date di modifica diverse (`composer.lock` al 10/09, `note.txt` al 05/09, `app.log` al 2025), `laravel/` | tutti i criteri di `find`, `-exec`, `-prune`, `-newer`, `-newermt`, duplicati, `locate` (dopo `updatedb`). L'esempio dei permessi Laravel si prova in `laravel/` invece che in `/var/www/app` |
| `03-archivi-compressione/` | `file1`, `file2`, `directory1/`, `progetto/` (con `.env`, `.git/`, `vendor/`, `node_modules/`, `.sql`), `backup.tar.gz` (è `progetto/` compresso), `dati/` | `gzip`, `xz`, `bzip2`, `tar` con esclusioni ed estrazione selettiva, `split`, `zip` |
| `04-link/` | `file` | link simbolici e hard link |
| `05-redirezioni/` | `elenco`, `elenco_server.txt` | redirezioni, here-doc, file descriptor. `file1`, `file2`... li crea il `.md` |
| `06-dd/` | niente | i file li crea il `.md` |
| `07-diff-e-rsync/` | `simile1.sh` e `simile2.sh`, `file1` e `file2` (diversi per maiuscole, spazi e una riga), `file1.bin` e `file2.bin` (diversi al byte 101), `lista1.txt` e `lista2.txt`, `config`, `sorgente/` e `destinazione/`, `cartella1/` e `cartella2/`, `src/` e `dst/`, `escludi.txt`, `.rsyncignore` | `diff`, `cmp`, `comm`, `patch`, `rsync` in locale |
| `08-permessi/` | `file`, `eseguibile`, `.env`, cartelle `cart/`, `protetta/`, `cartella/`, `progetto/` | `chmod` ottale e simbolico, bit speciali, `umask`, `stat`, ACL |
| `09-proprietari/` | `file.txt` | `chown`, `chgrp`. Gli utenti e le cartelle in `/` li crea il `.md`: serve root |

Gli esempi che parlano di server remoti (`rsync ... user@server:`, `ssh`) e di dischi (`dd` su
`/dev/sda`, `mount`) restano da provare su una macchina vera.

Torna all'[indice dell'area](../README.md)
