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


To                         Action      From
--                         ------      ----
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
41641/udp                  ALLOW       Anywhere
3702/udp                   ALLOW       192.168.1.0/24
5357/tcp                   ALLOW       192.168.1.0/24
445/tcp                    ALLOW       192.168.1.0/24
Anywhere on tailscale0     ALLOW       Anywhere
80/tcp (v6)                ALLOW       Anywhere (v6)
443/tcp (v6)               ALLOW       Anywhere (v6)
41614/udp (v6)             ALLOW       Anywhere (v6)
41641/udp (v6)             ALLOW       Anywhere (v6)
Anywhere (v6) on tailscale0 ALLOW       Anywhere (v6)
