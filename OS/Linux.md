# 1. 硬件信息

## 1.1 内存

```javascript
free -m
cat /proc/meminfo
dmidecode -t memory
```

 内存释放：

```bash
sync     # 多执行几次
echo 3 > /proc/sys/vm/drop_caches
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
systemd-resolve --statistics
 
# 临时方案 
vi /etc/resolv.conf
nameserver 8.8.8.8

# 永久方案（重启后临时方案失效）
vi /etc/resolvconf/resolv.conf.d/tail
nameserver 8.8.8.8
```

添加DNS：

```bash
$ vi /etc/systemd/resolved.conf
...
[Resolve]
DNS=114.114.114.114
DNS=8.8.8.8

systemctl restart systemd-resolved
```









## 2.4 网络流量监控

```bash
# 网卡监控
ip -s -h link

# 实时流量监控
iftop
iftop -nN -i enp1s0
```



## 2.5 nc

net cat

```bash
nc -l 8000     开启8000监听端口

nc -z -w 5 127.0.0.1 8000   连接端口，5s超时

nc -z -w 5 127.0.0.1 3300-3310 端口扫描

nc -v 192.168.31.20 1080
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



## 3.2 openssl

签发证书：

```bash
mkdir -p $HOME/docker/ssl && cd $HOME/docker/ssl

# 1. 创建CA私钥
openssl genrsa -out ca.key 4096

# 生成根证书请求文件
openssl req -new -key ca.key -out ca.csr -sha256 \
        -subj '/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/CN=Docker Registry CA'
          
# 配置根证书
cat > ca.conf <<EOF
[ca]
basicConstraints = critical,CA:TRUE,pathlen:1
keyUsage = critical, nonRepudiation, cRLSign, keyCertSign
subjectKeyIdentifier=hash
EOF

# 签发证书
openssl x509 -req -days 3650  -in ca.csr \
        -signkey ca.key -sha256 -out ca.crt \
        -extfile ca.conf -extensions ca
               
# 生成SSL私钥
openssl genrsa -out registry.xtwl.com.key 4096

# 生成证书请求文件
openssl req -new -key registry.xtwl.com.key -out server.csr -sha256 \
        -subj '/C=CN/ST=Jiangsu/L=Nanjing/O=XTWL/CN=registry-srv'
          
# 配置证书
cat > server.conf <<EOF
[server]
authorityKeyIdentifier=keyid,issuer
basicConstraints = critical,CA:FALSE
extendedKeyUsage=serverAuth
keyUsage = critical, digitalSignature, keyEncipherment
subjectAltName = DNS:registry.xtwl.com, IP:127.0.0.1
subjectKeyIdentifier=hash
EOF

# 签发SSL证书
openssl x509 -req -days 3650 -in server.csr -sha256 \
        -CA ca.crt -CAkey ca.key  -CAcreateserial \
        -out registry.xtwl.com.crt -extfile server.conf -extensions server
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



## 4.3 journalctl

```bash
# 显示不全
journalctl -n 40 -u kubelet.service | vim -

# 按时间倒序显示日志
journalctl -r

# 显示最近的25行日志
journalctl -n 25

# 实时查看日志
journalctl -f

# 内核日志
journalctl -k

# 常驻进程日志
journalctl -u ssh

# 指定时间段
journalctl --since=yesterday --until=now
journalctl --since "2020-07-10"
journalctl --since "2020-07-10 15:10:00" --until "2020-07-12"

# 根据UID、GID和PID过滤日志
journalctl _PID=1234

# -p：日志级别，0-emerg紧急，1-alert警报，2-crit关键，3-错误 4-警告 5-注意 6-普通信息 7-调试消息
# -x：日志的附加信息，-b：自上次启动，即当前会话以来。
journalctl -p 3 -xb
journalctl -p 4..6 -b0
```



## 4.4 运行级别

```bash
# 图形模式
sudo systemctl set-default graphical.target
sudo systemctl set-default runlevel5.target

# 文本命令模式
sudo systemctl set-default multi-user.target
sudo systemctl set-default runlevel3.target
```



## 4.5 日志管理

日志目录：`/var/log/journal/`

```bash
# 日志磁盘空间
journalctl --disk-usage

# 日志轮询
journalctl --rotate

# 清空日志，2s, 2m, 2h, 2w
journalctl --vacuum-time=2d

# 日志缩小到100MB
journalctl --vacuum-size=100M

# 限制日志文件数量
journalctl --vacuum-files=5

# 自动删除日志配置
vi /etc/systemd/journald.conf
SystemMaxUse = 1G
SystemMaxFileSize = 200M
SystemMaxFiles = 10

systemctl restart systemd-journald
```



# 5. 磁盘操作

## 5.1 dd

```bash
# 复制磁盘
dd if=/dev/sda of=/dev/sdb

# 磁盘镜像
dd if=/dev/sda of=/home/sdadisk.img

# 镜像还原
dd if=/dev/sda2 of=/home/sda2.img bs=4096

# 远程备份磁盘
ssh root@10.40.0.9 "dd if=/dev/sda | gzip -1 -" | dd of=backup.gz

# 覆写磁盘
dd if=/dev/zero of=/dev/sda1
dd if=/dev/urandom of=/dev/sda1

# 监控进度
apt install pv
dd if=/dev/urandom | pv | dd of=/dev/sdc1
```



## 5.2 格式化

```bash
fdisk /dev/sdb

mkfs.ext4 /dev/sdb1

mkdir -p /data
mount /dev/sdb1 /data

cat >> /etc/fstab <<EOF
/dev/sdb1 /data ext4 defaults 0 0
EOF
```





# 6. 文本编辑

## 6.1 vim

设置tab键大小：

```bash
vi /etc/vim/vimrc
set tabstop=4
```



删除空行：

```bash
:g/^$/d  删除空行
:g/^\s*//g  删除行首空格
:g/\s*$//g  删除行尾空格
```



# 7. 权限控制

## 7.1  suid, sgid, sbit

- suid: 二进制可执行文件(u+rx)，执行时，临时获取该文件的属主权限
- sgid: 二进制可执行文件(g+rx)，执行时，临时获取该文件的属组权限
           目录(g+rwx)，在目录下新建的文件，文件属组与目录一致
- sbit：目录，在目录下新建文件，只有文件所有者可以删除



# 8. find

## 8.1 xargs

当路径存在空格等字符时

```bash
find ./ -name '*.bak' -print0 | xargs -0 rm -rf
```



# 9. 进程内存

```bash
# 1. 通过进程的 status
$ cat /proc/1127/status
Name:   python3
Umask:  0022
State:  S (sleeping)
Tgid:   1127
Ngid:   0
Pid:    1127
PPid:   862
TracerPid:      0
Uid:    1000    1000    1000    1000
Gid:    1000    1000    1000    1000
FDSize: 64
Groups: 4 24 27 30 46 116 1000
NStgid: 1127
NSpid:  1127
NSpgid: 1127
NSsid:  862
VmPeak:   108340 kB
VmSize:   108340 kB
VmLck:         0 kB
VmPin:         0 kB
VmHWM:     83356 kB
VmRSS:     83076 kB   # 物理内存占用
...

# 2. 通过 pmap 详情
$ pmap -x 1127
1127:   /home/ubuntu/venv/bin/python3 ./main.py
Address           Kbytes     RSS   Dirty Mode  Mapping
0000000000400000     140     140       0 r---- python3.8
0000000000423000    2656    2656       0 r-x-- python3.8
00000000006bb000    2292     852       0 r---- python3.8
00000000008f8000       4       4       4 r---- python3.8
00000000008f9000     284     284     272 rw--- python3.8
0000000000940000     140     140     140 rw---   [ anon ]
0000000001422000   11476   11408   11408 rw---   [ anon ]
00007f5f20ceb000    1024     796     796 rw---   [ anon ]
...
---------------- ------- ------- -------
total kB          108344   83120   64816

# 3. 通过 smaps
$ cat /proc/1127/smaps | grep '^Rss:' | awk '{sum +=$2} END{print sum}'
83120

# 4. 通过 ps 命令
$ ps -e -o 'pid,comm,args,pcpu,rsz,vsz,stime,user,uid' | awk '$1 ~ /1127/'
   1127 python3         /home/ubuntu/venv/bin/pytho  0.1 83076 108340 Oct08 ubuntu    1000

# 按内存占用排序
$ ps -e -o 'pid,comm,args,pcpu,rsz,vsz,stime,user,uid' | grep python | sort -k5nr
   1127 python3         /home/ubuntu/venv/bin/pytho  0.1 83076 108340 Oct08 ubuntu    1000
 189813 grep            grep --color=auto python     0.0   656   6432 17:18 root         0
    771 networkd-dispat /usr/bin/python3 /usr/bin/n  0.0 20728  37132 Oct08 root         0
    862 supervisord     /usr/bin/python3 /usr/bin/s  0.0 23992  31396 Oct08 root         0
    863 unattended-upgr /usr/bin/python3 /usr/share  0.0 21464 115524 Oct08 root         0

# 方法2
$ ps -e -o 'pid,comm,args,pcpu,rsz,vsz,stime,user,uid' --sort -rsz | grep python
   1127 python3         /home/ubuntu/venv/bin/pytho  0.1 83076 108340 Oct08 ubuntu    1000
    862 supervisord     /usr/bin/python3 /usr/bin/s  0.0 23992  31396 Oct08 root         0
    863 unattended-upgr /usr/bin/python3 /usr/share  0.0 21464 115524 Oct08 root         0
    771 networkd-dispat /usr/bin/python3 /usr/bin/n  0.0 20728  37132 Oct08 root         0
 189821 grep            grep --color=auto python     0.0   656   6432 17:21 root         0
 
# 内存使用前10
$ ps aux | sort -k4,4nr | head -n 10

# 5. top (P：按CPU排序，M: 按内存排序)
top -p 1127
```



# 10. 串口

```bash
# 串口个数
dmesg | grep ttyS*

# 串口驱动信息
cat /proc/tty/driver/serial

# 串口波特率
stty -a -F /dev/ttyS4

# usb
lsusb
Bus 001 Device 005: ID 1a86:7523 QinHeng Electronics HL-340 USB-Serial adapter 

modprobe usbserial vendor=0x1a86 product=0x7523


# dmesg | grep ttyUSB
[   32.932894] usb 1-1.3: generic converter now attached to ttyUSB0
# chmod 777 /dev/ttyUSB0
# microcom -s 115200 /dev/ttyUSB0

# 查询串口
stty -F /dev/ttyS0

# 设置串口
stty -F /dev/ttyS0 speed 115200 cs8 -parenb -cstopb    115200   波特率 8数据位 1停止位 无校验

# 读取数据
cat /dev/ttyS0

# 发送数据
echo "test data" > /dev/ttyS0
```



# 11. tcpdump

```bash
tcpdump -i ens3 dst ip port tcp port 5236 and host 172.16.24.13 -w dm.cap

tcpdump tcp -i eth3 src host 192.168.3.107 -w ./a.cap

tcpdump ip host 192.168.3.195 and 192.168.3.155 -w ./a.cap
```



# 12. 远程登录黑名单

```bash
#!/usr/bin/env bash

lastb | awk '{print $3}' | grep ^[0-9] | sort | uniq -c | awk '{print $1"\t"$2}' | while read line; do
do
    num=$(echo $line | awk '{print $1}')
    ip=$(echo $line | awk '{print $2}')
    if [[ "$num" -ge 10 ]]; then
        grep "$ip" /etc/hosts.deny > /dev/null 2>&1
        if [[ "$?" -gt 0 ]]; then
            echo "# $(date +%F' '%H:%M:%S)" >> /etc/hosts.deny
            echo "sshd:$ip" >> /etc/hosts.deny
        fi
    fi
done
```

