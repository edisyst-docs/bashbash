# Laboratorio dell'area 07

L'area è sul lato **Windows** (`.bat`, PowerShell, `winget`): quei file girano su un PC Windows, non in un container. Il laboratorio c'è per **[09-active-directory.md](../09-active-directory.md)**,
che ha bisogno di un controller di dominio vero. Lo descrive [compose.yaml](compose.yaml):
```
pc01 10.30.0.5 ---- rete "ad" ---- dc1 10.30.0.10
```

| Container | Cosa è |
|---|---|
| `dc1` | un controller di dominio **Active Directory** (Samba 4) per `lab.test` (NetBIOS `LAB`), con DNS, Kerberos, LDAP e SYSVOL. Lo installa [dc.sh](dc.sh) al primo avvio. Amministratore: `administrator`, password `Passw0rd!2026` |
| `pc01` | dove si lavora: `lab.sh` entra qui. Ha `samba-tool`, `ldapsearch`, `kinit`, `klist`, `smbclient` e `net ads` (lo prepara [pc.sh](pc.sh)), e usa il DNS del dominio |

I file di lavoro li genera [prepara.sh](prepara.sh).

## Avvio
Dalla radice della KB:
```bash
./lab.sh 07               # la prima volta costruisce l'immagine bashbash-systemd; poi dc1 installa Samba (circa un minuto, serve internet)
cd 09-active-directory
host -t SRV _ldap._tcp.lab.test
```
All'uscita i due container e la rete vengono eliminati: il dominio, gli utenti e le GPO spariscono.

## 09-active-directory
In `09-active-directory/`: `utenti.csv` e `crea-utenti.sh` (creazione in blocco), e `ad.ps1` con i comandi PowerShell equivalenti, che **non si eseguono** nel laboratorio.
Il percorso del `.md`: OU, gruppi e utenti con `samba-tool` (`-H ldap://dc1.lab.test -U administrator%...`), ricerche con `ldapsearch -Y GSSAPI`, `net ads join` per far entrare `pc01` nel dominio, policy delle password
e blocco degli account, `samba-tool gpo create`, record DNS.

Da sapere:
- serve internet (`apt`) a ogni avvio: `dc1` e `pc01` partono da una macchina pulita
- `pc01` ha il DNS del dominio in `/etc/resolv.conf` (lo scrive `pc.sh`): se lo si rimette a quello di Docker, i nomi del dominio e Kerberos smettono di funzionare
- il dominio ha una **zona inversa** (`0.30.10.in-addr.arpa`, creata da `dc.sh`): senza, `ldapsearch -Y GSSAPI` dà `Server not found in Kerberos database`
- `net ads join` stampa `DNS update failed: NT_STATUS_INVALID_PARAMETER` e poi `Joined 'PC01' to dns domain 'lab.test'`: il join riesce, è solo l'aggiornamento automatico del nome del PC a non riuscire
- i comandi con `-H` mostrano `WARNING: Using passwords on command line is insecure`: è la password nella riga di comando, ed è normale in un laboratorio

## 10-scenari
`10-scenari/` ha `scenari.sh`, che lancia [scenari.sh](scenari.sh) (qui in `lab/`, con i guasti dentro): `./scenari.sh guasta N` porta il dominio in salute e poi lo rompe come lo scenario N (8 in tutto) stampando il sintomo; `controlla` dice se è sparito; `ripristina` toglie ogni guasto. La base sana: gli utenti `anna`, `marco`, `sara` (password `Passw0rd!NOME`, abilitati e sbloccati), la policy predefinita (complessità, minimo 7 caratteri, nessun blocco), la zona inversa con i due `PTR`, nessun record `web`, `/etc/resolv.conf` del dominio e `pc01` unito al dominio.
I guasti: il DNS del PC a `127.0.0.1`, `anna` bloccata (soglia di 3 tentativi), `sara` disabilitata (stesso errore di `kinit`, causa diversa), uno script con il realm in minuscolo, uno script con una password che non rispetta la complessità, la zona inversa cancellata, un record `A` sbagliato e l'account computer `PC01$` cancellato. Le riparazioni di riferimento e i tentativi che non bastano (`unlock` per un account disabilitato, complessità spenta, `/etc/hosts`, record aggiunto senza togliere il vecchio, account `PC01` ricreato a mano...) sono in [scenari-soluzioni.sh](scenari-soluzioni.sh); [scenari-autotest.sh](scenari-autotest.sh) rompe, prova le scorciatoie e ripara ogni scenario (circa 1 minuto), e deve dire che tutti i controlli sono ok (lo lancia la CI).
Da sapere, trovato provando: scrivere un DNS irraggiungibile in `/etc/resolv.conf` non basta se è `127.0.0.11` (il DNS di Docker inoltra a quello del controller, indicato in `compose.yaml`): lo scenario 1 usa `127.0.0.1`.

Torna all'[indice dell'area](../README.md)
