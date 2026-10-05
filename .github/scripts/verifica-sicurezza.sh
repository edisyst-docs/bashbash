#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq >/dev/null
sudo apt-get install -y -qq auditd apparmor-utils >/dev/null 2>&1
echo "##### AUDITD"
sudo systemctl start auditd
sudo auditctl -w /etc/passwd -p wa -k passwd
sudo auditctl -w /etc/ssh/sshd_config -p r -k sshd-letto
sudo auditctl -a always,exit -F arch=b64 -S execve -F path=/usr/bin/whoami -k whoami
sudo auditctl -l
sudo useradd -m prova
sudo cat /etc/ssh/sshd_config >/dev/null
whoami >/dev/null
sudo -k; echo sbagliata | sudo -S -u prova true 2>&1 | tail -1
sleep 2
echo "--- ausearch -k passwd -i --input-logs"; sudo ausearch --input-logs -k passwd -i | tail -22
echo "--- ausearch whoami"; sudo ausearch --input-logs -k whoami -i | tail -8
echo "--- ausearch -ts recent -m USER_AUTH,USER_CMD"; sudo ausearch --input-logs -m USER_CMD -ts recent -i | tail -4 | cut -c1-250
echo "--- aureport"
sudo aureport --input-logs --summary | sed -n 1,16p
sudo aureport --input-logs -k --summary
sudo aureport --input-logs -f -i --summary | head -8
sudo aureport --input-logs -x --summary | head -8
sudo aureport --input-logs --auth -i | tail -5 | cut -c1-200
echo "--- -w rimosso"
sudo auditctl -W /etc/passwd -p wa -k passwd; sudo auditctl -l
sudo auditctl -D
echo "--- file di regole + augenrules"
sudo tee /etc/audit/rules.d/50-kb.rules >/dev/null <<'R'
-w /etc/passwd -p wa -k passwd
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root-cmd
R
sudo augenrules --load | tail -3
sudo auditctl -l
sudo test -f /etc/audit/audit.rules && sudo head -4 /etc/audit/audit.rules
echo "--- sudo -> root-cmd"; sudo -u runner sudo id >/dev/null; sleep 1
sudo ausearch --input-logs -k root-cmd -i | tail -6 | cut -c1-260
echo "--- stdin trap"; sudo ausearch -k root-cmd < /dev/null | head -2; echo '(senza --input-logs, stdin vuoto)'
echo "--- immutabile"; sudo auditctl -e 2 | tail -1; sudo auditctl -w /etc/hosts -p w -k x 2>&1 | tail -1; sudo auditctl -s | head -1
