# Esercizi: find, permessi, link, archivi e rsync

> **Laboratorio**: `./lab.sh 02`, poi `cd 10-esercizi`. Il materiale è in `palestra/`; le risposte vanno in `risposte/` e `verifica.sh` le controlla (vedi [lab/](lab/)).

Venti esercizi sui comandi di quest'area ([find](02-find.md), [archivi](03-archivi-compressione.md), [link](04-link.md), [redirezioni](05-redirezioni.md), [diff e rsync](07-diff-e-rsync.md), [permessi](08-permessi.md)).
Alcuni **stampano** un risultato (quali file, quanti), altri **cambiano i file** (`chmod`, `ln`, `tar`): in tutti e due i casi `verifica.sh` sa controllare. Le soluzioni sono nascoste in fondo a ogni esercizio.

## Come si lavora
Ogni risposta è uno script `risposte/NN.sh` (due cifre) con **uno o più comandi**, che si pensa di lanciare **dentro la palestra**: i percorsi sono relativi a `palestra/` (`./app.log`, `progetto/a.txt`).
```bash
cd ~/lab/10-esercizi
echo "find . -name '*.log' | sort" > risposte/01.sh          # la risposta all'esercizio 1
./verifica.sh 1
#   01  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                                # tutti: quelli senza risposta sono "da fare"
```
Per ogni esercizio `verifica.sh` fa una **copia nuova della palestra** (con permessi e date di modifica), ci esegue la tua risposta, poi esegue la soluzione di riferimento in un'altra copia e confronta **l'output** e,
negli esercizi che cambiano i file, anche **lo stato** (per esempio `stat -c '%a'` del file, o l'elenco di un archivio). La palestra vera non si rovina: si può ritentare quante volte si vuole, e puoi provare i comandi a mano
in `palestra/` e rifarla con `bash /kb/02-file-e-permessi/lab/prepara.sh`. Un risultato sbagliato mostra la differenza:
```
  09  SBAGLIATO
        1c1
        < 600
        ---
        > 644
        (< atteso, > ottenuto)
```
Il confronto è sull'output esatto, riga per riga: se l'enunciato dice «in ordine alfabetico», serve `sort`.

## La palestra
```
palestra/
  app.log errori.log server/access.log server/old/vecchio.log        i log
  index.php lib.php src/a.php vendor/x.php node_modules/y.php         i sorgenti, e quelli di terzi
  cache/a.tmp cache/b.tmp (del 2020)  nuovo1.tmp nuovo2.tmp dati/c.tmp dati/d.tmp   i .tmp, vecchi e recenti
  grande.bin (2 MB)  piccolo.bin  deploy.sh backup.sh (755)  script.sh (644)  nota.txt  segreto.txt (644)
  progetto/ (a.txt 666, b.txt 664, sub/ 777...)   sito/ (tutto a 700/600)   condivisa/ (755)   release-1/ release-2/
  dati.txt  dati/ (a.csv b.csv c.tmp d.tmp)  release.tar.gz (con release/config.ini e release/app.py)
  lista1.txt lista2.txt  origine/ (con .git/, css/, index.html, LEGGIMI)   vuota/ src/vuota/ (cartelle vuote)
```

## find
**1.** I file `.log`, con il percorso (`./...`), in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
find . -name '*.log' | sort
# ./app.log
# ./errori.log
# ./server/access.log
# ./server/old/vecchio.log
```
</details>

**2.** I file `.php` **tranne** quelli sotto `vendor/` e `node_modules/` (codice di terzi), in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
find . -name '*.php' -not -path './vendor/*' -not -path './node_modules/*' | sort
# ./index.php
# ./lib.php
# ./src/a.php
```
`-not -path` (o `! -path`) esclude dopo aver guardato il percorso: con `-prune` si evita anche di entrare nella cartella ([02-find.md](02-find.md)).
</details>

**3.** I file regolari più grandi di 1 MiB.
<details><summary>soluzione</summary>

```bash
find . -type f -size +1M
# ./grande.bin
```
</details>

**4.** I `.tmp` **non modificati da più di 30 giorni**, in ordine alfabetico. (Sono quelli di `cache/`, datati 2020.)
<details><summary>soluzione</summary>

```bash
find . -name '*.tmp' -mtime +30 | sort
# ./cache/a.tmp
# ./cache/b.tmp
```
`-mtime +30` = più di 30 giorni fa; `-mtime -30` = negli ultimi 30.
</details>

**5.** Le **cartelle vuote**, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
find . -type d -empty | sort
# ./condivisa
# ./release-1
# ./release-2
# ./src/vuota
# ./vuota
```
</details>

**6.** I file regolari **eseguibili dal proprietario**, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
find . -type f -perm -u+x | sort
# ./backup.sh
# ./deploy.sh
```
`-perm -u+x`: **tutti** i bit indicati devono esserci (altri bit possono essere accesi). Con `-executable` si chiede «eseguibile da chi sta eseguendo `find`»: nel laboratorio, che è root, dà lo stesso risultato.
</details>

**7.** **Cancella** i `.tmp` non modificati da più di 30 giorni. *(Cambia i file: i `.tmp` recenti devono restare.)*
<details><summary>soluzione</summary>

```bash
find . -name '*.tmp' -mtime +30 -delete
find . -name '*.tmp' | sort           # per controllare: restano i quattro recenti
# ./dati/c.tmp
# ./dati/d.tmp
# ./nuovo1.tmp
# ./nuovo2.tmp
```
`-delete` va **dopo** i filtri: messo prima cancella tutto quello che `find` incontra. Equivale a `-exec rm {} \;` (o `-exec rm {} +`, più veloce).
</details>

**8.** Il numero **totale di righe** di tutti gli script `.sh` della palestra. (un numero)
<details><summary>soluzione</summary>

```bash
find . -name '*.sh' -exec cat {} + | wc -l
# 6
```
</details>

## Permessi
**9.** Rendi `segreto.txt` leggibile e scrivibile **solo dal proprietario** (modo `600`). *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
chmod 600 segreto.txt            # oppure: chmod u=rw,g=,o= segreto.txt
stat -c '%a' segreto.txt         # per controllare
# 600
```
</details>

**10.** In `progetto/`, **ricorsivamente**, togli il permesso di scrittura al gruppo e agli altri, senza toccare il resto. *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
chmod -R go-w progetto
find progetto -printf '%m %p\n' | sort -k2      # per controllare
# 755 progetto
# 644 progetto/a.txt
# 644 progetto/b.txt
# 755 progetto/sub
# 644 progetto/sub/c.txt
```
Prima erano `775`, `666`, `664`, `777`, `664`: `go-w` toglie solo la scrittura, e il resto (la `x` delle cartelle, la lettura) resta.
</details>

**11.** Dai a `condivisa/` il **bit setgid** e i permessi `775`: i file creati dentro prenderanno il gruppo della cartella. *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
chmod 2775 condivisa             # oppure: chmod g+ws condivisa   (da 755)
stat -c '%a' condivisa
# 2775
```
La cifra `2` davanti è il setgid (`4` setuid, `1` sticky).
</details>

**12.** In `sito/` tutte le cartelle devono essere `755` e tutti i file `644` (oggi sono `700` e `600`). *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
find sito -type d -exec chmod 755 {} +
find sito -type f -exec chmod 644 {} +
find sito -printf '%m %p\n' | sort -k2
# 755 sito
# 755 sito/css
# 644 sito/css/stile.css
# 755 sito/img
# 644 sito/img/logo.png
# 644 sito/index.html
# 644 sito/robots.txt
```
Un `chmod -R 755 sito` renderebbe eseguibili anche i file: per questo due comandi, uno per tipo.
</details>

**13.** Rendi `script.sh` **eseguibile** senza dire altro (nessun numero ottale). *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
chmod +x script.sh               # oppure: chmod a+x script.sh
stat -c '%a' script.sh
# 755
```
`+x` senza `u`, `g`, `o` vale per tutti, ma **rispettando la `umask`** (qui `022`: non cambia nulla). Era `644`.
</details>

## Link
**14.** Crea il link simbolico `corrente` che punta a `release-2`, e stampa dove punta. *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
ln -s release-2 corrente
readlink corrente
# release-2
```
Il link **contiene** il percorso `release-2`, relativo alla cartella del link: se la cartella viene spostata, il link continua a funzionare.
</details>

**15.** Crea `dati-copia` come **hard link** di `dati.txt`. *(Cambia i file: devono avere lo stesso inode.)*
<details><summary>soluzione</summary>

```bash
ln dati.txt dati-copia
stat -c '%h' dati.txt            # quanti nomi ha il file
# 2
[[ dati.txt -ef dati-copia ]] && echo "stesso inode"
# stesso inode
```
Con `ln -s` si farebbe un link simbolico: un file diverso, con il suo inode, e `stat -c '%h'` direbbe `1`.
</details>

## Archivi
**16.** Crea `backup.tar.gz` con la cartella `dati/`, **senza** i file `.tmp`. *(Cambia i file: si controlla l'elenco dell'archivio.)*
<details><summary>soluzione</summary>

```bash
tar czf backup.tar.gz --exclude='*.tmp' dati
tar tzf backup.tar.gz | sort
# dati/
# dati/a.csv
# dati/b.csv
```
Le virgolette su `'*.tmp'` evitano che la **shell** espanda il pattern prima di `tar`.
</details>

**17.** Da `release.tar.gz` estrai **solo** `release/config.ini`. *(Cambia i file: `app.py` non deve comparire.)*
<details><summary>soluzione</summary>

```bash
tar tzf release.tar.gz           # prima si guarda cosa c'è: release/  release/app.py  release/config.ini
tar xzf release.tar.gz release/config.ini
cat release/config.ini; ls release
# porta=8080
# config.ini
```
</details>

## Redirezioni
**18.** Lancia `ls . nonesiste` mandando l'**output normale** in `out.txt` e gli **errori** in `err.txt`, con un solo comando. *(Cambia i file.)*
<details><summary>soluzione</summary>

```bash
ls . nonesiste > out.txt 2> err.txt
cat err.txt
# ls: cannot access 'nonesiste': No such file or directory
```
`>` è lo stdout (descrittore 1), `2>` lo stderr: vedi [05-redirezioni.md](05-redirezioni.md). Con `&> tutto.txt` finirebbero insieme nello stesso file.
</details>

## Confronto e sincronizzazione
**19.** Le righe di `lista1.txt` che **non sono** in `lista2.txt`, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
sort lista1.txt | comm -23 - <(sort lista2.txt)
# arancia
# mela
```
`comm` vuole i file **ordinati**; `-23` toglie le colonne 2 (solo nel secondo) e 3 (in tutti e due). Un'altra via: `grep -vxFf lista2.txt lista1.txt | sort`.
</details>

**20.** Copia `origine/` in `destinazione/` **senza** la cartella `.git`. *(Cambia i file: si controlla l'elenco di `destinazione/`.)*
<details><summary>soluzione</summary>

```bash
rsync -a --exclude .git origine/ destinazione/
find destinazione | sort
# destinazione
# destinazione/LEGGIMI
# destinazione/css
# destinazione/css/s.css
# destinazione/index.html
```
Lo slash finale su `origine/` copia il **contenuto**; senza, si creerebbe `destinazione/origine/`.
</details>

## Se non sai da dove cominciare
| Devi... | Strumento |
|---|---|
| trovare file per nome, data, dimensione, tipo | `find . -name ... -mtime ... -size ... -type ...` ([02-find.md](02-find.md)) |
| escludere una cartella | `-not -path './vendor/*'` o `-prune` |
| fare qualcosa su ogni file trovato | `-exec comando {} +`, `-delete` |
| cambiare i permessi | `chmod` ottale (`640`) o simbolico (`g+w`, `o-r`) ([08-permessi.md](08-permessi.md)) |
| tutte le cartelle in un modo e i file in un altro | due `find` con `-type d` e `-type f` |
| vedere i permessi in numeri | `stat -c '%a %n' file` |
| un secondo nome per lo stesso file / un collegamento | `ln` / `ln -s` ([04-link.md](04-link.md)) |
| archivi | `tar czf` (crea), `tar tzf` (elenca), `tar xzf` (estrae) |
| separare output ed errori | `>` e `2>` |

Torna all'[indice dell'area](README.md)
