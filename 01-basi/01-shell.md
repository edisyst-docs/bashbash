# La shell

Quale shell sto usando, quali sono disponibili, come cambiarla.

## Shell in uso
```bash
echo $0                  # bash (è la shell di default)
echo $SHELL              # /bin/bash è il suo PATH
grep edoardo /etc/passwd # tra le varie info mi dice anche la shell di default di edoardo
```

## Shell disponibili e cambio shell
```bash
sh                     # apre al volo la shell sh (esiste anche ksh)
cat /etc/shells        # elenco shell installate
chsh -l                # elenco shell, permette anche di cambiare la propria shell
chsh -s /bin/sh morro  # modifico la shell all'utente morro
```

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
> **NOTA**: con le `{}` serve uno spazio all'inizio e uno alla fine, e bisogna terminare con `;`.

## Sostituire la shell corrente
```bash
exec ping 8.8.8.8 -c 4  # esegue il comando e poi fa exit/logout dalla shell
```

## Eseguire un comando dentro un altro
```bash
echo $(date)  # date è un comando: lo esegue e ne stampa l'output
echo `date`   # stessa cosa, ma è una sintassi vecchia: preferire $( )
```

Vedi anche: [../05-scripting/01-basi-scripting.md](../05-scripting/01-basi-scripting.md) per i modi di lanciare uno script e quando viene aperta una sottoshell.
