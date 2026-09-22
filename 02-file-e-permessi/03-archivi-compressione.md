# Archiviazione e compressione

- **Archiviazione**: un file unico che ne contiene N più le cartelle (`tar`).
- **Compressione**: riduzione dello spazio occupato (`gzip`, `bzip2`, `xz`).

## Leggere un file compresso senza scompattarlo
```bash
cat  /var/log/apt/history.log      # legge un file di testo
zcat /var/log/apt/history.log.1.gz # legge un file compresso .gz senza scompattarlo
bzcat, xzcat                       # analoghi per file compressi .bz e .xz
```

## gzip e xz
```bash
gzip file1 file2   # SOSTITUISCE file1 e file2 con file1.gz e file2.gz compressi
zcat file1.gz      # non lo posso leggere con cat ma con zcat
gzip -l file1.gz   # dice quanto occupa da compresso e da scompattato
gunzip file1.gz    # SOSTITUISCE file1.gz compresso con file1 (INVERSO di gzip)

xz file1     # SOSTITUISCE file1 con file1.xz compresso (comprime più di gzip)
xz -l file1.xz # dice quanto occupa da compresso e da scompattato
xz -d file1.xz # SOSTITUISCE file1.xz compresso con file1 (INVERSO di xz)
```

## tar
```bash
tar -cvf archivio.tar file1 file2          # CREA (-c) VERBOSAMENTE (-v) il file chiamato (-f) archivio.tar NON COMPRESSO contenente file1 e file2
tar -xf  archivio.tar -C /destinazione     # ESTRAE (-x) il contenuto di archivio.tar in una cartella specifica (-C)
tar -cf  archivio.tar file1 directory1     # CREA (-c) un archivio contenente sia file che directory
tar -czf compresso.tar.gz file1 directory1 # COMPRIME l'archivio con gzip (-z), bzip2 (-j) o xz (-J)
tar -xzf compresso.tar.gz                  # ESTRAE (-x) un archivio COMPRESSO (-z) di tipo tar.gz
tar -tf  compresso.tar.gz                  # è come fare "ls -l" ma dentro un archivio compresso

du -sh compresso.tar.gz file1 directory1   # confronto quanto occupano tutti quegli elementi
```
