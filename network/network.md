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
ipconfig /all        # mostra tutte le interfacce, anche quelle spente
ifconfig /displaydns # mostra la cache dei DNS memorizzata attualmente sul sistema
ifconfig /flushdns   # cancella la cache dei DNS, da fare per prevenire attacchi cache-poisoning

ipconfig | grep "Indirizzo IPv4"
ipconfig | grep IPv4 # in questo caso fa lo stesso
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
arp -a # stampa la relazione IP-Mac Addr di ogni interfaccia di rete. Opera a livello di MAC ADDRESS (liv.2)
route print # visualizzo la tabella di instradamento completa 

ping 8.8.8.8 # Opera a livello di IP ADDRESS (liv.3)
ping google.it
pathping google.it # misura la latenza dal mio router per esempio

tracert google.it # mostra a video tutti i salti del pacchetto per arrivare all'host remoto

net user # elenco utenti
net user Edoardo # dettagli utente

net session # elenco dei servizi
net stop # per fermare un servizio
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
doskey/history # uguale a history in Linux
nslookup # mi dice il mio DNS
traceroute www.google.com
```

```bash
netstat # stato porte TCP e UDP. Eseguire da Amministratore
netstat -tulpn # esistono tante opzioni, son da provare
netstat -b 5 # in 127.0.0.1:64038 c'è il PID=64038 per identificarlo se voglio killarlo
ss -tulpn
```


## Powershell
```bash
clip < network.md # copia negli appunti di Windows il contenuto di quel file
```