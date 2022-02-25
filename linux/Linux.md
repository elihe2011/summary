# 1. 硬件信息

## 1.1 内存

```javascript
free -m
cat /proc/meminfo
dmidecode -t memory
```

 

## 1.2 CPU

```javascript
lscpu
cat /proc/cpuinfo
dmidecode -t processor
dmidecode | grep  "CPU" 获取CPU信息
```



## 1.3 硬盘

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



## 1.4 网卡

```javascript
lspci|grep -i eth
ifconfig -a
ip link show
ethtool eth0 显示网卡eth0的详细参数和指标

lshw -c network
```



## 1.5 机器型号等

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



## 1.6 主板

```javascript
lspci
```



## 1.7 BIOS

```javascript
dmidecode -t bios
dmidecode -q 列出所有有用的信息
```



## 1.8 RAID信息

```javascript
lspci|grep RAID 列出RAID卡的信息
 
megacli64 需要额外安装
```



# 2. 网络

| **cmd**  | **explains**                                                 |
| -------- | ------------------------------------------------------------ |
| ip link  | network device configuration                                 |
| ip addr  | protocol IPv4 or IPv6 address management on a device         |
| ip netns | process network namespace management A network namespace is logically another copy of the network stack, <br/>with its own routes, firewall rules, and network devices. |
| ip route | routing table management. Configuration files are:<br/>/etc/iproute2/ematch_map<br/>/etc/iproute2/group<br/>/etc/iproute2/rt_dsfield<br/>/etc/iproute2/rt_protos<br/>/etc/iproute2/rt_realms<br/>/etc/iproute2/rt_scopes<br/>/etc/iproute2/rt_tables |



## 2.1 路由

### 2.1.1 查看路由

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



### 2.1.2 三种路由

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



### 2.1.3 路由配置

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



### 2.1.4 `ip route`

```bash
ip route show
ip route add 目标主机 via 网关 
ip route add 目标网络/掩码 via 网关
ip route add default via 网关
ip route del 目标网络/掩码
ip route del default [via 网关]
ip route flush // 清空
```



## 2.2 IP

无类别域间路由（Classless Inter-Domain Routing、CIDR）是一个用于给用户分配IP地址以及在互联网上有效地路由IP数据包的对IP地址进行归类的方法。 

### 2.2.1 IP 配置

```bash
ip addr add 192.168.80.248/24 dev ens33
ip addr show ens33

ifconfig eth38 192.168.80.245/24 up
```



### 2.2.2 链路状态

```bash
ip -s link ls ens33

禁用/启用链路
ip link set ens38 down
ip link set ens38 up

禁用/启用网卡
ifconfig ens33 down
ifconfig ens33 up
```



## 2.3 DNS

```bash
 systemd-resolve --status
```



## 2.4 网络流量监控

```bash
# 网卡监控
ip -s -h link

# 实时流量监控
iftop
iftop -nN -i enp1s0
```



# 3. 系统命令

## 3.1 pidstat

```bash
pidstat  -r -u -h -C sysadm
-r: memory
-u: CPU
-h: horizontally
-C: command
```



# 4. systemd

## 4.1 启动分析

```bash
# 列出各项启动占用的时间，但由于是并行启动，启动时间不决定启动完成先后
systemd-analyze blame

# 列出启动矢量图，用浏览器打开boot.svg文件  得到各service启动顺序
systemd-analyze plot > boot.svg
```



## 4.2 systemd 打补丁

```bash
mkdir /etc/systemd/system/nginx.service.d
printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
systemctl daemon-reload
systemctl restart nginx 
```


