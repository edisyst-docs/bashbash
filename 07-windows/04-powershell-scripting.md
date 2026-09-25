# PowerShell come linguaggio di scripting

[02-powershell.md](02-powershell.md) raccoglie i cmdlet. Qui c'è il linguaggio: variabili, condizioni,
cicli, funzioni, errori. I file di script hanno estensione `.ps1`.

> **Due versioni**: **Windows PowerShell 5.1** (`powershell.exe`, preinstallata, non più sviluppata) e
> **PowerShell 7** (`pwsh.exe`, da installare con `winget install Microsoft.PowerShell`, multipiattaforma).
> Tutto ciò che segue funziona in entrambe, salvo dove è indicato "solo 7".

## Eseguire uno script
```shell
Get-ExecutionPolicy -List                            # criterio di esecuzione per ogni ambito
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned  # permette gli script locali, richiede la firma per quelli scaricati
.\script.ps1                                         # il .\ è obbligatorio anche nella cartella corrente (come ./ in bash)
powershell -NoProfile -ExecutionPolicy Bypass -File .\script.ps1 # da cmd, da un .bat o da un'attività pianificata
Unblock-File .\script.ps1                            # rimuove il blocco "scaricato da internet"
```

## Variabili e tipi
```shell
$nome = "Mario"                  # le variabili iniziano sempre con $, nessun problema con gli spazi attorno all'uguale
[int]$eta = 42                   # tipo esplicito: assegnare "ciao" dà errore
$oggi = Get-Date                 # le variabili contengono OGGETTI, non testo
$oggi.Year                       # quindi hanno proprietà...
$oggi.AddDays(7)                 # ...e metodi
$nome.GetType().Name             # String
$env:PATH                        # variabile d'ambiente (in bash: $PATH)
$env:APP_ENV = "local"           # la imposta per la sessione e i processi figli
```

Stringhe:
```shell
'Ciao $nome'                     # apici singoli: letterale, come in bash
"Ciao $nome"                     # doppi: espande le variabili
"Anno: $($oggi.Year)"            # $( ) per espressioni e proprietà dentro una stringa
"riga1`nriga2`ttab"              # il carattere di escape è il backtick ` (non il backslash)
"{0} ha {1} anni" -f $nome, $eta # formattazione (come printf)
$testo = @"
Here-string multiriga: espande $nome
"@                               # la chiusura "@ deve stare a inizio riga
$nome.ToUpper(); $nome.Replace("M","P"); $nome.Length; "a,b,c".Split(",")
```

Array e hashtable:
```shell
$lista = @("uno", "due", "tre")  # array
$lista += "quattro"              # aggiunge (crea un nuovo array: lento dentro cicli grandi)
$lista[0]; $lista[-1]; $lista.Count
$conf = @{ Server = "10.0.0.5"; Porta = 3306 }  # hashtable (come gli array associativi di bash)
$conf.Server; $conf["Porta"]
$conf.Keys
$conf.ContainsKey("Server")
$obj = [pscustomobject]@{ Nome = "Mario"; Eta = 42 } # oggetto: si stampa come tabella ed esporta in CSV/JSON
```

## Operatori di confronto
`==`, `<`, `>` NON si usano per confrontare (`>` è la redirezione, come in bash).
```shell
-eq -ne -gt -lt -ge -le          # uguale, diverso, maggiore, minore... (come test in bash)
"Ciao" -eq "ciao"                # True: di default i confronti NON distinguono maiuscole/minuscole
"Ciao" -ceq "ciao"               # False: la c iniziale li rende case sensitive
"report.pdf" -like "*.pdf"       # wildcard
"ordine-2026" -match '\d{4}'     # regex; il match finisce in $Matches[0]
"a","b","c" -contains "b"        # l'array contiene l'elemento?
"b" -in "a","b","c"              # UGUALE, invertito
-and -or -not                    # logici (anche ! al posto di -not)
```

## Condizioni
```shell
if ($eta -ge 18) {
    "maggiorenne"
} elseif ($eta -ge 14) {
    "adolescente"
} else {
    "bambino"
}

if (Test-Path "C:\laragon\www\app\.env") { "il .env esiste" }  # come [ -e file ] in bash
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { "git non installato" } # come command -v

switch -Wildcard ($file) {       # come case in bash. -Regex per usare le regex
    "*.jpg" { "immagine" }
    "*.log" { "log" }
    default { "altro" }
}
```

## Cicli
```shell
foreach ($f in Get-ChildItem *.log) { "$($f.Name): $($f.Length) byte" }  # foreach su una collezione
Get-ChildItem *.log | ForEach-Object { $_.Name }                          # UGUALE in pipeline: $_ è l'elemento corrente
for ($i = 0; $i -lt 5; $i++) { $i }                                       # stile C
while ($true) { if ((Get-Random -Max 10) -eq 7) { break } }               # break e continue come in bash
1..10 | Where-Object { $_ % 2 -eq 0 }                                     # 1..10 è un range (come {1..10})
1..5 | ForEach-Object -Parallel { Start-Sleep 1; $_ } -ThrottleLimit 5    # SOLO 7: in parallelo
```

## Funzioni
```shell
function Get-Saluto {
    param(
        [Parameter(Mandatory)]         # obbligatorio: se manca lo chiede
        [string]$Nome,
        [ValidateSet("it", "en")]      # accetta solo questi valori (e il TAB li completa)
        [string]$Lingua = "it",        # con valore di default
        [switch]$Maiuscolo             # flag: presente = $true
    )
    $s = if ($Lingua -eq "it") { "Ciao $Nome" } else { "Hello $Nome" }
    if ($Maiuscolo) { $s = $s.ToUpper() }
    return $s                          # in realtà la funzione restituisce TUTTO l'output non catturato, non solo il return
}
Get-Saluto -Nome Mario -Lingua en -Maiuscolo
Get-Saluto Mario                       # i parametri si possono passare anche per posizione
```
> **ATTENZIONE**: ogni valore non assegnato né scartato dentro una funzione finisce nel risultato.
> Per scartare l'output di un comando: `$null = comando` oppure `comando | Out-Null`.

Lo stesso `param()` in cima a un file `.ps1` definisce i parametri dello script:
```shell
# deploy.ps1
param(
    [Parameter(Mandatory)][ValidateSet("staging","produzione")][string]$Ambiente,
    [switch]$DryRun
)
"Deploy su $Ambiente (dry run: $DryRun)"
```
```shell
.\deploy.ps1 -Ambiente staging -DryRun
Get-Help .\deploy.ps1                  # mostra i parametri
```

## Gestione degli errori
```shell
$ErrorActionPreference = "Stop"        # come "set -e": ogni errore diventa bloccante (di default molti errori sono solo avvisi)
Set-StrictMode -Version Latest         # come "set -u": errore sulle variabili non definite

try {
    Get-Content "C:\non\esiste.txt" -ErrorAction Stop  # -ErrorAction Stop rende bloccante l'errore di questo solo comando
}
catch [System.Management.Automation.ItemNotFoundException] {
    Write-Warning "file non trovato"
}
catch {
    Write-Error "errore imprevisto: $($_.Exception.Message)"  # in catch, $_ è l'errore
    exit 1
}
finally {
    "eseguito sempre"                  # come trap EXIT in bash
}
```

I programmi esterni (git, php, composer) NON generano eccezioni: si controlla `$LASTEXITCODE`.
```shell
git pull
if ($LASTEXITCODE -ne 0) { throw "git pull fallito" }  # $LASTEXITCODE è l'equivalente di $? di bash per gli eseguibili
git pull && composer install           # SOLO 7: && e || come in bash. In 5.1 danno errore di sintassi
```

## Output e stream
```shell
Write-Output "dato"                    # va nella pipeline (è il default: basta scrivere "dato")
Write-Host "messaggio" -ForegroundColor Green  # solo a video, NON nella pipeline: per i messaggi all'utente
Write-Warning "attenzione"; Write-Error "errore"; Write-Verbose "dettaglio"  # stream separati (visibili con -Verbose)
comando *> tutto.log                   # redirige tutti gli stream (come &> in bash)
comando 2> errori.log                  # solo gli errori
```

## Splatting: parametri da una hashtable
Evita righe lunghissime; la @ al posto del $ "espande" la hashtable in parametri.
```shell
$parametri = @{
    Path        = "C:\logs"
    Filter      = "*.log"
    Recurse     = $true
    ErrorAction = "SilentlyContinue"
}
Get-ChildItem @parametri
```

## Esempio completo: pulizia log con report
```shell
param(
    [string]$Cartella = "C:\laragon\www\app\storage\logs",
    [int]$Giorni = 14,
    [switch]$WhatIf                      # simula soltanto
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Cartella)) { throw "Cartella $Cartella inesistente" }

$limite = (Get-Date).AddDays(-$Giorni)
$vecchi = Get-ChildItem $Cartella -Filter *.log -File | Where-Object LastWriteTime -lt $limite
$mb = [math]::Round(($vecchi | Measure-Object Length -Sum).Sum / 1MB, 1)

Write-Host ("{0} file più vecchi di {1} giorni, {2} MB" -f $vecchi.Count, $Giorni, $mb)
$vecchi | Remove-Item -WhatIf:$WhatIf    # passa lo switch così com'è: con -WhatIf simula

$vecchi | Select-Object Name, LastWriteTime, @{ n = "KB"; e = { [math]::Round($_.Length / 1KB) } } |
    Export-Csv "$env:TEMP\pulizia_$(Get-Date -Format yyyy-MM-dd).csv" -NoTypeInformation -Delimiter ";"  # report apribile con Excel
```

## JSON e CSV
```shell
$dati = Get-Content .\composer.json -Raw | ConvertFrom-Json  # -Raw legge il file come stringa unica
$dati.require                                                # navigazione come un oggetto
$dati | ConvertTo-Json -Depth 5 | Set-Content out.json       # -Depth: il default (2) tronca gli oggetti annidati
Import-Csv .\utenti.csv -Delimiter ";" | Where-Object Ruolo -eq "admin"
Invoke-RestMethod https://jsonplaceholder.typicode.com/users | Select-Object -First 3 name, email # API: il JSON diventa subito oggetti
```
