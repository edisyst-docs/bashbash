# Posta: Postfix e Dovecot

> **Laboratorio**: `./lab.sh 10`, con il DNS di [06-dns-server.md](06-dns-server.md) già attivo su `web`. `web` è il server di posta di `lab.test`, `host` un computer che gli spedisce; dettagli in [lab/](lab/).

Un'email passa per tre ruoli, ognuno con il suo programma:

| Ruolo | Sigla | Cosa fa | Qui |
|---|---|---|---|
| **MUA** (*user agent*) | | il programma dell'utente: Thunderbird, `mail` | `mail`, `sendmail` |
| **MTA** (*transfer agent*) | SMTP, porta 25 | spedisce e **inoltra** la posta fra i server | **Postfix** |
| **MDA** (*delivery agent*) | | mette il messaggio nella casella dell'utente | `postfix/local` (Maildir) |
| accesso alla casella | IMAP 143/993, POP3 110/995 | l'utente **legge** la posta | **Dovecot** |

Il percorso di `anna@lab.test`: il `host` chiede al DNS il record **MX** di `lab.test` (→ `web.lab.test`), ne risolve l'indirizzo e consegna via SMTP a `web`; Postfix su `web` la mette in
`~anna/Maildir/new/`; il client di Anna la legge con IMAP da Dovecot. **Senza DNS la posta non funziona**: ecco perché prima c'è [06-dns-server.md](06-dns-server.md).

Gli esempi sono stati eseguiti nel laboratorio dell'area 10 (Postfix 3.8.6, Dovecot 2.3.21).

## Installazione
```bash
sudo DEBIAN_FRONTEND=noninteractive apt install postfix mailutils      # mailutils: il comando mail
sudo apt install dovecot-imapd                                         # solo sul server che ospita le caselle
postconf mail_version                                                  # mail_version = 3.8.6
```
Senza `DEBIAN_FRONTEND=noninteractive` l'installazione chiede il tipo di configurazione: **Internet Site** per un server che spedisce e riceve da solo, *Satellite system* per uno che
passa tutto a un altro. In un container il servizio non parte da solo (`policy-rc.d denied execution`): `sudo systemctl start postfix`.

## Configurare: `main.cf` e `postconf`
La configurazione è `/etc/postfix/main.cf`, ma non si modifica a mano: `postconf` legge e scrive.
```bash
postconf -n                      # solo quello che differisce dai valori di default
postconf mydestination           # un parametro
postconf -d mydestination        # il suo valore di default
sudo postconf -e "myhostname = web.lab.test" "mydomain = lab.test"       # modifica (-e), anche più parametri insieme
sudo postfix check               # nessun output = a posto
sudo systemctl reload postfix
```
I parametri che contano:

| Parametro | Cosa dice |
|---|---|
| `myhostname` | il nome completo (FQDN) di questo server: `web.lab.test`. È quello che dice nel saluto SMTP |
| `mydomain` | il dominio: `lab.test` |
| `mydestination` | per quali domini questo server è **la destinazione finale**: la posta a `@lab.test` finisce nelle caselle locali, il resto viene inoltrata |
| `mynetworks` | le reti che possono **spedire attraverso** questo server: ogni indirizzo qui dentro è "di fiducia" |
| `myorigin` | il dominio messo nel mittente dei messaggi spediti da qui (default `/etc/mailname`) |
| `inet_interfaces`, `inet_protocols` | su quali interfacce ascolta, IPv4/IPv6 |
| `home_mailbox` | dove consegnare: `Maildir/` (un file per messaggio) invece di un unico `/var/mail/utente` |
| `relayhost` | se non vuoto, **tutta** la posta in uscita passa da quel server (il caso di un server dietro un provider) |
| `alias_maps` | `/etc/aliases`: indirizzi che diventano altri indirizzi |

Il server di posta del laboratorio, `web`:
```bash
sudo postconf -e "myhostname = web.lab.test" "mydomain = lab.test" \
    "mydestination = \$myhostname, lab.test, localhost" \
    "mynetworks = 127.0.0.0/8, 10.10.2.0/24" "home_mailbox = Maildir/" "inet_protocols = ipv4"
sudo useradd -m -s /bin/bash anna ; sudo useradd -m -s /bin/bash marco       # le caselle sono gli utenti di sistema
sudo systemctl restart postfix
ss -tlnp | grep ':25 '            # LISTEN 0 100 0.0.0.0:25 ... master
```
E il `host`, che spedisce soltanto (nessuna casella: `mydestination = localhost`), con il DNS di `web` in `/etc/resolv.conf`:
```bash
echo host.lab.test | sudo tee /etc/mailname           # il dominio dei mittenti
sudo postconf -e "myhostname = host.lab.test" "mydomain = lab.test" "mydestination = \$myhostname, localhost" \
    "inet_protocols = ipv4" "mynetworks = 127.0.0.0/8, 10.10.1.0/24"
sudo systemctl restart postfix
```

## Spedire e leggere
```bash
printf 'Subject: prova dal host\n\nCiao Anna\n' | sendmail anna@lab.test
mailq                                      # la coda: il messaggio è lì per qualche secondo
journalctl -t postfix/smtp --no-pager | tail -1
# 044856366A: to=<anna@lab.test>, relay=web.lab.test[10.10.2.10]:25, delay=8.1, delays=0.01/0.02/8/0.01, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 044856366A)
```
`relay=web.lab.test[10.10.2.10]:25` è il risultato della ricerca MX; `dsn=2.0.0` e `status=sent` sono la consegna riuscita. I numeri di `delays=a/b/c/d` sono i secondi in: coda prima del gestore / gestore / connessione / trasmissione.
Su `web`, il messaggio è in un file della Maildir:
```bash
ls ~anna/Maildir/new                       # 1791210326.V73I6d632M24731.web
cat ~anna/Maildir/new/*
# Return-Path: <root@host.lab.test>
# Received: from host.lab.test (unknown [10.10.1.10]) by web.lab.test (Postfix) with ESMTPS id 044856366A for <anna@lab.test>; ...
# Subject: prova dal host
#
# Ciao Anna
```
`Received:` è il percorso del messaggio, riga per riga, ed è la prima cosa da leggere quando una mail arriva strana.
> Il comando `mail` di mailutils scrive nel messaggio il mittente col **nome corto** della macchina (`root@host`): Postfix non lo completa, e quando quel messaggio rimbalza,
> la risposta di errore non ha dove tornare (`Host not found, try again` per `host`, in `mailq`). Per mettere nei mittenti il nome completo si usa `sendmail` (che passa da Postfix e usa `myorigin`).

### Una conversazione SMTP a mano
SMTP è un protocollo di testo: ci si può parlare con `nc`, ed è il modo migliore per capire cosa succede.
```bash
(sleep 1; echo "EHLO host.lab.test"; sleep 1; echo "MAIL FROM:<root@host.lab.test>"; sleep 1; echo "RCPT TO:<marco@lab.test>"
 sleep 1; echo "DATA"; sleep 1; printf "Subject: a mano\r\n\r\nciao marco\r\n.\r\n"; sleep 1; echo "QUIT") | nc web 25
# 220 web.lab.test ESMTP Postfix (Ubuntu)
# 250-web.lab.test
# 250-PIPELINING ... 250-STARTTLS ... 250 CHUNKING
# 250 2.1.0 Ok                 <- MAIL FROM accettato
# 250 2.1.5 Ok                 <- RCPT TO accettato
# 354 End data with <CR><LF>.<CR><LF>
# 250 2.0.0 Ok: queued as DDE3A6366A
# 221 2.0.0 Bye
```
Le risposte sono numeri: `2xx` ok, `4xx` errore **temporaneo** (si riprova), `5xx` errore **definitivo** (rimbalza). La riga `250-STARTTLS` dice che il server offre la cifratura (vedi sotto).

## Quando qualcosa non va
**Il server di destinazione è giù.** Il messaggio resta in coda, e Postfix riprova a intervalli crescenti per giorni:
```bash
# su web: sudo systemctl stop postfix. Sul host:
printf 'Subject: differita\n\nmentre il server è giù\n' | sendmail anna@lab.test
mailq
# -Queue ID-  --Size-- ----Arrival Time---- -Sender/Recipient-------
# AA98CBC079      334 Mon Oct  5 14:26:17  root@host
#                   (connect to web.lab.test[10.10.2.10]:25: Connection refused)
#                                          anna@lab.test
# su web: sudo systemctl start postfix. Sul host:
postqueue -f                               # riprova subito (flush); mailq: coda vuota; il messaggio è arrivato
```
Il motivo dell'attesa è fra parentesi sotto l'ID. Per un messaggio, `postcat -q ID`; per cancellare: `sudo postsuper -d ID` (o `-d ALL` per tutta la coda).

**Il destinatario non esiste.** Il server destinazione lo rifiuta subito con un errore definitivo, e il mittente riceve un messaggio di **rimbalzo** (*bounce*):
```bash
printf 'Subject: bounce\n\nx\n' | sendmail nessuno@lab.test
journalctl -t postfix/smtp --no-pager | tail -1
# 30F87BC071: to=<nessuno@lab.test>, relay=web.lab.test[10.10.2.10]:25, delay=8.1, dsn=5.1.1, status=bounced
#   (host web.lab.test[10.10.2.10] said: 550 5.1.1 <nessuno@lab.test>: Recipient address rejected: User unknown in local recipient table
sudo cat /var/mail/root                    # From MAILER-DAEMON ... Subject: Undelivered Mail Returned to Sender
```
**Inoltrare per conto di altri: il relay aperto.** Un server che accetta posta da **chiunque** per **qualunque** destinazione è usato dagli spammer. Postfix lo evita da solo: spedisce
(*relay*) solo per i `mynetworks` o per chi si autentica. Da `host2` (`10.10.1.11`, fuori da `mynetworks` di `web`) verso un indirizzo esterno:
```bash
printf 'EHLO host2\r\nMAIL FROM:<a@lab.test>\r\nRCPT TO:<qualcuno@example.com>\r\nQUIT\r\n' | nc -q2 web 25
# 250 2.1.0 Ok
# 454 4.7.1 <qualcuno@example.com>: Relay access denied
```
Per un dominio **proprio** (`@lab.test`) invece accetta, perché è lui la destinazione. **Non si aggiunge mai `0.0.0.0/0` a `mynetworks`.**

## Alias
`/etc/aliases` trasforma un indirizzo in uno o più altri, anche in un programma o un file:
```bash
echo "info: anna, marco" | sudo tee -a /etc/aliases
sudo newaliases                            # ricostruisce /etc/aliases.db: senza, la modifica non vale
printf 'Subject: per info\n\nciao\n' | sendmail info@lab.test      # lo ricevono sia anna sia marco
```
Gli alias di sistema (`postmaster`, `root`) sono lì per ricevere gli avvisi dei servizi: `root: anna` fa arrivare in una casella vera le mail di `cron` e `fail2ban`.

## Dovecot: leggere la posta
Postfix consegna, **non** serve le caselle: per leggerle da un client serve IMAP. Con le caselle in Maildir:
```bash
echo "mail_location = maildir:~/Maildir" | sudo tee /etc/dovecot/conf.d/99-lab.conf
echo "disable_plaintext_auth = no" | sudo tee -a /etc/dovecot/conf.d/99-lab.conf       # SOLO nel laboratorio: la password in chiaro
sudo systemctl restart dovecot ; ss -tlnp | grep ':143 '
```
Il default di Ubuntu è `mail_location = mbox:~/mail:INBOX=/var/mail/%u`: se Postfix consegna in `Maildir/` e Dovecot cerca altrove, **la casella risulta vuota**. Una sessione IMAP a mano:
```bash
(sleep 1; echo 'a LOGIN anna anna'; sleep 1; echo 'a SELECT INBOX'; sleep 1; echo 'a FETCH 1:* (BODY[HEADER.FIELDS (SUBJECT)])'; sleep 1; echo 'a LOGOUT') | nc -w5 web 143
# * OK ... Dovecot (Ubuntu) ready.
# a OK [CAPABILITY ...] Logged in
# * 7 EXISTS
# * 1 FETCH (FLAGS (\Seen \Recent) BODY[HEADER.FIELDS (SUBJECT)] {27}
# Subject: prova dal host
# ...
```
In produzione si usa `993` (IMAP con TLS) e mai la password in chiaro.

## Cifratura, SPF, DKIM (non provati)
Qui tutto viaggia in chiaro e senza identità, che va bene in un laboratorio e non su internet. Un server vero ha bisogno di:
- **TLS**: un certificato per `smtpd_tls_cert_file` e `smtpd_tls_key_file` (Ubuntu usa quello *snakeoil*, autofirmato: gli altri server non lo verificano) — di solito Let's Encrypt, vedi [04-apache-nginx.md](04-apache-nginx.md)
- **SPF**, **DKIM**, **DMARC**: record DNS (TXT) e una firma (`opendkim`) con cui gli altri server verificano che la posta arrivi davvero da te. Senza, Gmail e Outlook scartano o mettono in spam
- **DNS inverso** (PTR) del tuo IP pubblico uguale a `myhostname`, e un IP non in una lista di spam
- **autenticazione** per gli utenti (porta 587, SASL con Dovecot) invece di `mynetworks`

Il lato difficile di un server di posta oggi è la **reputazione**, non Postfix: per un servizio vero molti usano un relay (`relayhost`) di un provider.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| la posta resta in `mailq` | il server destinazione non risponde o il DNS non trova l'MX | leggere la riga fra parentesi; `dig MX dominio`, `nc -zv server 25` |
| `Host or domain name not found. Name service error for name=... type=MX` | il nome non si risolve **dal server**: il DNS in `/etc/resolv.conf` non lo conosce | `getent hosts nome`, `dig MX dominio @dns` |
| `Relay access denied` | il mittente non è in `mynetworks` e non si è autenticato (e il dominio non è il tuo) | è il comportamento giusto; per un client interno, `mynetworks` o SASL |
| `User unknown in local recipient table` | l'utente non esiste (o `mydestination` non include il dominio) | `id utente`, `postconf mydestination` |
| i bounce non tornano al mittente | il mittente ha il nome corto (`root@host`) | `/etc/mailname`, `myorigin`, `sendmail` al posto di `mail` |
| la modifica a `/etc/aliases` non vale | manca `newaliases` | `sudo newaliases` |
| la casella IMAP è vuota ma la posta è consegnata | `mail_location` di Dovecot ≠ dove consegna Postfix | allineare `home_mailbox` e `mail_location` |
| `postfix/master: daemon started` ma la porta 25 non risponde | `inet_interfaces` o firewall | `ss -tlnp \| grep :25`, `sudo ufw allow 25/tcp` |

Torna all'[indice dell'area](README.md)
