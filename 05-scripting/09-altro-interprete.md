# Usare un altro interprete

Lo **shebang** nella prima riga dice al sistema quale interprete usare per eseguire il file.
Non deve per forza essere bash.

```bash
#!/usr/bin/bash          # bash
#!/usr/bin/env bash      # bash, cercandolo nel $PATH (più portabile)
#!/bin/sh                # sh
#!/c/Python311/python    # python, ma questo percorso esiste solo su Git Bash per Windows
#!/usr/bin/env python3   # python in modo portabile: su Linux è questa la forma da usare
```

```bash
which python # mi dice il percorso di python, da mettere nello shebang
./s4.sh      # esegue del codice python perché nello shebang gli ho detto qual è l'interprete
```

> **NOTA**: lo shebang funziona solo se lo script ha i permessi di esecuzione e viene lanciato
> come `./script`. Se lo lancio come `bash script` lo shebang viene ignorato.
>
> **ATTENZIONE su Windows**: se il file ha line ending CRLF, il `\r` finisce dentro il percorso
> dello shebang e l'interprete non viene trovato. Per questo il repo ha un `.gitattributes`
> che forza LF sui `.sh`.

Esempio eseguibile: [09-altro_interprete.sh](09-altro_interprete.sh).
