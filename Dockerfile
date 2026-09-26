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
    rsync tar gzip xz-utils zip unzip file \
    # scripting
    shellcheck bc \
    # processi e risorse
    procps lsof htop \
    # rete
    curl wget jq \
    iproute2 net-tools iputils-ping dnsutils \
    openssh-client \
    # sistema e terminale
    sudo adduser cron logrotate tmux \
    # git e docker CLI
    git \
    && rm -rf /var/lib/apt/lists/*

# utente non-root per testare permessi/sudo
RUN useradd -m -s /bin/bash tester \
    && echo "tester:tester" | chpasswd \
    && usermod -aG sudo tester

WORKDIR /kb

# avvia cron in background + shell interattiva
CMD ["bash"]
