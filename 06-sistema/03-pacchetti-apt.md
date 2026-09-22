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
