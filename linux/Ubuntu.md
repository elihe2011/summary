# 1. apt-get

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
    dns-nameservers 8.8.8.8
```



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
