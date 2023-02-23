# 1. 网络配置

以下操作适合 Debian 10 (buster)

## 1.1 IP 

```bash
# 禁用networking
mv /etc/network/interfaces /etc/network/interfaces.save
systemctl stop networking
systemctl disable networking

# 启用systemd-networkd
cat > /etc/systemd/network/eth1.network <<EOF
[Match]
Name=eth1

[Network]
Address=192.168.3.30/24
Gateway=192.168.3.1
DNS=114.114.114.114
EOF

systemctl start systemd-networkd
systemctl enable systemd-networkd
```



## 1.2 DNS

```bash
# 删除 connman DNS 管理
apt remove connman

# 配置 DNS
vi /etc/systemd/resolved.conf
[Resolve]
DNS=114.114.114.114 8.8.8.8

# 启用 systemd-resolved
systemctl start systemd-resolved
systemctl enable systemd-resolved

# 配置解析
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 查询dns解析
systemd-resolve --status
```

