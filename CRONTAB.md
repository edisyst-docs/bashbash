# Crontab

`crontab -e` apre (in EDIT MODE, tipicamente con VIM) il crontab dell'utente in corso

`crontab -e -u pippo` lo lancia root impersonando l'utente pippo, evidentemente perchè l'owner non è root ma pippo

Usage: `crontab [-c DIR] [-u USER] [-ler]|[FILE]`

```bash
-c      Crontab directory
-u      User
-l      List crontab
-e      Edit crontab
-r      Delete crontab
FILE    Replace crontab by FILE ('-': stdin)
```

**Esempio**: aggiungo questo nel crontab per fargli scrivere ogni minuto una riga nel file prova:
```bash
* * * * * echo "Oggi è il giorno $(date '+%d-%m-%Y') e sono le ore $(date '+%H:%M:%S')" >> orario.txt
```

**Esempi**: https://crontab.guru/examples.html
