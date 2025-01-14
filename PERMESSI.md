## Valori numerici (notazione ottale) dei permessi
La modalità numerica usa numeri per rappresentare i permessi. Ogni permesso è rappresentato da un valore numerico:

    4: Lettura (r).
    2: Scrittura (w).
    1: Esecuzione (x)

## Permessi di default
1. per file: rw-r--r-- => (4+2+0) (4+0+0) (4+0+0) => 644
2. cartelle: rwxrwxr-x => (4+2+1) (4+0+1) (4+0+1) => 755 (in più c'è il permesso di EXE, altrimenti non potrei manco fare `ls`)

### Esempi notazioni
    rwxrwxrwx => (4+2+1) (4+2+0) (4+2+1) => 777
    rwxr-xr-x => (4+2+1) (4+2+1) (4+0+1) => 775
    rw-rw-r-- => (4+2+0) (4+2+0) (4+0+0) => 644
    --------- => (0+0+0) (0+0+0) (0+0+0) => 000

## CHMOD per modificare i permessi
> **SINTASSI**: `chmod` `[u|g|o|a]` `[+|-|=]` `[r|w|x]` `file_o_directory`
```bash
chmod [u|g|o|a][+|-|=][r|w|x] file_o_directory # SINTASSI
```
* Il primo parametro [ugoa] indica a chi devo cambiare i permessi.
  * u: Utente.  
  * g: Gruppo.  
  * o: Altri.  
  * a: Tutti (utente, gruppo e altri).  
* Il secondo parametro indica se aggiungere (+), rimuovere (-) o impostare (=) i permessi.
  * +: Aggiungi un permesso.  
  * -: Rimuovi un permesso.  
  * =: Imposta i permessi esattamente a quelli specificati.  
* Il terzo parametro indica il tipo di permesso
  * r (lettura)
  * w (scrittura)
  * x (esecuzione)

### Esempi CHMOD
```bash
chmod 644 file   # setta i permessi per user(6) group(4) others(4): cioè (rw-)(r--)(r--)
chmod 755 file   # setta i permessi a 755: cioè (rwx)(r-x)(r-x)

chmod a+w file   # aggiunge permesso WRITE a ALL
chmod u+x file   # aggiunge permesso EXE a USER
chmod g-w file   # toglie permesso WRITE a GROUP
chmod ugo+x file # aggiunge a USER, GROUP, OTHERS il permesso EXE
chmod o=rwx file # aggiunge a OTHERS i permessi EXE, READ, WRITE
chmod o-x file   # toglie permesso EXE a OTHERS
chmod go-w file  # toglie permesso WRITE a GROUP e OTHERS
chmod -R o-w cartella/  # opera ricorsivamente su tutta la cartella
chmod -R a+r cartella/  # aggiunge READ a ALL per tutti i file dentro la cartella

mkdir protetta
chmod +t protetta  # setta sticky bit: solo il proprietario può cancellare i file all'interno, a prescindere dai permessi sui file
chmod +s protetta  # setta setuid bit: i file eseguibili all'interno verranno eseguiti con i permessi del proprietario
chmod +r protetta  # setta setgid bit: i file eseguibili all'interno verranno eseguiti con i permessi del gruppo proprietario
```


### UMASK per modificare i permessi di default
```bash
umask     # restituisce 0022. Quindi i permessi di default sono 666 - 0022 = 644
umask -S  # più leggiible: u=rwx,g=rx,o=rx
umask 777 # lo modifico a 777 per esempio. E' completamenmte insensato, equivale a u=,g=,o=, è solo un esempio
```
> **NOTA**: la maschera è un valore che viene sottratto ai permessi di default.
 
Se voglio modificare i permessi di default dei file devo modificare la maschera, poi creo i file
```bash
umask 000 ; touch file2 file3 # avranno entrambi i permessi 777
```



## CHOWN per modificare il proprietario
```bash
chown utente file.txt       # utente diventa il proprietario di file.txt
chown alice:staff file.txt  # modifico contemporaneamente proprietario e gruppo di file.txt
chown :gruppo file.txt      # modifico solo il gruppo di file.txt
chown -R utente /directory/ # si può fare anche per un'intera directory con -R

useradd -m messi                 
useradd -m benzema
useradd -m ronaldo               # -m crea anche la /home/ del nuovo utente
useradd -m -s /bin/bash ronaldo  # -s specifica la shell di default
sudo passwd ronaldo              # devo settargli la prima password per poterlo usare

groupadd realmadrid             
usermod -aG realmadrid ronaldo       # aggiungo ronaldo al gruppo realmadrid
usermod -aG realmadrid benzema
groups ronaldo                       # verifico a quali gruppi appartiene ronaldo
id ronaldo                           # verifico a quali gruppi appartiene ronaldo

mkdir /realmadrid_data              
chown :realmadrid /realmadrid_data  # cambio solo il gruppo di /realmadrid_data
chown ronaldo:realmadrid /data      # così cambio sia owner che gruppo
chmod 770 /realmadrid_data          # cambio i permessi di /realmadrid_data  

-u ronaldo touch /realmadrid_data/test_file  # TEST: creo un file come ronaldo: se i permessi sono corretti, posso farlo
-u messi ls /realmadrid_data                 # TEST: messi non può vedere il contenuto di /realmadrid_data

# Per creare file che appartengono a ronaldo, ma che possono essere modificati anche da messi, posso creare un gruppo condiviso
groupadd shared
usermod -aG shared ronaldo
usermod -aG shared messi

mkdir /shared_files
chown ronaldo:shared /shared_files   # Owner: ronaldo - Gruppo: shared (quindi anche messi può accedere a /shared_files) 
chgrp shared /shared_files           # cambio il gruppo. Deve farlo ronaldo, può farlo solo chi appartiene a entrambi i gruppi
chmod 770 /shared_files              # rwxrwx---: ronaldo e shared possono fare tutto, altri niente
chmod g+s /shared_files              # setto il bit setgid: ogni file creato in /shared_files avrà come gruppo proprietario "shared"
sudo -u ronaldo touch /shared_files/ronaldo_file                       # creo un file come ronaldo
sudo -u messi echo "Modificato da Messi" >> /shared_files/ronaldo_file # TEST: messi può modificare il file di ronaldo

# In alternativa posso fare così: è più generica ma anche pericolosa come soluzione
sudo -u ronaldo mkdir /home/ronaldo/shared_files   # creo una cartella condivisa come ronaldo
chmod 777 /home/ronaldo/shared_files          # do tutti i permessi a tutti, non solo a messi (PERICOLOSO)
sudo -u ronaldo touch /home/ronaldo/prova2.txt     # creo un file come ronaldo
chmod 666 /home/ronaldo/prova2.txt            # do tutti i permessi a tutti, non solo a messi (PERICOLOSO)
chown ronaldo:messi /home/ronaldo/prova3.txt  # ALTERNAVIVA: cambio il gruppo proprietario di prova3.txt
chmod 660 /home/ronaldo/prova3.txt                 # Solo ronaldo (proprietario) e messi (gruppo) possono leggere e scrivere il file
```


## SUDO per impersonare un utente
```bash
su - ronaldo                         # cambio utente a ronaldo (sarò loggato come ronaldo)
sudo -i -u ronaldo                   # UGUALE, se ho accesso root posso impersonalo senza inserire la sua password
sudo -u ronaldo ls /root             # UGUALE ma posso anche specificare il comando da eseguire

# DOPO LE PROVE POSSO ELIMINARE UTENTI, GRUPPI, CARTELLE
userdel -r messi        # -r rimuove anche la home
userdel -r ronaldo
userdel -r benzema
groupdel realmadrid     # rimuovo il gruppo
rm -rf /realmadrid_data # rimuovo la directory

```
