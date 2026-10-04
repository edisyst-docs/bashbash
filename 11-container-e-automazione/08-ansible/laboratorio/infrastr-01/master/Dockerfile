FROM ubuntu:24.04

# A failure before a pipe must fail the RUN too (hadolint DL4006)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends ansible openssh-client openssh-server sshpass && \
    rm -rf /var/lib/apt/lists/*

# Create the SSH and Ansible directories, generate the master's SSH keys
# and disable host key checking
RUN mkdir -p /run/sshd /etc/ansible && \
    ssh-keygen -q -N "" -f /root/.ssh/id_rsa && \
    printf 'Host *\n\tStrictHostKeyChecking no\n' > /root/.ssh/config

# Copy the Ansible configuration files
COPY ansible/ /etc/ansible/

CMD ["/usr/sbin/sshd", "-D"]
