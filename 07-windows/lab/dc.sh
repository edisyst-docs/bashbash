#!/usr/bin/env bash
# dc.sh - trasforma il container dc1 in un controller di dominio Active Directory (Samba 4) per lab.test
# Gira una sola volta, da compose.yaml (post_start). Alla fine crea /run/dc-pronto, che il healthcheck aspetta.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# la rete di un runner CI a volte fallisce a metà di apt: si riprova tutto (fino a 4 volte)
for tentativo in 1 2 3 4; do
    apt-get -o Acquire::Retries=5 update -qq \
        && apt-get -o Acquire::Retries=5 install -y -qq samba-ad-dc krb5-user ldap-utils libsasl2-modules-gssapi-mit smbclient dnsutils \
        && break
    (( tentativo < 4 )) || exit 1
    echo "apt non è riuscito (tentativo $tentativo): riprovo tra 5 secondi" >&2
    sleep 5
done

REALM=LAB.TEST
DOMINIO=LAB
PASSWORD='Passw0rd!2026'
IP=10.30.0.10
INOLTRO=$(sed -n 's/^nameserver //p' /etc/resolv.conf | head -1)        # il DNS di Docker: risolve internet per conto del dominio


# i servizi "da file server" non vanno con il controller di dominio: lo fa samba-ad-dc
systemctl disable --now smbd nmbd winbind 2> /dev/null || true
mv /etc/samba/smb.conf /etc/samba/smb.conf.orig

# systemd-resolved tiene la 53 su 127.0.0.53: il DNS di Samba deve legare solo le interfacce sue
iface=$(ip -o -4 addr show | awk -v ip="$IP" '$4 ~ "^"ip"/" {print $2}')
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMINIO" --adminpass="$PASSWORD" \
    --server-role=dc --dns-backend=SAMBA_INTERNAL --option="dns forwarder=$INOLTRO" \
    --option="interfaces=lo $iface" --option="bind interfaces only=yes" > /var/log/provision.log 2>&1

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
printf 'nameserver %s\nsearch lab.test\n' "$IP" > /etc/resolv.conf
systemctl unmask samba-ad-dc
systemctl enable --now samba-ad-dc

# aspetta che il DNS dell'AD risponda con il record del servizio LDAP
for _ in $(seq 60); do
    host -t SRV _ldap._tcp.lab.test "$IP" > /dev/null 2>&1 && break
    sleep 2
done
host -t SRV _ldap._tcp.lab.test "$IP" > /dev/null

# la zona inversa (IP -> nome): senza, il client chiede a Docker il nome dell'IP e Kerberos non trova il servizio (GSSAPI: "Server not found")
samba-tool dns zonecreate dc1.lab.test 0.30.10.in-addr.arpa -U "administrator%$PASSWORD" > /dev/null
samba-tool dns add dc1.lab.test 0.30.10.in-addr.arpa 10 PTR dc1.lab.test -U "administrator%$PASSWORD" > /dev/null
samba-tool dns add dc1.lab.test 0.30.10.in-addr.arpa 5 PTR pc01.lab.test -U "administrator%$PASSWORD" > /dev/null
touch /run/dc-pronto
