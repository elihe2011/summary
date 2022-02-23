# 1. 简介

## 1.1 特点

Kafka 是一个分布式、分区的、多副本的、多订阅者，基于zookeeper协调的分布式日志系统，常见可以用于web/nginx日志、访问日志，消息服务等

Kafka是一个分布式流媒体平台，它主要有三种功能：

- 发布和订阅消息流
- 以容错方式记录消息流，以文件方式存储消息流
- 可以在消息发布的时候进行处理

Kafka是分布式的，其所有的构件borker(服务端集群)、producer(消息生产)、consumer(消息消费者)都可以是分布式的。

在消息的生产时可以使用一个标识topic来区分，且可以进行分区；每一个分区都是一个顺序的、不可变的消息队列， 并且可以持续的添加。

同时为发布和订阅提供高吞吐量。

消息被处理的状态是在consumer端维护，而不是由server端维护。当失败时能自动平衡



**kafka 特性**：

- 高吞吐量高

- 顺写日志

- 零复制  sendFile 指令

- 分段日志 Segment。把一个文件分成多段，根据offset去读取相应的日志

- 预读 (read ahead), 后写 (write hehind)。预读：预选读取相邻的数据；后写：

  - 传统文件拷贝：a.txt -> PageCache => App-ReaderBuffer -> App-WriteBuffer => PageCache -> b.txt/network
  - kafka: a.txt -> PageCache -> b.txt。kafka 下发sendFile指令，OS 直接将PageCache数据发送出去

  - 传统的写：data -> WB => File
  - kafka后写：data => Cache -> File  由操作系统决定写入文件的时机 



## 1.2 使用场景

- **监控**：主机通过Kafka发送与系统和应用程序健康相关的指标，然后这些信息会被收集和处理从而创建监控仪表盘并发送警告。

- **消息队列**： 应用程度使用Kafka作为传统的消息系统实现标准的队列和消息的发布—订阅。Kafka有更好的吞吐量，内置的分区，冗余及容错性，这让Kafka成为了一个很好的大规模消息处理应用的解决方案。

- **站点用户活动追踪**: 为了更好地理解用户行为，改善用户体验，将用户查看了哪个页面、点击了哪些内容等信息发送到每个数据中心的Kafka集群上，并通过Hadoop进行分析、生成日常报告。

- **流处理**：保存收集流数据，以提供之后对接的Storm或其他流式计算框架进行处理。很多用户会将那些从原始topic来的数据进行阶段性处理、汇总、扩充或者以其他的方式转换到新的topic下再继续后面的处理。

- **日志聚合**: 使用Kafka代替日志聚合（log aggregation）。日志聚合一般来说是从服务器上收集日志文件，然后放到一个集中的位置（文件服务器或HDFS）进行处理。Kafka忽略掉文件的细节，将其更清晰地抽象成一个个日志或事件的消息流。这就让Kafka处理过程延迟更低，更容易支持多数据源和分布式数据处理。比起以日志为中心的系统比如Scribe或者Flume来说，Kafka提供同样高效的性能和因为复制导致的更高的耐用性保证，以及更低的端到端延迟

- **持久性日志**：Kafka可以为一种外部的持久性日志的分布式系统提供服务。这种日志可以在节点间备份数据，并为故障节点数据回复提供一种重新同步的机制。



# 2. 原理

## 2.1 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka.png)

- Broker: kafka 服务节点，即部署了kafka的服务器
- Topic：kafka 中，消息以 topic 为单位进行划分，生产者将消息发送到特定的 topic, 而消费者负责订阅 topic 并进行消费

- Partition: Topic 物理上分组，它可以分为多个分区，每个分区只属于单个topic。同一个topic下不同 partition包含的消息是不同的，分区在存储层面可看作是一个追加的日志文件，消息在被追加到分区日志的时候，都会分配一个特定的偏移量。
- Segment: Partition 物理上由多个 segment 组成，每个segment存着message信息
- Offset：消息在分区中的唯一标识，kafka 通过它来保证消息在分区内的顺序性，但是 offset 不能跨分区，即 kafka 保证的是分区的有序性而不是主题的有序性。
- Replica: 同一个 Partition 的数据，可在多个 Broker 存在多个副本。通常只有主副本对外提供读写服务，当主副本所在 broker 宕机，kafka 会重新选择新的 Leader 副本对外提供读写服务
- Producer：生产者，即消息发送方。它负责创建并发送消息到 kafka
- Consumer：消费者，即消息接收方。连接到 kafka 并接收消息，然后进行相应的业务逻辑处理
- Consumer Group：一个消息者组可包含一个或多个消费者。使用多分区+多消费者方式，可极大提高数据下游处理速度，同一个消费者组中的消费者不会重复消费数据，同样的，不同消费者组中的消费者消费消息时互不影响。kafka 通过消费组的方式来实现 P2P 和 广播模式。
- Leader：每个 partition 有多个副本，其中有且仅有一个作为 leader，负责当前分区的数据读写操作
- Follower：所有的写请求都通过 leader 路由，数据变更后会广播给所有 Follower，follower 主动发起数据同步请求。如果 leader 失效，则从 follower 中选举出一个新的 leader。如果 follower与leader的同步太慢，leader会把这个follower从 ISR 删除，然后重建一个 follower



## 2.2 工作流程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-work-flow.png)

1) 生产者从kafka集群获取分区leader信息

2) 生产者将消息发送给leader

3) leader将消息写入本地磁盘

4) follower从leader拉取消息数据 （主动地）

5) follower将消息写入本地磁盘后向leader发送ACK

6) leader收到所有的follower的ACK之后向生产者发送ACK



## 2.3 选择 Partition 的原则

1. partition在写入的时候可以指定需要写入的partition，如果有指定，则写入对应的partition。

2. 如果没有指定partition，但是设置了数据的key，则会根据key的值hash出一个partition。

3. 如果既没指定partition，又没有设置key，则会采用轮询⽅式，即每次取一小段时间的数据写入某个partition，下一小段的时间写入下一个partition

总结：**指定就用指定的；未指定则使用key的hash来确定；没有key的，则通过时间段轮询方式写入**



## 2.4 ACK 应答机制

producer 往集群发送数据，ACK应答，可设置 0, 1, all 三种值：

- 0：不需要等待集群的返回，不确保消息发送成功。安全性最低但效率最高。
- 1：只要leader应答就可以发送下一条，只确保leader发送成功。
- all：需要所有的follower都完成从leader的同步才会发送下一条，确保所有的副本都完成备份。安全性最高但效率最低。



## 2.5 Topic 和数据日志

topic 是同⼀类别的消息记录（record）的集合。在Kafka中，⼀个主题通常有多个订阅者。对于每个主题，Kafka集群维护了⼀个分区数据⽇志⽂件结构。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-topic-anatomy.png)

每个partition都是⼀个**有序**并且不可变的消息记录集合。当新的数据写⼊时，就被追加到partition的末尾。在每个partition中，每条消息都会被分配⼀个顺序的唯⼀标识，这个标识被称为offset，即偏移量。注意，**Kafka只保证在同⼀个partition内部消息是有序的，在不同partition之间，并不能保证消息有序。**

Kafka可以配置⼀个保留期限，⽤来标识⽇志会在Kafka集群内保留多⻓时间。Kafka集群会保留在保留期限内所有被发布的消息，不管这些消息是否被消费过。⽐如保留期限设置为两天，那么数据被发布到 Kafka集群的两天以内，所有的这些数据都可以被消费。当超过两天，这些数据将会被清空，以便为后续的数据腾出空间。由于Kafka会将数据进⾏持久化存储（即写⼊到硬盘上），所以保留的数据⼤⼩可以设置为⼀个⽐较⼤的值。



## 2.6 Partition 结构

- topic 在物理层面以 partition 为分组，一个 topic 可分成若干个 partition。partition 可细分为 segment，一个 partition 物理上由多个 segment 组成
- Logsegment 文件由 ".index" 和 ".log" 文件组成，分别为索引文件和数据文件
  - partition 全局的第一个 segment 从0开始，后续每个 segment 文件名最后一条消息的offset值
  - 数值大小为64位，20位数字字符长度，没有数据用0填充
  - 第一个 segment：00000000000000000000.index和00000000000000000000.log
  - 第二个 segment，为最后一条offset组成：00000000000000170410.index
- 索引文件以稀疏索引的方式构造消息的索引
- 偏移量索引和时间戳索引根据二分查找法来定位
- 索引查找只是 kafka的一个辅助功能，不需要为个这个功能花费高代价取维护一个高 level的索引

日志存储目录：`config/server.properties log.dirs=/tmp/kafka-logs`

**LogSegment:**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-log-segment.png)

Partition 是  Topic 的数据物理存储，本质是一个文件夹。每个分区被划分为多个日志分段 (LogSegment)，日志段是kafka日志对象分片的最小单位

LogSegment 的构成：

```bash
00000000000000000000.log      	# 数据文件
00000000000000000000.index  	# 索引文件
00000000000000000000.timeindex	# 索引文件
00000000000000000000.txnindex 	# 终止事务的索引文件
leader-epoch-checkpoint
```



为什么kafka快？

kafka 将磁盘中的随机读变为顺序读，通过index 和 timeindex 索引，能快速找到数据在那个磁盘的那个文件中、索引位置等等，能够快速操作数据，效率较高。



为什么要分区?

- 分区后，上传HDFS建立分布式
- 提高吞吐量
- 一个分区只能被消费者组中的一个消费者所消费。



**如何通过 offset 找到某一个消息？**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-index-log.png)

1. 首先根据 offset 值去找到 segment 中的 index 文件，因为 index 文件是以上个文件的最大 offset  偏移命名的，所以可通过二分法快速定位到索引文件
2. 找到索引文件后，根据索引文件中保存的 offset ，找到对应消息行在 log 文件中的存储行号。因为 kafka 采用稀疏矩阵的方式来存储索引信息，并不是每一条索引都存储，所以这里只是查到文件中符合当前 offset 范围的索引
3. 拿到 当前查询的索引范围定义的行号后，去对应的 log 文件中，从当前 position 位置开始查找 offset 对应的消息，直到找到该 offset 为止



## 2.7 消费者组

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-consumer-group.png)

**Consumer Group 特性**：

- 拥有一个或多个 Consumer 实例。该实例可以是一个进程，也可以是线程

- 拥有唯一的标识 Group ID

- 订阅的 Topic 下的每个分区，只能分配给组内某个 Consumer 实例消费



**消费总结**：

- 同一个分区内的消息只能被同一个组中的一个消费者消费，当消费者数量大于分区数量时，多余的消费者空闲（不能消费数据）
- 当分区数多于消费者数的时候，有的消费者对应多个分区；当分区数等于消费者数的时候，每个消费者对应一个分区。
- 启动多个组，相同的数据会被不同组的消费者消费多次。



**消费者位置**：消费者在消费过程中，需要记录自己消费了多少数据，即消费位置信息。它通过位移(offset) 来管理。kafka通过两种方式，来标记消费者位置：

1. 每个消费组保存自己的位移信息
2. 通过 checkpoint 机制定期持久化



**位移(offset)管理**：

1. 自动提交 ：`enable.auto.commit = true`。kafka会定期把 group 消费清空保存起来，形成一个 offset map

2. 位移提交：增加一个 `__consumers_offsets` Topic, 将 offset 信息写入该主题。`__consumer_offsets` 中保存了每个 consumer group 某一时刻提交的 offset 信息。

   ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-consumer-offsets.png)



**Rebalance**: 是一种协议，规定在一个消费者组中，所有的 Consumer 如何达成一致，来分配订阅的 Topic 的分区。当Rebalance发生时，所有的 Consumer 实例都会协调在一起共同参与

Rebalance 触发条件：

- 组成员数变更
- 订阅主题数变更
- 订阅主题的分区数变更

Rebalance 的劣势：

- 在 Rebalance 过程中，所有 Consumer 实例将停止消费，等待 Rebalance 完成，影响性能
- 所有 Consumer 实例共同参与，全部重新分配所有分区
- Rebalance 速度缓慢



# 3. 消息格式

## 3.1 V0

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-message-v0.png)

字段解释：

- magic: 消息格式版本，此版本为0
- attributes: 消息属性，低3位表示压缩类型。0-none, 1-gzip, 2-snappy, 3-LZ4
- key length: 如果为-1，则表示没有设置key, 即key=null
- key：可选
- value length: 如果为-1，表示消息为空
- value：消息体，可选

```bash
kafka-run-class.sh kafka.tools.DumpLogSegments --files /tmp/kafka-logs/msg_format_v0-0/00000000000000000000.log
Dumping /tmp/kafka-logs-08/msg_format_v0-0/00000000000000000000.log
Starting offset: 0
offset: 0 position: 0 isvalid: true payloadsize: 5 magic: 0 compresscodec: NoCompressionCodec crc: 592888119 keysize: 3
```



## 3.2 V1

v1 比 v0 多了一个 timestamp

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-message-v1.png)

- magic: 固定 1
- attribute： 第四个 bit表示timestamp类型，0-CreateTime 1-LogAppendTime

```text
    1. 4 byte CRC32 of the message
    2. 1 byte "magic" identifier to allow format changes, value is 0 or 1
    3. 1 byte "attributes" identifier to allow annotations on the message independent of the version
       bit 0 ~ 2 : Compression codec
           0 : no compression
           1 : gzip
           2 : snappy
           3 : lz4
       bit 3 : Timestamp type
           0 : create time
           1 : log append time
       bit 4 ~ 7 : reserved
    4. (可选) 8 byte timestamp only if "magic" identifier is greater than 0
    5. 4 byte key length, containing length K
    6. K byte key
    7. 4 byte payload length, containing length V
    8. V byte payload
```



**消息压缩:**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-message-wrap.png)



## 3.3 V2

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/platform/kafka-message-v2.png)

**Record:**

- length: 消息总长度
- attributes: 弃用
- timestamp delta: 时间戳增量
- offset delta: 位移增量。保存与RecordBatch起始位置的差值，可节约占用字节数
- headers: 扩展字段，一个Record里可包含0~N个header



**RecordBatch**:

- first offset: 当前 RecordBatch 的起始位移
- length: 计算 partition leader epoch 到 headers 之间的长度
- partition leader epoch: 用来确保数据可靠性
- magic：消息版本号，固定2
- attributes: 消息属性。低3位表示压缩格式；第四位表示时间戳类型；第五位表示此RecordBatch是否处于事务中，0-非事务，1-事务；第六位表示是否Control消息：0-no, 1-yes
- last offset delta: RecordBatch 中最后一个 Record的 offset 与 first offset 的差值。主要被 broker 用来确认 RecordBatch 中 Records 的组装正确性
- first timestamp: RecordBatch 中第一条 Record 的时间戳
- max timestamp: RecordBatch 中最大的时间戳，一般指最后一个 Record的时间戳，和 last offset delta 一样，用来确保消息组装的正确性
- producer id: 用来支持冥等性
- producer epoch：同上
- first sequence：同上
- records count：Record 个数

```bash
$ kafka-run-class.sh kafka.tools.DumpLogSegments --files /tmp/kafka-logs/msg_format_v2-0/00000000000000000000.log --print-data-log
Dumping /tmp/kafka-logs/msg_format_v2-0/00000000000000000000.log
Starting offset: 0
baseOffset: 0 lastOffset: 0 baseSequence: -1 lastSequence: -1 producerId: -1 producerEpoch: -1 partitionLeaderEpoch: 0 isTransactional: false position: 0 CreateTime: 1524709879130 isvalid: true size: 76 magic: 2 compresscodec: NONE crc: 2857248333
```





# 4. 安装 Kafka

## 4.1 原生安装包

下载 [kafka](http://kafka.apache.org/downloads.html) 并解压

```bash
# 启动 zookeeper
zookeeper-server-start.bat ..\..\config\zookeeper.properties

# 启动 kafka-broker
kafka-server-start.bat ..\..\config\server.properties

# 创建 topic
kafka-topics.bat --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic myTopic

# 获取 topic 列表
kafka-topics.bat --list --zookeeper localhost:2181

# 查询 topic 的配置信息
kafka-run-class.bat kafka.admin.TopicCommand --describe --zookeeper localhost:2181 --topic myTopic

# 启动生成者
kafka-console-producer.bat --broker-list localhost:9092 --topic myTopic
> hello kafka

# 启动消费者
kafka-console-consumer.bat --bootstrap-server localhost:9092 --topic myTopic --from-beginning
hello kafka
```



## 4.2 Docker 集群

docker-compose.yml

```yaml
version: '3'

networks:
  kafka_network:
    external: true

services:
  zk1:
    image: confluentinc/cp-zookeeper:5.5.4
    container_name: zk1
    ports:
      - "12181:12181"
    environment:
      ZOOKEEPER_SERVER_ID: 1
      ZOOKEEPER_CLIENT_PORT: 12181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_INIT_LIMIT: 5
      ZOOKEEPER_SYNC_LIMIT: 2
      ZOOKEEPER_SERVERS: zk1:12888:13888;zk2:22888:23888;zk3:32888:33888
    volumes:
      - ./zk1/data:/var/lib/zookeeper/data
      - ./zk1/log:/var/lib/zookeeper/log
    networks:
      - kafka_network

  zk2:
    image: confluentinc/cp-zookeeper:5.5.4
    container_name: zk2
    ports:
      - "22181:22181"
    environment:
      ZOOKEEPER_SERVER_ID: 2
      ZOOKEEPER_CLIENT_PORT: 22181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_INIT_LIMIT: 5
      ZOOKEEPER_SYNC_LIMIT: 2
      ZOOKEEPER_SERVERS: zk1:12888:13888;zk2:22888:23888;zk3:32888:33888
    volumes:
      - ./zk2/data:/var/lib/zookeeper/data
      - ./zk2/log:/var/lib/zookeeper/log
    networks:
      - kafka_network

  zk3:
    image: confluentinc/cp-zookeeper:5.5.4
    container_name: zk3
    ports:
      - "32181:32181"
    environment:
      ZOOKEEPER_SERVER_ID: 3
      ZOOKEEPER_CLIENT_PORT: 32181
      ZOOKEEPER_TICK_TIME: 2000
      ZOOKEEPER_INIT_LIMIT: 5
      ZOOKEEPER_SYNC_LIMIT: 2
      ZOOKEEPER_SERVERS: zk1:12888:13888;zk2:22888:23888;zk3:32888:33888
    volumes:
      - ./zk3/data:/var/lib/zookeeper/data
      - ./zk3/log:/var/lib/zookeeper/log
    networks:
      - kafka_network

  kfk1:
    image: confluentinc/cp-kafka:5.5.4
    container_name: kfk1
    ports:
      - "19092:19092"
    expose:
      - "19092"
    depends_on:
      - zk1
      - zk2
      - zk3
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zk1:12181,zk2:22181,zk3:32181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kfk1:19092
    volumes:
      - ./kfk1/data:/var/lib/kafka/data
    networks:
      - kafka_network

  kfk2:
    image: confluentinc/cp-kafka:5.5.4
    container_name: kfk2
    ports:
      - "29092:29092"
    expose:
      - "29092"
    depends_on:
      - zk1
      - zk2
      - zk3
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: zk1:12181,zk2:22181,zk3:32181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kfk2:29092
    volumes:
      - ./kfk2/data:/var/lib/kafka/data
    networks:
      - kafka_network

  kfk3:
    image: confluentinc/cp-kafka:5.5.4
    container_name: kfk3
    ports:
      - "39092:39092"
    expose:
      - "39092"
    depends_on:
      - zk1
      - zk2
      - zk3
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: zk1:12181,zk2:22181,zk3:32181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kfk3:39092
    volumes:
      - ./kfk3/data:/var/lib/kafka/data
    networks:
      - kafka_network

  kafka-manager:
    image: sheepkiller/kafka-manager:latest
    restart: unless-stopped
    container_name: kafka-manager
    hostname: kafka-manager
    ports:
      - "9000:9000"
    links:
      - kfk1
      - kfk2
      - kfk3
    external_links:
      - zk1
      - zk2
      - zk3
    environment:
      ZK_HOSTS: zk1:12181,zk2:22181,zk3:32181
      TZ: "Asia/Shanghai"
    networks:
      - kafka_network
```

集群管理：

```bash
# 启动集群
$ docker-compose up -d

# 安装 kafkacat
$ sudo apt install kafkacat

# 检查 kfk1 节点状态
$ kafkacat -L -b kfk1:19092
Metadata for all topics (from broker 1: kfk1:19092/1):
 3 brokers:
  broker 2 at kfk2:29092
  broker 3 at kfk3:39092
  broker 1 at kfk1:19092 (controller)
 1 topics:
  topic "__confluent.support.metrics" with 1 partitions:
    partition 0, leader 2, replicas: 2,3,1, isrs: 2,3,1

# 通过 kfk1 向 topic: hello 推送消息
$ kafkacat -P -b kfk1:19092 -t hello
hello, kafka
this is my first message via kafka!

# 通过 kfk3 从 topic: hello 接收消息
$ kafkacat -C -b kfk3:39092 -t hello
% Reached end of topic hello [0] at offset 0
hello, kafka
% Reached end of topic hello [0] at offset 1
this is my first message via kafka!
% Reached end of topic hello [0] at offset 2

# 通过 kfk2 从 topic: hello 接收消息
$ kafkacat -C -b kfk2:29092 -t hello
hello, kafka
this is my first message via kafka!
% Reached end of topic hello [0] at offset 2
go go go....
% Reached end of topic hello [0] at offset 3
```



## 4.3 k8s 集群

详见 





# 5. 操作命令

```bash
# topic 列表
kafka-topics.sh --list --bootstrap-server ip1:9092,ip2:9092,ip3:9092

# topic 新建
kafka-topics.sh --create --partitions 3 --replication-factor 1 --topic test --bootstrap-server ip1:9092,ip2:9092,ip3:9092 

# topic 详情
kafka-topics.sh --describe --topic sv --bootstrap-server ip1:9092,ip2:9092,ip3:9092

# topic 修改 (未成功，UnsupportedVersionException)
kafka-topics.sh --alter --partitions 10 --topic test --bootstrap-serverip1:9092,ip2:9092,ip3:9092 

# topic 删除
kafka-topics.sh --delete --bootstrap-server ip1:9092,ip2:9092,ip3:9092 --topic test

# 查看topic分区偏移量
kafka-run-class.sh kafka.tools.GetOffsetShell --topic test --broker-list ip1:9092,ip2:9092,ip3:9092 

# 生产数据
kafka-console-producer.sh --topic test --broker-list ip1:9092,ip2:9092,ip3:9092 

# 消费数据
kafka-console-consumer.sh --from-beginning --topic test --bootstrap-server ip1:9092,ip2:9092,ip3:9092 


kafka-topics.sh --list -bootstrap-server kafka-0.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-1.kafka-svc.kafka-cluster.svc.cluster.local:9092,kafka-2.kafka-svc.kafka-cluster.svc.cluster.local:9092
```





# 6. 问题总结

## 6.1 丢消息

- 生产者丢失消息：设置 `retries` 次数，可设置为 3 次，另外，重试时间间隔不能太小，因网络波动导致的消息丢失
- 消费者丢失消息：**手动关闭闭自动提交 offset，每次在真正消费完消息之后之后再自己手动提交 offset** 。但可能导致消息被重新消费的问题。比如刚刚消费完消息之后，还没提交 offset 就挂掉，那么这个消息理论上会被消费两次。
- Kafka 弄丢了消息：**acks = all**
