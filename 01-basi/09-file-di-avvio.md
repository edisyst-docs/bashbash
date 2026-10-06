# File di avvio della shell

> **Laboratorio**: `./lab.sh 01`, poi `cd 09-file-di-avvio`. File pronti: `casa/` (una home finta con i file di avvio), `benv.sh` e `prova.sh`. Gli esempi sono stati eseguiti con bash 5.2.

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

### Provarlo: `prova.sh`
Nel laboratorio `~/lab/09-file-di-avvio/` ha una **home finta** (`casa/`, con un `.profile`, `.bash_profile`, `.bash_login`, `.bashrc` e `.bash_logout` che dicono solo `[letto NOME]`) e `prova.sh`, che lancia bash in modi diversi con `HOME=casa`.
Il risultato, con i file a loro posto:

| Comando | File letti | Perché |
|---|---|---|
| `bash -lc "echo fatto"` | `.bash_profile` | login, non interattiva: legge il primo tra `.bash_profile`, `.bash_login`, `.profile` |
| `echo "echo fatto" \| bash -i` | `.bashrc` | interattiva, non login |
| `echo "echo fatto" \| bash -li` | `.bash_profile`, poi (all'uscita) `.bash_logout` | login e interattiva |
| `bash -c "echo fatto"` | **niente** | non interattiva, non login: è la shell di uno script |
| `BASH_ENV=$PWD/benv.sh bash -c "echo fatto"` | il file di `BASH_ENV` | l'unico modo di far leggere qualcosa a una shell non interattiva |
| `bash --noprofile -lc "echo fatto"` | **niente** | login, ma senza profili |
| `echo "echo fatto" \| bash --norc -i` | **niente** | interattiva, ma senza `.bashrc` |

E la regola del **primo che esiste**: tolto `.bash_profile`, una login shell legge `.bash_login`; tolto anche quello, legge `.profile`. In nessuno dei casi `.bash_profile` e `.profile` vengono letti **insieme**:
per questo, se si crea un `.bash_profile`, il `.profile` (e con lui il `.bashrc` che richiama) smette di caricarsi.

> **ATTENZIONE**: le opzioni **lunghe** (`--norc`, `--noprofile`, `--login`) vanno messe **prima** di quelle corte: `bash -i --norc` dà `bash: --: invalid option` e stampa tutta la guida;
> `bash --norc -i` funziona. E `bash -i` da un terminale legge `/etc/bash.bashrc` oltre al `~/.bashrc` (nel laboratorio con `HOME=casa` si vede solo il secondo).
> `$-` in una shell interattiva contiene la `i` (`hiBHs` nella prova).

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
(Il comportamento con `ssh host 'comando'` e con cron **non è stato provato** nel laboratorio, che non ha un server SSH né cron attivi: la parte verificata è il comportamento di una shell non interattiva, qui sopra.)

Vedi anche: [05-alias.md](05-alias.md) e [bashrc-esempio](bashrc-esempio).
