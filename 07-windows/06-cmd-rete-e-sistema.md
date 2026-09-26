# CMD: comandi di rete e di sistema

I comandi del prompt di Windows (`cmd.exe`) per diagnosticare rete, processi e macchina.
Funzionano anche da PowerShell, tranne dove indicato. Gli equivalenti in cmdlet sono in [02-powershell.md](02-powershell.md).

In CMD non c'è `grep`: si filtra con `findstr` (`/I` ignora maiuscole, `/C:"testo"` cerca una frase con spazi).
L'output è nella lingua di Windows: su un sistema italiano si cerca `"Indirizzo IPv4"`, non `"IPv4 Address"`.

> **NOTA**: nei blocchi qui sotto il testo dopo `::` è solo la spiegazione. CMD non ha commenti sulla stessa riga
> di un comando (`ipconfig :: testo` passa `::` e `testo` come argomenti): si copia solo il comando.
> Negli script un commento va su una riga sua, oppure dopo `& rem`.

## Configurazione IP e DNS
```bat
ipconfig                    :: IP, subnet e gateway di ogni scheda
ipconfig /all               :: in più MAC, DNS, DHCP, lease; anche le schede scollegate
ipconfig | findstr IPv4     :: solo le righe con gli indirizzi IPv4
ipconfig /release           :: rilascia l'IP ottenuto dal DHCP...
ipconfig /renew             :: ...e ne chiede uno nuovo
ipconfig /displaydns        :: la cache DNS del sistema
ipconfig /flushdns          :: svuota la cache DNS: dopo aver cambiato un record o il file hosts
getmac                      :: MAC address di ogni scheda
```
Il file hosts di Windows è `C:\Windows\System32\drivers\etc\hosts` (si modifica da amministratore).

## Connettività
```bat
ping google.it              :: 4 pacchetti ICMP: l'host risponde? (livello 3, IP)
ping -t 8.8.8.8             :: continuo, fino a CTRL+C (in Linux è il comportamento di default)
ping -n 20 8.8.8.8          :: 20 pacchetti (in Linux: -c 20)
tracert -d google.it        :: tutti i router attraversati; -d non risolve i nomi (molto più veloce)
pathping google.it          :: tracert + statistiche di perdita per ogni hop (come mtr su Linux). Impiega qualche minuto
nslookup www.google.com     :: interroga il DNS: stessa sintassi di Linux
nslookup www.google.com 8.8.8.8 :: usando un DNS specifico
```

## Porte e connessioni
```bat
netstat -ano                          :: tutte le connessioni e porte in ascolto, con il PID (-o) e senza risolvere i nomi (-n)
netstat -ano | findstr :8000          :: chi usa la porta 8000
netstat -ano | findstr LISTENING      :: solo le porte in ascolto
netstat -b                            :: il nome dell'eseguibile di ogni connessione (serve il prompt da amministratore)
netstat -r                            :: tabella di routing (UGUALE a route print)
```

## Routing e ARP
```bat
route print                                                  :: tabella di routing
route add 10.8.0.0 mask 255.255.255.0 192.168.1.1            :: rotta statica (fino al riavvio)
route -p add 10.8.0.0 mask 255.255.255.0 192.168.1.1         :: UGUALE ma permanente
route delete 10.8.0.0                                        :: la rimuove

arp -a                            :: tabella ARP: relazione IP - MAC dei dispositivi della rete locale
arp -a -N 192.168.1.34            :: solo per l'interfaccia con quell'IP
arp -d 192.168.1.2                :: rimuove una voce (arp -d * le rimuove tutte): utile dopo aver sostituito un dispositivo
arp -s 192.168.1.3 00-aa-bb-cc-dd-ee :: voce statica (su Windows il MAC si scrive con i trattini)
```

## netsh: configurare rete, Wi-Fi e firewall
Richiede il prompt da amministratore per le modifiche.
```bat
netsh interface show interface                   :: schede di rete con stato e nome (il nome serve nei comandi sotto)
netsh interface ipv4 show config                 :: configurazione IP di ogni scheda
netsh interface ipv4 show route                  :: tabella di routing

netsh interface ip set address name="Ethernet" static 192.168.1.10 255.255.255.0 192.168.1.1 :: IP statico: indirizzo, subnet mask, gateway
netsh interface ip set address name="Ethernet" source=dhcp                                   :: torna al DHCP
netsh interface ip set dns name="Ethernet" static 1.1.1.1                                     :: DNS statico
netsh interface ip set dns name="Ethernet" source=dhcp                                        :: DNS dal DHCP

netsh wlan show networks                         :: reti Wi-Fi visibili
netsh wlan show interfaces                       :: la rete Wi-Fi a cui sono collegato, con segnale e velocità
netsh wlan show profiles                         :: le reti Wi-Fi salvate sul PC
netsh wlan show profile name="CasaWiFi" key=clear :: dettagli di una rete salvata, password compresa (riga "Contenuto chiave")
netsh wlan connect name="CasaWiFi"               :: si collega a una rete salvata

netsh advfirewall firewall show rule name=all    :: tutte le regole del firewall (sono tantissime: filtrare con findstr)
netsh advfirewall firewall add rule name="Laravel dev" dir=in action=allow protocol=TCP localport=8000 :: apre una porta in ingresso
netsh advfirewall firewall delete rule name="Laravel dev"                                            :: e la richiude
```

## Processi e servizi
```bat
tasklist                               :: processi attivi, come ps
tasklist /FI "IMAGENAME eq php.exe"    :: solo i processi con quel nome
tasklist /FI "PID eq 12684"            :: quale programma ha quel PID (es. preso da netstat -ano)
taskkill /PID 19196                    :: chiede la chiusura del processo 19196
taskkill /PID 19196 /F                 :: lo termina forzatamente (come kill -9)
taskkill /IM php.exe /F                :: termina tutti i processi con quel nome (come pkill)

net start                              :: servizi IN ESECUZIONE
net stop Themes                        :: ferma un servizio (nome del servizio o nome visualizzato, es. "Temi")
net start Themes                       :: lo avvia
sc query type= service state= all      :: tutti i servizi con lo stato (lo spazio dopo "=" è obbligatorio)
sc qc Themes                           :: configurazione di un servizio: eseguibile, tipo di avvio
```

## Utenti
```bat
net user                           :: utenti locali
net user Edoardo                   :: dettagli di un utente: gruppi, ultimo accesso, scadenza password
net localgroup Administrators      :: chi è amministratore del PC
net session                        :: sessioni aperte da altri computer verso le cartelle condivise di questo PC (da amministratore)
whoami /groups                     :: i miei gruppi e privilegi
```

## Informazioni sulla macchina
```bat
systeminfo                         :: tutto: sistema operativo, BIOS, CPU, RAM, hotfix, schede di rete
systeminfo | findstr /B /C:"Nome SO" /C:"Versione SO" :: solo alcune righe
driverquery                        :: driver installati
powercfg /q                        :: impostazioni di alimentazione e risparmio energetico
powercfg /batteryreport            :: report HTML sullo stato della batteria del portatile
icacls C:\laragon\www\progetto     :: permessi NTFS di file e cartelle (cacls è il vecchio comando, deprecato)
doskey /history                    :: i comandi digitati in questa finestra (come history di Linux)
```
`wmic` è deprecato e sulle versioni recenti di Windows 11 non è più installato. Al suo posto, in PowerShell:
```powershell
(Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices                         # quanti slot RAM ha la scheda madre
Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, @{n='GB';e={$_.Capacity/1GB}} # quali sono occupati e con quanta RAM
```
La stessa informazione si vede in *Gestione attività > Prestazioni > Memoria* (slot utilizzati).

## Appunti
```bat
clip < file.md                     :: copia il contenuto del file negli appunti (in CMD)
ipconfig /all | clip               :: copia l'output di un comando
```
```powershell
Get-Content file.md | clip         # in PowerShell "<" non esiste: si usa la pipe
Get-Content file.md -Raw | Set-Clipboard # UGUALE con il cmdlet nativo
Get-Clipboard                      # legge gli appunti
```

## Esempio: liberare una porta occupata
```bat
netstat -ano | findstr :8000 | findstr LISTENING   :: l'ultima colonna è il PID, es. 12684
tasklist /FI "PID eq 12684"                        :: chi è
taskkill /PID 12684 /F                             :: lo termino
```
In un `.bat`, con `for /f` (vedi [01-batch.md](01-batch.md)):
```bat
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do taskkill /PID %%p /F
```
