#!/usr/bin/env bash
# pc.sh - prepara pc01: gli strumenti per amministrare il dominio da remoto e per entrarci
# Gira da compose.yaml (post_start) quando dc1 è pronto. Alla fine crea /run/pc-pronto.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# la rete di un runner CI a volte fallisce a metà di apt: si riprova tutto (fino a 4 volte)
for tentativo in 1 2 3 4; do
    apt-get -o Acquire::Retries=5 update -qq \
        && apt-get -o Acquire::Retries=5 install -y -qq samba-common-bin smbclient krb5-user ldap-utils libsasl2-modules-gssapi-mit winbind dnsutils \
        && break
    (( tentativo < 4 )) || exit 1
    echo "apt non è riuscito (tentativo $tentativo): riprovo tra 5 secondi" >&2
    sleep 5
done


cat > /etc/krb5.conf <<'KRB'
[libdefaults]
    default_realm = LAB.TEST
    dns_lookup_kdc = true
    rdns = false
KRB
cat > /etc/samba/smb.conf <<'SMB'
[global]
    workgroup = LAB
    realm = LAB.TEST
    security = ADS
    kerberos method = secrets and keytab
SMB
# il DNS del dominio direttamente (Docker lo gestirebbe con il suo 127.0.0.11, che risponde ai nomi inversi di suo)
printf 'nameserver 10.30.0.10\nsearch lab.test\n' > /etc/resolv.conf
touch /run/pc-pronto
