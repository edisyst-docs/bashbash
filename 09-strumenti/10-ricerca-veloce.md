# Cercare in fretta: ripgrep, fd, fzf, bat, ncdu

> **Laboratorio**: `./lab.sh 09`, poi `cd 10-ricerca-veloce`. Due cartelle: `progetto/` (codice, note e log, in un repository git) e `spazio/` (file di dimensioni diverse, per `ncdu`).

`grep`, `find` e `du` ([../03-testo-e-regex/](../03-testo-e-regex/), [../02-file-e-permessi/02-find.md](../02-file-e-permessi/02-find.md)) bastano sempre, e sono ovunque. In un progetto con migliaia di file, però, si usano spesso dei sostituti più veloci e
più comodi, che per default **saltano da soli** quello che non serve (`.git`, `node_modules`, i file in `.gitignore`):

| Strumento | Sostituisce | Cosa fa | Pacchetto Ubuntu |
|---|---|---|---|
| **ripgrep** (`rg`) | `grep -r` | cerca **dentro** i file | `ripgrep` |
| **fd** | `find` | cerca **i file** per nome | `fd-find` (il comando è `fdfind`) |
| **fzf** | — | scelta interattiva da un elenco, con ricerca "a caso" (*fuzzy*) | `fzf` |
| **bat** | `cat` | mostra un file con i colori e i numeri di riga | `bat` (il comando è `batcat`) |
| **ncdu** | `du` | esplora lo spazio su disco, in modo interattivo | `ncdu` |

Sono tutti nell'immagine del laboratorio (ripgrep 14.1, fd 9.0, fzf 0.44, bat 0.24, ncdu 1.19). Su Debian e Ubuntu `fd` e `bat` hanno un nome diverso, perché `fd` e `bat` esistevano già come altri programmi:
```bash
alias fd=fdfind
alias bat=batcat            # nel ~/.bashrc (vedi ../01-basi/09-file-di-avvio.md)
```

## Il progetto di prova
```bash
cd ~/lab/10-ricerca-veloce/progetto
git log --oneline                  # un commit: il repository serve perché rg e fd leggono .gitignore
cat .gitignore                     # node_modules/  vendor/  logs/
fdfind                             # i file e le cartelle, senza quelle ignorate
# app/
# app/controller/
# app/controller/login.js
# app/controller/ordini.php
# app/modelli/ordine.py ... docs/README.md ... tests/test_utente.py
```
Ci sono file Python, JavaScript e PHP con dei commenti `TODO` e `FIXME`, una cartella `node_modules/` e `vendor/` (codice di terzi) e `logs/app.log` con 20000 righe.

## ripgrep
```bash
rg TODO                            # cerca TODO in tutti i file, ricorsivamente
# docs/README.md:TODO: scrivere la guida all'installazione.
# app/controller/login.js:  // TODO: limitare i tentativi
# app/modelli/ordine.py:    # TODO: gestire gli sconti
# app/modelli/utente.py:    # TODO: validare l'indirizzo email
```
`rg` **non entra** in `node_modules/`, `vendor/`, `logs/` e `.git/` perché sono in `.gitignore` (o nascosti), e salta i file binari. Sul terminale l'output è a colori e con i numeri di riga
(`-n`); in una pipe, come sopra, no.
```bash
rg -i fixme                        # -i: senza distinguere maiuscole e minuscole
rg -n SELECT -g '*.php'            # -g: solo i file che corrispondono al glob (-g '!*.md' li esclude)
# app/controller/ordini.php:5:    return $db->query("SELECT * FROM ordini WHERE utente = '$utente'");
rg -t py "def " -c                 # -t py: solo i file Python;  -c: quante righe per file
# app/modelli/ordine.py:3
# app/modelli/utente.py:3
# tests/test_utente.py:1
rg --type-list | grep -E '^(py|js|php|md):'    # i tipi noti: py: *.py, *.pyi ...
rg -l TODO                         # -l: solo i nomi dei file
rg -C1 importo_con_iva             # -C N: N righe di contesto prima e dopo (-A dopo, -B prima)
rg -w self -c                      # -w: parola intera
rg -F '(?, ?)'                     # -F: testo letterale, senza regex (qui i caratteri ? ( ) sono speciali)
rg -o '[a-z]+@[a-z.]+'             # -o: solo la parte che corrisponde
# tests/test_utente.py:anna@example.com
rg --files                         # elenca i file che rg guarderebbe (utile per vedere cosa ignora)
rg --stats TODO | tail -4          # 4 matches / 6 files searched / 0.000071 seconds spent searching
```
Il linguaggio delle regex è quello di Rust (simile a PCRE: `\d`, `\w`, `(?i)`): quasi tutto ciò che si sa di `grep -E` vale.

> **Dentro uno script, una CI o un container senza terminale: `rg` senza percorso legge stdin.** Con un percorso non indicato, `rg` decide da solo: se lo **standard input è una pipe o un file**, cerca lì e non nella cartella.
> In un terminale c'è un terminale e cerca in `./`; con `docker exec -T` o `docker compose exec -T` (come in una CI) no, e `rg TODO` **non trova niente** (`rg --debug TODO` dice
> `heuristic chose to search stdin`; il codice d'uscita è 1). Negli script si scrive sempre il percorso: `rg TODO .`.

### Cosa ignora, e come cambiarlo
```bash
rg -l "function inutile|libreria"              # niente: sono in node_modules/ e vendor/, ignorati
rg -l "function inutile|libreria" --no-ignore  # --no-ignore: guarda anche i file ignorati
# vendor/pacchetto/Lib.php
# node_modules/lib/index.js
rg --hidden --files | head -3                  # --hidden: anche i file nascosti (.gitignore, .github/...)
rg -uuu TODO                                   # -u: meno filtri (-uu anche i nascosti, -uuu anche i binari)
rg -c ERROR logs/                              # un percorso dato ESPLICITAMENTE si cerca comunque: logs/app.log:2857
rg -n '10\.0\.3\.\d+' --no-ignore logs/app.log | head -2
# 3:2026-09-04 10:03:21 WARN richiesta 3 da 10.0.3.3
```
Quando `rg` "non trova" una cosa che c'è, quasi sempre il file è ignorato: `--no-ignore` o `--hidden`.

Ripgrep sa anche **sostituire** nell'output (non nel file): `rg 'Ciao (\w+)' -r 'Salve $1'` mostra cosa diventerebbe. Per modificare i file lo si combina con `sed -i` o `perl -pi`:
`rg -l vecchio | xargs sed -i 's/vecchio/nuovo/g'`.

## fd
```bash
fdfind -e py                       # -e: per estensione
# app/modelli/ordine.py
# app/modelli/utente.py
# tests/test_utente.py
fdfind utente                      # un testo nel nome (è una regex, senza distinguere maiuscole se è tutto minuscolo)
fdfind -t d                        # -t d: solo le cartelle (-t f i file, -t l i collegamenti)
fdfind '^o.*\.py$'                 # una regex sul nome del file
# app/modelli/ordine.py
fdfind -HI -t d | sort | head -3   # -H: anche i nascosti, -I: anche quelli ignorati (.git/, node_modules/ ...)
fdfind -S +1k -HI .log             # -S: per dimensione (+1k: più grande di 1 KB): logs/app.log
fdfind -e md --changed-within 1d   # modificati nell'ultimo giorno (docs/README.md)
fdfind -e py -x wc -l              # -x: esegue un comando PER OGNI file, in parallelo
# 14 ./app/modelli/ordine.py ...
fdfind -e py -X grep -c def        # -X: UN comando solo con tutti i file come argomenti
# ./tests/test_utente.py:1  ./app/modelli/ordine.py:3  ./app/modelli/utente.py:3
```
Rispetto a `find`: la sintassi è più corta (`fd -e py` contro `find . -name '*.py'`), è più veloce, e ignora i file di `.gitignore` e i nascosti. Con `-x` l'ordine dell'output **non è garantito**, perché i comandi girano insieme.

## fzf
`fzf` legge un elenco da **stdin**, ne fa scegliere una riga con una ricerca che si aggiorna ad ogni tasto, e stampa quella scelta. È un "filtro interattivo" che si combina con tutto il resto.
```bash
fdfind -e py | fzf                 # si scrive "ord": evidenzia app/modelli/ordine.py. Invio: lo stampa
vim "$(fdfind -e py | fzf)"        # apre nell'editor il file scelto
cd "$(fdfind -t d | fzf)"          # entra nella cartella scelta
```
Non è un lavoro da terminale non interattivo, ma con `-f` (`--filter`) fa la ricerca e stampa il risultato senza l'interfaccia, ed è così che si prova negli script:
```bash
fdfind -e py | fzf -f ordine                   # app/modelli/ordine.py
rg --files | fzf -f "mod utente"               # parole separate da spazio: tutte devono comparire -> app/modelli/utente.py
rg --files | fzf -f "^app" --exact | head -2   # --exact: testo esatto invece che "a caso" (fuzzy)
rg -n TODO | fzf -f login                      # app/controller/login.js:3:  // TODO: limitare i tentativi
```
Nel linguaggio di ricerca di `fzf`: `abc` corrisponde a `a...b...c` in ordine, `'abc` esatto, `^abc` inizia con, `abc$` finisce con, `!abc` **non** contiene, `a | b` OR.

Le opzioni che si usano:
| Opzione | Cosa fa |
|---|---|
| `--height 40%` | non occupa tutto lo schermo: una finestra sotto il cursore |
| `-m` | selezione **multipla** (Tab per segnare le righe) |
| `--preview 'batcat --color=always {}'` | un riquadro con l'anteprima del file evidenziato (`{}` = la riga) |
| `--bind 'ctrl-r:reload(...)'` | un tasto che esegue un'azione, per esempio ricaricare l'elenco |
| `-q testo` | parte con la ricerca già scritta |
| `-1 -0` | se c'è un solo risultato lo sceglie da solo; se non ce ne sono esce |

```bash
fdfind -e py | fzf --height 40% --preview 'batcat --color=always --style=numbers {}'    # anteprima a destra
export FZF_DEFAULT_COMMAND='fdfind --type f'      # da dove prende l'elenco se non c'è stdin
export FZF_DEFAULT_OPTS='--height 40% --border'   # opzioni sempre attive (nel ~/.bashrc)
```
### Le scorciatoie di tastiera
Il pacchetto porta un file da caricare nel `~/.bashrc`, che aggiunge tre scorciatoie alla shell:
```bash
source /usr/share/doc/fzf/examples/key-bindings.bash      # su Debian/Ubuntu; nell'immagine Docker mancano le cartelle /usr/share/doc
```
| Tasti | Cosa fa |
|---|---|
| `Ctrl-R` | cerca nella **history** dei comandi, con la ricerca fuzzy (il più usato) |
| `Ctrl-T` | sceglie un file e ne incolla il percorso sulla riga di comando |
| `Alt-C` | sceglie una cartella ed entra |

Queste scorciatoie **non sono state provate**: richiedono un terminale interattivo, e nel laboratorio il file `key-bindings.bash` non c'è (l'immagine Ubuntu per container esclude `/usr/share/doc`).
Provati sono `fzf -f` e le opzioni sopra elencate dall'`--help` (`--preview`, `--height`, `--bind`, `--exact`).

## bat
`bat` è un `cat` con i colori della sintassi, i numeri di riga e il paginatore:
```bash
batcat app/modelli/ordine.py                       # a colori, con numeri di riga e una cornice (in un terminale)
batcat -p app/modelli/ordine.py                    # -p (plain): senza cornice e numeri
batcat -r 5:7 app/modelli/ordine.py                # -r: solo le righe da 5 a 7
batcat --list-languages | head -2                  # ActionScript:as / Ada:adb,ads,gpr ...
batcat --color=never file                          # senza colori (negli script)
```
In una pipe (`batcat file | altro`) `bat` si comporta come `cat`. Serve soprattutto come **anteprima** di `fzf` e per leggere file di configurazione. (`bat --version` dà `bat 0.24.0`.)

## ncdu e du: dov'è finito lo spazio
Il disco si è riempito, ma da cosa? `du` dà la risposta, `ncdu` la rende **navigabile**.
```bash
cd ~/lab/10-ricerca-veloce/spazio
du -sh .                           # 93M	.
du -h --max-depth=1 . | sort -rh   # le cartelle, dalla più grande
# 93M	.
# 59M	./video
# 25M	./cache
# 11M	./log
# 904K	./documenti
du -ah . | sort -rh | head -4      # i file e le cartelle più grandi in tutto l'albero: 40M ./video/registrazione.mp4 ...
```
`sort -rh` ordina "da più grande" i numeri con le unità (`-h`: 904K, 11M). Con `ncdu`:
```bash
ncdu .                             # esamina la cartella e apre un'interfaccia a schermo intero
ncdu -x /                          # -x: non esce dal filesystem (non scende in /proc, nei dischi montati)
ncdu -o spazio.json .              # salva l'esame in un file (progress: "... 3 files"): si riapre con  ncdu -f spazio.json
ncdu -o- . | ssh altro 'cat > spazio.json'   # su un server: esame dove sta il disco, lettura dove si vuole
```
Dentro `ncdu` (un'interfaccia a tasti, non provata nel laboratorio perché serve un terminale; i tasti sono quelli della documentazione):

| Tasto | Cosa fa |
|---|---|
| frecce, `Invio` | muoversi, entrare in una cartella (`←` esce) |
| `n`, `s` | ordina per **nome** o per **dimensione** |
| `d` | **cancella** il file o la cartella evidenziata (chiede conferma) |
| `g` | alterna dimensione e percentuale |
| `?` | l'aiuto con tutti i tasti |
| `q` | esce |

`ncdu` va lanciato con cautela con `sudo` (vede tutto, e `d` cancella davvero), e su un server **in produzione** un esame di `/` carica il disco: meglio `-x` e fuori orario.
`ncdu -o` ha in uscita un JSON con una struttura ad albero (`[1,2,{"progname":"ncdu","progver":"1.19",...},[{"name":"/root/lab/...","asize":4096,...`).

Una versione moderna, `ncdu 2.x`, è scritta in Zig e più veloce; quella di Ubuntu 24.04 è 1.19. I tasti sono gli stessi.

## Mettere insieme gli strumenti
```bash
# apri nell'editor il file scelto fra quelli che contengono TODO, con l'anteprima
vim "$(rg -l TODO | fzf --preview 'batcat --color=always {}')"

# scegli un file Python e mostra le sue funzioni
fdfind -e py | fzf -m | xargs rg -n "def "

# un alias per cercare nel codice con una selezione interattiva
cercacodice() { rg --line-number --no-heading "$@" | fzf --delimiter : --preview 'batcat --color=always --highlight-line {2} {1}'; }

# i 10 file più grandi sotto la cartella corrente
fdfind -t f -HI -x du -h {} | sort -rh | head
```
## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `fd: command not found` / `bat: command not found` | su Debian e Ubuntu si chiamano `fdfind` e `batcat` | `alias fd=fdfind`, `alias bat=batcat` |
| `rg` non trova qualcosa che c'è | il file è in `.gitignore`, è nascosto o è binario | `rg --no-ignore --hidden`, `-uuu`, `rg --files \| grep nome` per vedere se lo guarda |
| `rg PATTERN` non trova niente in uno script, in una CI o con `docker exec -T`, ma a mano sì | senza percorso, con lo stdin che è una pipe o un file, cerca in stdin | `rg PATTERN .` (il percorso esplicito) |
| `rg` non fa a meno di un percorso ignorato | un percorso passato **esplicitamente** si cerca sempre | normale: `rg ERROR logs/` funziona anche se `logs/` è ignorata |
| `rg` dà errore di regex con `(`, `?`, `+` | sono caratteri speciali | `rg -F 'testo con (parentesi)'`, o `\(` |
| `fd` non entra in una cartella | è ignorata da `.gitignore` | `fd -I`, e `-H` per i nascosti |
| con `fd -x` l'ordine dell'output cambia | i comandi girano in parallelo | `-j 1` (uno alla volta, nell'ordine di visita), o `| sort` |
| `fzf` non parte negli script o in una pipe senza terminale | serve un terminale per l'interfaccia | `fzf -f testo` (filtro non interattivo) |
| `ncdu` mostra meno di `du` | file in altri filesystem (`-x`), o permessi | `sudo ncdu`, e senza `-x` |
| `du -sh *` non mostra i file nascosti | `*` non li comprende | `du -h --max-depth=1` (li include); `du -sh .[!.]* *` dà errore se non ce ne sono |

Torna all'[indice dell'area](README.md)
