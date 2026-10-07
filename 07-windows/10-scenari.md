# Scenari guidati: "non riesco a entrare nel dominio"

> **Laboratorio**: `./lab.sh 07`, poi `cd 10-scenari`. Qui non si prova un comando: **c'è un guasto vero** nel dominio `lab.test` (un controller Samba 4 e un PC), da diagnosticare e riparare (vedi [lab/](lab/)). Serve internet, come per il resto dell'area (`apt` all'avvio).

In [09-active-directory](09-active-directory.md) ci sono i comandi; qui c'è solo un **sintomo**, come lo racconta chi chiama il supporto, e la causa va trovata. Sono otto guasti diversi, uno per volta:
il DNS del PC che non trova il controller, un account **bloccato** e uno **disabilitato** (che danno lo stesso errore), un `kinit` con il realm scritto male, una password che la policy rifiuta, il nome inverso del DNS che manca, un record DNS sbagliato e un PC il cui account computer è sparito dal dominio.
Si lavora da `pc01` con `samba-tool`, `kinit`, `ldapsearch`, `host` e `net ads`: sono gli stessi problemi che si incontrano con Windows, con comandi diversi (la tabella in fondo li affianca).

## Come si lavora
```bash
cd ~/lab/10-scenari
./scenari.sh guasta 2          # porta il dominio in salute (qualche secondo), lo rompe come lo scenario 2 e stampa il "ticket" (il sintomo)
# ...diagnosi e riparazione, con quello che vuoi...
./scenari.sh controlla         # dice se il sintomo è sparito; non rivela la causa
./scenari.sh ripristina        # toglie ogni guasto (anche se ti sei perso)
```
- `controlla` guarda **il sintomo**, non il comando che hai usato: vale qualunque riparazione che funzioni davvero. In 5, per esempio, non vale **indebolire la policy** delle password per far passare quella sbagliata.
- `scenari.sh` **non va aperto** prima di aver provato: contiene i guasti. Ogni scenario ha un suggerimento e la soluzione, nascosti.
- Gli utenti degli scenari sono `anna`, `marco` e `sara`, con password `Passw0rd!NOME` (`Passw0rd!anna`...). L'amministratore è `administrator` / `Passw0rd!2026`; per abbreviare, in questa pagina: 
  ```bash
  PW='Passw0rd!2026'
  A="-H ldap://dc1.lab.test -U administrator%$PW"
  ```
  (`samba-tool` stampa a ogni comando un avviso su quella password in riga di comando: nelle soluzioni è omesso, come i `Password for ...:` di `kinit` quando la password arriva da una pipe.)
- I file degli scenari 4, 5 stanno in `~/lab/10-scenari/lavoro/`: si **modificano** lì. Ogni `guasta N` rifà tutto da zero, anche gli utenti e il DNS.

## Il metodo: DNS, tempo, account, policy
Quasi ogni guasto di un dominio è in una di queste quattro cose. Si controllano **in quest'ordine**, perché ognuna dipende dalla precedente:

| Livello | Domanda | Comando |
|---|---|---|
| DNS | il PC trova il controller? | `host -t SRV _ldap._tcp.lab.test`, `cat /etc/resolv.conf` |
| nomi diretti e inversi | il nome e l'indirizzo del controller coincidono? | `host dc1.lab.test`, `host 10.30.0.10` |
| Kerberos | il biglietto si ottiene? con quale errore? | `kinit utente@REALM` (realm **maiuscolo**), `klist` |
| account | com'è l'utente: abilitato? bloccato? | `samba-tool user show` (`userAccountControl`, `badPwdCount`, `lockoutTime`) |
| policy | cosa pretende il dominio? | `samba-tool domain passwordsettings show` |
| il PC | il PC è ancora "del dominio"? | `net ads testjoin`, `samba-tool computer list` |

Il **messaggio di `kinit`** è il dato migliore: `Cannot find KDC` è DNS, `Password incorrect` è la password, `Client's credentials have been revoked` è lo stato dell'account (e qui ne esistono due), `KDC reply did not match expectations` è il nome del realm.

---

## 1. Nessuno entra più nel dominio da questo PC
**Ticket**: *Su questo PC nessuno riesce più a entrare nel dominio: `kinit anna@LAB.TEST` non trova il controller. La rete funziona.*

<details><summary>da dove cominciare</summary>

Un client trova il controller **solo con il DNS**, tramite i record `SRV`. Chiedi al DNS di questo PC il record `_ldap._tcp.lab.test` e guarda quale DNS sta usando.
</details>
<details><summary>soluzione</summary>

```bash
cat /etc/resolv.conf
# nameserver 127.0.0.1                           <- il DNS è la macchina stessa, e lì non c'è niente
host -t SRV _ldap._tcp.lab.test
# ;; communications error to 127.0.0.1#53: connection refused
# ;; no servers could be reached
echo 'Passw0rd!anna' | kinit anna@LAB.TEST
# kinit: Cannot find KDC for realm "LAB.TEST" while getting initial credentials
```
`kinit` cerca il KDC (il servizio Kerberos) con i record `SRV` del dominio: se il DNS non risponde, "il dominio non si trova", anche con la rete a posto. Il PC ha un DNS sbagliato (succede quando una VPN o un servizio di rete riscrive `/etc/resolv.conf`): deve usare **il DNS del dominio**, cioè il controller.
```bash
printf 'nameserver 10.30.0.10\nsearch lab.test\n' > /etc/resolv.conf
host -t SRV _ldap._tcp.lab.test
# _ldap._tcp.lab.test has SRV record 0 100 389 dc1.lab.test.
echo 'Passw0rd!anna' | kinit anna@LAB.TEST
# Warning: Your password will expire in 41 days on Wed Nov 18 17:20:11 2026
```
Aggiungere `dc1.lab.test` in `/etc/hosts` risolverebbe il **nome**, ma non i record `SRV`: per Kerberos non basta. Su Windows il sintomo è "il dominio specificato non esiste o non può essere contattato" e si guarda `ipconfig /all` e `nslookup -type=SRV _ldap._tcp.lab.test` (non provato qui).
</details>

## 2. "La password è giusta, ma non entra" (1)
**Ticket**: *anna dice di usare la password giusta (`Passw0rd!anna`) ma `kinit anna@LAB.TEST` risponde "Client's credentials have been revoked".*

<details><summary>da dove cominciare</summary>

L'errore non dice "password sbagliata": dice che l'**account** non può entrare. Guarda l'utente con `samba-tool user show` (da amministratore), cercando `userAccountControl`, `badPwdCount` e `lockoutTime`, e la policy di blocco del dominio.
</details>
<details><summary>soluzione</summary>

```bash
echo 'Passw0rd!anna' | kinit anna@LAB.TEST
# kinit: Client's credentials have been revoked while getting initial credentials
samba-tool user show anna $A | grep -E 'userAccountControl|badPwdCount|lockoutTime'
# userAccountControl: 512                          <- 512 = account normale e ABILITATO
# badPwdCount: 3                                   <- tre password sbagliate di fila
# lockoutTime: 134358672175305050                  <- e un orario di blocco: l'account è BLOCCATO
samba-tool domain passwordsettings show $A | grep -i lockout
# Account lockout duration (mins): 30
# Account lockout threshold (attempts): 3          <- dopo 3 tentativi sbagliati l'account si blocca per 30 minuti
# Reset account lockout after (mins): 30
```
L'account è abilitato (`512`) ma **bloccato**: il dominio ha una soglia di 3 tentativi e qualcuno (anche un servizio con la password vecchia) l'ha superata. Con l'account bloccato, anche la password **giusta** viene rifiutata, con lo stesso errore. Si sblocca:
```bash
samba-tool user unlock anna $A
echo 'Passw0rd!anna' | kinit anna@LAB.TEST
# Warning: Your password will expire in 41 days on Wed Nov 18 17:20:15 2026
```
Da sola si sbloccherebbe dopo 30 minuti. `samba-tool user enable anna` non serve: l'account **era già abilitato** (e `controlla` lo verifica). Su Windows: `Search-ADAccount -LockedOut` e `Unlock-ADAccount anna` (evento `4740` sul controller; non provato qui).
</details>

## 3. "La password è giusta, ma non entra" (2)
**Ticket**: *sara è tornata dalle ferie e non entra: `kinit sara@LAB.TEST` con la sua password (`Passw0rd!sara`) risponde "Client's credentials have been revoked".*

<details><summary>da dove cominciare</summary>

Lo stesso errore dello scenario 2, ma **non è detto che sia la stessa causa**. Guarda gli stessi tre attributi di `sara`: dicono se è bloccata o altro.
</details>
<details><summary>soluzione</summary>

```bash
echo 'Passw0rd!sara' | kinit sara@LAB.TEST
# kinit: Client's credentials have been revoked while getting initial credentials
samba-tool user show sara $A | grep -E 'userAccountControl|badPwdCount|lockoutTime'
# badPwdCount: 0                                   <- nessun tentativo sbagliato
# lockoutTime: 0                                   <- e non è bloccata
# userAccountControl: 514                          <- 514 = 512 + 2: l'account è DISABILITATO
```
Stesso messaggio, causa diversa: `userAccountControl` vale `514` (`512` + il bit `2` di "disabilitato"), non c'è nessun blocco. L'account era stato disabilitato per le ferie. Qui `unlock` non serve:
```bash
samba-tool user enable sara $A
# Enabled user 'sara'
echo 'Passw0rd!sara' | kinit sara@LAB.TEST
# Warning: Your password will expire in 41 days on Wed Nov 18 17:20:20 2026
```
Per distinguere **bloccato** da **disabilitato**: `userAccountControl` (514 = disabilitato) e `lockoutTime` (diverso da 0 = bloccato). Su Windows: `Enable-ADAccount sara` (non provato qui). Vedi i bit di `userAccountControl` in [09-active-directory](09-active-directory.md).
</details>

## 4. `KDC reply did not match expectations`
**Ticket**: *`lavoro/accedi.sh` usa la password giusta di anna, ma `kinit` risponde "KDC reply did not match expectations" e non c'è nessun biglietto.*

<details><summary>da dove cominciare</summary>

Guarda **cosa** lo script passa a `kinit`: l'utente, la password e il realm. Ripeti il comando a mano con il realm scritto in modo diverso.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/10-scenari/lavoro
bash accedi.sh
# kinit: KDC reply did not match expectations while getting initial credentials
# klist: No credentials cache found (filename: /tmp/krb5cc_0)
cat accedi.sh | grep kinit
# echo 'Passw0rd!anna' | kinit anna@lab.test                     <- il realm è in minuscolo
echo 'Passw0rd!anna' | kinit anna@LAB.TEST; klist | grep 'Default principal'      # in maiuscolo funziona
# Default principal: anna@LAB.TEST
```
Il **realm di Kerberos** è il nome del dominio **in maiuscolo** (`LAB.TEST`); il nome DNS (`lab.test`) è minuscolo. Con `anna@lab.test` il KDC risponde per `LAB.TEST` e il client si accorge che non è il realm chiesto. Si corregge lo script:
```bash
sed -i 's/anna@lab.test/anna@LAB.TEST/' accedi.sh
bash accedi.sh
# Default principal: anna@LAB.TEST
```
Anche `kinit anna` (senza realm) funziona, perché il realm predefinito è `LAB.TEST` (in `/etc/krb5.conf`). Cambiare la password nello script non serve: la password era giusta.
</details>

## 5. La password non rispetta la policy
**Ticket**: *`lavoro/reimposta.sh` dovrebbe reimpostare la password di marco, ma dà un errore.*

<details><summary>da dove cominciare</summary>

L'errore dice **quale regola** la nuova password non rispetta. Guarda cosa pretende il dominio (`passwordsettings show`) e correggi la **password**, non la regola.
</details>
<details><summary>soluzione</summary>

```bash
cd ~/lab/10-scenari/lavoro
bash reimposta.sh
# ERROR: Failed to set password for user 'marco': (19, 'LDAP error 19 LDAP_CONSTRAINT_VIOLATION -  <0000052D: Constraint violation - check_password_restrictions: the password does not meet the complexity criteria!> <>')
samba-tool domain passwordsettings show $A | grep -iE 'complexity|length'
# Password complexity: on
# Password history length: 24
# Minimum password length: 7
```
La password dello script (`marco123`) è lunga abbastanza (8 caratteri) ma non rispetta la **complessità**: ne servono almeno tre tra maiuscole, minuscole, cifre e simboli, e `marco123` ha solo minuscole e cifre. Si sceglie una password che la rispetti:
```bash
sed -i 's/marco123/Marco!2026/' reimposta.sh
bash reimposta.sh
# Changed password OK
```
Spegnere la complessità (`samba-tool domain passwordsettings set --complexity=off`) farebbe passare lo script, ma **indebolisce la regola per tutto il dominio** per comodità di uno script: `controlla` lo respinge (complessità attiva, minimo 7 caratteri). La stessa policy è in [09-active-directory](09-active-directory.md).
</details>

## 6. `Server not found in Kerberos database`
**Ticket**: *Dopo una pulizia del DNS, `ldapsearch -Y GSSAPI` verso `dc1.lab.test` non funziona più (anche con un biglietto Kerberos valido), mentre `samba-tool` e il DNS diretto vanno.*

<details><summary>da dove cominciare</summary>

Kerberos e LDAP con GSSAPI controllano che il **nome** del server e il suo **indirizzo** coincidano nei due sensi. Prova a risolvere il nome (`host dc1.lab.test`) e poi l'indirizzo al contrario (`host 10.30.0.10`).
</details>
<details><summary>soluzione</summary>

```bash
echo "$PW" | kinit administrator@LAB.TEST
ldapsearch -H ldap://dc1.lab.test -Y GSSAPI -LLL -b 'DC=lab,DC=test' '(sAMAccountName=anna)' dn
# SASL/GSSAPI authentication started
# ldap_sasl_interactive_bind: Local error (-2)
#         additional info: SASL(-1): generic failure: GSSAPI Error: Unspecified GSS failure.  ... (Server not found in Kerberos database)
host dc1.lab.test                                # il nome diretto va
# dc1.lab.test has address 10.30.0.10
host 10.30.0.10                                  # il nome inverso no
# Host 10.0.30.10.in-addr.arpa. not found: 3(NXDOMAIN)
samba-tool dns zonelist dc1.lab.test -U administrator%$PW | grep pszZoneName
#   pszZoneName                 : lab.test
#   pszZoneName                 : _msdcs.lab.test              <- manca la zona inversa 0.30.10.in-addr.arpa
```
Il DNS risolve il nome in indirizzo ma non l'indirizzo in nome: **la zona inversa** `0.30.10.in-addr.arpa` è stata cancellata nella "pulizia". Quando il nome inverso non si risolve, la bind GSSAPI fallisce con `Server not found in Kerberos database` (è la zona che `dc.sh` crea all'avvio). Si ricrea la zona e i due record `PTR`:
```bash
D="-U administrator%$PW"
samba-tool dns zonecreate dc1.lab.test 0.30.10.in-addr.arpa $D
samba-tool dns add dc1.lab.test 0.30.10.in-addr.arpa 10 PTR dc1.lab.test $D
samba-tool dns add dc1.lab.test 0.30.10.in-addr.arpa 5 PTR pc01.lab.test $D
host 10.30.0.10
# 10.0.30.10.in-addr.arpa domain name pointer dc1.lab.test.
ldapsearch -H ldap://dc1.lab.test -Y GSSAPI -LLL -b 'DC=lab,DC=test' '(sAMAccountName=anna)' dn
# SASL SSF: 256
# dn: CN=anna,CN=Users,DC=lab,DC=test
```
Una riga in `/etc/hosts` non basta: `controlla` chiede che sia **il DNS** a rispondere al nome inverso (i client veri non usano il `/etc/hosts` di questo PC). Succede anche nelle reti vere: i nomi **diretti e inversi** di un controller devono coincidere (vedi "La zona inversa" in [09-active-directory](09-active-directory.md)).
</details>

## 7. Un nome che punta all'indirizzo sbagliato
**Ticket**: *`web.lab.test` dovrebbe puntare al server `10.30.0.50`, ma `host web.lab.test` risponde un altro indirizzo.*

<details><summary>da dove cominciare</summary>

Gli oggetti DNS di un dominio stanno nel dominio stesso. Guarda con `samba-tool dns query` i record `A` di `web` e correggili.
</details>
<details><summary>soluzione</summary>

```bash
host web.lab.test
# web.lab.test has address 10.30.0.99
samba-tool dns query dc1.lab.test lab.test web A -U administrator%$PW
#   Name=, Records=1, Children=0
#     A: 10.30.0.99 (flags=f0, serial=2, ttl=900)             <- un solo record, con l'indirizzo sbagliato
```
Il record `A` di `web` ha l'indirizzo sbagliato. Si toglie quello vecchio **e** si aggiunge il nuovo (`samba-tool dns` vuole il **nome del server**, non `-H`):
```bash
samba-tool dns delete dc1.lab.test lab.test web A 10.30.0.99 -U administrator%$PW
# Record deleted successfully
samba-tool dns add dc1.lab.test lab.test web A 10.30.0.50 -U administrator%$PW
# Record added successfully
host web.lab.test
# web.lab.test has address 10.30.0.50
```
Aggiungere solo il record giusto, lasciando quello sbagliato, darebbe **due** indirizzi: il DNS risponde a turno con uno e con l'altro, e metà delle volte il nome sarebbe ancora sbagliato (`controlla` vuole un solo record). Su Windows: `Remove-DnsServerResourceRecord` e `Add-DnsServerResourceRecordA` (non provato qui).
</details>

## 8. Il PC non è più nel dominio
**Ticket**: *Su questo PC `net ads testjoin` dice che il join non è valido. Ieri il PC era nel dominio.*

<details><summary>da dove cominciare</summary>

Un PC "del dominio" ha un **account computer** nella directory. Guarda se c'è (`samba-tool computer list`), e leggi bene l'errore di `testjoin`.
</details>
<details><summary>soluzione</summary>

```bash
net ads testjoin
# kerberos_kinit_password PC01$@LAB.TEST failed: Client not found in Kerberos database
# Join to domain is not valid: LDAP_INVALID_CREDENTIALS
samba-tool computer list $A
# DC1$                                             <- l'account PC01$ non c'è più
```
Per entrare nel dominio un PC crea un **account computer** (`PC01$`) con una password che conosce solo lui e il dominio. Qui l'account è stato cancellato dalla directory (un'altra procedura di pulizia): il PC si presenta, e il dominio dice "non ti conosco". È il caso dell'errore Windows "la relazione di trust tra la workstation e il dominio primario non è riuscita". Si rientra nel dominio:
```bash
net ads join -U "administrator%$PW"
# DNS update failed: NT_STATUS_INVALID_PARAMETER              <- l'aggiornamento DNS del nome del PC non riesce qui: il join sì
# Joined 'PC01' to dns domain 'lab.test'
net ads testjoin
# Join is OK
samba-tool computer list $A
# DC1$
# PC01$
```
Ricreare a mano un account con lo stesso nome (`samba-tool computer create PC01`) non basta: ha un'altra password, e `controlla` lo verifica (`testjoin` deve dire che il join è valido). Su Windows: `Test-ComputerSecureChannel -Repair`, o rientrare con `Add-Computer` (non provato qui).
</details>

---

## Riepilogo: come si riconosce
| Sintomo | Livello | Prima mossa |
|---|---|---|
| `Cannot find KDC for realm` | DNS del client | `cat /etc/resolv.conf`, `host -t SRV _ldap._tcp.dominio` (1) |
| `Client's credentials have been revoked` | stato dell'account | `samba-tool user show`: `userAccountControl`, `lockoutTime` (2: bloccato, 3: disabilitato) |
| `KDC reply did not match expectations` | nome del realm | il realm va in **maiuscolo** (4) |
| `check_password_restrictions` | policy delle password | `passwordsettings show`; si cambia la password, non la regola (5) |
| `Server not found in Kerberos database` | nome inverso | `host INDIRIZZO`, `samba-tool dns zonelist` (6) |
| il nome risponde l'indirizzo sbagliato | record DNS | `samba-tool dns query` (7) |
| `Join to domain is not valid` | account computer | `samba-tool computer list`, `net ads join` (8) |

| | Qui | Su Windows (non provato) |
|---|---|---|
| sbloccare / abilitare | `samba-tool user unlock` / `enable` | `Unlock-ADAccount` / `Enable-ADAccount` |
| account bloccati | `samba-tool user show` (`lockoutTime`) | `Search-ADAccount -LockedOut` |
| il DNS del dominio | `host -t SRV _ldap._tcp.lab.test` | `nslookup -type=SRV _ldap._tcp.lab.test`, `nltest /dsgetdc:lab.test` |
| record DNS | `samba-tool dns add/delete` | `Add-DnsServerResourceRecordA`, `Remove-DnsServerResourceRecord` |
| il PC è nel dominio? | `net ads testjoin` | `Test-ComputerSecureChannel`, `nltest /sc_verify:lab.test` |
| riparare il PC | `net ads join` | `Test-ComputerSecureChannel -Repair`, `Add-Computer` |

## Non provato
- Nessuno scenario di **orologio** (`Clock skew too great`): il container non può cambiare l'ora. La causa e il rimedio (NTP, `w32tm /resync`) sono nel `.md` dell'area, ma non c'è un guasto da riprodurre.
- Manca anche tutto il lato **Windows** (GPO, `gpupdate`, profili, `Test-ComputerSecureChannel -Repair`): la colonna di destra della tabella è presa dai comandi equivalenti e non è stata eseguita.
- Gli scenari agiscono su `pc01` e sulla directory del controller: un `dc1` che non parte, o la replica fra più controller, non ci sono.
- Il tempo per risolvere uno scenario non è stato misurato su una persona.

Torna all'[indice dell'area](README.md)
