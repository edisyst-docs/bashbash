# File di avvio della shell

Quando bash parte legge alcuni file di configurazione. Quali, dipende da **come** è stata avviata.
Da qui nasce il classico "l'alias funziona nel terminale ma non via SSH" (o viceversa).

## Login e non-login, interattiva e non interattiva
- **Login shell**: la prima shell dopo un'autenticazione. Login via SSH, `su -`, `sudo -i`, `bash -l`, TTY testuale.
- **Non-login shell**: una shell aperta dentro una sessione già avviata. Nuova scheda del terminale grafico, `bash` digitato a mano, tmux.
- **Interattiva**: aspetta i comandi da tastiera e mostra il prompt.
- **Non interattiva**: esegue uno script o un comando (`bash script.sh`, `ssh host 'comando'`, cron).

```bash
shopt -q login_shell && echo "login" || echo "non-login"  # che tipo di shell è questa?
[[ $- == *i* ]] && echo "interattiva"                     # $- contiene le opzioni attive: la "i" indica interattiva
```

## Quali file vengono letti
| Tipo di shell | File letti (in ordine) |
|---|---|
| Login interattiva | `/etc/profile`, poi il **primo che esiste** tra `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Non-login interattiva | `/etc/bash.bashrc` (Debian/Ubuntu), `~/.bashrc` |
| Non interattiva (script) | nessuno, salvo il file indicato in `$BASH_ENV` |
| Uscita da una login shell | `~/.bash_logout` |

> **NOTA**: su Debian/Ubuntu il `~/.profile` di default contiene un blocco che fa `source ~/.bashrc`.
> Per questo nella pratica `~/.bashrc` viene letto quasi sempre. Ma se crei un `~/.bash_profile`,
> `~/.profile` non viene più letto e il `~/.bashrc` smette di caricarsi nelle login shell.

## Cosa mettere dove
- **`~/.profile`**: variabili d'ambiente (`PATH`, `EDITOR`, `LANG`), cioè ciò che deve valere per tutta la sessione, anche per i programmi grafici. Viene letto una volta sola, al login.
- **`~/.bashrc`**: tutto ciò che serve alla shell interattiva: alias, funzioni, prompt, opzioni `shopt`, completamento. Viene letto a ogni nuova shell.
- **`/etc/profile.d/*.sh`**: impostazioni valide per TUTTI gli utenti (es. il PATH di un software installato in `/opt`).
- **`/etc/environment`**: variabili globali in formato `CHIAVE=valore`, senza sintassi shell. Letto da PAM, non da bash.

Se uso `~/.bash_profile`, deve richiamare esplicitamente `.bashrc`:
```bash
# ~/.bash_profile
[[ -f ~/.profile ]] && source ~/.profile  # mantiene le variabili definite in .profile
[[ -f ~/.bashrc ]]  && source ~/.bashrc   # e carica alias e funzioni anche nelle login shell
```

## Esempi pratici
```bash
source ~/.bashrc                  # ricarica il .bashrc nella shell corrente dopo averlo modificato (senza aprire un nuovo terminale)
. ~/.bashrc                       # UGUALE
exec bash                         # sostituisce la shell con una nuova, pulita: rilegge tutto da zero
bash --norc                       # apre una shell SENZA leggere .bashrc: per capire se un problema viene da lì
env -i bash --noprofile --norc    # UGUALE ma anche con l'ambiente completamente vuoto
```

Aggiungere una cartella al PATH senza duplicarla a ogni `source`:
```bash
# in ~/.profile
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;                    # c'è già: non faccio niente
    *) PATH="$HOME/.local/bin:$PATH" ;;           # la aggiungo in testa: ha la precedenza sui comandi di sistema
esac
export PATH
```

Parti del `.bashrc` solo per alcune macchine, senza mantenere file diversi:
```bash
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local  # impostazioni specifiche di questa macchina (non versionate)

if [[ -n $SSH_CONNECTION ]]; then                   # sono collegato via SSH?
    PS1='\[\e[31m\]\u@\h\[\e[0m\]:\w\$ '            # prompt rosso: ricorda che sono su un server remoto
fi

command -v composer >/dev/null && export PATH="$PATH:$HOME/.config/composer/vendor/bin" # solo se composer è installato
```

Un prompt con il branch git corrente:
```bash
branch_git() {
    git branch --show-current 2>/dev/null | sed 's/.*/ (&)/' # " (main)" se sono in un repo, niente altrimenti
}
PS1='\u@\h:\w$(branch_git)\$ '   # apici singoli: $(branch_git) viene rivalutato a ogni prompt, non una volta sola
```
Sequenze utili nel `PS1`: `\u` utente, `\h` hostname, `\w` cartella corrente, `\t` ora, `\$` `#` se root altrimenti `$`.

## Perché cron e gli script non vedono i miei alias
Cron e `ssh host 'comando'` avviano shell non interattive. Cron non legge `.bashrc`. Con ssh bash lo legge
(caso speciale), ma il `.bashrc` di default di Debian/Ubuntu nelle prime righe esce subito se la shell non è interattiva:
quindi in pratica niente alias né variabili definite lì. Inoltre gli alias non vengono espansi negli script.
Negli script vanno scritti i percorsi completi o definite le variabili all'inizio. Vedi [../06-sistema/09-crontab.md](../06-sistema/09-crontab.md).

Vedi anche: [05-alias.md](05-alias.md) e [bashrc-esempio](bashrc-esempio).
