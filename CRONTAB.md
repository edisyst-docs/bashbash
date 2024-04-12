# Crontab

`crontab -e` apre (in EDIT MODE) il crontab dell'utente in corso

`crontab -e -u dpamaster` è quello che lanciamo noi

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
