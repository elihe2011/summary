# 1. 前言

## 1.1 系统要求

**硬件最低要求**：

<table class="docutils align-default">
<colgroup>
<col style="width: 20%">
<col style="width: 23%">
<col style="width: 58%">
</colgroup>
<thead>
<tr class="row-odd"><th class="head"><p>Process</p></th>
<th class="head"><p>Criteria</p></th>
<th class="head"><p>Minimum Recommended</p></th>
</tr>
</thead>
<tbody>
<tr class="row-even"><td rowspan="5"><p><code class="docutils literal notranslate"><span class="pre">ceph-osd</span></code></p></td>
<td><p>Processor</p></td>
<td><ul class="simple">
<li><p>1 core minimum</p></li>
<li><p>1 core per 200-500 MB/s</p></li>
<li><p>1 core per 1000-3000 IOPS</p></li>
</ul>
<ul class="simple">
<li><p>Results are before replication.</p></li>
<li><p>Results may vary with different
CPU models and Ceph features.
(erasure coding, compression, etc)</p></li>
<li><p>ARM processors specifically may
require additional cores.</p></li>
<li><p>Actual performance depends on many
factors including drives, net, and
client throughput and latency.
Benchmarking is highly recommended.</p></li>
</ul>
</td>
</tr>
<tr class="row-odd"><td><p>RAM</p></td>
<td><ul class="simple">
<li><p>4GB+ per daemon (more is better)</p></li>
<li><p>2-4GB often functions (may be slow)</p></li>
<li><p>Less than 2GB not recommended</p></li>
</ul>
</td>
</tr>
<tr class="row-even"><td><p>Volume Storage</p></td>
<td><p>1x storage drive per daemon</p></td>
</tr>
<tr class="row-odd"><td><p>DB/WAL</p></td>
<td><p>1x SSD partition per daemon (optional)</p></td>
</tr>
<tr class="row-even"><td><p>Network</p></td>
<td><p>1x 1GbE+ NICs (10GbE+ recommended)</p></td>
</tr>
<tr class="row-odd"><td rowspan="4"><p><code class="docutils literal notranslate"><span class="pre">ceph-mon</span></code></p></td>
<td><p>Processor</p></td>
<td><ul class="simple">
<li><p>2 cores minimum</p></li>
</ul>
</td>
</tr>
<tr class="row-even"><td><p>RAM</p></td>
<td><p>2-4GB+ per daemon</p></td>
</tr>
<tr class="row-odd"><td><p>Disk Space</p></td>
<td><p>60 GB per daemon</p></td>
</tr>
<tr class="row-even"><td><p>Network</p></td>
<td><p>1x 1GbE+ NICs</p></td>
</tr>
<tr class="row-odd"><td rowspan="4"><p><code class="docutils literal notranslate"><span class="pre">ceph-mds</span></code></p></td>
<td><p>Processor</p></td>
<td><ul class="simple">
<li><p>2 cores minimum</p></li>
</ul>
</td>
</tr>
<tr class="row-even"><td><p>RAM</p></td>
<td><p>2GB+ per daemon</p></td>
</tr>
<tr class="row-odd"><td><p>Disk Space</p></td>
<td><p>1 MB per daemon</p></td>
</tr>
<tr class="row-even"><td><p>Network</p></td>
<td><p>1x 1GbE+ NICs</p></td>
</tr>
</tbody>
</table>




**内核要求**：

- **RBD**:  

  - 4.19.z

  - 4.14.z

  - 5.x
  - 自编译内核，需要打开rbd模块

```bash
# rbd 模块检查
$ lsmod | grep rbd
rbd                   110592  0
libceph               385024  2 ceph,rbd

$ modprobe rbd
$ modinfo rbd
filename:       /lib/modules/5.1.21-050121-generic/kernel/drivers/block/rbd.ko
license:        GPL
description:    RADOS Block Device (RBD) driver
author:         Jeff Garzik <jeff@garzik.org>
author:         Yehuda Sadeh <yehuda@hq.newdream.net>
author:         Sage Weil <sage@newdream.net>
author:         Alex Elder <elder@inktank.com>
srcversion:     2B1FF2FC4C9F328C978104F
depends:        libceph
intree:         Y
name:           rbd
vermagic:       5.1.21-050121-generic SMP mod_unload aarch64
signat:         PKCS#7
signer:
sig_key:
sig_hashalgo:   md4
parm:           single_major:Use a single major number for all rbd devices (default: true) (bool)
```



- **CephFS**：需要开启文件系统挂载相关参数，参考 https://docs.kernel.org/filesystems/ceph.html



**综上，自编译内核时，需要开启如下参数：**

```bash
Device Drivers --->
  [*] Block devices --->
    <*> Rados block device (RBD)
 
File systems --->
  [*] Network File Systems --->
    <*> Ceph distributed file system
```



## 1.2 版本选择

版本说明：

- x.0.z - 开发版（给早期测试者和勇士们）

- x.1.z - 候选版（用于测试集群、高手们）

- x.2.z - 稳定、修正版（给用户们）

Supported Ceph versions are associated with supported stable [Ubuntu LTS releases](https://ubuntu.com/blog/what-is-an-ubuntu-lts-release):

- 17.2.x (Quincy) on Ubuntu 22.04 LTS (Jammy)
- 17.2.x (Quincy) on Ubuntu 20.04 LTS (Focal)
- **16.2.x (Pacific) on Ubuntu 20.04 LTS (Focal)**
- 15.2.x (Octopus) on Ubuntu 20.04 LTS (Focal)
- 15.2.x (Octopus) on Ubuntu 18.04 LTS (Bionic)
- 13.2.x (Mimic) on Ubuntu 18.04 LTS (Bionic)
- 12.2.x (Luminous) on Ubuntu 18.04 LTS (Bionic)



# 2. 准备操作

## 2.1 安装规划

| 节点名称 |               角色说明                | Public subnet |
| :------: | :-----------------------------------: | :-----------: |
|  ceph01  | cephadm，ceph-mon，ceph-mgr，ceph-osd |  10.40.0.20   |
|  ceph02  |     ceph-mon，ceph-mgr，ceph-osd      |  10.40.0.21   |
|  ceph03  |          ceph-mon，ceph-osd           |  10.40.0.22   |

**角色说明：**

- **cephadm**：需要一个安装管理节点，安装节点负责集群整体部署；

- **ceph-mon**：用于维护集群状态映射(maintains maps of the cluster state)，比如 ceph 集群中有多少存储池、每个存储池有多少 PG 以及存储池和 PG的映射关系等，monitor map, manager map, the OSD map, the MDS map, and theCRUSH map，这些映射是 Ceph 守护程序相互协调所需的关键群集状态，此外监视器还负责管理守护程序和客户端之间的身份验证(认证使用 cephX 协议)。通常至少需要 3 个监视器才能实现冗余和高可用性

- **ceph-mgr**：ceph manager守护进程负责跟踪运行时指标和ceph集群当前的状态，包括存储利用率，当前性能指标和系统负载等，ceph-mgr还托管一些python模块，以实现基于web的ceph仪表盘和rest api，通常要实现高可用至少需要 2 个ceph-mgr进程，通常ceph-mon和ceph-mgr个数相同，1个ceph-mon同节点会伴随1个ceph-mgr守护进程。

- **ceph-osd**：提供存储数据，操作系统上的一个磁盘就是一个 OSD 守护程序，OSD 用于处理 ceph集群数据复制，恢复，重新平衡，并通过检查其他 Ceph OSD 守护程序的心跳来向 Ceph监视器和管理器提供一些监视信息。通常至少需要 3 个 Ceph OSD 才能实现冗余和高可用性。

- **ceph-mds**：元数据服务，注意Ceph块设备和对象存储不用mds存储元数据，Ceph MDS允许POSIX文件系统用户执行基本命令，而不会将压力都集中到Ceph OSD集群上，通常mds可以选择部署至少2个节点，可以和其他组件一起也可以分开。



**操作系统：** ubuntu 20.04

**软件版本：**pacific 16.2.10

**部署版本：**cephadm 16.2.10



## 2.2 时间同步

```bash
apt install chrony -y

# 修改时钟同步服务器
$ vi /etc/chrony/chrony.conf
#pool ntp.ubuntu.com        iburst maxsources 4
#pool 0.ubuntu.pool.ntp.org iburst maxsources 1
#pool 1.ubuntu.pool.ntp.org iburst maxsources 1
#pool 2.ubuntu.pool.ntp.org iburst maxsources 2
server ntp.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp1.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp2.aliyun.com minpoll 4 maxpoll 10 iburst

# 开机启动
systemctl restart chrony
systemctl status chrony
systemctl enable chrony

# 更改时区
timedatectl set-timezone Asia/Shanghai

# 时钟同步状态
timedatectl status

# 写⼊系统时钟
hwclock -w
```



## 2.3 主机设置

```bash
# 主机名称修改
hostnamectl set-hostname ceph01
hostnamectl set-hostname ceph02
hostnamectl set-hostname ceph03

# 主机解析
cat >> /etc/hosts <<EOF
10.40.0.20 ceph01
10.40.0.21 ceph02
10.40.0.22 ceph03
EOF
```



## 2.4 安装 docker

```bash
apt install docker.io -y

systemctl enable docker
systemctl restart docker
systemctl status docker
```



# 3. 集群安装

:warning: 在 ceph01 上执行



## 3.1 cephadm

```bash
wget -q -O- 'https://mirrors.163.com/ceph/keys/release.asc' | apt-key add -
echo "deb https://mirrors.163.com/ceph/debian-pacific focal main">> /etc/apt/sources.list

apt update

apt install cephadm -y
```



## 3.2 引导集群

### 3.2.1 ceph bootstrap

- 在本地主机上为新集群创建一个monitor 和 manager 守护进程
- 为 ceph 集群生成一个新的 SSH 密钥并将其添加到 root 用户 `/root/.ssh/authorized_keys` 文件中
- 将公钥副本写入 `/etc/ceph/ceph.pub`
- 将最小配置文件写入 `/etc/ceph/ceph.conf`
- 将管理私钥 `client.admin` 副本写入 `/etc/ceph/ceph.client.admin.keyring`
- 将 `_admin` 标签添加到引导主机。默认该标签的任何主机将获得副本 `/etc/ceph/ceph.conf` 和 `/etc/ceph/ceph.client.admin.keyring`



### 3.2.2 引导操作

```bash
root@ceph01:~# cephadm bootstrap --mon-ip 10.40.0.20
...
Ceph Dashboard is now available at:
             URL: https://ceph01:8443/
            User: admin
        Password: a6y2hi0xme
Enabling client.admin keyring and conf on hosts with "admin" label
Enabling autotune for osd_memory_target
You can access the Ceph CLI as following in case of multi-cluster or non-default config:
        sudo /usr/sbin/cephadm shell --fsid 81b3d002-9609-11ed-beb5-bd87d244b25c -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring
Or, if you are only running a single cluster on this host:
        sudo /usr/sbin/cephadm shell
Please consider enabling telemetry to help improve Ceph:
        ceph telemetry on
```

ceph 管理：https://10.40.0.20:8443   admin/a6y2hi0xme =>  admin/Admin123

prometheus：http://10.40.0.20:9095/targets

grafana：https://10.40.0.20:3000



### 3.2.3 启用 ceph cli

```bash
# 进入 ceph 环境
root@ceph01:~# cephadm shell --fsid 81b3d002-9609-11ed-beb5-bd87d244b25c -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring

root@ceph01:/# ceph version
ceph version 16.2.10 (45fa1a083152e41a408d15505f594ec5f1b4fe17) pacific (stable)

root@ceph01:/# ceph fsid
81b3d002-9609-11ed-beb5-bd87d244b25c
root@ceph01:/# ceph -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3

  services:
    mon: 1 daemons, quorum ceph01 (age 3m)
    mgr: ceph01.xegqko(active, since 2m)
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:

root@ceph01:/# ceph orch ps
NAME                  HOST    PORTS        STATUS        REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
alertmanager.ceph01   ceph01  *:9093,9094  running (7m)     6m ago   8m    14.5M        -           ba2b418f427c  d5a0e80b5b28
crash.ceph01          ceph01               running (8m)     6m ago   8m    7503k        -  16.2.10  32214388de9d  306be371fcb5
grafana.ceph01        ceph01  *:3000       running (7m)     6m ago   8m    39.4M        -  8.3.5    dad864ee21e9  432d137f93f6
mgr.ceph01.xegqko     ceph01  *:9283       running (9m)     6m ago   9m     420M        -  16.2.10  32214388de9d  773ca67a3199
mon.ceph01            ceph01               running (9m)     6m ago   9m    38.0M    2048M  16.2.10  32214388de9d  a9fb747a7c3f
node-exporter.ceph01  ceph01  *:9100       running (7m)     6m ago   8m    8632k        -           1dbe0e931976  f8882f90dd24
prometheus.ceph01     ceph01  *:9095       running (7m)     6m ago   7m    32.1M        -           514e6a882f6e  502e1040c2fe

root@ceph01:/# ceph orch ps --daemon_type mgr
NAME               HOST    PORTS   STATUS        REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
mgr.ceph01.xegqko  ceph01  *:9283  running (9m)     6m ago   9m     420M        -  16.2.10  32214388de9d  773ca67a3199

root@ceph01:/# ceph orch ls
NAME           PORTS        RUNNING  REFRESHED  AGE  PLACEMENT
alertmanager   ?:9093,9094      1/1  7m ago     9m   count:1
crash                           1/1  7m ago     9m   *
grafana        ?:3000           1/1  7m ago     9m   count:1
mgr                             1/2  7m ago     9m   count:2
mon                             1/5  7m ago     9m   count:5
node-exporter  ?:9100           1/1  7m ago     9m   *
prometheus     ?:9095           1/1  7m ago     9m   count:1

root@ceph01:/# ceph orch stop grafana
Scheduled to stop grafana.ceph01 on host 'ceph01'

root@ceph01:/# ceph orch start grafana
Scheduled to start grafana.ceph01 on host 'ceph01'
```



### 3.2.4 安装公共组件

此时可直接使用命令行管理，不再需要进入容器

```bash
root@ceph01:~# cephadm install ceph-common

root@ceph01:~# ceph version
ceph version 16.2.10 (45fa1a083152e41a408d15505f594ec5f1b4fe17) pacific (stable)
```



## 3.3 集群主机

添加节点后，会自动扩容 monitor 和 manager 数量



### 3.3.1 主机列表

```bash
root@ceph01:~# cephadm shell ceph orch host ls
Inferring fsid 81b3d002-9609-11ed-beb5-bd87d244b25c
Using recent ceph image quay.io/ceph/ceph@sha256:3cd25ee2e1589bf534c24493ab12e27caf634725b4449d50408fd5ad4796bbfa
HOST    ADDR        LABELS  STATUS
ceph01  10.40.0.20  _admin
1 hosts in cluster

root@ceph01:~# ceph orch host ls
HOST    ADDR        LABELS  STATUS
ceph01  10.40.0.20  _admin
1 hosts in cluster
```



### 3.3.2 添加主机

#### 3.3.2.1 拷贝密钥

```bash
ssh-copy-id -f -i /etc/ceph/ceph.pub ceph02
ssh-copy-id -f -i /etc/ceph/ceph.pub ceph03
```



#### 3.3.2.2 添加主机

```bash
cephadm shell ceph orch host add ceph02 10.40.0.21
cephadm shell ceph orch host add ceph03 10.40.0.22
```



#### 3.3.2.3 主机列表

```bash
root@ceph01:~# cephadm shell ceph orch host ls
Inferring fsid 81b3d002-9609-11ed-beb5-bd87d244b25c
Using recent ceph image quay.io/ceph/ceph@sha256:3cd25ee2e1589bf534c24493ab12e27caf634725b4449d50408fd5ad4796bbfa
HOST    ADDR        LABELS  STATUS
ceph01  10.40.0.20  _admin
ceph02  10.40.0.21
ceph03  10.40.0.22
3 hosts in cluster
```



#### 3.3.2.4 集群状态

```bash
root@ceph01:~# ceph -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3

  services:
    mon: 2 daemons, quorum ceph01,ceph02 (age 20s)
    mgr: ceph01.xegqko(active, since 14m), standbys: ceph02.akbbks
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
```



## 3.4 OSD 服务

磁盘要求：

- 必须没有分区
- 不得具有 LVM 状态
- 不包含文件系统
- 不包含 Ceph  BlueStore OSD
- 必须大于 5 GB



### 3.4.1 存储设备清单

```bash
root@ceph01:~# ceph orch device ls
HOST    PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS
ceph01  /dev/sdb  hdd              21.4G  Yes        15m ago
ceph02  /dev/sdb  hdd              21.4G  Yes        60s ago
ceph03  /dev/sdb  hdd              21.4G  Yes        13s ago
```



### 3.4.2 创建OSD

#### 3.4.2.1 指定主机和设备

```bash
ceph orch daemon add osd ceph01:/dev/sdb
ceph orch daemon add osd ceph02:/dev/sdb
ceph orch daemon add osd ceph03:/dev/sdb
```



#### 3.4.2.2 批量创建

```bash
ceph orch apply osd --all-available-devices
```

执行上述命令后：

- 集群节点新增磁盘，将自动创建新的 OSD
- 移除OSD并清理 LVM 物理卷，将自动创建新的 OSD

禁用自动创建 OSD：指定 `--unmanaged=true` 参数

注意：`ceph orch apply` 的默认行为导致 cephadm 不断地进行协调，在检测到新存储设备后立即创建 OSD。设置 unmanaged:True 将禁用OSD自动创建



#### 3.4.2.3 OSD 列表

```bash
root@ceph01:~# ceph orch device ls
HOST    PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS
ceph01  /dev/sdb  hdd              21.4G             29s ago    Insufficient space (<10 extents) on vgs, LVM detected, locked
ceph02  /dev/sdb  hdd              21.4G             18s ago    Insufficient space (<10 extents) on vgs, LVM detected, locked
ceph03  /dev/sdb  hdd              21.4G             4s ago     Insufficient space (<10 extents) on vgs, LVM detected, locked
```



#### 3.4.2.4 集群状态

```bash
root@ceph01:~# ceph -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph01,ceph02,ceph03 (age 3m)
    mgr: ceph01.xegqko(active, since 18m), standbys: ceph02.akbbks
    osd: 3 osds: 3 up (since 53s), 3 in (since 65s)

  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   15 MiB used, 60 GiB / 60 GiB avail
    pgs:     1 active+clean
```



## 3.5 服务管理

```bash
# 删除服务(自动)
ceph orch rm <service-name>

# 删除服务(手动)
ceph orch daemon rm <daemon-name> [--force]

# 禁用自动管理
cat > mgr.yaml <<EOF
service_type: mgr
unmanaged: true
placement:
  label: mgr
EOF

ceph orch apply -f mgr.yaml
```



# 4. CephFS

## 4.1 部署 cephfs

### 4.1.1 文件系统

```bash
root@ceph01:~# ceph fs ls
No filesystems enabled
```



### 4.1.2 存储池

```bash
root@ceph01:~# ceph osd pool ls
device_health_metrics
```



### 4.1.3 创建文件系统

```bash
root@ceph01:~# ceph fs volume create new_cephfs --placement=3

# 当前存储池
root@ceph01:~# ceph osd pool ls
device_health_metrics
cephfs.new_cephfs.meta
cephfs.new_cephfs.data

# 当前文件系统
root@ceph01:~# ceph fs ls
name: new_cephfs, metadata pool: cephfs.new_cephfs.meta, data pools: [cephfs.new_cephfs.data ]
```



### 4.1.4 MDS 服务

```bash
# mds状态
root@ceph01:~# ceph mds stat
new_cephfs:1 {0=new_cephfs.ceph01.hndtak=up:active} 2 up:standby

# mds服务
root@ceph01:~# ceph -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph01,ceph02,ceph03 (age 78m)
    mgr: ceph01.xegqko(active, since 51m), standbys: ceph02.akbbks
    mds: 1/1 daemons up, 2 standby                     # 新增
    osd: 3 osds: 3 up (since 55m), 3 in (since 55m)

  data:
    volumes: 1/1 healthy
    pools:   3 pools, 65 pgs
    objects: 22 objects, 2.3 KiB
    usage:   17 MiB used, 30 GiB / 30 GiB avail
    pgs:     65 active+clean
    
root@ceph01:~# ceph orch ls
NAME            PORTS        RUNNING  REFRESHED  AGE  PLACEMENT
alertmanager    ?:9093,9094      1/1  4m ago     2h   count:1
crash                            3/3  4m ago     2h   *
grafana         ?:3000           1/1  4m ago     2h   count:1
mds.new_cephfs                   3/3  4m ago     4m   count:3   # 新增
mgr                              2/2  4m ago     2h   count:2
mon                              3/5  4m ago     2h   count:5   
node-exporter   ?:9100           3/3  4m ago     2h   *
osd                                3  4m ago     -    <unmanaged>
prometheus      ?:9095           1/1  4m ago     2h   count:1
```



### 4.1.5 文件系统状态

```bash
root@ceph01:~# ceph fs status new_cephfs
new_cephfs - 0 clients
==========
RANK  STATE             MDS                ACTIVITY     DNS    INOS   DIRS   CAPS
 0    active  new_cephfs.ceph01.hndtak  Reqs:    0 /s    10     13     12      0
         POOL             TYPE     USED  AVAIL
cephfs.new_cephfs.meta  metadata  96.0k  18.9G
cephfs.new_cephfs.data    data       0   18.9G
      STANDBY MDS
new_cephfs.ceph02.ohemrt
new_cephfs.ceph03.iztbzr
MDS version: ceph version 16.2.10 (45fa1a083152e41a408d15505f594ec5f1b4fe17) pacific (stable)
```



## 4.2 用户管理

```bash
# 创建客户端用户
root@ceph01:~# ceph auth add client.eli mon 'allow rw' mds 'allow rw' osd 'allow rwx pool=cephfs.new_cephfs.data'
added key for client.eli

# 用户详情
root@ceph01:~# ceph auth get client.eli
[client.eli]
        key = AQBUDMZjjL6bDxAAe7JVxCUAXExe7of8NkDjNQ==
        caps mds = "allow rw"
        caps mon = "allow rw"
        caps osd = "allow rwx pool=cephfs.new_cephfs.data"
exported keyring for client.eli

# 用户keyring文件
root@ceph01:~# ceph auth get client.eli -o ceph.client.eli.keyring
exported keyring for client.eli

root@ceph01:~# cat ceph.client.eli.keyring
[client.eli]
        key = AQBUDMZjjL6bDxAAe7JVxCUAXExe7of8NkDjNQ==
        caps mds = "allow rw"
        caps mon = "allow rw"
        caps osd = "allow rwx pool=cephfs.new_cephfs.data"

# 用户key文件
root@ceph01:~# ceph auth print-key client.eli > cephfs_eli.key
root@ceph01:~# cat cephfs_eli.key
AQBUDMZjjL6bDxAAe7JVxCUAXExe7of8NkDjNQ==
```



## 4.3 客户端

新增一台集群，作为cephfs的客户端

### 4.3.1 配置客户端

```bash
# 安装 ceph-common
wget -q -O- 'https://mirrors.163.com/ceph/keys/release.asc' | apt-key add -
echo "deb https://mirrors.163.com/ceph/debian-pacific bionic main">> /etc/apt/sources.list

apt update
apt install ceph-common -y

# 从服务端拷贝认证文件
scp root@10.40.0.20:/root/ceph.client.eli.keyring /etc/ceph
scp root@10.40.0.20:/root/cephfs_eli.key /etc/ceph
scp root@10.40.0.20:/etc/ceph/ceph.conf /etc/ceph

# 验证权限
root@ubuntu:~# ceph --id eli -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph01,ceph02,ceph03 (age 43m)
    mgr: ceph01.xegqko(active, since 58m), standbys: ceph02.akbbks
    mds: 1/1 daemons up, 2 standby
    osd: 3 osds: 3 up (since 41m), 3 in (since 41m)

  data:
    volumes: 1/1 healthy
    pools:   8 pools, 177 pgs
    objects: 261 objects, 8.4 KiB
    usage:   107 MiB used, 60 GiB / 60 GiB avail
    pgs:     177 active+clean
```



### 4.3.2 挂载 cephfs

```bash
# 创建目录
mkdir -p /data/cephfs-share

# 挂载
mount -t ceph 10.40.0.20:6789,10.40.0.21:6789,10.40.0.22:6789:/ /data/cephfs-share -o name=eli,secretfile=/etc/ceph/cephfs_eli.key

# 检查挂载
root@ubuntu:~# df -Th
Filesystem                                        Type      Size  Used Avail Use% Mounted on
udev                                              devtmpfs  451M     0  451M   0% /dev
tmpfs                                             tmpfs      97M  944K   96M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv                 ext4       19G  5.8G   12G  33% /
tmpfs                                             tmpfs     482M     0  482M   0% /dev/shm
tmpfs                                             tmpfs     5.0M     0  5.0M   0% /run/lock
tmpfs                                             tmpfs     482M     0  482M   0% /sys/fs/cgroup
/dev/sda2                                         ext4      976M   77M  832M   9% /boot
tmpfs                                             tmpfs      97M     0   97M   0% /run/user/0
10.40.0.20:6789,10.40.0.21:6789,10.40.0.22:6789:/ ceph       19G     0   19G   0% /data/cephfs-share

# 挂载点信息
root@ubuntu:~# stat -f /data/cephfs-share/
  File: "/data/cephfs-share/"
    ID: 856d063fb1a34d44 Namelen: 255     Type: ceph
Block size: 4194304    Fundamental block size: 4194304
Blocks: Total: 4854       Free: 4854       Available: 4854
Inodes: Total: 0          Free: -1

# 创建文件
root@ubuntu:~# touch /data/cephfs-share/abc.txt

root@ubuntu:~# ls -l /data/cephfs-share
total 0
-rw-r--r-- 1 root root 0 Jan 17 02:55 abc.txt
```



## 4.4 删除 cephfs

```bash
ceph fs fail new_cephfs
ceph tell mon.* injectargs --mon-allow-pool-delete=true
ceph fs rm new_cephfs --yes-i-really-mean-it
ceph osd pool rm cephfs.new_cephfs.meta cephfs.new_cephfs.meta  --yes-i-really-really-mean-it
ceph osd pool rm cephfs.new_cephfs.data cephfs.new_cephfs.data  --yes-i-really-really-mean-it
```



# 5. RBD

## 5.1 存储池

```bash
# 64 64 是 PG 和 PGP 的数量。
root@ceph01:~# ceph osd pool create newrbd 64 64
pool 'newrbd' created

root@ceph01:~# ceph osd pool ls
device_health_metrics
cephfs.new_cephfs.meta
cephfs.new_cephfs.data
newrbd

# 启用存储池
root@ceph01:~# ceph osd pool application enable newrbd rbd
enabled application 'rbd' on pool 'newrbd'

# 初始化
root@ceph01:~# rbd pool init -p newrbd
```



## 5.2 镜像

```bash
# 创建镜像
root@ceph01:~# rbd create new-img01 --size 2G --pool newrbd --image-format 2 --image-feature layering

# 镜像信息
root@ceph01:~# rbd ls --pool newrbd -l --format json --pretty-format
[
    {
        "image": "new-img01",
        "id": "5f8f248b055a",
        "size": 2147483648,
        "format": 2
    }
]

# 镜像特征
root@ceph01:~# rbd --image new-img01 -p newrbd info
rbd image 'new-img01':
        size 2 GiB in 512 objects
        order 22 (4 MiB objects)
        snapshot_count: 0
        id: 5f8f248b055a
        block_name_prefix: rbd_data.5f8f248b055a
        format: 2
        features: layering
        op_features:
        flags:
        create_timestamp: Tue Jan 17 02:57:09 2023
        access_timestamp: Tue Jan 17 02:57:09 2023
        modify_timestamp: Tue Jan 17 02:57:09 2023
```



## 5.3 用户管理

```bash
# 创建用户
root@ceph01:~# ceph auth add client.newrbd mon 'allow rw' osd 'allow rwx pool=newrbd'
added key for client.newrbd

# 用户信息
root@ceph01:~# ceph auth get client.newrbd
[client.newrbd]
        key = AQDWDsZjnJfEORAAbM1RKGTkpW7MYswnfImNrA==
        caps mon = "allow rw"
        caps osd = "allow rwx pool=newrbd"
exported keyring for client.newrbd

# 导出keyring
root@ceph01:~# ceph auth get client.newrbd -o ceph.client.newrbd.keyring
exported keyring for client.newrbd
```



## 5.4 客户端

### 5.4.1 配置客户端

ceph-common 安装部分参看 CephFS

```bash
# 拷贝用户配置
scp root@10.40.0.20:/root/ceph.client.newrbd.keyring /etc/ceph

# 验证客户端权限
root@ubuntu:~# ceph --id newrbd -s
  cluster:
    id:     81b3d002-9609-11ed-beb5-bd87d244b25c
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph01,ceph02,ceph03 (age 51m)
    mgr: ceph01.xegqko(active, since 66m), standbys: ceph02.akbbks
    mds: 1/1 daemons up, 2 standby
    osd: 3 osds: 3 up (since 49m), 3 in (since 49m)
    rgw: 6 daemons active (3 hosts, 1 zones)

  data:
    volumes: 1/1 healthy
    pools:   9 pools, 241 pgs
    objects: 265 objects, 12 KiB
    usage:   83 MiB used, 60 GiB / 60 GiB avail
    pgs:     241 active+clean

# 映射rbd镜像
root@ubuntu:~# rbd --id newrbd -p newrbd map new-img01
/dev/rbd0

# 映射关系
root@ubuntu:~# rbd showmapped
id  pool    namespace  image      snap  device
0   newrbd             new-img01  -     /dev/rbd0
```



### 5.4.2 挂载 rbd

```bash
# 格式化
root@ubuntu:~# mkfs.xfs /dev/rbd0
meta-data=/dev/rbd0              isize=512    agcount=9, agsize=64512 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=0, rmapbt=0, reflink=0
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=1024   swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

# 挂载
mkdir -p /data/rdb-share
mount /dev/rbd0 /data/rdb-share/

# 验证
root@ubuntu:~# df -Th
Filesystem                                        Type      Size  Used Avail Use% Mounted on
udev                                              devtmpfs  451M     0  451M   0% /dev
tmpfs                                             tmpfs      97M  948K   96M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv                 ext4       19G  5.8G   12G  33% /
tmpfs                                             tmpfs     482M     0  482M   0% /dev/shm
tmpfs                                             tmpfs     5.0M     0  5.0M   0% /run/lock
tmpfs                                             tmpfs     482M     0  482M   0% /sys/fs/cgroup
/dev/sda2                                         ext4      976M   77M  832M   9% /boot
tmpfs                                             tmpfs      97M     0   97M   0% /run/user/0
10.40.0.20:6789,10.40.0.21:6789,10.40.0.22:6789:/ ceph       19G     0   19G   0% /data/cephfs-share
/dev/rbd0                                         xfs       2.0G   35M  2.0G   2% /data/rdb-share

# 开机启动
cat >> /etc/rc.d/rc.local <<EOF
rbd --user newrbd -p newrbd map new-img01
mount /dev/rbd0 /data/rdb-share
EOF
```



## 5.5 卸载操作

```bash
umount /data/rbd-share

# 取消映射
rbd --user newrbd -p newrbd unmap new-img01
```



# 6. RGW

Ceph RGW(即RADOS Gateway)是Ceph对象存储网关服务，是基于LIBRADOS接口封装实现的FastCGI服务，对外提供存储和管理对象数据的Restful API。 对象存储适用于图片、视频等各类文件的上传下载，可以设置相应的访问权限。目前Ceph RGW兼容常见的对象存储API，例如兼容绝大部分Amazon S3 API，兼容OpenStack Swift API



## 6.1 部署 rgw

### 6.1.1 设置标签

```bash
ceph orch host label add ceph01 rgw
ceph orch host label add ceph02 rgw
ceph orch host label add ceph03 rgw
```



### 6.1.2 创建 rgw

在标记了 rgw 主机上创建 rgw 服务，端口分别为8000和8001，共6个实例

```bash
ceph orch apply rgw new_rgw '--placement=label:rgw count-per-host:2' --port=8000
```



### 6.1.3 rgw 服务

```bash
root@ceph01:~# ceph orch ls
NAME           PORTS        RUNNING  REFRESHED  AGE  PLACEMENT
alertmanager   ?:9093,9094      1/1  2s ago     22m  count:1
crash                           3/3  3s ago     22m  *
grafana        ?:3000           1/1  2s ago     22m  count:1
mgr                             2/2  3s ago     22m  count:2
mon                             3/5  3s ago     22m  count:5
node-exporter  ?:9100           3/3  3s ago     22m  *
osd                               3  3s ago     -    <unmanaged>
prometheus     ?:9095           1/1  2s ago     22m  count:1
rgw.new_rgw    ?:8000           6/6  3s ago     13s  count-per-host:2;label:rgw

# 服务端口
root@ceph01:~# ss -tnlp |grep radosgw
LISTEN    0         128                0.0.0.0:8001             0.0.0.0:*        users:(("radosgw",pid=24224,fd=51))
LISTEN    0         128                0.0.0.0:8000             0.0.0.0:*        users:(("radosgw",pid=23898,fd=51))
LISTEN    0         128                   [::]:8001                [::]:*        users:(("radosgw",pid=24224,fd=52))
LISTEN    0         128                   [::]:8000                [::]:*        users:(("radosgw",pid=23898,fd=52))
```



### 6.1.4 rgw 存储池

```bash
root@ceph01:~# ceph osd pool ls
device_health_metrics
.rgw.root
default.rgw.log
default.rgw.control
default.rgw.meta
```



### 6.1.5 rgw zone 信息

```bash
root@ceph01:~# radosgw-admin zone get --rgw-zone=default
{
    "id": "78cb8553-b405-4dda-9ded-b6eaa1f2b463",
    "name": "default",
    "domain_root": "default.rgw.meta:root",
    "control_pool": "default.rgw.control",
    "gc_pool": "default.rgw.log:gc",
    "lc_pool": "default.rgw.log:lc",
    "log_pool": "default.rgw.log",
    "intent_log_pool": "default.rgw.log:intent",
    "usage_log_pool": "default.rgw.log:usage",
    "roles_pool": "default.rgw.meta:roles",
    "reshard_pool": "default.rgw.log:reshard",
    "user_keys_pool": "default.rgw.meta:users.keys",
    "user_email_pool": "default.rgw.meta:users.email",
    "user_swift_pool": "default.rgw.meta:users.swift",
    "user_uid_pool": "default.rgw.meta:users.uid",
    "otp_pool": "default.rgw.otp",
    "system_key": {
        "access_key": "",
        "secret_key": ""
    },
    "placement_pools": [
        {
            "key": "default-placement",
            "val": {
                "index_pool": "default.rgw.buckets.index",
                "storage_classes": {
                    "STANDARD": {
                        "data_pool": "default.rgw.buckets.data"
                    }
                },
                "data_extra_pool": "default.rgw.buckets.non-ec",
                "index_type": 0
            }
        }
    ],
    "realm_id": "",
    "notif_pool": "default.rgw.log:notif"
}
```



### 6.1.6 访问 rgw

```bash
root@ceph01:~# curl http://10.40.0.20:8000/
<?xml version="1.0" encoding="UTF-8"?><ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Owner><ID>anonymous</ID><DisplayName></DisplayName></Owner><Buckets></Buckets></ListAllMyBucketsResult>
```



## 6.2 用户管理

```bash
root@ceph01:~# radosgw-admin user create --uid="eli" --display-name="eli"
{
    "user_id": "eli",
    "display_name": "eli",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "eli",
            "access_key": "Q0NA375VW9IPJFQUWK2J",
            "secret_key": "5FErKu3HbJc2mlDCDplaBeicynubMuRdg42iSNQj"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
```



## 6.3 客户端

:warning: 在客户端服务器上进行

### 6.3.1 s3cmd

```bash
apt install s3cmd -y

cat >> /etc/hosts <<EOF
10.40.0.20 rgw.eli.io #内部域名解析
EOF

# 初始化
root@ubuntu:~# s3cmd --configure

Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key: Q0NA375VW9IPJFQUWK2J
Secret Key: 5FErKu3HbJc2mlDCDplaBeicynubMuRdg42iSNQj
Default Region [US]:

Use "s3.amazonaws.com" for S3 Endpoint and not modify it to the target Amazon S3.
S3 Endpoint [s3.amazonaws.com]: rgw.eli.io:8000

Use "%(bucket)s.s3.amazonaws.com" to the target Amazon S3. "%(bucket)s" and "%(location)s" vars can be used
if the target S3 system supports dns based buckets.
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.s3.amazonaws.com]:

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password:
Path to GPG program [/usr/bin/gpg]:

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [Yes]: No

On some networks all internet access must go through a HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name:

New settings:
  Access Key: Q0NA375VW9IPJFQUWK2J
  Secret Key: 5FErKu3HbJc2mlDCDplaBeicynubMuRdg42iSNQj
  Default Region: US
  S3 Endpoint: rgw.eli.io:8000
  DNS-style bucket+hostname:port template for accessing a bucket: %(bucket)s.s3.amazonaws.com
  Encryption password:
  Path to GPG program: /usr/bin/gpg
  Use HTTPS protocol: False
  HTTP Proxy server name:
  HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] Y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Not configured. Never mind.

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'


# 修改配置
root@ubuntu:~# vi /root/.s3cfg
[default]
access_key = Q0NA375VW9IPJFQUWK2J  # 访问密钥
...
host_base = rgw.eli.io:8000
host_bucket = rgw.eli.io:8000/%(bucket)   # 修改为rgw服务地址
...
secret_key = 5FErKu3HbJc2mlDCDplaBeicynubMuRdg42iSNQj  # 用户密钥
...
```



### 6.3.2 对象存储测试

```bash
root@ubuntu:~# s3cmd mb s3://elibucket
Bucket 's3://elibucket/' created

root@ubuntu:~# s3cmd ls s3:/
2023-01-17 02:36  s3://elibucket
```



## 6.4 服务端

```bash
root@ceph01:~# radosgw-admin bucket list
[
    "elibucket"
]
```



# 7. 附录

## 7.1 常用命令

```bash
ceph orch ls         # 集群内组件列表
ceph orch host ls    # 集群内主机列表
ceph orch ps         # 集群内容器详细
ceph orch apply mon --placement="3 node1 node2 node3"    #调整组件的数量
ceph orch ps --daemon-type rgw        # 指定查看的组件
ceph orch host label add node1 mon    # 设置主机标签
ceph orch apply mon label:mon         # 根据标签部署mon
ceph orch device ls                   # 集群内存储设备列表

ceph orch apply mon --unmanaged       # 禁用mon自动部署
ceph orch daemon add mon ceph04:10.40.0.23
ceph orch daemon add mon newhost:10.40.0.0/24

# 删除节点
ceph orch host drain ceph04    # 清理节点容器
ceph orch host rm ceph04       # 过段时间，等节点上的容器删除后，才能执行成功
```



## 7.2 暂停或禁用

```bash
# 出现问题，cephadm表现不佳，可暂停ceph集群后台活动
ceph orch pause

# puase后任会定期检查主机，刷新守护进程和设备清单，彻底禁止
ceph orch set backend ''
ceph mgr module disable cephadm
```



## 7.3 服务和事件

```bash
# 服务事件
$ ceph orch ls --service_name=mon --format yaml
service_type: mon
service_name: mon
placement:
  count: 5
status:
  created: '2023-01-17T01:52:44.767979Z'
  last_refresh: '2023-01-17T06:39:20.172048Z'
  running: 3
  size: 5
  
# 服务进程
$ ceph orch ps --service-name=mds.new_cephfs
NAME                          HOST    PORTS  STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
mds.new_cephfs.ceph01.hndtak  ceph01         running (27m)     2m ago   4h    13.2M        -  16.2.10  32214388de9d  642642f761af
mds.new_cephfs.ceph02.ohemrt  ceph02         running (4h)      2m ago   4h    13.8M        -  16.2.10  32214388de9d  a9c87a0dd1ae
mds.new_cephfs.ceph03.iztbzr  ceph03         running (4h)      6m ago   4h    22.9M        -  16.2.10  32214388de9d  c866de2ceb08
```



## 7.4 日志收集

```bash
# 当前主机上的服务列表
$ cephadm ls | jq -r '.[].name'
rgw.new_rgw.ceph01.zhutph
alertmanager.ceph01
prometheus.ceph01
mon.ceph01
crash.ceph01
node-exporter.ceph01
mgr.ceph01.xegqko
osd.0
mds.new_cephfs.ceph01.hndtak
grafana.ceph01
rgw.new_rgw.ceph01.nneplt

# 服务日志
$ cephadm logs --name prometheus.ceph01
```

