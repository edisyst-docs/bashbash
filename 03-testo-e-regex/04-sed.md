# sed = Stream EDitor

Individua i pattern di testo che gli definisco e trasforma il testo in base all'azione che gli dico.

```bash
sed [OPZIONI] 'ESPRESSIONE' [FILE]                # SINTASSI BASE
sed 'comando/<ricerca>/<sostituisci>/(parametri)' # SINTASSI PER 'ESPRESSIONE'
sed 'comando:<ricerca>:<sostituisci>:(parametri)' # ALTERNATIVA: posso usare come separatore qualunque carattere non contenuto nel testo
```

## Comandi che modificano l'output, non il file
```bash
cat /etc/xattr.conf > config     # contiene alcune righe commentate, che iniziano per #

sed -n '1,5 p' config            # stampa le righe 1,2,3,4,5
sed    '1,5 p' config            # stampa tutto il file MA DUPLICA le righe 1,2,3,4,5
sed -n '5,$ p' config            # stampa le righe dalla 5 alla fine del file
sed -n '/pattern/p' config       # stampa le righe che contengono "pattern"
sed -n '/^#/p' config            # stampa le righe che iniziano per #
sed -n '/Inizio/,/Fine/p' config # stampa tutto il contenuto tra "Inizio" e "Fine"
```
> **NOTA**: `-n` sopprime la stampa automatica di ogni riga, quindi stampa solo ciò che `p` seleziona.

### Aggiungere, inserire, sostituire righe
```bash
sed '2a testo aggiunto' config # aggiunge "testo aggiunto" DOPO la riga 2
sed '2i testo aggiunto' config # aggiunge "testo aggiunto" PRIMA della riga 2
sed '2c testo aggiunto' config # SOSTITUISCE la riga 2 con "testo aggiunto"

sed '/ciao/a\riga dopo' file.txt  # aggiunge una nuova riga DOPO ogni riga dove trova la parola "ciao"
sed '/ciao/i\riga prima' file.txt # aggiunge una nuova riga PRIMA di ogni riga dove trova la parola "ciao"
```

### Eliminare e sostituire
```bash
sed '2,4 d' config          # elimina le righe 2,3,4
sed '/pattern/d' config     # elimina le righe che contengono "pattern"
sed '2,4s/prima/dopo/g' config # sostituisce "prima" con "dopo" nelle righe 2,3,4
sed 's/^/#/' config         # aggiunge # all'inizio di ogni riga
```

### Inserire il contenuto di un altro file
```bash
sed '/ciao/r altrofile.txt' config # inserisce il contenuto di altrofile.txt dentro config DOPO OGNI RIGA che contiene "ciao"
```

## Comandi che modificano direttamente il file
```bash
sed -i             '/^#/d;' config # cerca nel file le righe che iniziano per # e le ELIMINA DAL FILE (non stampa)
sed -i.$(date +%F) '/^#/d;' config # UGUALE ma crea anche un backup, che chiamo con la data di oggi
```

## Sostituzioni e gruppi di cattura
```bash
echo "ciao mamma" | sed 's/mamma/babbo/' # "ciao babbo"
echo "ciao mamma" | sed 's/[a-z]*/(&)/g' # "(ciao) (mamma)" - & è il testo che ha fatto match
echo "123 abc"    | sed 's/[0-9]*/& &/'  # sostituisce la stringa numerica con se stessa due volte: "123 123 abc"
echo "abc-123"    | sed 's/^[a-z]*//'    # elimina le stringhe di sole lettere all'inizio
```

```bash
echo "123abc" | sed -E 's/([0-9]+)([a-z]+)/& &/'   # con -E (o -r) supporta le REGEX estese: il + e le () senza escape
echo "123abc" | sed -E 's/([0-9]+)([a-z]+)/\2\1/'  # stampa il gruppo 2 seguito dal gruppo 1: "abc123"
echo "123abc" | sed 's/\([0-9]*\)\([a-z]*\)/\2\1/' # UGUALE ma senza -E, quindi le () vanno protette col backslash
echo "abc123" | sed 's/\([a-z]*\).*/\1/'           # identifica le stringhe di sole lettere e stampa solo quelle
```
> **NOTA**: sed può matchare fino a 9 gruppi distinti, richiamabili con `\1` ... `\9`.

```bash
echo "Mario Rossi" | sed 's/\([A-Za-z]*\) \([A-Za-z]*\)/\2 \1/' # esempio pratico: stampa "Rossi Mario"
echo "ciao ciao"   | sed 's/\([a-z][a-z]*\) \1/\1/'             # identifica i duplicati e li elimina
```

## Il flag globale e altri flag
```bash
echo "buon giorno giorno" | sed 's/giorno/notte/'  # "buon notte giorno" perché sed opera 1 volta per riga
echo "buon giorno giorno" | sed 's/giorno/notte/g' # "buon notte notte"  perché gli dico di operare GLOBALMENTE
sed 's/pattern/nuovo/I' file.txt                   # sostituisce ignorando maiuscole/minuscole
```

## Più espressioni insieme
```bash
sed -e 's/uno/UNO/g' -e '/tre/d' config # sostituisce "uno" con "UNO" ed elimina le righe che contengono "tre"
sed -e 's/uno/UNO/g' -e '/tre/d' *.txt  # UGUALE ma esegue i comandi su tutti i file che gli passo

sed = config | sed 'N;s/\n/ /'          # aggiunge all'output la numerazione delle righe
```

## Salvare il risultato
```bash
sed 's/unix/linux/g' geek.txt       # sostituisce ogni "unix" con "linux" nel testo, MA NON SOVRASCRIVE IL FILE
sed 's/unix/linux/g' geek.txt > aaa # ora l'output non lo stampa ma lo scrive in aaa
```

Vedi anche: [03-regex.md](03-regex.md) per la sintassi dei pattern.
