# 1. 简介

## 1.1 概述

告警能力在 Prometheus 架构中被划分为两个独立的部分。通过在 Prometheus 中定义 AlertRule (告警规则)，Prometheus 会周期性的对告警规则进行计算，如果满足告警触发条件，就会向 AlertManager 发送告警消息

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-alert-flow-2.png)

每条告警规则主要由以下部分组成：

- 告警名称：能够直观表达该告警的主要内容
- 告警规则：由 PromQL 查询结果持续多长时间 （During）后发出告警

AlertManager 作为一个独立的组件，负责接收并处理来自 Prometheus Server 的告警信息。AlertManager 对这些告警信息进一步处理。比如当接收大量重复告警时消除重复的告警信息，同时对告警信息进行分组并路由到正确的通知方。



## 1.2 告警流程

prometheus—>触发阈值—>超出持续时间—>alertmanager—>分组|抑制|静默—>媒体类型—>邮件|钉钉|微信等。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-alert-flow-1.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-alert-flow-2.png)

一条告警规则的主要组成部分：

- **告警名称**：能够直接表达该告警的主要内容
- **告警规则**：主要根据`PromQL`进行定义，其实际意义是当表达式 (PromQL) 查询结果持续多长时间 (During) 后发出告警



AlertManager 除提供基本的告警通知能力外，还提供了分组、抑制、静默等告警特性：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/alertmanager-func.png)

- 去重
  将多个相同的告警,去掉重复的告警,只保留不同的告警

- **分组(group)**：将类似性质的告警合并为单个通知。

  - 系统宕机导致大量告警被同时触发，此时分组机制可将这些告警合并为一个告警通知
  - 告警分组、告警时间、告警接收方式等，可通过 AlertManager 配置文件定制

- 路由
  将不同的告警定制策略路由发送至不同的目标

- **抑制(inhibition)**
  抑制可以避免当某种问题告警产生之后用户接收到大量由此问题导致的一系列的其它告警通知同样通过AlertManager的配置文件进行设置。

- **静默(silences)**
  静默提供了一个简单的机制可以快速根据标签对告警进行静默处理。如果接收到的告警符合静默的配置，AlertManager则不会发送告警通知。静默设置需要在AlertManager的Web页面上进行设置。

  

# 2. 部署

## 2.1 应用

```bash
mkdir -p /opt/alertmanager/data

# 配置文件
cat > /opt/alertmanager/alertmanager.yml <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

# 启动服务
docker run -d --name alertmanager \
    -p 9093:9093 \
    -v /opt/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    -v /opt/alertmanager/data:/alertmanager \
    -e TZ="Asia/Shanghai" \
    --restart=always prom/alertmanager:v0.27.0 \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/alertmanager
```



## 2.2 集成

修改 prometheus.yml，并刷新

```bash
# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - 192.168.3.107:9093
```



# 3. 配置说明

```yaml
# 全局配置 
global:
  resolve_timeout: 5m
  
# 模板
templates:
  [ - <filepath> ... ]

# 根路由
route:
  # 顶级路由配置的接收者（匹配不到子级路由，会使用根路由发送报警）
  receiver: 'default-receiver'
  # 设置等待时间，在此等待时间内如果接收到多个报警，则会合并成一个通知发送给receiver
  group_wait: 30s
  # 两次报警通知的时间间隔，如：5m，表示发送报警通知后，如果5分钟内再次接收到报警则不会发送通知
  group_interval: 5m
  # 发送相同告警的时间间隔，如：4h，表示4小时内不会发送相同的报警
  repeat_interval: 4h
  # 分组规则，如果满足group_by中包含的标签，则这些报警会合并为一个通知发给receiver
  group_by: [cluster, alertname]
  routes:
  # 子路由的接收者
  - receiver: 'database-pager'
    group_wait: 10s
    # 默认为false。false：配置到满足条件的子节点点后直接返回，true：匹配到子节点后还会继续遍历后续子节点
    continue:false
    # 正则匹配，验证当前标签service的值是否满足当前正则的条件
    match_re:
      service: mysql|cassandra
  # 子路由的接收者
  - receiver: 'frontend-pager'
    group_by: [product, environment]
    # 字符串匹配，匹配当前标签team的值为frontend的报警
    match:
      team: frontend

# 告警接收者
receivers:
# 接收者名称
- name: 'default-receiver'
  # 接收者为webhook类型
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'
- name: 'database-pager'
  webhook_configs:
  - url: 'http://127.0.0.1:5002/'
- name: 'frontend-pager'
  webhook_configs:
  - url: 'http://127.0.0.1:5003/'
  
# 抑制规则
inhibit_rules:
  [ - <inhibit_rule> ... ]
```

AlertManager 配置包含以下主要部分：

- global：全局公共参数
  - resolve_timeout：持续多长时间未收到告警后标记告警状态未 resolved。该参数定义可能影响到告警恢复通知的接收时间，需要根据实际场景设置，默认5分钟
- templates：告警通知模板，如 HTML 模板、邮件模板等
- route：告警路由，根据标签匹配，确定当前告警应该如何处理
- receivers：接收者，可以是邮箱、Slack 或 Webhook 等，一般配置告警路由使用
- inhibit_rules：抑制规则，可减少垃圾告警的产生



## 3.1 告警路由

```yaml
route:
  [ receiver: <string> ]
 
  # false: 告警匹配到第一个节点就直接停止
  [ continue: <boolean> | default = false ]    
  
  # 基于字符串匹配
  match:
    [ <labelname>: <labelvalue>, ... ]
  
  # 基于正则表达式匹配
  match_re:
    [ <labelname>: <regex>, ... ]
    
  # 分组规则，基于告警中包含的标签进行分组
  [ group_by: '[' <labelname>, ... ']' ]       
  
  # 在等待时间内当前group接收到的新告警，合并为一个通知向 receiver 发送
  [ group_wait: <duration> | default = 30s ]  
  
  # 相同group之间发送告警通知的时间间隔
  [ group_interval: <duration> | default = 5m ]
  [ repeat_interval: <duration> | default = 4h ]
  
  routes:
    [ - <route> ... ]
```



示例：

```yaml
route:
  receiver: 'default-receiver'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  group_by: [cluster, alertname]
  routes:
  - receiver: 'database-pager'
    group_wait: 10s
    match_re:
      service: mysql|cassandra
  - receiver: 'frontend-pager'
    group_by: [product, environment]
    match:
      team: frontend
```



## 3.2 告警接收者

```yaml
receivers:
  - name: <string>
    email_configs:
      [ - <email_config>, ... ]
    hipchat_configs:
      [ - <hipchat_config>, ... ]
    pagerduty_configs:
      [ - <pagerduty_config>, ... ]
    pushover_configs:
      [ - <pushover_config>, ... ]
    slack_configs:
      [ - <slack_config>, ... ]
    opsgenie_configs:
      [ - <opsgenie_config>, ... ]
    webhook_configs:
      [ - <webhook_config>, ... ]
    victorops_configs:
      [ - <victorops_config>, ... ]
```



示例-1：邮件

```yaml
global:
  smtp_smarthost: smtp.gmail.com:587
  smtp_from: <smtp mail from>
  smtp_auth_username: <usernae>
  smtp_auth_identity: <username>
  smtp_auth_password: <password>

route:
  group_by: ['alertname']
  receiver: 'default-receiver'

receivers:
  - name: default-receiver
    email_configs:
      - to: <mail to address>
        send_resolved: true
```



示例-2：企业微信

```yaml
global:
  resolve_timeout: 10m
  wechat_api_url: 'https://qyapi.weixin.qq.com/cgi-bin/'
  wechat_api_secret: '应用的secret'
  wechat_api_corp_id: '企业id'
templates:
- '/etc/alertmanager/config/*.tmpl'
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  routes:
  - receiver: 'wechat'
    continue: true
inhibit_rules:
- source_match:
receivers:
- name: 'wechat'
  wechat_configs:
  - send_resolved: false
    corp_id: '企业id，在企业的配置页面可以看到'
    to_user: '@all'
    to_party: ' PartyID1 | PartyID2 '
    message: '{{ template "wechat.default.message" . }}'
    agent_id: '应用的AgentId，在应用的配置页面可以看到'
    api_secret: '应用的secret，在应用的配置页面可以看到'
```

模板：

```ruby
{{ define "wechat.default.message" }}
{{- if gt (len .Alerts.Firing) 0 -}}
{{- range $index, $alert := .Alerts -}}
{{- if eq $index 0 -}}
告警类型: {{ $alert.Labels.alertname }}
告警级别: {{ $alert.Labels.severity }}

=====================
{{- end }}
===告警详情===
告警详情: {{ $alert.Annotations.message }}
故障时间: {{ $alert.StartsAt.Format "2006-01-02 15:04:05" }}
===参考信息===
{{ if gt (len $alert.Labels.instance) 0 -}}故障实例ip: {{ $alert.Labels.instance }};{{- end -}}
{{- if gt (len $alert.Labels.namespace) 0 -}}故障实例所在namespace: {{ $alert.Labels.namespace }};{{- end -}}
{{- if gt (len $alert.Labels.node) 0 -}}故障物理机ip: {{ $alert.Labels.node }};{{- end -}}
{{- if gt (len $alert.Labels.pod_name) 0 -}}故障pod名称: {{ $alert.Labels.pod_name }}{{- end }}
=====================
{{- end }}
{{- end }}

{{- if gt (len .Alerts.Resolved) 0 -}}
{{- range $index, $alert := .Alerts -}}
{{- if eq $index 0 -}}
告警类型: {{ $alert.Labels.alertname }}
告警级别: {{ $alert.Labels.severity }}

=====================
{{- end }}
===告警详情===
告警详情: {{ $alert.Annotations.message }}
故障时间: {{ $alert.StartsAt.Format "2006-01-02 15:04:05" }}
恢复时间: {{ $alert.EndsAt.Format "2006-01-02 15:04:05" }}
===参考信息===
{{ if gt (len $alert.Labels.instance) 0 -}}故障实例ip: {{ $alert.Labels.instance }};{{- end -}}
{{- if gt (len $alert.Labels.namespace) 0 -}}故障实例所在namespace: {{ $alert.Labels.namespace }};{{- end -}}
{{- if gt (len $alert.Labels.node) 0 -}}故障物理机ip: {{ $alert.Labels.node }};{{- end -}}
{{- if gt (len $alert.Labels.pod_name) 0 -}}故障pod名称: {{ $alert.Labels.pod_name }};{{- end }}
=====================
{{- end }}
{{- end }}
{{- end }}
```



示例-3：Webhook

```yaml
receivers:
  - name: default-receiver
    webhook_configs:
      - url: http://localhost:8080/webhook
```



## 3.3 屏蔽告警

### 3.3.1 抑制机制

```yaml
inhibit_rules:
    # 已发送的告警通知匹配规则
  - target_match:
      [ <labelname>: <labelvalue>, ... ]
    target_match_re:
      [ <labelname>: <regex>, ... ]
    
    # 新增告警匹配规则
    source_match:
      [ <labelname>: <labelvalue>, ... ]
    source_match_re:
      [ <labelname>: <regex>, ... ]
    
    # 已发送告警和新增告警的标签与 equal 完全相同，则启动抑制机制，新告警将不再发送
    [ equal: '[' <labelname>, ... ']' ]
```

示例：当集群中的某一个主机节点异常宕机导致告警NodeDown被触发，同时在告警规则中定义了告警级别severity=critical。由于主机异常宕机，该主机上部署的所有服务，中间件会不可用并触发报警。根据抑制规则的定义，如果有新的告警级别为severity=critical，并且告警中标签node的值与NodeDown告警的相同，则说明新的告警是由NodeDown导致的，则启动抑制机制停止向接收器发送通知。

```yaml
inhibit_rules:
- source_match:
    alertname: NodeDown
    severity: critical
  target_match:
    severity: critical
  equal:
    - node
```



### 3.3.2 临时静默

进入AlertManager UI，点击"New Silence"显示如下内容：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/alertmanager-silence.png)

当静默规则生效以后，从 AlertManager 的Alerts页面下用户将不会看到该规则匹配到的告警信息:

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/alertmanager-silence-list.png)



# 4. 告警规则

## 2.1 规则定义

```yaml
# rules/node_rules.yml
groups:
- name: node_alert
  rules:
  - alert: node_down
    expr: up{job="node_exporter"} != 1
    for: 1m
    labels:
      level: critical
    annotaions:
      description: "The node is down more than 1 minute"
      summary: "The node is down"
```

- name：告警分组名称

- rules：告警规则

  - alert：告警名称，在组中必选唯一
  - expr：PromQL规则表达式，计算相关的时间序列指标是否满足规则
  - for：评估等待时间，即持续时间。在定义的时间范围内，规则处于 Pending 状态，达到改时间则变为Firing，告警信息发送到 AlertManager
  - labels：自定义标签
  - annotations：包含告警概要信息和详细信息的文字描述

  

在 Prometheus 配置文件中配置告警规则文件：

```yaml
rule_files:
  [ - <filepath_glob> ...]
```



默认情况下 Prometheus 每分钟对这些告警规则进行计算，支持自定义告警计算周期：

```yaml 
global:
  [ evaluation_interval: <duration> | default = 1m ]
```



## 2.2 使用模板

模板(template)是一种在警报中使用时间序列数据的标签和值的方法，可用于告警中的注解和标签。它使用标准的Go模板语法，并暴露一些包含时间序列的标签和值的变量。

告警规则文件 annotations 的 summary 告警的概要信息，description 告警的详细信息。为了让告警信息具有更好的可读性，Prometheus 支持模板化 label 和 annotations 中的标签值

- `$labels.<labelname>` ：当前告警实例中指定标签的值
- `$value` ：当前PromQL表达式计算的样本值

```bash
# To insert a firing element's label values:
{{ $labels.<labelname> }}
# To insert the numeric expression value of the firing element:
{{ $value }}
```

示例：

```bash
groups:
- name: node_alert
  rules:
  - alert: cpu_alert
    expr: 100 - avg(irate(node_cpu_seconds_total{mode="idle"}[1m])) by (instance)* 100 > 85
    for: 5m
    labels:
      level: warning
    annotations:
      description: "instance: {{ $labels.instance }}, cpu usage is too high! value: {{ $value }}"
      summary: "cpu usage is too high"
```



## 2.3 常用规则

### 2.3.1 主机告警

基于 node-exporter 的主机监控规则：

```bash
# 主机up/down状态
up{instance=~"10|80|192.*"} == 0

# CPU使用率
100 - ((avg by (instance,job,env)(irate(node_cpu_seconds_total{mode="idle"}[30s]))) *100) > 90

# 内存使用率
((node_memory_MemTotal_bytes -(node_memory_MemFree_bytes+node_memory_Buffers_bytes+node_memory_Cached_bytes) )/node_memory_MemTotal_bytes ) * 100 > 90

# 磁盘使用率
100 - (node_filesystem_free_bytes{fstype=~"ext3|ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext3|ext4|xfs"} * 100) > 95
```



```yaml
# alert-node-rules.yml
groups:
- name: hostStatsAlert
  rules:
  - alert: HostDown
    expr: up {job=~"tke|cvm"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      description: "实例 {{ $labels.instance }} 已宕机"
      summary:  "实例 {{ $labels.instance }} 已宕机"
  - alert: HostCpuUsageAlert
    expr: sum(avg without (cpu)(irate(node_cpu_seconds_total{mode!='idle'}[5m]))) by (instance) > 0.9
    for: 1m  
    labels:
      severity: critical
    annotations:
      summary: "实例 {{ $labels.instance }} CPU 使用率过高"
      description: "实例{{ $labels.instance }} CPU 使用率超过 90% (当前值为: {{ $value }})"
  - alert: HostMemUsageAlert
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes > 0.9
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "实例 {{ $labels.instance }} 内存使用率过高"
      description: "实例 {{ $labels.instance }} 内存使用率 90% (当前值为: {{ $value }})"
  - alert: HostDiskUsageAlert
    expr: 100 - (node_filesystem_free_bytes{fstype=~"ext3|ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext3|ext4|xfs"} * 100) > 95
    for: 5m  
    labels:
      severity: critical
    annotations:
      summary: "实例 {{ $labels.instance }} 磁盘使用率过高"
      description: "实例 {{ $labels.instance }} 磁盘使用率超过95% (当前值为: {{ $value }})"
```



### 2.3.2 Doris 数据库

Doris 数据库监控规则：

```bash
# 节点离线
up {job="doris"}  == 0 

# TcMalloc 占用的虚拟内存的大小超过80%
doris_be_memory_allocated_bytes / 1024 / 1024 / 1024 > 80

# BE节点的 compaction score 超过80% 
max by(instance, backend, job) (doris_fe_tablet_max_compaction_score) > 80

# Doris开启导入任务后，接收导入batch的线程池队列大小。当队列长度大于1时，说明有导入积压。如果可以容忍有少部分积压任务，可以适当增大预警值。
doris_be_add_batch_task_queue_size{group="be"} > 0

# 每个BE节点所有目录下的compaction任务总数
sum by(instance) (doris_be_disks_compaction_num{group="be",job="doris"}) > 15

# 该指标是当前BE节点打开导入任务的Channel数。值越大，说明当前正在执行的导入任务越多
doris_be_load_channel_count{group="be",job="doris"} > 10
```



```yaml
# alert-doris-rules.yml
groups:
- name: dorisBEAlert
  rules:
  - alert: BeDown
    expr: up {group="be", job="doris"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Doris BE {{ $labels.instance }} 宕机"
      description: "Doris BE {{ $labels.instance }} 宕机"
  - alert: TcMalloc
    expr: doris_be_memory_allocated_bytes / 1024 / 1024 / 1024 > 80
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} TcMalloc 占用的虚拟内存的大小过高"
      description: "Doris BE {{ $labels.instance }} TcMalloc 占用的虚拟内存的大小超过80%，(当前值为: {{ $value }})"
  - alert: CompactionScore
    expr: max by(instance, backend, job) (doris_fe_tablet_max_compaction_score) > 80
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} compaction score 超过80%"
      description: "Doris BE {{ $labels.instance }} compaction score 超过80%，(当前值为: {{ $value }})"
  - alert: BatchTaskQueue
    expr: doris_be_add_batch_task_queue_size{group="be"} > 10
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} 接收导入batch的线程池队列大小超过10"
      description: "Doris BE {{ $labels.instance }} 接收导入batch的线程池队列大小超过10，(当前值为: {{ $value }})"
  - alert: CompactionTaskNum
    expr: sum by(instance) (doris_be_disks_compaction_num{group="be",job="doris"}) > 15
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} 目录下的compaction任务总数超过15"
      description: "Doris BE {{ $labels.instance }} 目录下的compaction任务总数超过15，(当前值为: {{ $value }})"
  - alert: LoadTaskChannels
    expr: doris_be_load_channel_count{group="be",job="doris"} > 10
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} 打开导入任务的Channel数超过10个"
      description: "Doris BE {{ $labels.instance }} 打开导入任务的Channel数超过10个，(当前值为: {{ $value }})"
  - alert: BeRateOfCacheMoreThan0.8
    expr: doris_be_cache_usage_ratio > 0.8
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} LRU Cache 的使用率大于80%"
      description: "Doris BE {{ $labels.instance }} LRU Cache 的使用率大于80%，(当前值为: {{ $value }})"
  - alert: BeDiskAvailCapacityLessThan1G
    expr: node_filesystem_free_bytes{mountpoint="/data"} < (1024*1024*1024)
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris BE {{ $labels.instance }} 数据目录所在磁盘的剩余空间小于1G"
      description: "Doris BE {{ $labels.instance }} 数据目录所在磁盘的剩余空间小于1G，(当前值为: {{ $value }})"
  - alert: BeDiskStatusAbnormal
    expr: doris_be_disks_state == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Doris BE {{ $labels.instance }} 数据目录的磁盘状态异常"
      description: "Doris BE {{ $labels.instance }} 数据目录的磁盘状态异常"
- name: dorisFEAlert
  rules:
  - alert: FeDown
    expr: up {group="fe", job="doris"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Doris FE {{ $labels.instance }} 宕机"
      description: "Doris FE {{ $labels.instance }} 宕机"
  - alert: FeConnectionMoreThan1000
    expr: doris_fe_connection_total > 1000       
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris FE {{ $labels.instance }} MySQL客户端连接数超过1000"
      description: "Doris FE {{ $labels.instance }} MySQL客户端连接数超过1000，(当前值为: {{ $value }})"
  - alert: FeQpsMoreThan500
    expr: rate(doris_fe_query_total[1m])>500 
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris FE {{ $labels.instance }} QPS超过500"
      description: "Doris FE {{ $labels.instance }} QPS超过500，(当前值为: {{ $value }})"
  - alert: FeRateOfActiveThreadMoreThan0.8
    expr: (doris_fe_thread_pool_active_threads/doris_fe_thread_pool_size) > 0.8 
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris FE {{ $labels.instance }} 线程池使用占用比例超过80%"
      description: "Doris FE {{ $labels.instance }} 线程池使用占用比例超过80%，(当前值为: {{ $value }})"
  - alert: FeRateOfJVMUsedMemMoreThan0.8
    expr: (jvm_memory_heap_used_bytes/jvm_memory_heap_max_bytes) > 0.8
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris FE {{ $labels.instance }} JVM内存使用占用比例超过80%"
      description: "Doris FE {{ $labels.instance }} JVM内存使用占用比例超过80%，(当前值为: {{ $value }})"
  - alert: FeRateOfNodeAvailableMemLessThan0.2
    expr: (node_memory_MemAvailable/node_memory_MemTotal)<0.2
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Doris FE {{ $labels.instance }} 可用内存占比少于20%"
      description: "Doris FE {{ $labels.instance }} 可用内存占比少于20%，(当前值为: {{ $value }})"
```





# 5. 告警状态

三种告警状态：

- Inactive：非活动状态，表示正在监控，暂未触发告警
- Pending：告警已被触发，但由于告警被分组、抑制或静默，所以告警等待验证，一旦所有验证都通过，则将转到 Firing 状态
- Firing：将告警发送到 AlertManager，它将按配置将告警发送给所有接收者。一旦告警解出，其状态转为 Inactive，如此循环。



**Pending**: 告警已触发，但等待验证，必选满足`for`定义的持续时间才会 Firing

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-alert-pending.png)



**Firing**：告警发送到 AlertManager，然后有其发送给所有接收者

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prom-alert-firing.png)



对于已经 pending 或 firing 的告警，Prometheus 会将其存储到时间序列 ALERT {} 中

```
ALERTS{alertname="<alert name>", alertstate="pending|firing", <additional alert labels>}
```

样本值：

- 1：当前告警处于活动状态 (pending 或 firing)
- 0：告警从活动状态转为非活动状态



# 6. 性能优化

## 6.1 Recording Rules

某些 PromQL 复杂且计算量较大，可能导致响应超时。可使用 Recording Rule 规则支持后台批处理复杂的运算，提高查询效率

```yaml
groups:
  - name: example
    rules:
    - record: job:http_inprogress_requests:sum
      expr: sum(http_inprogress_requests) by (job)
```







# 7. 告警恢复

## 7.1 prometheus

**prometheus触发告警恢复**：

- 对于已恢复的告警，如果之前的状态是pending，或者之前的 ResolvedAt 非空，且在 resolvedRetention (15m) 之前的，则删除此告警；否则更新告警的状态为恢复，且恢复时间为当前时间

- 对告警进行判断是否需要发送。如果恢复时间大于上次发送告警的时间，证明恢复是在告警后发生的，那么已经恢复了，需要发送恢复

- 设置告警的 ValidUntil，如果告警过了 ValidUntil ，还没有收到新的  firing，则代表已恢复：

  `ValidUntil = ts + max([check_interval], [resend_deplay]) * 4`

- 发送前设置告警 EndAt

  - 如果告警的 ResolvedAt 不空，则 EndAt = ResolvedAt，否则等于 ValidUntil。即如果告警的 ResolvedAt不空，则证明是采集到了恢复的情况，EndAt 代表实际恢复时间
  - 如果告警的 ResovledAt 为空，则还没恢复，设置其为一个 ValidUntil，即告警的有效时间。如果持续了 ValidUntil 之后，依旧未收到新的 firing，则当做恢复来处理

- 发送告警



## 7.2 alertmanager

**alertmanager 触发告警恢复**：

Prometheus 需要持续地将 Firing 告警发送给 AlertManager，遇到以下情况，AlertManager 会认为告警已经解决，发送一个 resolved：

- Prometheus 发送一个 Inactive 消息给 AlertManager，即 endAt 为当前时间

- Prometheus 一直未发送任何消息给 AlertManager

  解释：prometheus 发送给 alertmanager 的告警触发消息里面携带endAt时间，用来告知如果超过这个时间还未收到新的告警就认为告警已恢复。如果 prometheus 未携带 endAt，那么 alertmanager 会设置 endAt 为 now + resolve_timeout，作为默认的恢复时间

  prometheus 会给告警加上一个默认endAt: `ts + max([check_interval], [resend_delay]) * 4`

  - resendDelay：配置参数`rules.alert.resend-delay`, 默认 1m
  - interval：采集间隔配置参数



当 AlertManager 收到告警消息后，分下列几种情况对 startsAt 和 endsAt 两个字段进行处理：

- 两者都存在：不做任何处理
- 两者都为指定：startsAt 指定为当前时间，endsAt为当前时间加上告警持续时间(默认5m)
- 只指定startsAt：endsAt为当前时间加上告警持续时间(默认5m)
- 只指定endsAt：startsAt设置为 endsAt

即：如果 endsAt 没有指定，则自动 `startsAt + resolve_time(默认5m)；如果已指定，则以指定的为准



为什么一条持续触发的告警不会触发恢复，而采集不到数据时会触发恢复？

如果告警一直 Firing，那么 Prometheus 会在 resend_delay 的间隔重复发送，而 startsAt 保持不变，endsAt 跟着 ValidUntil 变。这也就是为啥一直 firing 的规则不会被认为恢复，而不发 firing 则会认为已恢复。因为一直 firing 的告警消息中，endsAt 跟着 ValidUntil 变，一直延后。而如果没收到，则会导致 alertmanager 那边在过了告警的 endAt 后，没收到恢复或新 firing，则认为恢复



## 7.3 告警恢复过程

- Prometheus 采集到告警恢复的情况，推送给 AlertManager，然后由其发出告警
- Prometheus 发送了告警消息，但没有发送告警恢复消息，也没有持续发送告警消息，那么AlertManager 将根据该告警的 endsAt 判断，如果当前时间已过，则发出告警恢复消息
- 当告警没有再次触发时，多久后发送恢复数据的决定因素：告警的 endsAt 
  -  默认情况下，Prometheus 设置：`endsAt = ts + max([check_interval], [resend_delay]) * 4`
  -  未设置，由 AlertManager设置：`endsAt = now + resolve_timeout`



告警触发：

```json
{
    "receiver": "webhook",
    "status": "firing",
    "alerts": [
        {
            "status": "firing",
            "labels": {
                "alertname": "BeDown",
                "cluster": "kubernetes",
                "group": "be",
                "instance": "192.168.3.126:8040",
                "job": "doris",
                "severity": "critical"
            },
            "annotations": {
                "description": "Doris BE 192.168.3.126:8040 宕机",
                "summary": "Doris BE 192.168.3.126:8040 宕机"
            },
            "startsAt": "2024-08-27T03:30:47.93Z",
            "endsAt": "0001-01-01T00:00:00Z",
            "generatorURL": "http://prometheus-7fb6f8885b-4zs92:9090/graph?g0.expr=up%7Bgroup%3D%22be%22%2Cjob%3D%22doris%22%7D+%3D%3D+0&g0.tab=1",
            "fingerprint": "b348125a5fcebeab"
        }
    ],
    "groupLabels": {
        "instance": "192.168.3.126:8040"
    },
    "commonLabels": {
        "alertname": "BeDown",
        "cluster": "kubernetes",
        "group": "be",
        "instance": "192.168.3.126:8040",
        "job": "doris",
        "severity": "critical"
    },
    "commonAnnotations": {
        "description": "Doris BE 192.168.3.126:8040 宕机",
        "summary": "Doris BE 192.168.3.126:8040 宕机"
    },
    "externalURL": "http://alertmanager-6dfb84b96-rgbvb:9093",
    "version": "4",
    "groupKey": "{}:{instance=\"192.168.3.126:8040\"}",
    "truncatedAlerts": 0
}
```



告警恢复：

```json
{
    "receiver": "webhook",
    "status": "resolved",
    "alerts": [
        {
            "status": "resolved",
            "labels": {
                "alertname": "BeDown",
                "cluster": "kubernetes",
                "group": "be",
                "instance": "192.168.3.126:8040",
                "job": "doris",
                "severity": "critical"
            },
            "annotations": {
                "description": "Doris BE 192.168.3.126:8040 宕机",
                "summary": "Doris BE 192.168.3.126:8040 宕机"
            },
            "startsAt": "2024-08-27T03:30:47.93Z",
            "endsAt": "2024-08-27T07:05:02.93Z",
            "generatorURL": "http://prometheus-7fb6f8885b-4zs92:9090/graph?g0.expr=up%7Bgroup%3D%22be%22%2Cjob%3D%22doris%22%7D+%3D%3D+0&g0.tab=1",
            "fingerprint": "b348125a5fcebeab"
        }
    ],
    "groupLabels": {
        "instance": "192.168.3.126:8040"
    },
    "commonLabels": {
        "alertname": "BeDown",
        "cluster": "kubernetes",
        "group": "be",
        "instance": "192.168.3.126:8040",
        "job": "doris",
        "severity": "critical"
    },
    "commonAnnotations": {
        "description": "Doris BE 192.168.3.126:8040 宕机",
        "summary": "Doris BE 192.168.3.126:8040 宕机"
    },
    "externalURL": "http://alertmanager-6dfb84b96-rgbvb:9093",
    "version": "4",
    "groupKey": "{}:{instance=\"192.168.3.126:8040\"}",
    "truncatedAlerts": 0
}
```






































































































