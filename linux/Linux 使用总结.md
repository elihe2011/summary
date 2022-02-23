# 1. Ubuntu

## 1.1 apt

```bash
# 安装
apt install <package name>[=<version>]

# 版本查询
apt-cache madison <package name>
apt-cache policy <package name>    # 更详尽

# 包关联性查询
apt-cache showpkg <package name>

# dryrun, 安装时需要哪些包
apt-get install -s <package name>

# 基本信息
dpkg -l vim

# 详细信息
dpkg -s vim

# 查询版本
apt-cache show vim | grep Version
```



## 1.2 NFS

### 1.2.1 服务端

**磁盘准备，当需要时：**

```bash
# 1. 分区
fdisk /dev/sdb       

# 2. 格式化
mke2fs -t ext4 /dev/sdb1

# 3. 挂载
mkdir -p /mnt/nfs_share
mount /dev/sdb1 /nfsdata

# 4. 查询磁盘UUID
$ blkid  /dev/sdb1
/dev/sdb1: UUID="17b60a9a-92a2-4084-aaea-9f1e73d72509" TYPE="ext4" PARTUUID="42cf54d8-01"

# 5. 配置开机自动挂载
$ vi /etc/fstab
UUID=17b60a9a-92a2-4084-aaea-9f1e73d72509 /mnt/nfs_share ext4 defaults 0 2
```



**安装 NFS Server:**

```bash
# 1. Install NFS Kernel Server
sudo apt update
sudo apt install nfs-kernel-server

# 2. Create a NFS Export Directory
sudo mkdir -p /mnt/nfs_share
sudo chown -R nobody:nogroup /mnt/nfs_share/
sudo chmod 777 /mnt/nfs_share/

# 3. Grant NFS Share Access to Client
sudo vim /etc/exports
/mnt/nfs_share  192.168.*/24(rw,sync,no_subtree_check)

# 4. Export the NFS Share Directory
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# 5. Allow NFS Access through the Firewall
sudo ufw status
sudo ufw allow from 192.168.0.0/16 to any port nfs

# 6. 列出被mount的目录及客户端主机或IP
showmount -a
```

NFS 共享的常用参数：

| 参数             | 说明                                                         |
| ---------------- | ------------------------------------------------------------ |
| ro               | 只读访问                                                     |
| rw               | 读写访问                                                     |
| sync             | 同时将数据写入到内存与硬盘中                                 |
| async            | 异步，优先将数据保存到内存，然后再写入硬盘                   |
| secure           | 通过1024以下的安全TCP/IP端口发送                             |
| insecure         | 通过1024以上的端口发送                                       |
| wdelay           | 如果多个用户要写入NFS目录，则归组写入（默认）                |
| no_wdelay        | 如果多个用户要写入NFS目录，则立即写入，当使用async时，无需此设置 |
| hide             | 在NFS共享目录中不共享其子目录                                |
| no_hide          | 共享NFS目录的子目录                                          |
| subtree_check    | 如果共享/usr/bin之类的子目录时，强制NFS检查父目录的权限（默认） |
| no_subtree_check | 不检查父目录权限                                             |
| all_squash       | 全部用户都映射为服务器端的匿名用户，适合公用目录             |
| no_all_squash    | 保留共享文件的UID和GID（默认）                               |
| root_squash      | 当NFS客户端使用root用户访问时，映射到NFS服务器的匿名用户（默认） |
| no_root_squas    | 当NFS客户端使用root用户访问时，映射到NFS服务器的root用户     |
| anonuid=UID      | 将客户端登录用户映射为此处指定的用户uid                      |
| anongid=GID      | 将客户端登录用户映射为此处指定的用户gid                      |


### 1.2.2 客户端

```bash
# 1. Install the NFS-Common Package
sudo apt update
sudo apt install nfs-common

# 2. Create an NFS Mount Point on Client
sudo mkdir -p /mnt/nfs_clientshare

# 3. Mount NFS Share on Client System
sudo mount 192.168.3.103:/mnt/nfs_share  /mnt/nfs_clientshare
sudo nfsstat -m

# 4. Testing the NFS Share on Client System
touch /mnt/nfs_share/abc.txt  # server
ls -l /mnt/nfs_clientshare    # client
```



### 1.2.3 无法启动

```bash
$ systemctl start nfs-kernel-server
A dependency job for nfs-server.service failed. See 'journalctl -xe' for details.

$ journalctl -xe
Oct 29 19:38:04 k8s-master multipathd[720]: sda: add missing path
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get udev uid: Invalid argument
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get sysfs uid: Invalid argument
Oct 29 19:38:04 k8s-master multipathd[720]: sda: failed to get sgio uid: No such file or directory
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: add missing path
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get udev uid: Invalid argument
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get sysfs uid: Invalid argument
Oct 29 19:38:06 k8s-master multipathd[720]: sdb: failed to get sgio uid: No such file or directory

# 解决
$ vi /etc/multipath.conf
defaults {
    user_friendly_names yes
}

blacklist {
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
    devnode "^sd[a-z]?[0-9]*"
}

$ systemctl restart multipath-tools

# 启动 nfs
systemctl start nfs-kernel-server
```





## 1.3 更改默认编辑器

```bash
sudo update-alternatives --config editor
```



## 1.4 虚拟机磁盘问题

问题描述：

```bash
journalctl -xe
...
Feb 08 02:17:42 ubuntu multipathd[617]: sda: add missing path
Feb 08 02:17:42 ubuntu multipathd[617]: sda: failed to get udev uid: Invalid argument
Feb 08 02:17:42 ubuntu multipathd[617]: sda: failed to get sysfs uid: Invalid argument
Feb 08 02:17:42 ubuntu multipathd[617]: sda: failed to get sgio uid: No such file or directory
```



修改：

```bash
vi /etc/multipath.conf

defaults {
    user_friendly_names yes
}

blacklist {
    device {
         vendor "VMware"
         product "Virtual disk"
    }

    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
    devnode "^sd[a-z]?[0-9]*"
}

# 重启
/etc/init.d/multipath-tools restart
```



## 1.5 DNS 配置

`/etc/resolve.conf` 被覆盖

配置网络时，加上相关DNS配置信息：

Ubuntu 18.0+：`/etc/netplan/01-netcfg.yaml`

```yaml
network:
    ethernets:
        enp1s0:
            addresses: [192.168.3.191/24]
            gateway4: 192.168.3.1
            nameservers:
              addresses: [8.8.8.8,114.114.114.114]
            dhcp4: no
    version: 2
```

Debian & Ubuntu16：`/etc/network/interfaces`

```bash
auto wlp0s20f3
iface wlp0s20f3 inet static
    address 192.168.100.80
    netmask 255.255.255.0
    dns-nameservers 8.8.8.8
```



# 2. CentOS

## 2.1 运行级别

```bash
# 获取
$ systemctl get-default
multi-user.target

$ runlevel 
N 5

# 设置
$ systemctl set-default  multi-user.target   
$ systemctl set-default  graphical.target
```



# 3. Docker

## 3.1 代理配置

```bash
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="ALL_PROXY=http://192.168.3.99:8889/"
Environment="NO_PROXY=localhost,127.0.0.1,docker.io,hub.docker.com,pvjhx571.mirror.aliyuncs.com"
EOF
systemctl daemon-reload && systemctl restart docker


systemctl show --property=Environment docker
```



# 4. 硬件信息

## 4.1 内存

```javascript
free -m
cat /proc/meminfo
dmidecode -t memory
```

 

## 4.2 CPU

```javascript
lscpu
cat /proc/cpuinfo
dmidecode -t processor
dmidecode | grep  "CPU" 获取CPU信息
```



## 4.3 硬盘

```javascript
df -lhP
lsblk
fdisk -l
dmesg|grep sd 查看开机信息里面的磁盘info
hdparm -I /dev/sda  查看磁盘硬件信息、开启的功能等,信息特别详细 【hdparm需要yum安装】
smartctl -H /dev/sda 查看硬盘健康状态
smartctl --all /dev/sda   【smartctl需要yum安装才能用】
# smartctl -h 还有很多有用的参数
```



## 4.4 网卡

```javascript
lspci|grep -i eth
ifconfig -a
ip link show
ethtool eth0 显示网卡eth0的详细参数和指标

lshw -c network
```



## 4.5 机器型号等

```bash
dmidecode -t system

# 获取厂商
dmidecode | grep"Manufacturer" 

# 获取生产日期
dmidecode | grep "Date" 

# 查看服务器型号
dmidecode | grep 'Product Name'

# 查看主板的序列号
dmidecode | grep 'Serial Number'

# 查看系统序列号
dmidecode -s system-serial-number

# 查看内存信息
dmidecode -t memory

# 查看OEM信息
dmidecode -t 11
```



## 4.6 主板

```javascript
lspci
```



## 4.7 BIOS

```javascript
dmidecode -t bios
dmidecode -q 列出所有有用的信息
```



## 4.8 RAID信息

```javascript
lspci|grep RAID 列出RAID卡的信息
 
megacli64 需要额外安装
```



# 5. 网络

| **cmd**  | **explains**                                                 |
| -------- | ------------------------------------------------------------ |
| ip link  | network device configuration                                 |
| ip addr  | protocol IPv4 or IPv6 address management on a device         |
| ip netns | process network namespace management A network namespace is logically another copy of the network stack, <br/>with its own routes, firewall rules, and network devices. |
| ip route | routing table management. Configuration files are:<br/>/etc/iproute2/ematch_map<br/>/etc/iproute2/group<br/>/etc/iproute2/rt_dsfield<br/>/etc/iproute2/rt_protos<br/>/etc/iproute2/rt_realms<br/>/etc/iproute2/rt_scopes<br/>/etc/iproute2/rt_tables |



## 5.1 路由

### 5.1.1 查看路由

```bash
$ route -n
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.80.2    0.0.0.0         UG    0      0        0 ens33
10.244.0.0      10.244.0.0      255.255.255.0   UG    0      0        0 flannel.1
10.244.1.0      10.244.1.0      255.255.255.0   UG    0      0        0 flannel.1
10.244.2.0      0.0.0.0         255.255.255.0   U     0      0        0 cni0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.80.0    0.0.0.0         255.255.255.0   U     0      0        0 ens33
```

- Destination: 目标网络(network)或主机(host)

- Gateway: 网关地址，`*` 标识未设置网关
- Flags:
  - U: route is up
  - H: target is a host
  - G: use gateway, 需要通过外部的主机(gateway) 来转发封包
  - R: reinstate route for dynamic routing, 动态路由复位设置的标识
  - D: dynamically installed by daemon or redirect
  - M: modified from routing daemon or redirect
  - A: installed by addrconf
  - C: cache entry
  - !: reject route
- Metric: 路由距离，达到指定网络所需的中转数。内核未使用
- Ref: 路由项引用次数。内核未使用
- Use: 路由项被软件查找的次数
- Iface: 当前路由的数据发送接口



### 5.1.2 三种路由

**主机路由**：本机能访问的单个IP地址或主机的路由信息，Flags标记为 **H**

本地主机可通过 路由器(192.168.1.1) 访问主机 10.0.0.10

```bash
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
-----------     -----------     --------------  ----- ------ ---    --- ------
10.0.0.10       192.168.1.1     255.255.255.255 UH    100    0        0 eth0
```



**网络路由**：本机能访问的一个网络的路由信息。Flags 标记为 **G**

本地主机可通过 路由器(192.168.1.1) 访问网络 192.19.12.0/24

```bash
Destination    Gateway       Genmask        Flags    Metric    Ref     Use    Iface
-----------    -------       -------        -----    -----     ---     ---    -----
192.19.12.0   192.168.1.1    255.255.255.0   UG      0         0       0      eth0
```



**默认路由**：路由表中找不到目标主机或网络时，数据包被发送到默认路由

```bash
Destination    Gateway       Genmask    Flags     Metric    Ref    Use    Iface
-----------    -------       -------    -----    ------     ---    ---    -----
default       192.168.1.1    0.0.0.0    UG        0         0      0      eth0
```



### 5.1.3 路由配置

```bash
route  [add|del] [-net|-host] target [netmask NM] [gw GW] [[dev] If]
```

示例：

```bash
# 添加主机路由
route add -host 192.168.1.2 dev eth0
route add -host 10.244.1.5 gw 10.244.1.1

# 添加网络路由
route add -net 10.244.1.0 netmask 255.255.255.0 dev eth0
route add -net 10.96.0.0 netmask 255.255.0.0 gw 10.96.0.1
route add -net 172.16.0.0/16 eth1

# 默认路由
route add default gw 192.168.1.1

# 删除路由
route del -host 192.168.1.2 dev eth0
route del -net 172.16.0.0/16 eth1
route del default gw 192.168.1.1

# 屏蔽路由
route add -net 224.0.0.0 netmask 240.0.0.0 reject
```



### 5.1.4 `ip route`

```bash
ip route show
ip route add 目标主机 via 网关 
ip route add 目标网络/掩码 via 网关
ip route add default via 网关
ip route del 目标网络/掩码
ip route del default [via 网关]
ip route flush // 清空
```



## 5.2 IP

无类别域间路由（Classless Inter-Domain Routing、CIDR）是一个用于给用户分配IP地址以及在互联网上有效地路由IP数据包的对IP地址进行归类的方法。 

### 5.2.1 IP 配置

```bash
ip addr add 192.168.80.248/24 dev ens33
ip addr show ens33

ifconfig eth38 192.168.80.245/24 up
```



### 5.2.2 链路状态

```bash
ip -s link ls ens33

禁用/启用链路
ip link set ens38 down
ip link set ens38 up

禁用/启用网卡
ifconfig ens33 down
ifconfig ens33 up
```



## 5.3 DNS

```bash
 systemd-resolve --status
```



# 6. Shell 技巧

## 6.1 EOF

What is different between "<<-EOF" and "<<EOF" in bash script ？

<<-EOF will ignore leading tabs in your heredoc, while <<EOF will not. Thus:

```bash
cat <<EOF
    Line 1
    Line 2
EOF

# will produce
    Line 1 
    Line 2
```

while

```bash
cat <<-EOF
    Line 1
    Line 2
EOF

# produces
Line 1 
Line 2
```

example:

```bash
function foo() { 
        # the end EOF cannot be preceded and followed by any characters 
        cat <<EOF 
        Line 1 
        Line 2 
EOF 
        echo '--------------' 
        cat <<-EOF 
        Line 1 
        Line 2 
        EOF

        echo '--------------' 
        cat <<-EOF 
        Line 1 
        Line 2 
EOF 
}

# output
        Line 1 
        Line 2 
-------------- 
Line 1 
Line 2 
-------------- 
Line 1 
Line 2
```



# 7. 系统命令

## 7.1 pidstat

```bash
pidstat  -r -u -h -C sysadm
-r: memory
-u: CPU
-h: horizontally
-C: command
```



# 8. systemd

## 8.1 启动分析

```bash
# 列出各项启动占用的时间，但由于是并行启动，启动时间不决定启动完成先后
systemd-analyze blame

# 列出启动矢量图，用浏览器打开boot.svg文件  得到各service启动顺序
systemd-analyze plot > boot.svg
```



## 8.2 systemd 打补丁

```bash
mkdir /etc/systemd/system/nginx.service.d
printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
systemctl daemon-reload
systemctl restart nginx 
```

