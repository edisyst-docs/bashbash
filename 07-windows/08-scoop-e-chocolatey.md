# Scoop e Chocolatey

[05-wsl-e-winget.md](05-wsl-e-winget.md) ha `winget`, il gestore di pacchetti di Microsoft. Ce ne sono altri due molto diffusi, con idee diverse:

| | winget | **Scoop** | **Chocolatey** |
|---|---|---|---|
| installazione | già presente in Windows 11 | un comando da PowerShell, **senza** amministratore | un comando da PowerShell **come amministratore** |
| dove installa | dove decide l'installer del programma (`Program Files`, `AppData`) | `~\scoop` (la tua cartella), niente installer: **scompatta** archivi | `C:\ProgramData\chocolatey` e gli installer dei programmi |
| permessi | quello che chiede ogni installer (spesso UAC) | utente normale; con `--global` serve admin | amministratore |
| pacchetti | programmi con installer, anche con interfaccia grafica | soprattutto strumenti **da riga di comando** e programmi portabili | enorme catalogo, anche pacchetti aziendali, gratuiti e a pagamento |
| più versioni, riporto indietro | limitato | sì: le versioni restano in `apps\NOME\VERSIONE`, `scoop reset` | `choco install --version`, `choco pin` |
| quando | un programma normale | strumenti di sviluppo (`jq`, `ripgrep`, `fzf`, `git`), PC dove non si è amministratore | automazione di PC aziendali, script di provisioning |

`winget` e Scoop sono stati provati su Windows 11 (winget 1.29, Scoop v0.6.0) **senza amministratore**. **Chocolatey non è stato provato**: richiede un terminale elevato, che qui non c'era;
la sua sezione è la sintassi standard e va verificata.

## Scoop
Il modo ufficiale per installarlo è un comando da PowerShell normale (non amministratore):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser       # una volta sola: permette gli script locali
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression            # scarica ed esegue lo script dell'installatore
scoop --version                                                            # Current Scoop version: v0.6.0
```
Scoop è fatto di **script PowerShell** e **bucket**: un bucket è un repository Git di *manifest* (un JSON per programma: dove scaricarlo, l'hash, quali `.exe` esporre). Quello base è `main`.
Negli esempi sotto, Scoop è stato clonato in una cartella di prova con `git clone` e usato da lì, senza l'installatore.

> **Scoop modifica il PATH dell'utente**: alla prima `scoop install` aggiunge `~\scoop\shims` alla variabile `PATH` utente (`Adding ...\shims to your path.`), in modo **permanente**. È voluto,
> e la modifica sta nel registro dell'utente (`HKCU\Environment`), non serve amministratore. Il **PATH è letto all'avvio di un terminale**: dopo l'installazione di un programma, un terminale già aperto non lo vede.

### Cercare, installare, elencare
```powershell
scoop search ripgrep
# Results from local buckets...
# Name    Version Source Binaries
# rga     0.10.9  main   ripgrep-all
# ripgrep 15.2.0  main
scoop info jq
# Name        : jq
# Description : Lightweight and flexible command-line JSON processor
# Version     : 1.8.2
# Source      : main
# Binaries    : jq.exe
scoop install jq ripgrep fzf
# Downloading https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-windows-amd64.exe#/jq.exe (1.011,0 KB)...
# Checking hash of jq-windows-amd64.exe ... OK.
# Linking ~\scoop\apps\jq\current => ~\scoop\apps\jq\1.8.2
# Creating shim for 'jq'.
# 'jq' (1.8.2) was installed successfully!
scoop list
# Name    Version Source Updated
# fzf     0.74.4  main   2026-10-05 17:15:52
# jq      1.8.2   main   2026-10-05 17:15:11
# ripgrep 15.2.0  main   2026-10-05 17:15:51
rg --version | Select -First 1        # ripgrep 15.2.0 (rev e89fff89ac)
```
`scoop search` cerca nei bucket **già scaricati** (in locale), non su internet. Ogni programma ha l'**hash** del file: `Checking hash ... OK` è il controllo di integrità.

### Dove va a finire
```
~\scoop\
  apps\jq\1.8.2\jq.exe        <- il programma vero, una cartella per versione
  apps\jq\current             <- un collegamento (junction) alla versione attiva
  shims\jq.exe, jq.shim      <- il "finto" eseguibile nel PATH: un piccolo programma che lancia quello in apps\...
  buckets\main\              <- i manifest
  cache\                     <- gli archivi scaricati
```
Tutto sta in una cartella: disinstallare Scoop è cancellare quella cartella (più la riga nel `PATH`). Gli **shim** sono il motivo per cui nel `PATH` c'è una sola cartella, e non una per programma:
`(Get-Command rg).Source` dà `...\scoop\shims\rg.exe`.

### Disinstallare, versioni, congelare
```powershell
scoop uninstall fzf               # Uninstalling 'fzf' (0.74.4). ... Removing shim 'fzf.exe'.
scoop hold jq                     # jq is now held and can not be updated anymore.   (scoop list: Info = Held package)
scoop unhold jq                   # jq is no longer held and can be updated again.
scoop cleanup jq                  # toglie le versioni vecchie (jq is already clean: ce n'è una sola)
scoop cache show                  # Total: 3 files, 5,1 MB  - gli archivi scaricati
scoop reset jq@1.8.2              # rimette attiva una versione già installata: ricrea collegamento e shim
```
- `scoop update` aggiorna Scoop e i bucket; `scoop update jq` o `scoop update *` aggiorna i programmi (nelle prove qui non è stato eseguito: aggiorna anche Scoop stesso). `scoop status` dice cosa è aggiornabile; con tutto a posto: `Scoop is up to date. Everything is ok!`
- `scoop install jq@1.7.1` (versione precisa) **non ha funzionato** nelle prove: `Could not find manifest for 'jq@1.7.1'`. Una versione si può installare solo se il bucket la ha ancora (o se l'autoaggiornamento
  riesce a ricavarla: qui è fallito sull'hash di un file per un'altra architettura). Per le vecchie versioni di alcuni programmi esiste il bucket `versions`

### Bucket
```powershell
scoop bucket list
# Name Source                                 Updated             Manifests
# main https://github.com/ScoopInstaller/Main 05/10/2026 17:10:21      1667
scoop bucket known                # main, extras, versions, nirsoft, sysinternals, php, nerd-fonts, nonportable, java, games
scoop bucket add extras           # Checking repo... OK. The extras bucket was added successfully.
scoop bucket add mio https://github.com/utente/scoop-bucket     # un bucket di terzi, o il proprio
```
`extras` ha i programmi con interfaccia grafica (browser, editor); `versions` le versioni alternative (`php`, `nodejs-lts`); `nirsoft` e `sysinternals` gli strumenti omonimi. Un bucket è codice di terzi
che si scarica ed esegue: si aggiungono solo bucket fidati.

### Riprodurre l'installazione su un altro PC
```powershell
scoop export > scoop.json          # buckets e programmi con versione, in JSON
scoop import scoop.json            # su un PC nuovo (con Scoop installato): li reinstalla tutti
```
`scoop export` stampa un JSON con `"buckets": [...]` e `"apps": [{ "Name": "jq", "Version": "1.8.2", "Source": "main" ...}]` (come `winget export`).
`scoop import` non è stato provato.

## Chocolatey (non provato)
```powershell
# PowerShell COME AMMINISTRATORE
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco --version
```
```powershell
choco search git                       # cerca nel catalogo
choco install git -y                   # -y: senza chiedere conferma (serve amministratore)
choco install nodejs --version=22.11.0 # una versione precisa
choco list                             # installati (con --local-only nelle versioni vecchie)
choco outdated                         # cosa si può aggiornare
choco upgrade all -y                   # aggiorna tutto
choco pin add -n=nodejs                # non aggiornare più nodejs
choco uninstall git -y
```
I pacchetti sono **script PowerShell** (`chocolateyInstall.ps1`) che scaricano ed eseguono gli installer ufficiali: più compatibile (anche con programmi che richiedono un installer vero e permessi di
sistema), ma ogni `choco install` esegue codice con i **privilegi di amministratore**. Per un PC aziendale esiste un repository **interno**: `choco source add -n=interno -s https://nexus.azienda/...`.
Un elenco di pacchetti da riprodurre si scrive in un file `packages.config` (`choco install packages.config -y`).

## Quale usare
- un PC personale dove si installa software normale: **winget**
- strumenti da terminale (`jq`, `ripgrep`, `fzf`, `bat`, `git`), un PC dove non si è amministratore, o più versioni di uno strumento: **Scoop**
- un parco di PC aziendali da configurare con script, o un programma che esiste solo in Chocolatey: **Chocolatey**

Si possono usare insieme: ognuno tiene i propri programmi e `winget list` mostra anche quelli installati da altri. Dentro **WSL** si usa invece `apt` ([05-wsl-e-winget.md](05-wsl-e-winget.md)).

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `scoop : non è riconosciuto come cmdlet` subito dopo l'installazione | il terminale ha il `PATH` vecchio | aprirne uno nuovo |
| `running scripts is disabled on this system` | ExecutionPolicy | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| `Could not find manifest for 'nome@versione'` | il bucket non ha quella versione | `scoop search nome`, il bucket `versions`, o un'altra versione |
| `Could not install` per un programma che dipende da un altro (`vcredist`, `7zip`) | dipendenza in un altro bucket | `scoop bucket add extras` |
| un programma installato con Scoop non compare nei "Programmi e funzionalità" | è così: Scoop non registra gli installer | `scoop list` |
| `choco` dice `Access denied` o `Chocolatey detected you are not running from an elevated command shell` | non è un terminale amministratore | riaprire il terminale come amministratore |
| due versioni dello stesso comando | un programma è sia in `winget` sia in Scoop | `where.exe rg` (CMD) o `Get-Command rg -All` (PowerShell): il primo del `PATH` vince |
| il download fallisce | rete aziendale o proxy | `scoop config proxy server:porta` (non provato) |

Torna all'[indice dell'area](README.md)
