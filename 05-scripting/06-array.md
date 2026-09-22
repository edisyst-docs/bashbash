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

Esempio eseguibile: [06-array.sh](06-array.sh).
