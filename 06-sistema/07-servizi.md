# Servizi, spegnimento e messaggi broadcast

## systemd
```bash
systemctl reload apache2  # ricarica la configurazione di Apache dopo aver modificato le conf dei sites
systemctl status apache2  # stato del servizio
systemctl restart apache2 # riavvio completo del servizio
```

## Spegnimento e riavvio
```bash
shutdown -r now # riavvia adesso
shutdown -h now # spegne  adesso
shutdown    now # UGUALE
shutdown  20:40 # spegne alle 20:40
shutdown -h +10 # spegne fra 10 min
shutdown -c     # annulla lo spegnimento programmato
```

## Messaggi agli altri utenti
```bash
sudo wall messaggio  # broadcast del messaggio a tutti gli utenti connessi
sudo write utente    # invio del messaggio a un solo utente
```
> Per testarli servono almeno 2 utenti loggati su 2 terminali diversi.

## Librerie di un eseguibile
```bash
ldd /bin/pwd /sbin/pwck # mostra le dipendenze di questi eseguibili, quali librerie servono per funzionare
ldconfig -p             # per ogni libreria stampa il path sul file system: i comandi sono tutti link simbolici
```

## Curiosità
```bash
cmatrix # inutile, è Matrix
```
