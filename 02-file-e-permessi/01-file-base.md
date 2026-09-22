# Creare, copiare, eliminare file

## Capire con cosa ho a che fare
```bash
basename /etc/apache2/conf-available/common.conf # stampa solo common.conf

file -i crontab.md   # mi dice il MIME type del file
file file1.txt       # mi dice il tipo di file (ASCII text)
file *               # mi dice il tipo di file di tutti quelli in cartella
```

## Creare
```bash
touch pippo_{1,2,3}  # crea pippo_1, pippo_2, pippo_3
touch pippo_{01..12} # crea pippo_01, pippo_02, ..., pippo_12

mkdir dir{1,2,3}              # UGUALE a: mkdir dir1 dir2 dir3
mkdir -p progetti/2024/giugno # le crea tutte, già annidate, altrimenti dovrei crearle una per volta
mkdir -m 700 dir_privata      # specifico i permessi in creazione
```

## Copiare
```bash
ls /etc/*.conf                # mostra tutti i file .conf che sono dentro /etc
cp /etc/*.conf destinazione   # copia tutti i file .conf che sono dentro /etc dentro destinazione
cp -i origine destinazione    # UGUALE ma chiede conferma in caso di overwriting
cp file1 file2                # fa una copia di file1 e la chiama file2
cp -a file1 file2             # UGUALE ma copia anche i permessi (sennò il file nuovo avrebbe quelli di default)
cp file1 /percorso/directory/ # copia file1 dentro la cartella /percorso/directory/
cp -r dir_1 /percorso/dir_2/  # copia la dir_1 dentro la cartella /percorso/dir_2
```

## Eliminare
```bash
rmdir directory_vuota           # la directory dev'essere vuota per poterla eliminare
rmdir -p genitore/figlio/nipote # ricorsivo, ma devono essere tutte vuote

rm -r  directory_non_vuota      # rimuove directory NON VUOTE, eliminando ricorsivamente i file all'interno
rm -ri directory_non_vuota      # chiede conferma prima di rimuovere ogni file

shred pippo_01    # sovrascrive il file in modo illeggibile. Meglio che eliminarlo, perché si potrebbe ripristinare
shred -u pippo_01 # UGUALE ma elimina anche il file
```
Vedi anche [06-dd.md](06-dd.md) per un altro modo di sovrascrivere in sicurezza un file prima di cancellarlo.

## Contare il contenuto di un file
```bash
wc file    # nr. righe, parole, caratteri presenti in file
wc -l file # nr. righe    presenti in file
wc -w file # nr. parole   presenti in file
wc -c file # nr. byte     presenti in file
wc -m file # nr. caratteri presenti in file
```

## Verificare l'integrità di un file
```bash
md5sum file.txt      # calcola l'hash del file, utile per verificare se un file è stato trasferito con successo
sha256sum, sha512sum # alternative più sicure (hash con più bit)
```

## tree: come "ls -R" ma stampa un albero
```bash
tree cartella      # stampa un albero con ogni elemento
tree -p cartella   # stampa anche i permessi di ogni elemento
tree -f cartella   # stampa il path relativo di ogni elemento
tree -L 1 cartella # stampa l'albero solo fino a 1 LIVELLO DI SOTTODIRECTORY
tree -d cartella   # stampa solo le directory

tree -P "testo*" prova1 # fa anche un "find" sul PATTERN per filtrare i FILENAME
```
