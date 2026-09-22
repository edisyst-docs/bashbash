# bashbash

Knowledge base personale su bash, comandi da terminale Linux e scripting Windows.

Cartelle e file sono numerati nell'ordine in cui conviene studiarli: si parte da `01-basi/01-shell.md`
e si prosegue in ordine. Le cartelle `zz-` non sono tappe del percorso, sono materiale di supporto.
Ogni cartella ha il proprio `README.md` con l'indice dei suoi file.

## Percorso di studio

### [01-basi/](01-basi/) — la shell interattiva
Come muoversi nel terminale, trovare i comandi, concatenarli.

1. [shell](01-basi/01-shell.md) — quale shell sto usando, sottoshell, `exec`
2. [shortcut](01-basi/02-shortcut.md) — scorciatoie da tastiera
3. [help e manuali](01-basi/03-help-e-manuali.md) — `man`, `info`, `help`, `apropos`, `$PATH`
4. [comandi base](01-basi/04-comandi-base.md) — `ls`, `stat`, `mv`, `pwd`, `echo`
5. [alias](01-basi/05-alias.md) — `alias`, `type`, `unalias`
6. [history](01-basi/06-history.md) — `history`, `!!`, `!$`, `fc`
7. [concatenazioni](01-basi/07-concatenazioni.md) — `&&`, `||`, `;`, `{}`, `()`
8. [pipeline](01-basi/08-pipeline.md) — `|`, `|&`, `xargs`, `cat`

### [02-file-e-permessi/](02-file-e-permessi/) — operare sui file
Creare, cercare, trasferire file e decidere chi può farlo.

1. [file base](02-file-e-permessi/01-file-base.md) — `touch`, `cp`, `rm`, `mkdir`, `wc`, `tree`
2. [find](02-file-e-permessi/02-find.md) — `find`, `-exec`, `locate`
3. [archivi e compressione](02-file-e-permessi/03-archivi-compressione.md) — `tar`, `gzip`, `xz`
4. [link](02-file-e-permessi/04-link.md) — link simbolici, hard link, inode
5. [redirezioni](02-file-e-permessi/05-redirezioni.md) — `>`, `2>`, `tee`, here-doc, file descriptor
6. [dd](02-file-e-permessi/06-dd.md) — copia a basso livello di file e partizioni
7. [diff e rsync](02-file-e-permessi/07-diff-e-rsync.md) — `diff`, `patch`, `rsync`
8. [permessi](02-file-e-permessi/08-permessi.md) — notazione ottale, `chmod`, bit speciali, `umask`
9. [proprietari](02-file-e-permessi/09-proprietari.md) — `chown`, `chgrp`, gruppi condivisi

### [03-testo-e-regex/](03-testo-e-regex/) — cercare e trasformare testo
Gli strumenti che userai dentro ogni script.

1. [stampa e taglia](03-testo-e-regex/01-stampa-e-taglia.md) — `head`, `tail`, `sort`, `cut`, `awk`, `tr`, `split`
2. [grep](03-testo-e-regex/02-grep.md) — ricerca in file e pipeline
3. [regex](03-testo-e-regex/03-regex.md) — BRE ed ERE
4. [sed](03-testo-e-regex/04-sed.md) — stream editor, gruppi di cattura
5. [vim](03-testo-e-regex/05-vim.md) — i 4 modi e i comandi di ciascuno

### [04-processi/](04-processi/) — cosa gira e quanto consuma
1. [ps e kill](04-processi/01-ps-e-kill.md) — `ps`, `pgrep`, segnali, `lsof`
2. [jobs](04-processi/02-jobs.md) — `&`, `CTRL+Z`, `fg`, `bg`, `nohup`
3. [top e htop](04-processi/03-top-htop.md) — monitoraggio interattivo
4. [risorse](04-processi/04-risorse.md) — `free`, `du`, `df`, `nice`/`renice`, `/proc`

### [05-scripting/](05-scripting/) — scrivere script bash
Ogni argomento ha il suo `.md` e, dove esiste, lo script di prova con lo stesso numero.

1. [basi scripting](05-scripting/01-basi-scripting.md) — i 4 modi di lanciare uno script
2. [variabili](05-scripting/02-variabili.md) — `declare`, `export`, `unset`
3. [parametri](05-scripting/03-parametri.md) — `$0`, `$1`, `$#`, `$@`, `$?`
4. [condizioni](05-scripting/04-condizioni.md) — `test`, `if`, `case`
5. [cicli](05-scripting/05-cicli.md) — `while`, `until`, `for`, `select`
6. [array](05-scripting/06-array.md) — indicizzati e associativi
7. [input e read](05-scripting/07-input-read.md) — `read` e `IFS`
8. [espansioni](05-scripting/08-espansioni.md) — le 9 espansioni, nel loro ordine
9. [altro interprete](05-scripting/09-altro-interprete.md) — shebang

### [06-sistema/](06-sistema/) — amministrazione della macchina
1. [filesystem](06-sistema/01-filesystem.md) — la struttura di Debian/Ubuntu, cartella per cartella
2. [utenti](06-sistema/02-utenti.md) — `id`, `adduser`, `passwd`, `su`, `sudo`, `runuser`
3. [pacchetti apt](06-sistema/03-pacchetti-apt.md) — `apt`, `apt-get`, `apt-cache`
4. [dischi](06-sistema/04-dischi.md) — `mount`, `lsblk`, `blkid`, `fstab`
5. [data e ora](06-sistema/05-data-e-ora.md) — `date`, `cal`, `uptime`, timezone
6. [rete e host](06-sistema/06-rete-e-host.md) — `hostname`, `uname`, `ping`
7. [servizi](06-sistema/07-servizi.md) — `systemctl`, `shutdown`, `wall`, `ldd`
8. [tmux](06-sistema/08-tmux.md) — sessioni, finestre, pane
9. [crontab](06-sistema/09-crontab.md) — schedulare comandi ricorrenti
10. [logrotate](06-sistema/10-logrotate/) — rotazione dei log, con script e configurazione

### [07-windows/](07-windows/) — batch e PowerShell
1. [batch](07-windows/01-batch.md) — sintassi `.bat`, con esempi completi
2. [powershell](07-windows/02-powershell.md) — cmdlet per servizi, processi, rete
3. [esempi .bat](07-windows/03-esempi/) — script funzionanti: backup, clone Laravel, pulizia, menu

## Supporto (fuori dal percorso)

- **[zz-esempi/](zz-esempi/)** — script completi e funzionanti: la [rubrica](zz-esempi/rubrica/) interattiva e gli [esercizi](zz-esempi/esercizi/) di scripting
- **[zz-risorse/](zz-risorse/)** — [link utili](zz-risorse/link-utili.md), [sintassi Mermaid](zz-risorse/mermaid.md) e i PDF di riferimento
- **[zz-sandbox/](zz-sandbox/)** — file usa-e-getta su cui lanciare i comandi degli esempi. Si possono sporcare liberamente

## Trovare un comando
Se non ricordi in che file sta un comando:
```bash
grep -rn "nome_comando" --include="*.md" .
```

## Convenzioni
- Cartelle e file numerati nell'ordine di studio; il prefisso `zz-` marca il materiale di supporto.
- File e cartelle in minuscolo, parole separate da trattino.
- Ogni cartella ha un `README.md` con l'indice dei suoi file.
- In `05-scripting/` e `04-processi/` lo script di prova porta lo stesso numero del `.md` che lo spiega.
- Ogni comando ha il suo commento inline sulla stessa riga, allineato.
- `UGUALE` indica una forma alternativa che fa esattamente la stessa cosa del comando sopra.
- Gli script `.sh` sono in LF, i `.bat` e i `.ps1` in CRLF: lo forza il `.gitattributes`.
