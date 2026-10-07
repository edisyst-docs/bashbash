# 07 - Windows

Scripting e amministrazione sul lato Windows: batch, PowerShell, pianificazione, pacchetti e Active Directory.

**Laboratorio**: `./lab.sh 07` dalla radice della KB avvia un controller di dominio Active Directory (Samba 4) e un PC con gli strumenti per amministrarlo, per `09-active-directory.md`. Dettagli in [lab/](lab/).

| # | File | Contenuto |
|---|---|---|
| 01 | [batch](01-batch.md) | Sintassi `.bat`: variabili, parametri, `if`, `goto`, `for`, esempi completi |
| 02 | [powershell](02-powershell.md) | Cmdlet per servizi, processi, alias, rete, event log; con lo script di esempio [02-power1.ps1](02-power1.ps1) |
| 03 | [esempi .bat](03-esempi/) | Sei script funzionanti, uno per riga nel [README](03-esempi/README.md): `prova.bat`, backup, clone Laravel, pulizia, due menu |
| 04 | [powershell scripting](04-powershell-scripting.md) | Il linguaggio: variabili, operatori, `if`/`switch`, cicli, funzioni con `param()`, `try`/`catch` |
| 05 | [WSL e winget](05-wsl-e-winget.md) | Gestione di WSL, file e interoperabilità Windows/Linux, `wsl.conf`, `winget` |
| 06 | [CMD rete e sistema](06-cmd-rete-e-sistema.md) | `ipconfig`, `tracert`, `pathping`, `netstat`, `route`, `arp`, `netsh`, `tasklist`/`taskkill`, `net`, `systeminfo`, `clip` |
| 07 | [task scheduler](07-task-scheduler.md) | `schtasks` e il modulo ScheduledTasks: azioni, trigger, impostazioni, codici di uscita, cosa serve da amministratore |
| 08 | [scoop e chocolatey](08-scoop-e-chocolatey.md) | Altri gestori di pacchetti a confronto con `winget`: Scoop (bucket, shim, versioni) e Chocolatey |
| 09 | [active directory](09-active-directory.md) | Dominio, OU, utenti e gruppi, LDAP e Kerberos, join, GPO, DNS, con un controller di dominio Samba 4 |
| 10 | [scenari guidati](10-scenari.md) | 8 guasti veri del dominio da diagnosticare: DNS, account bloccato o disabilitato, realm, policy, zona inversa, record DNS, account computer; `scenari.sh controlla` guarda se il sintomo è sparito |

Area precedente: [../06-sistema/](../06-sistema/) · Prossima: [../08-remoto-e-sicurezza/](../08-remoto-e-sicurezza/) · Torna all'[indice](../README.md)
