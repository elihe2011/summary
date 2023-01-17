# 1. 简介

## 1.1 什么是 Ceph

Ceph 是一个非常流行的开源分布式存储系统，具有高扩展性、高性能、高可靠性等优点，同时提供块存储服务(rbd)、对象存储服务(rgw)以及文件系统存储服务(cephfs)，Ceph在存储的时候充分利用存储节点的计算能力，在存储每一个数据时都会通过计算得出该数据的位置，尽量的分布均衡。

Ceph设计思想：集群可靠性、集群可扩展性、数据安全性、接口统一性、充分发挥存储设备自身的计算能力、去除中心化

Ceph 的主要优势：

- 高性能

  - 摒弃了传统的集中式存储元数据寻址的方案，采用**CRUSH算法，数据分布均衡**，并行度高

  - 考虑了容灾域的隔离，能够实现各类负载的副本放置规则，例如跨机房、机架感知等

  - 能够支持上千个存储节点的规模。支持TB到PB级的数据

- 高可用

  - 副本数可以灵活控制

  - 支持故障域分隔，数据强一致性

  - 多种故障场景自动进行修复自愈

  - 没有单点故障，自动管理

- 高扩展性

  - 去中心化

  - 扩展灵活

  - 随着节点增加，性能线性增长

- 特性丰富

  - 支持三种存储接口：对象存储，块设备存储，文件存储

  - 支持自定义接口，支持多种语言驱动



## 1.2 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-arch-diagram-1.png) 

Ceph的底层是**RADOS**，RADOS本身也是分布式存储系统，RADOS采用C++开发，所提供的原生Librados API包括C和C++两种。Ceph的上层应用调用本机上的librados API，再由后者通过socket与RADOS集群中的其他节点通信并完成多种存储方式的文件和对象转换操作。

- RADOS GW (Object，有原生的API，而且也兼容Swift和S3的API，适合单客户端使用)
- RBD（Block，支持精简配置、快照、克隆，适合多客户端有目录结构）
- CephFS（File，Posix接口，支持快照，适合更新变动少的数据，没有目录结构不能直接打开）**它是内核态的程序，所有无需调用用户空间的librados库。它通过内核中的net模块来与RADOS进行交互。**



## 1.3 核心进程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-core-process.png)

三个核心进程：

- **OSD**：用于集群中所有数据与对象的存储。处理集群数据的复制、恢复、回填、再均衡，并向其他 osd 守护进程发送心跳，然后向 mon 进程提供监控信息
- **MDS(可选)**：为 CephFS 提供元数据计算、缓存和同步。元数据存储再 osd 节点上，mds 类似元数据的代理缓存服务器

​	![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-mds.png)

- **Monitor**：监控这个集群的状态，维护集群的 cluster MAP 二进制表，保证集群数据的一致性。ClusterMAP 描述了对象存储的物理位置，以及一个将设备集合到物理位置的桶列表



## 1.4 核心概念

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-arch-diagram-2.png) 

**Object**：Ceph 最底层的存储单元，每个 Obejct 包含元数据和原始数据

**PG**：`Placement Group`，放置策略组，是一个逻辑的概念，一个PG包含多个OSD。PG是为了更好的分配和定位数据

**RADOS**：`Reliable Autonomic Distributed Object Store`，即可靠的、自主的、分布式对象存储系统，它是Ceph集群的精华，用户实现数据分配、Failover等操作

**Librados**：RADOS的访问库，上层 RDB、RGW、CephFS 通过它访问 RADOS

**Crush**：Ceph 使用的数据分布算法，让数据分配到预期的地方

**Pool**：存储对象的逻辑分区，规定了数据冗余的类型和对应的副本分布策略，支持两种类型：副本(replicated) 和纠错码(erasure code)

**RBD**：`RADOS Block Device`，块设备服务

**RGW**：`RADOS Gateway`，对象存储服务，接口与 S3、Swift 兼容

**CephFS**：`Ceph File System`，文件系统服务



**Pool、PG及OSD的关系：**

- 一个 Pool 中有多个 PG
- 一个 PG 中包含一堆对象，一个对象只能属于一个 PG
- PG 有主从之分，一个 PG 分布在不同的 OSD 上 （一般配置三个副本）

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-pool-pg-osd.png)



## 1.5 存储类型

**块存储 RBD**：

- 优点：
  - 通过 Raid 和 LVM 等手段，对数据提供保护
  - 多块廉价的磁盘组合起来，提高容量
  - 多块磁盘组合成逻辑盘，提高读写速率
- 缺点：
  - SAN (存储区域网络) 组网，光纤交换机，造价高
  - 主机间无法共享数据
- 使用场景：
  - 容器、虚拟机磁盘存储分配
  - 日志存储
  - 文件存储



**文件存储 CephFS**:

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



**对象存储 RGW**: 适合变化较小的数据

- 优点：
  - 具备块存储的高读写速率
  - 具备文件存储的共享等特性
- 使用场景：
  - 图片存储
  - 视频存储



# 2. 存储引擎

## 2.1 存储架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-storage.png)

Ceph 后端支持多种存储引擎，以插件的形式进行管理。目前支持的引擎主要有 filestore, kvstore, memstore 和 bluestore，默认为 filestore。

**Filestore 的问题**：

- 在写数据前，需要先写 journal，会有一倍的写放大
- 如果另外配备 SSD 盘给 journal 使用，会增加额外成本
- 它是为 SATA/SAS 等机械硬盘设计的，未针对 SSD 等 Flash 介质盘做考虑

**Bluetore 的改进**：

- 减少写放大
- 针对 Flash 介质盘进行优化
- 直接管理裸盘，进一步减少文件系统部分的开销

结论：**机械盘场景 Bluestore 与 Filestore 在性能上相比没有太大优势，Bluestore的优势在 Flash 盘**



## 2.2 Filestore

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-filestore.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-filestore-flow.png)

操作步骤：

1. 为提高写事务的性能，增加 fileJournal 功能，所有的写事务在被 fileJournal 处理后都立即 callback(上图步骤2)；日志按 append only 模式处理，每次被 append 的 journal 文件末尾，同时该事务被写入 filestore op queue;
2. filestore 采用多 thread 方式从 op queue 中获取 op，然后真正 apply 事务数据到 disk (文件系统pagecache)。当 filestore 将事务写到 disk 上后，后续请求才会继续 (上图步骤5)
3. filestore 完成一个 op 后，对应的 journal 才会丢弃这部分 journal。

综上，对于每个副本都有两步操作：先写 journal，再写 disk，如果副本是3个，将涉及6次写操作，性能上体现不是很好。



## 2.3 Bluestore

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-bluestore.png)

1. bluestore 实现了震惊管理裸设备的方式，抛弃了本地文件系统。BlockDevice 实现了在用户态下使用 Linux aio (异步读写IO) 直接对裸设备进行 IO 操作，去除了本地文件系统的消耗，减少了系统复杂度，更有利于 Flash 介质盘发挥性能优势
2. bluestore 采用 allocator 进行裸磁盘的空间管理，目前支持 `StupidAllocator` 和 `BitmapAllocator` 两种方式
3. bluestore 的 metadata 以 KV 形式保存在 RocksDB 中，但它不能直接操作裸盘，为此 bluestore 实现了一个  BlueRocksEnv ，继承自 EnvWrapper，来为 RocksDB 提高底层文件系统的抽象接口支持；
4. 为对接 BlueRocksEnv, bluestore 实现了一个简洁的文件系统 BlueFS，只是实现 RocksDBEnv 所需的接口，在系统启动挂载这个文件系统时将所有的元数据加载到内存中，BlueFS 的数据和日志文件都通过 BlockDevice 保存到底层的裸设备上
5. BlueFS 和 bluestore 共享裸设备，也可分别指定不同的设备，比如为获得更好的性能，bluestore 采用 SATA SSD 盘，BlueFS 采用 NVMe SSD 盘

**内部组件**：

- **RocksDB**：存储预写式日志、数据对象元数据、Ceph的 omap 数据信息、分配器元数据等
- **BlueRocksEnv**：与 RocksDB 的交互接口
- **BlueFS**：迷你文件系统，解决元数据、文件空间及磁盘空间的分配和管理。因为 RocksDB 一般直接存储在 POSIX 兼容的文件系统上，但 BlueStore 引擎直接面向裸磁盘，没有兼容 POSIX 的文件接口，因此实现 RocksDBEnv 来满足 RocksDB 的适配性，在 osd 启动时，它被 mount 起来，并完成载入内存
-  **Allocator**：用来从空闲空间分配 block (即最小的可分配单位)



# 3. 核心组件

## 3.1 OSD

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-data-process.png)

Ceph 数据的存储过程：

- 无论使用何种存储方式 (对象、块、文件系统)，存储的数据都会被切分成对象 (Objects)
  - Object 大小由管理员调整，通常为 2M 或 4M
  - 每个 Object 都有一个唯一的 OID，由 `ino` 和 `ono` 组成。例如，FileID为A，被切成两个对象，则它的 OID 可以标识为 A0 & A1
    - ino：文件ID，用于全局唯一标识每个文件
    - ono：分片的编号

- Object 不会直接储存在 OSD中，因为它相对较小，如果直接存储，数量将十分可观，对象的遍历寻址将会很慢；而且如果将它直接通过某种固定映射的哈希算法映射到 osd 上，当这个 osd 损坏时，对象无法自动迁移到其他 osd 上；
- 为解决 Object 的存储问题，Ceph 引入了归置组策略 PG。PG是一个逻辑概念，它在数据寻址时类似数据库中的索引：每个 Object 都会固定映射进一个 PG 中，所以在寻找对象时，首先找到对象所属 PG，然后遍历这个 PG 即可；而且在数据迁移时，也是以 PG 作为基本单位进行迁移，Ceph 不会直接操作对象。
- Object 映射到 PG 的算法：使用静态hash函数对 OID 做hash运算得到特征码，用特征码与 PG 的数量取模，得到的序号就是 PGID。(PG 的数量直接决定了数据分布的均匀性，设定合理的PG数量可很好地提升Ceph集群的性能并使数据均匀分布)
- PG 会根据管理员设置的副本数量进行复制，然后通过 CRUSH 算法存储到不同的 OSD 节点上。第一个 osd 节点即为主节点，其余均为从节点

Ceph 存储流程：

```bash
locator = object_name
obj_hash = hash(locator)
pg = obj_hash % pg_num
osds_for_pg = crush(pg)   # return a list of osds
primary = osds_for_pg[0]
replicas = osds_for_pg[1:]
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-data-flow.png)

Pool 时管理员自定义的命名空间，用来隔离 Object 与 PG。使用对象存储时，需要指定对象要存储到哪一个 Pool 中。除了隔离数据，也可以对不同的 Pool 设置不同的优化策略，比如副本数、数据清洗次数、数据块即对象大小等。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-pool.png)

**OSD 是强一致性的分布式存储**，它的读写流程如下：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-osd-read-write.png)



总结：

- OSD进程，在Ceph中，每一个OSD进程都可以称作是一个OSD节点，也就是说，每台存储服务器可靠包含了众多的OSD节点，每个OSD节点监听不同的端口
- 每个OSD节点可以设置一个目录作为实际存储区域，也可以是一个分区、一整块硬盘。例如，一台机器上跑了两个OSD进程，每个OSD监听4个端口，分别用于接收客户请求、传输数据、发送心跳、同步数据等操作。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-osd-listener.png)

如上图所示，osd节点默认监听tcp的6800到6803端口，如果同一台服务器上有多个OSD节点，则依次往后排序。



## 3.2 Monitor

mon 节点监控着整个 Ceph 集群的状态信息，监听端口 6789。每个 Ceph 集群中至少需要一个 mon 节点，官方推荐每个集群至少部署三台。

mon 节点中保存了最新的爸爸集群数据分布图 (Cluster Map) 的主副本。客户端在使用时，需要挂载 mon 节点的 6789 端口，下载最小的  cluster map，通过 CRUSH 算法获取集群中个 OSD 的IP地址，然后再与 OSD 节点直接建立连接来传输数据。

mon 节点之间通过 Paxos 算法来保持各节点 Cluster Map 的一致性。

mon 节点不会主动轮询查询各个 OSD 的状态，相反，OSD只会在一些特殊的情况下上报自己的信息，平常之后简单的发送心跳，特殊情况包括：1、新的 OSD 加入集群；2、某个 OSD 发现自身或其他 OSD 发生异常。mon 节点在收到这些信息后，会更新 Cluster Map 信息并加以扩散。

Cluster Map 信息以异步且 lazy 的形式扩散的。monitor 不会再每次 Cluster Map 版本更新后将新版广播至全体 OSD，而是有  OSD 上报信息时，将更新回复给对方。类似的，各个 OSD 也是在和其他 OSD 通信时，如果发现对方的 OSD 中持有的 Cluster Map 版本较低，则把自己的版本发给对方。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-network.png)

Ceph 除了管理网络外，还有两个网段，一个用于客户端读写传输数据，另一个用于各 OSD 节点之间同步数据和发送心跳信息等。这样做可以分担网卡的 IO 压力，否则在数据清洗时，客户端的读写速度会变得即为缓慢。



## 3.3 MDS

mds 是 CephFS 的元数据服务器，但它不负责存储元数据，而是将元数据切成对象存储在各个 OSD 节点中。

在创建 CephFS 时，至少要创建两个 Pool，一个用于存储数据，另一个存储元数据。MDS 只负责接收用户的元数据查询请求，然后从 OSD 中把数据取出来映射进自己的内存供用户访问。所以 Mds 类似一个代理缓存服务器，替 OSD分担用户的访问压力

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-mds-flow.png)

# 4. 核心概念

## 4.1 存储数据 与 Object

当用户要数据存储到 Ceph 集群时，存储数据都会被分割成多个 Object，每个 Object 都有一个 OID，每个 Object 的大小是可以设置的，默认 4MB。**Object 是 Ceph 最小的存储单元**。



## 4.2 Object 与 PG

PG 是为了管理数据很多的 Object 而引入的概念，每个 Object 都会通过 CRUSH 计算映射到某个 PG 中，一个 PG 可以包含多个 Object。

OID 是进行线性映射生成的，即有 file 的元数据、Ceph 条带化产生的 Object 的序号连缀而成。此时 Object 需要映射到 PG 中，该映射包括两部分：

- 静态 hash 函数计算 Object 的 OID，获取其 hash 值
- 将 hash 值与 mask 进行操作，从而获得 PG ID

根据 RADOS 的设计，假定集群中设定的 PG 总数为M (=2^n)，则 mask 的值为 M-1。hash 值计算之后，进行**按位与操作**从所有 PG 中近似均匀地随机选择。基于该原理以及概率论的相关原理，当用于数据量庞大的 Object 及 PG 时，获得的 PG ID 是近似均匀的



## 4.3 PG 与 OSD

通过 CRUSH 算法，PG 被映射到数据存储 OSD 中，将 PG ID 作为该算法的输入，获得到包含 N 个 OSD 的集合，集合的第一个 OSD 被作为主 OSD，其余的 OSD 则依次作为从 OSD。N 为该 PG 所在 POOL 下的副本数量，在生产环境中 N 一般为 3；OSD 集合中的 OSD 将共同存储和维护该 PG 下的 Object。CRUSH 算法的影响因素：

- 当前系统状态，即 Cluster Map，当系统中的 OSD 状态，数量发生变化时，Cluster Map 可能发生变化，这种变化将会影响到 PG 和 OSD 之间的映射
- 存储策略配置。它主要与安全相关，利于策略配置，系统管理员可以指定承载同一个 PG 的 3 个 OSD 分别位于数据中心的不同服务器上，从而改善存储的可靠性。



## 4.4 PG 与 PGP

PG 用来存储 Object，PGP 相当于是 PG 存放 OSD 的一种排列组合。比如有 3 个 OSD，OSD.1、OSD.2 和 OSD.3，副本数为2，如果 PGP 的数量为1，那么 PG 存放的 OSD 组合只有一种可能：【OSD.1, OSD.2】，所有的 PG 主从副本分别存放在 OSD.1 和 OSD.2；如果 PGP 为2，那么 OSD 组合有两种：【OSD.1, OSD.2】、【OSD.1, OSD.3】

实验：

```bash
# 创建存储池testpool, 6个PG和6个PGP
$ ceph osd pool create testpool 6 6

# 统计信息
$ ceph osd pool stats testpool
pool testpool id 8
  nothing is going on

# PG的分布情况
$ ceph pg dump pgs | grep ^8 | awk '{print $1,$2,$16}'
dumped pgs
8.4 0 [2,0,1]
8.7 0 [1,0,2]
8.6 0 [0,2,1]
8.1 0 [1,0,2]
8.0 0 [1,2,0]
8.3 0 [0,1,2]
8.2 0 [0,1,2]
8.d 0 [0,2,1]
8.c 0 [0,1,2]
8.f 0 [0,1,2]
8.a 0 [0,1,2]
8.9 0 [0,2,1]
8.b 0 [0,2,1]
8.8 0 [2,1,0]
8.e 0 [1,2,0]
8.5 0 [0,2,1]
8.1a 0 [1,2,0]
8.1b 0 [2,1,0]
8.18 0 [2,0,1]
8.19 0 [2,0,1]
8.1e 0 [1,2,0]
8.1f 0 [0,2,1]
8.1c 0 [0,2,1]
8.1d 0 [1,0,2]
8.12 0 [2,0,1]
8.13 0 [1,0,2]
8.10 0 [2,0,1]
8.11 0 [0,2,1]
8.16 0 [0,1,2]
8.17 0 [2,1,0]
8.14 0 [2,1,0]
8.15 0 [0,2,1]

# 更改 pg & pgp 数量
$ ceph osd pool set testpool pg_num 3
$ ceph osd pool set testpool pgp_num 4
```



## 4.5 PG 与 Pool

Pool 是一个逻辑存储概念，创建 pool 时，需要指定 pg 和 pgp 的数量。逻辑上，object 属于某个 pg， 而 pg 属于某个 pool

数据、Object、PG、Pool、OSD、存储磁盘的关系：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-obj-pg-pool.png)

存储设备具有吞吐量限制，它影响读写性能和可扩展性能，所以存储系统通过支持条带化 (stripe) 方式来增加存储系统的吞吐量性能。最常见的条带化方式是 RAID。

- 将条带单元 (stripe unit) 从阵列的第一个磁盘到最后一个磁盘收集起来，可称之为条带。条带单元也被称为交错深度，在光纤技术中，一个条带单元被称为段
- 数据在阵列磁盘上以条带的形式分布，条带化是指数据在阵列中所有磁盘的存储过程。文件中的数据被分割成小块的数据段在阵列磁盘顺序上的存储，这个最小数据块即为条带阵列

Ceph 条带化提供了类似 RAID 0 的吞吐量，N 路 RAID 镜像的可靠性已经更快速的恢复能力。

决定 Ceph 条带化数据的 3 个因素：

- 对象大小：处于分布式集群中对象拥有一个最大可配置的尺寸 (2M, 4M等)，对象大小应该足够大以适应大量的条带单元
- 条带宽度：条带有一个可以配置的单元大小。Ceph 客户端将数据写入对象，分成相同大小的条带单元；
- 条带总量：Ceph 客户端写入一系列的条带单元到一系列的对象，这决定了条带的总量，这些对象被称为对象集。当 Ceph 客户端写入的对象集合中的最后一个对象之后，它将会返回到对象集合中的第一个对象处。



# 5. Crush 算法

## 5.1 数据分布式算法

- 数据分布和负载均衡
  - 数据分布均衡，使数据能均匀地分布到各个节点上
  - 负载均衡，使数据访问读写操作的负载在各个节点和磁盘的负载均衡
- 灵活应对集群伸缩
  - 集群可方便地增加或删除节点，并且对节点失效进行处理
  - 增加或删除节点后，能自动实现数据的均衡，并且尽可能少的迁移数据
- 支持大规模集群
  - 数据分布算法维护的元数据相对较小，并且计算量不能太大
  - 随着集群规模的增加，数据分布算法的开销相对较小



## 5.2 算法说明

CRUSH, Controlled Replication Under Scalable Hashing，是一种基于伪随机控制数据分布、复制的算法。

Crush 算法实现了 数据的平衡分布和负载 (提高资源利用率)、最大化系统的性能以及系统的扩展和硬件容错等。

PG 到 OSD 的映射过程算法即为 Crush 算法

Crush 算法是一个伪随机的过程，它可以从所有的 OSD 中，随机选择一个 OSD 集合，但是同一个 PG 每次随机选择的结果是不变的，即映射的 OSD 集合是固定的



## 5.3 算法因子

- **层次化的 Cluster Map**：反映了存储系统层级的物料拓扑结构。OSD 层级使得 Crush 算法在选择 OSD 时实现了机架感知能力，即通过规则定义，使得副本可以分布在不同的机架、不同的机房中，提高数据的安全性
- **Placement Rules**：决定了一个 PG 的对象副本如何选择的规则，通过这些可以自己设定规则，用户可以自定义设置副本在集群中的分布



## 5.4 关系分析

Crush 算法通过存储设备的权重来计算数据对象的分布，主要通过三个因素来确定数据对象的最终位置：

- Cluster Map  集群映射
- Data Distribution Policy  数据分布策略
- 一个随机数



### 5.4.1 Cluster Map

Cluster Map 记录所有可用的存储资源及它们之间的空间层次关系 (集群中有多少机架、机架上有多少服务器、每个服务器上有多少磁盘等信息)

Cluster Map 由 Device 和 Bucket 构成，它们都有自己的 ID 和权重值，并形成一个以 Device 为叶子节点、Bucket 为躯干的树状结构。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-cluster-map.png)

Bucket 拥有不同的类型，如 Host、Row、Rack、Room 等。

OSD的权重值越高，对应磁盘会被分配写入更多的数据。总体来说，数据会被均匀写入分布于集群所有磁盘，从而提高整体性能和可靠性。



### 5.4.2 Data Distribution Policy

由 Placement Rules 组成，Rule 决定了每个数据对象有多少个副本，这些副本存储的的限制条件等 (例如：3个副本放在不同的机架上）

```c
rule replicated_ruleset {           // rule名字
    ruleset 0                       // rule的ID
    type replicated                 // 类型为副本模式，另外一种模式为纠删码（EC）
    min_size 1                      // 如果存储池的副本数大于这个值，此rule不会应用
    max_size 10                     // 如果存储池的副本数大于这个值，此rule不会应用
    step take default               // 以default root 为入口
    step chooseleaf firstn 0 type host  // 隔离城为host级，即不同副本在不同的主机上
    step emit                       // 提交
}
```



### 5.4.3 Crush 伪随机

$$
CRUSH(x) \quad \rightarrow \quad (osd1,osd2 \cdots\cdots osdN)
$$

CRUSH使用了多参数的Hash函数，在Hash之后，映射都是按既定规则选择的，这使得从x到OSD的集合是确定的和独立的。CRUSH只使用Cluster Map、Placement Ruels、X。CRUSH是伪随机算法，相似输入的结果之间没有相关性。



## 5.5 总结

在PG通过Crush算法映射到数据的实际存储单元OSD时，需求通过Crush Map、Crush Rules和Crush算法配合才能完成。

Cluster Map用来记录全局系统状态记数据结构，由Crush Map和OSD Map两部分组成。 Crush Map包含当前磁盘、服务器、机架的层级结构，OSD Map包含当前所有Pool的状态和所有OSD的状态。

 Crush Rules就是数据映射的策略，决定了每个数据对象有多少个副本，这些副本如何存储。 Crush算法是一种伪随机算法，通过权重决定数据存放（如跨机房、机架感知等），通常采用基于容量的权重。Crush算法支持副本和EC两种数据冗余方式，还提供了四种不同类型的Bucket(Uniform、List、Tree、Straw)，大多数情况下的都采用Straw。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-crush-alg.png)



# 6. Ceph 数据流程

数据写入流程：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-arch-data-flow.png)



数据分布算法crush：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-crush-diagram.png)

- File用户需要读写文件，File->Object映射：

  - a. ino（File的元数据，File的唯一ID）

  - b. ono（File切分产生的某个Object的序号，默认以4M切分一个块大小）

  - c. oid（object id： ino + ono）

- Object是RADOS需要的对象。Ceph指定一个静态Hash函数计算OID的值，将OID映射成一个近似均匀分布的伪随机值，然后和mask按位相与，得到PGID。Object->PG映射：

  - a. hash(oid) & mask -> pgid

  - b. mask = PG总数m（m为2的整数幂）-1

- PG（Placement Group），用途是对Object的存储进行组织和位置映射，类似Redis Cluster里面的slot的概念。一个PG里面会有很多Object。采用CRUSH算法，将PGID带入其中，然后得到一组OSD。PG->OSD映射：
  - CRUSH(pgid) -> (osd1,osd2,osd3)



# 7. Ceph 心跳机制

心跳是用于节点间检测对方是否发送故障，以便及时发现故障点进入相应的故障处理流程。

故障检测策略应该能够做到：

- **及时**：节点发生异常如宕机或网络中断时，集群可以在可接受的时间范围内感知
- **适当的压力**：包括对节点的压力和网络的压力
- **容忍网络抖动**：网络偶尔延迟
- **扩散机制**：节点存活状态改变导致的元信息变化需要通过某种机制扩散到整个集群



## 7.1 心跳检查

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-heartbeat.png)

OSD节点会监听public、cluster、front和back四个端口:

- **public**：监听来自Monitor和Client的连接
- **cluster**：监听来自OSD Peer的连接
- **front**：供客户端连接集群使用的网卡，这里临时给集群内部之间进行心跳
- **back**：供集群内部使用的网卡，集群内部之间进行心跳
- **hbclient**：发送ping心跳的messenger



### 7.1.1 OSD 之间的心跳

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-heartbeat-osd-osd.png)

步骤：

- 同一个PG内的OSD相互心跳，它们互相发送PING/PONG信息
- 每隔6s检测一次（实际会在这个基础上加一个随机时间来避免峰值）
- 20s没有检测到心跳回复，加入failure队列



### 7.1.2 OSD 与 Mon 的心跳

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-heartbeat-osd-mon.png)

步骤：

- OSD有事件发生时（比如故障、PG变更）
- 自身启动5s内
- OSD周期性的上报给Monitor
  - OSD检查failure_queue中的伙伴OSD失败信息
  - 向Monitor发送失效报告，并将失败信息加入failure_pending队列，然后将其从failure_queue移除
  - 收到来自failure_queue或者failure_pending中的OSD的心跳时，将其从这两个队列中移除，并告知Monitor取消之前的失效报告
  - 当发生与Monitor网络重连时，会将failure_pending中的错误报告加回到failure_queue中，并再次发送给Monitor
- Monitor统计下线OSD
  - Monitor收集来自OSD的伙伴失效报告
  - 当错误报告指向的OSD失效超过一定阈值，且足够多的OSD报告其失效时，将该OSD下线



## 7.2 心跳检测总结

Ceph通过伙伴OSD汇报失效节点和Monitor统计来自OSD的心跳两种方式判定OSD节点失效。

- **及时**：伙伴OSD可以在秒级发现节点失效并汇报Monitor，并在几分钟内由Monitor将失效OSD下线
- **适当压力**：由于有伙伴OSD汇报机制，Monitor与OSD之间的心跳统计更像是一种保险措施，因此OSD向Monitor发送心跳的间隔可以长达600s，Monitor的检测阈值也可以长达900s。Ceph实际上是将故障检测过程中中心节点的压力分散到所有的OSD上，以此提高中心节点Monitor的可靠性，进而提高这个集群的可靠性
- **容忍网络抖动**：Monitor收到OSD对其伙伴OSD的汇报后，并没有马上将目标OSD下线，而是周期性地等待几个条件：
  - 目标OSD的失效时间大于通过固定量osd_heartbeat_grace和历史网络条件动态确定的阈值
  - 来自不同主机的汇报到的mod_osd_min_down_reports
  - 慢速前两个条件失效汇报没有被源OSD取消
- **扩散**：作为中心节点的Monitor并没有在更OSDMap后尝试广播通知所有的OSD和Client，而是惰性的等待OSD和Client来获取，以此来减少Monitor压力并简化交互逻辑



# 8. Ceph 通信框架

## 8.1 通信框架种类

- Simple 线程模式
  - 特点：每个网络连接，都会创建两个线程，一个用于接收，一个用于发送
  - 缺点：大量的连接将产生大量的线程，消耗CPU资源，性能低下
- Async 事件的IO多路复用模式：目前最广泛和通用的模式
- XIO 方式：使用开源的网络通信库 accelio 来是实现



## 8.2 通信框架设计模式

采取发布订阅模式 (Publish/Subscribe) 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-message-1.png)

步骤：

- Accepter监听peer的请求，调用SimpleMessenger::add_accept_pip3()创建新的pipe到SimpleMessenger::pipes来处理该请求
- Pipe用于消息的读取和发生。该类主要有两个组件：Pipe::Reader，Pipe::Writer用来处理消息读取和发送
- Messenger作为消息的发布者，各个Dispatcher子类作为消息的订阅者，Messenger收到消息之后，通过Pipe对取消息，然后转给Dispatcher处理
- Dispatcher是订阅者的基类，具体的订阅者后端继承该类，初始化的时候通过Messenger::add_dispatcher_tail/head注册到Messenger::dispatchers。收到消息后，通知该类处理
- DispatchQueue该类用来缓存收到的消息，然后唤醒DispatchQueue::dispatch_thread线程找到后端的Dispatch处理消息

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-message-2.png)



## 8.3 通信数据格式

通信协议格式由双方约定，消息内容主要分三部分：

- header
- user data
  - payload  // 元数据
  - middle   // 保留字段
  - data       // 数据
- footer  // 消息结束标记

```cpp
class Message : public RefCountedObject {
protected:
  ceph_msg_header  header;      // 消息头
  ceph_msg_footer  footer;      // 消息尾
  bufferlist       payload;  // "front" unaligned blob
  bufferlist       middle;   // "middle" unaligned blob
  bufferlist       data;     // data payload (page-alignment will be preserved where possible)

  /* recv_stamp is set when the Messenger starts reading the
   * Message off the wire */
  utime_t recv_stamp;       //开始接收数据的时间戳
  /* dispatch_stamp is set when the Messenger starts calling dispatch() on
   * its endpoints */
  utime_t dispatch_stamp;   //dispatch 的时间戳
  /* throttle_stamp is the point at which we got throttle */
  utime_t throttle_stamp;   //获取throttle 的slot的时间戳
  /* time at which message was fully read */
  utime_t recv_complete_stamp;  //接收完成的时间戳

  ConnectionRef connection;     //网络连接

  uint32_t magic = 0;           //消息的魔术字

  bi::list_member_hook<> dispatch_q;    //boost::intrusive 成员字段
};

struct ceph_msg_header {
    __le64 seq;       // 当前session内 消息的唯一 序号
    __le64 tid;       // 消息的全局唯一的 id
    __le16 type;      // 消息类型
    __le16 priority;  // 优先级
    __le16 version;   // 版本号

    __le32 front_len; // payload 的长度
    __le32 middle_len;// middle 的长度
    __le32 data_len;  // data 的 长度
    __le16 data_off;  // 对象的数据偏移量


    struct ceph_entity_name src; //消息源

    /* oldest code we think can decode this.  unknown if zero. */
    __le16 compat_version;
    __le16 reserved;
    __le32 crc;       /* header crc32c */
} __attribute__ ((packed));

struct ceph_msg_footer {
    __le32 front_crc, middle_crc, data_crc; //crc校验码
    __le64  sig; //消息的64位signature
    __u8 flags; //结束标志
} __attribute__ ((packed));
```



# 9. 总结

## 9.1 RADOS 对象寻址

Ceph 存储集群从 Ceph客户端接收数据，不管来自 Ceph块设备、Ceph对象存储、Ceph文件系统，还是基于 librados 的自定义实现，全部称之为对象。每个对象是文件系统中的一个文件，它们存在在对象存储设备上。由 Ceph OSD 守护进行处理存储设备上的读、写操作。

Ceph 消除了中心网关，允许客户端之间和 Ceph OSD 守护进程通信。Ceph OSD 守护进行自动在其它 Ceph 节点上创建对象副本来确保数据安全和高可用性；为保证高可用性，monitor 也实现了集群化。为消除中心节点，Ceph 使用了 CRUSH 算法。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-rados-object-addressing.png)

**File**：用户需要存储或访问的文件。用户存储数据时，将会被分割成多个 object

**Object**：每个 object 有唯一的 id，每个 object 的大小可以设置，默认 4MB。object 可看成 Ceph 存储的最小存储单元。

**PG(Placement Group)**：PG用于管理 object，每个 object 都会通过 CRUSH 算法计算映射到某个pg中，一个 pg 包含多个 object。

**OSD(object storage device)**：PG 也需要通过 CRUSH 算法计算映射到 osd 中存储。如果有两个副本，则每个 pg 都会映射到两个 osd 中，即[osd.1, osd.2]，那么 osd.1 中存放该 pg 的主副本，osd.2 则存放该 pg 的从副本，保证数据的冗余。



映射关系：

- **File -> object 映射**：按照 object 的最大 size 切分 file (相当于 RAID中的条带化)；每个切分后的 object 都有一个唯一的 oid；ino 是file的元数据，即file的唯一 id，ono则是 file 切分产生的 object 序号，而 `oid = ino + ono `
- **Object -> PG 映射**：通过 `hash(oid) & mask -> pgid`，将 object 映射到 PG 中。根据 RADOS 设计，给的 PG 的总是为 m(2^n)，则 mask 的值为 m-1。因此哈希计算和按位与操作整体结果事实上是从所有 m 个 PG 中近似均匀低随机选择一个。
- **PG -> OSD 映射**：采用 CRUSH 算法，将 pgid 传入，得到一组共 n 个 OSD。



## 9.2 集群维护

在集群中，各个 monitor 的功能总体一致，其相互间的关系可简单理解为主从备份关系。monitor 不主动轮询各个 OSD 的状态。相反，OSD 需要向 monitor 上报状态信息，常见的两种情况需要上报：

- 新的 OSD 加入集群
- 某个 OSD 发现自身或者其他 OSD 发生故障

monitor 在收到上报信息后，更新 cluster map 信息并扩散。cluster map 内容：

- **monitor map**：包含集群的 fsid、位置、名字、地址和端口，也包括当前版本、创建时间、最近修改时间。查询命令 `ceph mon dump`

  ```bash
  $ ceph mon dump
  epoch 5
  fsid 81b3d002-9609-11ed-beb5-bd87d244b25c
  last_changed 2023-01-17T06:32:53.616806+0000
  created 2023-01-17T01:52:21.239840+0000
  min_mon_release 16 (pacific)
  election_strategy: 1
  0: [v2:10.40.0.20:3300/0,v1:10.40.0.20:6789/0] mon.ceph01
  1: [v2:10.40.0.21:3300/0,v1:10.40.0.21:6789/0] mon.ceph02
  2: [v2:10.40.0.22:3300/0,v1:10.40.0.22:6789/0] mon.ceph03
  dumped monmap epoch 5
  ```

- osd map：包含集群的 fsid、创建时间、最近修改时间、存储池列表、副本数量、归属组数量、OSD列表及状态。查询命令 `ceph osd dump`

  ```bash
  $ ceph osd dump
  epoch 360
  fsid 81b3d002-9609-11ed-beb5-bd87d244b25c
  created 2023-01-17T01:52:24.077457+0000
  modified 2023-01-17T06:34:35.660371+0000
  flags sortbitwise,recovery_deletes,purged_snapdirs,pglog_hardlimit
  crush_version 12
  full_ratio 0.95
  backfillfull_ratio 0.9
  nearfull_ratio 0.85
  require_min_compat_client luminous
  min_compat_client luminous
  require_osd_release pacific
  stretch_mode_enabled false
  pool 1 'device_health_metrics' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 1 pgp_num 1 autoscale_mode on last_change 328 flags hashpspool stripe_width 0 pg_num_max 32 pg_num_min 1 application mgr_devicehealth
  pool 2 '.rgw.root' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 23 flags hashpspool stripe_width 0 application rgw
  pool 3 'default.rgw.log' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 25 flags hashpspool stripe_width 0 application rgw
  pool 4 'default.rgw.control' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 27 flags hashpspool stripe_width 0 application rgw
  pool 5 'default.rgw.meta' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 8 pgp_num 8 autoscale_mode on last_change 147 lfor 0/147/145 flags hashpspool stripe_width 0 pg_autoscale_bias 4 pg_num_min 8 application rgw
  pool 6 'default.rgw.buckets.index' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 8 pgp_num 8 autoscale_mode on last_change 263 lfor 0/263/261 flags hashpspool stripe_width 0 pg_autoscale_bias 4 pg_num_min 8 application rgw
  pool 7 'cephfs.new_cephfs.meta' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 268 flags hashpspool stripe_width 0 pg_autoscale_bias 4 pg_num_min 16 recovery_priority 5 application cephfs
  pool 8 'cephfs.new_cephfs.data' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 269 flags hashpspool stripe_width 0 application cephfs
  pool 9 'newrbd' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 64 pgp_num 64 autoscale_mode on last_change 276 flags hashpspool,selfmanaged_snaps stripe_width 0 application rbd
  pool 10 '.nfs' replicated size 3 min_size 2 crush_rule 0 object_hash rjenkins pg_num 32 pgp_num 32 autoscale_mode on last_change 348 flags hashpspool stripe_width 0 application nfs
  max_osd 4
  osd.0 up   in  weight 1 up_from 346 up_thru 357 down_at 279 last_clean_interval [8,278) [v2:10.40.0.20:6802/3305614373,v1:10.40.0.20:6803/3305614373] [v2:10.40.0.20:6804/3305614373,v1:10.40.0.20:6805/3305614373] exists,up 862d936b-81dd-4e0e-b349-d8771bd901de
  osd.1 up   in  weight 1 up_from 12 up_thru 357 down_at 0 last_clean_interval [0,0) [v2:10.40.0.21:6800/839322212,v1:10.40.0.21:6801/839322212] [v2:10.40.0.21:6802/839322212,v1:10.40.0.21:6803/839322212] exists,up 1e3eafe1-092e-417a-8702-d53108c7b224
  osd.2 up   in  weight 1 up_from 17 up_thru 356 down_at 0 last_clean_interval [0,0) [v2:10.40.0.22:6800/726862589,v1:10.40.0.22:6801/726862589] [v2:10.40.0.22:6802/726862589,v1:10.40.0.22:6803/726862589] exists,up 53bb1731-2851-4f5d-a698-907d7951b8f5
  pg_upmap_items 10.e [1,2]
  blocklist 10.40.0.20:6800/1606582008 expires 2023-01-18T01:52:39.525123+0000
  blocklist 10.40.0.20:0/2455497449 expires 2023-01-18T01:53:44.166093+0000
  blocklist 10.40.0.20:6801/1606582008 expires 2023-01-18T01:52:39.525123+0000
  blocklist 10.40.0.20:0/2532642866 expires 2023-01-18T01:53:44.166093+0000
  blocklist 10.40.0.20:6801/1997490213 expires 2023-01-18T01:53:44.166093+0000
  blocklist 10.40.0.20:6801/1348936590 expires 2023-01-18T06:22:09.591743+0000
  blocklist 10.40.0.20:0/4265282229 expires 2023-01-18T01:52:39.525123+0000
  blocklist 10.40.0.20:6800/1997490213 expires 2023-01-18T01:53:44.166093+0000
  blocklist 10.40.0.20:6810/2206575457 expires 2023-01-18T06:22:36.030647+0000
  blocklist 10.40.0.20:6811/2206575457 expires 2023-01-18T06:22:36.030647+0000
  blocklist 10.40.0.20:0/3482949002 expires 2023-01-18T06:22:09.591743+0000
  blocklist 10.40.0.20:0/3384338966 expires 2023-01-18T01:52:54.437086+0000
  blocklist 10.40.0.20:0/3492453501 expires 2023-01-18T01:52:54.437086+0000
  blocklist 10.40.0.20:0/2520319630 expires 2023-01-18T06:22:09.591743+0000
  blocklist 10.40.0.20:0/2344200192 expires 2023-01-18T06:22:09.591743+0000
  blocklist 10.40.0.20:6800/1348936590 expires 2023-01-18T06:22:09.591743+0000
  blocklist 10.40.0.20:6800/3803220924 expires 2023-01-18T01:52:54.437086+0000
  blocklist 10.40.0.20:6801/3803220924 expires 2023-01-18T01:52:54.437086+0000
  blocklist 10.40.0.20:0/1724668103 expires 2023-01-18T01:52:39.525123+0000
  ```

  osd 状态维度：up/down(OSD是否正常工作)、in/out(OSD中是否至少一个PG)，组合四种状态：

  - up+in：正常工作且最少一个PG，属标准工作状态
  - up+out：正常工作但没有PG。新加入的 OSD 或故障修复的 OSD 会在这个状态
  - down+in：发生异常但任承载至少一个PG，即存储在数据。该状态下OSD刚刚发现存在异常，可能恢复正常，也可能彻底无法工作
  - down+out：该 OSD 发生故障，无法工作

- **PG map**：包含归置组版本、其时间戳、最新的 OSD 运行图版本、占满率、以及各归置组详情，像归置组 ID 、 up set 、 acting set 、 PG 状态（如 active+clean ），和各存储池的数据使用情况统计。查看命令 `ceph pg dump`

- **CRUSH map**：包含存储设备列表、故障域树状结构（如设备、主机、机架、行、房间、等等）、和存储数据时如何利用此树状结构的规则。要查看 CRUSH 规则，执行 `ceph osd getcrushmap -o {filename}` 命令；然后用 `crushtool -d {comp-crushmap-filename} -o {decomp-crushmap-filename}` 反编译；然后就可以用 cat 或编辑器查看了。

- **MDS map**：包含当前 MDS 图的版本、创建时间、最近修改时间，还包含了存储元数据的存储池、元数据服务器列表、还有哪些元数据服务器是 up 且 in 的。



## 9.3 新增 OSD

**步骤一**：一个新的 OSD 上线后，首先与 monitor 通信，然后由 monitor 将其加入 cluster map，并设置为 up 且 out 状态，再将最新的 cluster map 发给这个新的OSD；收到 monitor 发生的 cluster map 后，这个新的 OSD 将计算除自己所承载的 PG，以及和自己承载同一个 PG 的其他 OSD，然后与这些 OSD 取得联系。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-osd-1.png)

**步骤二**：如果这个 PG 目前处于降级状态(即承载 PG 的 OSD 数量小于正常值，如正常需要3个，但目前只有2个，一般由OSD故障导致)，则其他 OSD 会把这个 PG 内的所有对象和数据复制给新 OSD；数据复制完毕后，新增的 OSD 被置为 up 且 in 状态；而 cluster map 数据也将被更新，本质上是一个自动化的 failure recovery 过程。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-osd-2.png)

**步骤三**：如果该 PG 目前一切正常，则这个新的 OSD 将替换现有 OSD中的一个(PG 内将重新选出 Primary OSD)，并承担其数据。在数据复制完成后，新 OSD 被置为 up 且 in 状态，而被替换的 OSD 将退出该 PG。而 cluster map 数据也将被更新，本质上是一个 自动化的数据 rebalancing 过程。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/ceph/ceph-osd-3.png)

**步骤四**：如果一个 OSD 发现和自己共同承载一个 PG 的另一个 OSD 无法通信，则会上报 monitor；如果一个 OSD 发现自己工作状态异常，也会上报 monitor。当 monitor 收到上报后，会将故障的 OSD 状态设置为 down 且 in。如果超过某个预定的时间期限，该 OSD任无法恢复正常，则其状态将被设置为 down 且 out；反之如果 OSD 恢复正常，其状态恢复成 up 且 in。上述状态发生变化后，monitor 都会更新 cluster map 并扩散，本质上是自动化的 failure detection 过程。
