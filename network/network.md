# Network
```bash
passwd # per cambiare la propria password
ssh username@ip_macchina
sudo useradd nick

curl https://official-joke-api.appspot.com/jokes/random > risultatocurl.html
curl -o risultatocurl.html https://official-joke-api.appspot.com/jokes/ten # fa la stessa cosa
curl -I https://www.google.com # Mi dà i metadati
curl -X POST https://www.techwithtim.net/ # il metodo di default è GET
curl -X POST --data "q=cane&par2=val2" hhttps://www.google.com/search # posso passargli dei parametri in POST

sudo ufw allow 80
sudo ufw status
sudo ufw enable
```

```bash
ifconfig - (ipconfig) - # eth0 è la mia connessione fisica a internet 
ip address - ip -4 address # ho solo gli IPv4 
ipconfig /all # le visualizza tutte, anche quelle spente
ifconfig /flushdns # caneclla la cache dei DNS

ipconfig | grep "Indirizzo IPv4"
ifconfig | grep eth0
```

```bash
cat /etc/resolv.conf

netsh # mi dice tutte le opzioni che ha
netsh wlan show profiles # mostra chi è connesso al Wifi

resolvectl status # IP pubblico
```

## Windows CMD
```bash
ping 8.8.8.8
ping www.google.com
pathping 192.168.1.1 # misura la latenza dal mio router per esempio

net user # elenco utenti
net user Edoardo # dettagli utente
```

```bash
tasklist # elenco processi attivi su Windows
taskkill /PID 19196 # killa il processo 19196
driverquery # elenco driver del PC indicato (default: il mio)
powercfg /q # info alimentazione e risparmio energetico
cacls # partizioni NTFS
getmac # MAC address
systeminfo # info su tutto: CPU, SO, Bios, RAM, schede di rete
```

```bash
Doskey/history # uguale a history in Linux
nslookup # mi dice il mio DNS
traceroute www.google.com

arp -a # mi dice tutte le interfacce
route print # visualizzo la tabella di instradamento completa
```

```bash
netstat # stato porte TCP e UDP
netstat -tulpn # esistono tante opzioni, son da provare
ss -tulpn
```


## Powershell
```bash
clip < network.md # copia negli appunti di Windows il contenuto di quel file
```


## GPG - Crittografia asimmetrica 
Esiste il pacchetto GPG (GNU Privacy Garb) su ogni distro Linux per cifrare 1 o + file
- https://www.youtube.com/watch?v=WR2FGdNkkmI
- chiave pubblica (serratura) serve per cifrare i file (la posso condividere senza problemi, così gli altri possono cifrare i file, che io con la mia chiave privata potrò aprire)
- chiave privata (chiave di casa) serve per aprire/decifrare i file
```bash
gpg # se è installato mi crea la cartella /home/nomeutente/.gnupg
gpg --full-generate-key # seleziono RSA and RSA, posso non mettere passphrase
gpg --list-keys # per leggere le mie chiavi pub
gpg --list-secret-keys # per leggere le mie chiavi priv
```
Se dovesse servire generare entropia posso fare
```bash
df -h # per vedere i dischi /dev montati
dd if=/dev/sdc of=/dev/null #input; output su /dev/null significa buttare ciò che gli si copia dentro. E' un trucco, lo usiamo nei cron ad esempio
```
Di norma poi esporto la chiave pubblica in una cartella accessibile anche agli altri utenti, 
così possono cifrarci un file e mandarcelo
```bash
gpg --export --output /tmp/chiavepubblica "nome_chiave" # esporto la pubkey in un file
cat /tmp/chiavepubblica # è cifrata, non si legge bene
gpg /tmp/chiavepubblica # dovrebbe darmi lo stesso output di --list-keys
```

La chiave può essere data a qualsiasi utente/sito (serve solo per cifrare)
```bash
useradd utente # creo un utente per provare
passwd utente  # digito la sua password
su - utente    # impersono l'utente

gpg /tmp/chiavepubblica # può leggerla perchè è una chiave pubblica
vim file-cifrato.txt     # ci scrivo qualcosa
gpg --import /tmp/chiavepubblica # la importo per usarla nella mia /home/utente/.gnupg
gpg --encrypt -r "nome_chiave" file-cifrato.txt # cifro il mio file, me lo crea nella stessa cartella
ls -la # vedo entrambi i file: il .txt.gpg sarà illeggibile se uso cat

cp file-cifrato.txt.gpg /tmp # lo metto a disposizione degli altri utenti
exit # divento root

cd /tmp
ls -la
cat file-cifrato.txt.gpg # illeggibile
gpg /tmp/file-cifrato.txt.gpg # decifro il file, crea il file decifrato
cat file-cifrato.txt # leggibile
```



