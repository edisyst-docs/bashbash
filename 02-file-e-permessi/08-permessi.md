# Permessi

## Valori numerici (notazione ottale)
La modalità numerica usa numeri per rappresentare i permessi. Ogni permesso ha un valore:

    4: Lettura    (r)
    2: Scrittura  (w)
    1: Esecuzione (x)

I tre gruppi, nell'ordine, sono **user**, **group**, **others**.

## Permessi di default
1. per i file: `rw-r--r--` => (4+2+0) (4+0+0) (4+0+0) => **644**
2. per le cartelle: `rwxr-xr-x` => (4+2+1) (4+0+1) (4+0+1) => **755**

Le cartelle hanno in più il permesso di esecuzione: senza quello non potrei nemmeno fare `ls`.

### Esempi di notazione
    rwxrwxrwx => (4+2+1) (4+2+1) (4+2+1) => 777
    rwxr-xr-x => (4+2+1) (4+0+1) (4+0+1) => 755
    rw-rw-r-- => (4+2+0) (4+2+0) (4+0+0) => 664
    rw-r--r-- => (4+2+0) (4+0+0) (4+0+0) => 644
    --------- => (0+0+0) (0+0+0) (0+0+0) => 000

## CHMOD per modificare i permessi
> **SINTASSI**: `chmod [u|g|o|a][+|-|=][r|w|x] file_o_directory`

* Il primo parametro `[ugoa]` indica a chi devo cambiare i permessi:
  * `u`: (USER)   Utente
  * `g`: (GROUP)  Gruppo
  * `o`: (OTHERS) Altri
  * `a`: (ALL)    Tutti (utente, gruppo e altri)
* Il secondo parametro indica se aggiungere, rimuovere o impostare i permessi:
  * `+`: aggiungi un permesso
  * `-`: rimuovi un permesso
  * `=`: imposta i permessi esattamente a quelli specificati
* Il terzo parametro indica il tipo di permesso:
  * `r` (lettura)
  * `w` (scrittura)
  * `x` (esecuzione)
  * `s` (set uid/gid bit) => permesso speciale
  * `t` (sticky bit)      => permesso speciale

### Esempi CHMOD
> **NOTA**: i permessi di default sono 644 per i file e 755 per le cartelle.
```bash
chmod 644 file # setta i permessi per user(6) group(4) others(4): cioè (rw-)(r--)(r--)
chmod 755 file # setta i permessi a 755: cioè (rwx)(r-x)(r-x)

chmod u+x file     # aggiunge a USER il permesso EXE
chmod g-w file     # toglie   a GROUP il permesso WRITE
chmod o=rx file    # setta    a OTHERS i permessi READ, EXE
chmod go-w file    # toglie   a GROUP e OTHERS il permesso WRITE
chmod ugo+x file   # aggiunge a USER, GROUP, OTHERS il permesso EXE
chmod a+x file     # UGUALE   (ALL = USER + GROUP + OTHERS)
chmod +x file      # UGUALE
chmod -R o-w cart/ # opera ricorsivamente su tutta la cartella

chmod u=rwxs,g=rw,o=t file # do anche i bit speciali (NON sono al posto delle x) => rwsrw---T
chmod u-x,g+s,o+x file     # diventano rwSrwS--t
```
> **NOTA**: nella forma simbolica gli elenchi vanno separati dalla virgola **senza spazi**,
> altrimenti la shell interpreta il resto come nome di file.

## Permessi speciali
```bash
chmod +t protetta   # sticky bit: in una cartella solo l'owner può eliminare i file all'interno, a prescindere dai permessi sui file
chmod 1777 protetta # UGUALE, ma assegna anche i permessi standard 777. I permessi saranno rwx rwx rwt
ll protetta         # drwxrwxrwt => la "t" minuscola indica sticky bit + permesso x, altrimenti sarebbe "T"

chmod u+s eseguibile # set uid bit: il file viene eseguito con i permessi del proprietario, non di chi lo lancia
chmod 4777 eseguibile # UGUALE, ma assegna anche i permessi standard 777. I permessi saranno rws rwx rwx
ll $(which passwd)    # -rwsr-xr-x => la "s" indica set uid + permesso x, altrimenti sarebbe "S". Senza set uid passwd non potrebbe scrivere su /etc/shadow, che è di root

chmod g+s cartella   # set gid bit: i file creati dentro la cartella ereditano il gruppo della cartella
chmod 2777 cartella  # UGUALE, ma assegna anche i permessi standard 777. I permessi saranno rwx rws rwx
```

**Esempio: trovare il codice ottale di (rws)(rw-)(-wt)**
- i bit speciali `(setuid, setgid, sticky)` valgono 101, ovvero 5
  - i permessi speciali si mettono al posto della x, e sono maiuscoli se x=0, minuscoli se x=1
- il resto (i permessi classici) è 763
- i permessi "totali" sono **5763**

**Esempio: trovare il codice ottale di (r-x)(--S)(r-x)**
- i bit speciali valgono 010, ovvero 2
- il resto (i permessi classici) è 505
- i permessi "totali" sono **2505**

## UMASK per modificare i permessi di default
```bash
umask     # restituisce 0022. Quindi i permessi di default dei file sono 666 - 022 = 644
umask -S  # più leggibile: u=rwx,g=rx,o=rx
umask 777 # lo modifico a 777 per esempio. È completamente insensato (equivale a u=,g=,o=), è solo un esempio
```
> **NOTA**: la maschera è un valore che viene sottratto ai permessi di default.
- Nuovo file: 666 - 022 = 644
- Nuova cartella: 777 - 022 = 755

Se voglio modificare i permessi di default dei file devo modificare la maschera, poi creare i file:
```bash
umask 000 ; touch file2 file3 # avranno entrambi i permessi 666 (i file non ricevono mai la x dalla umask)
```

## Esempi pratici
```bash
stat -c '%a %U:%G %n' *                  # permessi in ottale, owner, gruppo e nome di ogni file: più leggibile di ls -l per i controlli
namei -l /var/www/app/storage/logs/laravel.log # mostra owner e permessi di OGNI cartella del percorso: trova quale blocca l'accesso

find /var/www -perm -o+w -type f         # file scrivibili da chiunque (others): da correggere
find / -xdev -perm -4000 -type f 2>/dev/null # tutti gli eseguibili con setuid: controllo di sicurezza periodico

chmod 600 ~/.ssh/id_ed25519 ~/.ssh/config    # ssh rifiuta chiavi private leggibili da altri
chmod 700 ~/.ssh
chmod 640 .env && chown deploy:www-data .env # .env leggibile dal web server ma non da tutti

chmod -R u=rwX,g=rX,o= progetto/         # X maiuscola: dà l'esecuzione solo alle cartelle (e ai file già eseguibili)
                                         # così con un solo comando cartelle 750 e file 640
```

### ACL: permessi a un utente specifico
Quando owner/gruppo/altri non bastano (es. dare accesso a un utente senza cambiare gruppo).
```bash
setfacl -m u:mario:rwx /srv/progetto             # mario ha rwx su quella cartella, senza toccare owner e gruppo
setfacl -d -m u:mario:rwx /srv/progetto          # -d (default): anche i file creati DOPO dentro la cartella ereditano la regola
getfacl /srv/progetto                            # mostra tutte le ACL. In ls -l compare un "+" dopo i permessi
setfacl -x u:mario /srv/progetto                 # rimuove la regola di mario
setfacl -R -m g:www-data:rwX storage/            # alternativa comune per le cartelle scrivibili di Laravel
```

Vedi anche: [09-proprietari.md](09-proprietari.md) per cambiare owner e gruppo di un file.
