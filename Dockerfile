# Immagini della KB. Senza --target si costruisce l'ultimo stadio, cioè la shell di sempre:
#   docker build -t bashbash .                                  shell Ubuntu con gli strumenti della KB
#   docker build --target systemd -t bashbash-systemd .         UGUALE + systemd come PID 1 e servizi veri
# La seconda la costruisce da sola docker compose nei laboratori che ne hanno bisogno (06, 08, 10);
# lo stadio osservabilita (la seconda + node_exporter) la costruisce il laboratorio 12.

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y \
    # shell e navigazione
    bash bash-completion man-db info less tree \
    # editor
    vim nano \
    # testo e regex
    grep gawk sed mawk diffutils patch \
    # file e archivi
    rsync tar gzip bzip2 xz-utils zip unzip file \
    # permessi e ricerca
    acl plocate \
    # scripting
    shellcheck bc python-is-python3 \
    # processi e risorse
    procps lsof htop \
    # rete
    curl wget jq \
    iproute2 net-tools iputils-ping dnsutils \
    traceroute iputils-tracepath mtr-tiny whois iftop tcpdump nmap netcat-openbsd ipcalc \
    openssh-client gnupg \
    # sistema e terminale
    sudo adduser cron logrotate tmux \
    # git e client mysql
    git mysql-client pv \
    && rm -rf /var/lib/apt/lists/*

# utente non-root per testare permessi/sudo
RUN useradd -m -s /bin/bash tester \
    && echo "tester:tester" | chpasswd \
    && usermod -aG sudo tester

WORKDIR /kb


# ---------------------------------------------------------------- systemd
# systemd come PID 1: systemctl, journalctl, timer, servizi veri (ssh, nginx, apache2, fail2ban, ufw).
# Va avviato con /sys/fs/cgroup in scrittura e CAP_SYS_ADMIN (vedi i compose.yaml dei laboratori):
# NON serve --privileged, quindi il container non vede i dischi della macchina.
FROM base AS systemd

RUN apt-get update && apt-get install -y \
    systemd systemd-sysv dbus libpam-systemd rsyslog \
    openssh-server nginx apache2 \
    ufw fail2ban iptables \
    && rm -rf /var/lib/apt/lists/* \
    # apache2 sulla 8080: la 80 è di nginx (entrambi attivi, come su tanti server di sviluppo)
    && sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf \
    # unit che in un container non hanno senso e finirebbero in "failed"
    && systemctl mask systemd-udevd.service systemd-udevd-kernel.socket systemd-udevd-control.socket \
        systemd-modules-load.service sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount \
        getty@tty1.service console-getty.service systemd-remount-fs.service \
    && systemctl enable ssh nginx apache2 rsyslog

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]


# ---------------------------------------------------------------- osservabilita
# Il server monitorato del laboratorio 12: systemd + node_exporter installato come su un server vero
# (binario in /usr/local/bin, utente di sistema, unit systemd) e i client promtool, amtool e logcli.
FROM systemd AS osservabilita

ARG NODE_EXPORTER=1.12.1
ARG PROMETHEUS=3.15.0
ARG ALERTMANAGER=0.34.1
ARG LOKI=3.5.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends stress-ng \
    && rm -rf /var/lib/apt/lists/* \
    && cd /tmp \
    # TARGETARCH c'è solo con BuildKit; senza, l'architettura la dice dpkg (amd64, arm64)
    && arch=${TARGETARCH:-$(dpkg --print-architecture)} \
    && for p in node_exporter-$NODE_EXPORTER prometheus-$PROMETHEUS alertmanager-$ALERTMANAGER; do \
         curl -fsSL "https://github.com/prometheus/${p%-*}/releases/download/v${p##*-}/$p.linux-$arch.tar.gz" | tar xz || exit 1; \
       done \
    && curl -fsSL "https://github.com/grafana/loki/releases/download/v$LOKI/logcli-linux-$arch.zip" -o logcli.zip \
    && unzip -q logcli.zip && mv logcli-linux-$arch logcli \
    && install -m 755 node_exporter-*/node_exporter prometheus-*/promtool alertmanager-*/amtool logcli /usr/local/bin/ \
    && rm -rf /tmp/* \
    && useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter \
    && install -d -o node_exporter -g node_exporter -m 775 /var/lib/node_exporter/textfile \
    && usermod -aG node_exporter tester \
    && printf '%s\n' \
       '[Unit]' \
       'Description=Prometheus node_exporter' \
       'After=network-online.target' \
       '' \
       '[Service]' \
       'User=node_exporter' \
       'ExecStart=/usr/local/bin/node_exporter --collector.systemd --collector.textfile.directory=/var/lib/node_exporter/textfile' \
       'Restart=on-failure' \
       '' \
       '[Install]' \
       'WantedBy=multi-user.target' > /etc/systemd/system/node_exporter.service \
    && systemctl enable node_exporter \
    # amtool legge l'indirizzo di Alertmanager da qui: niente --alertmanager.url a ogni comando
    && install -d /etc/amtool && echo 'alertmanager.url: http://alertmanager:9093' > /etc/amtool/config.yml \
    # logcli legge l'indirizzo di Loki da qui: niente --addr a ogni comando
    && echo 'export LOKI_ADDR=http://loki:3100' >> /etc/bash.bashrc \
    # stub_status per nginx-prometheus-exporter, solo dalla rete del laboratorio
    && printf '%s\n' \
       'server {' \
       '    listen 8000;' \
       '    location = /stub_status { stub_status; }' \
       '}' > /etc/nginx/conf.d/stato.conf


# ---------------------------------------------------------------- default
FROM base

# shell interattiva; per i laboratori delle aree vedi ./lab.sh
CMD ["bash"]
