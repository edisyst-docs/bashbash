# Comandi base

> **SINTASSI**: `nome_comando [flag_opzionali] [argomenti_obbligatori]`

## ls: elencare il contenuto di una cartella
```bash
ls -R cartella   # mostra ricorsivamente tutti i file di tutte le sottocartelle
ls --color       # colora i file in base al tipo
ls -s            # mostra anche le dimensioni dei file
ls [a,e]*        # mostra i file che cominciano per "a" o per "e"
ls -l doc*.rar   # mostra i file che si chiamano docXXXXX.rar
ls -l doc?.rar   # mostra i file che si chiamano docX.rar (un solo carattere)
ls -l | grep ^d  # mostra solo le directory: è un trucco perché con "ls -l" le directory iniziano per "d"
```

## stat: come ls -l ma con più dettagli
```bash
stat .            # simile a "ls -l" ma con più info (relative specialmente all'inode)
stat -c '%U' .    # mi dice solo chi è l'owner della cartella
```

## mv con la brace expansion
```bash
mv testo{,.old}     # equivale a: mv testo testo.old
mv testo.{old,new}  # equivale a: mv testo.old testo.new
mv testo{.old,}     # equivale a: mv testo.old testo
```
Vedi [../05-scripting/08-espansioni.md](../05-scripting/08-espansioni.md) per il funzionamento completo della brace expansion.

## Dove sono
```bash
pwd  # stampa la directory corrente
```

## echo con calcoli e sottocomandi
```bash
echo ciao ho $((2024-1981)) anni  # le doppie parentesi eseguono l'operazione aritmetica
echo ciao ho $[2024-1981] anni    # DEPRECATO: sintassi vecchia, funziona ma va sostituita con $(( ))

echo ciao ci sono $(ls | wc) righe, parole e lettere nei file qui dentro # wc = words count
echo ciao ci sono $(ls | wc -w) parole nei file qui dentro
```

Vedi anche: [../02-file-e-permessi/01-file-base.md](../02-file-e-permessi/01-file-base.md) per `cp`, `mv`, `rm`, `mkdir` e `touch`.
