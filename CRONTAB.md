# Crontab

`crontab -e` apre il crontab dell'utente in corso

Usage: `crontab [-c DIR] [-u USER] [-ler]|[FILE]`

        -c      Crontab directory
        -u      User
        -l      List crontab
        -e      Edit crontab
        -r      Delete crontab
        FILE    Replace crontab by FILE ('-': stdin)

Aggiungo per fargli scrivere ogni minuto una riga:

`* * * * * echo "ciao - 1" >> /tmp/prova`

