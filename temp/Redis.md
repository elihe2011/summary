NoSQL追求的目标：

- High performance  对数据库高并发读写的需求
- Huge Storage 海量数据的高效率存储和访问需求
- High Scalability && High Availabiity 高可扩展性和高可用性需求

Redis：Remote Dictionary Server

Redis的特点：

- key-value 存储
- 支持数据可靠性存储及落地
- 单进程但线程高性能服务器
- crash safe & recovery slow
- 单机qps可达10W
- 适合小数据量高速读写访问

Redis优点：

- 支持持久化
- 高性能，每秒读写频率超过10W
- 数据类型丰富。string, list, hash, set, sorted set等
- 所有操作原子性
- 还支持publish/subscribe、通知、key过期等
- 支持异机主从复制

Redis缺陷和陷阱：

- 内存管理开销大（低于物理内存的60%）
- buffer io造成系统OOM

Redis持久化：

- Snapshot: 快照方式，将内存中的数据不断写入磁盘

  - save 900 1
  - save 300 10
  - save 60 10000

- AOF: 类似MySQL的binlog日志方式，记录每次更新的日志(aof不用于主从同步)

  - appendfsync always
  - appendfsync everysec  // 在性能和持久化方面折中
  - appendfsync no

  

  Snapchat性能更高，但可能会引起一定程度的数据丢失

  建议：

  - 更新频繁，一致性要求较高，AOF策略为主
  - 更新不频繁，可以容忍少量数据丢失或错误，Snapshot为主

Redis应用场景：

- 计数
- cache服务
- 展示最近、最热、点击率最高、活跃度最高等条件的top list
- 用户最近访问记录
- Relation List/Message Queue
- 粉丝列表

Redis 使用经验：

- 进行master-slave主从同步配置，在出现服务故障时可切换
- 在master禁用数据持久化，在slave上配置数据持久化
- Memory+swap不足。此时dump会挂死，最终会导致机器挡掉。64-128GB内存， SSD硬盘。
- 当使用的Memory超过60%，会使用swap，内存碎片大
- 当达到最大内存时，会清空带过期时间的key，即使该key未过期
- redis和DB同步，先写DB，后写redis，内存写速度快

Redis部署：

```bash
redis-server
redis-cli

redis-benchmark	   # 测试Redis在当前系统、当前配置下的性能
redis-check-aof    # 检查更新日志appendonly.aof
redis-check-dump   # 检查本地数据库rdb文件
```

Redis启动：

```bash
redis-server
redis-server --port 6479
redis-server --port 6479 --slaveof 127.0.0.1 6579

redis-server /etc/redis/redis.conf
redis-server /etc/redis/redis.conf --loglevel verbose
redis-server /etc/redis/redis.conf --sentinel
```

客户端操作：redis库(select 0~15)

```bash
telnet 192.168.1.100 6379

echo "set name abc" | nc 127.0.0.1 6379

redis-cli -h 192.168.1.100 -p 6379 -n 5
> help set
> help @string    # 字符串操作相关的所有命令
```

Redis设置客户端连接密码：

```bash
vi /etc/redis/redis.conf
requirepass New_Pass

redis-cli shutdown
redis-server /etc/redis/redis.conf

# 方法1：
redis-cli
> auth New_Pass

# 方法2：
redis-cli -a New_Pass
```

不安全的命令改名：

```bash
vi /etc/redis/redis.conf
rename-command keys ""
```

Redis配置文件说明：

```nginx
daemonize no

pidfile /var/run/redis.pid

port 6379

bind 127.0.0.1

timeout 0   # 0 client永不超时

loglevel notice    

logfile "/var/log/redis.log"

databases 16

# snapchat
save 900 1
save 300 10
save 60 10000   # after 60 sec if at least 10000 keys changed

save ""   # 读写频繁时，不使用Snapchat

rdbchecksum yes
dbfilename dump.rdb

maxmemory bytes?

appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
```

Redis使用建议：

```
key:
    object-type:id:field
    length 10~20
    
value:
    string 不超过2K
    set, sortedset 元素个数不超过5000
```

各数据类型使用场景：

- List：实时聊天系统、不同进程间传递消息队列、列表类的东西
- Set: 

Redis主从同步：

1) 主从同步特点

- 一个master可拥有多个slave
- slave还可连接到其他slave
- 主从复制不会阻塞master，数据同步时，master可继续处理client请求

2) 配置

salve:

```
slaveof <masterip> <masterport>
masterauth <master-password>
```

```
redis-cli
> info
> monitor
> info replication
```

Redis发布和订阅：

1) Client

```bash
redis-cli
> subscribe channel00
```

2) Server

```bash
redis-cli
> publish channel00 hello
```

Redis设置过期时间：

```bash
redis-cli
> flushdb
> keys *
> exists name
> set name tom
> ttl name        # -1, 永不过期
> expire name 5   # 5s后过期

> set age 20
> expireat age 1555506769
```

​	过期机制：redis采用lazy expriation方式，即在访问key时判断是否过期，如果过期，则进行过期处理。其次，每秒对volation keys进行抽样测试，如果有过期键，那对所有过期key处理。

Redis持久化：

1) snapshot: 默认方式，将内存中的数据以快照方式写入二进制文件中(dump.rdb)

```text
save 900 1
save 300 10
save 60 10000
```

​	快照保存过程：

- redis调用fork，产生一个子进程
- 父进程继续处理client请求，子进程负责将fork时刻整个内存数据库快照写入临时文件。
- 子进程完成写入临时文件后，用临时文件替换原来的快照文件，然后子进程退出。

​         问题：每次快照持久化都是将内存数据完整写入到磁盘，如果数据量较大，读写操作较多，必然会引起磁盘IO问题。

2) aof (append only file)

```
appendonly yes

appendfsync always
appendfsync everysec
appendfsync no   # 完全依赖操作系统，性能最好，但持久化可能丢数据
```

​     aof的问题：持久化文件会越来越大。为了压缩aof的持久化文件，redis提供命令bgrewriteaof命令。收到此命令，将使用和快照类似的处理方式，将内存以命令的方式保存到临时文件，最后替换原来的文件。

```text
# 自动bgrewriteaof
auto-aof-rewrite-percentage 100
auto-aof-rewrite-size 64mb
```

Redis命令补充：

```bash
redis-cli
> auth PASS
> config get appendonly
> config set appendonly yes    # 临时改参数
> config get *
> config reset
> info
> flushall
> monitor
> shutdown
```

Redis-benchmark: 服务器性能测试

```bash
# 100个并发，100000次
redis-benchmark -h localhost -p 6379 -c 100 -n 100000
```

Redis优化：

1) 内存管理

```text
# HashMap成员数量，小于配置，按紧凑格式存储，内存开销少，任意一个超过，就使用真实的HashMap存储，内存占用大
hash-max-zipmap-entries 64   # 成员数量少
hash-max-zipmap-value 512    # 成员长度小

# List
list-max-ziplist-value 64
list-max-ziplist-entries 512
```

2) 持久化

选择aof，每个实例不要超过2G



