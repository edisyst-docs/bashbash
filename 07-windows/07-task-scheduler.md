# Task Scheduler: `cron` di Windows

Su Linux si pianifica con `cron` e i timer systemd ([../06-sistema/09-crontab.md](../06-sistema/09-crontab.md)). Su Windows lo fa l'**Utilità di pianificazione** (*Task Scheduler*): un **task**
dice **cosa** eseguire (azione), **quando** (trigger), **come chi** (principal) e con quali **regole** (impostazioni). Si usa da interfaccia (`taskschd.msc`) e da riga di comando in due modi:

| Strumento | Come è fatto | Quando |
|---|---|---|
| `schtasks` | un comando con molti `/opzioni`, da CMD o PowerShell | task semplici, script `.bat` |
| modulo **ScheduledTasks** (`Register-ScheduledTask`...) | oggetti PowerShell: azione, trigger, impostazioni, principal | tutto il resto: più controllo, e le opzioni si leggono |

| `cron` / systemd | Task Scheduler |
|---|---|
| `crontab -e` | `schtasks /create`, `Register-ScheduledTask` |
| `*/5 * * * *` | trigger **Once** con ripetizione ogni 5 minuti, o `/sc minute /mo 5` |
| `0 3 * * *` | trigger **Daily** alle 3 |
| `0 8 * * 1,3,5` | trigger **Weekly** lunedì, mercoledì, venerdì |
| `@reboot` | trigger **AtStartup** (serve admin) o **AtLogOn** |
| `Persistent=true` (timer) | **`StartWhenAvailable`**: se la macchina era spenta all'ora prevista, lo esegue appena possibile |
| `systemctl list-timers` | `Get-ScheduledTask` |
| `journalctl -u servizio` | `Get-ScheduledTaskInfo` (ultimo esito), la cronologia (disattivata di default) |

Gli esempi sono stati eseguiti su Windows 11 con PowerShell 5.1, **senza privilegi di amministratore**: dove serve l'amministratore c'è scritto. L'output di `schtasks` è nella lingua di Windows
(qui italiano: `Nome attività`, `Prossima esecuzione`, `Stato: Pronta`).

## `schtasks`
```bat
schtasks /create /tn "bashbash-prova\ciao" /tr "cmd /c echo %date% %time% ciao >> C:\Temp\out.txt" /sc minute /mo 1
:: OPERAZIONE RIUSCITA: l'attività pianificata "bashbash-prova\ciao" è stata creata.
schtasks /query /tn "bashbash-prova\ciao"
:: Nome attività                            Prossima esecuzione    Stato
:: ciao                                     05/10/2026 17:13:00    Pronta
schtasks /run /tn "bashbash-prova\ciao"            :: esegui subito, senza aspettare
type C:\Temp\out.txt                                :: 05/10/2026 17:12:49,47 ciao
schtasks /delete /tn "bashbash-prova\ciao" /f      :: /f = senza chiedere conferma
```
`/tn` è il nome del task; con un **percorso** (`cartella\nome`) lo si mette in una cartella dell'Utilità di pianificazione, comodo per raggruppare i propri. `/tr` è il comando.
Nei `.bat` il `%date%` va scritto `%%date%%`.

| Opzione | Cosa fa |
|---|---|
| `/sc minute`, `hourly`, `daily`, `weekly`, `monthly`, `once`, `onlogon`, `onstart`, `onidle` | la **frequenza** (schedule) |
| `/mo N` | modificatore: ogni N minuti, ore, giorni... |
| `/d MON,WED,FRI` | i giorni della settimana (con `weekly`); con `monthly`, il giorno del mese (`/d 1`) |
| `/st 08:30` | l'ora di inizio |
| `/ri 30 /du 08:00` | ripeti ogni 30 minuti per 8 ore (con `daily`) |
| `/ru utente`, `/rp password` | esegui come un altro utente; `/ru SYSTEM` per l'account di sistema (**admin**) |
| `/rl highest` | con i massimi privilegi (**admin**) |
| `/s PC /u utente` | su un altro computer, in rete |
| `/f` | sovrascrive un task che esiste già |

Per ispezionare: `schtasks /query /tn "..." /v /fo list` mostra tutto (`Ultimo esito: 267011`, `Esegui come utente: User`, `Tipo di pianificazione`), `/fo csv` per gli script,
`schtasks /query /xml /tn "..."` la definizione in XML. `schtasks /query` senza nome elenca **tutti** i task del sistema (centinaia: quelli di Windows e dei programmi installati).

## PowerShell: modulo ScheduledTasks
Un task si costruisce a pezzi e si **registra**. Esempio: uno script `.ps1` ogni minuto.
```powershell
$azione  = New-ScheduledTaskAction -Execute "powershell.exe" `
           -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\job.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$opzioni = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "job" -TaskPath "\bashbash-prova\" -Action $azione -Trigger $trigger -Settings $opzioni -Description "prova"
# TaskPath  TaskName  State
# \bashbash-prova\  job   Ready
Get-ScheduledTask -TaskPath "\bashbash-prova\" | Format-Table TaskName,State
Start-ScheduledTask -TaskName job -TaskPath "\bashbash-prova\"          # esegui ora
Get-ScheduledTaskInfo -TaskName job -TaskPath "\bashbash-prova\" | Format-List LastRunTime,LastTaskResult,NextRunTime
# LastRunTime    : 05/10/2026 17:13:02
# LastTaskResult : 0
# NextRunTime    : 05/10/2026 17:14:01
Disable-ScheduledTask -TaskName job -TaskPath "\bashbash-prova\"        # State: Disabled (e Enable-ScheduledTask)
Unregister-ScheduledTask -TaskName job -TaskPath "\bashbash-prova\" -Confirm:$false
```
- **azione**: `-Execute` è il programma, `-Argument` **una sola stringa** con tutti gli argomenti, e anche `-WorkingDirectory`
- **trigger**: `-Once`, `-Daily -At 3am`, `-Weekly -DaysOfWeek Monday,Friday -At 08:30`, `-AtLogOn`, `-AtStartup`. Per il "ogni N minuti" si usa `-Once` con `-RepetitionInterval`
- **impostazioni**: `-StartWhenAvailable`, `-ExecutionTimeLimit`, `-MultipleInstances` (`IgnoreNew`, `Parallel`, `Queue`), `-RunOnlyIfNetworkAvailable`, `-AllowStartIfOnBatteries`, `-WakeToRun`
- `Get-ScheduledTask -TaskPath "\bashbash-prova\*"` elenca la cartella (con `*` finale); `Set-ScheduledTask` modifica un task che esiste (`-Action`, `-Trigger`, `-Settings`)
- `Export-ScheduledTask -TaskName job -TaskPath "\bashbash-prova\"` produce l'XML completo: si può versionare e rimettere con `Register-ScheduledTask -Xml`

### Cosa c'è davvero nelle impostazioni
Il default delle impostazioni è pensato per un portatile, e sorprende. L'XML di un task creato come sopra, con `Export-ScheduledTask`, contiene:
```xml
<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>      <- NON parte se il portatile va a batteria
<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>              <- e si ferma se si stacca l'alimentatore
<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
<StartWhenAvailable>true</StartWhenAvailable>
```
Un task che "non parte mai" su un laptop è quasi sempre il primo. Per i task che devono girare sempre: `New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`.

## Come chi gira, e che cosa serve
Un task ha un **principal**: l'utente e il tipo di accesso.
```powershell
$task.Principal | Format-List UserId,LogonType,RunLevel
# UserId    : User
# LogonType : Interactive          <- gira solo quando l'utente è connesso
# RunLevel  : Limited
```
Quello che si può fare **senza** essere amministratore (provato):

| Cosa | Risultato |
|---|---|
| task per il proprio utente, solo quando è connesso (`Interactive`) | funziona |
| trigger `-AtLogOn -User $env:USERNAME` | funziona |
| trigger `-AtStartup` | **`Accesso negato`** |
| `-RunLevel Highest` | **`Accesso negato`** |
| `-User "SYSTEM"` | **`Accesso negato`** |
| `-LogonType S4U` (gira anche senza accesso interattivo e senza password) | **`Accesso negato`** |

Da amministratore (o per un task "esegui anche se l'utente non è connesso") si usa `-User "SYSTEM"` o un account di servizio, dove nessun utente deve essere connesso. Non provato qui, perché serve un terminale elevato.
Due aspetti da non dimenticare (dalla documentazione di Windows, non provati qui): un task `Interactive` mostra la finestra di una console quando parte (per nasconderla: `-WindowStyle Hidden` in `powershell.exe`, oppure un task
`SYSTEM`/`S4U` che non ha finestra); e gli **unità di rete mappate** (`Z:`) non esistono per un task fuori dalla sessione: si usano i percorsi UNC (`\\server\condivisa`).

## Capire perché un task non funziona
`LastTaskResult` è il **codice d'uscita** del programma, oppure un codice di Task Scheduler. Quelli che si incontrano:

| Codice | Significato |
|---|---|
| `0` | tutto bene |
| `267011` (`0x41303`) | il task **non è ancora mai partito** (è quello che mostra `/query /v` appena creato) |
| `1` | errore generico del programma; per uno script PowerShell vedi sotto |
| `2147942402` (`0x80070002`) | **file non trovato**: il programma dell'azione non esiste |
| qualunque altro numero | l'`exit N` del tuo script: `exit 3` → `LastTaskResult = 3` |

Un test con uno script che fa `exit 3`:
```powershell
# fail.ps1 contiene:  exit 3
Start-ScheduledTask -TaskName fail ; Start-Sleep 3 ; (Get-ScheduledTaskInfo -TaskName fail).LastTaskResult
# 1          <- con "-NoProfile -File fail.ps1": NON è il 3 dello script!
# 3          <- con "-NoProfile -ExecutionPolicy Bypass -File fail.ps1"
```
Il `1` era la **ExecutionPolicy**: su Windows client il default è `Restricted`, che **blocca l'esecuzione di qualsiasi `.ps1`**, e `powershell.exe` esce con 1 senza nemmeno aprire lo script.
Per questo gli esempi di task usano `-ExecutionPolicy Bypass` (vale solo per quel processo); si controlla con `Get-ExecutionPolicy -List`.
Un task con un programma che non esiste (`C:\nonesiste\x.exe`) dà `2147942402` (`0x80070002`, `ERROR_FILE_NOT_FOUND`): `"0x{0:X}" -f 2147942402` converte.

**La cronologia è spenta di default.** `(Get-WinEvent -ListLog "Microsoft-Windows-TaskScheduler/Operational").IsEnabled` dà `False`, e `Get-WinEvent -LogName` non trova eventi: nel registro non c'è niente finché non si
attiva (da amministratore: `wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true`, o *Utilità di pianificazione → Abilita cronologia di tutte le attività*; non provato qui). Prima di
poterci contare, il modo più semplice per sapere cosa è successo è far scrivere un **log al proprio script** (`Start-Transcript`, o `>> C:\Logs\job.log 2>&1`), come per `cron`.

## Un esempio completo: backup notturno
```powershell
# C:\Scripts\backup.ps1 scrive un log e ha un exit code vero
$log = "C:\Logs\backup.log"
try {
    robocopy C:\Dati D:\Backup /MIR /R:2 /W:5 /NP /LOG+:$log
    if ($LASTEXITCODE -ge 8) { throw "robocopy ha fallito: $LASTEXITCODE" }   # robocopy: 0-7 sono successi
} catch {
    Add-Content $log "$(Get-Date -Format s) ERRORE: $_"
    exit 1
}
```
```powershell
$azione  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\backup.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
$opzioni = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName "backup-notturno" -TaskPath "\Miei\" -Action $azione -Trigger $trigger -Settings $opzioni
```
`StartWhenAvailable` fa partire il backup alla prima occasione se alle 3 il PC era spento. Il codice di `robocopy` (0-7 ok, 8 e oltre errore) è in [06-cmd-rete-e-sistema.md](06-cmd-rete-e-sistema.md) e
nei `.bat` di [03-esempi/](03-esempi/).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `Accesso negato` alla registrazione | trigger `AtStartup`, `SYSTEM`, `RunLevel Highest`, `S4U` | terminale come amministratore |
| il task non parte su un portatile | `DisallowStartIfOnBatteries` è `true` di default | `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries` |
| `LastTaskResult` `1` per uno script `.ps1` | ExecutionPolicy `Restricted` | `-ExecutionPolicy Bypass` nell'argomento |
| `0x80070002` | il programma o il percorso non esiste | percorsi **assoluti**, e `-WorkingDirectory` per quelli relativi |
| `267011` (`0x41303`) | non è mai partito | trigger nel passato, task disabilitato, o `-Once` senza ripetizione già scattato |
| il task funziona a mano e non da pianificato | variabili d'ambiente e `PATH` dell'utente, drive mappati | percorsi assoluti e UNC; il task non ha la shell interattiva |
| nessuna cronologia | è disattivata di default | log nello script, o abilitare il registro (admin) |
| un task scatta due volte | più trigger, o ripetizione e `-MultipleInstances Parallel` | `Get-ScheduledTask -TaskName X \| Select -Expand Triggers` |
