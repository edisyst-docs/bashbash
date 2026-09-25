# Array

Due tipi:
- **array classici** (indicizzati da numeri): posso NON dichiararli
- **array associativi** (indicizzati da stringhe): DEVO dichiararli

```bash
declare -a nome_arr=(19 "pippo" "cane" 23)  # array indicizzato (la dichiarazione è opzionale)
nome_arr=(19 "pippo" "cane" 23)             # UGUALE, senza dichiarazione

echo ${nome_arr[0]}   # 19
echo ${nome_arr[1]}   # pippo
echo ${nome_arr[@]}   # tutti gli elementi
echo ${#nome_arr[@]}  # numero di elementi
```

```bash
declare -A nome_assoc               # array associativo: la dichiarazione è OBBLIGATORIA
nome_assoc[colore]="rosso"
nome_assoc[taglia]="L"

echo ${nome_assoc[colore]}          # rosso
echo ${!nome_assoc[@]}              # tutte le chiavi
echo ${nome_assoc[@]}               # tutti i valori
```

## Operazioni comuni
```bash
arr=(uno due tre)
arr+=(quattro)                       # aggiunge in coda
echo "${arr[@]:1:2}"                 # slice: 2 elementi a partire dall'indice 1 => due tre
unset 'arr[1]'                       # elimina l'elemento 1 (gli indici NON vengono ricompattati)
echo "${!arr[@]}"                    # gli indici esistenti: 0 2 3
for el in "${arr[@]}"; do echo "$el"; done  # "${arr[@]}" tra virgolette: ogni elemento resta intero anche se contiene spazi
(IFS=,; echo "${arr[*]}")            # join con la virgola: "${arr[*]}" unisce usando il primo carattere di IFS
```

## Esempi pratici
```bash
mapfile -t righe < elenco.txt        # carica un file in un array, una riga per elemento (-t toglie il \n finale)
echo "${#righe[@]} righe, la prima è: ${righe[0]}"

mapfile -t php < <(find . -name '*.php') # array dall'output di un comando
```

Contare le occorrenze con un array associativo:
```bash
declare -A conta
while read -r ip _; do
    ((conta[$ip]++))                 # il primo campo del log è l'IP: incremento il suo contatore
done < access.log
for ip in "${!conta[@]}"; do
    echo "${conta[$ip]} $ip"
done | sort -rn | head               # l'ordine delle chiavi non è garantito: ordino dopo
```

Configurazione per ambiente:
```bash
declare -A SERVER=( [staging]="10.0.0.10" [produzione]="10.0.0.20" )
AMBIENTE=${1:-staging}
[[ -v SERVER[$AMBIENTE] ]] || { echo "ambiente sconosciuto: $AMBIENTE" >&2; exit 1; } # -v: la chiave esiste?
rsync -az ./ "deploy@${SERVER[$AMBIENTE]}:/var/www/app/"
```

Esempio eseguibile: [06-array.sh](06-array.sh).
