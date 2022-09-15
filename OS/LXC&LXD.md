# 1. 概述

## 1.1 LXC 

LXC是Linux Containers的缩写。它是一种虚拟化技术，通过一个Linux内核在一个受控主机上虚拟地运行多个Linux系统。

**LXC使用内核的Cgroups功能，来提供进程和网络空间的隔离，来替代通过创建一个完整的虚拟机来为应用程序提供隔离环境。**

LXC容器技术里的分散存储是绑定安装的，来为用户达到主机或者另一个容器。

LXC起源于cgroup和namespaces，使得进程之间相互隔离，即进程虚拟化。 



## 1.2 LXD

LXC的升级版，解决了LXC中存在的一些缺点，比如无法有效支持跨主机之间的容器迁移、管理复杂。



## 1.3 Docker 

Docker是一个开源工具，**用于在集中平台上创建、部署和运行应用程序.这使得主机的操作系统通过容器来运行具有相同Linux内核的应用程序，而不是创建一个完整的虚拟机**。

使用docker容器，你不需要关心Ram和磁盘空间的分配。它能够自己处理需求。



## 1.4 不同点

**LXD/LXC是一个系统容器，而docker是一个应用程序容器。**

LXC/LXD和docker不同的地方在于**LXC/LXD中包含完整的操作系统**。

<img src=".\images\lxc-vs-docker.png" style="zoom: 80%;" />

<table style="width:100%">
<thead>
<tr>
<th style="width:10%">Parameter</th>
<th>LXC</th>
<th>Docker</th>
</tr>
</thead>
<tbody>
<tr>
<td>Developed by</td>
<td>LXC was created by IBM, Virtuozzo, Google and Eric Biederman.</td>
<td>Docker was created by Solomon Hykes in 2003.</td>
</tr>
<tr>
<td>Data Retrieval</td>
<td>LXC does not support data retrieval after it is processed.</td>
<td>Data retrieval is supported in Docker.</td>
</tr>
<tr>
<td>Usability</td>
<td>It is a multi-purpose solution for virtualization.</td>
<td>It is single purpose solution.</td>
</tr>
<tr>
<td>Platform</td>
<td>LXC is supported only on Linux platform.</td>
<td>Docker is platform dependent.</td>
</tr>
<tr>
<td>Virtualization</td>
<td>LXC provides us full system virtualization.</td>
<td>Docker provides application virtualization.</td>
</tr>
<tr>
<td>Cloud support</td>
<td>There is no need for cloud storage as Linux provides each feature.</td>
<td>The need of cloud storage is required for a sizeable ecosystem.</td>
</tr>
<tr>
<td>Popularity</td>
<td>Due to some constraints LXC is not much popular among the developers.</td>
<td>Docker is popular due to containers and it took containers to a next level.</td>
</tr>
</tbody>
</table>



# 2. LXC

## 2.1 安装

```bash
# 1. 安装
$ apt install lxc

# 2. 检查内核是否支持
$ lxc-checkconfig

# 3. 新增网桥
$ ip addr show lxcbr0
3: lxcbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 00:16:3e:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.3.1/24 scope global lxcbr0
       valid_lft forever preferred_lft forever
```



## 2.2 容器模板

内置容器模板 (模板本质上是一个脚本，创建容器时调用它们)：

```bash
$ ls /usr/share/lxc/templates
lxc-alpine    lxc-archlinux  lxc-centos  lxc-debian    lxc-fedora  lxc-openmandriva  lxc-oracle  lxc-slackware   lxc-sshd    lxc-ubuntu-cloud
lxc-altlinux  lxc-busybox    lxc-cirros  lxc-download  lxc-gentoo  lxc-opensuse      lxc-plamo   lxc-sparclinux  lxc-ubuntu
```



## 2.3  容器管理

### 2.3.1 创建

```bash
# 不指定版本，默认使用最新版本
lxc-create -n <container> -t ubuntu 

# 指定版本
lxc-create -n <container> -t ubuntu -- --release utopic 

# 使用其他源
lxc-create -t download -n my-container -- --server mirrors.tuna.tsinghua.edu.cn/lxc-images
```



### 2.3.2 查看

```bash
# 容器目录
$ ls /var/lib/lxc
ubuntu

# 容器rootfs
$ ls /var/lib/ubuntu
config  rootfs

# 查看容器
$ lxc-ls --fancy
NAME   STATE   AUTOSTART GROUPS IPV4 IPV6
ubuntu STOPPED 0  
```



### 2.2.3 启停删除

```bash
# 启动容器
$ lxc-start -n ubuntu -d
$ lxc-ls --fancy
NAME   STATE   AUTOSTART GROUPS IPV4       IPV6
ubuntu RUNNING 0         -      10.0.3.171 -

# 网桥
$ brctl show lxcbr0
bridge name     bridge id               STP enabled     interfaces
lxcbr0          8000.00163e000000       no              vethGC90KU

# 删除容器
lxc-stop -n ubuntu
lxc-destroy -n ubuntu
```



### 2.2.4 进入容器

```bash
# 1. lxc-attach
$ lxc-attach -n ubuntu
$ lxc-attach -n ubuntu -- /bin/bash
$ lxc-attach -n ubuntu -e -s 'NETWORK|UTSNAME'  # 提升特权，并指定名字空间，在测试主机上软件时很有用

# 2. 打开容器控制台 (crtl+a q 退出控制台)
$ lxc-console -n ubuntu 

# 3. ssh
$ ssh ubuntu@10.0.3.171
```



### 2.2.5 克隆容器

"克隆"要么是其他容器的一份拷贝，要么是其他容器的一份快照。

- **拷贝：**完整的复制原来的容器，所占的空间和原来的容器一样大

- **快照：**利用后台文件系统的快照功能，创建一个很小的新容器，在发生写操作时才进行复制

要想使快照拥有这个写时复制的特性，需要一个特殊存储系统，支持快照的存储方式有：aufs，btrfs，LVM，overlayfs，zfs等，每种存储方式各有自己特点。

克隆：

```bash
$ lxc-stop -n ubuntu
$ lxc-copy -n ubuntu -N ubuntu-new
```

快照：创建的快照位于/var/lib/lxc/容器名目录下，快照名字为snap0，snap1…

```bash
$ lxc-copy -s -n ubuntu -N ubuntu-new

$ lxc-snapshot -n ubuntu -r snap0 -N ubuntu-new
```



### 2.2.6 其他命令

```bash
# 执行命令
lxc-execute -n ubuntu [-f config] /bin/bash

# 容器信息
lxc-info -n NAME

# 容器列表信息
lxc-ls --fancy 

# 监控容器：当容器状态变化时，在屏幕上打印信息
lxc-monitor -n "ubuntu|debian"
lxc-monitor -n ".*"   # 所有容器

# 监听容器特定状态后退出
lxc-wait -n ubuntu -s STOPPED &

# 设置或获取cgroup相关参数
lxc-cgroup -n ubuntu cpuset.cpus
lxc-cgroup -n ubuntu cpu.shares 512

# 创建和恢复快照
lxc-snapshot

# 冻结该容器所有的进程
lxc-freeze -n ubuntu

# 解除冻结
lxc-unfreeze -n ubuntu
```





# 3. LXD

## 3.1 概念

### 3.1.1 基础

LXD 就是一个提供了 REST API 的 LXC 容器管理器，LXD 最主要的目标就是使用 Linux 容器而不是硬件虚拟化向用户提供一种接近虚拟机的使用体验

LXD 聚焦于系统容器，通常也被称为架构容器。这就是说 LXD 容器实际上如在裸机或虚拟机上运行一般运行了一个完整的 Linux 操作系统。

**Docker 关注于短期的、无状态的、最小化的容器**，这些容器通常并不会升级或者重新配置，而是作为一个整体被替换掉。这就使得 Docker 及类似项目更像是一种软件发布机制，而不是一个机器管理工具。

可以使用 LXD 为你的用户提供一个完整的 Linux 系统，然后他们可以在 LXD 内安装 Docker 来运行他们想要的软件。

作为一个长时间运行的守护进程， LXD 可以绕开 LXC 的许多限制，比如动态资源限制、无法进行容器迁移和高效的在线迁移；同时，它也为创造新的默认体验提供了机会：默认开启安全特性，对用户更加友好。



### 3.1.2 容器

LXD 中的容器包括以下及部分：

- 根文件系统（rootfs）
- 配置选项列表，包括资源限制、环境、安全选项等等
- 设备：包括磁盘、unix 字符/块设备、网络接口
- 一组继承而来的容器配置文件
- 属性（容器架构、暂时的还是持久的、容器名）
- 运行时状态（当用 CRIU 来中断/恢复时）



### 3.1.3 快照

容器快照和容器是一回事，只不过快照是不可修改的，只能被重命名，销毁或者用来恢复系统，但是无论如何都不能被修改。

LXD 允许用户保存容器的运行时状态，可提供“有状态”的快照功能。可使用快照回滚容器的状态，包括快照当时的 CPU 和内存状态



### 3.1.4 镜像

LXD 基于镜像实现，容器镜像通常是一些纯净的 Linux 发行版的镜像，可以使用容器制作一个镜像并在本地或者远程 LXD 主机上使用。

镜像通常使用 sha256 哈希码来区分，但哈希码对用户来说不方便，所以镜像可以使用几个自身的属性来区分

LXD 安装时已经配置好了三个远程镜像服务器：

- “ubuntu”：提供稳定版的 Ubuntu 镜像
- “ubuntu-daily”：提供 Ubuntu 的每日构建镜像
- “images”： 社区维护的镜像服务器，提供一系列的其它 Linux 发布版，使用的是上游 LXC 的模板

LXD 守护进程会从镜像上次被使用开始自动缓存远程镜像一段时间（默认是 10 天），超过时限后这些镜像才会失效。LXD 还会自动更新远程镜像（除非指明不更新），所以本地的镜像会一直是最新版的。



### 3.1.5 配置

配置文件是一种在一个地方定义容器配置和容器设备，然后将其应用到一系列容器的方法。

一个容器可以被应用多个配置文件。当构建最终容器配置时（即通常的扩展配置），这些配置文件都会按照他们定义顺序被应用到容器上，当有重名的配置键或设备时，新的会覆盖掉旧的。然后本地容器设置会在这些基础上应用，覆盖所有来自配置文件的选项。

LXD 自带两种预配置的配置文件：

- “default”配置是自动应用在所有容器之上，除非用户提供了一系列替代的配置文件。目前这个配置文件只做一件事，为容器定义 eth0 网络设备。
- “docker”配置是一个允许你在容器里运行 Docker 容器的配置文件。它会要求 LXD 加载一些需要的内核模块以支持容器嵌套并创建一些设备。



### 3.1.6 lxc 命令

LXD 是一个基于网络的守护进程。其lxc命令行客户端可以与多个远程 LXD 服务器、镜像服务器通信。

默认情况下，lxc命令行客户端会与下面几个预定义的远程服务器通信：

- local：默认的远程服务器，使用 UNIX socket 和本地的 LXD 守护进程通信
- ubuntu：Ubuntu 镜像服务器，提供稳定版的 Ubuntu 镜像
- ubuntu-daily：Ubuntu 镜像服务器，提供 Ubuntu 的每日构建版
- images：images.linuxcontainers.org 的镜像服务器



### 3.1.7 安全性

LXD 的设计核心，就是在不修改 Linux 发行版的前提下，使容器尽可能的安全

主要的安全特性：

- 内核命名空间：尤其在用户命名空间，它让容器和系统剩余部分完全隔离。LXD默认使用用户命名空间（和LXC相反），并允许用户在需要的时候，以容器未单位关闭（将容器标记为“特权的”）
- Seccomp 系统调用：用来隔离潜在危险的系统调用
- AppArmor：对 mount、socket、ptrace 和文件访问提供额外的限制，特别是限制跨容器通信
- Capabilities：阻止容器加载内核模块，修改主机系统时间等
- CGroups：限制资源使用，防止针对主机的 DDoS 攻击



### 3.1.8 REST 接口

LXD 的工作都是通过 REST 接口实现的。在客户端和守护进程之间并没有其他的通讯渠道。

REST 接口可以通过本地的 unix socket 访问，只需要经过用户组认证，或者经过 HTTP 套接字使用客户端认证进行通信。 

REST 接口的结构能够和上文所说的不同的组件匹配，是一种简单、直观的使用方法。 

当需要一种复杂的通信机制时， LXD 将会进行 websocket 协商完成剩余的通信工作。这主要用于交互式终端会话、容器迁移和事件通知。



## 3.2 部署

**强烈推荐 ubuntu18.04**，16和20均存在各种小问题，解决起来不容易

### 3.2.1 安装

```bash
# 1. 安装
$ apt install lxd lxd-client -y

# 2. 初始化 (配置存储后端、添加网桥并新增IPv4/IPv6网络等)
$ lxd init

$ ip addr show lxdbr0
3: lxdbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.68.193.1/24 scope global lxdbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::58e5:58ff:fefa:d2/64 scope link
       valid_lft forever preferred_lft forever
```



### 3.2.2 存储

| STORAGE LOCATION         | DIRECTORY | BTRFS | LVM  | ZFS  | CEPH | CEPHFS |
| ------------------------ | --------- | ----- | ---- | ---- | ---- | ------ |
| Shared with the host     | ✓         | ✓     | -    | ✓    | -    | -      |
| Dedicated disk/partition | -         | ✓     | ✓    | ✓    | -    | -      |
| Loop disk                | ✓         | ✓     | ✓    | ✓    | -    | -      |
| Separate storage         | -         | -     | -    | -    | ✓    | ✓      |

1）ZFS：推荐使用，它能支持 LXD 的全部特性，同时提供最快和可靠的容器体验。支持以容器为单位的磁盘配额、即时快照和恢复、优化后的迁移（发送/接收），以及快递从镜像创建容器的能力。比 btrfs 更成熟


```bash
# 支持ZFS存储
$ apt install zfsutils-linux -y

# 指定zfs存储
$ lxd init    
Would you like to use LXD clustering? (yes/no) [default=no]:
Do you want to configure a new storage pool? (yes/no) [default=yes]:
Name of the new storage pool [default=default]:
Name of the storage backend to use (lvm, zfs, ceph, btrfs, dir) [default=zfs]:
Create a new ZFS pool? (yes/no) [default=yes]:
Would you like to use an existing empty block device (e.g. a disk or partition)? (yes/no) [default=no]: yes
Path to the existing block device: /dev/sdb
Would you like to connect to a MAAS server? (yes/no) [default=no]:
Would you like to create a new local network bridge? (yes/no) [default=yes]:
What should the new bridge be called? [default=lxdbr0]:
What IPv4 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]:
What IPv6 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: none
Would you like the LXD server to be available over the network? (yes/no) [default=no]: yes
Address to bind LXD to (not including port) [default=all]:
Port to bind LXD to [default=8443]:
Trust password for new clients:
Again:
Would you like stale cached images to be updated automatically? (yes/no) [default=yes]
Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]:
```



2）btrfs：提供与 ZFS 同级别的集成，支持磁盘配额，但不能正确报告容器内磁盘的使用情况。同时 btrfs 拥有很好的嵌套属性(ZFS不具备)，及可以在 LXD 中再使用 LXD。

使用 btrfs 不需要进行配置，只要确保 `/var/lib/lxd` 是 btrfs 文件系统即可

```bash
# 之前使用过该磁盘，存在分区表
$ lxc storage create lxd-btrfs btrfs source=/dev/sdc
Error: Failed to create the BTRFS pool: /dev/sdc appears to contain a partition table (dos).
ERROR: use the -f option to force overwrite of /dev/sdc
btrfs-progs v4.15.1
See http://btrfs.wiki.kernel.org for more information.

# 清掉分区表
dd if=/dev/zero of=/dev/sdc bs=512 count=1024

# 重新创建
$ lxc storage create lxd-btrfs btrfs source=/dev/sdc

# 存储列表
$ lxc storage list
+-----------+-------------+--------+--------------------------------------+---------+
|   NAME    | DESCRIPTION | DRIVER |                SOURCE                | USED BY |
+-----------+-------------+--------+--------------------------------------+---------+
| default   |             | zfs    | default                              | 2       |
+-----------+-------------+--------+--------------------------------------+---------+
| lxd-btrfs |             | btrfs  | 121bc9a5-1435-4606-9625-a78478182d69 | 0       |
+-----------+-------------+--------+--------------------------------------+---------+

# 容器创建在指定存储池
$ lxc launch images:ubuntu/xenial c2 -s lxd-btrfs
$  lxc list
+------+---------+----------------------+------+------------+-----------+
| NAME |  STATE  |         IPV4         | IPV6 |    TYPE    | SNAPSHOTS |
+------+---------+----------------------+------+------------+-----------+
| c2   | RUNNING | 10.68.193.229 (eth0) |      | PERSISTENT | 0         |
+------+---------+----------------------+------+------------+-----------+

# 创建自定义存储卷
$ lxc storage volume create lxd-btrfs lxd-custom-volume
$ lxc storage volume list lxd-btrfs
+--------+-------------------+-------------+---------+
|  TYPE  |       NAME        | DESCRIPTION | USED BY |
+--------+-------------------+-------------+---------+
| custom | lxd-custom-volume |             | 0       |
+--------+-------------------+-------------+---------+

# 将其连接到容器中
$ lxc storage volume attach lxd-btrfs lxd-custom-volume c2 data /data
$ lxc exec c2 -- df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc         10G  452M  7.7G   6% /
none            492K     0  492K   0% /dev
udev            1.9G     0  1.9G   0% /dev/tty
tmpfs           100K     0  100K   0% /dev/lxd
tmpfs           100K     0  100K   0% /dev/.lxd-mounts
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           2.0G  8.5M  2.0G   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sdc         10G  452M  7.7G   6% /data
```



3）LVM：LXD会以自动精简配置的方式使用 LVM，为每个镜像和容器创建 LV，同时也支持 LVM 的快照功能

```bash
# 创建VG并使用
fdsik /dev/sdc
pvcreate /dev/sdc1
vgcreate -s 1000M lxd_vg /dev/sdc1
lxc config set storage.lvm_vg_name "lxd_vg"

# 默认以 ext4 文件系统，可修改为 xfs
lxc config set storage.lvm_fstype xfs
```



4）目录：为每个容器创建一个目录，然后再创建容器时解压镜像压缩包，并再容器拷贝和快照时进行一次完整的文件系统拷贝

除磁盘配额外的特性都支持，但很浪费磁盘空间，并且非常慢，不建议在生产环境使用



### 3.2.3 网络

默认情况下，LXD不会监听网络，唯一的通信只能通过 `/var/lib/lxd/unix.socket`

```bash
# 绑定到监听IP和端口
lxc config set core.https_address [::]
lxc config set core.https_address 0.0.0.0:8443

# 设置密码
lxc config set core.trust_password 'mypass'

# 证书方式：客户端证书存放在 `~/.config/lxc` 下，然
lxc config trust add client.crt
```



### 3.2.4 代理

```bash
lxc config set core.proxy_http   http://192.168.3.3:3128
lxc config set core.proxy_https  http://192.168.3.3:3128
lxc config set core.proxy_ignore_hosts  image-server.local
```



### 3.2.5 镜像缓存

LXD 使用动态镜像缓存。创建容器时，自动从远程将镜像下载到本地镜像仓库，同时标记为已缓存并记录来源。几天后（默认10天），如果改镜像未被使用过，它将自动被删除。每个几小时（默认6小时），检查镜像是否有新版本，然后更新本地镜像

```bash
lxc config set images.remote_cache_expiry 5
lxc config set images.auto_update_interval 24
lxc config set images.auto_update_cached false
```



## 3.3 容器管理

### 3.3.1 创建

```bash
# 创建但不启动
lxc init  [<remote>:]<image> [<remote>:][<name>]

# 创建并启动
lxc launch  [<remote>:]<image> [<remote>:][<name>]
```

示例：
```bash
$ lxc image list ubuntu: | grep '22.04 LTS amd64'

$ lxc launch ubuntu:22.04 ubuntu22
```



### 3.3.2 列表


```bash
# 容器列表
$ lxc list
+------+---------+----------------------+------+------------+-----------+
| NAME |  STATE  |         IPV4         | IPV6 |    TYPE    | SNAPSHOTS |
+------+---------+----------------------+------+------------+-----------+
| c2   | RUNNING | 10.68.193.229 (eth0) |      | PERSISTENT | 0         |
+------+---------+----------------------+------+------------+-----------+


# 存在大量容器时，过滤一些耗时选项，快速展示列表
$ lxc list --fast   
+------+---------+--------------+----------------------+----------+------------+
| NAME |  STATE  | ARCHITECTURE |      CREATED AT      | PROFILES |    TYPE    |
+------+---------+--------------+----------------------+----------+------------+
| c2   | RUNNING | x86_64       | 2022/06/29 03:07 UTC | default  | PERSISTENT |
+------+---------+--------------+----------------------+----------+------------+


# 按名字或属性过滤
$ lxc list security.privileged=true   
$ lxc list --fast alpine
```



### 3.3.3 详情

```bash
$ lxc info c2 
Name: c2
Remote: unix://
Architecture: x86_64
Created: 2022/06/29 03:07 UTC
Status: Running
Type: persistent
Profiles: default
Pid: 3102
Ips:
  eth0: inet    10.68.193.229   veth645CE7
  eth0: inet6   fe80::216:3eff:fe10:1090        veth645CE7
  lo:   inet    127.0.0.1
  lo:   inet6   ::1
Resources:
  Processes: 9
  CPU usage:
    CPU usage (in seconds): 1
  Memory usage:
    Memory (current): 274.60MB
    Memory (peak): 341.36MB
  Network usage:
    eth0:
      Bytes received: 3.65kB
      Bytes sent: 3.07kB
      Packets received: 34
      Packets sent: 25
    lo:
      Bytes received: 0B
      Bytes sent: 0B
      Packets received: 0
      Packets sent: 0
```



### 3.3.4 生命周期

```bash
lxc start c2
lxc stop c2  --force
lxc restart c2  --force

lxc pause c2

lxc deletec2  --force
```



### 3.3.5 执行命令

```bash
# 进入容器
lxc exec c2 bash

# 设置环境变量（临时有效）
lxc exec c2 --env mykey=myvalue env | grep mykey
```



### 3.3.6 文件操作

```bash
# 从容器中取回文件
lxc file pull <container>/<path> <dest>

# 向容器中发送文件
lxc file push <source> <container>/<path>

# 修改容器中的文件
lxc file edit <container>/<path>
```



### 3.3.7 克隆

```bash
lxc copy <container> <new-container>
```



### 3.3.8 重命名

```bash
lxc stop <container>
lxc move <container> <new-container>
```



## 3.4  快照管理

```bash
# 创建快照: 名称默认snapX
lxc snapshot <container>

# 创建快照：自定义快照名称
lxc snapshot <container> <snapshot name>

# 快照列表
lxc info <container> | grep -A 10 Snapshots

# 恢复快照
lxc restore <container> <snapshot-name>

# 快照重命名
lxc move <container>/<snapshot-name> <container>/<new-snapshot-name>

# 通过快照创建新容器: 除MAC、IP等外，其他均与之前的相同
lxc copy <container>/<snapshot-name> <new-container>

# 删除快照
lxc delete <container>/<snapshot-name>
```



## 3.5 配置管理

### 3.5.1 系统配置

LXD 支持容器配置设定，包括资源限制，容器启动快照及对各种设备是否允许访问的配。

LXD 支持的设备类型：

- 磁盘：物理磁盘、一个被挂载到容器内的分区、来自主机的绑定挂载路径
- 网卡：物理网卡、虚拟网卡、点对点设备
- 块设备：比如 `/dev/sdc`
- 字符设备：比如 `/dev/kvm`
- none: 用来隐藏可以通过配置文件被继承的设备

```bash
# 获取配置列表
$ lxc profile list
default

# 配置详情
$ lxc profile show default
config: {}
description: Default LXD profile
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: lxdbr0
    type: nic
  root:
    path: /
    pool: default
    type: disk
name: default
used_by:
- /1.0/containers/c2

# 修改配置
$ lxc profile edit default

# 将配置应用到容器
$ lxc profile apply <container> <profile1>,<profile2>,<profile3>,...
```



### 3.5.2 本地配置

```bash
# 修改配置
lxc config edit <container>

# 单独配置
lxc config set <container> <key> <value>

# 添加设备
lxc config device add <container> kvm unix-char path=/dev/kvm

# 读取配置
lx config show <container>

# 所有配置项
lxc config show --expanded <container>
```



## 3.6 资源控制

### 3.6.1 CPU

```bash
# 限制使用任意两个CPU核心
lxc config set <container> limits.cpu 2

# 指定特定的CPU核心
lxc config set <container> limits.cpu 1,3
lxc config set <container> limits.cput 0-3,7-11

# 全局设置
lxc profile set default limits.cpu 3

# 限制CPU的使用时间
lxc config set <container> limits.cpu.allowance 10%

# 固定的CPU时间片
lxc config set <container> limits.cpu.allowance 25ms/200ms

# CPU优先级调至最低
lxc config set <container> limits.cpu.priority 0
```

示例：

```bash
$ lxc exec ubuntu20 -- cat /proc/cpuinfo | grep ^processor
processor       : 0
processor       : 1

$ lxc config set ubuntu20 limits.cpu 1

$ lxc exec ubuntu20 -- cat /proc/cpuinfo | grep ^processor
processor       : 0
```



### 3.6.2 MEM

```bash
# 限制内存大小：KB/MB/GB/TB/PB/EB
lxc config set <container> limits.memory 256MB

# 关闭交互分区
lxc config set <container> limits.memory.swap false

# 交换分区优先级
lxc config set <container> limits.memory.swap.priority 0

# 软性内存限制
lxc config set <container> limits.memory.enforce soft
```



### 3.6.3 磁盘和块IO

注意：需要 btrfs 或 ZFS

```bash
# 磁盘限制
lxc config device set <container> root size 20GB

# 限制IO频率
lxc config device set <container> root limits.read 20Iops
lxc config device set <container> root limits.write 10Iops

# 优先级调到最高
lxc config set <container> limits.disk.priority 10
```



### 3.6.5 网络IO

```bash
# 设置网络进出宽带
lxc profile device set default eth0 limits.ingress 100Mbit
lxc profile device set default eth0 limits.egress 100Mbit

# 设置网络优先级
lxc config set <container> limits.network.priority 5
```



示例：

```bash
$ lxc exec ubuntu-new -- wget http://speedtest.newark.linode.com/100MB-newark.bin -O /dev/null

$ lxc profile device set default eth0 limits.ingress 100Mbit
$ lxc profile device set default eth0 limits.egress 100Mbit

$ lxc exec ubuntu-new -- wget http://speedtest.newark.linode.com/100MB-newark.bin -O /dev/null
```



### 3.6.6 资源使用率

资源使用情况：

- 内存：当前、峰值
- swap：当前、峰值
- 磁盘：当前磁盘使用率
- 网络：每个接口传输的字节和包数

```bash
$ lxc info ubuntu20
Name: ubuntu20
Remote: unix://
Architecture: x86_64
Created: 2022/06/27 03:42 UTC
Status: Running
Type: persistent
Profiles: default
Pid: 8342
Ips:
  eth0: inet    10.40.0.248     vethQIBYM3
  eth0: inet6   fd1d:fcf1:6f8:38bf:216:3eff:fe89:5ba9   vethQIBYM3
  eth0: inet6   fe80::216:3eff:fe89:5ba9        vethQIBYM3
  lo:   inet    127.0.0.1
  lo:   inet6   ::1
Resources:
  Processes: 45
  Memory usage:
    Memory (current): 124.06MB
    Memory (peak): 161.09MB
  Network usage:
    eth0:
      Bytes received: 3.91kB
      Bytes sent: 2.78kB
      Packets received: 34
      Packets sent: 26
    lo:
      Bytes received: 308B
      Bytes sent: 308B
      Packets received: 4
      Packets sent: 4
Snapshots:
  my-snapshot (taken at 2022/06/28 02:22 UTC) (stateless)
```



## 3.7 镜像管理

容器镜像：

- LXC：基于模板。模板是导出一个容器文件系统以及一点配置的 shell 脚本。大多数模板通过在本机上执行一个完整的发行版自举生成改文件系统，这可能需要相当长的时间，并且无法在所有的发行版上可用，另外可能需要大量的网络带宽
- LXD：基于镜像。所有容器都是从镜像创建的，具有高级镜像缓存和预加载支持，以使镜像存储保持最新



### 3.7.1 镜像仓库

```bash
# 添加国内仓库
$ lxc remote add tuna-images https://mirrors.tuna.tsinghua.edu.cn/lxc-images/ --protocol=simplestreams --public
lxc image list tuna-images:

# 仓库列表
$ lxc remote list
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
|      NAME       |                       URL                        |   PROTOCOL    | AUTH TYPE | PUBLIC | STATIC |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| images          | https://images.linuxcontainers.org               | simplestreams |           | YES    | NO     |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| local (default) | unix://                                          | lxd           | tls       | NO     | YES    |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| lxc-02          | https://192.168.80.162:8443                      | lxd           | tls       | NO     | NO     |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| tuna-images     | https://mirrors.tuna.tsinghua.edu.cn/lxc-images/ | simplestreams |           | YES    | NO     |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| ubuntu          | https://cloud-images.ubuntu.com/releases         | simplestreams |           | YES    | YES    |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+
| ubuntu-daily    | https://cloud-images.ubuntu.com/daily            | simplestreams |           | YES    | YES    |
+-----------------+--------------------------------------------------+---------------+-----------+--------+--------+


# 本地仓库
$ lxc image list
$ lxc image list local:
+-------+--------------+--------+---------------------------------------+--------+---------+------------------------------+
| ALIAS | FINGERPRINT  | PUBLIC |              DESCRIPTION              |  ARCH  |  SIZE   |         UPLOAD DATE          |
+-------+--------------+--------+---------------------------------------+--------+---------+------------------------------+
|       | 3158ccbd7783 | no     | Busybox 1.34.1 amd64 (20220628_06:00) | x86_64 | 1.16MB  | Jun 29, 2022 at 1:30am (UTC) |
+-------+--------------+--------+---------------------------------------+--------+---------+------------------------------+
|       | f544fc3d0da4 | no     | Ubuntu xenial amd64 (20220628_07:43)  | x86_64 | 88.64MB | Jun 29, 2022 at 3:07am (UTC) |
+-------+--------------+--------+---------------------------------------+--------+---------+------------------------------+


# 远程仓库
$ lxc image list ubuntu:22.04
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
|       ALIAS        | FINGERPRINT  | PUBLIC |                  DESCRIPTION                  |  ARCH   |   SIZE   |          UPLOAD DATE          |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
| j (5 more)         | a0d7bbb3756a | yes    | ubuntu 22.04 LTS amd64 (release) (20220622)   | x86_64  | 403.14MB | Jun 22, 2022 at 12:00am (UTC) |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
| j/arm64 (2 more)   | 1833cdd18a76 | yes    | ubuntu 22.04 LTS arm64 (release) (20220622)   | aarch64 | 370.41MB | Jun 22, 2022 at 12:00am (UTC) |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
| j/armhf (2 more)   | feae0577d700 | yes    | ubuntu 22.04 LTS armhf (release) (20220622)   | armv7l  | 353.90MB | Jun 22, 2022 at 12:00am (UTC) |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
| j/ppc64el (2 more) | c7a8e485fd48 | yes    | ubuntu 22.04 LTS ppc64el (release) (20220622) | ppc64le | 395.88MB | Jun 22, 2022 at 12:00am (UTC) |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+
| j/s390x (2 more)   | 4fda5628283f | yes    | ubuntu 22.04 LTS s390x (release) (20220622)   | s390x   | 365.95MB | Jun 22, 2022 at 12:00am (UTC) |
+--------------------+--------------+--------+-----------------------------------------------+---------+----------+-------------------------------+


# 过滤镜像
$ lxc image list images: alpine   


# 镜像信息
$ lxc image info ubuntu:22.04
Fingerprint: a0d7bbb3756a64f56d17797535ef6641c73e69540defa0bd6b07b09f315257b4
Size: 403.14MB
Architecture: x86_64
Public: yes
Timestamps:
    Created: 2022/06/22 00:00 UTC
    Uploaded: 2022/06/22 00:00 UTC
    Expires: 2027/04/21 00:00 UTC
    Last used: never
Properties:
    release: jammy
    version: 22.04
    architecture: amd64
    label: release
    serial: 20220622
    description: ubuntu 22.04 LTS amd64 (release) (20220622)
    os: ubuntu
Aliases:
    - 22.04
    - 22.04/amd64
    - j
    - j/amd64
    - jammy
    - jammy/amd64
Cached: no
Auto update: disabled
```



### 3.5.2 下载镜像

```bash
# 从远程仓库复制镜像到本地仓库
lxc image copy ubuntu:18.04 local:
lxc launch ubuntu:18.04 c1  # 不存在，会自动下载

# 设置别名
lxc image copy ubuntu:18.04 local: --alias ubuntu18

# 保留远程仓库上的别名
lxc image copy ubuntu:15.10 local: --copy-aliases
lxc launch 15.10 c7

# 保持自动更新
lxc image copy images:alpine/3.15/cloud local: --alias alpine3.15 --auto-update
```



### 3.5.3 导出导入

```bash
# 导出
$ lxc image export ubuntu:22.04

$ ls -l ubuntu-22.04-*
-rw-r--r-- 1 root root       412 Jun 29 05:33 ubuntu-22.04-server-cloudimg-amd64-lxd.tar.xz
-rw-r--r-- 1 root root 422723584 Jun 29 06:09 ubuntu-22.04-server-cloudimg-amd64.squashfs

# 导入
lxc image imort <metadata tarball> <rootfs tarball>

# 从URL导入，HTTPS服务，Headers中设置了 LXD-Image-URL 和 LXD-Image-Hash
lxc image import https://dl.stgraber.org/lxd --alias busybox-amd64
```



### 3.7.4 编辑镜像

```bash
lxc image edit <alias or fingerprint>
```



### 3.7.5 删除镜像

```bash
lxc image delete <alias or fingerprint>
```



### 3.7.6 制作镜像

```bash
# 容器和快照转镜像
lxc publish <container> --alias <new-image>
lxc publish <container>/<snapshot-name> --alias <new-image>
```



## 3.8 运行 docker

```bash
# 下载进行
lxc image copy tuna-images:ubuntu/18.04 local: --copy-aliases

# 创建容器
lxc launch ubuntu/18.04 docker

# 安装docker
lxc exec docker -- apt update
lxc exec docker -- apt dist-upgrade -y
lxc exec docker -- apt install docker.io -y

# 在docker容器中运行容器
lxc exec docker -- docker run --detach --name web -p 8080:80 nginx

# 容器IP地址
$ lxc info docker | grep -A 8 Ips
Ips:
  eth0: inet    10.68.193.129   vethBNTFJ3
  eth0: inet6   fe80::216:3eff:fe0d:8ed1        vethBNTFJ3
  lo:   inet    127.0.0.1
  lo:   inet6   ::1
  veth75b2597:  inet6   fe80::34c2:41ff:fe5a:4a7d
  docker0:      inet    172.17.0.1
  docker0:      inet6   fe80::42:22ff:fe7a:cda3

# 访问
curl 10.68.193.129:8080
```

使用系统资源时，需要开启特权模式：

```bash
lxc config set docker security.privileged true   # 使用宿主机设备等时
lxc config set docker security.nesting true      # 解决mounting "proc" to rootfs at "/proc": permission denied
lxc restart docker
```



## 3.9 实时迁移

### 3.9.1 前提

需要满足的条件：

- 内核 4.4+
- CRIU 2.0+，可能需要一些 `cherry-pick` 的提交
- 直接在主机上运行 LXD，不支持容器嵌套
- 系统配置等尽量一致

```bash
$ apt install criu -y

$ criu check
Looks good.
```



### 3.9.2 使用 CRIU

1）有状态快照

```bash
# 无状态快照
lxc snapshot c1

# 有状态快照
lxc snapshot c1 --stateful
```



2）有状态启停

```bash
$ lxc stop c1 --stateful

$ tree /var/lib/lxd/containers/c1/state/
/var/lib/lxd/containers/c1/state/
├── apparmor.img
├── cgroup.img
├── core-1383.img
├── core-1443.img
├── core-1553.img
├── core-1561.img
├── core-1648.img
├── core-1650.img
...
```



### 3.9.3 远程主机

```bash
$ lxc remote add lxc-02 192.168.80.201
Certificate fingerprint: cd9931955aa64aa7fdd628d07b73d2c8de3ab97ee7a598ac6110391969f3aa19
ok (y/n)? y
Admin password for lxc-02:
Client certificate stored at server:  lxc-02
```



### 3.8.4 实时迁移

```bash
# 启动容器
$ lxc launch tuna-images:busybox/1.34.1 c1

# 容器已运行
$ lxc list
+------+---------+------+------+------------+-----------+
| NAME |  STATE  | IPV4 | IPV6 |    TYPE    | SNAPSHOTS |
+------+---------+------+------+------------+-----------+
| c1   | RUNNING |      |      | PERSISTENT | 0         |
+------+---------+------+------+------------+-----------+

# 远程节点上，没有容器
$ lxc list lxc-02:
+------+-------+------+------+------+-----------+
| NAME | STATE | IPV4 | IPV6 | TYPE | SNAPSHOTS |
+------+-------+------+------+------+-----------+

# 迁移容器
$ lxc move c1 lxc-02:

# 容器迁移成功
$ lxc list lxc-02:
+------+---------+------+------+------------+-----------+
| NAME |  STATE  | IPV4 | IPV6 |    TYPE    | SNAPSHOTS |
+------+---------+------+------+------------+-----------+
| c1   | RUNNING |      |      | PERSISTENT | 0         |
+------+---------+------+------+------------+-----------+
```



