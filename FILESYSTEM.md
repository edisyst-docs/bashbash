# FILE SYSTEM DEBIAN/UBUNTU

```plaintext
/
├── bin
│   ├── ls
│   ├── cp
│   └── mv
├── boot
│   ├── vmlinuz
│   ├── initrd.img
│   └── grub/
├── dev
│   ├── sda1
│   ├── tty
│   └── null
├── etc
│   ├── passwd
│   ├── hosts
│   └── nginx/nginx.conf
├── home
│   ├── user1/
│   └── user2/
├── lib
│   ├── libc.so.6
│   └── ld-linux.so.2
├── media
│   ├── cdrom
│   └── usb
├── mnt
│   ├── backup
│   └── disk
├── opt
│   ├── google/
│   └── vscode/
├── proc
│   ├── cpuinfo
│   ├── meminfo
│   └── [PID]/
├── root
│   ├── .bashrc
│   └── .ssh/
├── run
│   ├── utmp
│   └── systemd/
├── sbin
│   ├── ifconfig
│   ├── reboot
│   └── shutdown
├── srv
│   ├── www/
│   └── ftp/
├── sys
│   ├── class/
│   └── block/
├── tmp
│   ├── tmpfile123
│   └── session123
├── usr
│   ├── bin/
│   ├── lib/
│   ├── local/
│   └── share/
├── var
│   ├── log/
│   ├── spool/
│   └── tmp/
```

## /bin
Contiene i binari essenziali per l'uso del sistema, necessari sia per l'utente normale che per l'amministratore di sistema.
* Esempi:
  * ls: elenca i file e le directory.
  * cp: copia file e directory.
  * mv: sposta o rinomina file e directory.
  * rm: rimuove file e directory.
  * bash: shell Bourne Again Shell.

## /boot
Contiene i file necessari per l'avvio del sistema, inclusi il kernel e i file del bootloader.
* Sottodirectory:
  * grub/: directory del bootloader GRUB.
* Esempi:
  * vmlinuz: immagine del kernel.
  * initrd.img: immagine del disco RAM iniziale.

## /dev
Contiene i file dei dispositivi. Questi file rappresentano le periferiche hardware del sistema.
* Esempi:
  * sda1: rappresenta la prima partizione del primo disco rigido.
  * tty: terminali.
  * null: null device, che scarta qualsiasi input e produce un output vuoto.

## /etc
Contiene i file di config del sistema. Questi file sono specifici per ogni host e non contengono file binari.
* Sottodirectory:
  * nginx/: configurazioni per il server web Nginx.
* Esempi:
  * passwd: file degli utenti del sistema.
  * hosts: file host per la risoluzione dei nomi.
  * nginx/nginx.conf: file di configurazione principale di Nginx.

## /home
Contiene le directory home degli utenti. Ogni utente ha una directory separata che contiene i propri file personali e config.
* Esempi:
  * /home/user1/: directory home per l'utente "user1".
  * /home/user2/: directory home per l'utente "user2".

## /lib
Contiene le librerie essenziali condivise utilizzate dai binari presenti in `/bin` e `/sbin`.
* Sottodirectory:
  * modules/: moduli del kernel.
* Esempi:
  * libc.so.6: libreria standard del C.
  * ld-linux.so.2: loader delle librerie dinamiche.

## /media
Contiene i punti di montaggio per i dispositivi rimovibili montati automaticamente: CD-ROM, USB, ecc.
* Esempi:
  * /media/cdrom: punto di montaggio per i CD-ROM.
  * /media/usb: punto di montaggio per le chiavette USB.

## /mnt
Utilizzata per montare temporaneamente i file system. Gli amministratori di sistema possono montare file system temporanei qui.
* Esempi:
  * /mnt/backup: montaggio di un disco per backup.
  * /mnt/disk: montaggio temporaneo di un disco.

## /opt
Contiene software opzionale aggiuntivo che non fa parte della distribuzione standard. Spesso utilizzato per pacchetti di software aggiuntivi.
* Esempi:
  * /opt/google/chrome: installazione di Google Chrome.
  * /opt/vscode: installazione di Visual Studio Code.

## /proc
Un file system virtuale che contiene info sul sistema e sui processi in esecuzione. Fornisce un'interfaccia per il kernel.
* Sottodirectory:
  * [PID]: directory per ogni processo in esecuzione, identificato dal suo PID (Process ID).
* Esempi:
  * /proc/cpuinfo: informazioni sulla CPU.
  * /proc/meminfo: informazioni sulla memoria.

## /root
La directory home dell'utente root (l'amministratore di sistema).
* Esempi:
  * /root/.bashrc: file di configurazione della shell Bash per root.
  * /root/.ssh/: directory contenente le chiavi SSH dell'utente root.

## /run
Contiene file temporanei che descrivono lo stato del sistema dal suo avvio. È montata come un file system temporaneo (tmpfs).
* Sottodirectory:
  * systemd/: directory con informazioni di sistema gestite da systemd.
* Esempi:
  * /run/utmp: informazioni sugli utenti attualmente loggati.
  * /run/systemd/: directory contenente i file di stato di systemd.

## /sbin
Contiene i binari essenziali per l'amministrazione del sistema. Questi comandi sono usati di solito dall'utente root.
* Esempi:
  * ifconfig: configurazione delle interfacce di rete.
  * reboot: riavvio del sistema.
  * shutdown: spegnimento del sistema.

## /srv
Contiene dati specifici del sito per servizi forniti dal sistema. Utilizzato per directory dei dati di server web, file FTP, ecc.
* Esempi:
  * /srv/www: directory per i file del server web.
  * /srv/ftp: directory per i file del server FTP.

## /sys
Un file system virtuale che contiene informazioni e statistiche sui dispositivi e sui driver del kernel.
* Sottodirectory:
  * class/: classi di dispositivi.
  * block/: dispositivi a blocchi.
* Esempi:
  * /sys/class/net/eth0: informazioni sulla scheda di rete eth0.
  * /sys/block/sda: informazioni sul dispositivo a blocchi sda.

## /tmp
Contiene file temporanei creati da programmi. Questi file possono essere cancellati automaticamente al riavvio del sistema.
* Esempi:
  * /tmp/tmpfile123: file temporaneo generato da un'applicazione.
  * /tmp/session123: file temporaneo di sessione.

## /usr
Contiene dati a cui si accede frequentemente per software e librerie di sistema. È suddivisa in ulteriori sottodirectory.
* Sottodirectory:
  * /usr/bin: binari per utenti non amministratori.
  * /usr/lib: librerie per programmi in /usr/bin e /usr/sbin.
  * /usr/local: programmi installati localmente.
  * /usr/share: dati condivisi, come documentazione e configurazioni.
* Esempi:
  * /usr/bin/grep: comando per cercare testo nei file.
  * /usr/lib/libpython3.8.so: libreria di Python.
  * /usr/local/bin: directory per binari installati localmente.
  * /usr/share/doc: documentazione dei pacchetti installati.

## /var
Contiene file variabili come log, spool di stampa e file temporanei utilizzati da vari servizi di sistema.
* Sottodirectory:
  * /var/log: file di log.
  * /var/spool: spool di stampa e mail.
  * /var/tmp: file temporanei che possono essere mantenuti tra riavvii.
* Esempi:
  * /var/log/syslog: file di log di sistema.
  * /var/spool/cups: spool di stampa per CUPS (Common UNIX Printing System).
  * /var/tmp/file123: file temporaneo persistente.

