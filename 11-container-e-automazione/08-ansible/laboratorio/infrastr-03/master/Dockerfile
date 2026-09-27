FROM ubuntu:latest

# Install necessary packages
RUN apt-get update && \
    apt-get install -y ansible openssh-client openssh-server sshpass sudo python3-pymysql && \
    apt-get clean

# Create required directory for SSH
RUN mkdir -p /run/sshd

# Create Ansible directory
RUN mkdir -p /etc/ansible

# Generate SSH keys for the master
RUN ssh-keygen -q -N "" -f /root/.ssh/id_rsa

# Add ssh config to disable host key checking
RUN echo "Host *\n\tStrictHostKeyChecking no\n" > /root/.ssh/config

# Create user "edoardo" with root privileges
RUN useradd -m -s /bin/bash -G sudo edoardo && \
    echo "edoardo:edopassword" | chpasswd && \
    echo "edoardo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy the Ansible configuration files
COPY ansible/ /etc/ansible/

CMD ["/usr/sbin/sshd", "-D"]
