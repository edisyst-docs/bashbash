# GPG: cifrare file

> **Laboratorio**: `./lab.sh 08`, poi `cd 03-gpg`. Cosa contiene: [lab/](lab/).

GnuPG (`gpg`) è installato su quasi ogni distribuzione. Cifra e firma file con due metodi:
- **simmetrico**: una sola password, per cifrare e per decifrare. Semplice, per i propri backup
- **asimmetrico**: una coppia di chiavi
  - la chiave **pubblica** è la serratura: la do a chiunque, così può cifrare file che solo io potrò aprire
  - la chiave **privata** è la chiave di casa: resta solo a me e serve per decifrare

Video introduttivo: https://www.youtube.com/watch?v=WR2FGdNkkmI

## Cifratura simmetrica
```bash
gpg -c backup.sql                   # chiede una password e crea backup.sql.gpg (l'originale resta: va eliminato a mano)
gpg -c --armor note.txt             # --armor: output in testo ASCII (note.txt.asc), incollabile in una mail
gpg -o backup.sql -d backup.sql.gpg # decifra, chiedendo la password
tar -czf - cartella/ | gpg -c -o cartella.tar.gz.gpg # archivia e cifra in un passaggio, senza file intermedi in chiaro
gpg -d cartella.tar.gz.gpg | tar -xzf -              # il contrario
```

## Le chiavi
```bash
gpg --full-generate-key             # crea una coppia di chiavi: tipo (il default va bene), scadenza, nome, email, passphrase
                                    # la prima esecuzione crea ~/.gnupg
gpg --list-keys                     # le chiavi pubbliche che conosco (le mie e quelle importate)
gpg --list-secret-keys              # le mie chiavi private
gpg --fingerprint mario@example.com # impronta: la confronto a voce con il proprietario prima di fidarmi di una chiave importata
```
Una chiave si indica con l'email, il nome o l'ID.

## Scambiare le chiavi pubbliche
```bash
gpg --export --armor mario@example.com > mario.pub.asc   # esporto la MIA pubblica in un file di testo da condividere
gpg --show-keys mario.pub.asc                            # mostra cosa contiene un file di chiave, senza importarlo
gpg --import luigi.pub.asc                               # importo la pubblica di un altro, per poter cifrare file per lui
```
> **ATTENZIONE**: la chiave privata (`gpg --export-secret-keys`) si esporta solo per farne un backup in un posto sicuro.
> Chi ha la privata e la passphrase legge tutti i file cifrati per me.

## Cifrare e decifrare con le chiavi
```bash
gpg -e -r luigi@example.com contratto.pdf       # cifra PER luigi: crea contratto.pdf.gpg, solo lui potrà aprirlo
gpg -e -r luigi@example.com -r mario@example.com contratto.pdf # per più destinatari (aggiungendo me stesso posso riaprirlo anch'io)
gpg -o contratto.pdf -d contratto.pdf.gpg       # decifra con la MIA privata (chiede la passphrase)
```

## Firmare
La firma non nasconde il contenuto: dimostra chi ha prodotto il file e che non è stato modificato.
```bash
gpg --detach-sign --armor release.tar.gz        # crea release.tar.gz.asc, la firma separata
gpg --verify release.tar.gz.asc release.tar.gz  # "Good signature from ...": il file è integro e firmato da quella chiave
```
È così che si verificano i download di molti software (ISO, pacchetti) con la chiave pubblica del produttore.

## Esempio: scambio tra due utenti sulla stessa macchina
Per provare senza una seconda macchina: `edoardo` riceve un file cifrato da `utente`.
```bash
# come edoardo: creo le chiavi ed esporto la pubblica in un posto leggibile da tutti
gpg --full-generate-key
gpg --export --armor edoardo@example.com > /tmp/edoardo.pub.asc

# divento l'altro utente (lo creo se non c'è: sudo adduser utente)
su - utente
gpg --import /tmp/edoardo.pub.asc               # importa la pubblica di edoardo
echo "messaggio segreto" > segreto.txt
gpg -e -r edoardo@example.com segreto.txt       # alla domanda "Use this key anyway?" rispondo y: non l'ho ancora certificata
cat segreto.txt.gpg                             # illeggibile
cp segreto.txt.gpg /tmp/ && exit                # lo metto a disposizione e torno edoardo

# come edoardo
gpg -o segreto.txt -d /tmp/segreto.txt.gpg      # chiede la MIA passphrase e decifra
cat segreto.txt                                 # "messaggio segreto"
```
