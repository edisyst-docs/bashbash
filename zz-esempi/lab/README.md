# Laboratorio di zz-esempi

Gli script di [esercizi/](../esercizi/) e [rubrica/](../rubrica/) si provano qui. Niente servizi: [prepara.sh](prepara.sh) crea in `~/lab` i file su cui lanciarli e `verifica.sh`, che li mette alla prova.

## Avvio
Dalla radice della KB (il nome dell'area è la cartella, perché `zz-` non è un numero):
```bash
./lab.sh zz-esempi
cd esercizi && ./verifica.sh        # 31 casi, uno per riga: OK o ERRATO con la differenza
./base2.sh 11                       # gli script sono collegati qui: 11 --> 1011
cd ../rubrica && ./rubrica.sh       # il menu; ./rubrica.sh -h per la riga di comando
```
Tutto sparisce all'uscita. Per ripartire da zero senza uscire: `bash /kb/zz-esempi/lab/prepara.sh && cd ~/lab`.

## Cosa contiene

| Cartella | File pronti | Note |
|---|---|---|
| `esercizi/` | `include/` (`prova.c`, `prova.h`, `a.txt`, `prova.cpp`), `vuote/` (due file con righe vuote, uno con lo spazio nel nome), `disco/` (file e cartelle da 3 MB a 50 KB, anche con uno spazio nel nome), `rubrica/.rubrica`, `verifica.sh`, e i collegamenti `base2.sh`, `toupper.sh`, `removeblanklines.sh`, `include.sh`, `spaziodisco.sh` | `./verifica.sh` prova ogni script con casi giusti, sbagliati e limite |
| `rubrica/` | `rubrica.sh` (collegamento) | i dati sono in `~/rubrica/.rubrica`, dove lo script li cerca: si possono modificare, spariscono con il laboratorio |

`verifica.sh` non tocca `~/rubrica`: per i test della rubrica usa una home usa-e-getta (`mktemp -d`). `KB=/altra/cartella ./verifica.sh` prova una copia diversa degli script.

Torna all'[indice di zz-esempi](../README.md)
