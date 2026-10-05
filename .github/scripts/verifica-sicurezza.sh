#!/usr/bin/env bash
# temporaneo: output veri di auditd e AppArmor su un runner Ubuntu 24.04
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq >/dev/null
sudo apt-get install -y -qq auditd apparmor-utils selinux-utils policycoreutils >/dev/null 2>&1
uname -r
echo "##### AUDITD"
grep -E '^(flush|freq|log_file|log_format|max_log_file)' /etc/audit/auditd.conf
sudo systemctl start auditd; systemctl is-active auditd
sudo auditctl -w /etc/passwd -p wa -k passwd
sudo auditctl -w /etc/ssh/sshd_config -p rwxa -k sshd
sudo auditctl -l
sudo touch /etc/passwd
sudo cat /etc/ssh/sshd_config >/dev/null
sleep 2
sudo ls -l /var/log/audit/
echo "--- senza flush"; sudo ausearch -k passwd -i | tail -3
echo "--- con flush sync"
sudo sed -i 's/^flush = .*/flush = SYNC/' /etc/audit/auditd.conf
sudo systemctl restart auditd 2>&1 | tail -2; sudo auditctl -w /etc/passwd -p wa -k passwd
sudo touch /etc/passwd; sleep 1
sudo ausearch -k passwd -i | tail -14
echo "--- aureport"
sudo aureport --summary | sed -n 1,12p
sudo aureport -f -i --summary | head -8
sudo aureport -x --summary | head -6
echo "--- regola execve"
sudo auditctl -a always,exit -F arch=b64 -S execve -F path=/usr/bin/whoami -k whoami
whoami >/dev/null; sleep 1
sudo ausearch -k whoami -i | tail -6
echo "--- ausearch -ts / -ua / -m"
sudo ausearch -m SYSCALL -ts recent -i 2>&1 | head -3
sudo ausearch -k passwd --format text 2>&1 | head -3
echo "--- file di regole"
sudo tee /etc/audit/rules.d/50-kb.rules >/dev/null <<'R'
-w /etc/passwd -p wa -k passwd
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root-cmd
R
sudo augenrules --load | tail -3
sudo auditctl -l
sudo auditctl -s | head -3
sudo auditctl -D | tail -1
sudo auditctl -l
echo "##### APPARMOR"
sudo aa-status | head -3
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
sudo aa-status | grep -E "mycat"
echo "--- enforce"
sudo auditctl -D >/dev/null
/usr/local/bin/mycat /etc/hostname; echo rc=$?
sudo /usr/local/bin/mycat /etc/shadow; echo rc=$?
sleep 1
echo "-- dmesg"; sudo dmesg | grep -i 'apparmor="DENIED"' | tail -2
echo "-- journal"; sudo journalctl -k --no-pager | grep 'apparmor="DENIED"' | grep mycat | tail -2
echo "-- audit.log"; sudo ausearch -m AVC -i 2>&1 | tail -4
echo "--- complain con -C"
sudo apparmor_parser -r -C /etc/apparmor.d/usr.local.bin.mycat
sudo aa-status | grep -E "mycat"
sudo /usr/local/bin/mycat /etc/shadow | head -1 | cut -c1-8; echo rc=$?
sleep 1
sudo dmesg | grep -i 'apparmor="ALLOWED"' | grep mycat | tail -1
echo "--- aa-logprof / aa-genprof presenti?"; which aa-logprof aa-genprof aa-complain aa-enforce aa-disable aa-unconfined
echo "--- ancora enforce, rimuovere profilo"
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.mycat
sudo apparmor_parser -R /etc/apparmor.d/usr.local.bin.mycat
sudo aa-status | grep -c mycat
sudo /usr/local/bin/mycat /etc/shadow | head -1 | cut -c1-8
echo "--- aa-unconfined"
sudo aa-unconfined 2>&1 | head -4
echo "--- /proc/PID/attr"
cat /proc/self/attr/current
cat /sys/module/apparmor/parameters/enabled
echo "##### SELINUX"
getenforce 2>&1; sestatus 2>&1 | head -3; ls -Z /etc/passwd 2>&1; cat /sys/kernel/security/lsm; echo
