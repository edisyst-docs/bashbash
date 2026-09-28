FROM ubuntu:24.04

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
    traceroute mtr-tiny whois iftop tcpdump nmap netcat-openbsd ipcalc \
    openssh-client gnupg \
    # sistema e terminale
    sudo adduser cron logrotate tmux \
    # git
    git \
    && rm -rf /var/lib/apt/lists/*

# utente non-root per testare permessi/sudo
RUN useradd -m -s /bin/bash tester \
    && echo "tester:tester" | chpasswd \
    && usermod -aG sudo tester

WORKDIR /kb

# shell interattiva; per i laboratori delle aree vedi ./lab.sh
CMD ["bash"]
