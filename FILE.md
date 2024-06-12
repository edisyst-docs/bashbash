## FILE
```bash
touch pippo_{1,2,3}  # crea pippo_1, pippo_2, pippo_3 
touch pippo_{01..12} # crea pippo_01, pippo_02, ..., pippo_12

shred pippo_01    # sovrascrive in modo illeggibile il file. Meglio che eliminarlo, perchè si potrebbe ripristinare
shred -u pippo_01 # sovrascrive in modo illeggibile il file e lo elimina pure

tar -cf compresso.tar file1 file2 # crea un file compresso.tar contenente file1, file2
tar -xf compresso.tar             # estrae i file contenuti in compresso.tar

sort file.txt    # riordina in ordine alfabetico le righe dei file.txt
sort -r file.txt # riordina in ordine alfabetico inverso

find ./ -name "long.txt" # cerca un file chiamato long.txt nella directory corrente
find ./ -type f -name "*.py" ./get_keys.py ./github_automation.py ./binarysearch.py # cerca i file con estensione .py 
```


# REDIREZIONI

## Lettura e scrittura
```bash
exec > ~/t.txt    # serve per la redirezione permanente
exec > /dev/pts/0 # serve per la redirezione permanente
exec 5>~/t.txtv   # creo il file descriptor 5: chi può accedere allo stdOUT (default=1) scriverà in quel file
exec 5<>~/t.txt   # così lo creo sia per LETTURA che SCRITTURA
exec 5>&-         # chiudo il file descriptor "custom" 5 in SCRITTURA
```

## Lettura su file
```bash
CMD n< file # LETTURA - aprire il file in lettura; default n=0

head -n 10 divina_commedia.txt # mostra le prime 10 righe (default=10)
tail -n 10 divina_commedia.txt # mostra le ultime 10 righe

nl divina_commedia.txt | tail -n 15 # mostra e numera le ultime 15 righe
nl divina_commedia.txt | head -n 15 # mostra e numera le prime 15 righe
```

## Scrittura su file
```bash
tr "1234" "abcd" # provo a digitare 1261681185 e lui mi scrive ab6a68aa85
tr "1234" "abcd" < t.txt # legge nel file e stampa sovrascrivendo quei caratteri

ls > tt.txt  # SCRITTURA - creo il file contenente l'output del comando ls. Se il file esiste lo sovrascrive
ls >> tt.txt # SCRITTURA - stessa cosa ma opera in APPEND
echo "prima riga" >> file.txt # scrivo "prima riga" dentro file.txt (creandolo se non esiste)

cd /dev/fd
ls -l

sed 's/unix/linux/' geekfile.txt # sostituisce ogni occorrenza di "unix" con "linux" nel file geekfile.txt

dd if=/path/to/sourcefile of=/path/to/destinationfile # copia file, ma funziona anche per folder e volumi
```

## Differenze tra file
```bash
diff read/simile1.sh read/simile2.sh # mostra le differenze tra i file
diff -y read/simile1.sh read/simile2.sh # mostra riga per riga evidenziando le differenze

comm read/simile1.sh read/simile2.sh # 3 colonne: nella terza ci son le righe in comune tra i due file
```
