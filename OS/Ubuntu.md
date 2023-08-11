# 1. apt

## 1.1 apt-get

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

# 只下载不安装：/var/cache/apt/archives 
apt install -d mosquitto
```



## 1.2 apt-key

```bash
apt-key list
pub   1024R/B455BEF0 2010-07-29
uid                  Launchpad clicompanion-nightlies

# 删除
apt-key del B455BEF0
```



## 1.3 add-apt-repository

```bash
# 添加PPA源
add-apt-repository ppa:user/ppa-name
apt-get update

# 删除PPA源
add-apt-repository -r ppa:user/ppa-name

# 方法二，找到源文件，然后删除
cd /etc/apt/sources.list.d/
```





# 2. NFS 服务

## 2.1 服务端

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



## 2.2 客户端

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



## 2.3 无法启动

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





# 3. 默认编辑器

```bash
sudo update-alternatives --config editor
```



# 4. 远程桌面

## 4.1 xrdp

```bash
# 1. 安装相关软件
apt install vino
apt install dconf-editor

# 2. 系统重启
reboot

# 3. 依次展开org->gnome->desktop->remote-access，将 requre-encryption 设为 False。
dconf-editor

# 4. 安装xrdp
apt install xrdp

# 5. 解决远程连接黑屏
vi /etc/xrdp/startwm.sh
...
### 新增如下三行
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
. $HOME/.profile

if test -r /etc/profile; then
...

# 6. 重启xrdp
systemctl restart xrdp
```



## 4.2 vnc

```bash
apt install x11vnc

# 设置密码
x11vnc -storepasswd

# 配置文件
cat <<EOF > /etc/systemd/system/x11vnc.service
[Unit]
Description="x11vnc"
Requires=display-manager.service
After=display-manager.service

[Service]
ExecStart=/usr/bin/x11vnc -xkb -noxrecord -noxfixes -noxdamage -display :0 -auth guess -rfbauth /root/.vnc/passwd
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# 开机启动
systemctl daemon-reload
systemctl start x11vnc
systemctl enable x11vnc
```



# 5. 网络配置

## 5.1 ubuntu16

```bash
vi /etc/network/interfaces
auto ens33
iface ens33 inet static
address 192.168.80.200
netmask 255.255.255.0
gateway 192.168.80.2
dns-nameserver 8.8.8.8

systemctl restart networking.service
```



# 6. 升级内核

## 6.1 ubuntu16

https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.6-yakkety/

```bash
wget --no-check-certificate https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.6.7/linux-headers-4.6.7-040607_4.6.7-040607.201608160432_all.deb
wget --no-check-certificate https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.6.7/linux-headers-4.6.7-040607-generic_4.6.7-040607.201608160432_amd64.deb
wget --no-check-certificate https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.6.7/linux-image-4.6.7-040607-generic_4.6.7-040607.201608160432_amd64.deb
```



安装：

```bash
dpkg -i *.deb
reboot

uname -r
4.6.7-040607-generic
```



# 7. 安装 Python

PPA方式：Personal Package Archive

```bash
add-apt-repository ppa:deadsnakes/ppa 

apt update 
apt install python3.9 
```



源码方式：

```bash
# 编译工具
apt install -y wget build-essential checkinstall 
apt install -y libreadline-gplv2-dev libncursesw5-dev libssl-dev \
    libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev 
    
# 下载源码    
wget https://www.python.org/ftp/python/3.9.6/Python-3.9.6.tgz 

# 编译
tar zxvf Python-3.9.6.tgz 
cd Python-3.9.6 
./configure --enable-optimizations 

make altinstall 
```



# 8. Samba

磁盘分区、格式化、挂载：

```bash
fdisk /dev/vdb

mkfs.ext4 /dev/vdb1

mkdir -p /data

cat >> /etc/fstab <<EOF
/dev/vdb1              /data                    ext4    defaults        0 0
EOF

mount -a

mount -l | grep /data
```



安装 samba：

```bash
apt install samba -y

netstat -tulnp | grep smbd
tcp        0      0 0.0.0.0:445             0.0.0.0:*               LISTEN      18039/smbd
tcp        0      0 0.0.0.0:139             0.0.0.0:*               LISTEN      18039/smbd
tcp6       0      0 :::445                  :::*                    LISTEN      18039/smbd
tcp6       0      0 :::139                  :::*                    LISTEN      18039/smbd


smbpasswd -a root    # 密码root

mkdir -p /data
chmod 755 /data
chown root /data


vi /etc/samba/smb.conf 

[data]
   path = /data
   browseable = yes
   read only = no
   valid user = root
   

systemctl restart smbd
```



# Z. 问题

## 1. 虚拟机磁盘问题

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



## 2. DNS 配置

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
dns-nameserver 8.8.8.8
```



You are likely running `systemd-resolved` as a service.

`systemd-resolved` generates two configuration files on the fly, for optional use by DNS client libraries (such as the BIND DNS client library in C libraries):

- `/run/systemd/resolve/stub-resolv.conf` tells DNS client libraries to send their queries to 127.0.0.53. This is where the `systemd-resolved` process listens for DNS queries, which it then forwards on.
- `/run/systemd/resolve/resolv.conf` tells DNS client libraries to send their queries to IP addresses that `systemd-resolved` has obtained on the fly from its configuration files and DNS server information contained in DHCP leases. Effectively, this bypasses the `systemd-resolved` forwarding step, at the expense of also bypassing all of `systemd-resolved`'s logic for making complex decisions about what to actually forward to, for any given transaction.

In both cases, `systemd-resolved` configures a search list of domain name suffixes, again derived on the fly from its configuration files and DHCP leases (which it is told about via a mechanism that is beyond the scope of this answer).

`/etc/resolv.conf` can optionally be:

- a symbolic link to either of these;
- a symbolic link to a package-supplied *static* file at `/usr/lib/systemd/resolv.conf`, which also specifies 127.0.0.53 but no search domains calculated on the fly;
- some other file entirely.

It's likely that you have such a symbolic link. In which case, the thing that knows about the 192.168.1.1 setting, that is (presumably) handed out in DHCP leases by the DHCP server on your LAN, is `systemd-resolved`, which is forwarding query traffic to it as you have observed. Your DNS client libraries, in your applications programs, are themselves only talking to `systemd-resolved`.

Ironically, although it *could* be that you haven't captured loopback interface traffic to/from 127.0.0.53 properly, it is more likely that you aren't seeing it because `systemd-resolved` also (optionally) bypasses the BIND DNS Client in your C libraries and generates no such traffic to be captured.

There's an NSS module provided with `systemd-resolved`, named `nss-resolve`, that is a plug-in for your C libraries. Previously, your C libraries would have used another plug-in named `nss-dns` which uses the BIND DNS Client to make queries using the DNS protocol to the server(s) listed in `/etc/resolv.conf`, applying the domain suffixes listed therein.

`nss-resolve` gets listed *ahead* of `nss-dns` in your `/etc/nsswitch.conf` file, causing your C libraries to not use the BIND DNS Client, or the DNS protocol, to perform name→address lookups at all. Instead, `nss-resolve` speaks a non-standard and idiosyncratic protocol over the (system-wide) Desktop Bus to `systemd-resolved`, which again makes back end queries of 192.168.1.1 or whatever your DHCP leases and configuration files say.

To intercept *that* you have to monitor the Desktop Bus traffic with `dbus-monitor` or some such tool. It's not even IP traffic, let alone IP traffic over a loopback network interface. as the Desktop Bus is reached via an `AF_LOCAL` socket.

If you want to use a third-party resolving proxy DNS server at 1.1.1.1, or some other IP address, you have three choices:

- Configure your DHCP server to hand that out instead of handing out 192.168.1.1. `systemd-resolved` will learn of that via the DHCP leases and use it.
- Configure `systemd-resolved` via its own configuration mechanisms to use that instead of what it is seeing in the DHCP leases.
- Make your own `/etc/resolv.conf` file, an actual regular file instead of a symbolic link, list 1.1.1.1 there and remember to turn off `nss-resolve` so that you go back to using `nss-dns` and the BIND DNS Client.

The `systemd-resolved` configuration files are a whole bunch of files in various directories that get combined, and how to configure them for the second choice aforementioned is beyond the scope of this answer. Read the `resolved.conf`(5) manual page for that.



## 3. openssl 配置问题

```bash
$ openssl req -new -key eli.key -out eli.csr -subj "/CN=eli/O=exped.top"
Can't load /root/.rnd into RNG
139723054526912:error:2406F079:random number generator:RAND_load_file:Cannot open file:../crypto/rand/randfile.c:88:Filename=/root/.rnd
```

解决办法：

```bash
$ vi /etc/ssl/openssl.cnf
#RANDFILE               = $ENV::HOME/.rnd
```



## 4. apt 操作被锁定

```bash
E: Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)  
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend),   
 is another process using it?
```

问题根因：

1. 'Synaptic Package Manager' or 'Software Updater' is open.
2. Some apt command is running in Terminal.
3. Some apt process is running in background.

解决办法：

```bash
killall apt apt-get

rm /var/lib/apt/lists/lock
rm /var/cache/apt/archives/lock
rm /var/lib/dpkg/lock*

dpkg --configure -a

apt update
```



解决自动更新：

```bash
vi /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "0";
```

