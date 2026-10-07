# Immagini della KB. Senza --target si costruisce l'ultimo stadio, cioè la shell di sempre:
#   docker build -t bashbash .                                  shell Ubuntu con gli strumenti della KB
#   docker build --target systemd -t bashbash-systemd .         UGUALE + systemd come PID 1 e servizi veri
#   docker build --target dati -t bashbash-dati .               UGUALE alla prima + i client di RabbitMQ, Kafka e MongoDB
# Le ultime due le costruisce da sola docker compose nei laboratori che ne hanno bisogno (systemd: 06, 07, 08, 10; dati: 09);
# lo stadio osservabilita (systemd + node_exporter) la costruisce il laboratorio 12.
# I client dei servizi di dati (circa 340 MB) stanno in uno stadio a parte: gli altri laboratori non li portano con sé.

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# un errore prima di una pipe fa fallire tutto il RUN (DL4006); vale anche per gli stadi successivi
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# l'immagine ubuntu è "minimizzata": dpkg scarta le pagine di manuale (e /usr/share/doc). Qui servono: man, apropos e
# whatis degli esempi di 01-basi/03 non funzionerebbero. Tolta l'esclusione, i pacchetti che segue installa le portano
#
# Stessa RUN, per la rete dei runner di GitHub: a volte archive.ubuntu.com (o security.ubuntu.com) non risponde per ore e
# apt resta a timeout su ogni file (visto: 220 pacchetti da 41 secondi l'uno, il job ucciso dopo 30 minuti). Due difese:
#  - apt riprova ogni file fino a 5 volte e non aspetta più di 20 secondi per tentativo (guasti brevi);
#  - se uno dei due mirror non accetta nemmeno la connessione, si passa al mirror di Azure, lo stesso che usano le immagini
#    dei runner (guasto lungo). Sulle reti dove i mirror rispondono non cambia niente; su arm64 (ports.ubuntu.com) neppure.
# Vale anche per gli stadi successivi e per ciò che i laboratori installano a runtime, perché partono da questo.
RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes \
    && printf 'Acquire::Retries "5";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\n' > /etc/apt/apt.conf.d/80-rete \
    && for h in archive.ubuntu.com security.ubuntu.com; do \
         timeout 8 bash -c "exec 3<>/dev/tcp/$h/80" 2>/dev/null || { \
           echo "$h non raggiungibile: uso azure.archive.ubuntu.com"; \
           sed -Ei 's#http://(archive|security)\.ubuntu\.com/#http://azure.archive.ubuntu.com/#' /etc/apt/sources.list.d/ubuntu.sources; \
           break; }; \
       done

# ambiente di studio: servono anche i pacchetti raccomandati (man-db, bash-completion, ca-certificates...),
# quindi niente --no-install-recommends (DL3015)
# hadolint ignore=DL3015
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
    # build, test e ricerca veloce (fdfind e batcat: i nomi Debian di fd e bat)
    make bats bats-assert bats-support ripgrep fzf fd-find bat ncdu \
    # processi e risorse
    procps lsof htop strace ltrace sysstat \
    # perf: il pacchetto cerca la versione del kernel dell'host, che nel container non c'è; il collegamento sotto lo aggira
    linux-tools-common linux-tools-generic \
    # rete
    curl wget jq \
    iproute2 net-tools iputils-ping dnsutils \
    traceroute iputils-tracepath mtr-tiny whois iftop tcpdump nmap netcat-openbsd ipcalc \
    openssh-client gnupg wireguard-tools \
    # sistema e terminale
    sudo adduser cron logrotate tmux \
    # git e client mysql
    git mysql-client pv \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(ls /usr/lib/linux-tools/*/perf)" /usr/local/bin/perf

# i pacchetti già presenti nell'immagine base (coreutils, bash, util-linux...) erano stati installati SENZA le pagine di
# manuale: si reinstallano ora che l'esclusione è tolta, così "man ls" e "man bash" funzionano
# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y --reinstall \
    coreutils bash findutils diffutils util-linux login passwd procps \
    && rm -rf /var/lib/apt/lists/* \
    # il wrapper "man" dell'immagine minimizzata (stampa solo un avviso) si toglie come fa unminimize
    && rm -f /usr/bin/man && dpkg-divert --quiet --remove --rename /usr/bin/man \
    && mandb -q

# restic: l'ultima versione dal sito del progetto (apt ha una 0.16), con lo SHA-256 fissato per ogni architettura
ARG RESTIC=0.19.1
ARG RESTIC_SHA256_AMD64=f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c
ARG RESTIC_SHA256_ARM64=a5f64aaab53d51e311fa3829124c5b703f2d14cf187d8640b6be3b2b49376465
ARG TARGETARCH
WORKDIR /tmp
RUN arch=${TARGETARCH:-$(dpkg --print-architecture)} \
    && curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 "https://github.com/restic/restic/releases/download/v$RESTIC/restic_${RESTIC}_linux_$arch.bz2" -o restic.bz2 \
    && if [ "$arch" = arm64 ]; then sha=$RESTIC_SHA256_ARM64; else sha=$RESTIC_SHA256_AMD64; fi \
    && echo "$sha  restic.bz2" | sha256sum -c - \
    && bunzip2 restic.bz2 \
    && install -m 755 restic /usr/local/bin/restic \
    && rm -f /tmp/restic

# utente non-root per testare permessi/sudo
RUN useradd -m -s /bin/bash tester \
    && echo "tester:tester" | chpasswd \
    && usermod -aG sudo tester

WORKDIR /kb


# ---------------------------------------------------------------- systemd
# systemd come PID 1: systemctl, journalctl, timer, servizi veri (ssh, nginx, apache2, fail2ban, ufw).
# Va avviato con un cgroup privato (cgroup: private), CAP_SYS_ADMIN e senza AppArmor (vedi i compose.yaml dei
# laboratori). Docker monta il cgroup del container in sola lettura: avvia-systemd lo rimonta in scrittura, poi
# passa a /sbin/init. Così systemd vede solo il proprio cgroup, non quello della macchina, e funziona sia su
# Docker Desktop sia su un Linux con systemd (anche i runner di GitHub Actions).
# NON serve --privileged, quindi il container non vede i dischi della macchina.
FROM base AS systemd

# hadolint ignore=DL3015
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

COPY --chmod=755 <<'EOF' /usr/local/sbin/avvia-systemd
#!/bin/sh
# avvia-systemd: rende scrivibile il cgroup privato del container, poi systemd diventa il PID 1
if ! mount -o remount,rw /sys/fs/cgroup; then
    echo "avvia-systemd: cgroup in sola lettura (servono CAP_SYS_ADMIN e AppArmor unconfined)" >&2
    exit 1
fi
exec /sbin/init
EOF

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/local/sbin/avvia-systemd"]


# ---------------------------------------------------------------- osservabilita
# Il server monitorato del laboratorio 12: systemd + node_exporter installato come su un server vero
# (binario in /usr/local/bin, utente di sistema, unit systemd) e i client promtool, amtool e logcli.
FROM systemd AS osservabilita

# hadolint non segue l'ereditarietà tra stadi: la SHELL con pipefail va ripetuta (DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG NODE_EXPORTER=1.12.1
ARG PROMETHEUS=3.15.0
ARG ALERTMANAGER=0.34.1
ARG LOKI=3.7.8
ARG TARGETARCH

WORKDIR /tmp
RUN apt-get update && apt-get install -y --no-install-recommends stress-ng \
    && rm -rf /var/lib/apt/lists/* \
    # TARGETARCH c'è solo con BuildKit; senza, l'architettura la dice dpkg (amd64, arm64)
    && arch=${TARGETARCH:-$(dpkg --print-architecture)} \
    && for p in node_exporter-$NODE_EXPORTER prometheus-$PROMETHEUS alertmanager-$ALERTMANAGER; do \
         curl -fsSL "https://github.com/prometheus/${p%-*}/releases/download/v${p##*-}/$p.linux-$arch.tar.gz" | tar xz || exit 1; \
       done \
    && curl -fsSL "https://github.com/grafana/loki/releases/download/v$LOKI/logcli-linux-$arch.zip" -o logcli.zip \
    && unzip -q logcli.zip && mv "logcli-linux-$arch" logcli \
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
WORKDIR /kb


# ---------------------------------------------------------------- dati
# La shell del laboratorio 09: la base + i client dei servizi di quell'area (RabbitMQ, Kafka, MongoDB). Sono circa 340 MB
# (mongosh e gli strumenti di backup sono scaricati, non in apt) e servono a un solo laboratorio, per questo non stanno in "base":
# gli altri laboratori e le immagini systemd non li portano con sé. La costruisce da solo docker compose (vedi 09-strumenti/lab).
FROM base AS dati

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# amqp-publish e amqp-consume per RabbitMQ, kcat per Kafka
# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y amqp-tools kcat \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
WORKDIR /tmp
# mongosh e gli strumenti di backup di MongoDB (mongodump, mongorestore...): non sono in apt; SHA-256 fissato per architettura
ARG MONGOSH=2.13.0
ARG MONGOSH_SHA256_AMD64=b2089e67641a28aa621476c4d62c69f66b9a41484baba24d8a8b1f5f96e92d0b
ARG MONGOSH_SHA256_ARM64=a124ec6680c70ceabc61696bbd110f0da05d7c52524ed402ae9511b5aec7fe32
ARG MONGOTOOLS=100.13.0
ARG MONGOTOOLS_SHA256_AMD64=49f00ac68f25451c3e936b06011df38009f8418dafb5aa425c2810e59fd02029
ARG MONGOTOOLS_SHA256_ARM64=0dad172b672d574d03e11b6d2c6e3e8bf0306be9578865a637af11cad9e239ef
RUN arch=${TARGETARCH:-$(dpkg --print-architecture)} \
    && if [ "$arch" = arm64 ]; then sh_arch=arm64; sh=$MONGOSH_SHA256_ARM64; tl_arch=arm64; th=$MONGOTOOLS_SHA256_ARM64; \
       else sh_arch=x64; sh=$MONGOSH_SHA256_AMD64; tl_arch=x86_64; th=$MONGOTOOLS_SHA256_AMD64; fi \
    && curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 "https://github.com/mongodb-js/mongosh/releases/download/v$MONGOSH/mongosh-$MONGOSH-linux-$sh_arch.tgz" -o mongosh.tgz \
    && echo "$sh  mongosh.tgz" | sha256sum -c - \
    && curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2404-$tl_arch-$MONGOTOOLS.tgz" -o tools.tgz \
    && echo "$th  tools.tgz" | sha256sum -c - \
    && tar xzf mongosh.tgz && tar xzf tools.tgz \
    && install -m 755 mongosh-*/bin/mongosh /usr/local/bin/ \
    && install -m 755 mongodb-database-tools-*/bin/* /usr/local/bin/ \
    && rm -rf /tmp/*

WORKDIR /kb


# ---------------------------------------------------------------- default
FROM base

# shell interattiva; per i laboratori delle aree vedi ./lab.sh
CMD ["bash"]
