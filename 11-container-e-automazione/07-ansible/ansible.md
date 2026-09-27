# Ansible

Strumento di automazione agentless: si collega agli host via **SSH**, esegue task definiti in YAML e non richiede
nessun software installato sulle macchine target (solo Python e un server SSH).

- **inventory**: l'elenco degli host su cui agire (file statico o sorgente dinamica)
- **playbook**: l'elenco dei task da eseguire sugli host, nell'ordine
- **modulo**: il "verbo" di ogni task (`apt`, `copy`, `service`, `user`, …); `ansible-doc nome_modulo` per la doc
- **handler**: task speciale eseguito solo se un task precedente ha riportato `changed`

Documentazione: https://docs.ansible.com/ · Inventori: https://docs.ansible.com/ansible/latest/inventory_guide/

```bash
# installazione su Ubuntu/Debian
sudo apt install ansible
# su macOS
brew install ansible
```

Per provare senza macchine reali: laboratorio Docker in [laboratorio/](laboratorio/).

## Inventory

Di default in `/etc/ansible/hosts`; si specifica con `-i file` a ogni comando.

**Formato INI** (compatto, vecchio stile):
```ini
# /etc/ansible/hosts o custom.ini
mail.example.com                      # host standalone

[webservers]                          # gruppo
web1 ansible_host=192.168.1.10
web2 ansible_host=192.168.1.11

[dbservers]
db1 ansible_host=192.168.1.100

[all:vars]                            # variabili per tutti
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_ed25519

[webservers:vars]                     # variabili per il gruppo
http_port=80
```

**Formato YAML** (consigliato, più espressivo):
```yaml
# inventory.yml
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 192.168.1.10
          http_port: 80
        web2:
          ansible_host: 192.168.1.11
          http_port: 443
      vars:
        ansible_user: ubuntu
    dbservers:
      hosts:
        db1:
          ansible_host: 192.168.1.100
```

```bash
ansible-inventory -i inventory.yml --list  # verifica l'inventory in JSON
ansible -i inventory.yml all -m ping       # pinga tutti (-k chiede la password SSH)
ansible -i inventory.yml webservers -m ping
ansible -i inventory.yml all -m shell -a "free -m"    # comando ad hoc
ansible -i inventory.yml all -m setup     # raccoglie i "facts" della macchina (OS, IP, RAM, …)
```

## Connessione SSH

Ansible usa le chiavi SSH per connettersi; `ansible_ssh_pass` in chiaro è sconsigliato.
```bash
# generare e distribuire la chiave sul nodo target (una sola volta)
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key
ssh-copy-id -i ~/.ssh/ansible_key.pub utente@192.168.1.10

# o con sshpass se non ho ancora la chiave
ansible all -m ping -i inventory.ini -k   # -k: chiede la password SSH interattivamente
```

Per più host ognuno con la propria chiave:
```ini
[servers]
client1 ansible_host=192.168.1.100 ansible_user=root ansible_ssh_private_key_file=/etc/ansible/keypairs/client1
client2 ansible_host=192.168.1.200 ansible_user=root ansible_ssh_private_key_file=/etc/ansible/keypairs/client2
```

`host_key_checking = False` in `ansible.cfg` (o variabile d'ambiente `ANSIBLE_HOST_KEY_CHECKING=False`) disabilita
la verifica dell'impronta SSH: comodo per lab, sconsigliato in produzione.

## ansible.cfg
```ini
[defaults]
inventory          = ./hosts
host_key_checking  = False
remote_user        = ubuntu
private_key_file   = ~/.ssh/ansible_key
# roles_path       = ./roles
```

## Playbook

```yaml
---
- name: Installa e avvia Apache         # nome del play (facoltativo ma consigliato)
  hosts: webservers                     # gruppo dall'inventory; "all" per tutti; "localhost" per la macchina locale
  become: true                          # sudo su tutti i task (o per singolo task con become: true nel task)

  vars:                                 # variabili locali al play
    http_port: 80

  vars_files:
    - group_vars/all.yml                # variabili esterne (utile per segreti)

  tasks:
    - name: Aggiorna la cache APT
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600          # riusa la cache se aggiornata meno di 1h fa

    - name: Installa Apache
      ansible.builtin.apt:
        name: apache2
        state: present                  # present / absent / latest

    - name: Avvia Apache e abilitalo
      ansible.builtin.service:
        name: apache2
        state: started
        enabled: true
      notify: Riavvia Apache            # chiama l'handler solo se questo task riporta "changed"

    - name: Copia il virtualhost
      ansible.builtin.copy:
        src: files/mio-sito.conf
        dest: /etc/apache2/sites-available/mio-sito.conf
        owner: root
        group: root
        mode: "0644"
      notify: Riavvia Apache

    - name: Modifica php.ini
      ansible.builtin.lineinfile:
        path: /etc/php/8.3/cli/php.ini
        regexp: "^date.timezone ="
        line: "date.timezone = UTC"

    - name: Crea directory progetto
      ansible.builtin.file:
        path: /var/www/mio-sito
        state: directory
        owner: www-data
        group: www-data
        mode: "0755"

    - name: Clona il repository
      ansible.builtin.git:
        repo: https://github.com/utente/repo.git
        dest: /var/www/mio-sito
        version: main
        update: no                      # non aggiorna se la directory esiste già

    - name: Comando shell (solo quando necessario)
      ansible.builtin.shell:
        cmd: php artisan key:generate
        chdir: /var/www/mio-sito
      tags: deploy                      # esegui solo con --tags deploy

    - name: Task condizionale
      ansible.builtin.apt:
        name: python3-pymysql
      when: ansible_distribution == "Ubuntu"

    - name: Loop su una lista
      ansible.builtin.apt:
        name: "{{ item }}"
        state: present
      loop:
        - git
        - curl
        - unzip

  handlers:
    - name: Riavvia Apache
      ansible.builtin.service:
        name: apache2
        state: restarted                # eseguito UNA sola volta alla fine del play, se qualche task lo ha notificato
```

```bash
ansible-playbook -i inventory.yml playbook.yml
ansible-playbook -i inventory.yml playbook.yml --check    # dry run: simula senza modificare
ansible-playbook -i inventory.yml playbook.yml --diff     # mostra le differenze nei file modificati
ansible-playbook -i inventory.yml playbook.yml --tags deploy # solo i task con quel tag
ansible-playbook -i inventory.yml playbook.yml --limit web1  # solo quell'host
ansible-playbook -i inventory.yml playbook.yml -v           # verboso (-vvv molto verboso)
ansible-lint playbook.yml                                    # verifica stile e buone pratiche
```

## Gestione utenti
La password va hashata prima di metterla nel playbook:
```bash
python3 -c "from passlib.hash import sha512_crypt; print(sha512_crypt.using(rounds=5000).hash('miapwd'))"
# oppure sul sistema: openssl passwd -6 miapwd
```
```yaml
- name: Crea utente deployer
  ansible.builtin.user:
    name: deployer
    password: "$6$salt$..."             # hash SHA-512
    groups: sudo
    shell: /bin/bash
    state: present

- name: Elimina utente
  ansible.builtin.user:
    name: deployer
    state: absent
    remove: yes                         # cancella anche la home
```

## Variabili e group_vars
```
inventory.yml
group_vars/
  all.yml          # variabili per tutti gli host
  webservers.yml   # variabili solo per il gruppo webservers
host_vars/
  web1.yml         # variabili solo per web1
```
I file vengono caricati automaticamente se si trovano accanto all'inventory.

## Moduli più usati
| Modulo | Cosa fa |
|---|---|
| `apt` | pacchetti Debian/Ubuntu |
| `yum` / `dnf` | pacchetti RedHat/CentOS |
| `service` | avvia, ferma, abilita servizi |
| `copy` | copia file dal controller agli host |
| `template` | copia file Jinja2 renderizzati |
| `file` | crea, elimina, permessi, symlink |
| `git` | clona o aggiorna un repository |
| `shell` / `command` | comandi arbitrari (`command` non usa la shell, più sicuro) |
| `lineinfile` | assicura che una riga sia (o non sia) in un file |
| `user` | gestione utenti |
| `debug` | stampa variabili per il debug |
| `setup` | raccoglie i facts dell'host |
| `ping` | verifica la connettività SSH/Python |

```bash
ansible-doc copy           # documentazione completa del modulo
ansible-doc -l             # lista di tutti i moduli disponibili
```

## Laboratorio Docker
Per provare senza macchine reali: un container **master** con Ansible che gestisce due **slave** via SSH,
tutto in rete Docker. Tre varianti in [laboratorio/](laboratorio/):

| Cartella | Cosa aggiunge |
|---|---|
| [laboratorio/infrastr-01/](laboratorio/infrastr-01/) | base: master → ping slave |
| [laboratorio/infrastr-02/](laboratorio/infrastr-02/) | utente condiviso, deploy Laravel |
| [laboratorio/infrastr-03/](laboratorio/infrastr-03/) | aggiunge MySQL e phpMyAdmin |
