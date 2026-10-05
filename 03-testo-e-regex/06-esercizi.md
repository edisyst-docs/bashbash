# Esercizi: grep, awk, sed e regex

> **Laboratorio**: `./lab.sh 03`, poi `cd 06-esercizi`. File pronti: `access.log`, `vendite.csv`, `contatti.txt`, `app.ini`, `passwd.txt`, `note.txt`, `verifica.sh` e la cartella `risposte/` (vedi [lab/](lab/)).

Diciotto esercizi sui comandi di quest'area ([01](01-stampa-e-taglia.md), [02](02-grep.md), [03](03-regex.md), [04](04-sed.md)): ognuno è un problema reale (un log, un CSV, un file di configurazione) e la risposta è **una riga di shell**.
Le soluzioni sono in fondo a ogni esercizio, nascoste: si provano prima da soli.

## Come si lavora
Ogni risposta si scrive in un file `risposte/NN.sh` (due cifre: `risposte/01.sh`) e **stampa il risultato**. `verifica.sh` lo confronta con la soluzione di riferimento:
```bash
cd ~/lab/06-esercizi
echo "grep -c '\" 404 ' access.log" > risposte/01.sh        # la risposta all'esercizio 1: un comando che stampa il numero
./verifica.sh 1                                              # solo l'esercizio 1
#   01  OK
# giusti 1, sbagliati 0, da fare 0
./verifica.sh                                                # tutti: quelli senza risposta sono "da fare"
```
Un risultato sbagliato mostra la differenza (`<` atteso, `>` ottenuto), per esempio con `echo 21` al posto del conteggio:
```
  01  SBAGLIATO
        1c1
        < 20
        ---
        > 21
        (< atteso, > ottenuto)
```
Il confronto è sull'**output esatto**, riga per riga: se l'enunciato dice "con uno spazio" o "in ordine alfabetico", conta. Nessun esercizio modifica i file originali: si stampa sullo `stdout` (con `sed` senza `-i`). Il codice d'uscita di `verifica.sh`
è `0` solo se nessuna risposta è sbagliata.

## I dati
`access.log`: 200 richieste in formato *combined*. Per `awk` i campi sono `$1` l'IP, `$4` la data (`[25/Sep/2026:10:00:00`), `$7` il percorso, `$9` lo **status** HTTP, `$10` i **byte**:
```
10.0.0.5 - - [25/Sep/2026:10:00:00 +0200] "GET / HTTP/1.1" 200 200 "-" "curl/8.5"
```
`vendite.csv`: `data,negozio,prodotto,quantita,prezzo` (con intestazione, 60 righe). `contatti.txt`: nome, email e `tel:`. `app.ini`: un file INI con tre sezioni. `passwd.txt`: nel formato di `/etc/passwd`
(`utente:x:UID:GID:nome:home:shell`). `note.txt`: blocchi fra `START` e `END`.

## Log di accesso (`access.log`)
**1.** Quante richieste hanno avuto status **404**? (un numero)
<details><summary>soluzione</summary>

```bash
grep -c '" 404 ' access.log          # il pattern comprende le virgolette e gli spazi: non confonde un 404 nei byte
# 20
```
</details>

**2.** Quanti **IP diversi** hanno fatto richieste? (un numero)
<details><summary>soluzione</summary>

```bash
cut -d' ' -f1 access.log | sort -u | wc -l
# 5
```
</details>

**3.** I **due IP** con più richieste, nel formato `IP conteggio` (uno per riga, dal più attivo).
<details><summary>soluzione</summary>

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -2 | awk '{print $2, $1}'
# 10.0.0.5 75
# 192.168.1.20 50
```
`uniq -c` mette il conteggio **prima**; l'ultimo `awk` inverte le colonne. Si prende solo il secondo posto perché il terzo ha un pareggio.
</details>

**4.** Quanti **byte** in totale sono stati serviti con status **200**? (un numero)
<details><summary>soluzione</summary>

```bash
awk '$9 == 200 {s += $10} END {print s}' access.log
# 3018360
```
</details>

**5.** I **percorsi** richiesti, uno per riga, senza ripetizioni, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
cut -d' ' -f7 access.log | sort -u
# /
# /admin
# /api/ordini
# /api/utenti
# /carrello
# /img/logo.png
# /login
```
</details>

**6.** Le richieste **per minuto**, nel formato `HH:MM conteggio` (uno spazio), in ordine di orario. *Suggerimento*: `substr($4, 14, 5)` estrae `HH:MM` da `[25/Sep/2026:10:00:00`; un array associativo conta.
<details><summary>soluzione</summary>

```bash
awk '{c[substr($4, 14, 5)]++} END {for (m in c) print m, c[m]}' access.log | sort
# 10:00 60
# 10:01 60
# 10:02 60
# 10:03 20
```
Gli array di `awk` non hanno un ordine: per questo il `sort` finale.
</details>

## CSV (`vendite.csv`)
**7.** L'**incasso totale** (`quantita * prezzo` di tutte le righe) con **due decimali**. (un numero)
<details><summary>soluzione</summary>

```bash
awk -F, 'NR > 1 {s += $4 * $5} END {printf "%.2f\n", s}' vendite.csv
# 2367.60
```
`-F,` separa per virgola; `NR > 1` salta l'intestazione.
</details>

**8.** L'incasso **per negozio**, nel formato `negozio incasso` (due decimali), in ordine alfabetico di negozio.
<details><summary>soluzione</summary>

```bash
awk -F, 'NR > 1 {s[$2] += $4 * $5} END {for (n in s) printf "%s %.2f\n", n, s[n]}' vendite.csv | sort
# Milano 57.60
# Napoli 1942.20
# Roma 99.00
# Torino 268.80
```
</details>

**9.** Il **prodotto più venduto** per quantità totale. (solo il nome)
<details><summary>soluzione</summary>

```bash
awk -F, 'NR > 1 {q[$3] += $4} END {for (p in q) print q[p], p}' vendite.csv | sort -rn | head -1 | cut -d' ' -f2
# quaderno
```
(`quaderno` 84, `zaino` 78, `righello` 72, `penna` 66.)
</details>

## File di configurazione (`app.ini`) con sed
**10.** Il file **senza commenti** (righe che cominciano per `;` o `#`) e **senza righe vuote**.
<details><summary>soluzione</summary>

```bash
grep -Ev '^[;#]|^$' app.ini
# [app]
# nome = demo
# debug = true
# [db]
# host = localhost
# ...
```
Anche con `sed -e '/^[;#]/d' -e '/^$/d' app.ini`.
</details>

**11.** Il file **intero**, ma con `debug = true` cambiato in `debug = false` **solo nella sezione `[app]`** (le altre due restano `true`). Si stampa, non si modifica.
<details><summary>soluzione</summary>

```bash
sed '/^\[app\]/,/^\[/ s/^debug = true/debug = false/' app.ini
# ; configurazione dell'applicazione
# [app]
# nome = demo
# debug = false
#
# # il database
# [db]
# host = localhost
# debug = true
# ...
```
L'indirizzo `/inizio/,/fine/` limita la sostituzione al blocco che va da `[app]` alla riga che comincia con `[` successiva. È lo schema di *sed* per "solo in questa sezione" ([04-sed.md](04-sed.md)).
</details>

## Regex (`contatti.txt`)
**12.** Le **email valide**, una per riga (nell'ordine del file). Non vanno prese `bruno.verdi(at)example.com`, `carla@`, `dario@example` (senza dominio con punto) né `luigi @ example.com`.
<details><summary>soluzione</summary>

```bash
grep -Eo '[A-Za-z0-9._-]+@[A-Za-z0-9-]+(\.[A-Za-z]+)+' contatti.txt
# anna.rossi@example.com
# elena_g@mail.example.org
# fabio-b@sub.dominio.it
# hugo.fabbri@example.co.uk
```
`-o` stampa solo la parte che corrisponde. La parte dopo la `@` pretende almeno un `.suffisso`: per questo `dario@example` non c'è.
</details>

**13.** I numeri di **cellulare** (cominciano per `3`) dopo `tel:`, **senza spazi né trattini**, uno per riga.
<details><summary>soluzione</summary>

```bash
grep -o 'tel: .*' contatti.txt | cut -c6- | tr -d ' -' | grep '^3'
# 3331234567
# 3407654321
# 3471112233
# 3289990001
# 3665554433
```
I fissi (`06 ...`, `02 ...`) cominciano per `0` e vengono scartati dall'ultimo `grep`.
</details>

## `passwd.txt` e `note.txt`
**14.** Gli utenti con shell **`/bin/bash`**, nel formato `utente:home`, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
awk -F: '$7 == "/bin/bash" {print $1 ":" $6}' passwd.txt | sort
# anna:/home/anna
# carla:/home/carla
# dario:/home/dario
# root:/root
```
</details>

**15.** L'utente con l'**UID più alto** fra quelli "veri" (**da 1000 a 59999**, per escludere `nobody`, 65534). (solo il nome)
<details><summary>soluzione</summary>

```bash
awk -F: '$3 >= 1000 && $3 < 60000 {print $3, $1}' passwd.txt | sort -n | tail -1 | cut -d' ' -f2
# dario
```
`sort -n` ordina per **numero** (con un ordinamento alfabetico `1500` verrebbe prima di `999`).
</details>

**16.** Le righe **fra `START` e `END`** di `note.txt`, **senza** le righe `START` e `END` (anche se i blocchi sono più di uno).
<details><summary>soluzione</summary>

```bash
sed -n '/START/,/END/p' note.txt | grep -v -e START -e END
# uno
# due
# tre
# quattro
```
</details>

## Ancora su `access.log`
**17.** Gli **IP** che hanno ricevuto almeno un errore **500 o 503**, senza ripetizioni, in ordine alfabetico.
<details><summary>soluzione</summary>

```bash
grep -E '" (500|503) ' access.log | cut -d' ' -f1 | sort -u
# 10.0.0.5
# 10.0.0.9
# 192.168.1.20
```
(Un'altra via: `awk '$9 == 500 || $9 == 503 {print $1}' access.log | sort -u`.)
</details>

**18.** Le prime **tre richieste con più di 49000 byte**, nel formato `percorso byte`, nell'ordine del file.
<details><summary>soluzione</summary>

```bash
awk '$10 > 49000 {print $7, $10}' access.log | head -3
# /api/ordini 49053
# /admin 50050
# /img/logo.png 49900
```
</details>

## Se non sai da dove cominciare
| Devi... | Strumento |
|---|---|
| contare le righe che corrispondono | `grep -c`, oppure `... \| wc -l` |
| prendere una colonna | `cut -d' ' -f3`, `awk '{print $3}'` |
| contare i doppioni | `sort \| uniq -c \| sort -rn` |
| sommare, raggruppare, calcolare | `awk` con `s += $4` e array associativi |
| estrarre una parte di una riga | `grep -o`, `sed -n 's/.../\1/p'` |
| modificare solo in una zona | `sed '/da/,/a/ s/x/y/'` |
| scrivere la regex | [03-regex.md](03-regex.md); si prova con `grep -oE 'REGEX' file` |

Torna all'[indice dell'area](README.md)
