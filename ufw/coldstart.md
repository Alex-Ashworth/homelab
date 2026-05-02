```bash
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow 80/tcp
sufo ufw allow 443/tcp
sudo ufw allow 41641/udp
sudo ufw allow from 192.168.1.0/24 to any port 3702 proto udp
sudo ufw allow from 192.168.1.0/24 to any port 5357 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 445 proto tcp
sudo ufw allow in on tailscale0
sudo ufw enable
```
