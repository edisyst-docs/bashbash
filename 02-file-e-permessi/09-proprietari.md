# Proprietario e gruppo di un file

## CHOWN e CHGRP
```bash
chown utente file.txt       # utente diventa il proprietario di file.txt
chown -R utente /directory/ # si può fare anche per un'intera directory con -R
chown alice:staff file.txt  # modifico contemporaneamente proprietario e gruppo di file.txt
chown :gruppo file.txt      # modifico solo il gruppo di file.txt
chgrp  gruppo file.txt      # UGUALE (comando apposito "change group")
```

## Esempio completo: cartella di gruppo
Creo alcuni utenti e un gruppo, poi una cartella accessibile solo a quel gruppo.
```bash
useradd -m messi                # adduser è UGUALE ma setta tutto ai valori di default, quindi abitualmente userò adduser
useradd -m benzema              # useradd permette invece di specificare le opzioni una per una
useradd -m ronaldo              # -m crea anche la /home/ del nuovo utente
useradd -m -s /bin/bash ronaldo # -s specifica la shell di default
sudo passwd ronaldo             # devo settargli la prima password per poterlo usare

groupadd realmadrid
usermod -aG realmadrid ronaldo  # aggiungo ronaldo al gruppo realmadrid
usermod -aG realmadrid benzema
groups ronaldo                  # verifico a quali gruppi appartiene ronaldo
id ronaldo                      # UGUALE, con qualche info in più

mkdir /realmadrid_data
chown :realmadrid /realmadrid_data # cambio solo il gruppo di /realmadrid_data
chown ronaldo:realmadrid /data     # così cambio sia owner che gruppo
chmod 770 /realmadrid_data         # rwxrwx---: ronaldo e il gruppo possono tutto, gli altri niente

sudo -u ronaldo touch /realmadrid_data/test_file # TEST: creo un file come ronaldo, se i permessi sono corretti funziona
sudo -u messi ls /realmadrid_data                # TEST: messi non può vedere il contenuto di /realmadrid_data
```

## Gruppo condiviso tra due utenti
Per creare file che appartengono a ronaldo ma modificabili anche da messi, serve un gruppo condiviso.
```bash
groupadd shared
usermod -aG shared ronaldo
usermod -aG shared messi

mkdir /shared_files
chown ronaldo:shared /shared_files # Owner: ronaldo - Gruppo: shared (quindi anche messi può accedere)
chgrp shared /shared_files         # cambio solo il gruppo. Può farlo solo chi appartiene a entrambi i gruppi
chmod 770 /shared_files            # rwxrwx---: ronaldo e shared possono fare tutto, altri niente
chmod g+s /shared_files            # setgid: ogni file creato in /shared_files avrà come gruppo proprietario "shared"

sudo -u ronaldo touch /shared_files/ronaldo_file                  # creo un file come ronaldo
sudo -u messi sh -c 'echo "Modificato da Messi" >> /shared_files/ronaldo_file' # TEST: messi può modificare il file di ronaldo
```
> **ATTENZIONE**: `sudo -u messi echo "..." >> file` **non** funziona come ci si aspetta.
> La redirezione `>>` viene eseguita dalla shell corrente, con l'utente corrente, non da messi.
> Per far valere l'utente anche sulla scrittura serve `sudo -u messi sh -c '... >> file'`.

## Alternativa: permessi larghi (sconsigliata)
È più generica ma anche pericolosa come soluzione, perché apre il file a chiunque.
```bash
sudo -u ronaldo mkdir /home/ronaldo/shared_files
chmod 777 /home/ronaldo/shared_files          # do tutti i permessi a tutti, non solo a messi (PERICOLOSO)
sudo -u ronaldo touch /home/ronaldo/prova2.txt
chmod 666 /home/ronaldo/prova2.txt            # do tutti i permessi a tutti, non solo a messi (PERICOLOSO)

chown ronaldo:messi /home/ronaldo/prova3.txt  # ALTERNATIVA: cambio il gruppo proprietario di prova3.txt
chmod 660 /home/ronaldo/prova3.txt            # solo ronaldo (proprietario) e messi (gruppo) possono leggere e scrivere
```

## Pulizia dopo le prove
```bash
userdel -r messi        # -r rimuove anche la home
userdel -r ronaldo
userdel -r benzema
groupdel realmadrid     # rimuovo il gruppo
rm -rf /realmadrid_data # rimuovo la directory
```

Vedi anche: [08-permessi.md](08-permessi.md) per chmod e i bit speciali, [../06-sistema/02-utenti.md](../06-sistema/02-utenti.md) per la gestione degli utenti.
