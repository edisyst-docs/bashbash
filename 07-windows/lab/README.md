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

Torna all'[indice dell'area](../README.md)
