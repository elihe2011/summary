# 1. 简介

## 1.1 目标

在《SRE：Google运维解密》一书中指出，监控系统需要能够有效的支持白盒监控和黑盒监控。通过白盒能够了解其内部的实际运行状态，通过对监控指标的观察能够预判可能出现的问题，从而对潜在的不确定因素进行优化。而黑盒监控，常见的如HTTP探针、TCP探针等，可以在系统或者服务在发生故障时能够快速通知相关人员进行处理。通过建立完善的监控体系，从而达到如下目标：

- 长趋势分析：通过对监控样本数据的持续收集和统计，对监控指标进行长期趋势分析。比如，通过对磁盘空间增长率的判断，可以提前预测未来什么时间点上需要对资源进行扩容。
- 对照分析：两个版本的系统运行资源使用情况的差异如何？在不同容量情况下，系统的并发和负载变化如何？通过监控能够方便对系统进行跟踪和比较
- 告警：当系统出现或即将出现故障时，监控需要需要迅速反应并通知管理员，从而能够对问题进行快速的处理或提前预防问题的发生，避免出现对业务的影响。
- 故障分析与定位：当问题发生后需要对问题进行调查和处理。通过对不同监控及历史数据的分析，能够找到并解决根源问题。
- 数据可视化：通过可视化仪表盘能够直接获取系统的运行状态、资源使用情况、以及服务运行状态等直观信息。



## 1.2 概述

Prometheus 是一款**基于时序数据库的开源监控告警系统**，基本原理是**通过 HTTP 协议周期性抓取被监控服务的状态**，任意服务只要提供对应的 HTTP 接口即可接入监控。不需要任何SDK 或其他集成过程，输出被监控服务信息的 HTTP 接口被叫做 exporter。大部分互联网服务均支持exporter，比如 Haproxy、Nginx、MySQL、Linux 系统信息 (磁盘、CPU、内存、网络等)

Prometheus 非常适合记录**任何纯数字时间序列**。它既适合以机器为中心的监控，也适合监控高度动态的面向服务的体系结构。在微服务世界中，其对多维数据收集和查询的支持是一种特别的优势。 Prometheus 是为可靠性而设计的，在出现故障时，你可以使用该系统快速诊断问题。每个 Prometheus 服务器都是独立的，而不依赖于网络存储或其他远程服务。当基础结构的其他部分损坏时单独依赖它就行，而且不需要设置大量的基础设施来使用它。



**主要特征**：

- 多维数据模型（时序数据由 **metric** 名和一组 **key/value** 组成）
- 提供 **`PromQL`** 查询语言，可利用多维数据完成复杂的查询 

- 不依赖分布式存储，支持服务器**本地存储**
- 基于 HTTP 的 **Pull** 方式采集时间序数据
- 通过 `PushGateway` 可以支持 **Push** 模式推送 **时间序列**

- 可通过 **动态服务发现** 或 **静态配置** 等方式发现目标对象



## 1.3 生态架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-architecture.png)

**组件说明：**

- Prometheus Server：负责对监控数据的采集、存储及查询。
- Grafana：可视化数据统计和监控平台
- Exporter：启动监控数据采集 HTTP 服务，由 Prometheus Server 通过访问该 Exporter 提供的 Endpoint 获取需要采集的监控数据。2类采集方式
  - 直接采集：直接内置了对 Prometheus 监控的支持，如 cAdvisor、Kuberenetes、Etcd、Gokit等，都直接内置了用于向 Prometheus 暴露监控数据的端点
  - 间接采集：原有监控目标不直接支持 Prometheus，需要通过 Prometheus 提供的 Client Library 编写该监控目标的监控采集程序。如 MySQL Exporter, JMX Exporter, Consul Exporter 等

- AlertManager：在 Prometheus Server 中支持基于 PromQL 创建告警规则。如果满足 PromQL 定义的规则，则会产生一条告警，而告警的后续处理流程则由 AlertManager 进行管理
- PushGateway：解决由于网络限制，Prometheus 无法直接采集内网监控数据，改用 PushGateway 中转。可以通过 PushGateway 将内部网络的监控数据主动 Push 到 Gateway中，而 Prometheus Server 采用同样  Pull 方式从 PushGateway 获取监控数据



## 1.4 优势

Prometheus 是一个基于中央化的规则计算、统一分析和告警的新模型。与传统监控系统相比具有如下有点：

- 易于管理

  - 核心部分只有一个单独的二进制文件，不依赖第三方（数据库、缓存等），唯一需要的就是本地磁盘，因此不会有潜在级联故障的风险
  - 基于 Pull 模型，可以在任何地方搭建监控系统。对一些复杂的情况，还支持通过服务发现(Service Discovery) 的能力动态管理监控目标

- 监控服务的内部运行状态

  - 基于 Prometheus 丰富的 Client 库，用户可以轻松的在应用程序中添加对 Prometheus 的支持，从而让用户可以获取服务和应用内部真正的运行状态

- 强大的数据模型

  - 所有采集的监控数据均以指标(metric)的形式保存在内置的时间序列数据库当中(TSDB)，所有样本除了基本的指标名称外，还包含一直用于描述该样本特征的标签

    ```text
    http_request_status{code='200',content_path='/api/path', environment='produment'} => [value1@timestamp1,value2@timestamp2...]
    
    http_request_status{code='200',content_path='/api/path2', environment='produment'} => [value1@timestamp1,value2@timestamp2...]
    ```

  - 每一条时间序列由指标名称 (Metrics Name) 及一直标签(Labels)唯一标识。每条时间序列按照时间的先后顺序存储一系列样本值

  - 表示维度的标签可能源于监控对象的状态，如 `code=404` 或 `content_path=/api/path`。也可能来源于你的环境变量，如 `environment=production`。基于这些 Labels 可以方便地对监控数据进行聚合、过滤、裁剪

- 强大的查询语言 PromQL

  - 通过 PromQL 可以实现对监控数据的查询、聚合。同时它也被应用于数据可视化及告警中
  - 通过 PromQL 可轻松解决如下问题
    - 过去一段时间中 95% 应用延迟时间的分布范围
    - 预测在 4 小时后，磁盘空间占用大致会是什么情况
    - CPU 占有率前 5 位的服务有那些

- 高效

  - 数以百万的监控指标
  - 每秒处理数十万的数据点

- 可扩展

  - 当单实例 Prometheus 处理的任务量过大时，通过使用功能分区(sharding) + 联邦集群(federation) 对其进行扩展

- 易于集成

  - 支持多语言客户端SDK，非常方便在应用程序中集成
  - 支持与其他监控系统集成：Graphite, Statsd, Collected, Scollector, muini, Nagios等
  - 第三方实现的监控数据采集支持：JMX， CloudWatch， EC2， MySQL， PostgresSQL， Haskell， Bash， SNMP， Consul， Haproxy， Mesos， Bind， CouchDB， Django， Memcached， RabbitMQ， Redis， RethinkDB， Rsyslog等等。

- 可视化

  - 自带 Prometheus UI，可方便地直接对数据进行查询，并支持直接以图形化展示数据
  - Grafana 可视化工具，提供更精美的监控页面

- 开放性

  - 使用 Prometheus 的 Client Library 的输出格式不仅支持 Prometheus 的格式化数据，也可以上传支持其他监控系统的格式化数据，如 Graphite



# 2. 部署

## 2.1 应用安装

```bash
# 安装目录
mkdir -p /opt/prometheus/{data,rules}
chown -R 65534:65534 /opt/prometheus/data

# 基础配置
cat > /opt/prometheus/prometheus.yml <<EOF 
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

rule_files:
  - "rules/*_rules.yml"

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: prometheus
EOF

# 启动服务
docker run -d --name prometheus \
	-p 9090:9090 \
	-v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
	-v /opt/prometheus/rules:/etc/prometheus/rules \
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



## 2.2 配置文件

```yaml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']
```

配置项说明：

- global：全局配置

  - scrape_interval：抓取数据的时间间隔

  - evaluation_interval：检测告警规则变更的时间间隔

- alerting：告警配置

- rule_files：告警规则文件路径

- scrape_configs：抓取的目标信息

  - **job_name**：job名称，会生成一个标签{job="prometheus"}，并插入到该任务所有获取指标的标签列中
  - static_configs：静态配置
    - targets：目标主机 IP:Port
  - file_sd_configs：动态文件配置
    - files：文件路径
  - metric_path：抓取路径，默认 /metrics
  - scheme：协议，默认 http
  - params：抓取请求的url参数
    - module: [http_2xxx]
  - basic_auth：
    - username
    - password
  - relabel_config：在抓取前，修改 target 和它的 labels



## 2.3 标签处理

标签过滤和处理的阶段：

- **目标选择**：在 `scrape_configs` 工作的 `relabel_configs` 部分，允许使用 `relabel_config` 对象来选择目标，以刮取和重新标注由任何服务发展机制创建的元数据。
- **指标选择**：在 `scrape_configs` 工作的 `metric_relabel_configs` 部分，允许使用 `relabel_config` 对象来选择应该被写入 Prometheus 存储的标签和系列。
- **远程写入**：在 `remote_write` 配置的 `write_relabel_configs` 部分，允许使用 `relabel_config` 来控制 Prometheus 运送到远程存储的标签和系列。

```yaml
global:
. . .
rule_files:
. . .
scrape_configs:

- job_name: sample_job_1
  kubernetes_sd_configs:
  - . . .
  relabel_configs:
  - source_labels: [. . .]
     . . .
  - source_labels: [. . .]
    . . .
  metric_relabel_configs:
  - source_labels: [. . .]
    . . .
  - source_labels: [. . .]
    . . .

- job_name: sample_job_2
  static_configs:
  - targets: [. . .]
  metric_relabel_configs:
  - source_labels: [. . .]
    . . .

. . .

remote_write:
- url: . . .
  write_relabel_configs:
  - source_labels: [. . .]
    . . .
  - source_labels: [. . .]
    . . .
```



### 2.3.1 relabel_config

通过 `relabel_configs` 来对 Target 标签进行重新标记(relabel) 。 常用于实现两个功能:

- 将来自服务发现的元数据标签中的信息附加到指标的标签上
- 过滤目标，可以针对标签的某个值进行过滤(处理问题一将使用这个功能)

```yaml
scrape_configs:
  - job_name: 'job'                           # 实例名称
    static_configs:
    - targets: ['prometheus-server:9090']     # 监控主机地址
    relabel_configs:                          # 重新标记标签
    - source_labels: ['job']                  # 源标签的名字
      separator: ;                            # 源标签的分隔符，当有多个源标签的值的时候默认使用`;`连接
      regex: (.*)                             # 使用正则匹配元标签的值，.*表示匹配所有
      action: replace                         # 动作，replace动作就是将原来标签的值传给新标签
      replacement: $1                         # 将正则表达式匹配到的结果值引用给新标签
      target_label: idc                       # 新标签的名称
```

action 选项：

- `replace`：根据 regex 的配置匹配 `source_labels` 标签的值，并且将匹配到的值写入到 `target_label` 当中，如果有多个匹配组，则可以使用 `${1}`, `${2}` 确定写入的内容。如果没匹配到任何内容则不对 `target_label` 进行重写， 默认为 `replace`。如果有replacement，则使用replacement替换目标标签
- `keep`：保留 `source_labels` 的值匹配到 `regex` 的目标(targets)或系列(series)，丢弃不匹配的
- `drop`：丢弃 `source_labels` 的值匹配到 `regex` 的目标(targets)或系列(series)，保留不匹配的
- `hashmod`：将 `target_label` 设置为关联的 `source_label` 的哈希模块
- `labelmap`：根据 `regex` 去匹配目标(targets)所有标签的名称 (注意是名称)，并且将捕获到的内容作为为新的标签名称，`regex` 匹配到标签的的值作为新标签的值
- `labeldrop`：将 `regex` 与所有标签名称匹配，**删除所有匹配的标签** (忽略 `source_labels`，适用于所有标签名称)
- `labelkeep`：将 `regex` 与所有标签名称匹配，**删除所有不匹配的标签** (忽略 `source_labels`，适用于所有标签名称)



注意：**重订定义标签并应用后，`__`开头的标签会被删除，要临时存储值用于下一阶段的处理；使用 `__tmp`开头的标签名，不会被 prometheus 使用**



#### 2.3.1.1 replace

```yaml
relabel_configs:
  - action: replace
    source_labels: [<labelname>, ...]
    target_label: <labelname>
    regex: <regex>  # 可选，默认为'(.*)'
    replacement: <string>  # 可选，默认为'$1'
```

核心功能：

- **创建新标签**：当 `target_label` 不存在时，会创建新标签
- **修改现有标签**：当 `target_label` 已存在时，会覆盖其值
- **值转换**：通过 `regex` 和 `replacement` 实现复杂的值转换



注意事项：

- replace 是默认操作
- 当 regex 不匹配时，不会执行替换
- `replacement` 中可以使用 `$1`, `$2` 等引用捕获组
- 多个 `replace` 规则按顺序执行



使用场景：

- 简单标签替换

```yaml
relabel_configs:
  - action: replace
    source_labels: [__address__]
    target_label: instance
```

用途：将 `__address__` 的值复制到 `instance` 标签



- 使用正则表达式提取部分值

```yaml
relabel_configs:
  - action: replace
    source_labels: [__meta_kubernetes_pod_name]
    target_label: pod_name
    regex: '(.+)-[a-z0-9]{5}-[a-z0-9]{5}'
    replacement: '$1'
```

用途：从 Kubernetes Pod 名称中提取主名称部分 (去掉随机后缀)



- 多标签组合

```yaml
relabel_configs:
  - action: replace
    source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_name]
    separator: '/'
    target_label: k8s_pod
```

用途：将命名空间和 Pod 名称组合成一个新标签，格式为 `namespace/podname`



- 值重写：

```yaml
relabel_configs:
  - action: replace
    source_labels: [status]
    regex: '^5..$'
    replacement: 'server_error'
    target_label: status_class
```

用途：将 5xx 状态码统一转换为 "server_error"



- 条件替换：

```yaml
relabel_configs:
  - action: replace
    source_labels: [__meta_kubernetes_pod_annotation_monitoring_group]
    regex: '(.+)'
    target_label: group
    replacement: '$1'
  - action: replace
    source_labels: [__meta_kubernetes_namespace]
    target_label: group
    regex: '(.+)'
    replacement: '$1'
    # 只有当前面的替换没发生时才会执行
    # (即没有 monitoring_group 注解时使用命名空间作为 group)
```



- 与其它操作组合

```yaml
relabel_configs:
  - action: replace
    source_labels: [__address__]
    regex: '([^:]+)(?::\d+)?'
    replacement: '${1}:9090'
    target_label: __address__
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
```



#### 2.3.1.2 keep

用于**选择性保留**符合特定条件的 metrics，丢弃所有其他不匹配的

```yaml
relabel_configs:
  - action: keep
    source_labels: [<labelname>, ...]
    regex: <regex>  # 必须指定
    [ separator: <string> ]  # 可选，默认为';'
```

核心功能：

- **过滤指标**：只保留匹配指定正则表达式的指标
- **条件判断**：基于一个或多个标签的值进行过滤
- **前置过滤**：通常在抓取前应用，减少不必要的数据收集



注意事项：

- keep 是白名单机制，只有匹配的指标会被保留；而 drop是黑名单机制
- 多个 keep 规则是 AND 关系，必须同时满足才会被保留



| 特性     | keep                 | drop                 |
| -------- | -------------------- | -------------------- |
| 逻辑     | 白名单（保留匹配的） | 黑名单（丢弃匹配的） |
| 性能影响 | 通常更好（早期过滤） | 可能需要处理更多指标 |
| 使用场景 | 明确知道需要保留什么 | 明确知道需要排除什么 |
| 默认行为 | 不匹配=丢弃          | 不匹配=保留          |



使用场景：

- 保留规则

```yaml
relabel_configs:
  - action: keep
    source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    regex: "true"
```

用途：只保留带有 `prometheus.io/scrape=true` 注释的 Kubernetes Pod 指标



- 多标签条件判断

```yaml
relabel_configs:
  - action: keep
    source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_annotation_monitoring]
    regex: "(production|staging);enabled"
    separator: ";"  # 明确指定分隔符
```

用途：只保留命名空间为 "production" 或 "staging"，且带有 `monitoring=enabled` 注释的 Pod



- 基于服务发现元数据过滤

```yaml
relabel_configs:
  - action: keep
    source_labels: [__meta_consul_service]
    regex: "(nginx|postgres|redis).*"
```

用途：只保留 Consul 服务发现中服务名以 nginx、postgres 或 redis 开头的服务



- 与 `replace` 组合

```yaml
relabel_configs:
  - action: keep
    source_labels: [__meta_kubernetes_pod_label_app]
    regex: "critical-app"
  - action: replace
    source_labels: [__meta_kubernetes_pod_name]
    target_label: pod_name
```

用途：先保留标签为 `app=critical` 的Pod，然后对这些 Pod 的指标添加 pod_name 标签



- 反向保留（通过否定正则）

```yaml
relabel_configs:
  - action: keep
    source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    regex: "(?!false).*"  # 保留所有值不为"false"的
```



- 复杂条件组合

```yaml
relabel_configs:
  - action: keep
    source_labels: [
        __meta_kubernetes_namespace,
        __meta_kubernetes_pod_label_tier,
        __meta_kubernetes_pod_annotation_monitoring
    ]
    regex: "production;frontend|backend;enabled"
    separator: ";"
```



#### 2.3.1.3 labeldrop

用于删除特定标签，不会删除整个 metrics，只是移除特定标签

```yaml
relabel_configs:
  - action: labeldrop
    regex: <regular_expression>  # 必须指定
```



核心功能：

- **标签删除**：删除匹配正则表达式的标签
- **不影响指标**：时间序列本身会被保留
- **元数据清理**：常用于删除不必要的或敏感的标签



注意事项：

- 执行顺序：`labeldrop` 通常在 `labelmap` 或 `replace` 之后执行
- 不可逆操作：被删除的标签无法在后续处理中被恢复
- 性能影响：删除多余标签可以减少存储空间和提高查询效率
- 正则表达式：使用精确的正则以避免意外删除需要的标签



使用场景：

- 删除临时或调试标签

```yaml
relabel_configs:
  - action: labeldrop
    regex: "temp_.*"  # 删除所有以temp_开头的标签
```



- 清理 Kuberenetes 元数据标签

```yaml
relabel_configs:
  - action: labeldrop
    regex: "__meta_kubernetes_pod_label_(.+)"  # 删除K8s自动生成的pod标签
```



- 删除敏感信息

```yaml
relabel_configs:
  - action: labeldrop
    regex: "(password|token|key)"  # 删除可能包含敏感信息的标签
```



- 保留特定标签 (反向操作)

```yaml
relabel_configs:
  - action: labelkeep
    regex: "(instance|job|env)"  # 只保留这些标签，删除其他所有标签
```



- 多节点标签清理

```yaml
relabel_configs:
  - action: labeldrop
    regex: "__meta_kubernetes_.*"  # 先删除所有K8s元数据标签
  - action: labeldrop
    regex: "tmp_.*"  # 再删除临时标签
```



- 与服务发现结合

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)  # 先映射节点标签
  - action: labeldrop
    regex: "__meta_kubernetes_.*"  # 然后删除原始元数据标签
```



#### 2.3.1.4 labelmap

用于批量重命名标签，适合处理服务发现系统生成的大量元数据标签

```yaml
relabel_configs:
  - action: labelmap
    regex: <regular_expression>  # 必须指定
    replacement: <string>       # 可选，默认为 '$1'
```



核心功能：

- **批量标签重命名**：基于正则表达式匹配和重命名多个标签
- **元数据标签转换**：常用于将服务发现系统的元数据标签转为标准标签
- **模式匹配**：使用有正则捕获组提取签名部分



注意事项：

- 执行顺序：通常在其他操作 (replace， keep等) 之前执行

- 非破坏性：原始标签会保留，除非显示使用 `labeldrop` 删除
- 冲突解决：当新标签名已存在时会被覆盖



使用场景：

- Kubernetes 元数据标签转换

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)  # 将K8s Pod标签转为普通标签
```

转换结果：

- `__meta_kubernetes_pod_label_app` → `app`
- `__meta_kubernetes_pod_label_version` → `version`



- Consul 服务标签处理

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_consul_service_metadata_(.+)
```



- 添加前缀/修改命名空间

```yaml
relabel_configs:
  - action: labelmap
    regex: (.+)
    replacement: k8s_$1  # 给所有标签添加k8s_前缀
```



- 选择性重命名

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(region|zone)  # 只转换region和zone标签
```



- 多阶段处理

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - action: labeldrop
    regex: "__meta_kubernetes_.+"  # 转换后删除原始元数据标签
```



- 复杂替换模式

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_([^_]+)_(.+)
    replacement: ${1}_${2}  # 将__meta_xxx_yyy转为xxx_yyy
```



#### 2.3.1.3 总结

|操作|作用对象|结果|常用场景                         |
|---|-----|---|---|
|`keep`|整个时间序列|保留匹配的指标|保留需要的指标 |
|`drop`|整个时间序列|丢弃匹配的指标|丢弃不需要的指标 |
|`labelkeep`|标签|只保留匹配的标签|严格限制标签集        |
|`labeldrop`|标签|删除匹配的标签|清理元数据、敏感信息     |
|`labelmap`|标签|批量标签重命名|基于模式匹配的标签名转换 |
|`replace`|标签值|修改或创建标签值|标签值转换、标准化     |




### 2.3.2 metric_relabel_configs

`metric_relabel_configs` 是 Prometheus 在保存数据前的最后一步标签重新编辑，其用途如下：

- 删除不必要的指标
- 从指标中删除敏感或不需要的标签
- 添加、编辑或修改指标的标签值或标签格式



与 `relabel_configs` 的区别：

| 特性     | relabel_configs        | metric_relabel_configs |
| -------- | ---------------------- | ---------------------- |
| 执行阶段 | 服务发现后，抓取前     | 抓取后，存储前         |
| 主要用途 | 控制抓取目标           | 控制存储内容           |
| 可见数据 | 只能看到服务发现元数据 | 能看到完整的指标和标签 |
| 性能影响 | 影响目标选择           | 影响存储内容           |



```yaml
scrape_configs:
  - job_name: 'my_job'
    metric_relabel_configs:
      - action: <action_type>
        source_labels: [<labelname>, ...]
        target_label: <labelname>
        regex: <regex>  # 默认'(.*)'
        replacement: <string>  # 默认'$1'
```



使用场景：

- 过滤不需要的指标

```yaml
metric_relabel_configs:
  - action: drop
    source_labels: [__name__]
    regex: 'go_memstats_.*'  # 丢弃所有go_memstats开头的指标
```



- 删除敏感标签

```yaml
metric_relabel_configs:
  - action: labeldrop
    regex: 'password|token|key'  # 删除敏感标签
```



- 指标重命名

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'external_(.*)'
    target_label: __name__
    replacement: 'prefix_$1'  # external_metric → prefix_metric
```



- 基于标签值过滤

```yaml
metric_relabel_configs:
  - action: keep
    source_labels: [env]
    regex: 'production|staging'  # 只保留生产环境和预发环境的指标
```



- 动态标签生成

```yaml
metric_relabel_configs:
  - source_labels: [path]
    regex: '/api/(v\d+)/.*'
    target_label: api_version
    replacement: '$1'
```



- 指标聚合准备

```yaml
metric_relabel_configs:
  - source_labels: [instance]
    regex: '([^:]+):\d+'
    target_label: host
    replacement: '$1'  # 从instance中提取主机名
```



- 跨标签计算

```yaml
metric_relabel_configs:
  - source_labels: [request_size, response_size]
    regex: '(.+);(.+)'
    target_label: total_size
    replacement: '${1}${2}'  # 合并两个大小值
```



## 2.4 配置更新

两种配置更新方法：

- 重启 prometheus
- 动态更新




配置动态更新步骤：

- 启动带参数 `--web.enable-lifecycle`

```bash
prometheus --config.file=/usr/local/etc/prometheus.yml --web.enable-lifecycle
```

- 更新配置

- 调用接口，动态更新配置

```bash
curl -v -X POST 'http://localhost:9090/-/reload'
```

​    

动态更新原理：

- Prometheus 在 web 模块中，注册了一个 handler：

```go
if o.EnableLifecycle {
    router.Post("/-/quit", h.quit)
    router.Put("/-/quit", h.quit)
    router.Post("/-/reload", h.reload)
    router.Put("/-/quit", h.reload)
}
```

- 通过 `h.reload` 这个 handler方法实现

```go
func (h *Handler) reload(w http.ResponseWriter, r *http.Request) {
    rc := make(chan error)
    
    h.reloadCh <- rc
    
    if err := <- rc; err != nil {
        http.Error(w, fmt.Sprintf("failed to reload config: %s", err),
                  http.StatusInternalServerError)
    }
}
```

- 在 main 函数中监听这个 channel， 收到信号则做配置的 reload，将新配置加载到内存

```go
func main() {
    ...
    select {
        ...
        case rc:= <- webHandler.Reload():
        if err := reloadConfig(cfg.configFile, cfg.enableExpandExternalLabels, 
                               cfg.tsdb.EnableExemplarStorage, logger,
                               noStepSubqueryInterval, reloaders...); err != nil {
            level.Error(logger).Log("msg", "Error reloading config", "err", err)
            rc <- err
        } else {
            rc <- nil
        }
    }
}
```



# 3. 工作原理

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-workflow.png)

## 3.1 服务发现

job：被监控的服务

target：被监控服务的实例

被监控服务的注册，就是在 Prometheus 中注册一个 Job 和其所有的 target，注册分两种：

- 静态注册：将服务的 IP 和抓取指标的端口号配置在 prometheus.yaml 文件的 scrape_config 下：

  ```yaml
  scrape_configs:
   - job_name: "prometheus"
     static_configs:
     - targets: ["localhost:9090"]
  ```

- 动态注册：在 scrape_configs 下配置服务发现的地址和服务名，由 prometheus 去该地址，动态发现实例列表。支持 consul, dns, k8s 等多种服务发现机制

  ```yaml
  scrape_configs:
  - job_name: "node_export_consul"
    metrics_path: /node_metrics
    scheme: http
    consul_sd_configs:
     - server: localhost:8500
       services:
       - node_exporter
  ```



Prometheus 支持的服务发现协议：

```xml
<azure_sd_config>
<consul_sd_config>
<digitalocean_sd_config>
<docker_sd_config>
<dockerswarm_sd_config>
<dns_sd_config>
<ec2_sd_config>
<openstack_sd_config>
<file_sd_config>
<gce_sd_config>
<hetzner_sd_config>
<http_sd_config>
<kubernetes_sd_config>
<kuma_sd_config>
<lightsail_sd_config>
<linode_sd_config>
<marathon_sd_config>
<nerve_sd_config>
<serverset_sd_config>
<triton_sd_config>
<eureka_sd_config>
<scaleway_sd_config>
<static_config>
```



## 3.2 指标收集

每一个被 Prometheus 监控的服务都是一个 Job， Prometheus 为这些 Job 提供了官方的 SDK，利用这个 SDK 可以自定义并导出自己的业务指标，也可以使用 Prometheus 官方提供的各种常用组件和中间件的 Exporter （比如 MySQL等）

对于短时间执行的脚本任务或者不好直接 Pull 指标的服务，Prometheus 提供了 PushGateway 网关给这些任务将服务指标主动 Push 到网关，然后由 Prometheus 从 网关中 Pull。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-pull-push.png)

**Pull 模型**：监控服务主动拉取被监控服务得指标。被监控的服务一般通过主动暴露 metrics 端口或通过 exporter 的方式暴露指标

**Push 模型**：被监控服务主动将指标推送到监控服务，可能需要对指标做协议适配，必须得符合监控服务要求得指标格式

Prometheus 中的指标抓取，采用 Pull 模型，默认一分钟抓取一次指标，通过 Pull Exporter 或 Pull  PushGateway 暴露指标。

```yaml
global:
  scrape_interval: 15s
```



## 3.3 数据查询

抓取到的指标会被以时间序列的形式保存到内存中，并定时刷到磁盘上（默认2小时回刷一次）。并且为了防止 Prometheus 发生崩溃或重启时能够恢复数据，会读一个预写日志来恢复数据。

指标的抓取后，会存储在内置的时序数据库中，提供 PromSQL 查询语言做指标的查询，可以在 WebUI 上通过 PromSQL 可视化查询指标，也可通过第三方可视化工具 如  Grafana查询



## 3.4 可视化

自带 Web-UI 支持图表展示 ，但功能及界面较简陋，建议接入到grafana进行展示



## 3.5 聚合告警

提供 AlertManager 基于 PromSQL 做系统的监控告警，当 PromSQL 查询出来的指标超过阈值时，Prometheus 会发送一条告警信息到 AlertManager，然后由它将告警下发到配置的邮箱或告警平台上。



# 4. Metric 指标

## 4.1 数据模型

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-model.png)

Prometheus 采集的所有指标都以时间序列的形式进行存储，每个时间序列有三部分组成：

- 指标名和指标标签集合：`metric_name{<label1=v1>,<label2=v2>...}`
  - 指标名：表示这个指标是监控哪一方面的状态，比如 http_request_total 表示请求数量
  - 指标标签：描述所选指标的维度，比如 http_request_total 下，有请求状态码 code = 200/400/500，请求方式 method = get/post等
- 时间戳：描述当前时间序列的时间，单位：毫秒
- 样本值：当前监控指标的具体数值



### 4.1.1 样本

Prometheus 会将所有采集到的样本数据以时间序列(time-series)的方式保存在内存数据库中，并定时持久化到磁盘。time-series 是按照时间戳和值的序列顺序存放的，称之为向量(vector)。每条 time-series 通过指定名称 (metrics name) 和 一组标签集(label-set)命名。

可以将 time-series 理解位一个以时间为 Y 轴的数字矩阵：

```text
  ^
  │   . . . . . . . . . . . . . . . . .   . .   node_cpu{cpu="cpu0",mode="idle"}
  │     . . . . . . . . . . . . . . . . . . .   node_cpu{cpu="cpu0",mode="system"}
  │     . . . . . . . . . .   . . . . . . . .   node_load1{}
  │     . . . . . . . . . . . . . . . .   . .  
  v
    <------------------ 时间 ---------------->
```

在 time-series 中的每一个点称为一个样本 (sample)，样本由三部分组成：

- 指标(metric)：指标名称和描述该样本特征的标签集
- 时间戳(timestamp)：精确到毫秒
- 样本值(value)：float64浮点型

```text
<--------------- metric ---------------------><-timestamp -><-value->
http_request_total{status="200", method="GET"}@1434417560938 => 94355
http_request_total{status="200", method="GET"}@1434417561287 => 94334

http_request_total{status="404", method="GET"}@1434417560938 => 38473
http_request_total{status="404", method="GET"}@1434417561287 => 38544

http_request_total{status="200", method="POST"}@1434417560938 => 4748
http_request_total{status="200", method="POST"}@1434417561287 => 4785
```



### 4.1.2 指标

```text
<metric name>{<label name>=<label value>, ...}
```

**指标名称**：反映被监控样本的含义，只能由 ASCII 字符、数字、下划线及冒号组成 `[a-zA-Z_:][a-zA-Z0-9_:]*`

**标签**：反应样本的特征维度，Prometheus可通过维度对样本数据进行过滤、聚合等。只能由 ASCII 字符、数字及下划线组成 `[a-zA-Z_][a-zA-Z0-9_]`。其中以 `__` 作为前缀的标签，是系统保留的关键字，仅系统内部使用

**标签值**：可以饱和任何 Unicode 编码的字符



在 Prometheus 底层限制中指标名称实际上以 `__name__=<metric name>` 形式保存在数据库中，因此以下两个方式均表示同一条 time-series：

```text
api_http_requests_total{method="POST", handler="/messages"}

{__name__="api_http_requests_total"，method="POST", handler="/messages"}
```



## 4.2 指标类型

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-types.png)

### 4.2.1 Counter

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-counter.png)

**计数器**，用于记录请求总数、错误总数等。常见的监控指标有 http_requests_total，node_cpu_seconds_total 等

使用示例：

- 通过 rate() 函数获取 HTTP 请求量的增长率：

  ```text
  rate(http_requests_total[5m])
  ```

- 查询当前系统中，访问量前10的 HTTP 地址

  ```text
  topk(10, http_requests_total)
  ```


![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-counter-instance.png)



### 4.2.2 Gauge

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-gauge.png)

**仪表盘**，系统的瞬时状态。常见的监控指标有 node_memory_MemFree_bytes，node_memory_MemAvailable_bytes。

使用示例：

- 查看系统当前内存状态

  ```
  node_memory_MemFree_bytes
  ```

- 通过 delta() 获取样本在一段时间内的变化情况，计算内存在两小时内的变化

  ```text
  delta(node_memory_MemAvailable_bytes{instance="172.16.8.158:9100"}[2h])
  ```

- 通过 predict_linear() 对数据变化趋势进行预测，预测系统磁盘空间在4小时之后的剩余情况

  ```text
  predict_linear(node_filesystem_files{job="cvm"}[1h], 4 * 3600)
  ```


![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-gauge-instance.png)



### 4.2.3 Histogram

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-histogram.png)

**直方图**，随机正态分布数据，可观察到指标在各个不同的区间范围的分布情况。表示样本数据的分布情况，通常用于统计请求的耗时、大小等。它提供了多个时间序列，包括_sum（总和）、_count（总数）以及多个_bucket（分桶统计）。

在大多数情况，人们倾向于使用某些量化指标的平均值，如CPU的平均使用率、页面的平均响应时间等。这种方式的问题和明显，以系统API调用的平均响应时间为例：如果大多数API都维持在100ms的响应时间范围内，而个别请求的响应时间需要5s，那么就会导致某些 web 页面的响应时间落到中位数的情况，这种现象被称为长尾问题。

为区分是平均的慢还是长尾的慢，最简单的方式就是按照请求延迟的范围进行分组。例如，统计延迟在 0~10ms, 10~20ms 之间的请求数各多少，通过这种方式可以快速分析系统慢的原因。Histogram 和 Summary 就是为了解决这样的问题，通过这两种监控指标，快速了解监控样本的分布情况。

直方图对观察结果（通常是请求持续时间或响应大小等）进行采样，并将它们计数到可配置的存储桶中。它还提供所有观察值的总和。

基本指标名称为 `<basename>` 的直方图在抓取过程中显示多个时间序列：

- **存储桶累积计数器**： `<basename>_bucket{le="<upper inclusive bound>"}`
- **所有观察值总和**： `<basename>_count`
- **已观察到的事件计数**：`<basename>_count`（与上面的 `<basename>_bucket{le="+Inf"}` 相同）

使用 `histogram_quantile()` 函数从直方图甚至直方图聚合中计算分位数。直方图也适用于计算 *Apdex 分数*。在对存储桶进行操作时，请记住直方图是累积的。

```text
# HELP prometheus_tsdb_compaction_chunk_range Final time range of chunks on their first compaction
# TYPE prometheus_tsdb_compaction_chunk_range histogram
prometheus_tsdb_compaction_chunk_range_bucket{le="100"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="6400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="25600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="102400"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="409600"} 0
prometheus_tsdb_compaction_chunk_range_bucket{le="1.6384e+06"} 260
prometheus_tsdb_compaction_chunk_range_bucket{le="6.5536e+06"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="2.62144e+07"} 780
prometheus_tsdb_compaction_chunk_range_bucket{le="+Inf"} 780
prometheus_tsdb_compaction_chunk_range_sum 1.1540798e+09
prometheus_tsdb_compaction_chunk_range_count 780
```

观察请求耗时在各个桶的分布。Histogram 是累计直方图，即每个桶的只有上区间。如图表示小于 0.1 毫秒的请求数量是 18173 个，小于 0.2 毫秒 的请求为 18182 个。桶 le="0.2" 包含了桶 le="0.1" 的所有数据，0.1~0.2毫秒之间的请求量，两桶相减即得。 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-histogram-instance.png)



### 4.2.4 Summary

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-summary.png)

**摘要**，随机正态分布数据，用来做统计分析的，与 Histogram 的区别在于，Summary 直接存储的就是百分比

类似于Histogram，但更注重于分位数的计算。它同样提供了_sum、_count以及多个quantile（分位数）。虽然它还提供观察结果的总数和所有观察值的总和，但它会在滑动时间窗口内计算可配置的分位数。

基本指标名称为 `<basename>` 的摘要会在抓取过程中显示多个时间序列：

- 流式传输观察到的事件的 **φ-分位数** (0 ≤ φ ≤ 1)： `<basename>{quantile="<φ>"}`
- 所有观察值**总和**： `<basename>_sum`
- 已观察到的事件**计数**，显示为 `<basename>_count`

```text
# HELP prometheus_tsdb_wal_fsync_duration_seconds Duration of WAL fsync.
# TYPE prometheus_tsdb_wal_fsync_duration_seconds summary
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.5"} 0.012352463
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.9"} 0.014458005
prometheus_tsdb_wal_fsync_duration_seconds{quantile="0.99"} 0.017316173
prometheus_tsdb_wal_fsync_duration_seconds_sum 2.888716127000002
prometheus_tsdb_wal_fsync_duration_seconds_count 216
```

从上面的样本中可以得知当前Prometheus Server进行wal_fsync操作的总次数为216次，耗时2.888716127000002s。其中中位数（quantile=0.5）的耗时为0.012352463，9分位数（quantile=0.9）的耗时为0.014458005s。

Summary 的百分比由客户端计算好，Prometheus 只负责抓取，可通过内置函数 histogram_quantile 在服务端计算

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-metric-type-summary-instance.png)

## 4.3 存储时间

Prometheus 偏向于短期监控和问题的及时告警发现，它不会保留长期的Metric数据
默认情况下，只会在数据库中保留15天的时间序列数据。如果需要保留更长时间的数据，需要将Prometheus数据写入外部数据存储。



# 5. PromQL

## 5.1 基本操作

### 5.1.1 查询时间序列

```text
# 查询指标的所有时间序列
http_requests_total
http_requests_total{}

# 携带过滤条件
http_requests_total{code="401"}

# 排除条件
http_requests_total{instance!="localhost:9090"}

# 正则条件
http_requests_total{environment=~"staging|testing|development", method!="GET"}
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/promql-basic.png)



### 5.1.2 范围查询

```text
http_requests_total{code="200"}[5m]
http_requests_total{code="200"} offset 1h  
http_requests_total{code="200"}[5m] offset 1h  
```

通过区间向量表达式查询到的结果称为**区间向量**，PromQL支持的时间单位：s, m, h, d, w, y



### 5.1.3 时间位移操作

通过 offset 获取前5分钟、前一天的数据

```text
http_requests_total{}      # 瞬时向量表达式，当前最新的数据
http_requests_total{}[5m]  # 区间向量表达式，当前时间为基准，5分钟内的数据

http_requests_total{}[5m] offset 5m
http_requests_total{}[1d] offset 1d
```



### 5.1.4 集合操作

样本特征标签不唯一的情况下，通过 PromQL 查询数据，会返回多条满足这些特征维度的时间序列，而聚合操作可用来对这些时间序列进行处理，形成一条新的时间序列

```text
# 所有 http 请求总量
sum(http_requests_total)

# 按 mode 计算主机 CPU 的平均使用率
avg(node_cpu_seconds_total) by (mode)

# 查询各主机的 CPU 使用率
sum(sum(irate(node_cpu_seconds_total{mode!='idle'}[5m])) / sum(irate(node_cpu_seconds_total[5m]))) by (instance)
```



### 5.1.5 标量和字符串

除了使用瞬时向量表达式和区间向量表达式外，PromQL还支持标量(Scalar)和字符串(String)

- 标量：一个浮点数，没有时序。`count(http_requests_total)` 返回的依旧是瞬时向量，可以通过内置函数 scalar() 将单个瞬时向量转换为标量
- 字符串：直接返回字符串



## 5.2 操作符

### 5.2.1 数学运算

支持的数学运算符：`+`, `-`, `*`, `/`, `%`, `^`

```text
node_disk_written_bytes_total{device="dm-1"} / (1024 * 1024)

node_disk_written_bytes_total{device="dm-1"} + node_disk_read_bytes_total{device="dm-1"}
```



### 5.2.2 布尔运算

支持的布尔运算符：`==`、`!=`、`>`、`<`、`>=`、`<=`

使用 bool 修饰符改变布尔运算符行为：true(1)，false(0)

```text
# 大于1000时，返回1
http_requests_total > bool 1000

# 两个标量之间的布尔运算，必须使用 bool 修饰符
2 == bool 2     # 返回1
```



### 5.2.3 集合运算符

瞬时向量表达式能够获取一个包含多个时间序列的集合，称之为瞬时向量。可以在两个瞬时向量之间进行相应的集合操作，支持如下操作符：

- v1 and v2：两个向量的交集
- v1 or v2：两个向量的并集
- v1 unless v2：v1中没有与v2匹配的元素集合



### 5.2.4 操作符优先级

优先级由高到低，依次为：

- `^`
- `*, /, %`
- `+, -`
- `==, !=, <, <=, >, >=`
- `and, unless`
- `or`



### 5.2.5 匹配模式

向量与向量之间进行运算操作时会基于默认的匹配规则：依次找到与左边向量元素匹配（标签完全一致）的右边向量元素进行运算，如果没有找到，则直接丢弃

**一对一匹配(one-to-one)**：从操作符的两边表达式获取瞬时变量依次比较并找到唯一配（标签完全一致）的样本值

```text
vector1 <operator> vector2
```

在操作符两边表达式标签不一致的情况下，可使用 on (label list) 或 ignoring (label list) 来修饰标签的匹配行为

```text
<vector expr> <bin-op> ignoring(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) <vector expr>
```

示例样本：

```text
method_code:http_errors:rate5m{method="get", code="500"}  24
method_code:http_errors:rate5m{method="get", code="404"}  30
method_code:http_errors:rate5m{method="put", code="501"}  3
method_code:http_errors:rate5m{method="post", code="500"} 6
method_code:http_errors:rate5m{method="post", code="404"} 21

method:http_requests:rate5m{method="get"}  600
method:http_requests:rate5m{method="del"}  34
method:http_requests:rate5m{method="post"} 120
```

获取过去5分钟内，HTTP 请求状态码为 500 的所在请求中的比例：

```text
method_code:http_errors:rate5m{code="500"} / ignoring(code) method:http_requests:rate5m
```

计算结果：

```text
{method="get"}  0.04            //  24 / 600
{method="post"} 0.05            //   6 / 120
```



**多对一和一对多**：”一“的每个向量元素可以与”多“的多个元素匹配。使用 group 修饰符：group_left 或 group_right 来确定哪一个向量具有更高的基数

```text
<vector expr> <bin-op> ignoring(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> ignoring(<label list>) group_right(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_right(<label list>) <vector expr>
```

使用表达式：

```text
method_code:http_errors:rate5m / ignoring(code) group_left method:http_requests:rate5m
```

该表达式中，左向量`method_code:http_errors:rate5m`包含两个标签method和code。而右向量`method:http_requests:rate5m`中只包含一个标签method，因此匹配时需要使用ignoring限定匹配的标签为code。 在限定匹配标签后，右向量中的元素可能匹配到多个左向量中的元素 因此该表达式的匹配模式为多对一，需要使用group修饰符group_left指定左向量具有更好的基数。

运算结果：

```
{method="get", code="500"}  0.04            //  24 / 600
{method="get", code="404"}  0.05            //  30 / 600
{method="post", code="500"} 0.05            //   6 / 120
{method="post", code="404"} 0.175           //  21 / 120
```



## 5.3 集合操作

内置集合操作函数：

- sum
- min
- max
- avg
- stddev 标准差
- stdvar 标准方差
- count
- count_values  对 value 进行计数
- bottomk 后 n 条时序
- topk 前 n 条时序
- quantile 分位数

聚合操作语法：

```text
<aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
```

其中：只有`count_values`, `quantile`, `topk`, `bottomk` 支持参数

without： 用于从计算结果中移除列举的标签，保留其他标签

by：与 without 相反，结果向量中只保留列出的标签，其余标签移除

```
sum(http_requests_total) without (instance)

sum(http_requests_total) by (code,handler,job, method)
```



示例：

```text
# HTTP 请求总量
sum(http_requests_total)

sum(prometheus_http_requests_total{}) without (code,handler,job) 
sum(prometheus_http_requests_total{}) by (instance) 

// 整个服务的QPS
sum(rate(demo_api_request_duration_seconds_count{job="demo", method="GET", status="200"}[5m]))

// 具体接口的QPS
sum(rate(demo_api_request_duration_seconds_count{job="demo", method="GET", status="200"}[5m])) by(path)

// 排除接口
sum(rate(demo_api_request_duration_seconds_count{job="demo", method="GET", status="200"}[5m])) without(path)

max(prometheus_http_requests_total{})
min(prometheus_http_requests_total{})
avg(prometheus_http_requests_total)

# 为每个唯一的样本值输出一个时间序列，并包含一个额外的标签
count_values("count", http_requests_total)

# 请求数前5位的序列样本
topk(5, http_requests_total)

# 计算当前样本数据分布情况 quantile(φ, express)其中0 ≤ φ ≤ 1
quantile(0.5, http_requests_total)  # 找到当前样本数据中的中位数
```



## 5.4 内置函数

### 5.4.1 计算 Counter 指标增长率

```
# increase 获取区间向量中第一个后最后一个样本并返回其增长量
increase(node_cpu_seconds_total[2m]) / 120    # 两分钟的增长量，除以120s得到最近两分钟的平均增长率

# rate 直接计算区间向量在时间窗口内的平均增长率
rate(node_cpu_seconds_total[2m])    # 效果同上

# irate 同样计算区间内的增长率，但其反映出瞬时增长率，可用于避免时间窗口范围内的”长尾问题“，具有更好的灵敏度
irate(node_cpu_seconds_total[2m])
```

**rate**：`Counter` 指标的平均变化速率。可用于求某个时间区间内的请求速率，即QPS

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-rate.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-rate-instance.png)

**irate**：更高的灵敏度，通过时间区间中最后两个样本数据来计算区间向量的增长速率，解决 rate() 函数无法处理的突变

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-irate.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-irate-instance.png)



### 5.4.2 预测 Gauge 指标变化趋势

```text
# predict_linear 函数可以预测时间序列在n秒后的值。它基于简单线性回归的方式，对时间窗口内的样本数据进行统计，从而对时间序列的变化趋势做成预测
predict_linear(node_filesystem_free{job="node"}[2h], 4 * 3600) < 0  # 基于2小时的样本数据，预测主机可用磁盘是否在4小时后被占满
```



### 5.4.3 统计 Histogram 指标的分位数

区别于 Summary 直接在客户端计算了数据分布的分位数情况，Histogram 的分位数计算需要通过 `histogram_quantile(φ float, b instant-vector)`函数进行计算。其中φ（0<φ<1）表示需要计算的分位数.

指标http_request_duration_seconds_bucket：

```text
# HELP http_request_duration_seconds request duration histogram
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.5"} 0
http_request_duration_seconds_bucket{le="1"} 1
http_request_duration_seconds_bucket{le="2"} 2
http_request_duration_seconds_bucket{le="3"} 3
http_request_duration_seconds_bucket{le="5"} 3
http_request_duration_seconds_bucket{le="+Inf"} 3
http_request_duration_seconds_sum 6
http_request_duration_seconds_count 3
```

计算中位分位数：

```text
histogram_quantile(0.5, http_request_duration_seconds_bucket)
```



### 5.4.4 动态标签替换

label_replace 为时间序列添加额外的标签：

```text
label_replace(v instant-vector, dst_label string, replacement string, src_label string, regex string)
```

label_join 将时间序列中的多个标签 src_label 的值，通过 separator 作为连接符写入到一个新的标签 dst_label 中

```text
label_join(v instant-vector, dst_label string, separator string, src_label_1 string, src_label_2 string, ...)
```

示例：增加host标签

```text
# 原始数据
up{instance="localhost:8080",job="cadvisor"}    1
up{instance="localhost:9090",job="prometheus"}    1
up{instance="localhost:9100",job="node"}    1

# 替换操作
label_replace(up, "host", "$1", "instance",  "(.*):.*")

# 输出结果
up{host="localhost",instance="localhost:8080",job="cadvisor"}    1
up{host="localhost",instance="localhost:9090",job="prometheus"}    1
up{host="localhost",instance="localhost:9100",job="node"} 1
```



# 6. HTTP API

## 6.1 瞬时数据查询

查询接口：`GET /api/v1/query`

URL请求参数：

- `query`：PromQL 表达式
- `time`：时间戳，可选，默认当前系统时间
- `timeout`：超时时间，可选

```bash
$ curl 'http://172.16.7.181:30090/api/v1/query?query=up\{job="cvm"\}'

{
    "status": "success",
    "data": {
        "resultType": "vector",
        "result": [
            {
                "metric": {
                    "__name__": "up",
                    "instance": "172.16.8.158:9100",
                    "job": "cvm"
                },
                "value": [
                    1725531748.123,
                    "1"
                ]
            }
        ]
    }
}
```



## 6.2 响应数据类型

返回数据格式：

```json
{
    "resultType": "matrix" | "vector" | "scalar" | "string",
    "result": <value>
}
```

- 瞬时向量(vector)：

  ```json
  [
    {
      "metric": { "<label_name>": "<label_value>", ... },
      "value": [ <unix_time>, "<sample_value>" ]
    },
    ...
  ]
  ```

- 区间向量(matrix)

  ```json
  [
    {
      "metric": { "<label_name>": "<label_value>", ... },
      "values": [ [ <unix_time>, "<sample_value>" ], ... ]
    },
    ...
  ]
  ```

- 标量(scalar)

  ```json
  [ <unix_time>, "<scalar_value>" ]
  ```

- 字符串

  ```json
  [ <unix_time>, "<string_value>" ]
  ```

  

## 6.3 区间数据查询

查询接口：`GET /api/v1/query_range`

URL请求参数：

- `query`：PromQL 表达式
- `start`：开始时间戳
- `end`：结束时间戳
- `step`：查询，单位s
- `timeout`：超时时间，可选

```bash
$ curl 'http://172.16.7.181:30090/api/v1/query_range?query=up\{job="cvm"\}&start=1725532200.000&end=1725532445.418&step=30'

{
    "status": "success",
    "data": {
        "resultType": "matrix",
        "result": [
            {
                "metric": {
                    "__name__": "up",
                    "instance": "172.16.8.158:9100",
                    "job": "cvm"
                },
                "values": [
                    [
                        1725532200,
                        "1"
                    ],
                    [
                        1725532260,
                        "1"
                    ],
                    [
                        1725532320,
                        "1"
                    ],
                    [
                        1725532380,
                        "1"
                    ],
                    [
                        1725532440,
                        "1"
                    ]
                ]
            }
        ]
    }
}
```



# 7. 最佳实践

## 7.1 监控维度

| 级别              | 监控什么                                                   | Exporter                         |
| ----------------- | ---------------------------------------------------------- | -------------------------------- |
| 网络              | 网络协议：http、dns、tcp、icmp；网络硬件：路由器，交换机等 | BlackBox Exporter; SNMP Exporter |
| 主机              | 资源用量                                                   | node exporter                    |
| 容器              | 资源用量                                                   | cAdvisor                         |
| 应用(包括Library) | 延迟，错误，QPS，内部状态等                                | 集成 Prometheus Client           |
| 中间件状态        | 资源用量，以及服务状态                                     | 集成 Prometheus Client           |
| 编排工具          | 集群资源用量，调度等                                       | Kubernetes Components            |



## 7.2 黄金指标

Four Golden Signals 是 Google 针对大量分布式监控的经验总结，4个黄金指标可以在服务级别帮助衡量终端用户体验、服务中断、业务影响等层面的问题。主要关注的四个核心指标：延迟（Latency）、流量（Throughput）、错误（Errors）和饱和度（Saturation）。

1. **延迟（Latency）**

   延迟是服务请求或操作所需的时间。例如，HTTP请求的平均响应时间。

   PromQL写法示例：

   ```promql
   histogram_quantile(0.95, sum(rate({job="my-service"}[5m]) by (le)))
   ```

   这个查询假设你有一个名为`histogram_quantile`的直方图指标，它记录了延迟分布。这个查询将计算过去5分钟内95%的请求延迟。

   

2. **流量（Throughput）**

   流量是系统在给定时间内处理的事务数量。例如，每秒处理的HTTP请求数。

   PromQL写法示例：

   ```promql
   rate({job="my-service"}[1m])
   ```

   这个查询将计算过去1分钟内`my-service`作业的HTTP请求率。

   

3. **错误（Errors）**

   错误是失败的服务请求或操作的数量。例如，返回HTTP 5xx状态码的请求。

   PromQL写法示例：

   ```promql
   increase(http_requests_total{code=~"5.."}[1m])
   ```

   这个查询将计算过去1分钟内HTTP响应码以5开头的请求数量（即错误请求）的增长量。

   

4. **饱和度（Saturation）**

   饱和度是指系统资源的利用情况，如CPU、内存、磁盘I/O等的使用率。

   PromQL写法示例（以CPU为例）：

   ```promql
   (1 - avg(irate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
   ```

   这个查询将计算过去5分钟内CPU的平均非空闲时间（即饱和度），并将其转换为百分比。



## 7.3 RED方法

RED方法是Weave Cloud在基于Google的“4个黄金指标”的原则下结合Prometheus以及Kubernetes容器实践，细化和总结的方法论，特别适合于云原生应用以及微服务架构应用的监控和度量。主要关注以下三种关键指标：

- (请求)速率：服务每秒接收的请求数。
- (请求)错误：每秒失败的请求数。
- (请求)耗时：每个请求的耗时。

在“4大黄金信号”的原则下，RED方法可以有效的帮助用户衡量云原生以及微服务应用下的用户体验问题。



## 7.4 USE方法

USE 即 "Utilization Saturation and Errors Method"，主要用于分析系统性能问题，可以指导用户快速识别资源瓶颈以及错误的方法。正如USE方法的名字所表示的含义，USE方法主要关注与资源的：使用率(Utilization)、饱和度(Saturation)以及错误(Errors)。

- 使用率：关注系统资源的使用情况。 这里的资源主要包括但不限于：CPU，内存，网络，磁盘等等。100%的使用率通常是系统性能瓶颈的标志。
- 饱和度：例如CPU的平均运行排队长度，这里主要是针对资源的饱和度(注意，不同于4大黄金信号)。任何资源在某种程度上的饱和都可能导致系统性能的下降。
- 错误：错误计数。例如：“网卡在数据包传输过程中检测到的以太网网络冲突了14次”。

通过对资源以上指标持续观察，通过以下流程可以知道用户识别资源瓶颈：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-use-method.avif)



# 8. 存储

## 8.1 TSDB

Prometheus 使用一种称为 TSDB（时间序列数据库）的存储引擎来存储时间序列数据。以下是 Prometheus 存储时间序列数据的基本原理：

1. **时间序列结构**：
   - Prometheus 中的每个时间序列都由一个唯一的指标名称（metric name）和一组键值对标签（label pairs）组成。这些标签用于过滤和聚合数据。
   - 每个时间序列还包含一组按时间戳排序的数据点（samples），每个数据点都有一个浮点数值（value）和一个时间戳（timestamp）。
2. **存储方式**：
   - Prometheus 将时间序列数据存储在本地磁盘上，而不是依赖外部数据库。
   - 数据按照时间戳进行分片存储，每个分片包含一个时间范围内的数据点。这种分片策略有助于高效地存储和查询数据。
3. **数据压缩和清理**：
   - Prometheus 会定期对存储的数据进行压缩，以减少存储空间的使用。
   - 同时，Prometheus 还会进行数据清理，删除旧的数据或不再需要的数据，以释放存储空间并确保系统的性能。
4. **查询语言**：
   - Prometheus 提供了一种名为 PromQL（Prometheus Query Language）的查询语言，用于从时间序列数据库中检索和聚合数据。
   - 用户可以使用 PromQL 编写复杂的查询语句，以获取所需的数据并进行可视化或告警。
5. **与其他存储后端的集成**：
   - 除了内置的 TSDB 存储引擎外，Prometheus 还支持与其他存储后端（如 InfluxDB、Graphite 等）集成。
   - 这种集成允许 Prometheus 将数据写入外部数据库，从而支持更大的数据存储量和更复杂的查询需求。
6. **WAL（Write-Ahead Logging）技术**：
   - Prometheus 使用 WAL 技术来确保数据的持久性和可靠性。
   - 当 Prometheus 接收新的数据点时，它首先将数据写入到 WAL 文件中，然后再将其追加到时间序列数据库中。
   - 如果 Prometheus 服务器崩溃或重启，它可以从 WAL 文件中恢复未写入时间序列数据库的数据，从而确保数据的完整性。

总结：Prometheus 通过使用 TSDB 存储引擎、数据压缩和清理机制、PromQL 查询语言以及与外部存储后端的集成等方式来高效地存储和查询时间序列数据。

要优化Prometheus的存储性能，可以考虑以下几个方面的策略：

1. **选择适当的存储后端**：
   - 选择性能较高的存储后端，例如SSD（固态硬盘），它们比传统的HDD（硬盘驱动器）具有更高的I/O性能和更低的延迟。
   - 如果可能的话，使用RAID配置（如RAID 10）来提高数据冗余和读取性能。
2. **调整存储容量和保留策略**：
   - 根据业务需求和数据量增长情况，合理设置Prometheus的存储容量。
   - 配置合适的数据保留策略，定期清理过期数据，避免存储空间不足导致性能下降。
3. **优化查询性能**：
   - 使用PromQL语言编写高效的查询语句，避免不必要的计算和过滤操作。
   - 合理使用标签索引，特别是在大数据量的情况下，可以加快查询速度。
4. **避免频繁的数据写入**：
   - 减少指标数据的频繁写入，合理控制采集频率和数据量，以降低系统负载。
   - 考虑批量写入数据，以减少I/O操作次数。
5. **合理设置参数**：
   - 根据实际情况合理设置Prometheus的参数，如存储周期、采样频率等。
   - 调整抓取频率和超时时间，避免频繁的数据拉取和超时导致性能下降。
6. **避免重复计算和全表扫描**：
   - 避免重复计算相同的指标数据，可以通过使用缓存或优化查询语句来避免。
   - 尽量避免在大表上进行全表扫描操作，可以通过添加索引或优化查询语句来避免。
7. **考虑数据分片**：
   - 当数据量较大时，考虑使用数据分片的方式来分散数据存储，以提高查询性能。
   - 将数据分布到多个Prometheus实例上，通过联邦集群（federation）或其他方式进行数据聚合和查询。
8. **监控和调优**：
   - 定期监控Prometheus的性能指标，如CPU、内存、磁盘I/O等。
   - 根据监控结果及时发现并解决性能瓶颈，优化系统运行效率。
9. **硬件升级和扩展**：
   - 如果Prometheus的存储性能仍然无法满足需求，可以考虑升级硬件配置，如增加内存、更换更高效的CPU等。
   - 如果单个Prometheus实例无法处理所有数据，可以考虑扩展Prometheus集群的规模，增加更多的实例来分担负载。



## 8.2 远程存储

**启动配置项**：

```bash
--storage.tsdb.path		#指定数据保存位置
--storage.tsdb.retention.time	#指定数据保存时间，默认15d
--storage.tsdb.retention.size 	#指定block可以保存的数据大小
--query.timeout	#最大查询超时时间，默认2m
--query.max-concurrency		#最大查询并发数，默认20
```



修改 `prometheus.yml`，增加远程存储支持：

```yaml
...
remote_write:
  - url: "http://10.0.0.12:6041/prometheus/v1/remote_write/prometheus"
    basic_auth:
      username: root
      password: NUma@numa1
    remote_timeout: 30s
    queue_config:
        capacity: 100000  # 队列中最多可以存储的样本数量。当队列中的样本数达到时，新的数据将被丢弃。在远程存储不及时处理时，Prometheus可以暂时存储的样本数量，以避免在短时间内网络故障或其他问题时丢失数据。
        max_shards: 1000  # 最大并发分片数量
        max_samples_per_send: 1000  # 每次发送的样本数量
        batch_send_deadline: 5s  # 批量发送的超时时间
        min_backoff: 200ms      # 最短重试等待时间，默认100ms
        max_backoff: 5s         # 最长重试等待时间，默认5s
remote_read:
  - url: "http://10.0.0.12:6041/prometheus/v1/remote_read/prometheus"
    basic_auth:
      username: root
      password: NUma@numa1
    remote_timeout: 10s
    read_recent: true
```

**`min_backoff`**：定义最短的重试等待时间。即在失败后，Prometheus 至少要等待这么长时间才会进行下一次重试。

**`max_backoff`**：定义最长的重试等待时间。如果在重试过程中退避时间逐渐增加，达到 `max_backoff` 后，不会再进一步增加，保持在这个最大等待时间。



# 9. TSDB Admin API

Prometheus TSDB Admin API提供了三个接口，分别是`快照(Snapshot)`， `数据删除(Delete Series)`，`数据清理(Clean Tombstones)`

默认是关闭的，需要加入启动参数`--web.enable-admin-api`才会启动

## 9.1 创建快照

在 TSDB 数据目录下创建文件 `snapshots/<datetime>-<rand>`

```
POST /api/v1/admin/tsdb/snapshot
PUT /api/v1/admin/tsdb/snapshot
```

URL参数：

- `skip_head=<bool>`: Skip data present in the head block. Optional.

示例：

```bash
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# 快照查询
ls -l /opt/monitoring/prometheus/data/snapshots/
drwxr-xr-x 27 nobody nogroup 4096 May 23 15:18 20250523T071823Z-7bbda610ffb7bc2b
```



## 9.2 删除指标

```
POST /api/v1/admin/tsdb/delete_series
PUT /api/v1/admin/tsdb/delete_series
```

URL参数：

- `match[]=<series_selector>`: Repeated label matcher argument that selects the series to delete. At least one `match[]` argument must be provided.
- `start=<rfc3339 | unix_timestamp>`: Start timestamp. Optional and defaults to minimum possible time.
- `end=<rfc3339 | unix_timestamp>`: End timestamp. Optional and defaults to maximum possible time.

示例：

```bash
curl -v -X PUT -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]=ssCpuUser{group="cvm"}'
```



## 9.3 磁盘清理

使用数据删除接口将 metric 数据删除后，只是将数据标记为删除，实际的数据 (tombstones) 仍然存在于磁盘上，其在将来的某一时刻会被Prometheus清除释放空间，也可以通过数据清理接口显式地清除。

```bash
PUT /api/v1/admin/tsdb/clean_tombstones
```

示例：

```bash
curl -X PUT http://localhost:9090/api/v1/admin/tsdb/clean_tombstones
```





