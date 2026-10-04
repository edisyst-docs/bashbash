#!/usr/bin/env python3
"""Controlla i link relativi nei file .md della KB: ogni [testo](percorso) deve puntare a un file o una cartella
che esiste. Gli URL (http, mailto) e le ancore (#sezione) non vengono controllati.

Uso: python3 .github/scripts/controlla-link.py [cartella]      (default: la cartella corrente)
Per ogni link rotto stampa una riga nel formato dei comandi di GitHub Actions (::error file=...,line=...::),
che diventa un'annotazione sul file nella pagina dell'esecuzione e nella pull request. Exit code 1 se ce n'è almeno uno.
"""
import pathlib
import re
import sys

LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")       # ](percorso) oppure ](percorso#ancora)
ESCLUSE = {".git", "node_modules"}


def main() -> int:
    radice = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    rotti = controllati = 0
    for md in sorted(radice.rglob("*.md")):
        if ESCLUSE & set(md.parts):
            continue
        for numero, riga in enumerate(md.read_text(encoding="utf-8").splitlines(), start=1):
            for destinazione in LINK.findall(riga):
                if destinazione.startswith(("http://", "https://", "mailto:")):
                    continue
                controllati += 1
                if not (md.parent / destinazione).exists():
                    rotti += 1
                    print(f"::error file={md.as_posix()},line={numero}::link rotto: {destinazione}")
    print(f"{controllati} link controllati, {rotti} rotti")
    return 1 if rotti else 0


if __name__ == "__main__":
    sys.exit(main())
