# LOGROTATE

`logrotate` è un utility su Linux che aiuta a gestire i file di log. Il suo scopo principale è quello di ruotare i log, 
ovvero rinominarli, comprimerli, eliminarli o inviarli via email dopo che hanno raggiunto una certa dimensione o dopo un certo periodo di tempo. 
Questo evita che i file di log crescano indefinitamente, occupando spazio su disco.



Ecco un esempio pratico da provare su una VM Ubuntu, in cui:
- ✅ Generiamo dei log con uno script Bash
- ✅ Creiamo una configurazione `logrotate` per gestire la rotazione dei log
- ✅ Testiamo la rotazione manualmente



## 1. crea una cartella per i log e uno script Bash che scrive continuamente in un file di log:
```bash
mkdir -p /var/log/mio_test
nano /usr/local/bin/genera_log.sh
```


Contenuto di `genera_log.sh`
```bash
#!/bin/bash

LOGFILE="/var/log/mio_test/app.log"

while true; do
    echo "$(date) - Questo è un messaggio di log" >> "$LOGFILE"
    sleep 1  # Scrive un log ogni secondo
done
```
Salva ed esci con CTRL + X, poi Y, poi INVIO.


Rendi lo script eseguibile e avvialo in background per fargli generare log
```bash
chmod +x /usr/local/bin/genera_log.sh
nohup /usr/local/bin/genera_log.sh &
```
In un'altro terminale verifica il contenuto (tail si aggiorna in realtime)
```bash
tail -f /var/log/mio_test/app.log
```



## 2. Crea il relativo file di configurazione di logrotate
```bash
sudo nano /etc/logrotate.d/mio_test
```


Contenuto di `genera_log.sh`
```bash
/var/log/mio_test/*.log {
    # Ruota i log ogni giorno
    daily            
    # Mantiene gli ultimi 5 log
    rotate 5         
    # Ruota se il file supera 100 KB
    size 100k        
    # Comprime i log vecchi in .gz
    compress         
    # Non genera errore se il file non esiste
    missingok        
    # Non ruota se il file è vuoto
    notifempty       
    # Svuota il log attuale senza interrompere lo script
    copytruncate     
}
```



## 3. Testare `logrotate`
Forza la rotazione manualmente per testarla e verifica i file di log ruotati
```bash
sudo logrotate -f /etc/logrotate.d/mio_test
ls -lh /var/log/mio_test/
```
Dovrei vedere qualcosa come:
```bash
app.log
app.log.1.gz
app.log.2.gz
app.log.3.gz
app.log.4.gz
```
✅ I log più vecchi sono compressi (.gz), mentre app.log è ripartito da zero!


Guarda il contenuto dei log ruotati e alla fine stoppa lo script infinito
```bash
zcat /var/log/mio_test/app.log.1.gz | tail -n 10
jobs
fg 1
```



## 4. Impostare `logrotate` per funzionare automaticamente
Di default, `logrotate` viene eseguito una volta al giorno tramite `cron`:
```bash
cat /var/log/syslog | grep logrotate
```
Oppure posso eseguirlo manualmente:
```bash
sudo /usr/sbin/logrotate /etc/logrotate.conf

```

📌 Riepilogo
1️⃣ Abbiamo generato log infiniti con uno script Bash.
2️⃣ Abbiamo creato una regola logrotate per gestire quei log.
3️⃣ Abbiamo testato la rotazione manualmente e verificato i file compressi.
4️⃣ Ora logrotate gestirà tutto in automatico ogni giorno.

🚀 Ora hai una configurazione base di gestione dei log su Ubuntu!
