## Comandi base

```shell
Get-Service # mostra tutti i servizi
Get-Service | Where-Object {$_.Status -eq "running"} # mostra solo i servizi attivi
Stop-Service Themes # stoppa il servizio Temi
Get-Service | Where-Object {$_.name -eq "Themes"} # se lo cerco è Stopped
Start-Service Themes # lo riavvia
```

```shell
Get-Alias # lista degli alias
Get-Alias -Definition Get-ChildItem # è l'alias di dir,ls
Get-Alias | Where-Object {$_.name -clike "dir"} # trova l'alias di dir
Get-Alias | Where-Object {$_.name -clike "cd"} # alias di cd = Set-Location

Set-Alias listonebalasso Get-ChildItem # creo un alias identico a dir,ls
```

```shell
Get-Process # mostra i processi attivi
Get-Process | sort ProcessName
Get-Process | Export-Clixml C:\laragon\www\lista-proc.xml # esporta la lista XML

# posso avviare dei servizi
# notepad
# calc
# code # VS code

Get-Process | Export-Clixml C:\laragon\www\lista-proc1.xml # esporta un'altra lista 
```


```shell
Compare-Object -ReferenceObject (Import-Clixml C:\laragon\www\lista-processi.xml) -DifferenceObject (Import-Clixml C:\laragon\www\lista-processi1.xml) # Compare-Object=diff
Compare-Object -ReferenceObject (Import-Clixml C:\laragon\www\lista-processi.xml) -DifferenceObject (Import-Clixml C:\laragon\www\lista-processi1.xml) -Property name

Get-Module -ListAvailable # lista moduli attivi

Get-EventLog -LogName system -Newest 50 # devo specificarglieli altrimenti mostra un mucchio di righe
  
Get-EventLog -LogName system -Newest 50 | gm # mi dice metodi e property che potrei voler usare per un sort
```



## Rete e diagnostica


```shell
Get-NetIPConfiguration # info sulla ethernet in uso: modello, dominio, IPv4, DNS
Get-NetIPAddress # tutti gli IP configurati sulla macchina
Test-NetConnection keep.google.com # una sorta di ping/telnet, mi risolve anche il DNS
Test-NetConnection keep.google.com - Port "80" # ping con una specifica RemotePort
Test-NetConnection keep.google.com -CommonTCPPort HTTP # capisce qual è la porta utilizzata
Test-NetConnection keep.google.com -TraceRoute # mi dà tutta la rotta percorsa x arrivare al server finale
```

```shell
Resolve-DnsName keep.google.com # mi risolve solo il DNS
Get-NetRoute -Protocol Local -DestinationPrefix 192.168* # mostra le rotte degli indirizzi IP
Get-NetTCPConnection # elenca le porte in ascolto, connesse, chiuse, ecc

slmgr /dlv # versione Window, eccetera

Get-Help Copy-Item # help per esempio di "copia file"
```


## Equivalenti dei comandi Linux

```shell
Get-ChildItem -Recurse -Filter *.log                         # find . -name "*.log"
Select-String -Path .\*.log -Pattern "ERROR"                 # grep ERROR *.log
Get-ChildItem -Recurse -Include *.php | Select-String "dd\(" # grep -r "dd(" --include=*.php
Get-Content .\laravel.log -Tail 50 -Wait                     # tail -n 50 -f
Get-Content .\file.txt | Measure-Object -Line                # wc -l
Get-Process | Sort-Object WS -Descending | Select-Object -First 10 Name, Id, @{n='MB';e={[math]::Round($_.WS/1MB)}} # ps aux --sort=-%mem | head
Stop-Process -Name php -Force                                # pkill php
Get-Command git                                              # which git
$env:PATH -split ';'                                         # echo $PATH, una cartella per riga
```


## Esempi pratici

```shell
# i 20 file più grandi dentro una cartella, con la dimensione in MB
Get-ChildItem C:\laragon\www -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 20 FullName, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}

# dimensione di ogni sottocartella (come du -sh *)
Get-ChildItem C:\laragon\www -Directory | ForEach-Object {
    $mb = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    [pscustomobject]@{ Cartella = $_.Name; MB = [math]::Round($mb, 1) }
} | Sort-Object MB -Descending
```

```shell
# quale processo occupa la porta 8000, e poi lo termina
Get-NetTCPConnection -LocalPort 8000 -State Listen | Select-Object OwningProcess, @{n='Nome';e={(Get-Process -Id $_.OwningProcess).Name}}
Get-NetTCPConnection -LocalPort 8000 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }

# un servizio web risponde? (come curl -I)
Invoke-WebRequest https://example.com -Method Head -UseBasicParsing | Select-Object StatusCode

# la porta 3306 di un server è raggiungibile? (come nc -zv)
Test-NetConnection db.interno -Port 3306 -InformationLevel Quiet   # restituisce solo True/False
```

```shell
# backup zip datato di un progetto, escludendo vendor e node_modules
$oggi = Get-Date -Format 'yyyy-MM-dd'
$src  = 'C:\laragon\www\progetto'
$file = Get-ChildItem $src -Recurse -File | Where-Object { $_.FullName -notmatch '\\(vendor|node_modules|\.git)\\' }
Compress-Archive -Path $file.FullName -DestinationPath "D:\backup\progetto_$oggi.zip" -CompressionLevel Optimal
# NB: Compress-Archive con un elenco di file li mette tutti nella radice dello zip. Per mantenere le cartelle
# conviene tar, incluso in Windows 10/11: tar -czf progetto.tar.gz --exclude=vendor --exclude=node_modules progetto

# eliminare i log più vecchi di 30 giorni (-WhatIf simula, toglierlo per eseguire davvero)
Get-ChildItem C:\logs -Recurse -Filter *.log | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item -WhatIf
```

```shell
# attività pianificata: esegue uno script ogni giorno alle 02:00 (serve PowerShell come amministratore)
$azione  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\script\backup.ps1'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName 'BackupNotturno' -Action $azione -Trigger $trigger -User 'SYSTEM' -RunLevel Highest
Get-ScheduledTask -TaskName 'BackupNotturno' | Get-ScheduledTaskInfo  # ultima e prossima esecuzione, esito
```

```shell
# eventi di errore del sistema nelle ultime 24 ore (Get-EventLog è deprecato, Get-WinEvent è il sostituto)
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2; StartTime = (Get-Date).AddDays(-1) } |
    Select-Object TimeCreated, ProviderName, Message -First 20
```
