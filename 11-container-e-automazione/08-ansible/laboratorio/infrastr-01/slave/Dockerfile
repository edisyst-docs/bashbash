FROM ubuntu:24.04

# A failure before a pipe must fail the RUN too (hadolint DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install SSH server and Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server python3 && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH server
RUN mkdir -p /run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

CMD ["/usr/sbin/sshd", "-D"]
