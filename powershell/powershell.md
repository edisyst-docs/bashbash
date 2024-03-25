## Forse questi 3 sono di Networking

```powershell
net start # mi dice i servizi attivi su Windows
net stop Temi # stoppa il servizio Temi
net start Temi # lo riavvia
```

```powershell
Get-Service # mostra tutti i servizi
Get-Service | Where-Object {$_.Status -eq "running"} # mostra solo i servizi attivi
Stop-Service Themes # stoppa il servizio Temi
Get-Service | Where-Object {$_.name -eq "Themes"} # se lo cerco è Stopped
Start-Service Themes # lo riavvia
```

```powershell
Get-Alias # lista degli alias
Get-Alias -Definition Get-ChildItem # è l'alias di dir,ls
Get-Alias | Where-Object {$_.name -clike "dir"} # trova l'alias di dir
Get-Alias | Where-Object {$_.name -clike "cd"} # alias di cd = Set-Location

Set-Alias listonebalasso Get-ChildItem # creo un alias identico a dir,ls
```

```powershell
Get-Process # mostra i processi attivi
Get-Process | sort ProcessName
Get-Process | Export-Clixml C:\laragon\www\lista-proc.xml # esporta la lista XML

# posso avviare dei servizi
# notepad
# calc
# code # VS code

Get-Process | Export-Clixml C:\laragon\www\lista-proc1.xml # esporta un'altra lista 
```


```powershell
Compare-Object -ReferenceObject (Import-Clixml C:\laragon\www\lista-processi.xml) -DifferenceObject (Import-Clixml C:\laragon\www\lista-processi1.xml) # Compare-Object=diff
Compare-Object -ReferenceObject (Import-Clixml C:\laragon\www\lista-processi.xml) -DifferenceObject (Import-Clixml C:\laragon\www\lista-processi1.xml) -Property name

Get-Module -ListAvailable # lista moduli attivi

Get-EventLog -LogName system -Newest 50 # devo spcificarglieli altrimenti mostra un motto di righe
  
Get-EventLog -LogName system -Newest 50 | gm # mi dice metodi e property che potrei voler usare per un sort
```



## Aggiungi la roba vista a casa


```powershell
Get-NetIPConfiguration # info sulla ethernet in uso: modello, dominio, IPv4, DNS
Get-NetIPAddress # tutti gli IP configurati sulla macchina
Test-NetConnection keep.google.com # una sorta di ping/telnet, mi risolve anche il DNS
Test-NetConnection keep.google.com - Port "80" # ping con una specifica RemotePort
Test-NetConnection keep.google.com -CommonTCPPort HTTP # capisce qual è la porta utilizzata
Test-NetConnection keep.google.com -TraceRoute # mi dà tutta la rotta percorsa x arrivare al server finale
```

```powershell
Resolve-DnsName keep.google.com # mi risolve solo il DNS
Get-NetRoute -Protocol Local -DestinationPrefix 192.168* # mostra le rotte degli indirizzi IP
Get-NetTCPConnection # elenca le porte in ascolto, connesse, chiuse, ecc

slmgr /dlv # versione Window, eccetera

Get-Help Copy-Item # help per esempio di "copia file"
```
