#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq >/dev/null
sudo apt-get install -y -qq auditd apparmor-utils >/dev/null 2>&1
echo "##### AUDITD"
sudo grep -E '^(flush|freq|log_file|log_format|max_log_file|write_logs)' /etc/audit/auditd.conf
sudo systemctl start auditd; systemctl is-active auditd
sudo auditctl -w /etc/passwd -p wa -k passwd
sudo auditctl -s | head -2
sudo touch /etc/passwd
sudo cat /etc/ssh/sshd_config >/dev/null
sleep 2
sudo wc -l /var/log/audit/audit.log
sudo head -c 600 /var/log/audit/audit.log; echo
sudo grep -c 'key="passwd"' /var/log/audit/audit.log
sudo grep 'key="passwd"' /var/log/audit/audit.log | head -3 | cut -c1-300
echo "--- ausearch"
sudo ausearch -k passwd 2>&1 | head -6
sudo ausearch --input-logs -k passwd 2>&1 | head -3
echo "--- ausearch da file"
sudo ausearch -if /var/log/audit/audit.log -k passwd 2>&1 | head -6
echo "--- journal"; sudo journalctl _TRANSPORT=audit --no-pager -n 3 2>&1 | cut -c1-200
echo "##### APPARMOR LOG"
sudo cp /usr/bin/cat /usr/local/bin/mycat
sudo tee /etc/apparmor.d/usr.local.bin.mycat >/dev/null <<'P'
abi <abi/4.0>,
include <tunables/global>
/usr/local/bin/mycat {
  include <abstractions/base>
  /etc/hostname r,
}
P
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.mycat
sudo /usr/local/bin/mycat /etc/shadow; echo rc=$?
sleep 1
sudo grep -c AVC /var/log/audit/audit.log; sudo grep AVC /var/log/audit/audit.log | tail -1 | cut -c1-400
sudo dmesg 2>&1 | tail -2
sudo journalctl -k --no-pager 2>&1 | tail -3
cat /proc/sys/kernel/dmesg_restrict; cat /proc/sys/kernel/printk_ratelimit 2>&1
sudo journalctl --no-pager -g 'apparmor=' -n 3 2>&1 | cut -c1-300
