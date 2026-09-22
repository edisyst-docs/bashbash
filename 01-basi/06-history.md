# History

Lo storico dei comandi lanciati e come richiamarli senza riscriverli.

## Consultare la history
```bash
history            # storico di tutti i comandi lanciati
cat  .bash_history # viene letto questo file della mia home
history 5          # gli ultimi 5 comandi lanciati
history -c         # cancella tutta la history
```

## Richiamare un comando
```bash
!101    # esegue il comando con ID=101 della history
!!      # esegue l'ultimo comando della history
sudo !! # esegue l'ultimo comando come SUDO (TRUCCHETTO UTILE)
!?at?   # esegue l'ultimo comando della history contenente 'at'. Es: date
!apt    # esegue l'ultimo comando della history che inizia con 'apt'. Es: apt-get update
```

## Riusare gli argomenti del comando precedente
```bash
rm !$  # !$ è l'argomento dell'ultimo comando digitato, quindi rimuove il file digitato nel comando precedente (es: touch file nuovo)
```

## Rieseguire più comandi insieme
```bash
fc 92 94  # apre nano/vim scrivendo in un file temporaneo i comandi 92-93-94. All'uscita li esegue tutti
```

Vedi anche: [02-shortcut.md](02-shortcut.md) per `CTRL+R`, `CTRL+P` e `CTRL+N`.
