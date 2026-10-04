# Laboratorio dell'area 08

Una piccola rete con un PC e tre server, per provare ssh, tunnel, hardening, firewall e fail2ban senza
rischiare di chiudersi fuori da un server vero. La descrive [compose.yaml](compose.yaml):
```
client ---- rete "esterna" ---- produzione ---- rete "interna" ---- db-interno
                    \---------- staging
```

| Container | Cosa è |
|---|---|
| `client` | il "PC" su cui si lavora: `lab.sh` entra qui. Ha `ssh`, `scp`, `sftp`, `ssh-agent`, `gpg` |
| `produzione`, `staging` | server Ubuntu con systemd: `sshd` (attivato da `ssh.socket`), `ufw`, `fail2ban`, nginx che risponde `risposta da <nome>` |
| `db-interno` | UGUALE, ma solo sulla rete interna: dal client **non** si risolve nemmeno il nome, ci si arriva solo con `ProxyJump produzione` |

Sui tre server ci sono gli utenti `deploy` (password `deploy`) ed `edoardo` (password `edoardo`, con sudo),
creati da [server.sh](server.sh). I nomi dei server sono gli stessi alias usati nel `.md`.

Sul `client`, invece, [prepara.sh](prepara.sh) crea i file delle prove (`01-ssh/`, `02-firewall-e-hardening/`, `03-gpg/`) in `~/lab`;
`lab.sh` lo lancia da solo, e per ripartire da zero senza uscire: `bash /kb/08-remoto-e-sicurezza/lab/prepara.sh && cd ~/lab`.

## Avvio
Dalla radice della KB:
```bash
./lab.sh 08               # la prima volta costruisce l'immagine bashbash-systemd (qualche minuto)
ssh deploy@produzione     # password: deploy
```
All'uscita i quattro container vengono eliminati: chiavi, configurazioni e ban spariscono.

## 01-ssh
Il percorso tipico, dal client:
```bash
ssh-keygen -t ed25519 -C "edoardo@pc-ufficio"
ssh-copy-id deploy@produzione             # password deploy, poi mai più
cp 01-ssh/config-esempio ~/.ssh/config    # il config del .md, con gli host del laboratorio
ssh produzione                            # entra con la chiave
ssh-copy-id db-interno                    # passa da produzione grazie a ProxyJump
```
File pronti in `01-ssh/`: `config-esempio`, `multiplexing` (il blocco `ControlMaster` da aggiungere al config),
`file.txt`, `file.sql`, `cartella/`, `script_locale.sh` e `script.sh` (per `ssh produzione 'bash -s' < script.sh`).

Cose che nel laboratorio funzionano davvero:
- `scp` e `sftp` (su ogni server c'è `/var/log/app/app.log` da scaricare);
- `ssh -fNL 8080:127.0.0.1:80 produzione`, poi `curl localhost:8080` risponde `risposta da produzione`;
- `ssh -fNL 8081:db-interno:80 produzione`, poi `curl localhost:8081` risponde `risposta da db-interno`, una macchina
  che il client non vede;
- `ssh -R` (un `python3 -m http.server 8000` sul client, visto da `staging` sulla 9000) e `ssh -D 1080` con
  `curl --socks5-hostname localhost:1080 http://db-interno/`;
- `ssh-agent`, `ssh -A`, il multiplexing con `ssh -O check`.

Il ciclo `for h in web1 web2 db1` si prova con `produzione staging db-interno`. Per l'esempio del dump MySQL remoto
serve un server MySQL: c'è nel laboratorio dell'area 09.

## 02-firewall-e-hardening
In `02-firewall-e-hardening/` ci sono `10-hardening.conf`, `05-porta.conf` e `jail.local` del `.md`: si copiano sul
server con `scp` e si spostano con `sudo` (entrando come `edoardo`, che ha sudo).

> **CONSIGLIO**: fare le prove su `staging` e lasciare `produzione` per ssh. Se ci si chiude fuori da un server
> (è il bello del laboratorio: vedere cosa succede), da un altro terminale del PC si rientra con
> `docker exec -it lab-08-staging-1 bash`, oppure si esce e si rilancia `./lab.sh 08`.

Verificato nel laboratorio:
- `sshd -t`, `sshd -T | grep -Ei 'permitroot|passwordauth|allowusers'` e `systemctl reload ssh`;
- `ufw default deny incoming` + `ufw allow OpenSSH` + `ufw enable`: dal client la 80 aperta risponde, la 8080
  di apache2 va in timeout;
- il cambio porta con `ssh.socket` (Ubuntu 24.04): dopo `systemctl daemon-reload` e `restart ssh.socket`
  `ss -tlnp` mostra `systemd` in ascolto sulla 2222 e la 22 risponde `Connection refused`;
- fail2ban (già attivo con la jail `sshd`): sei `ssh nessuno@staging` sbagliati dal client e il client viene bannato.
  Sul server `fail2ban-client status sshd` mostra l'IP del client in `Banned IP list`.
- `journalctl -u ssh --since today | grep -c 'Failed password'`.

`unattended-upgrades` non è installato: `apt update && apt install unattended-upgrades` (serve internet).

## 03-gpg
File pronti: `backup.sql`, `note.txt`, `cartella/`, `contratto.pdf`, `release.tar.gz`. Sul client c'è anche
l'utente `utente` (password `utente`) per l'esempio dello scambio tra due utenti: `su - utente`.

Torna all'[indice dell'area](../README.md)
