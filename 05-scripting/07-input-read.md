# Input e read

`read` legge una riga dallo standard input e la assegna a una o più variabili.
```bash
read var1 var2 var3  # legge una riga e la spezza in 3 variabili usando IFS come separatore
```

```bash
echo -n "Inserisci: " # -n evita l'a capo, così il cursore resta sulla stessa riga
read a b c
echo $a
```

Cambiando `IFS` cambio il separatore usato per spezzare l'input:
```bash
IFS=";"     # ora read spezza sui punto e virgola invece che sugli spazi
read a b c
```

## Opzioni di read
```bash
read -p "Nome: " nome          # prompt sulla stessa riga (sostituisce echo -n + read)
read -s -p "Password: " pwd    # -s non mostra cosa digito
echo                           # dopo -s serve un a capo a mano
read -t 10 -p "Continuo? " r   # timeout: dopo 10 secondi prosegue (exit status > 128)
read -n 1 -p "Premi un tasto"  # legge 1 solo carattere, senza aspettare INVIO
read -r riga                   # -r: i backslash restano backslash. Da usare quasi sempre
read -a parti <<< "a b c"      # -a: spezza la riga in un array
```

## Esempi pratici
Chiedere conferma prima di un'operazione pericolosa:
```bash
conferma() {
    local risposta
    read -r -p "${1:-Sei sicuro?} [s/N] " risposta
    [[ ${risposta,,} == s || ${risposta,,} == si ]]  # restituisce 0 (vero) solo con s/si/S/SI
}

conferma "Eliminare il database di produzione?" || exit 1
```

Chiedere un valore con default e validazione:
```bash
while true; do
    read -r -p "Porta [8080]: " porta
    porta=${porta:-8080}                            # INVIO vuoto = valore di default
    [[ $porta =~ ^[0-9]+$ ]] && (( porta >= 1 && porta <= 65535 )) && break
    echo "porta non valida" >&2
done
```

Leggere un CSV con intestazione:
```bash
{
    read -r _                                        # la prima read "consuma" l'intestazione
    while IFS=, read -r nome email ruolo; do
        echo "creo $nome <$email> come $ruolo"
    done
} < utenti.csv
```

Esempi eseguibili: [07-read1.sh](07-read1.sh), [07-read2.sh](07-read2.sh).
