# History

> **Laboratorio**: `./lab.sh 01`, poi `cd 06-history`. File pronti: `comandi.txt` e `prova.sh`, che lancia i comandi di un file in una shell **interattiva**.

Lo storico dei comandi lanciati e come richiamarli senza riscriverli.

> **Provarli senza una tastiera**: `!!`, `!$`, `^a^b` sono funzioni della shell **interattiva**: in uno script o in `bash -c` non si espandono.
> `./prova.sh comandi.txt` li fa girare in una `bash -i` che legge i comandi da un file, e mostra per ciascuno il testo espanso
> (la riga che bash stampa prima di eseguirla, per esempio `echo due`).

## Consultare la history
```bash
history            # storico di tutti i comandi lanciati
cat  .bash_history # viene letto questo file della mia home
history 5          # gli ultimi 5 comandi lanciati
history -c         # cancella tutta la history
```
Il file `~/.bash_history` viene scritto **all'uscita** della shell: i comandi della sessione in corso stanno solo in memoria finché non si esce (o non si dà `history -a`).

## Richiamare un comando
```bash
!101    # esegue il comando con ID=101 della history
!!      # esegue l'ultimo comando della history
sudo !! # esegue l'ultimo comando come SUDO (TRUCCHETTO UTILE)
!?at?   # esegue l'ultimo comando della history contenente 'at'. Es: date
!apt    # esegue l'ultimo comando della history che inizia con 'apt'. Es: apt-get update
```
Con `comandi.txt` (le prime righe: `echo uno`, `echo due`, `!!`, `!echo`, `!?du?`):
```
bash-5.2# echo uno
uno
bash-5.2# echo due
due
bash-5.2# !!               <- l'ultimo comando: "echo due"
echo due
due
bash-5.2# !echo            <- l'ultimo che comincia per "echo"
echo due
due
bash-5.2# !?du?            <- l'ultimo che contiene "du"
echo due
due
```

## Riusare gli argomenti del comando precedente
```bash
rm !$  # !$ è l'argomento dell'ultimo comando digitato, quindi rimuove il file digitato nel comando precedente (es: touch file nuovo)
```
```
bash-5.2# touch file nuovo
bash-5.2# rm !$
rm nuovo
```

## Rieseguire più comandi insieme
```bash
fc 92 94  # apre nano/vim scrivendo in un file temporaneo i comandi 92-93-94. All'uscita li esegue tutti
```
`fc` apre l'editor in `$FCEDIT` o `$EDITOR`. Altre forme: `fc -s` rilancia l'ultimo comando (come `!!`), `fc -ln -2` elenca gli ultimi due senza numeri.

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
Provati con `prova.sh` (le ultime righe di `comandi.txt`):
```
bash-5.2# echo a b c
a b c
bash-5.2# echo !*              <- tutti gli argomenti: a b c
echo a b c
a b c
bash-5.2# echo !:1             <- solo il primo
echo a
a
bash-5.2# !echo:p              <- :p stampa e NON esegue (e diventa l'ultimo comando della history)
echo a
bash-5.2# ^a^A                 <- sostituisce nell'ultimo comando: "echo a" -> "echo A"
echo A
A
bash-5.2# echo dev dev
dev dev
bash-5.2# !!:s/dev/prod/       <- solo la PRIMA occorrenza
echo prod dev
prod dev
bash-5.2# echo dev dev
dev dev
bash-5.2# !!:gs/dev/prod/      <- tutte le occorrenze
echo prod prod
prod prod
```
Se la sostituzione non trova il testo, o l'argomento chiesto non esiste, bash non esegue niente e protesta: `bash: :s^uno^UNO: substitution failed`, `bash: :2: bad word specifier`.

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
Provato (`HISTCONTROL=ignoreboth:erasedups`, `HISTIGNORE='ls:pwd'`, `HISTTIMEFORMAT`) su `echo uno`, ` echo con spazio`, `echo uno`, `ls`, `pwd`, `echo fine`, `history`:
```
    1  2026-10-06 05:07:31  echo uno       <- una sola volta: erasedups ha tolto il primo doppione
    2  2026-10-06 05:07:31  echo fine      <- " echo con spazio" (ignorespace), "ls" e "pwd" (HISTIGNORE) non ci sono
    3  2026-10-06 05:07:31  history
```
> **TRUCCO**: con `HISTCONTROL=ignorespace` (incluso in `ignoreboth`) un comando che inizia con
> uno spazio non finisce nella history. Utile quando si passa una password sulla riga di comando.

```bash
history | awk '{print $2}' | sort | uniq -c | sort -rn | head -10 # i 10 comandi che uso di più
history | grep -i docker | tail -20                               # gli ultimi 20 comandi docker lanciati
```

Vedi anche: [02-shortcut.md](02-shortcut.md) per `CTRL+R`, `CTRL+P` e `CTRL+N`.
