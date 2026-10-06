# Esercizi di scripting

Ogni script ha in cima il testo dell'esercizio e un esempio d'uso: si può leggere l'enunciato, provare a scriverlo da
soli e poi confrontare con la soluzione.

| File | Cosa chiede |
|---|---|
| [base2.sh](base2.sh) | Stampare un intero in base 10 in base 2 |
| [toupper.sh](toupper.sh) | Stampare in maiuscolo i nomi passati come argomento |
| [removeblanklines.sh](removeblanklines.sh) | Rimuovere le righe vuote da una lista di file |
| [include.sh](include.sh) | Trovare gli `#include` locali e globali in un sorgente C |
| [spaziodisco.sh](spaziodisco.sh) | Elencare file e cartelle per dimensione decrescente, con tipo (`F`/`D`) e size leggibile |

**Laboratorio**: `./lab.sh zz-esempi`, poi `cd esercizi`. Il file `verifica.sh` prova ogni script con casi noti (giusti, sbagliati e limite) e stampa `OK` o `ERRATO` con la differenza: se si riscrive una soluzione da soli, basta
puntarlo sulla propria copia con `KB=CARTELLA ./verifica.sh` (la cartella deve avere `esercizi/` e `rubrica/` come questa) per sapere se regge agli stessi casi. Dettagli in [../lab/](../lab/).

## Cosa è stato corretto provandoli
Gli script originali funzionavano sul caso dell'esempio ma non sui casi limite. Provati nel laboratorio, ora gestiscono:

| Script | Prima | Ora |
|---|---|---|
| `base2.sh` | `base2.sh abc` stampava `abc --> 0` (per `bc` una parola vale 0) e senza argomento ` -->` | controlla che l'argomento sia un intero: altrimenti `ERRORE: usa: base2.sh intero` ed exit 1 |
| `toupper.sh` | `for f in $@` senza virgolette: `"con spazio"` diventava due nomi (`con --> CON`, `spazio --> SPAZIO`) | `"$@"`: `con spazio --> CON SPAZIO` |
| `include.sh` | le regex non erano ancorate: `// #include <ignorato.h>` contava come include, e `prova.cpp` passava per `.c` | `^` a inizio riga e `$` a fine nome; `read -r` |
| `spaziodisco.sh` | un nome con uno spazio finiva spezzato in due righe (`nome F 788K` e `spazio F con`) | legge i campi di `du` separati dal TAB: `nome con spazio   D   788K` |
| `removeblanklines.sh` | già a posto | resta così: una riga con **soli spazi** non è vuota e non viene tolta (`^$` non la trova) |

> **NOTA**: sono esercizi da studiare, non script di produzione: la CI non li controlla con shellcheck
> (restano fuori da [kb.yml](../../.github/workflows/kb.yml)).

Torna a [../](../)
