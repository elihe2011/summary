# 1. 概述

所有可以向Prometheus提供监控样本数据的程序都可以被称为一个Exporter。而Exporter的一个实例称为target，如下所示，Prometheus通过轮询的方式定期从这些target中获取样本数据:

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-exporter.png)



## 1.1 来源

从Exporter的来源上来讲，主要分为两类：

- 社区提供的

Prometheus社区提供了丰富的Exporter实现，涵盖了从基础设施，中间件以及网络等各个方面的监控功能。这些Exporter可以实现大部分通用的监控需求。下表列举一些社区中常用的Exporter：

| 范围     | 常用Exporter                                                 |
| -------- | ------------------------------------------------------------ |
| 数据库   | MySQL Exporter, Redis Exporter, MongoDB Exporter, MSSQL Exporter等 |
| 硬件     | Apcupsd Exporter，IoT Edison Exporter， IPMI Exporter, Node Exporter等 |
| 消息队列 | Beanstalkd Exporter, Kafka Exporter, NSQ Exporter, RabbitMQ Exporter等 |
| 存储     | Ceph Exporter, Gluster Exporter, HDFS Exporter, ScaleIO Exporter等 |
| HTTP服务 | Apache Exporter, HAProxy Exporter, Nginx Exporter等          |
| API服务  | AWS ECS Exporter， Docker Cloud Exporter, Docker Hub Exporter, GitHub Exporter等 |
| 日志     | Fluentd Exporter, Grok Exporter等                            |
| 监控系统 | Collectd Exporter, Graphite Exporter, InfluxDB Exporter, Nagios Exporter, SNMP Exporter等 |
| 其它     | Blockbox Exporter, JIRA Exporter, Jenkins Exporter， Confluence Exporter等 |

- 用户自定义的

除了直接使用社区提供的Exporter程序以外，用户还可以基于Prometheus提供的Client Library创建自己的Exporter程序，目前Promthues社区官方提供了对以下编程语言的支持：Go、Java/Scala、Python、Ruby。同时还有第三方实现的如：Bash、C++、Common Lisp、Erlang,、Haskeel、Lua、Node.js、PHP、Rust等。



示例：自定义

```golang
import (
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	counter   prometheus.Counter
	counter2  *prometheus.CounterVec
	gauge     prometheus.Gauge
	histogram prometheus.Histogram
	summary   prometheus.Summary
)

func init() {
	counter = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "my_counter_total",
		Help: "自定义 counter",
	})

	counter2 = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "my_counter_vec_total",
		Help: "自定义带标签的 counter",
	}, []string{"label1", "label2"})

	gauge = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "my_gauge_sum",
		Help: "自定义 gauge",
	})

	histogram = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "my_histogram",
		Help:    "自定义 histogram",
		Buckets: []float64{0.1, 0.2, 0.3, 0.4, 0.5},
	})

	summary = prometheus.NewSummary(prometheus.SummaryOpts{
		Name: "my_summary",
		Help: "自定义 summary",
		Objectives: map[float64]float64{
			0.5:  0.05,
			0.9:  0.01,
			0.99: 0.001,
		},
	})

	prometheus.MustRegister(counter)
	prometheus.MustRegister(counter2)
	prometheus.MustRegister(gauge)
	prometheus.MustRegister(histogram)
	prometheus.MustRegister(summary)
}

func say(w http.ResponseWriter, r *http.Request) {
	counter.Inc()
	counter2.With(prometheus.Labels{"label1": "1", "label2": "2"}).Inc()

    histogram.Observe(0.1)
	histogram.Observe(0.3)
	histogram.Observe(0.4)
    
	fmt.Fprintln(w, "hello world")
}

func main() {
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", say)

	http.ListenAndServe(":8080", nil)
}
```



## 1.2 运行方式

从Exporter的运行方式上来讲，又可以分为：

- 独立使用的

以我们已经使用过的Node Exporter为例，由于操作系统本身并不直接支持Prometheus，同时用户也无法通过直接从操作系统层面上提供对Prometheus的支持。因此，用户只能通过独立运行一个程序的方式，通过操作系统提供的相关接口，将系统的运行状态数据转换为可供Prometheus读取的监控数据。 除了Node Exporter以外，比如MySQL Exporter、Redis Exporter等都是通过这种方式实现的。 这些Exporter程序扮演了一个中间代理人的角色。

- 集成到应用中的

为了能够更好的监控系统的内部运行状态，有些开源项目如Kubernetes，ETCD等直接在代码中使用了Prometheus的Client Library，提供了对Prometheus的直接支持。这种方式打破的监控的界限，让应用程序可以直接将内部的运行状态暴露给Prometheus，适合于一些需要更多自定义监控指标需求的项目。



## 1.3 规范

所有的Exporter程序都需要按照Prometheus的规范，返回监控的样本数据。以Node Exporter为例，当访问/metrics地址时会返回以下内容：

```text
# HELP node_cpu Seconds the cpus spent in each mode.
# TYPE node_cpu counter
node_cpu{cpu="cpu0",mode="idle"} 362812.7890625
# HELP node_load1 1m load average.
# TYPE node_load1 gauge
node_load1 3.0703125
```

Exporter返回的样本数据，主要由三个部分组成：样本的一般注释信息（HELP），样本的类型注释信息（TYPE）和样本。

- `# HELP`，指标名称以及相应的说明信息：

```text
# HELP <metrics_name> <doc_string>
```

- `# TYPE`，指标名称以及指标类型:

```text
# TYPE <metrics_name> <metrics_type>
```

TYPE注释行必须出现在指标的第一个样本之前。否则指标类型为untyped。 除了# 开头的所有行都会被视为是监控样本数据。 每一行样本需要满足以下格式规范:

```
metric_name [
  "{" label_name "=" `"` label_value `"` { "," label_name "=" `"` label_value `"` } [ "," ] "}"
] value [ timestamp ]
```

其中metric_name和label_name必须遵循PromQL的格式规范要求。value是一个float格式的数据，timestamp的类型为int64（从1970-01-01 00:00:00以来的毫秒数），timestamp为可选默认为当前时间。具有相同metric_name的样本必须按照一个组的形式排列，并且每一行必须是唯一的指标名称和标签键值对组合。

Summary 和 Histogram 类型样本，需要按约定返回样本数据：指标x

- `x_sum`：该指标所有样本的值的总和
- `x_count`：该指标所有样本的总数
- `x{quantile="y"}`：Summary 其不同分位数 quantile 所代表的样本
- `x_bucket{le="y"}`：Histogram 每个分布都需要，其中 y 为当前分布的上位数
- `x_bucket{le="+Inf"}`：Histogram 最后一个分布，其样本值必须和 `x_count` 相同

对于 Histogram 和 Summary 的样本，必须按照分位数 quantile 和 分布le 的值递增排序

```
# A histogram, which has a pretty complex representation in the text format:
# HELP http_request_duration_seconds A histogram of the request duration.
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.05"} 24054
http_request_duration_seconds_bucket{le="0.1"} 33444
http_request_duration_seconds_bucket{le="0.2"} 100392
http_request_duration_seconds_bucket{le="+Inf"} 144320
http_request_duration_seconds_sum 53423
http_request_duration_seconds_count 144320

# Finally a summary, which has a complex representation, too:
# HELP rpc_duration_seconds A summary of the RPC duration in seconds.
# TYPE rpc_duration_seconds summary
rpc_duration_seconds{quantile="0.01"} 3102
rpc_duration_seconds{quantile="0.05"} 3272
rpc_duration_seconds{quantile="0.5"} 4773
rpc_duration_seconds_sum 1.7560473e+07
rpc_duration_seconds_count 2693
```



# 2. 节点监控 node-exporter

node-exporter使用Go语言编写，用于收集节点服务器资源，如 **CPU频率信息**、**磁盘IO统计**、**剩余内存** 等。并将这些信息转换成 Prometheus 可识别的  **Metrics** 数据。还提供了textfile功能，可用于自定义指标。



## 2.1 部署

```bash
docker run -d --name node-exporter \
    -e TZ="Asia/Shanghai" \
    -p 9100:9100 \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    -v /:/rootfs:ro \
    --restart=always prom/node-exporter:v1.8.2 \
    --path.procfs=/host/proc \
    --path.rootfs=/rootfs \
    --path.sysfs=/host/sys \
    --collector.filesystem.ignored-mount-points='^/(sys|proc|dev|host|etc)($$|/)'
```



修改 prometheus.yml，添加配置

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```



## 2.2 textfile收集器

textfile 是一个特定的收集器，它允许我们暴露自定义的指标。这些指标或者是没有相关的exporter可以使用，或者是你自己开发的应用指标。

textfile通过扫描指定目录中的文件，提取所有符合Prometheus数据格式的字符串，然后暴露它们给到Prometheus进行抓取

```bash
mkdir -p /opt/prom
cat > /opt/prom/metadata.prom <<EOF
# HELP node_host_temp this is the temperature of host
# TYPE node_host_temp gauge
node_host_temp{edgegateway="eg-12345",location="beijing"} 36
EOF

docker run -d --name=node-exporter -p 9100:9100 \
    -v "/proc:/host/proc" \
    -v "/sys:/host/sys" \
    -v "/:/rootfs" \
    prom/node-exporter:v1.3.1 \
        --path.procfs /host/proc \
        --path.sysfs /host/sys \
        --collector.textfile.directory="/rootfs/opt/prom"
```



模拟脚本：

```bash
#!/bin/bash

while [ 1 -eq 1 ]
do
        t=$(expr $RANDOM % 100)

        cat > /opt/prom/metadata.prom <<EOF
# HELP node_host_temp this is the temperature of host
# TYPE node_host_temp gauge
node_host_temp{edgegateway="eg-12345",location="beijing"} $t
EOF

        sleep 2
done
```



## 2.3 典型指标

1. CPU相关指标：
   - `node_cpu_seconds_total{mode="idle"}`：CPU空闲时间（秒）的总和。这是评估CPU使用率的重要指标之一。
   - `node_cpu_seconds_total{mode="system"}`、`node_cpu_seconds_total{mode="user"}`等：分别表示CPU在内核态和用户态的运行时间。
2. 内存相关指标：
   - `node_memory_MemTotal_bytes`：内存总量（以字节为单位）。
   - `node_memory_MemFree_bytes`：空闲内存大小（以字节为单位）。
   - `node_memory_Buffers_bytes`和`node_memory_Cached_bytes`：分别表示被内核用作缓冲和缓存的内存大小。
   - `node_memory_SwapTotal_bytes`和`node_memory_SwapFree_bytes`：分别表示交换空间的总大小和空闲大小。
3. 磁盘相关指标：
   - `node_filesystem_size_bytes`：文件系统的大小（以字节为单位）。
   - `node_filesystem_free_bytes`和`node_filesystem_avail_bytes`：分别表示文件系统的空闲空间和非root用户可用的空间大小。
   - `node_disk_io_now`、`node_disk_io_time_seconds_total`等：与磁盘I/O操作相关的指标，如当前正在进行的I/O操作数以及花费在I/O操作上的总时间。
4. 网络相关指标：
   - `node_network_receive_bytes_total`和`node_network_transmit_bytes_total`：分别表示网络接口接收和发送的总字节数。这些指标对于评估网络流量和带宽使用情况非常重要。
5. 系统负载相关指标：
   - `node_load1`、`node_load5`、`node_load15`：分别表示系统在过去1分钟、5分钟和15分钟的平均负载。这些指标有助于了解系统的整体忙碌程度和性能表现。



示例：

```bash
# 5分钟内，cpu使用率
100 -avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)* 100

# 内存使用率：`（总内存  -（空闲内存 + 缓冲缓存 + 页面缓存））/ 总内存 * 100`
(node_memory_MemTotal_bytes - (node_memory_MemFree_bytes + node_memory_Buffers_bytes+node_memory_Cached_bytes ))/node_memory_MemTotal_bytes * 100 

# swap 使用率：
(node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes)/node_memory_SwapTotal_bytes * 100

# 分区 "/" 的使用率：
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"})/node_filesystem_size_bytes{mountpoint="/"} * 100

# 磁盘的读写速率：
irate(node_disk_read_bytes_total{device="vda"}[5m]) 
irate(node_disk_written_bytes_total{device="vda"}[5m]) 

# 磁盘的读写 IOPS:
irate(node_disk_reads_completed_total{device="vda"}[5m]) 
irate(node_disk_writes_completed_total{device="vda"}[5m]) 

# 网络速率：
irate(node_network_receive_bytes_total{device="eth0"}[1m])
irate(node_network_transmit_bytes_total{device="eth0"}[1m])

# 可用性
up{job="node_exporter"}
```



# 3. 容器监控 cAdvisor

cAdvisor 是 Google 开源的一款用于监控和展示容器运行状态的可视化工具。它可直接运行在主机上，收集机器上运行的所有容器信息，还提供查询界面和http接口，方便 prometheus 等监控平台获取相关数据



## 3.1 部署

```bash
docker run -d --name cadvisor \
    -p 8080:8080 \
    -e TZ="Asia/Shanghai" \
    -v /:/rootfs:ro \
    -v /var/run:/var/run:rw \
    -v /sys:/sys:ro \
    -v /var/lib/docker/:/var/lib/docker:ro \
    -v /dev/disk/:/dev/disk:ro \
    --privileged \
    --device=/dev/kmsg \
    --restart=always google/cadvisor:v0.45.0
```

从 cAdvisor 中采集数据，在 prometheus.yml 添加如下内容：

```yaml
scrape_configs:
  ...
  - job_name: 'cAdvisor'
    static_configs:
      - targets: ['192.168.3.111:8080']
```

查看当前主机上容器的运行状态：http://192.168.3.111:8080



## 3.2 典型指标

| 指标名称                               | 类型    | 含义                                         |
| -------------------------------------- | ------- | -------------------------------------------- |
| container_cpu_load_average_10s         | gauge   | 过去10秒容器CPU的平均负载                    |
| container_cpu_usage_seconds_total      | counter | 容器在每个CPU内核上的累积占用时间 (单位：秒) |
| container_cpu_system_seconds_total     | counter | System CPU累积占用时间（单位：秒）           |
| container_cpu_user_seconds_total       | counter | User CPU累积占用时间（单位：秒）             |
| container_fs_usage_bytes               | gauge   | 容器中文件系统的使用量(单位：字节)           |
| container_fs_limit_bytes               | gauge   | 容器可以使用的文件系统总量(单位：字节)       |
| container_fs_reads_bytes_total         | counter | 容器累积读取数据的总量(单位：字节)           |
| container_fs_writes_bytes_total        | counter | 容器累积写入数据的总量(单位：字节)           |
| container_memory_max_usage_bytes       | gauge   | 容器的最大内存使用量（单位：字节）           |
| container_memory_usage_bytes           | gauge   | 容器当前的内存使用量（单位：字节             |
| container_spec_memory_limit_bytes      | gauge   | 容器的内存使用量限制                         |
| machine_memory_bytes                   | gauge   | 当前主机的内存总量                           |
| container_network_receive_bytes_total  | counter | 容器网络累积接收数据总量（单位：字节）       |
| container_network_transmit_bytes_total | counter | 容器网络累积传输数据总量（单位：字节）       |

常用容器 PromQL：

``` 
# 容器的 CPU 使用率
sum(irate(container_cpu_usage_seconds_total{image!=""}[1m])) without (cpu)

# 容器内存使用量 （bytes)
container_memory_usage_bytes{image!=""}

# 容器网络接收速率 (bps)
sum(rate(container_network_receive_bytes_total{image!=""}[5m])) without (interface)

# 容器网络传输速率 (bps)
sum(rate(container_network_transmit_bytes_total{image!=""}[2m])) without (interface)

# 容器文件系统读取速率 (bps)
sum(rate(container_fs_reads_bytes_total{image!=""}[2m])) without (device)

# 容器文件系统写入速率 (bps)
sum(rate(container_fs_writes_bytes_total{image!=""}[2m])) without (device)
```



# 4. MySQL Exporter

## 4.1 部署

```bash
# 创建专用用户
mysql -u root -p
mysql> CREATE USER 'exporter'@'192.168.3.105' IDENTIFIED BY '123456' WITH MAX_USER_CONNECTIONS 3;
mysql> GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'192.168.3.105';
mysql> FLUSH PRIVILEGES;

# 创建配置文件
mkdir -p /opt/mysqld-exporter && cd $_
cat > /opt/mysqld-exporter/my.cnf <<EOF
[client]
user = exporter
password = 123456
host = 192.168.3.112
port = 3306
EOF

# 启动容器
docker run -d --name mysqld-exporter \
    -p 9104:9104 \
    -e TZ="Asia/Shanghai" \
    -v /opt/mysqld-exporter/my.cnf:/.my.cnf \
    --restart=always prom/mysqld-exporter:v0.15.1
```



注册服务到 consul:

```bash
curl -X PUT -d '{"name": "mysql-exporter", "address": "192.168.3.105","port": 9104, "tags": ["mysql"], "checks": [{"http": "http://192.168.3.105:9104/metrics", "interval":"30s"}]}'  http://192.168.3.105:8500/v1/agent/service/register
```



修改 prometheus.yml，添加配置:

```bash
...
  # 动态配置
  - job_name: 'mysql'
    consul_sd_configs:
      - server: '192.168.3.105:8500'
    relabel_configs:
    - source_labels: [__meta_consul_tags]
      regex: ".*mysql.*"
      action: keep 
    - regex: __meta_consul_service_metadata_(.+)
      action: labelmap
    metric_relabel_configs:
      - source_labels: [ __name__ ]
        regex:  "go_.*"
        action: drop
        
  # 静态配置
  - job_name: 'mysqld-exporter'
    static_configs:
      - targets: ['192.168.3.111:9104']
```



## 4.2 典型指标

1. MySQL 全局状态指标：

   - `mysql_global_status_uptime`：MySQL 服务器的运行时间（以秒为单位）。
   - `mysql_global_status_threads_connected`：当前打开的连接数。
   - `mysql_global_status_threads_running`：当前正在运行的线程数。
   - `mysql_global_status_queries`：从服务器启动开始执行的查询总数。
   - `mysql_global_status_questions`：从服务器启动开始接收的客户端查询总数。

2. MySQL 复制指标（如果配置了复制）：

   - `mysql_slave_status_slave_io_running`：表示 IO 线程是否正在运行（1 为运行，0 为停止）。
   - `mysql_slave_status_slave_sql_running`：表示 SQL 线程是否正在运行（1 为运行，0 为停止）。
   - `mysql_slave_status_seconds_behind_master`：从服务器相对于主服务器的延迟时间（以秒为单位）。

3. InnoDB 存储引擎指标：

   - `mysql_global_status_innodb_buffer_pool_read_requests`：InnoDB 缓冲池执行的逻辑读请求数。
   - `mysql_global_status_innodb_buffer_pool_reads`：不能满足 InnoDB 缓冲池而直接从磁盘读取的请求数。
   - `mysql_global_status_innodb_row_lock_time_avg`：平均行锁定时间（以毫秒为单位）。
   - `mysql_global_status_innodb_row_lock_time_max`：最大行锁定时间（以毫秒为单位）。

4. 连接和资源使用指标：

   - `mysql_global_variables_max_connections`：MySQL 配置的最大连接数。
   - `mysql_global_status_aborted_connects`：尝试连接到 MySQL 服务器但失败的连接数。
   - `mysql_global_status_connection_errors_total`：由于各种原因导致的连接错误总数。

5. 查询缓存指标（如果启用了查询缓存）：

   - `mysql_global_status_qcache_hits`：查询缓存命中次数。
   - `mysql_global_status_qcache_inserts`：插入到查询缓存中的查询次数。
   - `mysql_global_status_qcache_not_cached`：由于查询类型或其他原因而无法缓存的查询次数。

6. 其他常用指标：

   - `mysql_exporter_last_scrape_duration_seconds`：`mysql-exporter` 上次抓取指标所花费的时间。
   - `mysql_exporter_scrape_errors_total`：`mysql-exporter` 在抓取过程中遇到的错误总数。

   

```
# Questions计数器的大小
rate(mysql_global_status_questions[2m])

# 写操作速率变化
sum(rate(mysql_global_status_commands_total{command=~"insert|update|delete"}[10m])) without (command)

# 最大连接数
mysql_global_variables_max_connections

# 可用连接数
mysql_global_variables_max_connections - mysql_global_status_threads_connected

# 拒绝连接数
mysql_global_status_aborted_connects

# 缓冲池利用率
(sum(mysql_global_status_buffer_pool_pages) by (instance) - sum(mysql_global_status_buffer_pool_pages{state="free"}) by (instance)) / sum(mysql_global_status_buffer_pool_pages) by (instance)

# 2分钟内磁盘读取请求次数的增长率
rate(mysql_global_status_innodb_buffer_pool_reads[2m])

# Slow_queries的增长情况
rate(mysql_global_status_slow_queries[2m])
```



# 5. Snmp Exporter

## 5.1 部署

```bash
mkdir -p /opt/snmp-exporter

apt install snmp-mibs-downloader

docker pull prom/snmp-generator:v0.26.0
docker pull prom/snmp-exporter:v0.26.0

             
# 查看OID对应的名字
snmptranslate -Tz -m /opt/mibs/iDRAC-SMIv2.mib

# 生成配置 snmp.yml
docker run -it -v "${PWD}:/opt/" prom/snmp-generator:v0.26.0 generate

# 启动容器
docker run -d --name snmp-exporter \
    -p 9116:9116 \
    -e TZ="Asia/Shanghai" \
    -v ${PWD}/snmp.yml:/etc/snmp_exporter/snmp.yml \
    --restart=always prom/snmp-exporter:v0.26.0
```



在 prometheus.yml 添加如下内容：

```yaml
scrape_configs:
  ...
  - job_name: 'snmp-exporter-linux'
    static_configs:
      - targets:
          - 192.168.3.100
          - 192.168.3.112
    metrics_path: /snmp
    params:
      auth: [auth_linux]
      module: [linux]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.3.111:9116

```



192.168.3.111:9116?module=server&target=192.168.3.100



curl 'http://192.168.3.200:9116/snmp?module=linux&auth=auth_linux&target=192.168.3.200'

```yaml
 - job_name: 'snmp-exporter'
    scrape_interval: 30s
    scrape_timeout: 15s
    file_sd_configs:
      - files:
        - /etc/prometheus/file_sd/snmp_device.yml
    metrics_path: /snmp
    params:
      community:
        - public
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - source_labels: [module]
        target_label: __param_module
      - source_labels: [auth]
        target_label: __param_auth
      - target_label: __address__
        replacement: 192.168.3.111:9116
```



snmp_device.yml

```yaml
[
    {
        "labels": {
            "module": "linux",
            "auth": "auth_linux",
            "brand": "XFUSION",
            "hostname": "xtwl-server",
            "model": "2488H V5"
        },
        "targets": [
            "192.168.3.100"
        ]
    },
    {
        "labels": {
            "module": "linux",
            "auth": "auth_linux",
            "brand": "Red Hat",
            "hostname": "ubuntu-20-04",
            "model": "KVM"
        },
        "targets": [
            "192.168.3.112"
        ]
    },
    {
        "labels": {
            "module": "linux",
            "auth": "auth_linux",
            "brand": "Red Hat",
            "hostname": "ubuntu-20-04",
            "model": "KVM"
        },
        "targets": [
            "192.168.3.113"
        ]
    }
]
```



动态发现：

```bash
docker run -d --name prometheus \
    -p 9090:9090 \
    -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    -v /opt/prometheus/file_sd/snmp_devices.json:/etc/prometheus/file_sd/snmp_devices.json \
    -v /opt/prometheus/data:/prometheus \
    -e TZ="Asia/Shanghai" \
    --restart=always prom/prometheus:v2.53.2 \
    --web.enable-lifecycle \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention=15d \
    --web.console.libraries=/usr/share/prometheus/console_libraries \
    --web.console.templates=/usr/share/prometheus/consoles
```



# 6. 黑盒监控

## 6.1 概述

BlackBox Expoter 是 Prometheus 官方提供的黑盒监控解决方案，允许用户通过 HTTP、HTTPS、DNS、TCP 及 ICMP 等方式对网络进行探测，这种探测方式常常用于探测一个服务的运行状态，观察服务是否正常运行。

应用程序监控的两种方式：

- 白盒监控：通过获取目标内部信息指标，来监控目标的运行状态。主机监控、容器监控属于此类监控
- 黑盒监控：在程序外部通过探针模拟访问，获取程序的响应指标俩监控程序状态。常见的黑盒监控手段包括 HTTP、HTTPS 探针，DNS 探测、ICMP等。常用于检测站点与服务可用性、连通性，以及访问效率等



黑白盒区别：

- 黑盒监控是以故障为主导，当被监控的服务发生故障时，能快速进行预警。
- 白盒监控则更偏向于主动的和提前预判方式，预测可能发生的故障。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/blackbox-exporter.png)



## 6.2 部署

```yaml
mkdir -p /opt/blackbox_exporter

# config.yml
cat > /opt/blackbox_exporter/config.yml <<EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200, 301, 302]
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      method: GET
EOF

# 启动服务
docker run -d --name blackbox-exporter \
    -v /etc/localtime:/etc/localtime \
    -v /opt/blackbox_exporter/config.yml:/etc/blackbox_exporter/config.yml \
    -p 9115:9115 \
    prom/blackbox-exporter:v0.22.0
```



修改 prometheus.yml 并刷新配置：

```yaml
...
scrape_configs:
  ...
  
  - job_name: 'blackbox_exporter'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
    - targets:
      - http://baidu.com
      - http://cn.bing.com
    relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: 192.168.3.107:9115
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-blackbox-exporter.png)

## 6.3 典型指标

1. HTTP指标：

- `http_status_code`：HTTP响应状态码，如200、404、500等。
- `http_content_length`：HTTP响应内容长度。
- `http_request_duration_seconds`：HTTP请求延迟。
- `http_ssl_expiry_seconds`：HTTPS证书过期时间。

2. DNS指标：

- `dns_lookup_time_seconds`：DNS查询时间。
- `dns_lookup_error`：DNS查询是否出错。

3. TCP指标：

- `tcp_connect_time_seconds`：TCP连接时间。
- `tcp_connection_refused`：TCP连接是否被拒绝。

4. ICMP指标：

- `icmp_response`：ICMP响应是否正常，通常用于检测远程主机是否在线（存活状态）。



# 7. Redis Exporter



## 7.2 典型指标

1. Redis 连接相关指标：
   - `redis_connected_clients`：当前连接的 Redis 客户端数量。
   - `redis_connected_slaves`：当前连接的 Redis 从节点数量。
   - `redis_blocked_clients`：正在等待 Redis 的客户端数量（通常因为 BLPOP、BRPOP、BRPOPLPUSH 等命令阻塞）。
2. Redis 性能相关指标：
   - `redis_instantaneous_ops_per_sec`：每秒执行的操作数，反映 Redis 的处理速度。
   - `redis_latency_spike_duration_seconds`：最近一次延迟峰值持续了多长时间（秒），这是检测性能问题的一个标志。
3. 内存使用相关指标：
   - `redis_mem_used_bytes`：Redis 使用的内存大小（字节）。
   - `redis_mem_fragmentation_ratio`：内存碎片率，当该值远大于 1 时，表示存在较多的内存碎片。
   - `redis_evicted_keys_total`：由于 maxmemory 限制而被淘汰的 key 的总数量。
   - `redis_expired_keys_total`：已过期的 key 的总数量。
4. 持久性相关指标：
   - `redis_rdb_last_save_time_seconds`：自从 Redis 服务器启动以来，最后一次 RDB 持久化的 UNIX 时间戳。
   - `redis_rdb_changes_since_last_save`：自从最后一次 RDB 持久化以来，数据库发生的改变次数。
   - `redis_aof_current_size_bytes`：当前 AOF 文件的大小（字节）。
   - `redis_aof_last_rewrite_time_seconds`：上一次 AOF 重写操作的耗时（秒）。
5. 其他常用指标：
   - `redis_uptime_in_seconds`：Redis 自启动以来的运行时间（秒）。
   - `redis_keyspace_hits_total` 和 `redis_keyspace_misses_total`：键空间命中和未命中的总数，这些可以帮助了解缓存的效率。



# 8. Kafka Exporter

## 8.2 典型指标

### 8.2.1 Kafka集群和Broker相关指标

- `kafka_cluster_id`：Kafka集群的唯一标识符。
- `kafka_broker_id`：Broker的唯一标识符。
- `kafka_broker_version`：Kafka Broker的版本号。
- `kafka_controller_count`：集群中控制器的数量。
- `kafka_broker_requests_total`：Broker接收到的请求总数。

### 8.2.2 主题和分区相关指标

- `kafka_topic_partitions_count`：每个主题的分区数量。
- `kafka_topic_partition_current_offset`：每个分区的当前偏移量。
- `kafka_topic_partition_leader_replica_count`：每个分区的Leader副本数量。
- `kafka_topic_partition_isr_replica_count`：每个分区的ISR（In-Sync Replicas）副本数量。
- `kafka_topic_partition_replica_count`：每个分区的副本总数。
- `kafka_topic_partition_under_replicated_partitions`：分区副本数量少于期望值的分区数。

### 8.2.3 生产者相关指标

- `kafka_producer_request_rate`：生产者发送请求的速率。
- `kafka_producer_request_size_max`：生产者发送的最大请求大小。
- `kafka_producer_record_send_rate`：生产者发送记录的速率。
- `kafka_producer_record_errors_total`：生产者发送失败的消息数量。
- `kafka_producer_batch_size_avg`：生产者批处理大小的平均值。

### 8.2.4 消费者相关指标

- `kafka_consumer_group_current_offset`：消费者组在每个分区上的当前偏移量。
- `kafka_consumer_group_lag`：消费者组在每个分区上的滞后量（即当前偏移量与最后一条消息的偏移量之差）。
- `kafka_consumer_group_membership_count`：每个消费者组中的消费者成员数量。
- `kafka_consumer_fetch_rate`：消费者从Broker拉取消息的速率。
- `kafka_consumer_fetch_size_bytes`：消费者从Broker拉取消息的大小（以字节为单位）。

### 8.2.5 复制和同步相关指标

- `kafka_replica_fetch_manager_max_lag`：每个副本的最大滞后量。
- `kafka_replica_fetch_manager_min_fetch_rate`：副本拉取的最小速率。
- `kafka_replica_leader_elections_per_sec`：每秒发生的Leader选举次数。



