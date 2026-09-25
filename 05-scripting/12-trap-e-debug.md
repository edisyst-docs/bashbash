# Trap, gestione errori e debug

## trap: reagire a segnali ed eventi
> **SINTASSI**: `trap 'comandi' SEGNALE [SEGNALE...]`

```bash
trap 'echo "uscita"' EXIT        # EXIT: eseguito SEMPRE quando lo script termina (fine normale, exit, errore, CTRL+C)
trap 'echo "CTRL+C!"' INT        # INT: CTRL+C
trap 'echo "terminato"' TERM     # TERM: kill PID (il segnale di default)
trap 'echo "ricarico"' HUP       # HUP: convenzione per "rileggi la configurazione"
trap 'echo "errore"' ERR         # ERR (solo bash): un comando è fallito
trap '' INT                      # stringa vuota: IGNORA il segnale (CTRL+C non ha effetto)
trap - INT                       # ripristina il comportamento di default
trap -p                          # elenca i trap attivi
```
> **NOTA**: `SIGKILL` (9) e `SIGSTOP` non si possono intercettare: il processo muore senza eseguire il trap.
> Per questo prima si prova sempre con `kill` semplice (TERM). Vedi [../04-processi/01-ps-e-kill.md](../04-processi/01-ps-e-kill.md).

### Pulizia garantita dei file temporanei
```bash
tmp=$(mktemp)                    # file temporaneo con nome univoco (es. /tmp/tmp.X8f2kQ)
trap 'rm -f "$tmp"' EXIT         # qualunque cosa succeda, all'uscita viene eliminato

curl -s https://example.com > "$tmp"
grep -q 'OK' "$tmp" || exit 1    # anche uscendo qui il file viene rimosso
```

### Lock: impedire due esecuzioni contemporanee
```bash
exec 9> /tmp/mio_script.lock     # apro il file di lock sul descriptor 9
flock -n 9 || { echo "già in esecuzione" >&2; exit 1; } # -n: se il lock è preso non aspetto, esco
# ... da qui in poi sono l'unica istanza. Il lock si libera da solo quando lo script termina
```

### Interruzione pulita di un ciclo lungo
```bash
fermati=0
trap 'fermati=1' INT TERM        # al CTRL+C non muoio subito: alzo un flag

for f in *.csv; do
    (( fermati )) && { echo "interrotto, ultimo file completato: ${ultimo:-nessuno}"; break; }
    importa "$f"                 # il file in corso viene completato, non lasciato a metà
    ultimo=$f
done
```

## set: modalità della shell per script più sicuri
```bash
set -e            # errexit:  esce al primo comando che fallisce
set -u            # nounset:  errore se si usa una variabile non definita (typo nei nomi scoperti subito)
set -o pipefail   # una pipeline fallisce se fallisce uno qualsiasi dei suoi comandi
set -E            # errtrace: il trap ERR vale anche dentro funzioni e sottoshell
set -Eeuo pipefail # tutto insieme: la riga standard in cima agli script

set +e            # il + DISATTIVA l'opzione (es. per un blocco dove i fallimenti sono attesi)
comando_che_puo_fallire
set -e
comando_che_puo_fallire || true  # alternativa più locale: "|| true" rende il fallimento accettabile
```

Quando `set -e` NON interviene (fonte classica di sorprese):
```bash
if comando_fallito; then ...; fi # dentro la condizione di if/while/until
comando_fallito && echo ok       # a sinistra di && e ||
! comando_fallito                # negato con !
local x=$(comando_fallito)       # dentro local/export/declare: conta l'exit status di local, che è 0
```

### Trap ERR con numero di riga e comando
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERRORE: exit $? alla riga $LINENO: $BASH_COMMAND" >&2' ERR

cp /nonesiste /tmp/     # => ERRORE: exit 1 alla riga 5: cp /nonesiste /tmp/
```

## Debug
```bash
bash -n script.sh      # controlla SOLO la sintassi, senza eseguire niente
bash -x script.sh      # esegue stampando ogni comando DOPO le espansioni, preceduto da +
bash -xv script.sh     # UGUALE, e stampa anche le righe così come sono scritte nel file (-v)
```

Dentro lo script, per tracciare solo un pezzo:
```bash
set -x                 # da qui in poi traccia
problema_misterioso
set +x                 # smette di tracciare
```

```bash
export PS4='+ ${BASH_SOURCE##*/}:${LINENO} ${FUNCNAME[0]:-main}(): ' # PS4 è il prefisso delle righe di -x: aggiungo file, riga e funzione
bash -x script.sh      # => + script.sh:12 deploy(): rsync -az ./ ...

BASH_XTRACEFD=7 bash -x script.sh 7> trace.log # la traccia va in trace.log, l'output normale resta a video
```

## ShellCheck: il linter per bash
Trova staticamente quote mancanti, variabili non usate, confronti sbagliati, `cd` senza controllo e molto altro.
```bash
sudo apt install shellcheck   # su Windows: winget install koalaman.shellcheck
shellcheck script.sh          # ogni avviso ha un codice (es. SC2086) con spiegazione su https://www.shellcheck.net/wiki/
shellcheck -x script.sh       # -x segue anche i file inclusi con source
shellcheck -f diff script.sh | git apply # applica automaticamente le correzioni che sa fare da solo (es. aggiungere le virgolette)
```
Per ignorare consapevolmente un avviso su una riga:
```bash
# shellcheck disable=SC2086
rsync $OPZIONI_VOLUTAMENTE_SPEZZATE src/ dst/
```
> **TRUCCO**: esiste anche online su https://www.shellcheck.net e come estensione per VS Code e JetBrains,
> che segnala i problemi mentre si scrive.

Vedi anche: [01-basi-scripting.md](01-basi-scripting.md) per lo scheletro di script robusto che usa tutto questo.
