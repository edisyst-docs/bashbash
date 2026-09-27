FROM ubuntu:latest

# Install SSH server and Python
RUN apt-get update && \
    apt-get install -y openssh-server python3 && \
    apt-get clean

# Configure SSH server
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

CMD ["/usr/sbin/sshd", "-D"]
