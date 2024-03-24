# Network
```bash
ssh username@ip_macchina
sudo useradd nick
curl https://it.wikipedia.org/wiki/Shred > risultatocurl.html

sudo ufw allow 80
sudo ufw status
sudo ufw enable
```

```bash
ifconfig - (ipconfig) - ip address
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
netstat # porte TCP e UDP
netstat -tulpn
ss -tulpn
```


## Powershell
```bash
clip < network.md # copia negli appunti di Windows il contenuto di quel file
```