# Crontab

`crontab -e` apre (in EDIT MODE, tipicamente con VIM) il crontab dell'utente in corso

`crontab -e -u dpamaster` lo lanciamo noi perchè l'utente è dpamaster, non root

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

`* * * * * echo "ciao - 1" >> /tmp/prova`

**Esempi**: https://crontab.guru/examples.html
