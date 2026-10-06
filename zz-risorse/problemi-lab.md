# Problemi con i laboratori e come risolverli

Cosa fare quando `./lab.sh` non parte, o quando dentro il laboratorio qualcosa non va come nel `.md`. Quasi tutto viene da **Docker Desktop su Windows**, ma i comandi di diagnosi valgono anche su Linux e macOS.
Gli errori riportati sono quelli veri, incontrati lavorando sulla KB (Windows 11, Docker Desktop 29 con WSL2, Git Bash); dove un'idea non è stata provata c'è scritto.

## Prima di tutto: tre controlli
```bash
docker info --format '{{.ServerVersion}}'     # un numero (es. 29.8.0): Docker risponde. Altrimenti vedi "Docker non risponde"
docker ps -a --filter name=lab-               # container di un laboratorio rimasti da una prova precedente
docker compose -f 12-osservabilita/lab/compose.yaml ps      # stato dei servizi di un'area (health: healthy / starting / unhealthy)
```
Se un servizio non è `healthy`, il motivo sta nei suoi log: `docker compose -f 12-osservabilita/lab/compose.yaml logs NOME-SERVIZIO` (`lab.sh` stampa il comando completo quando i servizi non partono).

## Avvio
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `ERRORE: Docker non risponde: avvia Docker Desktop (o il demone)` | Docker non è in esecuzione (su Windows: Docker Desktop chiuso) | avviarlo e **aspettare** che dica *Engine running* (circa un minuto); `docker info` deve rispondere. Simulato con un `DOCKER_HOST` sbagliato: stesso messaggio |
| `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine` | lo stesso, visto da `docker` | idem |
| `./lab.sh` da PowerShell non parte | `lab.sh` è uno script bash | da PowerShell si lancia `bash lab.sh 02` (provato con il `bash` di Git for Windows); da Git Bash o WSL: `./lab.sh 02`. Da WSL serve l'integrazione di Docker Desktop con la distribuzione (**non provato**) |
| `ERRORE: nessun laboratorio per 'NN'` e l'elenco delle aree | l'area non ha un laboratorio, o il numero è sbagliato | si usa il numero (`02`) o il nome della cartella (`02-file-e-permessi`, `zz-esempi`); `11-container-e-automazione` non ha un `lab/` di area, i suoi laboratori sono nelle sottocartelle |
| il primo avvio dura minuti | costruisce l'immagine (`apt install`, download) e scarica le immagini dei servizi | normale la prima volta: circa 1-2 minuti per `bashbash`, di più per le aree con tanti servizi (09, 12). Poi parte in pochi secondi |
| `ERRORE: i servizi non sono partiti: docker compose -f "..." logs` | un servizio non è diventato `healthy` in tempo | eseguire il comando che stampa; di solito è una porta occupata (vedi sotto), un'immagine non scaricabile (rete) o poca memoria |

## Porte occupate
Dei laboratori lanciati da `lab.sh`, **solo l'area 12** pubblica porte sul PC (Prometheus 9090, Alertmanager 9093, Grafana 3000, Loki 3100, Tempo 3200, Jaeger 16686, Alloy 12345 e OTLP 4317/4318, Mailpit 8025): gli altri laboratori si vedono solo dall'interno.
Se una è già usata:
```
Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:8025 -> 127.0.0.1:0:
listen tcp 0.0.0.0:8025: bind: Di norma è consentito un solo utilizzo di ogni indirizzo di socket
```
(Il testo dopo `bind:` è in italiano perché lo scrive Windows; su Linux è `address already in use`.) Chi la occupa:
```powershell
Get-NetTCPConnection -LocalPort 8025 -State Listen | ForEach-Object { (Get-Process -Id $_.OwningProcess).ProcessName }
# mailpit      <- nel PC di prova era Laragon, che ha un suo Mailpit sulla stessa porta
```
Su Linux e macOS: `ss -ltnp | grep :8025` o `lsof -i :8025`. Si può fermare quel programma, oppure togliere la porta dal laboratorio: nel `compose.yaml` dell'area 12 si cancella la riga del servizio coinvolto
(`ports: ["8025:8025"]` di `mailpit`; le altre porte servono solo per aprire le interfacce dal browser), si lancia `./lab.sh 12` e a fine lavoro si torna indietro con `git checkout 12-osservabilita/lab/compose.yaml`.
Provato (con un file di override che azzerava le porte di Mailpit, equivalente a togliere la riga): tutti i servizi del laboratorio 12 diventano `healthy` e gli esempi dei `.md` funzionano (non si apre solo la sua interfaccia su `localhost:8025`).

## Git Bash: i percorsi che cambiano
Git Bash (MSYS) **riscrive** gli argomenti che sembrano percorsi Linux: `docker exec CONTAINER /opt/kafka/bin/kafka-topics.sh` diventa
```
exec: "C:/Program Files/Git/opt/kafka/bin/kafka-topics.sh": stat C:/Program Files/Git/opt/kafka/bin/kafka-topics.sh: no such file or directory
```
`lab.sh` lo disattiva da solo; per i comandi `docker` scritti a mano: `export MSYS_NO_PATHCONV=1` prima (vale per la sessione), oppure `//opt/kafka/bin/...` con la doppia barra (**non provato**). In PowerShell e in WSL il problema non c'è.
Il percorso del `compose.yaml` per `docker compose -f` va bene scritto relativo alla radice della KB (`09-strumenti/lab/compose.yaml`).

## Dentro il laboratorio
| Sintomo | Causa | Cosa fare |
|---|---|---|
| `/usr/bin/env: 'bash\r': No such file or directory` lanciando uno script | il file ha le fine riga di Windows (CRLF): il `\r` finisce nel nome dell'interprete | `sed -i 's/\r$//' script.sh` (`file script.sh` dice `with CRLF line terminators`). Gli `.sh` della KB sono forzati a LF dal `.gitattributes`: capita con un file salvato da un editor che usa CRLF |
| `command not found` per un comando del `.md` (`kcat`, `mongosh`, ...) | quel comando c'è solo in alcune immagini | `kcat`, `mongosh` e `amqp-*` sono solo nell'area 09 (immagine `bashbash-dati`); gli strumenti di un'area sono elencati nel README del suo `lab/` |
| `man ls` stampa solo `This system has been minimized` | immagine Ubuntu minimizzata, senza i manuali | l'immagine della KB li ha già (se compare, è una vecchia: `./lab.sh NN --build`) |
| i file del laboratorio non ci sono più dopo `exit` | è voluto: il container è usa-e-getta, e la KB in `/kb` è in **sola lettura** | `bash /kb/NN-area/lab/prepara.sh` ricrea i file senza uscire. Per tenere un risultato (uno script scritto, un file modificato) va copiato fuori **prima** di uscire, con `docker cp` da un altro terminale (**non provato**) |
| un comando funziona in un laboratorio e non in un altro | ogni area ha il suo container e i suoi servizi (host `mysql`, `api`, `rabbitmq`... esistono solo nell'area che li avvia) | il README del `lab/` dell'area elenca i servizi |
| `apt` o `curl` verso internet falliscono: `Temporary failure resolving ...` | la DNS del container non raggiunge internet (alcune reti aziendali o VPN bloccano le query verso server esterni) | `docker run --rm bashbash getent hosts example.com` deve rispondere; se no, si imposta la DNS di Docker Desktop (Settings > Docker Engine, `"dns": [...]`) o ci si collega fuori dalla VPN (**non provato**: nel PC di prova funzionava, ma un problema simile era stato visto con un DNS esterno bloccato) |

## Il laboratorio non parte dopo una modifica
`lab.sh` costruisce l'immagine `bashbash` solo se **non esiste**. Dopo aver cambiato il `Dockerfile` (o un `git pull` che lo cambia) va ricostruita:
```bash
./lab.sh 02 --build                      # ricostruisce bashbash e, dove serve, bashbash-systemd o bashbash-dati
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep '^bashbash'     # le immagini della KB e la loro dimensione
```
Dimensioni oggi: `bashbash` 845 MB, `bashbash-systemd` 916 MB, `bashbash-dati` 1,32 GB, `bashbash-osservabilita` 1,6 GB.

## Container e volumi rimasti
All'uscita `lab.sh` spegne tutto (`compose down -v`). Se il terminale si è chiuso di colpo, o Docker si è fermato, restano container e volumi: i progetti si chiamano `lab-NN`.
```bash
docker ps -a --filter name=lab-                                   # container rimasti
docker compose -f 09-strumenti/lab/compose.yaml down -v --remove-orphans     # spegne e cancella container, rete e volumi di quell'area
```
Un laboratorio che parte sopra uno rimasto a metà può comportarsi in modo strano (nomi già in uso, dati vecchi nei volumi): prima `down -v`, poi `./lab.sh NN`.

## Spazio su disco e memoria
Le immagini della KB sono grandi, e ogni modifica al `Dockerfile` lascia livelli vecchi:
```bash
docker system df                          # quanto occupano immagini, container, volumi e cache di build
docker image prune                        # toglie le immagini senza nome (quelle sostituite da una ricostruzione)
docker builder prune                      # svuota la cache di build (la prossima costruzione riparte da zero)
```
Nel PC di prova, dopo aver costruito tutte le aree più volte: **41 GB** di immagini (31 GB recuperabili) e **22 GB** di cache di build. Docker Desktop su Windows usa WSL2, che di default prende fino a metà della RAM del PC;
per limitarla si crea `%UserProfile%\.wslconfig` con `[wsl2]` e `memory=8GB`, poi `wsl --shutdown` (**non provato**).
Quanta memoria serve: l'area 09 con RabbitMQ, Kafka e MongoDB usa circa 700 MB in più degli altri laboratori (Kafka ~400 MB), la 12 avvia dieci servizi, la 07 un controller di dominio Samba.

## Errori che passano da soli
- **`dc1 hook exited with status 100`** (area 07): `apt` ha perso la rete durante l'installazione di Samba. Lo script ripete l'installazione fino a 4 volte; se compare lo stesso, basta rilanciare `./lab.sh 07`.
- **`unable to apply cgroup configuration: failed to write ... cgroup.procs: device or resource busy`** subito dopo aver (ri)avviato Docker Desktop: il motore non è ancora stabile. Si spegne quello che resta
  (`docker compose -f 06-sistema/lab/compose.yaml down -v --remove-orphans`) e si rilancia `./lab.sh`: la seconda volta è partito.
- **I laboratori con systemd** (06, 07, 08, 10, 12) su un **Linux** con systemd uscivano con `exited (255)`: due systemd che si contendono lo stesso `/sys/fs/cgroup`. Il `compose.yaml` usa un cgroup privato (`cgroup: private`), e funziona; la storia è in
  [la guida a GitHub Actions](../11-container-e-automazione/13-github-actions/github-actions.md). Su Docker Desktop non succedeva.
- **Prima richiesta lenta** di un servizio (Kafka, Samba AD, Grafana): i servizi hanno un controllo di salute (`healthcheck`) e `lab.sh` aspetta che tutti siano `healthy`; se l'attesa sembra lunga, `docker compose ... ps` mostra quale è ancora `starting`.

## Se è un problema della KB
Un esempio del `.md` che non dà il risultato scritto, o un laboratorio che non parte neanche in una macchina pulita, è un difetto della KB: vale la pena segnalarlo con il comando eseguito, l'output e il sistema
(`docker version`, Windows/Linux/macOS). La CI del repository ([kb.yml](../.github/workflows/kb.yml)) avvia ogni laboratorio a ogni pull request: se lì passa e da te no, il problema è quasi sempre nell'ambiente (Docker, porte, rete, memoria).

Torna all'[indice di zz-risorse](README.md)
