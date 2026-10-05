# Active Directory

> **Laboratorio**: `./lab.sh 07`. Un controller di dominio vero (Samba 4) e un PC "del dominio": [lab/](lab/). Il PC Windows di una rete aziendale si comporta allo stesso modo, ma i comandi di questa pagina sono quelli di Linux (`samba-tool`, `ldapsearch`, `kinit`):
> le equivalenze con PowerShell sono nella tabella e in [lab/](lab/) (`ad.ps1`), e **non sono state eseguite**.

In un'azienda i PC, gli utenti e le regole non si gestiscono uno per uno: stanno in un **dominio**, e la directory che lo descrive è **Active Directory** (AD) di Microsoft. Sono tre servizi insieme, che girano su uno o più server chiamati **controller di dominio** (DC):

| Servizio | Cosa fa | Porta |
|---|---|---|
| **LDAP** | la *directory*: un albero di oggetti (utenti, gruppi, computer) che si interroga e si modifica | 389 (636 con TLS), 3268 per il catalogo globale |
| **Kerberos** | l'autenticazione: l'utente prova chi è **una volta** e riceve un *ticket* che vale per tutti i servizi del dominio (single sign-on) | 88 |
| **DNS** | trova i servizi: i **record SRV** dicono dove sta il controller (`_ldap._tcp.lab.test`) | 53 |
| SMB | `SYSVOL` e `NETLOGON`: le cartelle con le **Criteri di gruppo** e gli script di accesso | 445 |

## Gli oggetti
```
lab.test                       <- il dominio (DC=lab,DC=test)
 ├── Users, Computers, ...     <- contenitori predefiniti
 ├── Domain Controllers        <- l'OU dei controller
 └── Ufficio                   <- un'OU (unità organizzativa) nostra
      ├── Anna Rossi           <- utente
      ├── contabilita          <- gruppo
      └── PC01                 <- computer (dopo il join)
```
- **dominio**: il confine di gestione e di sicurezza, con un nome DNS (`lab.test`) e uno corto NetBIOS (`LAB`). **Foresta**: uno o più domini con la stessa radice
- **OU** (*Organizational Unit*): una cartella dentro il dominio. Serve a due cose: ordinare e **dare regole** (si collega un criterio di gruppo a un'OU e vale per quello che contiene) o delegare l'amministrazione
- **utente**, **gruppo**, **computer**: gli oggetti veri. Il PC ha un account come l'utente (`PC01$`, con la password cambiata da solo ogni 30 giorni)
- **DN** (*distinguished name*): l'indirizzo completo di un oggetto, dal basso verso l'alto: `CN=Anna Rossi,OU=Ufficio,DC=lab,DC=test`. `CN` è il nome, `OU` l'unità, `DC` le parti del nome del dominio
- **GPO** (*Group Policy Object*, Criteri di gruppo): impostazioni (password, USB, sfondo, software) che i PC del dominio applicano da soli
- gli attributi che si usano di più: `sAMAccountName` (il nome di login breve: `anna`), `userPrincipalName` (`anna@lab.test`), `memberOf` (i gruppi), `userAccountControl` (lo stato: `512` normale, `514` disabilitato)

## Il laboratorio
`./lab.sh 07` avvia due container sulla rete `10.30.0.0/24`:

| | Cosa è |
|---|---|
| `dc1` (`10.30.0.10`) | il controller di dominio, **Samba 4 come DC Active Directory**, dominio `lab.test` (NetBIOS `LAB`). Amministratore: `administrator`, password `Passw0rd!2026` |
| `pc01` (`10.30.0.5`) | dove si lavora: una macchina con gli strumenti per amministrare il dominio da remoto e per **entrarci** |

La prima volta ci vuole circa un minuto: `dc.sh` installa e configura il dominio (`samba-tool domain provision`). Samba 4 parla il protocollo di AD (LDAP, Kerberos, DNS, SMB, le GPO): un PC Windows può anche
entrare in un dominio Samba. Per i comandi quotidiani cambia lo strumento, non il concetto:

| Operazione | PowerShell (modulo ActiveDirectory, RSAT) | Qui |
|---|---|---|
| un'OU | `New-ADOrganizationalUnit -Name Ufficio -Path "DC=lab,DC=test"` | `samba-tool ou create "OU=Ufficio"` |
| un utente | `New-ADUser -Name "Anna Rossi" -SamAccountName anna ...` | `samba-tool user create anna ...` |
| un gruppo | `New-ADGroup -Name contabilita -GroupScope Global` | `samba-tool group add contabilita` |
| membri | `Add-ADGroupMember contabilita anna,marco` | `samba-tool group addmembers contabilita anna,marco` |
| elencare | `Get-ADUser -Filter *` | `samba-tool user list`, `ldapsearch` |
| disabilitare | `Disable-ADAccount anna` | `samba-tool user disable anna` |
| password | `Set-ADAccountPassword anna -Reset` | `samba-tool user setpassword anna` |
| sbloccare | `Unlock-ADAccount anna` | `samba-tool user unlock anna` |
| la cartella `SYSVOL` e le GPO | console *Gestione Criteri di gruppo* (GPMC), `New-GPO` | `samba-tool gpo` |

## Il dominio: DNS, Kerberos, LDAP
Un client trova il dominio **solo con il DNS**: il suo DNS deve essere quello del dominio. Nel laboratorio `pc01` lo ha già.
```bash
host -t SRV _ldap._tcp.lab.test            # _ldap._tcp.lab.test has SRV record 0 100 389 dc1.lab.test.
host -t SRV _kerberos._tcp.lab.test        # ... 0 100 88 dc1.lab.test.
host dc1.lab.test                          # dc1.lab.test has address 10.30.0.10
samba-tool domain info 10.30.0.10
# Forest           : lab.test
# Domain           : lab.test
# Netbios domain   : LAB
# DC name          : dc1.lab.test
```
I record `_ldap._tcp` e `_kerberos._tcp` sono come un client Windows sa **a quale server** parlare: se il DNS non li risolve, "il dominio non si trova", e quasi tutti i problemi di AD sono problemi di DNS.

Un'**amministrazione da remoto** è un comando con `-H ldap://dc1.lab.test -U administrator%password` (in questa pagina abbreviato con `A`):
```bash
PW='Passw0rd!2026'
A="-H ldap://dc1.lab.test -U administrator%$PW"
```

## OU, gruppi e utenti
```bash
samba-tool ou create "OU=Ufficio" $A
samba-tool ou list $A
# OU=Ufficio
# OU=Domain Controllers
samba-tool group add contabilita --groupou="OU=Ufficio" $A
samba-tool user create anna 'Passw0rd!anna' --given-name=Anna --surname=Rossi --userou="OU=Ufficio" $A
samba-tool group addmembers contabilita anna $A
samba-tool user list $A
# luca sara Guest Administrator krbtgt marco anna
samba-tool user show anna $A | grep -E '^(dn|sAMAccountName|userPrincipalName|memberOf|userAccountControl):'
# dn: CN=Anna Rossi,OU=Ufficio,DC=lab,DC=test
# sAMAccountName: anna
# userPrincipalName: anna@lab.test
# memberOf: CN=contabilita,OU=Ufficio,DC=lab,DC=test
# userAccountControl: 512
```
La password deve rispettare la **policy del dominio** (complessità, lunghezza minima 7, storico di 24):
```bash
samba-tool user setpassword marco --newpassword='breve' $A
# ERROR: Failed to set password for user 'marco': ... check_password_restrictions: the password is too short. It should be equal or longer than 7 characters!
samba-tool user setpassword marco --newpassword='Nuova!Passw0rd9' $A       # Changed password OK
```
`userAccountControl` è un insieme di bit: `512` è un account normale, `514` è **disabilitato** (512 + 2).
```bash
samba-tool user disable sara $A ; samba-tool user enable sara $A
samba-tool user delete sara $A                    # Deleted user sara
```

### Creare molti utenti
Con la cartella `09-active-directory/` del laboratorio, `crea-utenti.sh` legge un file CSV e crea utenti e membri dei gruppi:
```bash
cat utenti.csv
# nome,cognome,utente,gruppo
# Anna,Rossi,anna,contabilita
# Marco,Bianchi,marco,contabilita
# Luca,Verdi,luca,magazzino
# Sara,Neri,sara,magazzino
./crea-utenti.sh utenti.csv                       # chiede la password di administrator
# User 'anna' added successfully / creato anna ...
samba-tool group listmembers magazzino $A         # sara luca
```
Su Windows è un ciclo di `Import-Csv` con `New-ADUser` (nel file `ad.ps1`).

## Cercare con LDAP
`samba-tool` è comodo per le operazioni; per **interrogare** la directory si usa LDAP, con filtri. Prima l'autenticazione Kerberos:
```bash
echo "$PW" | kinit administrator@LAB.TEST          # il ticket (TGT). Warning: Your password will expire in 41 days ...
klist
# Ticket cache: FILE:/tmp/krb5cc_0
# Default principal: administrator@LAB.TEST
# Valid starting     Expires            Service principal
# 10/05/26 15:21:07  10/06/01:21:07     krbtgt/LAB.TEST@LAB.TEST
```
```bash
ldapsearch -H ldap://dc1.lab.test -Y GSSAPI -LLL -b "OU=Ufficio,DC=lab,DC=test" "(objectClass=user)" sAMAccountName memberOf
# dn: CN=Anna Rossi,OU=Ufficio,DC=lab,DC=test
# sAMAccountName: anna
# memberOf: CN=contabilita,OU=Ufficio,DC=lab,DC=test
# ...
```
`-b` è la base della ricerca (da dove scendere), `-Y GSSAPI` usa il ticket Kerberos, `-LLL` toglie i commenti, e gli ultimi argomenti sono il **filtro** e gli attributi da mostrare. I filtri:

| Filtro | Cosa trova |
|---|---|
| `(sAMAccountName=anna)` | un utente |
| `(&(objectClass=user)(sAMAccountName=*a))` | AND: utenti il cui nome finisce per `a` (`*` è un carattere jolly) |
| `(\|(sAMAccountName=anna)(sn=Verdi))` | OR |
| `(memberOf=CN=contabilita,OU=Ufficio,DC=lab,DC=test)` | i membri di un gruppo |
| `(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2))` | gli account **disabilitati**: la regola `1.2.840.113556.1.4.803` è un AND bit a bit sul bit 2. (Con `sara` disabilitata: `sara`, e anche `Guest` e `krbtgt`, che lo sono di fabbrica) |

Provato: `memberOf` di un gruppo dà `anna` e `marco`; il filtro AND con `*a` dà `luca`, `sara`, `anna`; quello OR dà `Luca Verdi` e `Anna Rossi`.
Un **bind semplice** (utente e password in chiaro) è rifiutato: `Strong(er) authentication required ... Transport encryption required.` Con Kerberos (GSSAPI) o con LDAPS sulla 636 funziona.

## Entrare nel dominio (join)
Un PC diventa "del dominio" quando ha un **account computer**: da quel momento si fida del DC e gli utenti del dominio possono accedervi.
```bash
net ads join -U "administrator%$PW"
# DNS update failed: NT_STATUS_INVALID_PARAMETER           <- l'aggiornamento DNS del nome del PC: non riuscito qui, il join sì
# Joined 'PC01' to dns domain 'lab.test'
net ads testjoin                                           # Join is OK
samba-tool computer list $A                                # DC1$ / PC01$
```
Da Windows è `Add-Computer -DomainName lab.test -Credential LAB\administrator -Restart` (non provato), o *Sistema → Dominio*.
Poi un utente si autentica con il suo ticket e accede alle risorse del dominio:
```bash
echo 'Passw0rd!anna' | kinit anna@LAB.TEST ; klist | grep -E 'Default|krbtgt'
# Default principal: anna@LAB.TEST
# 10/05/26 15:21:18  10/06/26 01:21:18  krbtgt/LAB.TEST@LAB.TEST
smbclient //dc1.lab.test/sysvol -U 'anna%Passw0rd!anna' -c ls         # la cartella delle GPO: lab.test D ...
```
Il `kinit` con la password sbagliata dà `Password incorrect while getting initial credentials`. L'orologio deve essere allineato a meno di **5 minuti** con il DC, altrimenti Kerberos rifiuta il ticket (`Clock skew too great`: non
provato, ma è la prima cosa da controllare quando "il login non funziona").

## Policy delle password e blocco degli account
```bash
samba-tool domain passwordsettings show $A
# Password complexity: on
# Password history length: 24
# Minimum password length: 7
# Minimum password age (days): 1
# Maximum password age (days): 42
# Account lockout duration (mins): 30
# Account lockout threshold (attempts): 0          <- 0: l'account non si blocca MAI, per quanti tentativi sbagliati
```
Con soglia 0, `kinit` con la password sbagliata si può provare all'infinito (provato: sei tentativi, `badPwdCount` resta `0`). Con una soglia:
```bash
samba-tool domain passwordsettings set --account-lockout-threshold=3 --account-lockout-duration=5 --reset-account-lockout-after=5 $A
echo sbagliata | kinit anna@LAB.TEST               # x3: Password incorrect while getting initial credentials
echo sbagliata | kinit anna@LAB.TEST               # il 4°: Client's credentials have been revoked while getting initial credentials
echo 'Passw0rd!anna' | kinit anna@LAB.TEST         # con la password GIUSTA: lo stesso errore, l'account è bloccato
samba-tool user show anna $A | grep -E 'lockoutTime|badPwdCount'     # badPwdCount: 3 / lockoutTime: 1343568733...
samba-tool user unlock anna $A                     # sbloccato (altrimenti dopo 5 minuti da solo)
```
Il "bloccato" è la causa di molte chiamate al supporto: la password è giusta e non entra comunque. Nei log di un DC Windows è l'evento `4740`.

## Criteri di gruppo (GPO)
Una GPO è un oggetto nella directory e una cartella in `SYSVOL` con le impostazioni. Si **collega** a un'OU (o al dominio), e i PC e gli utenti lì dentro la applicano all'avvio e ogni 90 minuti circa.
```bash
samba-tool gpo create "Blocca USB" $A
# GPO 'Blocca USB' created as {DDAE3CD8-B3B8-49D1-88BE-2331569EDED9}
samba-tool gpo listall $A | grep 'display name'
# display name : Default Domain Policy
# display name : Blocca USB
# display name : Default Domain Controllers Policy
```
Le impostazioni dentro la GPO e il collegamento a un'OU si fanno con la console *Gestione Criteri di gruppo* di Windows (`samba-tool gpo setlink` esiste, ma non è stato provato): il laboratorio ha solo la creazione. Sul PC Windows:
```powershell
gpupdate /force            # applica subito, senza aspettare
gpresult /r                # quali GPO si applicano a questo utente e a questo PC
```

## DNS del dominio
Gli oggetti DNS stanno in AD, e si gestiscono con `samba-tool dns` (su Windows: `Add-DnsServerResourceRecordA`, `dnsmgmt.msc`):
```bash
samba-tool dns add dc1.lab.test lab.test web A 10.30.0.50 -U "administrator%$PW"      # Record added successfully
host web.lab.test                                   # web.lab.test has address 10.30.0.50
samba-tool dns query dc1.lab.test lab.test @ A -U "administrator%$PW" | grep -E 'Name=|A:'
samba-tool dns delete dc1.lab.test lab.test web A 10.30.0.50 -U "administrator%$PW"
```
Qui `samba-tool dns` vuole il **nome del server** (`dc1.lab.test`), non `-H`.

**La zona inversa** (da IP a nome) deve esistere: nel laboratorio senza la zona `0.30.10.in-addr.arpa`, Docker risponde lui al nome inverso dell'IP del DC (`lab-07-dc1-1.lab-07_ad`) e il client Kerberos cerca un servizio con quel nome, che non esiste:
```
ldap_sasl_interactive_bind: Local error (-2)
    additional info: SASL(-1): generic failure: GSSAPI Error: ... (Server not found in Kerberos database)
```
`dc.sh` la crea (`samba-tool dns zonecreate` e due `dns add ... PTR`). Succede anche nelle reti vere: Kerberos e i nomi **diretti e inversi** devono coincidere.

## Sul PC Windows (non provato)
Questo PC di prova non è in un dominio (`(Get-CimInstance Win32_ComputerSystem).PartOfDomain` è `False`, `Domain` è `WORKGROUP`; `nltest /dsgetdc:lab.test` dà `ERROR_NO_SUCH_DOMAIN`; `klist` ha 0 ticket), quindi qui i comandi di AD
sono quelli da riconoscere in una rete aziendale:
```powershell
(Get-CimInstance Win32_ComputerSystem) | Select Name, Domain, PartOfDomain       # il PC è nel dominio?
echo $env:USERDOMAIN $env:USERDNSDOMAIN             # LAB  lab.test
whoami.exe /upn ; whoami.exe /groups                # chi sono nel dominio, e in quali gruppi (whoami.exe: in PowerShell con Git nel PATH `whoami` è quello di Linux)
nltest /dsgetdc:lab.test                            # quale controller risponde
nltest /sc_verify:lab.test                          # il canale sicuro del PC con il dominio
Test-ComputerSecureChannel -Repair                  # lo ripara (account computer scollegato: "relazione di trust non riuscita")
net user /domain ; net group /domain                # utenti e gruppi del dominio
klist ; klist purge                                 # i ticket Kerberos in cache
Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'    # installa il modulo ActiveDirectory (amministratore)
Get-ADUser anna -Properties MemberOf, LastLogonDate, LockedOut
Get-ADUser -Filter 'Enabled -eq $false' | Select Name
Search-ADAccount -LockedOut ; Unlock-ADAccount anna
```
Il nome del modulo (`Get-AD*`) è l'equivalente di `samba-tool` e di `ldapsearch` di questa pagina: stessi oggetti, stesse operazioni.

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| "il dominio non si trova" / join fallito | il DNS del client non è quello del dominio | `host -t SRV _ldap._tcp.dominio` deve rispondere; `nslookup -type=SRV _ldap._tcp.lab.test` su Windows |
| `Server not found in Kerberos database` | nome diretto e inverso del server non coincidono (manca la zona inversa) | creare la zona inversa e i PTR |
| `Clock skew too great` | orologi non allineati (più di 5 minuti) | NTP / `w32tm /resync` |
| `Client's credentials have been revoked` | account bloccato (o disabilitato) | `samba-tool user unlock` / `Unlock-ADAccount`, `userAccountControl` |
| `Password incorrect` anche se giusta | password scaduta o cambiata, tastiera, o il suffisso del realm (`@LAB.TEST` maiuscolo) | `kinit utente@REALM` con il REALM **maiuscolo** |
| `Strong(er) authentication required` | bind LDAP semplice senza cifratura | GSSAPI o LDAPS |
| `check_password_restrictions: the password is too short` | policy del dominio | rispettare complessità e lunghezza |
| `The trust relationship between this workstation and the primary domain failed` | la password dell'account computer non coincide più (ripristino da snapshot, PC fermo mesi) | `Test-ComputerSecureChannel -Repair`, o rientrare nel dominio |
| `samba-tool: no such option: -H` (con `dns`) | `samba-tool dns` vuole il server, non `-H` | `samba-tool dns add dc1.lab.test ...` |

Torna all'[indice dell'area](README.md)
