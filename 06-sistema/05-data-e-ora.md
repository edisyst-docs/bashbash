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

## Esempi pratici
```bash
timedatectl                              # timezone, ora di sistema e se è sincronizzata via NTP
sudo timedatectl set-timezone Europe/Rome # imposta il fuso orario senza menu interattivo

date +%s                                 # Unix timestamp: secondi dal 1/1/1970
date -d @1758794400                      # da timestamp a data leggibile
date -d 'yesterday' +%F                  # data di ieri (YYYY-MM-DD)
date -d '2026-09-25 +30 days' +%F        # 30 giorni dopo una data
date -d 'last monday' +%F                # il lunedì scorso
date -d 'first day of next month' +%F    # primo giorno del mese prossimo
date +%F_%H%M%S                          # 2026-09-25_101500: formato ideale per i nomi file (ordinabile)
TZ=America/New_York date                 # ora corrente in un altro fuso, senza cambiare quello di sistema

echo $(( ($(date -d 2026-12-25 +%s) - $(date +%s)) / 86400 )) giorni a Natale # differenza tra date in giorni
```

Misurare quanto dura qualcosa:
```bash
time ./script.sh                         # real = tempo reale, user/sys = tempo di CPU

inizio=$(date +%s)
./backup.sh
echo "backup completato in $(( $(date +%s) - inizio )) secondi"

SECONDS=0                                # SECONDS è una variabile di bash che conta i secondi da quando la azzero
./backup.sh
printf 'durata: %02d:%02d\n' $((SECONDS/60)) $((SECONDS%60))
```

Vedi anche: [09-crontab.md](09-crontab.md) per schedulare comandi a orari fissi.
