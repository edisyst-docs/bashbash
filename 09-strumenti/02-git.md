# git oltre le basi

Si dà per scontato `clone`, `add`, `commit`, `push`, `pull`. Qui ci sono i comandi per indagare, correggere e recuperare.

## Leggere la storia
```bash
git log --oneline --graph --all --decorate      # grafo compatto di tutti i branch
git log -p -- app/Models/User.php               # tutte le modifiche a un file, con il diff
git log --follow -- vecchio/percorso.php        # la storia di un file anche prima che fosse rinominato
git log -S 'calcolaTotale' --oneline            # "pickaxe": commit che hanno AGGIUNTO o RIMOSSO questa stringa
git log -G 'env\(.*DB_' --oneline               # UGUALE ma con una regex, su qualsiasi riga modificata
git log --author='Edoardo' --since='2 weeks ago' --oneline
git log main..feature --oneline                 # commit presenti in feature ma non in main
git shortlog -sn                                # numero di commit per autore
git show a1b2c3d                                # dettagli e diff di un commit
git show a1b2c3d:config/app.php                 # il contenuto di un file com'era in quel commit
git blame -L 40,60 app/Http/Kernel.php          # chi ha scritto le righe 40-60 e in quale commit
git diff main...feature --stat                  # cosa cambia il branch rispetto al punto in cui si è staccato da main
git grep -n 'TODO'                              # cerca solo nei file versionati (più veloce di grep -r, ignora vendor)
```

## Lavoro in corso: stash
```bash
git stash push -m "prova login"          # mette da parte le modifiche non committate
git stash push -u -m "con i nuovi file"  # -u include anche i file non tracciati
git stash push -- app/Models/User.php    # solo alcuni file
git stash list                           # elenco
git stash show -p stash@{1}              # contenuto di uno stash
git stash pop                            # riapplica l'ultimo e lo rimuove dalla lista
git stash apply stash@{1}                # riapplica ma lo tiene
git stash drop stash@{1}                 # elimina
git stash branch fix-login stash@{0}     # crea un branch dal punto in cui lo stash era stato fatto e lo applica lì
```

## Correggere
```bash
git restore file.php                     # annulla le modifiche NON in stage di un file (ATTENZIONE: perse)
git restore --staged file.php            # toglie dallo stage, le modifiche restano
git restore -s HEAD~3 -- file.php        # riporta il file com'era 3 commit fa

git commit --amend                       # modifica l'ULTIMO commit (messaggio o file aggiunti dopo). Solo se non ancora pushato
git commit --amend --no-edit             # UGUALE tenendo il messaggio
git reset --soft HEAD~1                  # annulla l'ultimo commit, le modifiche restano in stage
git reset HEAD~1                         # UGUALE ma le modifiche tornano fuori dallo stage
git reset --hard HEAD~1                  # annulla commit E modifiche (recuperabile solo col reflog)
git revert a1b2c3d                       # crea un commit che annulla a1b2c3d: il modo corretto su un branch già condiviso

git rebase -i HEAD~5                     # riordina, unisce (squash), modifica gli ultimi 5 commit. Solo su commit non pushati
git commit --fixup a1b2c3d               # commit di correzione "attaccato" ad a1b2c3d...
git rebase -i --autosquash main          # ...che il rebase unisce automaticamente al suo commit
git cherry-pick a1b2c3d                  # copia un singolo commit sul branch corrente (es. un hotfix)
git push --force-with-lease              # dopo un rebase: forza il push, ma FALLISCE se qualcun altro ha pushato nel frattempo
```

## Recuperare: reflog
Il reflog registra ogni spostamento di HEAD (commit, reset, rebase, checkout) per circa 90 giorni.
Quasi niente di committato va perso davvero.
```bash
git reflog                                # HEAD@{0}, HEAD@{1}...: la storia delle MIE operazioni
git reset --hard HEAD@{2}                 # torno allo stato di 2 operazioni fa (es. prima di un rebase andato male)
git branch recupero a1b2c3d               # recupero un commit di un branch cancellato per sbaglio
git fsck --lost-found                     # ultima spiaggia: oggetti non più raggiungibili (anche stash eliminati)
```

## Trovare il commit che ha introdotto un bug: bisect
Ricerca binaria: con 1000 commit bastano circa 10 prove.
```bash
git bisect start
git bisect bad                            # la versione attuale ha il bug
git bisect good v2.3.0                    # questa versione funzionava
# git fa il checkout di un commit a metà: provo e rispondo
git bisect good                           # oppure: git bisect bad
# ...ripeto finché git stampa "a1b2c3d is the first bad commit"
git bisect reset                          # torno dove ero
```
Automatico, con un comando che esce 0 se va bene e diverso da 0 se c'è il bug:
```bash
git bisect start HEAD v2.3.0
git bisect run php artisan test --filter=CalcoloTotaleTest
git bisect reset
```

## Branch e remoti
```bash
git switch -c feature/login               # crea ed entra in un branch (equivale a checkout -b)
git switch -                              # torna al branch precedente (come cd -)
git branch -vv                            # branch locali con il remoto collegato e se sono avanti/indietro
git branch --merged main                  # branch già uniti in main: si possono cancellare
git branch -d feature/login               # cancella (rifiuta se non unito); -D forza
git fetch --prune                         # aggiorna i remoti e rimuove i riferimenti ai branch cancellati sul server
git push -u origin feature/login          # primo push, collega il branch locale al remoto
git push origin --delete feature/login    # cancella il branch sul remoto
git remote -v                             # remoti configurati
```

## Configurazione utile
```bash
git config --global pull.rebase true             # pull = fetch + rebase: niente commit di merge inutili
git config --global fetch.prune true             # prune automatico a ogni fetch
git config --global init.defaultBranch main
git config --global core.autocrlf input          # Windows/WSL: converte CRLF in LF al commit, non tocca in checkout
git config --global alias.lg "log --oneline --graph --all --decorate"
git config --global alias.st "status -sb"
git config --global rerere.enabled true          # ricorda come ho risolto un conflitto e lo riapplica se si ripresenta
git config --global --list --show-origin         # tutte le impostazioni e da quale file arrivano
```

## Esempi pratici
```bash
git ls-files -m                                   # file modificati (utile negli script)
git diff --name-only main... -- '*.php' | xargs -r php -l # controlla la sintassi solo dei file PHP modificati nel branch
git clean -nd                                     # SIMULA la rimozione dei file non tracciati...
git clean -fd                                     # ...e li rimuove davvero (ATTENZIONE: non recuperabili, non sono in git)
git archive --format=tar.gz -o release.tar.gz HEAD # archivio dei soli file versionati: niente .git, vendor, node_modules
git worktree add ../app-hotfix main               # un secondo checkout dello stesso repo in un'altra cartella: hotfix senza toccare il lavoro in corso
git worktree remove ../app-hotfix
git tag -a v2.4.0 -m "release 2.4.0" && git push origin v2.4.0 # tag annotato di release
git describe --tags                               # v2.4.0-3-ga1b2c3d: ultimo tag, commit successivi, hash (versione per build)
```

Hook `pre-commit` che blocca i `dd()` dimenticati (file `.git/hooks/pre-commit`, reso eseguibile con `chmod +x`):
```bash
#!/usr/bin/env bash
trovati=$(git diff --cached --name-only --diff-filter=ACM -- '*.php' | xargs -r grep -nHE '\b(dd|dump|var_dump)\(') # -H: stampa sempre il nome del file
if [[ -n $trovati ]]; then                # controllo l'output e non l'exit status: senza file PHP xargs -r esce comunque con 0
    echo "$trovati"
    echo "ERRORE: debug dimenticato nei file sopra. Commit bloccato (bypass: git commit --no-verify)" >&2
    exit 1
fi
```
