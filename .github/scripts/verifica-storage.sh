#!/usr/bin/env bash
# script usa-e-getta: produce gli output veri per 06-sistema/12-storage-avanzato.md
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
h() { echo; echo "######## $*"; }
r() { echo "\$ $*"; "$@" 2>&1; echo "[rc=$?]"; }
apt-get update -qq >/dev/null; apt-get install -y -qq lvm2 mdadm smartmontools xfsprogs autofs e2fsprogs >/dev/null 2>&1
modprobe raid1; modprobe raid5; modprobe dm_mod
uname -r; lsb_release -ds
mkdir -p /lab && cd /lab

h "FS su file immagine"
truncate -s 64M disco.img
r mkfs.ext4 -q -L dati disco.img
dumpe2fs -h disco.img 2>/dev/null | grep -E 'Filesystem (volume name|features|state)|Block (count|size)|Inode count'
r e2fsck -f -p disco.img
truncate -s 128M disco.img
r resize2fs disco.img
dumpe2fs -h disco.img 2>/dev/null | grep -E 'Block count'
r tune2fs -L archivio disco.img
truncate -s 300M xfs.img; r mkfs.xfs -q -L xfsdati xfs.img
xfs_info xfs.img 2>&1 | head -4

h "loop device"
for i in 1 2 3 4; do truncate -s 200M d$i.img; done
L1=$(losetup -f --show d1.img); L2=$(losetup -f --show d2.img); L3=$(losetup -f --show d3.img); L4=$(losetup -f --show d4.img)
echo "$L1 $L2 $L3 $L4"
r losetup -a
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS | grep -E 'NAME|loop'

h "LVM"
r pvcreate $L1 $L2
r pvs
r vgcreate vg0 $L1
r vgs
r vgextend vg0 $L2
r vgs
r lvcreate -L 150M -n dati vg0
r lvs
r mkfs.ext4 -q /dev/vg0/dati
mkdir -p /mnt/dati; mount /dev/vg0/dati /mnt/dati; seq 1 100000 > /mnt/dati/numeri.txt
r df -h /mnt/dati
r lvextend -r -L +100M vg0/dati
r df -h /mnt/dati
r lvs -o lv_name,vg_name,lv_size,devices
echo "--- snapshot"
r lvcreate -s -n snap -L 30M vg0/dati
echo modificato > /mnt/dati/numeri.txt; echo extra > /mnt/dati/extra.txt
mkdir -p /mnt/snap; mount -o ro /dev/vg0/snap /mnt/snap; head -c 20 /mnt/snap/numeri.txt | head -2; ls /mnt/snap
r lvs -o lv_name,lv_size,origin,data_percent
umount /mnt/snap; r lvremove -y vg0/snap
echo "--- pvmove"
r pvs -o pv_name,pv_size,pv_used
r vgextend vg0 $L3
r pvmove $L1
r vgreduce vg0 $L1
r pvs -o pv_name,vg_name,pv_used
echo "--- xfs: si ingrandisce, non si riduce"
mkdir -p /mnt/x; XL=$(losetup -f --show xfs.img); mount $XL /mnt/x; r df -h /mnt/x
umount /mnt/x; losetup -d $XL; truncate -s 400M xfs.img; XL=$(losetup -f --show xfs.img); mount $XL /mnt/x; r xfs_growfs /mnt/x; r df -h /mnt/x; umount /mnt/x; losetup -d $XL
echo "--- ext4: riduzione a freddo"
umount /mnt/dati
r e2fsck -f -y /dev/vg0/dati
r lvreduce -r -y -L 100M vg0/dati
r lvs
r vgdisplay vg0
r lvremove -y vg0/dati; r vgremove -y vg0; r pvremove -y $L1 $L2

h "RAID"
cat /proc/mdstat | head -3
r mdadm --create /dev/md0 --level=1 --raid-devices=2 --run $L1 $L2
sleep 3; cat /proc/mdstat
r mdadm --detail /dev/md0
mkfs.ext4 -q /dev/md0; mkdir -p /mnt/raid; mount /dev/md0 /mnt/raid; seq 1 50000 > /mnt/raid/dati.txt
echo "--- guasto"
r mdadm /dev/md0 --fail $L2
cat /proc/mdstat
r mdadm /dev/md0 --remove $L2
mdadm --detail /dev/md0 | grep -E 'State|Active Devices|Failed Devices|Working Devices'
md5sum /mnt/raid/dati.txt
r mdadm --zero-superblock $L2
r mdadm /dev/md0 --add $L3
sleep 2; cat /proc/mdstat
mdadm --detail /dev/md0 | grep -E 'State|Rebuild|Active Devices|Spare'
sleep 3; mdadm --detail /dev/md0 | grep -E 'State :'
echo "--- scan e mdadm.conf"
r mdadm --detail --scan
mdadm --detail --scan > /etc/mdadm/mdadm.conf
umount /mnt/raid; r mdadm --stop /dev/md0
r mdadm --assemble --scan
cat /proc/mdstat | head -3
umount /mnt/raid 2>/dev/null; mdadm --stop /dev/md0
echo "--- RAID5"
r mdadm --create /dev/md1 --level=5 --raid-devices=3 --run $L1 $L3 $L4
sleep 5; cat /proc/mdstat
mdadm --detail /dev/md1 | grep -E 'Raid Level|Array Size|State :'
mdadm --stop /dev/md1

h "smartctl"
r smartctl --scan
r smartctl -i /dev/nvme0
r smartctl -H /dev/nvme0
r smartctl -a /dev/nvme0

h "autofs"
mkfs.ext4 -q -L auto $L4; mkdir -p /srv/dati-auto
cat > /etc/auto.master.d/lab.autofs <<EOT
/mnt/auto  /etc/auto.lab  --timeout=5
EOT
echo "dati  -fstype=ext4  :$L4" > /etc/auto.lab
r systemctl restart autofs
sleep 2
r ls /mnt/auto
r findmnt /mnt/auto/dati
r ls /mnt/auto/dati
r findmnt /mnt/auto/dati
sleep 8
r findmnt /mnt/auto/dati
r systemctl is-active autofs
echo "--- systemd automount (tmpfs)"
systemctl stop autofs; mkdir -p /mnt/sd
echo "tmpfs /mnt/sd tmpfs noauto,size=16M,x-systemd.automount,x-systemd.idle-timeout=5 0 0" >> /etc/fstab
systemctl daemon-reload
r systemctl start mnt-sd.automount
r systemctl list-units --type=automount --no-pager
r findmnt /mnt/sd
r ls /mnt/sd
r findmnt /mnt/sd
sleep 8
r findmnt /mnt/sd
r systemctl status mnt-sd.automount --no-pager
echo "--- systemd automount (device con LABEL, journal)"
mkdir -p /mnt/sd2; echo "LABEL=auto /mnt/sd2 ext4 noauto,x-systemd.automount,x-systemd.idle-timeout=5 0 0" >> /etc/fstab
systemctl daemon-reload
systemctl start mnt-sd2.automount; echo rc=$?
systemctl list-dependencies mnt-sd2.automount --no-pager 2>&1 | head
systemctl status 'dev-disk-by\x2dlabel-auto.device' --no-pager 2>&1 | head -8
udevadm info /dev/loop3 | grep -E 'SYSTEMD|TAGS|ID_FS_LABEL'
