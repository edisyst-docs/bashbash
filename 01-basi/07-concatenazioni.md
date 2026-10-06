# Concatenazione di comandi

> **Laboratorio**: `./lab.sh 01`, poi `cd 07-concatenazioni` (o qualunque cartella: servono solo `ls` e `echo`). Gli errori riportati sono quelli di bash 5.2 in uno script lanciato da `bash -s`; sul prompt interattivo non c'è il `line N:`.

In `AND` l'esecuzione continua finché un comando non fallisce, in `OR` si ferma alla prima esecuzione riuscita.

```bash
cmd1 && cmd2  # esegue cmd2 solo se cmd1 ha avuto successo (exit status 0)
cmd1 || cmd2  # esegue cmd2 solo se cmd1 è fallito
cmd1 ;  cmd2  # esegue cmd2 in ogni caso, sono due comandi indipendenti
```

```bash
ls && echo ciao && ls   # tutto ha successo, esegue tutti e tre
ls && echi ciao && ls   # "echi" fallisce: la catena si interrompe e stampa l'errore
# bash: line 7: echi: command not found      <- il secondo "ls" non parte
lss || echo ciao || ls  # si va avanti finché un comando non ha successo
# bash: line 7: lss: command not found
# ciao                                        <- "echo ciao" riesce: il terzo comando (ls) NON parte
```
`ls && echi ciao && ls` stampa prima l'elenco del primo `ls` e poi l'errore: i comandi già eseguiti restano eseguiti.

## Raggruppare le catene
```bash
{ ls  || echo ciao; } && echo finito
# (l'elenco di ls) e poi: finito          <- ls riesce, "echo ciao" salta, il gruppo ha successo e parte "echo finito"
{ lss || echo ciao; } && echo finito
# bash: line 7: lss: command not found
# ciao
# finito                                  <- il gruppo ha successo grazie a "echo ciao"
```
> **NOTA**: con le `{}` serve uno spazio all'inizio e uno alla fine, e bisogna terminare con `;`.
> Le `()` fanno la stessa cosa ma aprono una sottoshell: vedi [01-shell.md](01-shell.md).

## Esempi pratici
```bash
mkdir -p build && cd build || { echo "impossibile entrare in build" >&2; exit 1; } # guard clause tipica degli script

command -v docker >/dev/null 2>&1 || { echo "docker non installato"; exit 1; } # verifica che un comando esista prima di usarlo

git pull && composer install --no-dev && php artisan migrate --force # deploy minimale: si ferma al primo passo fallito

(cd /var/www/app && php artisan cache:clear) # la sottoshell cambia cartella solo per quel comando: dopo sono ancora dove ero

ping -c1 -W1 192.168.1.1 >/dev/null && echo "UP" || echo "DOWN" # forma compatta di if/else
```
> **ATTENZIONE**: `a && b || c` non è un vero if/else. Se `a` riesce ma `b` fallisce, parte
> anche `c`. Va bene quando `b` è un `echo` (che non fallisce mai), altrimenti meglio un `if`.

```bash
true && false || echo "parte c"         # a riesce, b FALLISCE: c parte lo stesso
# parte c
```
`exit 1` dentro `{ ... }` esce dalla **shell corrente**: in uno script termina lo script, sul prompt chiude il terminale. Per questo la *guard clause* si usa negli script, non a mano.

L'exit status dell'ultimo comando si legge con `$?`: vedi [../05-scripting/03-parametri.md](../05-scripting/03-parametri.md).
