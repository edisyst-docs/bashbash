FROM ubuntu:24.04

# A failure before a pipe must fail the RUN too (hadolint DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install SSH server and Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server python3 sudo && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH server
RUN mkdir -p /run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Create user "edoardo" with root privileges
RUN useradd -m -s /bin/bash -G sudo edoardo && \
    echo "edoardo:edopassword" | chpasswd && \
    echo "edoardo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

CMD ["/usr/sbin/sshd", "-D"]
