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



# 4. HTTP API

## 4.1 瞬时数据查询

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



## 4.2 响应数据类型

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

  

## 4.3 区间数据查询

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



# 5. 最佳实践

## 5.1 监控维度

| 级别              | 监控什么                                                   | Exporter                         |
| ----------------- | ---------------------------------------------------------- | -------------------------------- |
| 网络              | 网络协议：http、dns、tcp、icmp；网络硬件：路由器，交换机等 | BlackBox Exporter; SNMP Exporter |
| 主机              | 资源用量                                                   | node exporter                    |
| 容器              | 资源用量                                                   | cAdvisor                         |
| 应用(包括Library) | 延迟，错误，QPS，内部状态等                                | 集成 Prometheus Client           |
| 中间件状态        | 资源用量，以及服务状态                                     | 集成 Prometheus Client           |
| 编排工具          | 集群资源用量，调度等                                       | Kubernetes Components            |



## 5.2 黄金指标

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



## 5.3 RED方法

RED方法是Weave Cloud在基于Google的“4个黄金指标”的原则下结合Prometheus以及Kubernetes容器实践，细化和总结的方法论，特别适合于云原生应用以及微服务架构应用的监控和度量。主要关注以下三种关键指标：

- (请求)速率：服务每秒接收的请求数。
- (请求)错误：每秒失败的请求数。
- (请求)耗时：每个请求的耗时。

在“4大黄金信号”的原则下，RED方法可以有效的帮助用户衡量云原生以及微服务应用下的用户体验问题。



## 5.4 USE方法

USE 即 "Utilization Saturation and Errors Method"，主要用于分析系统性能问题，可以指导用户快速识别资源瓶颈以及错误的方法。正如USE方法的名字所表示的含义，USE方法主要关注与资源的：使用率(Utilization)、饱和度(Saturation)以及错误(Errors)。

- 使用率：关注系统资源的使用情况。 这里的资源主要包括但不限于：CPU，内存，网络，磁盘等等。100%的使用率通常是系统性能瓶颈的标志。
- 饱和度：例如CPU的平均运行排队长度，这里主要是针对资源的饱和度(注意，不同于4大黄金信号)。任何资源在某种程度上的饱和都可能导致系统性能的下降。
- 错误：错误计数。例如：“网卡在数据包传输过程中检测到的以太网网络冲突了14次”。

通过对资源以上指标持续观察，通过以下流程可以知道用户识别资源瓶颈：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-use-method.avif)



# 6. 存储

## 6.1 TSDB

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



## 6.2 远程存储

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



# 7. TSDB Admin API

Prometheus TSDB Admin API提供了三个接口，分别是`快照(Snapshot)`， `数据删除(Delete Series)`，`数据清理(Clean Tombstones)`

默认是关闭的，需要加入启动参数`--web.enable-admin-api`才会启动



## 7.1 创建快照

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



## 7.2 删除指标

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



## 7.3 磁盘清理

使用数据删除接口将 metric 数据删除后，只是将数据标记为删除，实际的数据 (tombstones) 仍然存在于磁盘上，其在将来的某一时刻会被Prometheus清除释放空间，也可以通过数据清理接口显式地清除。

```bash
PUT /api/v1/admin/tsdb/clean_tombstones
```

示例：

```bash
curl -X PUT http://localhost:9090/api/v1/admin/tsdb/clean_tombstones
```





