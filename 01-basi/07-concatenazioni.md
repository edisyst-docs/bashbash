# Concatenazione di comandi

In `AND` l'esecuzione continua finché un comando non fallisce, in `OR` si ferma alla prima esecuzione riuscita.

```bash
cmd1 && cmd2  # esegue cmd2 solo se cmd1 ha avuto successo (exit status 0)
cmd1 || cmd2  # esegue cmd2 solo se cmd1 è fallito
cmd1 ;  cmd2  # esegue cmd2 in ogni caso, sono due comandi indipendenti
```

```bash
ls && echo ciao && ls   # tutto ha successo, esegue tutti e tre
ls && echi ciao && ls   # "echi" fallisce: la catena si interrompe e stampa l'errore
lss || echo ciao || ls  # si va avanti finché un comando non ha successo
```

## Raggruppare le catene
```bash
{ ls  || echo ciao; } && echo finito
{ lss || echo ciao; } && echo finito
```
> **NOTA**: con le `{}` serve uno spazio all'inizio e uno alla fine, e bisogna terminare con `;`.
> Le `()` fanno la stessa cosa ma aprono una sottoshell: vedi [01-shell.md](01-shell.md).

L'exit status dell'ultimo comando si legge con `$?`: vedi [../05-scripting/03-parametri.md](../05-scripting/03-parametri.md).
