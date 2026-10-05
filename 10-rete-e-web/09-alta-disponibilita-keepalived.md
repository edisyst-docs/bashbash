# Alta disponibilità: IP virtuale con keepalived

> **Laboratorio**: `./lab.sh 10`. I due server sono `host` (`10.10.1.10`) e `host2` (`10.10.1.11`), il client `web`. Dettagli in [lab/](lab/).

Un bilanciatore ([05-load-balancer/](05-load-balancer/)) o un server davanti a tutto il resto è un **punto singolo di guasto**: se si ferma, il servizio sparisce. La soluzione è averne due, e un indirizzo
che passa da uno all'altro. **keepalived** fa esattamente questo con il protocollo **VRRP** (*Virtual Router Redundancy Protocol*):

- due macchine condividono un **IP virtuale** (VIP), qui `10.10.1.100`: i client usano solo quello
- una è **MASTER** e ha il VIP sulla scheda; l'altra è **BACKUP** e sta in ascolto
- il MASTER manda ogni secondo un annuncio (*advertisement*) in multicast (`224.0.0.18`) con la sua **priorità**
- se il BACKUP non sente più gli annunci, o ne sente uno con priorità più bassa, **si prende il VIP** e manda un ARP gratuito: la rete impara subito il nuovo indirizzo MAC

keepalived controlla anche che il servizio **funzioni**, non solo che la macchina sia viva: se `nginx` si ferma sul MASTER, il suo punteggio scende e il VIP passa all'altro. Gli esempi sono
stati eseguiti nel laboratorio dell'area 10 (keepalived 2.2.8).

## Il percorso
```
                 client (web, 10.10.2.10) --> router --> 10.10.1.100  (VIP)
                                                              |
                                          +-------------------+------------------+
                                  host 10.10.1.10 (MASTER, 150)      host2 10.10.1.11 (BACKUP, 100)
                                          nginx                              nginx
```
Su ogni server c'è un nginx che risponde `risposta da <nome>`, così si vede chi risponde al VIP.
```bash
sudo apt install keepalived nginx curl
echo "risposta da $(hostname)" | sudo tee /var/www/html/index.html
keepalived --version | head -1                  # Keepalived v2.2.8
```

## La configurazione
`/etc/keepalived/keepalived.conf` è uguale sui due server, a parte `state` e `priority` (qui la versione del MASTER `host`):
```
global_defs {
    router_id host                  # un nome per i log
    enable_script_security
    script_user root
}

vrrp_script controlla_nginx {       # un controllo di salute
    script "/usr/bin/curl -fsS -m 2 -o /dev/null http://127.0.0.1/"
    interval 2                      # ogni 2 secondi
    fall 2                          # 2 fallimenti di fila = guasto
    rise 2                          # 2 successi di fila = di nuovo sano
    weight -60                      # in guasto la priorità scende di 60
}

vrrp_instance VI_1 {
    state MASTER                    # BACKUP sull'altro server
    interface eth0                  # la scheda su cui sta il VIP e dove passano gli annunci
    virtual_router_id 51            # lo stesso su entrambi (1-255), diverso per ogni coppia sulla stessa rete
    priority 150                    # 100 sull'altro
    advert_int 1                    # un annuncio al secondo
    authentication {
        auth_type PASS
        auth_pass segreto1          # solo 8 caratteri contano: serve contro le configurazioni sbagliate, non contro un attaccante
    }
    virtual_ipaddress {
        10.10.1.100/24
    }
    track_script {
        controlla_nginx
    }
}
```
Il punto chiave è la **priorità effettiva**: 150 sul master, `150 − 60 = 90` se `nginx` non risponde, che è **sotto** il 100 del backup, quindi il VIP passa. Se il peso fosse `-20`
(150 → 130) il master resterebbe tale anche con `nginx` fermo: **il peso deve far scendere la priorità sotto quella dell'altro**.
```bash
sudo keepalived -t                              # controlla la configurazione (nessun output e rc=0 = ok)
sudo systemctl enable --now keepalived
ip -br a show eth0                              # sul master: eth0 UP 10.10.1.10/24 10.10.1.100/24   <- c'è il VIP
ip -br a show eth0                              # sul backup: eth0 UP 10.10.1.11/24                  <- non c'è
journalctl -u keepalived | grep Entering
# (VI_1) Entering BACKUP STATE (init)
# (VI_1) Entering MASTER STATE
curl http://10.10.1.100/                        # dal client: risposta da host
```
Gli errori di configurazione, che `keepalived -t` trova:
```
(/tmp/k: Line 17) WARNING - interface eth9 for vrrp_instance VI_1 doesn't exist
(/tmp/k: Line 18) (VI_1): VRID '999' not valid - must be between 1 & 255
```

### Gli annunci VRRP
```bash
sudo tcpdump -ni eth0 -c 3 vrrp                 # sul backup
# 14:33:26.270720 IP 10.10.1.10 > 224.0.0.18: VRRPv2, Advertisement, vrid 51, prio 150, authtype simple, intvl 1s, length 20
# 14:33:27.270898 IP 10.10.1.10 > 224.0.0.18: VRRPv2, Advertisement, vrid 51, prio 150, authtype simple, intvl 1s, length 20
```
Un annuncio al secondo dal MASTER: finché arriva, il BACKUP resta fermo. Se il firewall blocca il protocollo **112** (VRRP) o il multicast fra i due, ognuno crede di essere solo e **entrambi diventano MASTER**
(*split brain*): il VIP risponde da due macchine.

## Il guasto
Un ciclo di richieste dal client, ogni secondo, mentre si ferma `nginx` sul master:
```bash
# sul client:
for i in $(seq 1 24); do echo "$(date +%T) $(curl -s -m 1 http://10.10.1.100/ || echo NESSUNA)"; sleep 1; done
# sul master, dopo 3 secondi:    sudo systemctl stop nginx
# 12 secondi dopo:               sudo systemctl start nginx
#
#   3 risposta da host            <- il master serve
#   6 NESSUNA                     <- nginx è fermo e il VIP è ancora lì: 2 controlli (fall 2 x 2 s) e poi il passaggio
#  11 risposta da host2           <- il backup ha preso il VIP
#   4 risposta da host            <- nginx torna sano, la priorità risale a 150 e il master si riprende il VIP
```
Circa **6 secondi senza risposta**: il tempo di accorgersi del guasto (`interval` × `fall`) più quello del BACKUP per decidere (circa 3 intervalli di annuncio). Nel log:
```bash
# sul master:
journalctl -u keepalived | grep -E "Script|priority|Entering"
# Script `controlla_nginx` now returning 7                   <- 7 = curl: connessione rifiutata
# VRRP_Script(controlla_nginx) failed (exited with status 7)
# (VI_1) Changing effective priority from 150 to 90
# (VI_1) Master received advert from 10.10.1.11 with higher priority 100, ours 90

# VRRP_Script(controlla_nginx) succeeded
# (VI_1) Changing effective priority from 90 to 150
# (VI_1) Entering MASTER STATE
# sul backup:
# (VI_1) Entering MASTER STATE
# (VI_1) Master received advert from 10.10.1.10 with higher priority 150, ours 100
# (VI_1) Entering BACKUP STATE
```
Un arresto **ordinario** di keepalived (`systemctl stop keepalived` sul master) è più veloce: il master manda un annuncio con priorità 0 ("lascio") e il backup si prende il VIP subito,
senza nessuna richiesta persa nella prova. Un crollo vero della macchina (spenta di colpo) si nota solo dagli annunci che mancano: circa 3 secondi.

### Cosa succede al ritorno: `preempt`
Per default un nodo con priorità **più alta** si **riprende** il VIP appena torna (*preempt*), come sopra. Può non essere quello che si vuole: una commutazione in più è un'altra interruzione.
Con `nopreempt` (e `state BACKUP` su entrambi) il VIP resta dov'è finché non c'è un guasto.

### Avvisare: gli script `notify`
Si può eseguire un comando a ogni cambio di stato: spedire un messaggio, avviare un servizio che deve girare solo sul master (un job, un DNS), aggiornare un'altra configurazione.
```
    notify_master "/bin/sh -c 'echo $(date +%T) MASTER >> /tmp/vrrp.log'"
    notify_backup "/bin/sh -c 'echo $(date +%T) BACKUP >> /tmp/vrrp.log'"
    notify_fault  "..."
```
Fermando e riavviando keepalived sull'altro nodo, `/tmp/vrrp.log` sul backup mostra `14:34:01 MASTER`, poi `14:34:10 BACKUP`.

## Cose da sapere
- Il VIP deve stare **nella stessa rete** dei due server. Fra reti diverse VRRP non funziona
- **I servizi devono ascoltare anche sul VIP**: nginx su `0.0.0.0` va bene; su un indirizzo preciso (`listen 10.10.1.10:80`) no. Per un servizio che si lega al solo indirizzo del VIP,
  sul backup (che non lo ha) non partirebbe: `net.ipv4.ip_nonlocal_bind=1` lo permette
- **I dati devono essere gli stessi** su entrambi (database replicato, file condivisi come in [08-condivisioni-nfs-samba.md](08-condivisioni-nfs-samba.md)): keepalived sposta l'indirizzo, non i dati
- Per più coppie sulla stessa rete serve un `virtual_router_id` diverso, altrimenti si leggono gli annunci a vicenda
- Con un **bilanciatore** (HAProxy, nginx) davanti ai server, la coppia con keepalived serve ai bilanciatori stessi: è lo schema classico "due HAProxy con un VIP"
- In un cloud (AWS, Azure, GCP) il multicast non passa e un indirizzo non si sposta con un ARP: si usano i servizi del provider (IP elastici, bilanciatori gestiti)
- Nel laboratorio basta `CAP_NET_ADMIN` sul container (c'è già) perché il VIP si possa aggiungere e togliere dalla scheda

## Problemi comuni
| Sintomo | Causa | Cosa fare |
|---|---|---|
| entrambi i nodi hanno il VIP | gli annunci non passano (firewall, multicast, scheda sbagliata) | `tcpdump -ni eth0 vrrp` sul backup: arrivano? Se c'è un firewall, aprire il protocollo 112 fra i due |
| il VIP non passa quando il servizio si ferma | `weight` troppo piccolo, o manca `track_script` | la priorità effettiva (`150 + weight`) deve scendere **sotto** quella dell'altro |
| `Unknown keyword` / `Non-existent interface specified in configuration` | errore nel file | `keepalived -t` |
| lo script di controllo fallisce sempre | percorso senza `/usr/bin/`, permessi, `script_user` | provare il comando a mano come root; `journalctl -u keepalived \| grep Script` |
| il VIP passa avanti e indietro | controllo troppo sensibile (`fall 1`) o servizio instabile | `fall 3`, `rise 3`; correggere il servizio |
| due coppie si disturbano | stesso `virtual_router_id` sulla stessa rete | un id per ogni coppia |
| il client continua a contattare il vecchio nodo per qualche secondo | cache ARP del client | normale per un attimo: keepalived manda un ARP gratuito, ma alcuni apparati lo ignorano |

Torna all'[indice dell'area](README.md)
