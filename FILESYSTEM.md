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

## Indice
* [bin](#bin)
* [boot](#boot)
* [dev](#dev)
* [etc](#etc)
* [home](#home)
* [lib](#lib)
* [media](#media)
* [mnt](#mnt)
* [opt](#opt)
* [proc](#proc)
* [root](#root)
* [run](#run)
* [sbin](#sbin)
* [srv](#srv)
* [sys](#sys)
* [tmp](#tmp)
* [usr](#usr)
* [var](#var)

## /bin
Contiene i binari essenziali per l'uso del sistema, necessari sia per l'utente normale che per l'amministratore di sistema.
* Esempi:
  * ls: elenca i file e le directory.
  * cp: copia file e directory.
  * mv: sposta o rinomina file e directory.
  * rm: rimuove file e directory.
  * bash: shell Bourne Again Shell.

## /boot
Contiene i file necessari per l'avvio del sistema (immagini del kernel, i file del bootloader, ramdisk).
* Esempi:
  * vmlinuz: immagine del kernel.
  * initrd.img: immagine del disco RAM iniziale.
* Sottodirectory:
  * grub/: directory del bootloader GRUB.
    * Es: /boot/grub/grub.cfg ==> file di config bootloader per cambiare le opzioni di avvio

## /dev
Contiene i file dei dispositivi, che permettono l’accesso alle periferiche hardware del sistema.
* Esempi:
  * sda1: rappresenta la prima partizione del primo disco rigido.
  * tty: terminali.
  * null: null device, che scarta qualsiasi input e produce un output vuoto.
  * loop0: dispositivo di loopback
    * Es: `sudo mount /dev/loop0 /mnt` per montare un file immagine come un dispositivo

## /etc
Contiene i file di config del sistema e gli script di avvio. Questi file sono specifici per ogni host e non contengono file binari.
* Esempi:
  * passwd: file degli utenti del sistema.
  * hosts: file host per la risoluzione dei nomi.
* Sottodirectory:
  * nginx/: configurazioni per il server web Nginx.
    * Es: /etc/nginx/nginx.conf ==> file di config di Nginx

## /home
Contiene le home directory degli utenti. Ogni utente ha una directory separata con i propri file personali e config. **E preferibile montarla in un
filesystem separato**
* Esempi:
  * `sudo adduser username` crea un nuovo utente e la sua directory `/home/username/`
* Sottodirectory:
  * /home/user1/: directory home per l'utente "user1".
  * /home/user2/: directory home per l'utente "user2".

## /lib
Contiene le librerie essenziali condivise, utilizzate dai binari presenti in `/bin` e `/sbin`.
* Esempi:
  * libc.so.6: libreria standard del C.
  * ld-linux.so.2: loader delle librerie dinamiche.
* Sottodirectory:
  * modules/: moduli del kernel.

## /media
Contiene i punti di montaggio per i dispositivi rimovibili montati automaticamente: CD-ROM, USB, floppy, ecc.
* Esempi:
  * /media/cdrom: punto di montaggio per i CD-ROM.
  * /media/usb: punto di montaggio per le chiavette USB
  * /media/username/usbdrive: se la chiavetta la inserisce un utente username nella sua sessione privata

## /mnt
Utilizzata unicamente per i montaggi temporanei. Solo gli admin di sistema possono montare file system temporanei qui.
* Montaggio disco temp: `sudo mount /dev/sdb1 /mnt` e l'accesso al disco sarà `cd /mnt`
* Esempi:
  * /mnt/backup: montaggio di un disco per backup.
  * /mnt/disk: montaggio temporaneo di un disco.

## /opt
Contiene software/pacchetti opzionali aggiuntivi che non fanno parte della distribuzione standard. Un pacchetto si installa nella cartella /opt/nome-pacchetto
* Esempi:
  * /opt/google/chrome: installazione di Google Chrome.
  * /opt/vscode: installazione di Visual Studio Code.

## /proc
Un file system virtuale che contiene tutta una serie di variabili interne al kernel (forniscono info sul sistema e sui processi in esecuzione). Fornisce un'interfaccia per queste info sul kernel.
* Esempi:
  * /proc/cpuinfo: informazioni sulla CPU.
  * /proc/meminfo: informazioni sulla memoria.
* Sottodirectory:
  * [PID]: directory per ogni processo in esecuzione, identificato dal suo PID (Process ID).

## /root
La directory home dell'utente root (l'admin di sistema).
* Esempi:
  * /root/.bashrc: file di configurazione della shell Bash per root.
  * /root/.ssh/: directory contenente le chiavi SSH dell'utente root.
    * `/root/.ssh/authorized_keys` configura l'accesso SSH per l'utente root

## /run
Contiene file temporanei (dati di run-time volatili) che descrivono lo stato del sistema. È montata come un file system temporaneo (tmpfs).
* Esempi:
  * /run/utmp: informazioni sugli utenti attualmente loggati
  * /run/systemd/: directory contenente i file di stato di systemd
* Sottodirectory:
  * systemd/: directory contenente i file di stato gestiti da systemd

## /sbin
Contiene i binari essenziali per l'admin del sistema. Questi comandi sono usati di solito dall'utente root
* Esempi:
  * ifconfig: configurazione delle interfacce di rete
  * reboot: riavvio del sistema
  * shutdown: spegnimento del sistema

## /srv
Contiene dati specifici del sito per servizi forniti dal sistema. Utilizzato per directory dei dati di server web, file FTP, ecc.
* Sottodirectory:
  * /srv/www: directory per i file del server web
  * /srv/ftp: directory per i file del server FTP

## /sys
Un file system virtuale che contiene informazioni e statistiche sui dispositivi e sui driver del kernel.
* Esempi:
  * /sys/class/net/eth0: informazioni sulla scheda di rete eth0
  * /sys/block/sda: informazioni sul dispositivo a blocchi sda
* Sottodirectory:
  * class/: classi di dispositivi
  * block/: dispositivi a blocchi

## /tmp
Contiene file temporanei creati da programmi. Di norma questi file vengono cancellati automaticamente al riavvio del sistema
* Esempi:
  * /tmp/tmpfile123: file temporaneo generato da un'applicazione
  * /tmp/session123: file temporaneo di sessione

## /usr
Contiene dati a cui si accede frequentemente per software e librerie di sistema. È suddivisa in ulteriori sottodirectory.
* Esempi:
  * /usr/bin/grep: comando per cercare del testo dentro i file.
  * /usr/lib/libpython3.8.so: libreria di Python.
  * /usr/local/bin: directory per binari installati localmente.
  * /usr/share/doc: documentazione dei pacchetti installati.
* Sottodirectory:
  * /usr/bin: binari per utenti non amministratori.
  * /usr/lib: librerie per programmi in /usr/bin e /usr/sbin.
  * /usr/local: programmi installati localmente.
  * /usr/share: dati condivisi, come documentazione e configurazioni.

## /var
Contiene file variabili come log, spool di stampa e file temporanei utilizzati da vari servizi di sistema. **E preferibile montarla in un
filesystem separato**
* Esempi:
  * /var/log/syslog: file di log di sistema.
  * /var/spool/cups: spool di stampa per CUPS (Common UNIX Printing System).
  * /var/tmp/file123: file temporaneo persistente.
* Sottodirectory:
  * /var/log: file di log.
  * /var/spool: spool di stampa e mail.
  * /var/tmp: file temporanei che possono essere mantenuti tra riavvii.

