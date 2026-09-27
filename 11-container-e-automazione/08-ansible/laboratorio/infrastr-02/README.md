# Problema
Creare con un Docker container una `infrastruttura costituita da 3 macchine`:
una (`master`) che tramite `Ansible` potrà controllare, comandare, installare pacchetti e gestire le altre 2 macchine (`slave1` e `slave2`).
Le 3 macchine devono essere collegate tra loro in una `rete Docker`.
Nella macchina `master` deve essere configurato `Ansible` affinché possa lanciare i comandi alle altre 2 macchine.


# Soluzione con docker-compose
Per creare una infrastruttura Docker con una macchina `master` che utilizza `Ansible` per gestire due macchine `slave`,
è più conveniente utilizzare `Docker Compose`, che consente di gestire facilmente la configurazione della rete e dei container.

Ecco i passaggi per configurare l'infrastruttura:

### 1. Creare il file docker-compose.yml
Nella directory principale del progetto, crea un file `docker-compose.yml`:
```yaml
version: '3'
services:
  master:
    build: ./master
    container_name: master
    networks:
      - mynet
    volumes:
      - ./master/ansible:/etc/ansible
  slave1:
    build: ./slave
    container_name: slave1
    networks:
      - mynet
  slave2:
    build: ./slave
    container_name: slave2
    networks:
      - mynet

networks:
  mynet:
    driver: bridge
```

### 2. Creare la directory per il master e per le slave
Crea le seguenti directory: `master` e `slave`.
```bash
mkdir master slave
```

### 3. Creare i Dockerfile per master e slave:
- Dockerfile per il master (`master/Dockerfile`):
```dockerfile
FROM ubuntu:latest

# Install necessary packages
RUN apt-get update && \
    apt-get install -y ansible openssh-client openssh-server sshpass && \
    apt-get clean

# Create required directory for SSH
RUN mkdir -p /run/sshd

# Create Ansible directory
RUN mkdir -p /etc/ansible

# Generate SSH keys for the master
RUN ssh-keygen -q -N "" -f /root/.ssh/id_rsa

# Add ssh config to disable host key checking
RUN echo "Host *\n\tStrictHostKeyChecking no\n" > /root/.ssh/config

# Copy the Ansible configuration files
COPY ansible/ /etc/ansible/

CMD ["/usr/sbin/sshd", "-D"]
```

- Dockerfile per le slave (`slave/Dockerfile`):
```dockerfile
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
```

### 4.  Configurare Ansible nel master:
Crea i file di configurazione di Ansible nella directory `master/ansible`.
- `master/ansible/ansible.cfg`: Configura Ansible per eseguire i comandi in modalità locale.
```ini
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
```

- `master/ansible/hosts`: Definisce gli host su cui eseguire i comandi.
```ini
[slaves]
slave1 ansible_host=slave1
slave2 ansible_host=slave2
```

- `master/ansible/playbook.yml`: Definisce i comandi da eseguire sulle macchine slave.
```yaml
---
- hosts: slaves
  tasks:
    - name: Ensure Python is installed
      apt:
        name: python3
        state: present
    - name: Test command
      command: echo "Hello from {{ inventory_hostname }}"
```


## 5. Avviare i container docker-compose
Nella directory principale del progetto, esegui il comando:
```bash
docker-compose up --build
docker ps   # Verifica che tutti i container siano in esecuzione
```


## 6. OPZIONALE - Copiare manualmente la chiave SSH:
Accedere al container `master`:
```bash
docker exec -it master bash
```
All'interno del container `master` eseguire i seguenti comandi:
```bash
ssh-keyscan slave1 >> /root/.ssh/known_hosts
ssh-keyscan slave2 >> /root/.ssh/known_hosts

sshpass -p root ssh-copy-id root@slave1
sshpass -p root ssh-copy-id root@slave2
```


## 7. Verificare l'infrastruttura
Sempre all'interno del container `master` eseguire il playbook di Ansible:
```bash
docker exec -it master bash
ansible -m ping slaves                     # Verifica la connessione con le slave
ansible-playbook /etc/ansible/playbook.yml # Esegui il playbook sulle slave
```

Questa infrastruttura parte dalla precedente (infrastr_01) e aggiunge le seguenti funzionalità:
- Sia su master che sugli slave creo un utente edoardo:edopassword : sarà l'utente che svolge le operazioni su ansible
  - ciò permette di non dover aggiungere a mano la chiave ssh di root nelle slave
- nel playbook si installa anche composer secondo la sua documentazione, (il file ansible/scripts/install_composer.sh contiene le istruzioni)
- il playbook prevede di installare sulle slave apache2, mysql, php8, il progetto Laravel, e di deployarlo lì dentro
- stò provando anche il playbook del corso, per quanto possibile
