# Link simbolici e hard link

## Link simbolico
Punta a un **percorso**. È un file a sé, con il suo inode.
```bash
ln -s file link_s1 # LINK SIMBOLICO: ha sempre permessi 777, ma tanto eredita i permessi del file che punta
ls -l              # riconosco il simlink dalla "l" iniziale
```

## Hard link
Punta a un **inode**. È lo stesso file, con un secondo nome.
```bash
touch origine
ls -l              # vedo che origine ha 1 nella colonna dei link

ln origine link_h1 # HARD LINK. Apparentemente è come un file diverso
ls -l              # ora hanno entrambi 2 nella colonna dei link
ls -i              # hanno lo stesso numero di inode
ls -li             # sono proprio lo stesso file, tutti i dati coincidono. Se ne modifico uno, modifico anche l'altro
```

## La differenza che conta
- Se sposto il file originale, il **simlink** non funziona più perché punta a un path non più valido.
- L'**hard link** funziona ancora perché punta sempre all'inode del file originale, che tiene traccia degli spostamenti.
