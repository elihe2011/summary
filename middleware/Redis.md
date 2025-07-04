# 1. 入门

## 1.1 简介

Redis：**Remote Dictionary Server**，高性能非关系型(NoSQL)键值对数据库

**特性**：

- key-value 存储
- 支持数据可靠性存储及落地
- 单进程但线程高性能服务器
- crash safe & recovery slow
- 单机qps可达10W
- 适合小数据量高速读写访问

**应用场景：**

- 高速缓存
  - 高频次，热门数据，降低数据库IO
  - 分布式，做session共享

- 多样化数据结构
  - 最新N个数据：通过List实现按时间排序的数据
  - 排行榜，top N：zset有序集合
  - 时效性数据，验证码：Expire过期
  - 计算器，秒杀：原子性，INCR， DECR
  - 大数据量去重：set集合
  - 队列：list
  - 发布订阅：pub/sub

**优缺点：**

- 优点：

  - 读写性能高

  - 支持持久化，RDB & AOF

  - 数据类型丰富，五种：string, list, set, sorted-set, hash

  - 支持简单事务

  - 支持TTL

  - 支持主从复制，可以进行读写分离


- 缺点：

  - 数据库容量受限物理内存（低于物理内存的60%），不能支持海量数据的高性能读写。

  - 不具备自动容错和恢复功能

  - 主节点宕机，可能会有部分数据未及时同步到从节点，导致数据不一致
  
  
    - 很难在线扩容，一般在系统上线前必须保有足够的空间
  
  
  
    - buffer io造成系统OOM
  



## 1.2 安装

```bash
# 1. 编译工具
apt install build-essential libssl-dev pkg-config -y

# 2. 获取软件包
wget https://download.redis.io/releases/redis-6.2.5.tar.gz
tar zxvf redis-6.2.5.tar.gz

# 3. 支撑包编译
cd redis-6.2.5/deps
make lua hiredis linenoise hdr_histogram

# 4. 编译安装
cd ..
make MALLOC=libc BUILD_TLS=yes
make install

# 5. 相关目录创建
mkdir -p /etc/redis
mkdir -p /var/lib/redis
mkdir -p /var/log/redis
mkdir -p /var/run/redis

# 6. 配置文件
cp redis.conf /etc/redis

vi /etc/redis/redis.conf
daemonize yes
logfile /var/log/redis/redis.log
dir /var/lib/redis/

# 7. 开机启动
cat > /lib/systemd/system/redis.service <<EOF
[Unit]
Description=Redis data structure server
Documentation=https://redis.io/documentation

[Service]
Type=forking
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
ExecReload=/bin/kill -s HUP \$MAINPID
PrivateTmp=true
RestartSec=10
LimitCORE=infinity
LimitNOFILE=10032
LimitNPROC=10032
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start redis
systemctl status redis
systemctl enable redis
```



## 1.3 性能测试

```bash
# 100个并发，100000次
redis-benchmark -h localhost -p 6379 -c 100 -n 100000
```



# 2. 数据类型

- string：字符串操作、原子计数器等

- hash：以hashmap方式存储，可用来存储json对象。

- list：消息队列，timeline等

- set：Unique去重操作。统计独立IP，好友推荐去重等

- sorted-set：排行榜，TOP N操作，带权重



## 2.1 String

数据结构：简单动态字符串 (Simple Dynamic String, SDS)，内部结构类似Golang的Slice，采用预先分配冗余空间方式来减少内存的频繁分配。

扩容机制：长度小于1M，翻倍扩容；超过1M，每次扩容1M。最大512M

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-string-sds.png)

```bash
get KEY

set KEY VALUE
setex KEY 10 VALUE

append KEY VALUE
strlen KEY

setnx KEY VALUE  # 不存在才设置

# 原子性操作
incr KEY
decr KEY
incrby KEY 5
decrby KEY 3

mset k1 v1 k2 v2 ...
mget k1 k2 ...
```



## 2.2 List

数据结构：ziplist | quicklist

- 数据量较少时，使用一块连续的内存存储，结构为ziplist，即压缩列表。
- 数据量较大时，会改成quickList，即快速链表，结构上有额外的指针prev 和 next

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-list-quicklist.png)

**Redis 将链表和ziplist 集合起来组成quicklist，即满了快速插入删除性能，又不会出现太大的冗余空间**。

```bash
lpush KEY e1 e2 ...
rpush KEY e1 e2 ...

lpop KEY
rpop KEY

rpoplpush KEY1 KEY2   # KEY1列表右吐出一个附加到KEY左边

lrange KEY 0 -1

lindex KEY 2

llen KEY

linsert KEY before pivot element
linsert KEY after pivot element

lrem KEY count element  # 从左边删除count个elment元素

lset KEY index element  # 替换
```



## 2.3 Set

数据结构：无序集合，底层是一个value为null的hash表，所以添加、删除和查找的时间复杂度都是o(1)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-set-hashtable.png)

```bash
sadd KEY member...

smembers KEY
sismember KEY member

scard KEY   # 

srem KEY member...
spop KEY   # 随机取出一个值
srandmember KEY count  # 随机取出多个值，注意：不删除

smove source destination member  # 将source中的member移动到destination

sinter k1 k2  # 交集
sunion k1 k2  # 并集
sdiff  k1 k2  # 差集 
```



## 2.4 Hash

数据结构：ziplist | hashtable。当field-value长度短且个数少时，使用ziplist，否则使用hashtable

```bash
hset k f1 v1 f2 v2  # hmset 效果一样
hget k f1
hmget k f1 f2 f3

hexists k f1

hkeys k
kvals k

hincrby k age 5

hsetnx k addr LA  # 不存在时才添加
```



## 2.5 ZSet

数据结构：hashtable + skiplist

- hash：关联member和score，保证member的唯一性，可直接通过member找到相应的score值
- skiplist：根据score值，为member排序。它是一种可以进行二分查找的有序链表

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-zset.png)

```bash
zadd k 100 java 200 cpp 300 golang 400 python 500 php

zrange k 0 -1  # 按score从小到大排序

zrangebyscore k 200 400
zrevrangebyscore k 200 400

zincrby k 200 golang

zrem k php cpp

zcount k 100 300

zrank k golang   # 排名
```



## 2.6 总结

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-basic-structure.png)

- String：如果存储数字的话，是用int类型的编码；如果存储非数字，小于等于39字节的字符串，是embstr；大于39个字节，则是raw编码。
- List：如果列表的元素个数小于512个，列表每个元素的值都小于64字节(默认)，使用ziplist编码；否则使用linkedlist编码
- Hash：哈希类型元素个数小于512个，所有值小于64字节的话，使用ziplist编码；否则使用hashtable编码。
- Set：如果集合中的元素都是整数且元素个数小于512个，使用intset编码；否则使用hashtable编码。
- Zset：当有序集合的元素个数小于128个，每个元素的值小于64字节时，使用ziplist编码；否则使用skiplist编码



### 2.6.1 hashtable

哈希表：由**数组 + 链表**构成的二维数据结构，数组是第一维，链表是第二维。数组中的每个元素称为槽或者桶，存储着链表的第一个元素的指针。

整体结构图：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-hashtable-overall.png)

一维数组：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-hashtable.png)

二维链表：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-hashtable-linkedlist.png)

扩容和缩容：

- 扩容：元素个数等于一维数组长度时，会对数组进行两倍扩容
- 缩容：元素个数小于一维数组的10%

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-hashtable-rehash.png)

扩缩容时，需要重新申请一维数组，并对所有元素重新hash并挂载到元素链表。Redis采用**rehash策略：所有的字典结构内部首层时一个数组，数组的两个元素分别指向一个hashtable，正常情况下只有一个hashtable，而在迁移过程中，保留新旧两个hashtable，元素可能会在两个表中任意一个中，因此同时尝试从两个hashtable中查找数据。当数据搬迁完毕，旧的hashtable会被自动删除**。

**哈希函数：**将key值打散的越均匀越好，高随机性的元素分布能够提升整体的查找效率。**Redis的hash函数为siphash**。hash函数打散效率如果很差或有迹可循，就会存在hash攻击，攻击者利用模式偏向性产生大量数据，并将这些数据挂载在同一个链表上，这种不均匀会导致查找性能急剧下降，同时浪费大量内存空间，导致Redis性能低下



### 2.6.2 skiplist

跳跃表：**在链表的基础上，增加索引，以提高查找效率**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-skiplist-overall.png)

- 每一层都有一条有序的链表，最底层的链表包含了所有的元素。
- 跳跃表支持平均 O（logN）,最坏 O（N）复杂度的节点查找，还可以通过顺序性操作批量处理节点。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-zset-skiplist-insert.png)

根据score值插入紫色kv节点，首先从 kv-head 的最高层启动，判断指针的下一个元素的score值是否小于新元素的score，小于则继续向前遍历，否则从kv-head降一层，重新比较



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-zset-skiplist-search.png)

寻找51：

- 从第2层开始，1节点比51小，向后比较、
- 21节点比51小，继续向后，但后面是NULL，则从21节点下降到第1层
- 41节点比51小，继续向后，61节点比51大，则从41节点下降到第0层
- 51节点即为所要查找的节点，共查找了四次



### 2.6.3 ziplist

压缩列表：由一系列特殊编码的内存块构成的列表， 一个ziplist可以包含多个entry， 每个entry可以保存一个长度受限的字符数组或者整数。由于内存是**连续分配**的，所以遍历速度很快。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-ziplist.png)

- zlbytes ：记录整个压缩列表占用的内存字节数
- zltail: 尾节点至起始节点的偏移量
- zllen : 记录整个压缩列表包含的节点数量
- entryX: 压缩列表包含的各个节点
- zlend : 特殊值0xFF(十进制255)，用于标记压缩列表末端





# 3. 发布订阅

```bash
# 1. 订阅消息
SUBSCRIBE mychannel
UNSUBSCRIBE mychannel

# 2. 发布消息
PUBLISH mychannel hello

# 3. 模式匹配订阅
PSUBSCRIBE news:*
PUNSUBSCRIBE news:*

# 4. 查看订阅与发布系统状态
PUBSUB CHANNELS
```



# 4. 新类型

## 4.1 Bitmaps

Bitmaps本身不是数据类型，实际它就是字符串，但可可以对字符串的位进行操作

**注意**：初始化bitmaps时，如果offset过大，整个初始化过程会较慢，可能会造成redis的阻塞

```bash
setbit key offset value
gitbit key offset
bitcount key [start end]
bitop operation destkey key [key ...]
```

示例：

```bash
127.0.0.1:6379> setbit k1 2 1
(integer) 0
127.0.0.1:6379> setbit k1 3 1
(integer) 0
127.0.0.1:6379> setbit k1 4 1
(integer) 0
127.0.0.1:6379> setbit k1 5 1
(integer) 0

127.0.0.1:6379> setbit k2 0 1
(integer) 0
127.0.0.1:6379> setbit k2 1 1
(integer) 0
127.0.0.1:6379> setbit k2 2 1
(integer) 0
127.0.0.1:6379> setbit k2 3 1
(integer) 0

127.0.0.1:6379> bitop and k3 k1 k2
(integer) 1
127.0.0.1:6379> bitcount k3
(integer) 2

127.0.0.1:6379> bitop or k4 k1 k2
(integer) 1
127.0.0.1:6379> bitcount k4
(integer) 6

127.0.0.1:6379> bitop xor k5 k1 k2
(integer) 1
127.0.0.1:6379> bitcount k5
(integer) 4

127.0.0.1:6379> bitop not k6 k1
(integer) 1
127.0.0.1:6379> bitcount k6
(integer) 4
127.0.0.1:6379> getbit k6 1
(integer) 1
127.0.0.1:6379> getbit k6 2
(integer) 0
```



## 4.2 HyperLogLog

网站统计PV(PageView): 可使用 incr, incrby实现

独立访客UV(UniqueVistor)、独立IP、搜索记录数等需要去重和计数的问题。

**HyperLogLog 用来做基数统计，其优点在，输入元素的数量或者体积非常大时，计算基数需要的空间是固定的，并且很小**。

每个 HyperLogLog 键只需要花费 12KB内存，就可以计算接近 2^64个不同元素的基数。

HyperLogLog 只会根据输入的元素来计算基数，但不会存储输入元素，所以它不能像集合一样，返回输入的各个元素。

```bash
PFADD key element [element ...]
PFCOUNT key [key ...]
PFMERGE destkey sourcekey [sourcekey ...]
```

示例：

```bash
127.0.0.1:6379> pfadd nosql redis mongodb memcached
(integer) 1
127.0.0.1:6379> pfadd rdbms mysql oracle mssql
(integer) 1
127.0.0.1:6379> pfmerge dbs nosql rdbms
OK
127.0.0.1:6379> pfcount dbs
(integer) 6
```



## 4.3 Geospatial

Geospatial 是一个2维坐标，即经纬度。

```bash
GEOADD key longitude latitude member [longitude latitude member ...]
GEOPOS key member [member ...]
GEODIST key member1 member2 [unit]   # unit: m, km, mi, ft
GEORADIUS key longitude latitude radius m|km|ft|mi [WITHCOORD] [WITHDIST] [WITHHASH] [ASC|DESC] [COUNT count]
GEORADIUSBYMEMBER key member radius m|km|ft|mi [WITHCOORD] [WITHDIST] [WITHHASH] [ASC|DESC] [COUNT count]
GEOHASH key member [member ...]
```

示例：

```bash
127.0.0.1:6379> geoadd cities 121.47 31.23 Shanghai
(integer) 1
127.0.0.1:6379> geoadd cities 106.50 29.53 Chongqing
(integer) 1
127.0.0.1:6379> geoadd cities 114.05 22.52 Shenzhen
(integer) 1

127.0.0.1:6379> geopos cities Shanghai
1) 1) "121.47000163793563843"
   2) "31.22999903975783553"
   
127.0.0.1:6379> geodist cities Shanghai Chongqing km
"1447.6737"

127.0.0.1:6379> georadius cities 110 30 1000 km
1) "Chongqing"
2) "Shenzhen"
```



# 5. 命令补充

## 5.1 数据库

```bash
SELECT db
FLUSHDB
FLUSHALL
SWAPDB db1 db2

EXISTS key
TYPE key
RENAME key newkey
RENAMENX key newkey
MOVE key db
DEL key [key ...]
UNLINK key  # 非阻塞删除

RANDOMKEY
DBSIZE   # 当前数据库的 key 的数量

KEYS pattern
```



## 5.2 自动过期

```bash
EXPIRE key seconds
EXPIREAT key timestamp
TTL key  # 过期剩余时间 -1：永不过期 -2: 已过期
PERSIST key

PEXPIRE key milliseconds
PEXPIREAT key milliseconds-timestamp
PTTL key
```



**过期策略**:

- 定时过期：过期立即删除。对内存友好，但会占用大量CPU资源去处理过期的键，影响缓存的响应时间和吞吐量
- 惰性过期：只有当访问一个key时，才会判断它是否过期，过期则清除。对内存不友好，无用key占用了大量内存。
- 定期过期：每隔一定时间，扫描一定数量的数据库的expires字典中一定数量的key，并清除其中已过期的key。

Redis 同时使用 **惰性过期** 和 **定期过期** 两种策略：**即在访问key时判断是否过期，如果过期，则进行过期处理。其次，每秒对volation keys进行抽样测试，如果有过期键，那对所有过期key处理**。



## 5.3 scan

```bash
SCAN cursor [MATCH pattern] [COUNT count]      # 用于迭代当前数据库中的数据库键，优于KEYS
SSCAN key cursor [MATCH pattern] [COUNT count] # 用于迭代集合键中的元素，优于SMEMBERS命令
HSCAN key cursor [MATCH pattern] [COUNT count] # 用于迭代哈希键中的键值对
ZSCAN key cursor [MATCH pattern] [COUNT count] # 用于迭代有序集合中的元素(包括元素成员和元素分值)
```

**keys & scan 对比**：

- keys: 复杂度 O(N)，没有offset, limit 参数，海量key时，会导致redis服务不可用
- scan: 复杂度 O(N)，但它通过游标分步进行，不阻塞线程

**示例**：

```bash
127.0.0.1:6379> mset k1 v1 k2 v2 k3 v3 k11 v11 k22 v22 k111 v111
OK

127.0.0.1:6379> scan 0 match k1* count 2
1) "1"
2) 1) "k111"
   2) "k1"
   
127.0.0.1:6379> scan 1 match k1* count 2
1) "3"
2) 1) "k11"

127.0.0.1:6379> scan 3 match k1* count 2
1) "0"
2) (empty array)
```



## 5.4 sort

```bash
SORT key [BY pattern] [LIMIT offset count] [GET pattern [GET pattern ...]] [ASC | DESC] [ALPHA] [STORE destination]
```

**示例：**

```bash
# 默认数值排序
127.0.0.1:6379> lpush cost 1.2 0.9 2.5 1.4
(integer) 4
127.0.0.1:6379> sort cost
1) "0.9"
2) "1.2"
3) "1.4"
4) "2.5"
127.0.0.1:6379> sort cost desc
1) "2.5"
2) "1.4"
3) "1.2"
4) "0.9"

# 字符排序
127.0.0.1:6379> lpush lang java python golang clang rust
(integer) 5
127.0.0.1:6379> sort lang
(error) ERR One or more scores can't be converted into double
127.0.0.1:6379> sort lang ALPHA
1) "clang"
2) "golang"
3) "java"
4) "python"
5) "rust"

# LIMIT 限定返回结果
127.0.0.1:6379> rpush level 9 1 5 3 2 4 6 8 7
(integer) 9
127.0.0.1:6379> sort level LIMIT 0 5
1) "1"
2) "2"
3) "3"
4) "4"
5) "5"

# 使用外部 key 排序
127.0.0.1:6379> lpush uid 1 2 3 4
(integer) 4
127.0.0.1:6379> mset level:1 8 level:2 5 level:3 7 level:4 1
OK
127.0.0.1:6379> sort uid BY level:*
1) "4"
2) "2"
3) "3"
4) "1"

# 组合使用 BY 和 GET
127.0.0.1:6379> mset name:1 tom name:2 jack name:3 lily name:4 sara
OK
127.0.0.1:6379> sort uid BY level:* GET name:*
1) "sara"
2) "jack"
3) "lily"
4) "tom"

# 将hash作为 GET 和 BY 参数
127.0.0.1:6379> hmset info:1 name tom age 21
OK
127.0.0.1:6379> hmset info:2 name lucy age 19
OK
127.0.0.1:6379> hmset info:3 name joe age 22
OK
127.0.0.1:6379> hmset info:4 name kent age 20
OK
127.0.0.1:6379> sort uid BY info:*->age
1) "2"
2) "4"
3) "1"
4) "3"
127.0.0.1:6379> sort uid BY info:*->age GET info:*->name
1) "lucy"
2) "kent"
3) "tom"
4) "joe"

# 保存排序结果
127.0.0.1:6379> lrange rank 0 -1
1) "9"
2) "1"
3) "5"
4) "3"
5) "2"
6) "4"
7) "6"
8) "8"
9) "7"
127.0.0.1:6379> sort rank STORE sorted-rank
(integer) 9
127.0.0.1:6379> lrange sorted-rank 0 -1
1) "1"
2) "2"
3) "3"
4) "4"
5) "5"
6) "6"
7) "7"
8) "8"
9) "9"
```



## 5.5 配置选项

```bash
CONFIG SET parameter value
CONFIG GET parameter
CONFIG RESETSTAT      # 重置INFO命令的统计信息
CONFIG REWRITE        # 重写redis.conf，在配置文件中不存在的项，不会被写入
```

示例：

```bash
127.0.0.1:6379> config get slowlog-max-len
1) "slowlog-max-len"
2) "128"

127.0.0.1:6379> config set slowlog-max-len 1024
OK

127.0.0.1:6379> config get slowlog-max-len
1) "slowlog-max-len"
2) "1024"

127.0.0.1:6379> config get sa*
1) "sanitize-dump-payload"
2) "no"
3) "save"
4) "3600 1 300 100 60 10000"
```



## 5.6 客户端和服务器

```bash
AUTH password
INFO [section]
SHUTDOWN [SAVE|NOSAVE]
TIME     # Unix TS, milliseconds

CLIENT GETNAME
CLIENT KILL ip:port
CLIENT LIST
CLIENT SETNAME connection-name
```

密码认证：

```bash
$ redis-cli
127.0.0.1:6379> CONFIG SET requirepass 123456
OK
127.0.0.1:6379> quit

$ redis-cli
127.0.0.1:6379> ping
(error) NOAUTH Authentication required.
127.0.0.1:6379> auth 123456
OK
127.0.0.1:6379> CONFIG SET requirepass ""
OK
127.0.0.1:6379> quit
```

客户端信息：

```bash
127.0.0.1:6379> client getname
(nil)
127.0.0.1:6379> client setname just-a-test
OK
127.0.0.1:6379> client getname
"just-a-test"

127.0.0.1:6379> client list
id=4 addr=127.0.0.1:41090 laddr=127.0.0.1:6379 fd=9 name= age=792 idle=789 flags=N db=0 sub=0 psub=0 multi=-1 qbuf=0 qbuf-free=0 argv-mem=0 obl=0 oll=0 omem=0 tot-mem=17032 events=r cmd=info user=default redir=-1
id=6 addr=127.0.0.1:41094 laddr=127.0.0.1:6379 fd=8 name=just-a-test age=110 idle=0 flags=N db=0 sub=0 psub=0 multi=-1 qbuf=26 qbuf-free=32744 argv-mem=10 obl=0 oll=0 omem=0 tot-mem=49794 events=r cmd=client user=default redir=-1

127.0.0.1:6379> client kill 127.0.0.1:41090
OK
127.0.0.1:6379> client list
id=6 addr=127.0.0.1:41094 laddr=127.0.0.1:6379 fd=8 name=just-a-test age=232 idle=0 flags=N db=0 sub=0 psub=0 multi=-1 qbuf=26 qbuf-free=32744 argv-mem=10 obl=0 oll=0 omem=0 tot-mem=49794 events=r cmd=client user=default redir=-1
```



## 5.7 调试

```bash
# 用于测试与服务器的连接是否仍然生效，或者用于测量延迟值
PING       
ECHO message

# 允许从内部察看给定key的Redis对象，它通常用在除错(debugging)或者了解为了节省空间而对key使用特殊编码的情况
OBJECT subcommand [arguments [arguments]]
OBJECT REFCOUNT <key>    # key引用所储存的值的次数，主要用于除错。
OBJECT ENCODING <key>    # key 锁储存的值所使用的内部表示(representation)。
OBJECT IDLETIME <key>    # key 自储存以来的空闲时间(idle， 没有被读取也没有被写入)，以秒为单位

# 执行一个查询命令所耗费的时间，不包括像客户端响应(talking)、发送回复等IO操作
SLOWLOG subcommand [argument]

# 实时打印出 Redis 服务器接收到的命令
MONITOR

# 获取key对象详细信息
DEBUG OBJECT key

# 执行一个不合法的内存访问让Redis崩溃，用于开发时模拟BUG
DEBUG SEGFAULT   
```

示例：

```bash
# 对象观察
127.0.0.1:6379> set name admin
OK
127.0.0.1:6379> object refcount name
(integer) 1
127.0.0.1:6379> object idletime name
(integer) 20
127.0.0.1:6379> object encoding name
"embstr"
127.0.0.1:6379> set small-number 128
OK
127.0.0.1:6379> object encoding small-number
"int"
127.0.0.1:6379> set big-number 23102930128301091820391092019203810281029831092
OK
127.0.0.1:6379> object encoding big-number
"raw"

# slow log
CONFIG SET slowlog-log-slower-than 100  # 查询时间大于等于100ms
CONFIG SET slowlog-max-len 1000         # 最多保留1000条

127.0.0.1:6379> CONFIG SET slowlog-log-slower-than 1
OK
127.0.0.1:6379> SLOWLOG GET
1) 1) (integer) 0
   2) (integer) 1644285401
   3) (integer) 7
   4) 1) "CONFIG"
      2) "SET"
      3) "slowlog-log-slower-than"
      4) "1"
   5) "127.0.0.1:50200"
   6) ""
127.0.0.1:6379> slowlog len
(integer) 2
   
# monitor
127.0.0.1:6379> monitor
OK
1644285538.880115 [0 127.0.0.1:50202] "COMMAND"
1644285546.854069 [0 127.0.0.1:50202] "keys" "*"
1644285551.079207 [0 127.0.0.1:50202] "get" "name"
1644285560.006910 [0 127.0.0.1:50202] "ping"

# debug
127.0.0.1:6379> debug object name
Value at:0x564e14e412c0 refcount:1 encoding:embstr serializedlength:6 lru:118383 lru_seconds_idle:120
```



## 5.8 内部命令

**MIGRATE**：将 key原子性地从当前实例传送到目标实例的指定数据库上，一旦传送成功， key保证会出现在目标实例上，而当前实例上的key会被删除。

内部实现：它在当前实例对给定 `key` 执行 `DUMP` 命令 ，将它序列化，然后传送到目标实例，目标实例再使用 `RESTORE` 对数据进行反序列化，并将反序列化所得的数据添加到数据库中；当前实例就像目标实例的客户端那样，只要看到 `RESTORE` 命令返回 `OK` ，它就会调用 `DEL` 删除自己数据库上的 `key` 

```bash
MIGRATE host port key destination-db timeout [COPY] [REPLACE]

# 1. 启动另一个redis实例
redis-server --port 7777 &

# 2. 执行迁移操作
$ redis-cli
127.0.0.1:6379> set greeting "hello from 6379 instance"
OK
127.0.0.1:6379> migrate 127.0.0.1 7777 greeting 0 1000 COPY
OK
127.0.0.1:6379> exists greeting
(integer) 1
127.0.0.1:6379> migrate 127.0.0.1 7777 greeting 0 1000 REPLACE
OK
127.0.0.1:6379> exists greeting
(integer) 0

# 3. 实例 7777 上查询
$ redis-cli -p 7777
127.0.0.1:7777> exists greeting
(integer) 1
127.0.0.1:7777> get greeting
"hello from 6379 instance"
```



**DUMP & RESTORE**: 序列化和反序列化

```bash
DUMP key
RESTORE key ttl serialized-value [REPLACE]

127.0.0.1:6379> set greeting "hello, dumping world!"
OK
127.0.0.1:6379> dump greeting
"\x00\x15hello, dumping world!\t\x00\x03\xbfc\xcey\xa1\x9e\xfc"

127.0.0.1:6379> restore greeting-copy 0 "\x00\x15hello, dumping world!\t\x00\x03\xbfc\xcey\xa1\x9e\xfc"
OK
127.0.0.1:6379> get greeting-copy
"hello, dumping world!"
```



**SYNC & PSYNC**: 用于复制功能(replication)



# 6. 事务和锁

## 6.1 事务

Redis事务：是一个单独的隔离操作。事务中所有命令都会序列化，按顺序执行；在执行过程中，不会被其他客户端发送的命令请求打断。

作用：串行执行多个命令，防止其他命令插队

Redis事务特性：


- 单独的隔离操作，一次性、顺序性、排他性的执行一个队列中的一系列命令
- 没有隔离级别
- 不保证原子性

```bash
MULTI      # 标记一个事务块的开始
EXEC       # 执行所有事务块内的命令
DISCARD    # 取消事务，放弃执行事务块内的所有命令, 如果正在 WATCH 某个/些 key，那将取消WATCH，即UNWATCH
WATCH key [key ...]  # 监视一个(或多个) key ，如果在事务执行之前这个(或这些) key 被其他命令所改动，那么事务将被打断。
UNWATCH    # 取消 WATCH 命令对所有 key 的监视

```




Queued失败，无法执行：一般只在语法错误时出现

```bash
127.0.0.1:6379> multi
OK
127.0.0.1:6379(TX)> set k1 v1
QUEUED
127.0.0.1:6379(TX)> ping
QUEUED
127.0.0.1:6379(TX)> incr
(error) ERR wrong number of arguments for 'incr' command
127.0.0.1:6379(TX)> exec
(error) EXECABORT Transaction discarded because of previous errors.
127.0.0.1:6379> keys *
(empty array)
```



Queued成功，正常执行，跳过失败命令：

```bash
127.0.0.1:6379> multi
OK
127.0.0.1:6379(TX)> set k1 v1
QUEUED
127.0.0.1:6379(TX)> incr k1
QUEUED
127.0.0.1:6379(TX)> ping
QUEUED
127.0.0.1:6379(TX)> exec
1) OK
2) (error) ERR value is not an integer or out of range
3) PONG
127.0.0.1:6379> get k1
"v1"
```



Watch:

```bash
127.0.0.1:6379> mset lock_by admin lock_times 0
OK
127.0.0.1:6379> watch lock_by lock_times
OK
127.0.0.1:6379> multi
OK
127.0.0.1:6379(TX)> set lock_by daniel
QUEUED
127.0.0.1:6379(TX)> incr lock_times      # 在其他客户端执行“incrby lock_times 5”，导致本次事务不成功
QUEUED
127.0.0.1:6379(TX)> exec
(nil)
127.0.0.1:6379> mget lock_by lock_times
1) "admin"
2) "5"
```



## 6.2 锁

- **悲观锁**：每次操作，都上锁，别人不能操作，等我释放锁后，才能操作。MySQL中的行锁、表锁；读锁、写锁即为该类锁。
- **乐观锁**：使用版本机制，在操作前，所有人均能获得当前的版本，在提交操作时，比对用户用户操作的版本是否和当前系统中的版本一致，只有在一致的情况下，操作才能成功，并生成新的版本号。乐观锁适用于多读的的应用类型，这样可提高吞吐量。

Redis使用乐观锁，CAS: check-and-set 机制实现事务。

```bash
> set balance 10000

# session 1
> WATCH balance
> MULTI
> decrby balance 2000
> EXEC                 # 事务失败
> UNWATCH

# session 2
> decrby blanace 5000  # 在 session 1的 WATCH后，EXEC前操作
```



# 7. Lua 脚本

## 7.1 概述

Lua脚本，很容易被 C/C++调用，也可反过来调用C/C++函数。解释器不超过200k，适合做嵌入式脚本语言。

Redis 的乐观锁，在多写的情况下，复杂的事务操作提交失败，导致与预想不一致的情况发生。此时可将复杂、多步调用操作，写为一个Lua脚本，一次提交给Redis执行，减少连接Redis的次数，提升性能。

**Lua 脚本的优点**：

- **减少网络开销**：可以将多个请求通过脚本的形式一次发送，减少网络时延。
- **原子操作**：Redis会将整个脚本作为一个整体执行，中间不会被其他请求插入。因此在脚本运行过程中无需担心会出现竞态条件，无需使用事务。
- **可复用**：客户端发送的脚本会永久存在redis中，这样其他客户端可以复用这一脚本，而不需要使用代码完成相同的逻辑。



## 7.2 相关命令

```bash
EVAL script numkeys key [key ...] arg [arg ...]

# 不执行脚本，将其存储在服务器脚本缓存中，返回脚本的SHA1校验值
SCRIPT LOAD script

# 通过脚本的SHA1校验值来执行脚本
EVALSHA sha1 numkeys key [key ...] arg [arg ...]

# 通过脚本的SHA1校验值，检测脚本是否存在
SCRIPT EXISTS sha1 [sha1 ...]

# 清空服务器所有的脚本缓存
SCRIPT FLUSH 

# 强制终止正在运行的脚本，"当且仅当这个脚本没有执行过任何写操作时，这个命令才生效"。 它的主要用于终止运行时间过长的脚本，比如一个因为 BUG 而发生无限 loop 的脚本等。当脚本执行过写操作，无法被终止，因为它违法了Lua脚本的原子性执行原则，此时唯一可行的办法是使用SHUTDOWN NOSAVE命令，通过停止整个Redis来终止，并防止不完整(half-write)的信息被写入数据库
SCRIPT KILL
```



**参数处理：**

```bash
127.0.0.1:6379> eval "return KEYS[1]" 2 k1 k2
"k1"

127.0.0.1:6379> eval "return ARGV[2]" 0 v1 v2
"v2"

127.0.0.1:6379> eval "return {KEYS[1],KEYS[2],ARGV[1],ARGV[2]}" 2 k1 k2 v1 v2
1) "k1"
2) "k2"
3) "v1"
4) "v2"
```



**执行redis命令**：

- `redis.call()`: 在执行命令的过程中发生错误时，脚本会停止执行，并返回一个脚本错误
- `redis.pcall()`：出错时并不引发(raise)错误，而是返回一个带 `err` 域的 Lua 表(table)，用于表示错误

```bash
127.0.0.1:6379> eval "return redis.call('set', 'k1', 'v1')" 0
OK
127.0.0.1:6379> get k1
"v1"
127.0.0.1:6379> eval "return redis.call('get', KEYS[1])" 1 k1
"v1"

# 设置值和过期时间
127.0.0.1:6379> eval "redis.call('set', KEYS[1], ARGV[1]); redis.call('expire', KEYS[1], ARGV[2]); return 1" 1 name jack 15
(integer) 1
127.0.0.1:6379> get name
"jack"
127.0.0.1:6379> ttl name
(integer) 11

# redis.pcall 忽略错误
127.0.0.1:6379> lpush queue 1 2 3
(integer) 3
127.0.0.1:6379> type queue
list
127.0.0.1:6379> eval "redis.call('get', 'queue')" 0
(error) ERR Error running script (call to f_e5becba52dbf557c9a67e5d618be2cd3ccc70ea1): @user_script:1: WRONGTYPE Operation against a key holding the wrong kind of value
127.0.0.1:6379> eval "redis.pcall('get', 'queue')" 0
(nil)
```



**脚本相关操作：**

```bash
# 导入脚本
127.0.0.1:6379> script load "redis.call('set', KEYS[1], ARGV[1]); redis.call('expire', KEYS[1], ARGV[2]); return 1"
"cecc687421671f6065277c7801e02f5125d444f9"
127.0.0.1:6379> evalsha cecc687421671f6065277c7801e02f5125d444f9 1 name john 30
(integer) 1
127.0.0.1:6379> get name
"john"
127.0.0.1:6379> ttl name
(integer) 21

# 存在判断
127.0.0.1:6379> script exists cecc687421671f6065277c7801e02f5125d444f9
1) (integer) 1
127.0.0.1:6379> script exists cecc687421671f6065277c7801e02f5125d444f0
1) (integer) 0

# 清空脚本
127.0.0.1:6379> script flush
```



## 7.3 实例

### 7.3.1 CompareAndSet

```lua
local key = KEYS[1]
local oldVal = redis.call("GET", key)

if oldVal == ARGV[1]
then
    redis.call('SET', KEYS[1], ARGV[2])
    return 1
else
    return 0
end
```

执行：

```bash
127.0.0.1:6379> set name jack
OK

# 注意：通过"," 来分割 keys 和 values，且","前后必须加空格
redis-cli --eval ./redis_cas.lua name , tom sara
(integer) 0

redis-cli --eval ./redis_cas.lua name , jack sara
(integer) 1
```



### 7.3.2 IP 访问频率控制

```lua
local visitCount = redis.call('incr', KEYS[1])

if visitCount == 1 then
    redis.call('expire', KEYS[1], ARGV[1])
end

if visitCount > tonumber(ARGV[2]) then
    return 0
end

return 1
```

执行：

```bash
redis-cli --eval ./redis_LimitIPVisit.lua ip:192.168.1.10 , 10 3
(integer) 1

redis-cli --eval ./redis_LimitIPVisit.lua ip:192.168.1.10 , 10 3
(integer) 1

redis-cli --eval ./redis_LimitIPVisit.lua ip:192.168.1.10 , 10 3
(integer) 1

redis-cli --eval ./redis_LimitIPVisit.lua ip:192.168.1.10 , 10 3
(integer) 0

redis-cli --eval ./redis_LimitIPVisit.lua ip:192.168.1.10 , 10 3
(integer) 0
```










# 8. 持久化

## 8.1 RDB (Redis Database)

- 将数据以快照(snapshot)形式保存在磁盘上 (dump.db)

- 触发快照的三种机制：

  - save: 手动持久化，将阻塞服务器，save期间，不能处理其他命令，直到持久化完毕

  - bgsave: 后台异步进行快照操作。它会fork一个子进程负责处理

  - 自动触发：

```text
 save 3600 1     # 1h内，至少有一个key变化，触发持久化
 save 300 10
 save 60 10000

 stop-writes-on-bgsave-error yes
 rdbcompression yes
 rdbchecksum yes
 dbfilename dump.db
 dir /var/lib/redis/
```

快照保存过程：

- redis调用fork，产生一个子进程
- 父进程继续处理client请求，子进程负责将fork时刻整个内存数据库快照写入临时文件。
- 子进程完成写入临时文件后，用临时文件替换原来的快照文件，然后子进程退出。

​         问题：每次快照持久化都是将内存数据完整写入到磁盘，如果数据量较大，读写操作较多，必然会引起磁盘IO问题。

**优势:**

- RDB文件紧凑，全量备份，适合用于进行备份和灾难恢复
- 生成RDB时，Redis主进程fork一个子进程来处理保存工作，主进程不需要进行任何磁盘IO操作
- RDB恢复比AOF快

**劣势：**RDB数据保存子进程可能来不及保存数据，导致数据丢失



## 8.2 AOF (append only file)

- 以日志形式记录每个**写操作(增量保存)**，追加写，不修改原有记录
- aof的问题：文件会越来越大。可通过**bgrewriteaof**命令，fork一个子进程来重写aof文件。
- AOF和RDB同时开启，系统默认取AOF的数据

```ini
appendonly yes
appendfilename "appendonly.aof"

# 三选一
appendsync always
appendsync everysec
appendsync no # 完全依赖操作系统，性能最好，但持久化可能丢数据

# 自动bgrewriteaof
auto-aof-rewrite-percentage 100  # 大于64M到100%，即超过128M时开始重写
auto-aof-rewrite-size 64mb
```

**优势：**  

- 数据不容易丢失
- 日志文件过大时，后台会自动重写，不会影响客户端读写
- 日志文件以命令可读方式记录，容易查找命令记录来恢复数据

**劣势：**

- AOF日志文件比RDB文件大
- AOF开启后，写的QPS会降低



## 8.3 方案选择

Snapchat性能更高，但可能会引起一定程度的数据丢失

建议：

- 更新频繁，一致性要求较高，AOF策略为主
- 更新不频繁，可以容忍少量数据丢失或错误，Snapshot为主



## 8.4 AOF 文件修复

修复步骤：

- 先创建 AOF 文件备份
- 执行修复操作：`redis-check-aof --fix`
- 比较修复前后的文件：`diff -u`
- 重启Redis服务，等待服务载入修复好的文件，进行数据恢复



# 9. 集群方案

## 9.1 主从模式

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-master-slave.png)

主从同步特点:

- 一个master可拥有多个slave
- master可读写，并将变化的数据sync给slave
- slave只读，接收master的sync数据
- 缺点：master只有一个，如果挂掉，无法对外提供写服务

配置 salve:

```ini
replicaof 192.168.1.200 6379
masterauth <master-password>
```

```bash
redis-cli
> info
> monitor
> info replication  # 查看集群状态
```



## 8.2 Sentinel

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-sentinel.png)

- 哨兵模式建立在主从模式之上

- 当master挂掉，sentinel会在salve中选择一个作为master，并修改它们的配置文件，其他slave节点的配置文件也会同步修改

- 当master恢复后，它将不再是master，而是做为slave接收新master同步数据

- 多sentinel配置时，形成一个sentinel小集群，sentinel之间也会自动监控

配置：

```ini
sentinel monitor mymaster 192.168.1.200 6379
sentinel auth-pass mymaster 123456
sentinel down-after-milliseconds mymaster 30000  # 默认30s
```

启动：

```bash
/usr/local/bin/redis-sentinel /usr/local/reids/sentinel.conf
```



## 9.3 Cluster

集群节点责任：

- 持有键值对数据
- 记录集群状态，包括键到正确节点的映射(mapping keys to right nodes)
- 自动发现其他节点，识别不正常的节点，并在有需要时，在从节点中选举出新的主节点

节点之间使用**Gossip协议**通信：

- 传播(propagate) 关于集群的信息，以此来发现新的节点
- 向其他节点发送 PING 数据包，以此来检查目标节点是否正常工作
- 在特定事件发生时，发送集群信息

键分布模型：

- Redis集群的键空间被分割为 16348 个槽(slot)，集群的最大节点数量也是16348个，推荐1000个左右。
- 每个节点都负责处理 16384 个哈希槽的其中一部分。当集群处于稳定(stable)状态时，即集群没有执行重配置(reconfiguration)操作，每个哈希槽都由一个节点进行处理
- 键分布到槽的算法：`HASH_HOST = CRC16(key) mod 16348`

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-cluster.png)

节点 1 只负责 执行 0 - 4999 的槽位，而节点 2 负责执行 5000 - 9999，节点 3 执行 9999- 16383

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/redis-cluster-sync.png)

配置：

```ini
cluster-enabled yes
cluster-config-file node_6379.conf
cluster-node-timeout 15000
```

集群命令：

```bash
# 增加节点
> CLUSTER MEET 192.168.1.201 6380
> CLUSTER NODES

# 更改节点身份, 节点改为slave
> CLUSTER REPLICATE a8fdc205a9f19cc1c7507a60c4f01b13d11d7fd0

# 删除节点
> CLUSTER FORGET 40bd001563085fc35165329ea1ff5c5ecbdbbeef

# 保存配置
> CLUSTER SAVECONFIG
```



# 10. 分布式锁

分布式锁的核心：请求的时候 Set 这个 key，如果其他请求设置失败的时候，即拿不到锁。为防止因为业务 panic 或者忘记调用 del 而产生的死锁问题，需要增加一个 expire 过期时间，这样就可以保证请求不会一直独占锁且无法释放锁的问题

```bash
setnx lock:mutex 1
del lock:mutex

SET lock:mutex 1 NX 30 EX  # 上锁 + 设置过期时间
```

锁释放问题：别人可以去释放你加的锁，你也亦然。

解决方案：

- UUID：锁的值设置为uuid，只在获取到的锁的值等于你设置的uid时，才允许释放锁

- Lua脚本：

  ```lua
  if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1]);
  else
      return 0;
  end
  ```




# 11. 布隆过滤器

**Bloom Filter**: 它是一个很长的二进制向量和一系列随机映射函数。可用于检测一个元素是否在一个集合中。其优点是空间效率和查询时间都远远超过一般的算法，缺点是有一定的误识别率和删除困难。

**原理**：当一个元素被加入集合时，通过K个散列函数将这个元素映射成一个位数组中的K个点，把它们设置为1。检索时，只要看看这些点是不是都是1就（大约）知道集合中有没有它了。如果这些点有任何一个0，则被检元素一定不在；如果都是1，则被检元素很可能在。

**Step-1**: 初始化

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-init.png)

**Step-2**: 若干次 hash 来确定其位置

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-hash-1.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-hash-2.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-hash-n.png)

**Step-3**: 判断是否存在

存在：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-judge-exist.png)

不存在：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-judge-nonexist.png)

误判：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/bloom-filter-judge-miss.png)

**如何减少误判？**

- **增加二进制位**：二进制位越多，hash后的数据越分散，出现重复的情况越小，准确率越高
- **增加Hash的次数**：hash次数越多，特征性越多，准确率越高

**Redis中使用布隆过滤器：**

```bash
# 1. 编译安装
wget https://github.com/RedisBloom/RedisBloom/archive/refs/tags/v2.2.9.tar.gz
tar zxvf v2.2.9.tar.gz
cd RedisBloom-2.2.9
make
mv redisbloom.so /usr/lib

vi /etc/redis/redis.conf
loadmodule /usr/lib/redisbloom.so

systemctl restart redis

# 2. docker版本
docker run -p6379:6379 redislabs/rebloom
```

相关指令:

```bash
bf.add       # 添加元素
bf.exists    # 判断元素是否存在
bf.madd      # 批量添加
bf.mexists   # 批量判断是否存在

127.0.0.1:6379> bf.add users user1
(integer) 1
127.0.0.1:6379> bf.add users user2
(integer) 1
127.0.0.1:6379> bf.add users user3
(integer) 1
127.0.0.1:6379> bf.exists users user1
(integer) 1
127.0.0.1:6379> bf.exists users user4
(integer) 0
127.0.0.1:6379> bf.madd users user4 user5 user6
1) (integer) 1
2) (integer) 1
3) (integer) 1
127.0.0.1:6379> bf.mexists users user1 user3 user7
1) (integer) 1
2) (integer) 1
3) (integer) 0
```



# 12. 内存淘汰策略

MySQL中2000w数据，redis中只存20w数据，如何保证redis中的数据都是热数据？

- 全局键空间选择性移除：
  - noeviction：内存不足，写入新数据，报错
  - allkeys-lru：内存不足，写入新数据，将移除最近最少使用的key （最常用）
  - allkeys-random: 内存不足，写入新数据，将随机删除一个key
- 带TTL的键空间选择性移除：
  - volatile-lru：内存不足，写入新数据，在设置了过期时间的键空间中，移除最近最少使用的key
  - volatile-random：内存不足，写入新数据，在设置了过期时间的键空间中，随机移除一个key
  - volatile-ttl：内存不足，写入新数据，在设置了过期时间的键空间中，移除更早过期的key



# 13. 缓存异常

## 13.1 雪崩 (大量key集中过期)

场景：服务器重启或**大量缓存同一时期失效**时，大量的流量会冲击到数据库上，数据库会因承受不了而当机。即缓存层出现了错误，所有数据请求到达存储层，导则存储层无法响应

解决方案：

- 构建多级缓存架构：nginx缓存 + redis缓存 + 其他缓存
- 使用锁或队列：可保证问题不出现，但不适合高并发情况
- **设置过期标志更新缓存**：记录缓存数据是否过期（设置提前量），如果过期会触发通知另外的线程去后台更新实际key的缓存
- **将缓存失效时间分散开**：可通过随机数生成随机时间，这样保证key不在同一时间内过期。



## 13.2 穿透 (缓存空值)

场景：用户查询某条数据，但redis中没有，即缓存未命中；继续向持久层数据库查询，还是没有，即本次查询失败。当大量查询失败时，导则持久层数据库压力过大，即为缓存穿透

解决方案：

- **缓存空值**：即数据不存在，依旧设置一个默认值到缓存中，但该key的过期时间较短。简单应急方案
- **设置白名单**：使用bitmaps定义一个可访问的名单，名单id作为bitmaps的偏移量，每次访问和bitmaps中的id进行比较，如果id不存在，则不允许访问。每次访问都要查询，效率不高
- **布隆过滤器(Bloom Filter)**：是一个二进制向量(位图)和一系列随机映射函数(哈希函数)。布隆过滤器科研检测一个元素是否在一个集合中，其优点是空间效率和查询时间远超过一般的算法，缺点是有一定的错误识别率和删除困难。实现：将所有可能存在的数据哈希到以恶搞足够大的bitmaps中，一个一定不存在的数据会被这个bitmaps拦截掉，从而避免了对底层存储系统的查询压力。
- 实时监控：当发现Redis的命中率开始急速降低，需要排查访问对象和访问的数据，和运维人员配合，设置黑名单限制访问。

**缓存穿透攻击**，是指恶意用户在短时内大量查询不存在的数据，导致大量请求被送达数据库进行查询，当请求数量超过数据库负载上限时，使系统响应出现高延迟甚至瘫痪的攻击行为，就是缓存穿透攻击



## 13.3 击穿 (热门key过期)

场景：某个key非常热点，高并发访问它时，该key突然失效，导则高并发请求直接访问持久数据库，就像在屏障上凿了一个洞

解决方案：

- **预先设置热门数据**：在redis高峰访问前，把一些热门数据提前存入redis中，并加大这些热门数据key的过期时长
- 实时调整：现场监控哪些热门数据，实时调整可以的过期时长

- 使用互斥锁：缓存失效时，不立即查询数据库，先获取锁setnx mutex lock，成功后，查询数据库并设置缓存，删除mutex锁。缺点：访问效率会被降低



# 14. Redis优化

## 14.1 内存管理

```ini
# HashMap成员数量，小于配置，按紧凑格式存储，内存开销少，任意一个超过，就使用真实的HashMap存储，内存占用大
hash-max-zipmap-entries 64   # 成员数量少
hash-max-zipmap-value 512    # 成员长度小

# List
list-max-ziplist-value 64
list-max-ziplist-entries 512
```



## 14.2 持久化

选择aof，每个实例不要超过2G



## 14.3 优化方向

- 进行master-slave主从同步配置，在出现服务故障时可切换
- 在master禁用数据持久化，在slave上配置数据持久化
- Memory+swap不足。此时dump会挂死，最终会导致机器挡掉。64-128GB内存， SSD硬盘。
- 当使用的Memory超过60%，会使用swap，内存碎片大
- 当达到最大内存时，会清空带过期时间的key，即使该key未过期
- redis和DB同步，先写DB，后写redis，内存写速度快

Redis使用建议：

```
key:
    object-type:id:field
    length 10~20
    
value:
    string 不超过2K
    set, sortedset 元素个数不超过5000
```



## 10.4 变慢分析

业务场景中，Redis 变慢的情况：

- 执行 SET、DEL 命令耗时长
- 偶现卡顿，之后又恢复正常
- 在某个时间点，突然开始变慢

慢查询分析：

```bash
127.0.0.1:6379> slowlog get 5
 1) 1) (integer) 22
    2) (integer) 1644289543
    3) (integer) 818
    4) 1) "COMMAND"
    5) "127.0.0.1:50222"
    6) ""
```

响应慢的原因总结：

- Redis 本身单线程限制，导致在客户端上执行命令操作延迟大
- 复杂的命令，导致CPU灯占用高。典型的命令 SORT, SUNION, ZUNIONSTORE等
- 数据量大，导致数据协议组装和网络传输耗时长
- 数据设计不合理，导致某key太大，如果hash, zset
- 内存分配上，一个太大的值，会一次性申请更大的内存，此时可能导致卡顿

- 集中过期，导致数据查询穿透
- 内存达到上限
- 碎片整理，消耗过多CPU
- 网络阻塞
- AOF 写频率过高

- flushdb清空数据库



# 15. IO 模型

Redis 的IO模型：

- **单线程**：IO 和键值对的读写是一个线程完成的。其他操作会fork一个子进程来完成各自的任务
- **多路复用**：使用一个线程来检查多个文件描述符 (socket) 的就绪状态，比如调用select 和epoll函数，传入多个文件描述符，如果有一个文件描述符就绪，则返回，否则阻塞直到超时。得到就绪状态后，进行真正的操作可以在同一个线程里执行，也可以启动线程执行（比如线程池）

Redis 为什么快？

因为 Redis 本身就是在内存中运算，而对于上游的客户端请求，采用了多路复用的原理。Redis 会给每一个客户端套接字都关联一个指令队列，客户端的指令队列通过队列排队来进行顺序处理，同时 Reids 给每一个客户端的套件字关联一个响应队列，Redis 服务器通过响应队列来将指令的接口返回给客户端。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/redis/io-multiplexing.png)

I/O多路复用：是一种同步IO模型，它实现了一个线程可以监视多个文件句柄；一旦某个文件句柄就绪，就能够通知应用程序进行相应的读写操作；而没有文件句柄就绪时,就会阻塞应用程序，交出cpu。**一个线程，可同时管理多个网络连接**。其作用是一次性把多个连接的事件通知业务代码处理，处理的方式由业务代码来决定。在I/O多路复用模型中，最重要的函数调用就是I/O 多路复用函数，该方法能同时监控多个文件描述符（fd）的读写情况，当其中的某些fd可读/写时，该方法就会返回可读/写的fd个数

Redis使用用epoll作为I/O多路复用技术的实现。并且Redis自身的事件处理模型将epoll中的连接、读写、关闭都转换为事件，不在网络I/O上浪费过多的时间。



