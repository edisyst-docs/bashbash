#!/usr/bin/env bash
# soluzioni.sh FASE N - le soluzioni di riferimento e l'ambiente degli esercizi di 13-esercizi.md (area 06).
#   soluzioni.sh prepara N    porta il sistema nello stato di partenza dell'esercizio N
#   soluzioni.sh risolvi N    la soluzione di riferimento
#   soluzioni.sh controllo N  stampa lo stato che il controllo guarda (vuoto se basta l'output)
#   soluzioni.sh pulisci N    riporta il sistema com'era (utenti, unit, mount, cron... creati dall'esercizio)
# La usa verifica.sh. Gira come root nel laboratorio 06 (systemd): tocca il sistema vero del container.
set -uo pipefail
fase=${1:?uso: $0 prepara|risolvi|controllo|pulisci N}
n=${2:?uso: $0 FASE N}
CURSORE=${VERIFICA_CURSORE:-}

prepara() {
    case $n in
        3)  useradd -m deploy 2> /dev/null ;;
        18) touch /var/log/miaapp.log ;;
    esac
}
pulisci() {
    case $n in
        1)  userdel -r deploy 2> /dev/null ;;
        2)  userdel -r anna 2> /dev/null; groupdel sviluppo 2> /dev/null ;;
        3)  rm -f /etc/sudoers.d/deploy; userdel -r deploy 2> /dev/null ;;
        7)  umount /mnt/dati 2> /dev/null; rmdir /mnt/dati 2> /dev/null ;;
        10) timedatectl set-timezone Etc/UTC ;;
        11) systemctl disable --now hello 2> /dev/null; rm -f /etc/systemd/system/hello.service; systemctl daemon-reload ;;
        12) systemctl stop ciao.timer 2> /dev/null; rm -f /etc/systemd/system/ciao.timer /etc/systemd/system/ciao.service /tmp/ciao.txt; systemctl daemon-reload ;;
        15) crontab -r 2> /dev/null ;;
        17) tmux kill-server 2> /dev/null ;;
        18) rm -f /etc/logrotate.d/miaapp /var/log/miaapp.log ;;
    esac
    return 0
}
controllo() {
    case $n in
        1)  getent passwd deploy | cut -d: -f1,6,7; id -nG deploy 2>&1 | tr ' ' '\n' | sort | tr '\n' ' '; echo ;;
        2)  getent group sviluppo; getent passwd anna | cut -d: -f1 ;;
        3)  visudo -cf /etc/sudoers.d/deploy 2>&1; stat -c %a /etc/sudoers.d/deploy; sudo -l -U deploy 2>&1 | tail -1 ;;
        7)  findmnt -no FSTYPE,SIZE /mnt/dati ;;
        10) readlink -f /etc/localtime | sed 's|.*/zoneinfo/||'; date +%Z ;;
        11) systemctl is-active hello; systemctl is-enabled hello ;;
        12) sleep 3; cat /tmp/ciao.txt 2>&1 ;;
        13) journalctl -t esercizio -p warning -o cat --no-pager ${CURSORE:+--after-cursor="$CURSORE"} ;;
        15) crontab -l 2>&1 ;;
        16) e2label disco.img 2>&1; stat -c %s disco.img 2>&1 ;;
        17) tmux ls 2>&1 | cut -d: -f1 ;;
        18) logrotate -d /etc/logrotate.d/miaapp 2>&1 | grep 'rotating pattern' ;;
    esac
    return 0
}
risolvi() {
    case $n in
        1)  useradd -m -s /bin/bash -G www-data deploy ;;
        2)  groupadd -g 2000 sviluppo; useradd -m -G sviluppo anna ;;
        3)  echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx' > /etc/sudoers.d/deploy; chmod 440 /etc/sudoers.d/deploy ;;
        4)  dpkg -S /usr/bin/ls | cut -d: -f1 ;;
        5)  dpkg-query -W -f='${Version}\n' nginx ;;
        6)  dpkg -L cron | grep '^/usr/sbin/' ;;
        7)  mkdir -p /mnt/dati; mount -t tmpfs -o size=16M tmpfs /mnt/dati ;;
        8)  LC_ALL=C date -d '2026-10-05 +30 days' +%F ;;
        9)  LC_ALL=C date -d 2026-10-05 +%A ;;
        10) timedatectl set-timezone Europe/Rome ;;
        11) printf '[Unit]\nDescription=Hello\n\n[Service]\nExecStart=/bin/sleep infinity\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/hello.service
            systemctl daemon-reload; systemctl enable --now hello ;;
        12) printf '[Service]\nType=oneshot\nExecStart=/bin/sh -c "echo ok > /tmp/ciao.txt"\n' > /etc/systemd/system/ciao.service
            printf '[Timer]\nOnActiveSec=1s\n\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/ciao.timer
            systemctl daemon-reload; systemctl start ciao.timer ;;
        13) logger -t esercizio -p user.warning "ciao dal journal" ;;
        14) ss -ltnpH 'sport = :80' | grep -o '"[a-z0-9]*"' | head -1 | tr -d '"' ;;
        15) printf '30 3 * * * /usr/local/bin/backup.sh\n' | crontab - ;;
        16) dd if=/dev/zero of=disco.img bs=1M count=8 2> /dev/null; mkfs.ext4 -q -L DATI disco.img ;;
        17) tmux new -d -s lavoro 'sleep 300' ;;
        18) printf '/var/log/miaapp.log {\n    weekly\n    rotate 4\n    missingok\n}\n' > /etc/logrotate.d/miaapp ;;
        *)  echo "esercizi da 1 a 18" >&2; exit 2 ;;
    esac
}
case $fase in
    prepara|risolvi|controllo|pulisci) "$fase" ;;
    *) echo "fasi: prepara, risolvi, controllo, pulisci" >&2; exit 2 ;;
esac
