# Data, ora e localizzazione

## Configurazione
```bash
dpkg-reconfigure tzdata  # modifica timezone/fuso orario
dpkg-reconfigure locales # modifica la lingua del terminale
```

## Il comando date
```bash
date                          # stampa data e ora di oggi
date -I                       # stampa solo la data
date '+%d-%m-%Y'              # stampa la data nel formato che gli dico io
date '+%H:%M:%S'              # posso indicargli anche un formato per stampare l'ora
date '+%d-%m-%Y --- %H:%M:%S' # altro esempio per combinarli

touch docum-$(date -I)        # trucco per creare un file con la data di oggi nel nome
```

## Calendario e tempo di attività
```bash
cal    # mostra il calendario
uptime # orario, tempo di attività, utenti connessi, carico di lavoro (è la prima riga del comando "top")
```

## Attendere
```bash
sleep 3; echo ciao # attende 3 secondi, poi esegue il comando echo
```

Vedi anche: [09-crontab.md](09-crontab.md) per schedulare comandi a orari fissi.
