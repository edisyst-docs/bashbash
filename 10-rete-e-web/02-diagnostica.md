# Diagnostica di rete

Percorso dei pacchetti, DNS in profondità, traffico in tempo reale, scansione delle porte.

Molti di questi strumenti non sono installati di default:
```bash
sudo apt install traceroute mtr-tiny whois dnsutils iftop tcpdump nmap netcat-openbsd
```

## Percorso dei pacchetti
```bash
traceroute www.google.com          # ogni router (hop) attraversato per arrivare a destinazione, con i tempi
traceroute -n www.google.com       # -n: niente reverse DNS degli hop, molto più veloce
traceroute -T -p 443 example.com   # usa TCP sulla 443 invece di UDP: passa dai firewall che bloccano il traceroute classico (serve sudo)
tracepath -n google.com            # SIMILE, non serve root; mostra anche l'MTU del percorso
mtr www.google.com                 # traceroute + ping continui: perdita di pacchetti e latenza di ogni hop in tempo reale (q per uscire)
mtr -rw -c 100 google.com > mtr_report.txt # report di 100 cicli salvato su file (-w: nomi completi): da allegare a un ticket al provider
```
> **NOTA**: in `mtr` una perdita su un hop intermedio che **non** prosegue sugli hop successivi non è un problema:
> molti router danno bassa priorità alle risposte ICMP. Conta la perdita che arriva fino all'ultimo hop.

## DNS in profondità
Le query base (`dig +short`, `dig @server`, `dig -x`) sono in [../06-sistema/06-rete-e-host.md](../06-sistema/06-rete-e-host.md).
```bash
dig www.google.com                 # risposta completa: sezione ANSWER, TTL, server che ha risposto, tempo della query
dig www.google.com +noall +answer  # solo la sezione ANSWER, con il TTL
dig www.google.com +trace          # segue la risoluzione dalla radice: root server -> .com -> google.com. Rivela deleghe NS sbagliate
dig example.com NS +short          # i nameserver autoritativi del dominio
dig @ns1.example.com example.com   # interroga direttamente l'autoritativo: vedo la modifica prima che scada la cache degli altri
dig example.com TXT +short         # record TXT (SPF, verifiche di dominio)
dig example.com ANY +noall +answer # tutti i record (molti server rispondono in modo ridotto a ANY)

host google.com                    # UGUALE più sintetico: IP (v4 e v6) e mail server
host -t ns example.com             # solo i record NS
host 8.8.8.8                       # reverse: dns.google

nslookup www.google.com            # disponibile anche su Windows con la stessa sintassi
nslookup 8.8.8.8                   # reverse: restituisce il nome (dns.google)
nslookup example.com 8.8.8.8       # usa il DNS 8.8.8.8 per la query
nslookup -query=MX example.com     # record MX
```
`nslookup` ha anche una modalità interattiva:
```
$ nslookup
> server 8.8.8.8        cambia il server DNS
> set type=MX           cambia il tipo di record (A, MX, NS, TXT...)
> example.com
> exit
```

```bash
whois google.com                   # registrar, date di registrazione e scadenza, nameserver, stato del dominio
whois 8.8.8.8                      # a chi appartiene un IP: organizzazione, blocco di indirizzi, contatti abuse
whois example.com | grep -iE 'expir|registrar:' # quando scade il dominio e chi è il registrar
```

## Traffico in tempo reale
```bash
sudo iftop -i eth0                 # come top, ma per le connessioni: chi scambia più traffico con chi (q per uscire)
sudo iftop -i eth0 -nP             # -n senza DNS, -P mostra anche le porte
sudo iftop -F 192.168.1.0/24       # considera "locale" quella rete: il traffico entrante e uscente si separa meglio
sudo iftop -t -s 10                # modalità testo per 10 secondi, poi esce: utilizzabile negli script e nei log
ip -s link show eth0               # contatori totali di byte, pacchetti, errori e scarti dell'interfaccia
```

## tcpdump: catturare i pacchetti
Mostra i pacchetti che passano da un'interfaccia. Serve per rispondere a "la richiesta arriva davvero al server?".
```bash
sudo tcpdump -i eth0                  # tutto il traffico dell'interfaccia (CTRL+C per fermare)
sudo tcpdump -i any -nn               # tutte le interfacce; -nn: niente risoluzione di nomi e porte (più leggibile e veloce)
sudo tcpdump -i any -nn port 3306     # solo il traffico sulla porta 3306
sudo tcpdump -i any -nn host 192.168.1.1                  # solo da o verso quell'IP
sudo tcpdump -i any -nn 'host 10.0.0.5 and tcp port 443'  # filtri combinabili con and, or, not
sudo tcpdump -i any -nn 'tcp port 80 and not host 10.0.0.1' -c 50 # si ferma dopo 50 pacchetti
sudo tcpdump -i any -nn -A 'tcp port 80'                  # -A: stampa il contenuto in ASCII (HTTP in chiaro è leggibile)
sudo tcpdump -i eth0 -w cattura.pcap  # salva su file...
tcpdump -nn -r cattura.pcap           # ...per rileggerlo dopo, o aprirlo con Wireshark sul PC
```
> **NOTA**: via SSH escludere la propria sessione, altrimenti tcpdump cattura anche il proprio output
> all'infinito: `sudo tcpdump -i eth0 -nn 'not port 22'`.

## nc (netcat): parlare con una porta
```bash
nc -zv server.example.com 443              # la porta è aperta? (-z non invia dati)
nc -zv server.example.com 20-25            # UGUALE su un intervallo di porte
nc -l 9000                                 # sulla macchina A: resta in ascolto sulla 9000...
nc 192.168.1.10 9000                       # ...dalla macchina B: quello che scrivo compare su A. Prova definitiva che firewall e rotte lasciano passare
printf 'GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n' | nc example.com 80 # richiesta HTTP scritta a mano
```

## nmap: host e porte di una rete
> **ATTENZIONE**: scansionare reti e server che non sono tuoi, o senza autorizzazione, può essere illegale e
> viene comunque rilevato come attacco. Usalo sulla tua rete, sui tuoi server o in un laboratorio.

```bash
nmap -sn 192.168.1.0/24            # ping scan: quali host sono accesi, senza scansionare le porte (vecchio nome: -sP)
nmap -sn 192.168.1.1-50            # UGUALE su un intervallo
sudo nmap -sn 192.168.1.0/24       # da root sulla rete locale usa ARP: trova anche i dispositivi che non rispondono al ping (e mostra MAC e produttore)

nmap 192.168.1.1                   # le 1000 porte più comuni di un host: aperte, chiuse, filtrate
nmap 192.168.1.0/24                # UGUALE per tutta la rete
nmap 192.168.1.1,2,3               # alcuni host specifici
nmap 192.168.1.1 192.168.1.5       # UGUALE
nmap 192.168.1.0/24 --exclude 192.168.1.2 # esclude un IP
nmap -iL host.txt --excludefile esclusi.txt # host da scansionare (ed esclusi) letti da file, uno per riga

nmap -p 80,443 192.168.1.1         # solo quelle porte
nmap -p 1-1000 192.168.1.1         # un intervallo di porte
nmap -p- 192.168.1.1               # tutte le 65535 porte (lento)
nmap --top-ports 100 192.168.1.1   # le 100 porte più usate (veloce)
nmap -sV 192.168.1.1               # rileva il servizio e la versione su ogni porta aperta (es. "OpenSSH 9.6p1")
sudo nmap -O 192.168.1.1           # prova a indovinare il sistema operativo
sudo nmap -A 192.168.1.1           # aggressivo: -O + -sV + script di default + traceroute
nmap -Pn 192.168.1.1               # salta la verifica "host acceso": lo scansiona comunque (per host che bloccano il ping)
sudo nmap -sU -p 53,161 192.168.1.1 # porte UDP (DNS, SNMP): lento, serve root

nmap -oN risultato.txt 192.168.1.1 # salva l'output normale
nmap -oX risultato.xml 192.168.1.1 # in XML
nmap -oG - 192.168.1.0/24          # formato "grepable" su stdout: una riga per host, facile da filtrare
```

## Esempi pratici
```bash
# elenco degli IP accesi nella mia LAN, uno per riga
nmap -sn 192.168.1.0/24 -oG - | awk '/Status: Up/ {print $2}'

# il mio server espone solo quello che deve? (da un'ALTRA macchina: da dentro il server il firewall non si vede)
nmap -Pn -p- --open server.example.com       # solo le porte aperte: devono essere 22, 80, 443 e nient'altro

# la richiesta arriva al web server? Da un terminale sul server:
sudo tcpdump -i any -nn 'tcp port 443 and host 203.0.113.50'
# ...e intanto dal PC (203.0.113.50) lancio curl: se tcpdump non mostra nulla, il problema è prima del server (DNS, firewall, rotta)

# a quale latenza e con quale perdita arrivo a un server, per 60 secondi
ping -c 60 -i 1 server.example.com | tail -2 # riepilogo finale: pacchetti persi e tempi min/avg/max
```

Vedi anche: [01-indirizzi-e-configurazione.md](01-indirizzi-e-configurazione.md) per `ip` e le rotte,
[03-namespace.md](03-namespace.md) per fare pratica con questi comandi su una rete finta.
