# La shell

> **Laboratorio**: `./lab.sh 01`, poi `cd 01-shell`. Gli esempi di questa pagina sono stati eseguiti nel container (Ubuntu 24.04, bash 5.2).

Quale shell sto usando, quali sono disponibili, come cambiarla.

## Shell in uso
```bash
echo $0                  # bash (è la shell di default)
echo $SHELL              # /bin/bash è il suo PATH
grep root /etc/passwd    # tra le varie info mi dice anche la shell di default dell'utente (l'ultimo campo)
# root:x:0:0:root:/root:/bin/bash
```
`$0` è il nome della shell **in esecuzione**, `$SHELL` quella **di default** dell'utente: possono essere diversi (con `sh` aperta a mano, `$0` dice `sh` e `$SHELL` resta `/bin/bash`).

## Shell disponibili e cambio shell
```bash
sh                     # apre al volo la shell sh (esiste anche ksh)
cat /etc/shells        # elenco shell installate
# /bin/sh
# /usr/bin/sh
# /bin/bash
# /usr/bin/bash
# /bin/rbash
# /usr/bin/rbash
# /usr/bin/dash
# /usr/bin/tmux
chsh -s /bin/sh morro  # modifico la shell all'utente morro
```
> **NOTA**: `chsh -l` (elenco delle shell) esiste su Fedora e RHEL, **non** su Debian e Ubuntu: lì dà
> `chsh: invalid option -- 'l'`. Per l'elenco si legge `/etc/shells`. `/bin/sh` su Ubuntu è `dash`, non bash.

## Sottoshell e gerarchia dei processi
```bash
sudo su -    # esempio per scendere in profondità coi processi figli
bash         # scendo giù ancora di un livello
ps --forest  # vedo la gerarchia dei vari processi
exit         # risalgo di un livello
```

```bash
(ps;ps)      # per vedere che ci sono 2 PID annidati: le () aprono una sottoshell
{ ps;ps; }   # così c'è un solo PID, un'unica sequenza di processi nella shell corrente
```
Nell'output di `(ps;ps)` compare un **processo `bash` in più** (la sottoshell, PID 13 nella prova) con i due `ps` come figli; con `{ ps;ps; }` ci sono solo la
shell e i due `ps` uno dopo l'altro:
```
  PID TTY          TIME CMD
    1 ?        00:00:00 bash
   13 ?        00:00:00 bash          <- la sottoshell aperta da ( )
   15 ?        00:00:00 ps
```
> **NOTA**: con le `{}` serve uno spazio all'inizio e uno alla fine, e bisogna terminare con `;`.

## Sostituire la shell corrente
```bash
exec ping 8.8.8.8 -c 4  # esegue il comando e poi fa exit/logout dalla shell
```
`exec` **sostituisce** il processo della shell con il comando: finito `ping`, non c'è più una shell a cui tornare, e la sessione (o il terminale) si chiude.
Per provarlo senza perdere la shell: `(exec ping -c 2 8.8.8.8)`, dove a sparire è solo la sottoshell.

## Eseguire un comando dentro un altro
```bash
echo $(date)  # date è un comando: lo esegue e ne stampa l'output
echo `date`   # stessa cosa, ma è una sintassi vecchia: preferire $( )
# Tue Oct 6 05:03:54 UTC 2026
```

Vedi anche: [../05-scripting/01-basi-scripting.md](../05-scripting/01-basi-scripting.md) per i modi di lanciare uno script e quando viene aperta una sottoshell.
