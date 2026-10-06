# Comandi base

> **Laboratorio**: `./lab.sh 01`, poi `cd 04-comandi-base`. File pronti: `doc1.rar`, `doc22.rar`, `docA.rar`, `apple`, `eagle`, `zebra`, `testo`, le cartelle `d1/` e `d2/`.

> **SINTASSI**: `nome_comando [flag_opzionali] [argomenti_obbligatori]`

## ls: elencare il contenuto di una cartella
```bash
ls -R cartella   # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color       # colora i file in base al tipo
ls -s            # mostra anche le dimensioni dei file
ls [a,e]*        # mostra i file che cominciano per "a" o per "e"
# apple  eagle
ls -l doc*.rar   # mostra i file che si chiamano docXXXXX.rar
ls -l doc?.rar   # mostra i file che si chiamano docX.rar (un solo carattere)
# doc1.rar  docA.rar                    <- doc22.rar non c'è: ha DUE caratteri dopo "doc"
ls -l | grep ^d  # mostra solo le directory: è un trucco perché con "ls -l" le directory iniziano per "d"
```
In `[a,e]` la virgola è un carattere **come gli altri**: l'insieme è `a`, `,` ed `e` (un file che comincia per virgola corrisponderebbe). Basta `[ae]*`, o `[a-e]*` per un intervallo.
`*` e `?` li espande la **shell**, prima di lanciare `ls`: se nessun file corrisponde, `ls` riceve il pattern tale e quale e risponde `No such file or directory`.

## stat: come ls -l ma con più dettagli
```bash
stat .            # simile a "ls -l" ma con più info (relative specialmente all'inode)
#   File: .
#   Size: 4096      	Blocks: 8          IO Block: 4096   directory
# Device: 0,88	Inode: 1021980     Links: 4
stat -c '%U' .    # mi dice solo chi è l'owner della cartella
# root
```

## mv con la brace expansion
```bash
mv testo{,.old}     # equivale a: mv testo testo.old
mv testo.{old,new}  # equivale a: mv testo.old testo.new
mv testo{.old,}     # equivale a: mv testo.old testo
```
Eseguiti uno dopo l'altro, `ls testo*` mostra `testo.old`, poi `testo.new`, poi di nuovo `testo`.
Vedi [../05-scripting/08-espansioni.md](../05-scripting/08-espansioni.md) per il funzionamento completo della brace expansion.

## Dove sono
```bash
pwd  # stampa la directory corrente
```

## echo con calcoli e sottocomandi
```bash
echo ciao ho $((2024-1981)) anni  # le doppie parentesi eseguono l'operazione aritmetica
# ciao ho 43 anni
echo ciao ho $[2024-1981] anni    # DEPRECATO: sintassi vecchia, funziona ma va sostituita con $(( ))
# ciao ho 43 anni

echo ciao ci sono $(ls | wc) righe, parole e lettere nei file qui dentro # wc = words count
# ciao ci sono 9 9 58 righe, parole e lettere nei file qui dentro      <- i tre numeri di wc: righe, parole, byte
echo ciao ci sono $(ls | wc -w) parole nei file qui dentro
# ciao ci sono 9 parole nei file qui dentro
```
(`wc` conta righe, parole e **byte**, non lettere: per i caratteri `wc -m`.)

Vedi anche: [../02-file-e-permessi/01-file-base.md](../02-file-e-permessi/01-file-base.md) per `cp`, `mv`, `rm`, `mkdir` e `touch`.
