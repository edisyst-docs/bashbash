# Utenti e gruppi

## Chi sono, chi è collegato
```bash
whoami     # restituisce il mio username
echo $USER # UGUALE
users      # indica tutti gli utenti connessi

who -a # mostra gli utenti loggati sul sistema
w      # mostra gli utenti loggati sul sistema con altre info
last   # elenca login/logout di tutti gli utenti da che esiste la macchina
```

## UID, GID e gruppi
```bash
id          # uid (da 1000 in su; uid=0 è solo per root), gid, gruppi dell'utente in uso (tra cui sudo)
id list     # UGUALE ma per l'utente "list"
groups      # gruppi dell'utente in uso
groups list # UGUALE ma per l'utente "list"
```

## I file di sistema che li descrivono
```bash
grep edoardo /etc/passwd  # uid, gid, cartella home, shell di default (di ogni utente)
grep edoardo /etc/group   # gid e nome di tutti i gruppi associati

grep edoardo /etc/shadow  # hash delle password (di ogni utente). Può leggerlo solo root
grep edoardo /etc/gshadow # UGUALE ma relativo ai gruppi
```

## Creare e rimuovere utenti e gruppi
```bash
addgroup disney # crea il gruppo "disney"
delgroup disney # elimina il gruppo "disney"
cat /etc/group  # lista tutti i gruppi

adduser pippo        # crea utente "pippo", gruppo "pippo" e cartella "/home/pippo"
adduser pippo disney # se l'utente "pippo" e il gruppo "disney" esistono già, aggiunge "pippo" a "disney"
cat /etc/passwd      # lista tutti gli utenti

deluser pippo marvel        # rimuovo "pippo" dal gruppo "marvel"
deluser --remove-home pluto # elimina l'utente + la sua home, che di solito non serve più
```
Per `useradd`, `usermod` e `groupadd` (versioni a basso livello, che non assumono i default)
vedi [../02-file-e-permessi/09-proprietari.md](../02-file-e-permessi/09-proprietari.md).

## Password
```bash
groups pippo    # mi dice i gruppi di "pippo"
passwd pippo    # modifica la password di "pippo"; senza argomento modifica quella dell'utente corrente
passwd -d pippo # elimina la password di pippo: da ora si può loggare senza password
passwd -e pippo # fa scadere la password di pippo, che la dovrà modificare al prossimo accesso
```

```bash
head -c 32 /dev/urandom | base64                     # TRICK per creare password random: estrae 32B random e li codifica
head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' # UGUALE ma usa solo lettere e numeri
```

## SU e SUDO per impersonare un utente
```bash
su - ronaldo             # switch user a ronaldo (sarò loggato come ronaldo)
sudo -i -u ronaldo       # UGUALE: con accesso root posso impersonarlo senza inserire la sua password
sudo -u ronaldo ls /root # UGUALE ma posso anche specificare direttamente il comando da eseguire
```

## RUNUSER per eseguire comandi come un altro utente
Devo essere già loggato come root.
```bash
runuser -l ronaldo -c '<comando>'                     # SIMILE a "su", si usa in script o ambienti non interattivi (non richiede la password)
runuser -l ronaldo -c 'tar -czf /backup.tar.gz /dati' # il file backup.tar.gz avrà come owner ronaldo
```
