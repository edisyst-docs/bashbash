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
grep 'de*' logfile.txt    # ATTENZIONE: "d" seguita da 0 o più "e", quindi matcha QUALSIASI riga che contiene una "d"
grep 'de.*' logfile.txt   # UGUALE nel risultato: .* può essere vuoto. Per "de" seguito da qualcosa serve 'de.\+' (o -E 'de.+')
grep '^\.' logfile.txt    # righe che iniziano col punto (il \ indica un carattere speciale)
grep '[.ca]' logfile.txt  # righe contenenti almeno un carattere tra quelli in parentesi (un punto, una "a" o una "c")
grep '^[d]' logfile.txt   # righe che iniziano col carattere "d"
grep '[^.ca]' logfile.txt # righe contenenti almeno un carattere NON tra quelli in parentesi (quasi tutte: basta un solo altro carattere)
grep -v '[.ca]' logfile.txt # righe che NON contengono NESSUNO di quei caratteri: spesso è questo che si intende
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

## Opzioni avanzate
```bash
grep -A3 -B2 'ERROR' laravel.log # stampa anche 3 righe DOPO (After) e 2 PRIMA (Before) di ogni match
grep -C5 'ERROR' laravel.log     # 5 righe di contesto prima e dopo
grep -o 'user_id=[0-9]*' log     # stampa SOLO la parte che fa match, non l'intera riga
grep -l 'TODO' *.php             # stampa solo i NOMI dei file che contengono il match
grep -L 'strict_types' *.php     # stampa solo i nomi dei file che NON lo contengono
grep -m1 'ERROR' laravel.log     # si ferma al primo match (veloce su file enormi)
grep -q 'pattern' file           # silenzioso: non stampa niente, serve solo l'exit status (per gli if negli script)
grep -e '-v' file                # -e dice che quello che segue è un pattern, anche se inizia con il trattino
```

## Esempi pratici
```bash
grep -rn --include='*.php' --exclude-dir={vendor,node_modules} -E '\b(dd|dump|var_dump)\(' app/ # debug dimenticati prima di un deploy
grep -Ev '^\s*(#|;|$)' /etc/php/8.3/fpm/php.ini                  # config senza commenti né righe vuote: vedo solo le direttive attive
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' access.log | sort | uniq -c | sort -rn | head # estrae tutti gli IP e li conta
grep -oP '(?<=user=)\w+' app.log                                 # -P (PCRE): lookbehind, estrae solo il valore dopo "user="
grep -rl 'vecchio.dominio.it' . | xargs sed -i 's/vecchio\.dominio\.it/nuovo.dominio.it/g' # cerca e sostituisce in tutti i file che lo contengono
grep -c '' file                                                  # conta le righe (come wc -l ma conta anche l'ultima senza a capo)

if grep -q '^APP_DEBUG=true' .env; then                          # uso in uno script: -q + exit status
    echo "ATTENZIONE: debug attivo in produzione" >&2
fi
```
