# Network

ssh username@ip_macchina

sudo useradd nick

curl https://it.wikipedia.org/wiki/Shred > risultatocurl.html

ifconfig - (ipconfig) - ip address

ipconfig | grep "Indirizzo IPv4"
ifconfig | grep eth0

cat /etc/resolv.conf

netsh # mi dice tutte le opzioni che ha
netsh wlan show profiles # mostra chi è connesso al Wifi

resolvectl status # IP pubblico

ping 8.8.8.8
ping www.google.com

traceroute www.google.com

netstat
netstat -tulpn
ss -tulpn

sudo ufw allow 80
sudo ufw status
sudo ufw enable

Per Powershell
clip < network.md # copia negli appunti di Windows il contenuto di quel file
