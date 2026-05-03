Set-up Samba with Windows Network Discovery

```bash
sudo wipefs -a /dev/sdb
sudo parted /dev/sdb --mklabel gpt
sudo parted -a optimal /dev/sdb -- mkpart primary btrfs 1MiB 100%
sudo mkfs.btrfs -L homelab /dev/sbd1

sudo mkdir -p /mnt/temp
sudo mount /dev/sdb1 /mnt/temp
sudo btrfs subvolume create /mnt/temp/@share
sudo btrfs subvolume create /mnt/temp/@services
sudo btrfs subvolume create /mnt/temp/@backups
sudo umount /mnt/temp

mkdir -p /srv/storage/share
mkdir -p /srv/storage/services
mkdir -p /srv/storage/backups
sudo blkid /dev/sdb1
sudo nvim /etc/fstab
sudo mount -a

sudo groupadd -f samba
sudo usermod -aG samba alex

sudo chown -R alex:samba /srv/storage/share
sudo chmod 2770 /srv/storage/share\
newgrp samba

sudo smbpasswd -a alex
sudo smbpasswd -e alex
sudo nvim /etc/samba/smb.conf
sudo testparm

sudo systemctl enable --now smb wsdd
```
