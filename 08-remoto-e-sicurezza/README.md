# 08 - Remoto e sicurezza

Collegarsi ai server e metterli in sicurezza.

| # | File | Contenuto |
|---|---|---|
| 01 | [ssh](01-ssh.md) | Chiavi, `ssh-agent`, `~/.ssh/config`, `ProxyJump`, `scp`/`sftp`, tunnel `-L`/`-R`/`-D`, multiplexing, PuTTYgen e WinSCP |
| 02 | [firewall e hardening](02-firewall-e-hardening.md) | `ufw`, hardening di sshd, `fail2ban`, `unattended-upgrades`, checklist per un server nuovo |
| 03 | [gpg](03-gpg.md) | Cifratura simmetrica e con chiavi, scambio di chiavi pubbliche, firme |
| 04 | [vpn wireguard](04-vpn-wireguard.md) | Peer, chiavi, `wg-quick`, split e full tunnel, `AllowedIPs`, NAT e `ufw route`, più client, revoca, systemd |
| 05 | [sicurezza del sistema](05-sicurezza-sistema.md) | AppArmor e SELinux, `auditd` (`auditctl`, `ausearch`, `aureport`), `lynis`, ClamAV |
| 06 | [esercizi](06-esercizi.md) | 16 esercizi: chiavi e `config` ssh, comandi remoti, tunnel `-L`/`-D`, `ufw` e fail2ban su server veri, GPG senza tastiera, WireGuard: `verifica.sh` guarda il risultato |
| 07 | [scenari guidati](07-scenari.md) | 8 guasti veri da diagnosticare (chiave, `config`, chiave del server, permessi sul server, `ProxyJump`, firewall, ban di `fail2ban`, GPG): `scenari.sh controlla` guarda se il sintomo è sparito |

**Laboratorio**: `./lab.sh 08` dalla radice della KB avvia un PC e tre server (`produzione`, `staging` e
`db-interno`, raggiungibile solo via `ProxyJump`) con sshd, ufw e fail2ban veri. Dettagli in [lab/](lab/).

Area precedente: [../07-windows/](../07-windows/) · Prossima: [../09-strumenti/](../09-strumenti/) · Torna all'[indice](../README.md)
