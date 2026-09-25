# WSL e winget

**WSL** (Windows Subsystem for Linux) fa girare una vera distribuzione Linux dentro Windows.
**winget** è il gestore di pacchetti di Windows: l'equivalente di `apt`.

## winget
```shell
winget search php                           # cerca un pacchetto
winget show Git.Git                         # dettagli e versione disponibile
winget install Git.Git                      # installa (l'ID esatto evita ambiguità)
winget install --id Microsoft.PowerShell -e # -e: corrispondenza esatta dell'ID
winget list                                 # software installato (anche non installato con winget)
winget upgrade                              # cosa si può aggiornare
winget upgrade --all                        # aggiorna tutto
winget uninstall Git.Git
```

Ripristinare lo stesso software su un PC nuovo:
```shell
winget export -o pacchetti.json             # esporta l'elenco dei programmi installati
winget import -i pacchetti.json --accept-package-agreements --accept-source-agreements # li reinstalla tutti su un'altra macchina
```

Installazione di un ambiente di sviluppo in un colpo solo:
```shell
$pacchetti = "Git.Git", "Microsoft.PowerShell", "Microsoft.VisualStudioCode", "Docker.DockerDesktop", "koalaman.shellcheck", "jqlang.jq"
foreach ($p in $pacchetti) { winget install --id $p -e --silent --accept-package-agreements --accept-source-agreements }
```

## WSL: gestione dal lato Windows
Da PowerShell o cmd:
```shell
wsl --install                     # installa WSL e Ubuntu (serve un riavvio)
wsl --list --online               # distribuzioni installabili
wsl --install -d Debian           # installa una distribuzione specifica
wsl -l -v                         # distribuzioni installate, stato e versione WSL (1 o 2)
wsl                               # apre la distribuzione di default
wsl -d Debian                     # apre una distribuzione specifica
wsl -d Ubuntu -u root             # come root (utile se si è persa la password dell'utente: poi "passwd utente")
wsl --set-default Ubuntu          # distribuzione di default
wsl --shutdown                    # spegne tutte le distribuzioni e la VM (dopo aver cambiato .wslconfig, o per liberare RAM)
wsl --terminate Ubuntu            # spegne solo quella
wsl --update                      # aggiorna WSL
wsl --status
```

Backup e spostamento di una distribuzione:
```shell
wsl --export Ubuntu D:\backup\ubuntu.tar          # esporta l'intero filesystem della distribuzione
wsl --import Ubuntu-Test D:\wsl\test D:\backup\ubuntu.tar # la reimporta con un altro nome e in un'altra cartella (un clone per prove)
wsl --unregister Ubuntu-Test                      # ATTENZIONE: elimina la distribuzione e TUTTI i suoi file
```

## File tra Windows e Linux
```bash
cd /mnt/c/laragon/www             # da Linux, i dischi Windows sono in /mnt/c, /mnt/d...
explorer.exe .                    # apre la cartella Linux corrente in Esplora risorse
code .                            # apre VS Code collegato a WSL
```
Da Windows, i file Linux sono in `\\wsl$\Ubuntu\home\utente` (o `\\wsl.localhost\Ubuntu\...`).

> **PRESTAZIONI**: i file sotto `/mnt/c` passano attraverso un filesystem di rete e sono **molto** più lenti
> per le operazioni con tanti file piccoli (`composer install`, `npm install`, `git status` su repo grandi).
> Per i progetti su cui si lavora da Linux conviene tenerli nella home di Linux (`~/progetti`).

## Interoperabilità
Da Linux si possono lanciare eseguibili Windows (con `.exe`) e viceversa.
```bash
cmd.exe /c ver                                 # comando cmd da bash
powershell.exe -NoProfile -Command 'Get-Date'  # comando PowerShell da bash
ipconfig.exe | grep -a IPv4                    # output di un comando Windows filtrato con strumenti Linux
cat /etc/os-release | clip.exe                 # copia negli appunti di Windows
powershell.exe -NoProfile -Command Get-Clipboard # legge gli appunti di Windows
wslpath 'C:\laragon\www'                       # da percorso Windows a Linux: /mnt/c/laragon/www
wslpath -w ~/progetti                          # da Linux a Windows: \\wsl.localhost\Ubuntu\home\...
```
```shell
wsl ls -la                         # da PowerShell: esegue un comando Linux nella cartella corrente
wsl grep -rn "TODO" .              # grep sui file di Windows
Get-Content .\app.log | wsl awk '{print $1}' | wsl sort | wsl uniq -c  # strumenti Linux in una pipeline PowerShell
```

## Configurazione
File `/etc/wsl.conf` (dentro la distribuzione, vale per quella):
```ini
[boot]
# abilita systemd: systemctl, servizi, timer (default nelle installazioni recenti)
systemd=true

[user]
default=edoardo

[interop]
# non aggiungere il PATH di Windows a quello di Linux: which e il completamento con TAB diventano molto più veloci
appendWindowsPath=false
```

File `%UserProfile%\.wslconfig` (lato Windows, vale per la VM di tutte le distribuzioni):
```ini
[wsl2]
# limiti di risorse: senza, WSL può prendersi gran parte della RAM
memory=8GB
processors=4
swap=4GB

[experimental]
# restituisce a Windows la RAM che Linux non usa più
autoMemoryReclaim=gradual
```
Dopo ogni modifica serve `wsl --shutdown` perché abbia effetto.

## Problemi comuni
```bash
sed -i 's/\r$//' script.sh        # "bad interpreter: /bin/bash^M": lo script ha fine riga CRLF (vedi il .gitattributes del repo)
git config --global core.autocrlf input # evita il problema alla radice sui repo usati da Linux
sudo hwclock -s                   # orologio sbagliato dopo la sospensione del PC (errori TLS, "Release file is not valid yet" di apt)
```
> Se `git status` mostra tutti i file come modificati in un repo sotto `/mnt/c`, di solito sono permessi o
> fine riga: `git config core.fileMode false` ignora i cambi di permessi.
