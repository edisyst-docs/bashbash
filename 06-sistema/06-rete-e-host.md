# Rete e identità della macchina

## Hostname e sistema operativo
```bash
hostname    # hostname della macchina
hostname -i # IP
hostnamectl # info complete su hostname, sistema operativo, kernel, architettura

uname -a    # info sul sistema operativo e sul kernel
uname -r    # solo la versione del kernel (utile per i percorsi in /lib/modules/)
```

## Connettività
```bash
ping 8.8.8.8 # verifica semplice di connessione
```

## Interfacce, indirizzi e rotte (ip)
`ip` sostituisce i vecchi `ifconfig` e `route` (pacchetto net-tools, non più installato di default).
```bash
ip -br a              # indirizzi di tutte le interfacce, una riga ciascuna (-br = brief)
ip -br link           # interfacce e stato UP/DOWN
ip r                  # tabella di routing: la riga "default via" è il gateway
ip route get 8.8.8.8  # quale interfaccia e quale gateway verrebbero usati per raggiungere quell'IP
ip neigh              # tabella ARP: IP e MAC dei vicini sulla rete locale
```

## Porte e connessioni (ss)
`ss` sostituisce `netstat`.
```bash
ss -tulpn                     # porte TCP/UDP in ASCOLTO con il processo che le usa (serve sudo per vedere i processi degli altri)
ss -tn state established      # connessioni TCP attive
ss -tn '( dport = :3306 )'    # connessioni verso la porta 3306 (MySQL)
ss -s                         # riepilogo statistico
```

## DNS
```bash
dig +short example.com        # solo l'IP
dig example.com MX +short     # record MX (mail)
dig @1.1.1.1 example.com      # interroga un DNS specifico (per capire se il problema è il DNS locale)
dig -x 93.184.215.14 +short   # reverse DNS: da IP a nome
resolvectl status             # quali DNS sta usando la macchina (systemd-resolved)
getent hosts example.com      # risoluzione come la fanno i programmi: tiene conto anche di /etc/hosts
```

## HTTP e porte remote
```bash
curl -I https://example.com                   # solo gli header della risposta
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' https://example.com # status e tempo di risposta
curl -v https://example.com 2>&1 | grep -E '^[<>*]' # dettaglio di handshake TLS, richiesta e risposta
curl --resolve example.com:443:10.0.0.5 https://example.com # forza l'IP senza toccare /etc/hosts (test di un server nuovo prima del cambio DNS)
nc -zv db.interno 3306                        # la porta 3306 è raggiungibile? (-z non invia dati, -v stampa l'esito)
timeout 3 bash -c '</dev/tcp/db.interno/3306' && echo aperta # UGUALE senza nc: bash sa aprire connessioni TCP
```

## Diagnosticare "il sito non risponde"
Dal basso verso l'alto: rete, DNS, porta, servizio.
```bash
ping -c3 server.example.com              # 1. il server risponde? (alcuni firewall bloccano il ping: non è una prova definitiva)
dig +short server.example.com            # 2. il nome si risolve nell'IP giusto?
nc -zv server.example.com 443            # 3. la porta è aperta?
curl -I https://server.example.com       # 4. il web server risponde e con quale status?
# sul server:
ss -tlnp | grep -E ':(80|443)\b'         # 5. nginx è in ascolto?
sudo systemctl status nginx              # 6. il servizio è attivo?
sudo tail -50 /var/log/nginx/error.log   # 7. cosa dice il log
```

Vedi anche: [../04-processi/01-ps-e-kill.md](../04-processi/01-ps-e-kill.md) per `lsof -i`, che elenca le connessioni di rete aperte.
