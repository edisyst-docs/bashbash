# Rete e identità della macchina

## Hostname e sistema operativo
```bash
hostname    # hostname della macchina
hostname -i # IP
hostnamectl # info complete su hostname, sistema operativo, kernel, architettura

uname -a    # info sul sistema operativo e sul kernel
uname -r    # solo la versione del kernel (utile per i percorsi in /lib/modules/)
```

## Connettività
```bash
ping 8.8.8.8 # verifica semplice di connessione
```

Vedi anche: [../04-processi/01-ps-e-kill.md](../04-processi/01-ps-e-kill.md) per `lsof -i`, che elenca le connessioni di rete aperte.
