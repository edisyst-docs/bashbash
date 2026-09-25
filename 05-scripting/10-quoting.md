# Quoting e printf

Il quoting decide quali [espansioni](08-espansioni.md) avvengono e se il risultato viene spezzato
in più parole. È la causa numero uno dei bug negli script.

## I tre modi di quotare
```bash
nome="Mario Rossi"

echo '$nome $(date) \n'   # SINGLE QUOTES: tutto letterale, nessuna espansione => $nome $(date) \n
echo "$nome $(date)"      # DOUBLE QUOTES: espande variabili, $( ), $(( )) e \ davanti a $ ` " \ ... ma NON spezza il risultato
echo $nome                # NESSUN QUOTING: espande E poi spezza in parole (word splitting) ed espande i glob (* ? [])
echo \$nome               # BACKSLASH: rende letterale il singolo carattere che segue => $nome
echo $'riga1\nriga2\t<-'  # ANSI-C QUOTING: interpreta \n \t \e \x41 ecc. come in C
```

```bash
echo 'l'\''apostrofo'     # un apice singolo DENTRO gli apici singoli: chiudo, backslash-apice, riapro => l'apostrofo
echo "l'apostrofo"        # UGUALE, più leggibile: dentro le doppie l'apice singolo è un carattere normale
echo "lui disse \"ciao\"" # le doppie dentro le doppie vanno protette col backslash
```

## Perché le virgolette servono sempre
```bash
file="report finale.txt"
touch "$file"
rm $file                  # SBAGLIATO: la shell lo spezza in due argomenti, "report" e "finale.txt"
rm "$file"                # corretto: un solo argomento

dir=""
rm -rf $dir/*             # PERICOLOSO: se $dir è vuota diventa "rm -rf /*"
rm -rf "${dir:?vuota}"/*  # difesa: se $dir è vuota lo script si ferma con errore invece di cancellare /

pattern="*.txt"
echo $pattern             # il glob viene espanso: elenca i file .txt
echo "$pattern"           # stampa letteralmente *.txt

[ $var = "si" ]           # se $var è vuota diventa "[ = si ]" => errore "unary operator expected"
[ "$var" = "si" ]         # corretto
[[ $var = "si" ]]         # dentro [[ ]] il word splitting non avviene: le virgolette sono facoltative a sinistra
```
> **REGOLA PRATICA**: metti sempre le doppie virgolette attorno a `$variabile`, `$(comando)` e `"$@"`.
> Toglile solo quando vuoi esplicitamente lo splitting o il globbing, e scrivi un commento che lo dice.

## Array e "$@"
```bash
args=("primo argomento" "secondo")
printf '[%s]\n' ${args[@]}     # SBAGLIATO: 3 elementi => [primo] [argomento] [secondo]
printf '[%s]\n' "${args[@]}"   # corretto:  2 elementi => [primo argomento] [secondo]

wrapper() {
    comando_vero "$@"          # inoltra gli argomenti così come sono arrivati, spazi compresi
}
```

## Comandi dentro stringhe: meglio gli array
```bash
opzioni="-avz --exclude='cache dir'"
rsync $opzioni src/ dst/                 # NON funziona: gli apici dentro la variabile restano letterali

opzioni=(-avz --exclude='cache dir')     # un array tiene separati gli argomenti
rsync "${opzioni[@]}" src/ dst/          # funziona

[[ $DRY_RUN == 1 ]] && opzioni+=(--dry-run) # e posso aggiungere opzioni in modo condizionale
```

## printf: output formattato
`echo` si comporta diversamente tra shell e sistemi (`-e`, `-n`, backslash). `printf` no: negli script è preferibile.
> **SINTASSI**: `printf 'FORMATO' argomenti...` — il formato viene riapplicato finché ci sono argomenti.

```bash
printf '%s\n' "ciao"                 # %s stringa, \n a capo (printf NON va a capo da solo)
printf '%s\n' uno due tre            # il formato si ripete: una riga per argomento
printf '%d file\n' 42                # %d intero
printf '%.2f EUR\n' 3.14159          # %f decimale con 2 cifre dopo la virgola
printf '%05d\n' 42                   # 00042: riempie con zeri fino a 5 cifre
printf '%x %o\n' 255 8               # ff 10: esadecimale e ottale
printf '%-10s|%8s|\n' nome valore    # - allinea a sinistra: colonne di larghezza fissa
printf '%s\n' "${array[@]}"          # stampa un array un elemento per riga
printf -v oggi '%(%F)T' -1           # -v scrive in una variabile invece che a video; %(...)T formatta una data (-1 = adesso)
printf '%q\n' "file con 'apici'"     # %q stampa la stringa con il quoting necessario per riusarla nella shell
```

```bash
# tabella allineata
printf '%-20s %8s %6s\n' "FILE" "BYTE" "RIGHE"
for f in *.md; do
    printf '%-20s %8d %6d\n' "$f" "$(stat -c %s "$f")" "$(wc -l < "$f")"
done
```

```bash
# barra di avanzamento sulla stessa riga: \r torna a inizio riga senza andare a capo
for i in $(seq 1 100); do
    printf '\rAvanzamento: %3d%%' "$i"   # %% stampa un simbolo di percentuale
    sleep 0.02
done
printf '\n'
```

```bash
# colori ANSI (funzionano nella maggior parte dei terminali)
ROSSO=$'\e[31m'; VERDE=$'\e[32m'; RESET=$'\e[0m'
printf '%sOK%s    backup completato\n' "$VERDE" "$RESET"
printf '%sERRORE%s disco pieno\n' "$ROSSO" "$RESET" >&2
```

Vedi anche: [08-espansioni.md](08-espansioni.md) per l'ordine in cui la shell applica le espansioni.
