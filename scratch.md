
```bash

uptime # orario, utenti connessi, carico di lavoro sulla macchina
last   # elenca login/logout di tutti gli utenti da che esiste la macchina

df -h          # elenca i file nel disco fisso 
df -h --total  # mette anche il totale alla fine

sudo wall messaggio # broadcast del messaggio a tutti gli utenti. Per testarlo dovrei creare 2 utenti in 2 terminali
sudo write messaggio # invio del messaggio a un solo utente. Per testarlo dovrei creare 2 utenti in 2 terminali

who # mostra gli utenti loggati sul sistema
w   # mostra gli utenti loggati sul sistema con altre info
uname -a # info sul sistema operativo

htop # mostra le info sulle risorse usate da ogni processo
free # mostra le risorse di sistema in utilizzo e disponibili
mount | column -t # mostra i dischi

sort file.txt # riordina in ordine alfabetico le righe dei file.txt
sort -r file.txt # riordina in ordine alfabetico inverso

shutdown -r now # riavvia adesso
shutdown -h now # spegne  adesso
shutdown -h +10 # spegne  fra 10 min

whatis ls # dice solo cosa fa il comando
ls --help # helper del comando
man ls    # helper più dettagliato 
info ls   # helper più dettagliato 

tail file      # mostra le ultime 10 righe del file
tail -n 3 file # mostra le ultime 3  righe del file

cmatrix # inutile, è Matrix
```
