FROM ubuntu:latest

# Install SSH server and Python
RUN apt-get update && \
    apt-get install -y openssh-server python3 sudo && \
    apt-get clean

# Configure SSH server
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Create user "edoardo" with root privileges
RUN useradd -m -s /bin/bash -G sudo edoardo && \
    echo "edoardo:edopassword" | chpasswd && \
    echo "edoardo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

CMD ["/usr/sbin/sshd", "-D"]
