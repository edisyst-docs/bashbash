# Variabili

## Assegnare e leggere
```bash
variabile="valore" # senza nessuno spazio prima e dopo l'uguale

$nomevar   # prendo il valore della variabile
${nomevar} # stessa cosa ma è più leggibile in caso di concatenazioni strane
```

## declare: dichiarare il tipo
```bash
declare -i numero=13          # integer: se non è stringa lo devo dichiarare
declare -r costante="ciao"    # readonly: se le assegno un altro valore ho un errore
declare -x variabileglobale="globale" # export: la rende disponibile alle shell figlie, come "export"
export -n variabileglobale    # rimuove il flag di export: la variabile non è più globale

declare -a array=()           # array numerico (indicizzato)
declare -A arrayassociativo=() # array associativo (indicizzato da stringhe)
```
Vedi [06-array.md](06-array.md) per l'uso degli array.

## export: passare variabili alle shell figlie
```bash
merenda=torta        # variabile valorizzata
echo $merenda        # stampa torta
export merenda       # la esporta così posso usarla anche nelle shell figlie
export merenda=torta # fa entrambe le operazioni in un colpo solo
export               # senza argomenti, elenca le variabili globali
unset merenda        # ELIMINA la variabile (non la svuota: dopo unset non esiste più). Dà errore su una costante
```

## Opzioni della shell
```bash
set -o           # elenca le opzioni di bash con lo stato on/off
set +o           # UGUALE, ma stampa il risultato come comandi rieseguibili
echo $SHELLOPTS  # mostra velocemente solo quelle attive
set -o allexport # da questo momento in poi ogni variabile sarà automaticamente esportata
```

## Variabili d'ambiente utili
```bash
echo $?  # exit status dell'ultimo comando eseguito: 0 vuol dire SUCCESS
         # stampa 13 se lo script appena eseguito finisce con "exit 13"

echo $RANDOM # stampa un numero casuale tra 0 e 32767

echo $ + TAB # premendo TAB dopo il $ la shell mostra l'elenco di tutte le variabili disponibili
env          # mostra i valori di molte variabili d'ambiente
```

Vedi anche: [03-parametri.md](03-parametri.md) per i parametri posizionali e gli altri parametri speciali.
