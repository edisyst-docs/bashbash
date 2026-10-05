#!/usr/bin/env bash
# temporaneo: output veri di auditd, AppArmor e SELinux su un runner Ubuntu 24.04
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq >/dev/null
sudo apt-get install -y -qq auditd apparmor-utils selinux-utils >/dev/null 2>&1
uname -r
echo "##### APPARMOR"
sudo aa-status | head -8
sudo cp /usr/bin/cat /usr/local/bin/mycat
sudo tee /etc/apparmor.d/usr.local.bin.mycat >/dev/null <<'P'
abi <abi/4.0>,
include <tunables/global>
/usr/local/bin/mycat {
  include <abstractions/base>
  /etc/hostname r,
  /etc/passwd r,
}
P
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.mycat && echo "parser ok"
sudo aa-status | grep -E "mycat|profiles are in"
echo "--- enforce"
/usr/local/bin/mycat /etc/hostname; echo rc=$?
sudo /usr/local/bin/mycat /etc/shadow; echo rc=$?
sudo dmesg | grep -i 'apparmor="DENIED"' | tail -2
sudo journalctl -k --no-pager 2>/dev/null | grep 'mycat' | tail -2
echo "--- complain"
sudo aa-complain /usr/local/bin/mycat
sudo /usr/local/bin/mycat /etc/shadow | head -1 | cut -c1-12; echo rc=$?
sudo dmesg | grep -i 'ALLOWED' | grep mycat | tail -1
sudo aa-status | grep -E "complain|mycat"
echo "--- enforce di nuovo"
sudo aa-enforce /usr/local/bin/mycat
echo "--- disable"
sudo aa-disable /usr/local/bin/mycat
sudo aa-status | grep -c mycat
echo "--- profili di sistema"
sudo aa-status --json 2>/dev/null | head -c 300; echo
sudo aa-status | sed -n 1,3p
ls /etc/apparmor.d | head -5
echo "--- ps -Z"
ps -eZ | head -3
echo "##### AUDITD"
sudo systemctl start auditd; systemctl is-active auditd
sudo auditctl -s | head -4
sudo auditctl -w /etc/passwd -p wa -k passwd
sudo auditctl -w /etc/ssh/sshd_config -p rwxa -k sshd
sudo auditctl -a always,exit -F arch=b64 -S execve -F auid=1001 -k exec1001 2>&1 | tail -1
sudo auditctl -l
sudo touch /etc/passwd
sudo usermod -c "prova" "$USER" 2>/dev/null
sudo cat /etc/ssh/sshd_config >/dev/null
sleep 1
sudo ausearch -k passwd -i | tail -12
echo "---"
sudo ausearch -k sshd -i --start recent | tail -8
echo "--- aureport"
sudo aureport --summary | head -15
sudo aureport -f -i --summary | head -8
echo "--- ausearch -m USER_LOGIN / -ts"
sudo ausearch -m USER_LOGIN -ts today -i 2>&1 | tail -4
echo "--- file di regole"
sudo tee /etc/audit/rules.d/50-kb.rules >/dev/null <<'R'
-w /etc/passwd -p wa -k passwd
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root-cmd
R
sudo augenrules --load | tail -3
sudo auditctl -l
sudo auditctl -D | tail -1
sudo auditctl -l
ls /var/log/audit
echo "##### SELINUX"
sestatus 2>&1 | head -3
getenforce 2>&1
ls -Z /etc/passwd 2>&1
id -Z 2>&1
cat /sys/kernel/security/lsm
grep -o 'selinux' /proc/cmdline || echo "selinux non nel cmdline"
