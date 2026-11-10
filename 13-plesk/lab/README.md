# Laboratorio dell'area 13

Un server con **Plesk Obsidian 18.0** vero, descritto da [compose.yaml](compose.yaml): un solo container, l'immagine ufficiale `plesk/plesk:18.0`
(Ubuntu 24.04, systemd, nginx, apache, PHP 8.3 e 8.4, BIND, Postfix, Dovecot, MariaDB, fail2ban).

| Cosa | Dove |
|---|---|
| la shell (`root`, come un amministratore sul server) | si entra qui con `./lab.sh 13` |
| il pannello | dal PC su **https://localhost:8443** (certificato autofirmato: il browser avvisa) |
| i siti, la posta, il DNS | dentro il container: nginx `80`/`443`, Postfix `25`, Dovecot `143`/`993`, BIND `53`; non sono pubblicati sul PC |

## Avvio
Dalla radice della KB:
```bash
./lab.sh 13                                # la prima volta scarica l'immagine (3 GB); Plesk è pronto in circa 30 secondi
cd 02-cli-hosting && ./crea-esempio.sh     # il cliente mario e il sito esempio.test su cui lavorano 03 e 04
plesk login mario                          # il link di accesso al pannello come cliente (aggiungere :8443 dopo localhost)
plesk login                                # lo stesso come amministratore
```
All'uscita il container e i suoi dati vengono eliminati: si riparte da zero a ogni `./lab.sh 13`.

## Cosa c'è in `~/lab`
| Cartella | File pronti | Note |
|---|---|---|
| `02-cli-hosting/` | `crea-esempio.sh`, `info.php`, `cron.php`, `php-extra.ini`, `dump.sql` | gli esempi di [02-cli-hosting.md](../02-cli-hosting.md) e [03-manutenzione.md](../03-manutenzione.md); `crea-esempio.sh` crea il cliente `mario` e il sito `esempio.test` in un colpo |
| `04-pannello-cliente/` | `sito-statico/` (`index.html`, `chi-siamo.html`) | file da caricare con il File Manager del pannello |

## I limiti del laboratorio
- **Un dominio e un cliente**: la licenza dell'immagine ammette solo questi. Un secondo `customer --create` o `subscription --create` dà `There are no available resources of this type ... left`. Sottodomini, alias, caselle e database non contano.
- **Solo `en-US`**: il pannello è in inglese (`plesk bin server_pref --locales-list` ne mostra una).
- **Niente DNS pubblico e niente Let's Encrypt**: `esempio.test` non esiste su internet. Il sito si prova con `curl --resolve esempio.test:443:IP https://esempio.test/`, il DNS con `dig @127.0.0.1`. Il pannello segnala *"Domain is not resolvable"*: è atteso.
- **Immagine grande**: 3 GB sul disco e una partenza di mezzo minuto. L'autotest completo dura circa 5 minuti (la posta, ad esempio, arriva in una decina di secondi).
- **La licenza dell'immagine ha una scadenza** (`plesk bin keyinfo --list`, riga `lim_date`): un'immagine più nuova (`docker pull plesk/plesk:18.0`) ne porta una rinnovata.
- **Non in CI**: a differenza degli altri laboratori, quello di Plesk non fa parte dei controlli automatici di GitHub (immagine da 3 GB, licenza con scadenza, partenza lenta). Il controllo si lancia a mano con `autotest.sh`.

## Il controllo degli esempi: `autotest.sh`
```bash
./lab.sh 13 -- 'bash /kb/13-plesk/lab/autotest.sh'
```
Esegue in sequenza i comandi di [02](../02-cli-hosting.md) e [03](../03-manutenzione.md) (cliente, sito, sottodominio, DNS, posta, database, PHP, certificato, FTP, cron, backup e ripristino, `repair`, API) e controlla da terminale che ognuno abbia fatto quello che il `.md` dice. Esce con `0` e scrive `tutti i controlli sono ok` se è tutto giusto: serve a verificare le guide dopo un aggiornamento di Plesk. Il pannello del cliente ([04](../04-pannello-cliente.md)) non è coperto: si prova a mano dal browser.

## Se qualcosa non parte
- `docker compose -f 13-plesk/lab/compose.yaml logs` mostra l'avvio di systemd; il container deve diventare `healthy` (il pannello risponde e il web server di Plesk è attivo).
- Porta **8443** occupata sul PC: togliere la riga `ports` dal `compose.yaml` (il pannello resta raggiungibile dentro il container: `curl -k https://localhost:8443/`).
- `Failed to create /init.scope control group: Read-only file system`: manca il rimontaggio del cgroup (lo fa [avvia-systemd](avvia-systemd)): servono `cap_add: SYS_ADMIN`, `security_opt: apparmor:unconfined` e `cgroup: private`, come negli altri laboratori con systemd. Altri problemi: [../../zz-risorse/problemi-lab.md](../../zz-risorse/problemi-lab.md).

Torna all'[indice dell'area](../README.md)
