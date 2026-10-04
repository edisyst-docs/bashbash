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

## Esempi pratici
```bash
^stauts^status  # riesegue l'ultimo comando sostituendo "stauts" con "status" (correggere un typo al volo)
!!:s/dev/prod/  # UGUALE ma con la sintassi dei modificatori: sostituisce la prima occorrenza
!!:gs/dev/prod/ # UGUALE ma sostituisce tutte le occorrenze

cp config.yml /etc/app/
vim !$          # !$ = ultimo argomento del comando precedente => apre /etc/app/
echo !*         # !* = tutti gli argomenti del comando precedente
echo !:1        # !:1 = solo il primo argomento del comando precedente
echo !cp:2      # secondo argomento dell'ultimo comando che iniziava con "cp"
!cp:p           # :p stampa il comando senza eseguirlo: utile per controllare prima di lanciare
```

Da mettere nel `~/.bashrc` per una history più utile:
```bash
HISTSIZE=10000                        # comandi tenuti in memoria nella sessione
HISTFILESIZE=20000                    # comandi tenuti nel file ~/.bash_history
HISTCONTROL=ignoreboth:erasedups      # ignora duplicati e comandi che iniziano con uno spazio, elimina i doppioni vecchi
HISTTIMEFORMAT='%F %T  '              # history mostra anche data e ora di ogni comando
HISTIGNORE='ls:ll:pwd:clear:history'  # comandi banali da non salvare
shopt -s histappend                   # appende al file invece di sovrascriverlo: più terminali non si cancellano a vicenda
PROMPT_COMMAND='history -a'           # salva ogni comando subito, non solo alla chiusura del terminale
```
> **TRUCCO**: con `HISTCONTROL=ignorespace` (incluso in `ignoreboth`) un comando che inizia con
> uno spazio non finisce nella history. Utile quando si passa una password sulla riga di comando.

```bash
history | awk '{print $2}' | sort | uniq -c | sort -rn | head -10 # i 10 comandi che uso di più
history | grep -i docker | tail -20                               # gli ultimi 20 comandi docker lanciati
```

Vedi anche: [02-shortcut.md](02-shortcut.md) per `CTRL+R`, `CTRL+P` e `CTRL+N`.
