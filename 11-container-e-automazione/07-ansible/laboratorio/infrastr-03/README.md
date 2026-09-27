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


Questa infrastruttura, parte dalla precedente (infrastr_02) e mantiene solo questa funzionalità:
- Sia su master che sugli slave creo un utente edoardo:edopassword : sarà l'utente che svolge le operazioni su ansible
    - ciò permette di non dover aggiungere a mano la chiave ssh di root nelle slave
Questa infrastruttura aggiunge al docker-compose.yml, i seguenti servizi:
- un'istanza di un DB mysql, con un suo volume (dove salvare i dati e i DB)
- un'istanza di phpmyadmin (per avere un'interfaccia dei DB del container mysql)
- su master e slave installo il pacchetto mysql-client, per poter interagire con il DB mysql da dentro quei container (se installo Laravel sugli slave, dovrò installare anche il mysql)
- il playbook si incazza al composer perchè stò clonando un repo Laravel 8 in php 8.0 mentre stò installando sugli slave php 8.3
  - ma di per sè l'infrastruttura funziona
  

## 8. Verificare l'infrastruttura aggiornata
Avvio il docker-compose con il comando:
```bash
docker-compose up -d
docker compose up -d --build
```


### Verifica che MySQL sia attivo
Accedi al container mysql e Verifica lo stato del servizio:
```bash
docker exec -it mysql bash

mysqladmin -u root -p status
```
(Password: quella definita nel tuo Dockerfile, ad es. rootpassword)


### Verifica della comunicazione Slave → MySQL
Dal container `slave1` o `slave2`:
```bash
docker exec -it slave1 bash
mysql -h mysql -u root -p
```
* `-h mysql`: il nome del container MySQL (Docker risolve tramite hostname nel network)
* Se vedi il prompt `mysql>`, è tutto OK 


### Accesso via phpMyAdmin da browser
Hai esposto phpmyadmin sulla `porta 8080:80` nel `docker-compose.yml`, quindi lo trovi all'url `http://127.0.0.1:8080` 

Credenziali di accesso:
```bash
Server: mysql # nome del container
Utente: root
Password: rootpassword # o quella che hai impostato nel Dockerfile di MySQL
```

### Verifica della comunicazione Master → MySQL
Nel container `master` puoi fare:
```bash
docker exec -it master bash
apt update && apt install -y mysql-client
mysql -h mysql -u root -p
```

