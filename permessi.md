## Valori numerici (notazione ottale) dei permessi
La modalità numerica usa numeri per rappresentare i permessi. Ogni permesso è rappresentato da un valore numerico:

    4: Lettura (r).
    2: Scrittura (w).
    1: Esecuzione (x)

## Permessi di default
1) per file: rw-rw-r-- => (4+2+0) (4+2+0) (4+0+0) => 664
1) cartelle: rwxrwxr-x => (4+2+1) (4+2+0) (4+0+1) => 775

### Esempi notazioni
    rwxrwxrwx => (4+2+1) (4+2+0) (4+2+1) => 777
    rwxr-xr-x => (4+2+1) (4+0+1) (4+0+1) => 775
    rw-rw-r-- => (4+2+0) (4+0+0) (4+0+0) => 644
    --------- => (0+0+0) (0+0+0) (0+0+0) => 000

## CHMOD per modificare i permessi
```bash
$ chmod [u|g|o|a][+|-|=][r|w|x] file_o_directory # SINTASSI
```
u: Utente.
g: Gruppo.
o: Altri.
a: Tutti (utente, gruppo e altri).
+: Aggiungi un permesso.
-: Rimuovi un permesso.
=: Imposta i permessi esattamente a quelli specificati.

### Esempi CHMOD
```bash
chmod ugo file   # SINTASSI: setta i permessi per user-group-others
chmod 755 file   # setta i permessi a 755 cioè (rwx)(r-x)(r-x)

chmod a+w file   # aggiunge permesso WRITE a ALL
chmod u+x file   # aggiunge permesso EXE a USER
chmod g-w file   # toglie permesso WRITE a GROUP
chmod ugo+x file # dà il permesso EXE a USER, GROUP, OTHERS (+ lungo da scrivere)
chmod o-x file   # toglie permesso EXE a OTHERS
chmod go-w file  # toglie permesso WRITE a GROUP e OTHERS
chmod -R o-w cartella/  # opera ricorsivamente su tutta la cartella
chmod -R a+r cartella/  # aggiunge READ a ALL per tutti i file dentro la cartella

umask # "maschera" = restituisce 0022
umask 777 # lo modifico a 777 per esempio
```
> I permessi di default sono 666 - 0022 (umask)

Quindi se voglio modificare i permessi di default x i file devo modificare la maschera, poi creo i file
```bash
umask 000 ; touch file2 file3 # avranno entrambi i permessi 777
```


```bash
chown utente file.txt       # utente diventa il proprietario di file.txt
chown alice:staff file.txt  # modifico contemporaneamente proprietario e gruppo di file.txt
chown :gruppo file.txt      # modifico solo il gruppo di file.txt

chown -R utente /directory/ # si può fare anche per un'intera directory con -R
```
