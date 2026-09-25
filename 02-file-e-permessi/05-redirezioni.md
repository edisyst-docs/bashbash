# Redirezioni

Ogni processo nasce con tre file descriptor: `0` standard input, `1` standard output, `2` standard error.
Redirigere significa collegare uno di questi a un file invece che al terminale.

## Separare output ed errori
```bash
touch file{1,2,4,5}                       # creo 4 file
ls -lh file1 file0                        # ho errore per file0 e output per file1. Default: stdout e stderr vanno entrambi a video

ls -lh file1 file0  > risultati           # redirigo nel file solo std_output (1), std_error (2) resta a video
ls -lh file1 file0 1> risultati           # UGUALE

ls -lh file1 file0 2> errori              # redirigo nel file solo std_error (2), std_output (1) resta a video
ls -lh file1 file0  > risultati 2> errori # posso fare ENTRAMBE LE COSE INSIEME
ls -lh file1 file0 &> tutto               # UGUALE ma redirigo entrambi (output ed error) dentro un unico file "tutto"
ls -lh file1 file0  > tutti 2>&1          # UGUALE (output dentro "tutti", error dove è reindirizzato l'output, cioè sempre "tutti")

ls -lh file1 file0  2>&1 > risultati      # Equivale a "> risultati": std_error è reindirizzato nel default di std_output, cioè il terminale
```
> **NOTA**: l'ordine conta. `2>&1` copia la destinazione *attuale* di stdout, quindi va scritto
> **dopo** la redirezione di stdout, non prima.

## tee: stampare e scrivere insieme
```bash
echo messaggio | tee file       # stampa "messaggio" a video e lo scrive dentro "file"
                                # legge dallo std_input e invia il testo sia allo std_output (schermo) sia a uno o più file
echo "altra riga" | tee -a file # UGUALE ma fa l'APPEND nel file
```

## Redirezione permanente e file descriptor custom
```bash
exec > ~/t.txt    # redirezione permanente: da qui in poi tutto lo stdout della shell va nel file
exec > /dev/pts/0 # torno a scrivere sul terminale

exec 5> ~/t.txt   # creo il file descriptor 5: chi scrive su 5 scriverà in quel file
exec 5<> ~/t.txt  # così lo apro sia in LETTURA che in SCRITTURA
exec 5>&-         # chiudo il file descriptor "custom" 5 in SCRITTURA
```

## << (Here-Document) e <<< (Here-String)
`<<` fornisce input multi-linea a un comando, con un DELIMITATORE definito dall'utente.
```bash
cat << EOF > file.txt        # ciò che digito dopo lo scrive in file.txt finché non digito EOF
> Questa è la prima riga.    # cat riceve come input le righe scritte fino al delimitatore EOF
> Questa è la seconda riga.  # utile per passare input multi-linea a un comando
> EOF                        # EOF è un delimitatore, posso chiamarlo come voglio
```
```bash
tr 'a-z' 'A-Z' << FINE
> ciao questa è una frase lunga
> divisa in più righe
> e finisco qua
> FINE
```

`<<<` fornisce una stringa singola come input a un comando.
```bash
grep "parola" <<< "Frase contenente parola." # la stringa è passata come input a grep, come se fosse letta da un file o da stdin
python <<< 'print("Ciao Mondo")'             # utile per fornire una stringa singola come input
```

## Redirezione dell'input
```bash
cat elenco | sort > ordinato  # legge "elenco", lo ordina e scrive dentro "ordinato"
sort < elenco > ordinato      # UGUALE ma sfrutto la redirezione dell'input invece della pipe

echo "testo1 testo2 testo3" | xargs -n1 # stampa il testo andando a capo a ogni parola
xargs -n1 <<< "testo1 testo2 testo3"    # UGUALE ma più elegante perché uso l'operatore <<<

CMD n< file # LETTURA: apre il file in lettura sul descriptor n; default n=0
```

## Scrittura su file
```bash
ls  > tt.txt                  # SCRITTURA: creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt                  # SCRITTURA: stessa cosa ma opera in APPEND
echo "prima riga" >> file.txt # scrivo "prima riga" dentro file.txt (creandolo se non esiste)

cd /dev/fd ; ls -l            # elenco dei file descriptor aperti dal processo corrente
```

## Esempi pratici
```bash
: > /var/log/app.log             # SVUOTA il file senza eliminarlo: il processo che lo tiene aperto continua a scriverci
                                 # con "rm" invece lo spazio su disco non viene liberato finché il processo non lo chiude

sudo tee /etc/app.conf > /dev/null << 'EOF'   # scrivere in un file di root: "sudo cat > file" non funziona, la redirezione la fa la mia shell
chiave=valore
EOF
# > /dev/null evita che tee ristampi tutto a video. NB: dentro l'here-doc niente commenti, finirebbero nel file

cat << 'EOF' > deploy.sh         # delimitatore tra apici: NESSUNA espansione, $HOME e $(date) restano scritti così
echo "deploy fatto da $USER il $(date)"
EOF

if true; then
	cat <<- EOF                  # con <<- vengono rimossi i TAB iniziali (non gli spazi): posso indentare l'here-doc nel codice
	testo indentato nel sorgente ma non nell'output
	EOF
fi

{ echo "== $(date) =="; df -h; free -h; } >> report.txt  # redirigo l'output di un intero blocco di comandi in un colpo solo

find / -name '*.conf' 2> >(grep -v 'Permission denied' >&2) # filtra solo lo stderr: nasconde i "Permission denied" ma lascia gli altri errori
```

### Loggare tutto l'output di uno script
Da mettere in cima allo script: da quella riga in poi stdout e stderr vanno sia a video che nel log.
```bash
exec > >(tee -a /var/log/mio_script.log) 2>&1
```

### Leggere un file riga per riga con un file descriptor dedicato
```bash
exec 3< elenco_server.txt           # apro il file in lettura sul descriptor 3
while read -r server <&3; do        # leggo da 3: lo stdin (0) resta libero per ssh o read interattivi
    ssh "$server" uptime
done
exec 3<&-                           # chiudo il descriptor
```
Senza il descriptor dedicato `ssh` dentro il ciclo si "mangerebbe" le righe rimanenti del file,
perché leggerebbe anche lui dallo stesso stdin (in alternativa: `ssh -n`).

Vedi anche: [../01-basi/08-pipeline.md](../01-basi/08-pipeline.md) per `|` e `|&`, e [06-dd.md](06-dd.md) per la copia a basso livello.
