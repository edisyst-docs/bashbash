# Risorse di sistema

## Hardware e memoria
```bash
lshw         # info sull'hardware della macchina
lshw -short  # UGUALE ma senza tante info inutili
lscpu        # info sulla CPU
lsmem        # info sulla memoria
free -h      # mostra la memoria libera e occupata in formato human readable
```

## Lo pseudo-filesystem /proc
```bash
cat /proc/cpuinfo # info sulla CPU: memoria, modello, ecc.
cat /proc/meminfo # info sulla memoria
ls  /proc/        # ci sono tante cartelle chiamate coi PID dei processi in esecuzione: se chiudo un processo scompare la cartella corrispondente
```

## Spazio su disco
```bash
du -hs /home/edo/*     # restituisce la dimensione di ogni elemento dentro /home/edo/
du -hs /home/edo/      # restituisce la dimensione totale della cartella /home/edo/
df -h                  # mostra spazio occupato e libero (per ogni partizione)
df -h --total          # aggiunge il totale alla fine
df -h /dev/sda1        # uso dello spazio su una partizione specifica
df -hT                 # mostra anche il tipo di file system
df -hT | grep -v tmpfs # calcolo escludendo i file system temporanei (es: tmpfs)
```

## watch: ripetere un comando a intervalli
```bash
watch ls -lh /var/log/      # esegue "ls -lh" ogni 2 secondi
watch -n 5 ls -lh /var/log/ # esegue "ls -lh" ogni 5 secondi
```

## Priorità e niceness
La **niceness** è la disponibilità di un processo a cedere risorse agli altri.
```bash
ps -l                   # mostra anche priorità e niceness dei processi
nice -n 5 sleep 1000&   # lancia un processo in background con niceness 5
nice -n 10 sleep 1000&  # lancia un processo in background con niceness 10
ps -l                   # questi processi hanno priorità e niceness differenti dal default
renice -n 7 95740       # cambia la priorità del PID 95740 a 7. Posso solo aumentare il valore se non sono root
renice -n 10 -u edoardo # cambia la priorità di tutti i processi di edoardo a 10
```
Il valore di nice è tra **-20** e **19**, dove -20 è la priorità più alta e 19 la più bassa.
Solo root può abbassare il valore di nice (cioè alzare la priorità) e creare un processo con niceness negativa.

Si può fare il renice anche da dentro `top`, premendo `r`: vedi [03-top-htop.md](03-top-htop.md).
