# Cicli

La condizione si scrive sempre in uno dei 3 modi: `[ condizione ]`, `[[ condizione ]]`, `test condizione`.

> **NOTA su IFS**: `IFS` (Internal Field Separator) ha 3 valori di default — newline, spazio e tab
> (`"\n \t"`) — e identifica i separatori fra parole quando bash divide una stringa.

## WHILE
Cicla finché la condizione è vera.
```bash
while condizione
do
    cmd1
    cmd2
done
```

## UNTIL
Contrario di WHILE: cicla finché la condizione è falsa.
```bash
until condizione
do
    cmd1
    cmd2
done
```

## FOR su una lista
```bash
for var in listaElementi
do
    cmd1
    cmd2
done
```

## FOR in stile C
```bash
for (( i=0; i<=10; i++ ))
do
    echo "valore di i: "$i
done
```

## SELECT: menu interattivo
Costruisce un menu numerato a partire da una lista e cicla finché non esce.
```bash
PS3="Scegli un'opzione: "
select vardir in $(ls -d ../zz-sandbox/zz_esempi/*/)
do
    echo "Hai scelto la directory: $vardir"
    break
done
```

## Esempi pratici

### Leggere un file riga per riga (il modo corretto)
```bash
while IFS= read -r riga; do          # IFS= non toglie gli spazi a inizio/fine riga, -r non interpreta i backslash
    echo "-> $riga"
done < elenco.txt                    # redirigo il file sul while, NON "cat elenco.txt | while": vedi sotto
```

```bash
while IFS=: read -r utente _ uid _ _ home shell; do  # IFS=: spezza la riga sui ":" e assegna i campi alle variabili
    (( uid >= 1000 && uid < 65534 )) && echo "$utente $home $shell" # "_" è una variabile usa-e-getta per i campi che non mi servono
done < /etc/passwd
```

> **ATTENZIONE**: con `cmd | while ...` il ciclo gira in una sottoshell, quindi le variabili
> modificate dentro si perdono all'uscita. Per leggere l'output di un comando usare la process substitution:
```bash
conta=0
while read -r _; do ((conta++)); done < <(find . -name '*.php') # < <( ) = l'output di find come se fosse un file
echo "$conta file PHP"                                          # con la pipe qui stamperebbe 0
```

### Ciclare su file (anche con spazi nel nome)
```bash
for f in *.JPG; do
    [[ -e "$f" ]] || continue        # se non ci sono .JPG il glob resta letterale "*.JPG": lo salto
    mv -- "$f" "${f%.JPG}.jpg"       # rinomina l'estensione. Le virgolette sono OBBLIGATORIE per i nomi con spazi
done

find . -type f -name '*.log' -print0 | while IFS= read -r -d '' f; do # -d '' legge fino al NUL: regge qualsiasi nome file
    gzip -- "$f"
done
```

### Retry con attesa crescente
```bash
tentativo=1
until curl -sf https://api.example.com/health > /dev/null; do # until: ripete finché il comando FALLISCE
    (( tentativo >= 5 )) && { echo "servizio giù dopo 5 tentativi" >&2; exit 1; }
    attesa=$(( 2 ** tentativo ))                              # 2, 4, 8, 16 secondi (backoff esponenziale)
    echo "tentativo $tentativo fallito, riprovo tra ${attesa}s"
    sleep "$attesa"
    (( tentativo++ ))
done
echo "servizio raggiungibile"
```

### Attendere che un servizio sia pronto (es. MySQL in Docker)
```bash
for i in {1..30}; do
    mysqladmin ping -h 127.0.0.1 --silent && break # break esce dal ciclo appena risponde
    sleep 1
done
```

### Ciclo infinito con uscita controllata
```bash
while true; do
    read -rp "comando (q per uscire): " cmd
    [[ $cmd == q ]] && break
    [[ -z $cmd ]] && continue        # continue salta al giro successivo
    echo "hai scritto: $cmd"
done
```

Esempi eseguibili: [05-cicli1.sh](05-cicli1.sh), [05-select.sh](05-select.sh).
