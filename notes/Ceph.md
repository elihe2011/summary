# 1. 简介

Ceph设计思想：集群可靠性、集群可扩展性、数据安全性、接口统一性、充分发挥存储设备自身的计算能力、去除中心化

Ceph 的特点：

- 高性能
  - 摒弃传统集中式存储元数据寻址方案，采用CRUSH算法，数据分布均衡，并行度高
  - 考虑了容灾域隔离，能够实现各类负载的副本放置规则，如跨机房、机架感知等
  - 能支持上千存储节点规模，支持TB到PB级数据
- 搞扩展性
  - 去中心化
  - 扩展灵活
  - 随节点增加而线性增长
- 特性丰富
  - 支持三种存储接口：块存储、文件存储、对象存储
  - 支持自定义接口，支持多种语言驱动



1. mon：monitor
2. mgr：manager
3. osd：storage
4. mds(optional)：用于 CephFS
5. radosgw(optional)：用于 Ceph Object Storage



## 1.1 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/ceph-arch.png) 

**RADOS**: Reliable Autonomic Distributed Object Store, 可靠的、自主的、分布式对象存储。它是Ceph集群的核心，实现了数据分配、Failover等集群操作

**Librados**: RDB, RGW和CephFS的访问库

**Crush**: 寻址操作算法，它摒弃了传统的集中式存储数据寻址方案，在一致性哈希基础上很好的考虑了容灾域的隔离，使得Ceph能够实现各类负载副本放置规则，如跨机房、机架感知等。同时，它强大的扩展性，理论上可支持数千个存储节点

**Pool**: 存储对象的逻辑分区，规定了数据冗余的类型和对应的副本分布策略，支持两种类型：副本(replicated) 和纠错码(erasure code)

**PG**: placement group，放置策略组。它是对象的集合，该集合中的所有对象具有相同的放置策略，即相同的PG内的对象都会放在相同的磁盘上。PG是ceph的逻辑概念，服务器数据均衡和恢复的最小颗粒就是PG，一个PG包含多个OSD。PG是为了更好的分配和定位数据

**Object**: 对象存储，最底层的存储单元，包含元数据和原始数据

**OSD**: 负载物理存储的进程，一块磁盘启动一个OSD进程，主要功能是存储数据、复制数据、平衡数据、恢复数据，以及与其它OSD间进行心跳检查，负责响应客户端请求并返回具体的数据

**Monitor**: 一个Ceph集群需要多个Monitor组成的小集群，它们通过Paxos同步数据，用来保存OSD的元数据。负责监控整个Ceph集群运行的Map视图（OSD Map、Monitor Map、PG Map和CRUSH Map），维护集群的健康状态，维护展示集群状态的各种图表，管理集群客户端认证与授权

**MDS**: Ceph Metadata Server, CephFS服务依赖的元数据服务，负责保存文件系统的元数据，管理目录结构。对象存储和块设备存储不需要元数据服务

**Mgr**: Ceph集群对外提供的统一管理入口。如cephmetrics、zabbix、calamari、promethus

**RGW**: RADOS gateway，Ceph对外提供的对象存储服务，接口与S3和Swift兼容

**Admin**: 命令行管理工具，如rados, ceph, rdb等



## 1.2 三种存储类型

### 1.2.1 块存储 RBD

- 优点：
  - 通过 Raid 和 LVM 等手段，对数据提供保护
  - 多块廉价的磁盘组合起来，提高容量
  - 多块磁盘组合成逻辑盘，提高读写速率
- 缺点：
  - SAN组网使，光纤交换机，造价高
  - 主机间无法共享数据
- 使用场景：
  - 容器、虚拟机磁盘存储分配
  - 日志存储
  - 文件存储



### 1.2.2 文件存储 CephFS

- 优点：
  - 造价低，随便一台机器就可以
  - 方便文件共享
- 缺点：
  - 读写效率低
  - 传输速度慢
- 使用场景：
  - 日志存储
  - FTP, NFS
  - 其他带目录的文件存储



### 1.2.3 对象存储 Object

- 优点：
  - 具备块存储的高读写速率
  - 具备文件存储的共享等特性
- 使用场景：
  - 图片存储
  - 视频存储



# 2. 集群安装

## 2.1 准备操作

```bash
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-8.repo

hostnamectl set-hostname ceph-node1
hostnamectl set-hostname ceph-node2
hostnamectl set-hostname ceph-node3

cat >> /etc/hosts <<EOF
192.168.3.130 ceph-node1
192.168.3.131 ceph-node2
192.168.3.132 ceph-node3
EOF

systemctl disable --now firewalld
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

yum install -y chrony
systemctl enable --now chronyd

dnf install -y epel-release
dnf install -y python3

yum erase podman buildah -y

dnf config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum install docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
```



## 2.2 安装 cephadm

```bash
wget https://raw.githubusercontent.com/ceph/ceph/pacific/src/cephadm/cephadm
chmod +x cephadm

./cephadm add-repo --release pacific
./cephadm install

# which cephadm
/usr/sbin/cephadm

# cephadm version
ceph version 16.2.7 (dd0603118f56ab514f133c8d2e3adfc983942503) pacific (stable)
```



## 2.3 引导新集群

命令所做的操作：

- 在本机上为新集群创建 monitor 和 manager-daemon 守护进程
- 为Ceph集群生成一个新的SSH密钥，并将其添加到`/root/.ssh/authorized_keys`文件中
- 创建集群通信配置文件`/etc/ceph/ceph/conf`
- 将`client.admin`管理的特权secret key副本写入 `/etc/ceph/ceph.client.admin.keyring`
- 将 public key 的副本写入 `/etc/ceph/ceph.pub`

```bash
# mkdir -p /etc/ceph

# cephadm bootstrap --mon-ip 192.168.3.130
 URL: https://ceph-node1:8443/
            User: admin
        Password: c3t58y0kos

# cat /etc/ceph/ceph.conf
# minimal ceph.conf for e9bc1522-77fd-11ec-9930-5254002b114f
[global]
        fsid = e9bc1522-77fd-11ec-9930-5254002b114f
        mon_host = [v2:192.168.3.130:3300/0,v1:192.168.3.130:6789/0]
        
# docker images
REPOSITORY                         TAG       IMAGE ID       CREATED         SIZE
quay.io/ceph/ceph                  v16       cc266d6139f4   5 weeks ago     1.21GB
quay.io/ceph/ceph-grafana          6.7.4     557c83e11646   5 months ago    486MB
quay.io/prometheus/prometheus      v2.18.1   de242295e225   20 months ago   140MB
quay.io/prometheus/alertmanager    v0.20.0   0881eb8f169f   2 years ago     52.1MB
quay.io/prometheus/node-exporter   v0.18.1   e5a616e4b9cf   2 years ago     22.9MB

# docker ps -a --format "table {{.Image}}\t{{.Command}}"
IMAGE                                      COMMAND
quay.io/ceph/ceph-grafana:6.7.4            "/bin/sh -c 'grafana…"
quay.io/prometheus/alertmanager:v0.20.0    "/bin/alertmanager -…"
quay.io/prometheus/prometheus:v2.18.1      "/bin/prometheus --c…"
quay.io/prometheus/node-exporter:v0.18.1   "/bin/node_exporter …"
quay.io/ceph/ceph                          "/usr/bin/ceph-crash…"
quay.io/ceph/ceph:v16                      "/usr/bin/ceph-mgr -…"
quay.io/ceph/ceph:v16                      "/usr/bin/ceph-mon -…"

# ceph命令
alias ceph='cephadm shell -- ceph'
cephadm install ceph-common

# 组件运行状态
ceph orch ps
NAME                      HOST        PORTS        STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
alertmanager.ceph-node1   ceph-node1  *:9093,9094  running (22m)   104s ago  23m    16.1M        -  0.20.0   0881eb8f169f  fe33e6a848b6
crash.ceph-node1          ceph-node1               running (23m)   104s ago  23m    7287k        -  16.2.7   cc266d6139f4  7087410ed9de
grafana.ceph-node1        ceph-node1  *:3000       running (22m)   104s ago  22m    30.4M        -  6.7.4    557c83e11646  4f680d8bdc7c
mgr.ceph-node1.bkxsrs     ceph-node1  *:9283       running (24m)   104s ago  24m     410M        -  16.2.7   cc266d6139f4  3ee0b22bfce1
mon.ceph-node1            ceph-node1               running (24m)   104s ago  24m    47.4M    2048M  16.2.7   cc266d6139f4  6783a2ae12b6
node-exporter.ceph-node1  ceph-node1  *:9100       running (22m)   104s ago  22m    13.3M        -  0.18.1   e5a616e4b9cf  28f9bff30cd1
prometheus.ceph-node1     ceph-node1  *:9095       running (22m)   104s ago  22m    38.9M        -  2.18.1   de242295e225  35fee2e69b1f

ceph orch ps --daemon-type mon
NAME            HOST        PORTS  STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
mon.ceph-node1  ceph-node1         running (39m)     7m ago  39m    70.7M    2048M  16.2.7   cc266d6139f4  6783a2ae12b6


# 容器状态
cephadm ls

# ceph status
  cluster:
    id:     e9bc1522-77fd-11ec-9930-5254002b114f
    health: HEALTH_WARN
            OSD count 0 < osd_pool_default_size 3

  services:
    mon: 1 daemons, quorum ceph-node1 (age 26m)
    mgr: ceph-node1.bkxsrs(active, since 24m)
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
```



## 2.4 添加主机到集群

```bash
ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph-node2
ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph-node3

# 将主机添加到集群
ceph orch host add ceph-node2
ceph orch host add ceph-node3

# 节点列表
ceph orch host ls
HOST        ADDR           LABELS  STATUS
ceph-node1  192.168.3.130  _admin
ceph-node2  192.168.3.131
ceph-node3  192.168.3.132

# 查看集群是否已经扩展完成(3个crash，3个mon，2个mgr)
ceph orch ps
NAME                      HOST        PORTS        STATUS          REFRESHED   AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID
alertmanager.ceph-node1   ceph-node1  *:9093,9094  running (51s)     40s ago   45m    15.6M        -  0.20.0   0881eb8f169f  6c00636c5586
crash.ceph-node1          ceph-node1               running (45m)     40s ago   45m    7287k        -  16.2.7   cc266d6139f4  7087410ed9de
crash.ceph-node2          ceph-node2               running (2m)      41s ago    2m    8040k        -  16.2.7   cc266d6139f4  0b8968bec17e
crash.ceph-node3          ceph-node3               running (65s)     41s ago   65s    7912k        -  16.2.7   cc266d6139f4  9624d2bb72e7
grafana.ceph-node1        ceph-node1  *:3000       running (44m)     40s ago   44m    31.0M        -  6.7.4    557c83e11646  4f680d8bdc7c
mgr.ceph-node1.bkxsrs     ceph-node1  *:9283       running (46m)     40s ago   46m     421M        -  16.2.7   cc266d6139f4  3ee0b22bfce1
mgr.ceph-node2.cueeyu     ceph-node2  *:8443,9283  running (2m)      41s ago    2m     368M        -  16.2.7   cc266d6139f4  1e9fbd7f2a2f
mon.ceph-node1            ceph-node1               running (46m)     40s ago   46m     126M    2048M  16.2.7   cc266d6139f4  6783a2ae12b6
mon.ceph-node2            ceph-node2               running (2m)      41s ago    2m    76.9M    2048M  16.2.7   cc266d6139f4  bdaa180f8666
mon.ceph-node3            ceph-node3               running (63s)     41s ago   64s    72.5M    2048M  16.2.7   cc266d6139f4  a6ad80032630
node-exporter.ceph-node1  ceph-node1  *:9100       running (44m)     40s ago   44m    13.7M        -  0.18.1   e5a616e4b9cf  28f9bff30cd1
node-exporter.ceph-node2  ceph-node2  *:9100       running (111s)    41s ago  119s    5835k        -  0.18.1   e5a616e4b9cf  0472e4010722
node-exporter.ceph-node3  ceph-node3  *:9100       running (56s)     41s ago   63s    5867k        -  0.18.1   e5a616e4b9cf  23a2e8ad50b0
prometheus.ceph-node1     ceph-node1  *:9095       running (48s)     40s ago   44m    33.4M        -  2.18.1   de242295e225  e53242bb949b
```



## 2.5 部署 OSD

先为每个机器添加磁盘 `/dev/vdb`

```bash
ceph orch daemon add osd ceph-node1:/dev/vdb
ceph orch daemon add osd ceph-node2:/dev/vdb
ceph orch daemon add osd ceph-node3:/dev/vdb

ceph orch device ls
HOST        PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REJECT REASONS
ceph-node1  /dev/vdb  hdd              10.7G             Insufficient space (<10 extents) on vgs, LVM detected, locked
ceph-node2  /dev/vdb  hdd              10.7G             Insufficient space (<10 extents) on vgs, LVM detected, locked
ceph-node3  /dev/vdb  hdd              10.7G             Insufficient space (<10 extents) on vgs, LVM detected, locked
```



## 2.6 部署 MDS 提供 CephFs 功能

```bash
# 创建一个用于存储cephfs数据的pool
ceph osd pool create cephfs_data 64 64

# 创建一个存储cephfs元数据的pool
ceph osd pool create cephfs_metadata 32 32

# 创建 cephfs
ceph fs new cephfs cephfs_metadata cephfs_data
ceph fs ls

# 部署 mds
ceph orch apply mds cephfs --placement="3 ceph-node1 ceph-node2 ceph-node3"
ceph orch ps --daemon-type mds

# 查看集群所有的 pool
ceph osd lspools
```



## 2.7 部署 RGWS

Ceph RGW(即RADOS Gateway)是Ceph对象存储网关服务，是基于LIBRADOS接口封装实现的FastCGI服务，对外提供存储和管理对象数据的Restful API。 对象存储适用于图片、视频等各类文件的上传下载，可以设置相应的访问权限。目前Ceph RGW兼容常见的对象存储API，例如兼容绝大部分Amazon S3 API，兼容OpenStack Swift API

```bash
# 创建领域
radosgw-admin realm create --rgw-realm=cn --default

# 创建区域组
radosgw-admin zonegroup create --rgw-zonegroup=cn-eastern --master --default

# 创建区域
radosgw-admin zone create --rgw-zonegroup=cn-eastern --rgw-zone=shanghai --master --default

# 部署 RGW
ceph orch apply rgw cn shanghai --placement="3 ceph-node1 ceph-node2 ceph-node3"

# 检查 RGW
ceph orch ps --daemon-type rgw
```



## 2.8 RDB

```bash
# 创建 RBD
ceph osd pool create rbd 16

# 启用 RBD
ceph osd pool application enable rbd rbd

# 创建 RDB 存储
rbd create rbd0 --size 5120
rbd --image rbd0 info 

ceph osd crush tunables hammer
ceph osd crush reweight-all

# 关闭内核默认不支持的特性
rbd feature disable rbd0 exclusive-lock object-map fast-diff deep-flatten

# 查看特性是否已被禁用
rbd --image rbd0 info | grep features

# 映射到客户端
rbd map --image rbd0

# 映射情况
rbd showmapped

# 格式化
mkfs.xfs /dev/rbd0
mount /dev/rbd0 /mnt/rbd/
df -hl | grep rbd
```



## 2.9 存储对象

```bash
# 安装 AWS s3 API
yum install s3cmd -y

# 创建用户
radosgw-admin user create --uid=s3 --display-name="object storage" --system

# 获取access_key & secret_key
radosgw-admin uset info --uid=s3 | grep -E "access_key|secret_key"
            "access_key": "I3VN4PL455UORQO5T8ZA",
            "secret_key": "BaIEulgfNxQCgrM7hGNNsLrgbRoZ8fmMqgI9wGhV"

# 生成 s3 客户端配置
# s3cmd --configure
Access Key: I3VN4PL455UORQO5T8ZA
Secret Key: BaIEulgfNxQCgrM7hGNNsLrgbRoZ8fmMqgI9wGhV
S3 Endpoint [s3.amazonaws.com]: ceph-node1
DNS-style bucket+hostname:port template for accessing a bucket [%(bucket)s.s3.amazonaws.com]: ceph-node1
New settings:
  Access Key: I3VN4PL455UORQO5T8ZA
  Secret Key: BaIEulgfNxQCgrM7hGNNsLrgbRoZ8fmMqgI9wGhV
  Default Region: US
  S3 Endpoint: ceph-node1
  DNS-style bucket+hostname:port template for accessing a bucket: %(bucket)s.ceph-node1
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

vi /root/.s3cfg
cloudfront_host = ceph-node1
host_base = ceph-node1
host_bucket = ceph-node1

# 创建桶
s3cmd mb s3://bucket

# 查看当前所有桶
s3cmd ls
```



## 2.10 CephFS

```bash
# 创建客户端用户
ceph auth get-or-create client.cephfs mon 'allow r' mds 'allow r, allow rw path=/' osd 'allow rw pool=cephfs_data' -o ceph.client.cephfs.keyring

# 获取用户 token
ceph auth get-key client.cephfs

# 挂载
mkdir /mnt/cephfs/
mount -t ceph ceph-node1:/ /mnt/cephfs/ -o name=cephfs,secret=AQD6e+ZhQ5qzCBAAum6vziXvv69ksHTWDsqgGQ==

# 查看挂载
mount | grep cephfs
192.168.3.130:/ on /mnt/cephfs type ceph (rw,relatime,name=cephfs,secret=<hidden>,acl)
```

