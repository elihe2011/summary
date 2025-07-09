# 1. 概述

Grafana Loki 是一个功能齐全的日志聚合系统。与其它日志系统不同的是，它只会索引日志的元数据即 `labels` ，日志数据本身被压缩并分块 (chunk)存储在对象存储中，也可以存储在本地文件系统中。小的索引和高度压缩的分块简化了操作，大大降低了使用成本。



## 1.1 基本概念

- Loki 是一个为有效保存日志数据而优化的数据存储。它通过标签 labels 建立高效索引，没有对原始日志信息进行索引。
- Agent 负责获取日志，将日志变成数据流，并通过 HTTP API 推送给 Loki。`Promtail` 就是其中一个 Agent 实现。
- Loki 对流进行索引，每个流标识了一组独特标签相关的日志。一组高质量的标签是创建索引的关键，它既紧凑又允许有效的查询执行。
- LogQL 是 Loki 的查询语言。



## 1.2 基本特性

- **高效地利用内存为日志建立索引**：通过在一组标签上建立索引，索引可以比其它日志聚合产品小得多。
- **多租户**：允许多个组合使用一个 Loki 实例。不同租户得数据与其它租户是完全隔离得。多租户是通过在代理中分配一个租户ID来配置。
- **`LogQL`**：与 `PromQL` 类似，对日志得查询方面非常熟悉和灵活。
- **可扩展性**：Loki 是为扩展性设计得，因为每个组件都可以作为微服务运行。配置允许单独扩展微服务。
- **灵活性**：支持多种 Agent 插件。
- **Grafana集成**：Loki 与 Grafana 无缝集成，提供了一个完整得客观性栈。



# 2. 架构

## 2.1 概念

### 2.1.1 多租户

当 Grafana Loki 在多租户模式下运行时，所有数据，包括内存和长期存储中得数据，都可以通过租户 ID 进行分区，该 ID 来自请求中的 `X-Scope-OrgID` HTTP 请求头。当 Loki 不在多租户模式下时，该标头被忽略，租户 ID 被设置为 "fake"，这将出现在索引和存储块中。



### 2.1.2 Chunk 格式

`mint` 和 `maxt` 分别描述了最小和最大的 Unix 纳秒时间戳。

```
-------------------------------------------------------------------
|                               |                                 |
|        MagicNumber(4b)        |           version(1b)           |
|                               |                                 |
-------------------------------------------------------------------
|         block-1 bytes         |          checksum (4b)          |
-------------------------------------------------------------------
|         block-2 bytes         |          checksum (4b)          |
-------------------------------------------------------------------
|         block-n bytes         |          checksum (4b)          |
-------------------------------------------------------------------
|                        #blocks (uvarint)                        |
-------------------------------------------------------------------
| #entries(uvarint) | mint, maxt (varint) | offset, len (uvarint) |
-------------------------------------------------------------------
| #entries(uvarint) | mint, maxt (varint) | offset, len (uvarint) |
-------------------------------------------------------------------
| #entries(uvarint) | mint, maxt (varint) | offset, len (uvarint) |
-------------------------------------------------------------------
| #entries(uvarint) | mint, maxt (varint) | offset, len (uvarint) |
-------------------------------------------------------------------
|                      checksum(from #blocks)                     |
-------------------------------------------------------------------
|                    #blocks section byte offset                  |
-------------------------------------------------------------------
```



**Block Format**

一个 block 由一系列 entries 组成，每个 entry 都是一个单独的日志行。

注意：一个 block 的 bytes 是用 Gzip 压缩存储的，以下是它们未压缩时的格式：

```
-------------------------------------------------------------------
|    ts (varint)    |     len (uvarint)    |     log-1 bytes      |
-------------------------------------------------------------------
|    ts (varint)    |     len (uvarint)    |     log-2 bytes      |
-------------------------------------------------------------------
|    ts (varint)    |     len (uvarint)    |     log-3 bytes      |
-------------------------------------------------------------------
|    ts (varint)    |     len (uvarint)    |     log-n bytes      |
-------------------------------------------------------------------
```

`ts` 是日志的 Unix 纳秒时间戳，而 `len` 是日志条目的字节长度。



### 2.1.3 存储

Loki 将所有数据存储在一个单一的对象存储后端。这种操作模式快速、经济、简单，使用一个叫 `boltdb_shipper` 的适配器，将索引存储在对象存储中 （与存储 chunks 的方式相同）



## 2.2 部署模式

Loki 是由许多组件的微服务构建而成，并被设计为一个水平可扩展的分布式系统来运行。

Loki 的独特设计是将整个分布式系统代码编译成一个单一的二进制文件或docker镜像。该二进制文件的行为由 `-target` 命令行标志控制，并定义了三种操作模式。



### 2.2.1 单体模式

最简单的操作模式 `-target=all`，也是默认行为，不需要指定。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/loki-monolithic-mode.png)

单体模式对于**每天不超过100GB**的小规模读写量非常有用。通过使用共享对象存储和配置 `ring section` 在所有实例之间共享状态，可以将单体模式的部署水平地扩展到更多的实例。

通过使用 `memberlist_config` 配置和共享对象存储运行两个 Loki 实例，可以配置搞可用性。

以 round robin 形式将流量路由到所有 Loki 实例。查询并行化的限制在于实例的数量和定义的查询并行度。



### 2.2.2 简单可扩展部署

当每天日志超过几百GB，或者想把日志读写分离，建议使用简单的可扩展部署模型。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/loki-simple-scalable.png)

在这种模式下，Loki的组件微服务被分为两类：`-target=read` 和 `-target=write`。BoltDB 压缩器服务将作为读取目标的一部分运行。



### 2.2.3 微服务模式

微服务部署模式将 Loki 的组件实例化为不同的进程，通过指定 target 实现：

- ingester
- distributor
- query-frontend
- query-scheduler
- querier
- index-gateway
- ruler
- compactor

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/loki-microservices-mode.png)

微服务模式建议用在非常大的 Loki 集群，或者需要扩展和集群操作进行更多控制的集群。适合与 Kubernetes 一起部署。



## 2.3 组件

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/loki-architecture-components.png)

### 2.3.1 Distributor

distributor 是一个无状态组件，可轻松扩展或卸载。

分发器负责处理客户端传入的数据流。当它收到一组数据流时，先验证器是否正确，以确保它在配置的租户(或全局)限制范围内。然后，有效的 Chunk 被分割成批次，并平行地发送到多个 ingesters.

核心功能：

- **Validation**：校验传入的数据是否符合规范，包括标签是否有效，时间戳既不太旧也不太新，日志行也不太长。
- **Preprocessing**：预处理规范化标签，对标签进行排序，使得Loki能够以确定性方式对其进行缓存和哈希处理。
- **Rate limiting**：速率限制。通过检查每个租户的限制并将其除以当前分发器数量来实现。
- **Forwarding**：将数据转发给 ingester 组件。
- **Replication factor**：为降低任单个 ingester 丢失数据的可能性，分发器将写操作转发给它们的复制因子。通常情况下，复制因子为3，复制允许在不中断写入的情况下进行 ingester 的重启和升级，并为某些场景提供了额外的数据丢失保护。
- **Hashing**：所有的Ingestor都使用一组自己拥有的tokens在哈希环中注册自己。每个token是一个随机的无符号32位数字。除了一组tokens，Ingestor还将自己的状态注册到哈希环中。状态`JOINING`、`ACTIVE`都可以接收写请求，而`ACTIVE`和`LEAVING`的Ingestor可以接收读请求。在进行哈希查找时，distributor只使用适合请求的状态的Ingestor的tokens。
- **Quorum consistency**：仲裁一致性，由于所有的distributor共享对同一个哈希环的访问权限，写请求可以发送到任何一个distributor。



### 2.3.2 Ingester

接收器服务负责在写入路径上将日志数据写入长期存储后端（如DynamoDB、S3、Cassandra等），并在读取路径上返回内存查询的日志数据。

Ingester 包含了一个生命周期管理器，用于管理哈希环中 Ingester 的生命中期：

- PENDING
- JOINING
- ACTIVE
- LEAVING
- UNHEALTHY

每个 Ingester 接收到的日志流都会在内存中主机构成一组许多块 (chunks)，并在可配置的时间间隔刷新到后端存储。



### 2.3.3 Query frontend

查询前端是一个可选服务，提供查询器的 API 端点，可用于加速读取路径。



### 2.3.4 Querier

查询器使用 logQL查询语言处理查询，从 Ingester 和长期存储中获取日志。



## 2.4 Consistent Hash Rings

一致性哈希环的用途：

- 帮助对日志进行分片，实现更好的负载均衡
- 使用高可用性，确保系统在组件故障时仍能正常运行
- 便于集群的水平扩展和缩小。对于需要重新平衡数据的操作，性能影响较小。

并非所有的 Loki 组件都通过哈希环连接，以下组件需要：

- distributors
- ingesters
- query schedulers
- compactors
- rulers
- index gateway （可选择性地连接到哈希环）

在一个具有三个分发器和三个接收器的架构中，这些组件的哈希环将连接相同类型的组件实例：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/loki-ring-overview.png)

环中的每个节点代表一个组件实例。每个节点都有一个键值存储，用于保存该环中每个节点的通信信息。节点定期更新键值存储。以确保所有节点之间的内容保持一致。对于每个节点，键值存储包含以下内容：

- 组件节点ID
- 组件地址，用于其它节点的通信渠道
- 组件节点健康状态的指示



# 3. 标签

标签是键值对，可定义任何内容，也称元数据，用于描述日志流。

Prometheus 通过指标名称和标签来定义系列(series)，而Loki则没有指标名称，只有标签来定义日志流(stream)

Loki 的标签名称命名与 Prometheus 相同，它必选符合正则表达 `[a-zA-Z_:][a-zA-Z0-9_:]*`，其中冒号保留给用户定义的记录规则，导出器 exporters 或直接仪表化的过程不应使用冒号。



## 3.1 示例

基本用法：

```yaml
scrape_configs:
 - job_name: system
   pipeline_stages:
   static_configs:
   - targets:
      - localhost
     labels:
      job: syslog
      __path__: /var/log/syslog
```

上述配置将分配一个标签：`job=syslog`。可以按以下方式查询：

```
{job="syslog"}
```



额外标签：

```yaml
scrape_configs:
 - job_name: system
   pipeline_stages:
   static_configs:
   - targets:
      - localhost
     labels:
      job: syslog
      env: dev
      __path__: /var/log/syslog
 - job_name: apache
   pipeline_stages:
   static_configs:
   - targets:
      - localhost
     labels:
      job: apache
      env: dev
      __path__: /var/log/apache.log
```

查询：

```
{job=~"apache|syslog"} - 显示标签 job 为 apache 或 syslog 的日志
{env="dev"} - 将返回所有具有 env=dev 的日志，在这种情况下，包括两个日志流。
```



## 3.2 Cardinality 基数

动态定义标签，以 Apache 日志为例：

```
11.11.11.11 - frank [25/Jan/2000:14:00:01 -0500] "GET /1986.js HTTP/1.1" 200 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
11.11.11.12 - frank [25/Jan/2000:14:00:02 -0500] "POST /1986.js HTTP/1.1" 200 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
11.11.11.13 - frank [25/Jan/2000:14:00:03 -0500] "GET /1986.js HTTP/1.1" 400 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
11.11.11.14 - frank [25/Jan/2000:14:00:04 -0500] "POST /1986.js HTTP/1.1" 400 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
```



配置规则：

```yaml
- job_name: system
   pipeline_stages:
      - regex:
        expression: "^(?P<ip>\\S+) (?P<identd>\\S+) (?P<user>\\S+) \\[(?P<timestamp>[\\w:/]+\\s[+\\-]\\d{4})\\] \"(?P<action>\\S+)\\s?(?P<path>\\S+)?\\s?(?P<protocol>\\S+)?\" (?P<status_code>\\d{3}|-) (?P<size>\\d+|-)\\s?\"?(?P<referer>[^\"]*)\"?\\s?\"?(?P<useragent>[^\"]*)?\"?$"
    - labels:
        action:
        status_code:
   static_configs:
   - targets:
      - localhost
     labels:
      job: apache
      env: dev
      __path__: /var/log/apache.log
```

在 Loki 中，将创建以下日志流：

```
{job="apache",env="dev",action="GET",status_code="200"} 11.11.11.11 - frank [25/Jan/2000:14:00:01 -0500] "GET /1986.js HTTP/1.1" 200 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
{job="apache",env="dev",action="POST",status_code="200"} 11.11.11.12 - frank [25/Jan/2000:14:00:02 -0500] "POST /1986.js HTTP/1.1" 200 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
{job="apache",env="dev",action="GET",status_code="400"} 11.11.11.13 - frank [25/Jan/2000:14:00:03 -0500] "GET /1986.js HTTP/1.1" 400 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
{job="apache",env="dev",action="POST",status_code="400"} 11.11.11.14 - frank [25/Jan/2000:14:00:04 -0500] "POST /1986.js HTTP/1.1" 400 932 "-" "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB6"
```



# 4. 组件部署

## 4.1 Loki

```bash
mkdir -p /opt/loki && cd $_
mkdir -p data/{chunks,index}

cat > loki.yaml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  #grpc_listen_port: 9096
  log_level: debug
  grpc_server_max_concurrent_streams: 1000

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

limits_config:
  metric_aggregation_enabled: true

schema_config:
  configs:
    - from: 2025-03-19
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h      # 每张表的时间范围

pattern_ingester:
  enabled: true
  metric_aggregation:
    loki_address: localhost:3100

ruler:
  alertmanager_url: http://192.168.3.111:9093
EOF

docker run -d --name loki \
  --restart always \
  -p 3100:3100 \
  -v /opt/loki/loki.yaml:/etc/loki/local-config.yaml \
  -v /opt/loki/data:/loki \
  grafana/loki:3.4.2 \
  -config.file=/etc/loki/local-config.yaml
```



指标数据：http://192.168.3.111:3100/metrics

运行状态：http://192.168.3.111:3100/ready    // 显示ready时OK



## 4.2 Promtail

```bash
mkdir -p /opt/promtail && cd $_

cat > promtail.yaml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.3.111:3100/loki/api/v1/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/*log
- job_name: rsyslog
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      __path__: /var/log/rsyslog/*.log
EOF


docker run -d --name promtail \
  --restart always \
  -p 9080:9080 \
  -p 1514:1514/udp \
  -v /opt/promtail/promtail.yaml:/etc/promtail/local-config.yaml \
  grafana/promtail:3.4.2 \
  -config.file=/etc/promtail/local-config.yaml
  
docker run -d --name promtail \
  --restart always \
  -p 9080:9080 \
  -p 1514:1514 \
  -v /opt/promtail/promtail.yaml:/etc/promtail/local-config.yaml \
  grafana/promtail:3.4.2 \
  -config.file=/etc/promtail/local-config.yaml
  
docker run -d --name promtail \
  --restart always \
  -p 9080:9080 \
  -v /var/log/rsyslog:/var/log/rsyslog \
  -v /opt/promtail/promtail.yaml:/etc/promtail/local-config.yaml \
  grafana/promtail:3.4.2 \
  -config.file=/etc/promtail/local-config.yaml  
```



可用标签:

```
Available Labels
__syslog_connection_ip_address: The remote IP address.
__syslog_connection_hostname: The remote hostname.
__syslog_message_severity: The syslog severity parsed from the message. Symbolic name as per syslog_message.go.
__syslog_message_facility: The syslog facility parsed from the message. Symbolic name as per syslog_message.go and syslog(3).
__syslog_message_hostname: The hostname parsed from the message.
__syslog_message_app_name: The app-name field parsed from the message.
__syslog_message_proc_id: The procid field parsed from the message.
__syslog_message_msg_id: The msgid field parsed from the message.
__syslog_message_sd_<sd_id>[_<iana_enterprise_id>]_<sd_name>: The structured-data field parsed from the message. The data field 
```





## 4.3 rsyslog

### 4.3.1 安装

```bash
apt install rsyslog
```



### 4.3.2 服务端

```bash
# 1. 开启udp和tcp接收日志端口
vi /etc/rsyslog.conf
...
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")

# 2. 配置远程日志存储
cat > /etc/rsyslog.d/remote.conf <<EOF
#### GLOBAL DIRECTIVES ####
# Use default timestamp format  # 使用自定义的格式
#$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
#$template myFormat,"%timestamp% %fromhost-ip% %syslogtag% %msg%\n"
#$ActionFileDefaultTemplate myFormat

# 根据客户端的IP单独存放主机日志在不同目录，rsyslog需要手动创建
#$template RemoteLogs,"/var/log/rsyslog/%fromhost-ip%/%syslogtag%_%$YEAR%-%$MONTH%-%$DAY%-%$hour%:%$minute%.log"
$template RemoteLogs,"/var/log/rsyslog/%fromhost-ip%/%syslogtag%_%$YEAR%-%$MONTH%-%$DAY%.log
# 排除本地主机IP日志记录，只记录远程主机日志
:fromhost-ip, !isequal, "127.0.0.1" ?RemoteLogs
# 忽略之前所有的日志，远程主机日志记录完之后不再继续往下记录
& ~
EOF

# 3. 重启服务
systemctl restart rsyslog

# 4. 检查监听端口
lsof -i :514
```



### 4.3.3 客户端

```bash
# 配置服务端
cat > /etc/rsyslog.d/99-remote.conf <<EOF
*.* @192.168.3.111:514     # UDP
# *.* @@192.168.3.111:514  # TCP
EOF

# 重启服务
systemctl restart rsyslog
```













































