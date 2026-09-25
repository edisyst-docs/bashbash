# Gestione pacchetti (apt)

## Cercare e ispezionare
```bash
apt-cache search pdf   # cerca ad esempio programmi per PDF
apt-cache pkgnames pdf # cerca programmi il cui nome inizia con "pdf"
apt-cache show xpdf    # mostra info sul programma "xpdf"
apt-cache showpkg xpdf # info sulle dipendenze
apt-cache depends xpdf # elenco dipendenze di xpdf
apt-cache stats        # statistiche sulla cache dei pacchetti
apt-cache unmet        # quali dipendenze non sono soddisfatte
```

## Installare e rimuovere
```bash
apt-get -s install virtualbox # con -s simula l'install, così vedo se ci sarebbero errori/problemi
ls /var/cache/apt/archives/   # elenco pacchetti scaricati (non necessariamente anche installati)
apt-get remove virtualbox     # lo elimina ma lascia i pacchetti delle dipendenze ormai inutili
apt-get autoremove virtualbox # lo elimina con tutte le dipendenze
```

## Il comando apt (interfaccia moderna)
```bash
apt list          # restituisce una lista immensa
apt list ssh      # mostra le versioni disponibili per questo particolare pacchetto
apt show ssh      # dettagli sul software
apt search webcam # trova software per la webcam
```

## Aggiornare e manutenere
```bash
sudo apt update                    # aggiorna l'ELENCO dei pacchetti disponibili (non installa niente)
apt list --upgradable              # cosa verrebbe aggiornato
sudo apt upgrade                   # aggiorna i pacchetti installati
sudo apt full-upgrade              # UGUALE ma può anche rimuovere/aggiungere pacchetti per risolvere le dipendenze
sudo apt purge nginx               # rimuove il pacchetto E i suoi file di configurazione (remove li lascia)
sudo apt autoremove --purge        # rimuove le dipendenze non più usate da nessuno
sudo apt clean                     # svuota la cache dei .deb scaricati in /var/cache/apt/archives/
```

## Esempi pratici
```bash
dpkg -S /usr/bin/convert           # a quale pacchetto appartiene questo file
dpkg -L nginx                      # quali file ha installato il pacchetto nginx
dpkg -l | grep php                 # pacchetti installati che contengono "php" (ii = installato)
apt-cache policy php8.3            # versione installata, candidata e da quale repository arriva
apt-cache rdepends --installed libssl3 # quali pacchetti installati dipendono da libssl3

sudo apt-mark hold mysql-server    # BLOCCA gli aggiornamenti di un pacchetto (es. per non cambiare versione di MySQL per sbaglio)
apt-mark showhold                  # elenco dei pacchetti bloccati
sudo apt-mark unhold mysql-server  # sblocca

sudo apt install ./pacchetto.deb   # installa un .deb scaricato risolvendo le dipendenze (il ./ è obbligatorio)
```

Installazione non interattiva (script, Dockerfile, Ansible):
```bash
export DEBIAN_FRONTEND=noninteractive  # niente finestre di dialogo che bloccano lo script
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    nginx php8.3-fpm php8.3-mysql php8.3-mbstring php8.3-xml unzip  # --no-install-recommends: solo il necessario, immagine più leggera
```
> **NOTA**: negli script usare `apt-get`, non `apt`: l'interfaccia di `apt` può cambiare
> tra una versione e l'altra e stampa un avviso quando non è usato in modo interattivo.
