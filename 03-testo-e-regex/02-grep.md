# grep

Cerca specifiche stringhe di testo o regex all'interno di file, cartelle o output di altri comandi.

## Sintassi base
```bash
grep 'stringa' file            # SINTASSI BASE
cat file | grep 'stringa'      # ALTERNATIVA
grep 'stringa' file1 file2     # può cercare anche in più file contemporaneamente
grep riga file*                # cerca la parola 'riga' in tutti i file che si chiamano file*
grep -r --include="file*" riga # UGUALE
```

## Opzioni più usate
```bash
grep "errore" logfile.txt    # cerca la parola "errore" e restituisce le righe dove la trova
grep -i "errore" logfile.txt # UGUALE ma non distingue maiuscole/minuscole, quindi trova anche ERRORE, Errore, ecc.
grep -n "errore" logfile.txt # restituisce anche gli indici delle righe che fanno matching
cat  -n logfile.txt          # verifico effettivamente che l'indice sia corretto
grep -c "errore" logfile.txt # restituisce solo il numero di righe trovate (con almeno 1 match per riga)

grep -v "errore" logfile     # grep INVERSO: esclude le righe contenenti "errore"
grep -r "errore" /var/log/   # cerca ricorsivamente "errore" in tutti i file dentro /var/log/
```

## Match esatto di parola e di riga
```bash
grep -w "dei" logfile       # cerca la parola esatta "dei" e non le parole che la contengono
grep "\<dei\>" logfile      # UGUALE, questa sarebbe la regex corrispondente
grep -x "Ciao raga" logfile # cerca la riga esatta "Ciao raga"
grep "^Ciao raga$" logfile  # UGUALE, questa sarebbe la regex corrispondente
```

## Pattern da file e regex estese
```bash
grep -f regexfile logfile  # cerca in OR tutte le regex contenute in regexfile dentro logfile
grep -E '[0-9]{3}' logfile # -E accetta le regex estese; cerca tutte le sequenze di 3 numeri
egrep '[0-9]{3}' logfile   # UGUALE (deprecato in favore di grep -E)
fgrep '[circa]' logfile    # cerca esattamente [circa]: le [] e i simboli non li interpreta come regex
```
Per la sintassi completa vedi [03-regex.md](03-regex.md).

## Esempi di pattern
```bash
grep '^b' logfile.txt     # righe che iniziano per "b"
grep 'fine$' logfile.txt  # righe che finiscono con la parola "fine"
grep errore *             # cerca la parola "errore" in tutti i file della cartella corrente
grep 'de.' logfile.txt    # righe contenenti "dei", "del", "degli", "delle"
grep 'de*' logfile.txt    # righe contenenti "de", "dei", "del", "degli", "delle", "deambulante"
grep '^\.' logfile.txt    # righe che iniziano col punto (il \ indica un carattere speciale)
grep '[.ca]' logfile.txt  # righe contenenti almeno un carattere tra quelli in parentesi (un punto, una "a" o una "c")
grep '^[d]' logfile.txt   # righe che iniziano col carattere "d"
grep '[^.ca]' logfile.txt # righe contenenti almeno un carattere NON tra quelli in parentesi
```

## In pipeline
```bash
cat script.md | grep ciao       # apre "script.md" e filtra le righe contenenti "ciao"
cat script.md | grep -c ciao    # UGUALE, ma restituisce solo il numero di righe filtrate
cat script.md | grep -n ciao    # UGUALE, ma restituisce anche gli indici delle righe filtrate
cat script.md | grep -v ciao    # apre "script.md" ed esclude le righe contenenti "ciao"
cat script.md | grep -v '^[#;]' # apre "script.md" ed esclude le righe che iniziano per # o per ; (trucco per saltare i commenti di un file di config)
grep ciao script.md | grep ls   # filtra le righe contenenti "ciao" e sul risultato filtra quelle contenenti "ls"
```
