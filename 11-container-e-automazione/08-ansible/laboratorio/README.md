# Laboratorio Ansible su Docker

Tre infrastrutture progressive: un container **master** con Ansible che gestisce due **slave** via SSH,
tutto connesso tramite una rete Docker. Nessuna VM richiesta.

| Cartella | Cosa aggiunge |
|---|---|
| [infrastr-01/](infrastr-01/) | Base: master pinga gli slave con `ansible -m ping`, esegue playbook con `echo` |
| [infrastr-02/](infrastr-02/) | Utente condiviso master/slave, playbook che installa Apache + PHP + Laravel |
| [infrastr-03/](infrastr-03/) | Aggiunge MySQL e phpMyAdmin al compose; playbook che crea DB, utente e configura `.env` |

## Come avviare

```bash
cd infrastr-01                          # o infrastr-02, infrastr-03
docker compose up -d --build
docker exec -it master bash
```

Dentro il container master:
```bash
# infrastr-01: basta eseguire il playbook (le chiavi SSH sono già configurate nel Dockerfile)
ansible -m ping slaves
ansible-playbook /etc/ansible/playbook.yml

# infrastr-02 e 03: distribuire prima la chiave SSH agli slave
ssh-keyscan slave1 >> /root/.ssh/known_hosts
ssh-keyscan slave2 >> /root/.ssh/known_hosts
sshpass -p edopassword ssh-copy-id edoardo@slave1
sshpass -p edopassword ssh-copy-id edoardo@slave2

ansible -m ping slaves
ansible-playbook /etc/ansible/playbook.yml
```

Smontare tutto (inclusi volumi, se ci sono):
```bash
docker compose down -v
```

Torna a [../](../)
