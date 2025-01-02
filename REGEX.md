https://www.youtube.com/watch?v=fPii79dBQqY&list=PL4L8OWDC99_c1pppqEyT3FXuBPDI3Qx4F

https://regex101.com/  
https://regexr.com/

Utili da usare con SED e con GREP

? => 0,1 OCCORRENZE DELL'ELEMENTO PRECEDENTE
* => 0,N OCCORRENZE DELL'ELEMENTO PRECEDENTE
+ => 1,N OCCORRENZE DELL'ELEMENTO PRECEDENTE
{2,7} => DA 2 A 7 OCCORRENZE DELL'ELEMENTO PRECEDENTE

. => QUALSIASI CARATTERE (A PARTE L'A CAPO) 
.* => QUALSIASI SEQUENZA DI CARATTERI (COMBINO . E *) 
[] => QUALSIASI CARATTERE dentro le []

[.aeiou]      => cerca tutte le vocali e i punti
[a-z]         => cerca tutte le lettere minuscole
[a-z] | [A-Z] => cerca tutte le lettere minuscole o maiuscole
[A-Z] [a-z]+  => cerca tutte le parole che iniziano per una MAIUSCOLA
[A-Z] [a-z]*  => così prenderebbe anche le SIGLE tutte maiuscole
[^e]          => tutto tranne la lettera "e"
[^aeiou ]     => esclude le vocali minuscole, e gli SPAZI (è un carattere anche lo spazio)
[Cc]iao       => matcha "ciao" e "Ciao"

([Cc]iao)|(colou*r)  => OR tra due pattern (basta che matchi 1 dei 2)


## PUNTATORI
^  => inizio del file
^W => cerca la W se è il primo carattere di tutto il file/testo
$  => fine del file
.$ => seleziona l'ultimo carattere (qualsiasi) della fine del file

```shell
cat crontab | grep '^#'      # stampa tutte le righe che iniziano per #
cat crontab | grep -v '^#'   # stampa tutte le righe che NON iniziano per #
cat crontab | grep ')$'      # stampa tutte le righe che finiscono con )
```
