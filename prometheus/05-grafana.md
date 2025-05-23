# 1. 概述

Grafana 是一个开源的度量分析和可视化工具，它提供查询、可视化、告警和指标展示等功能，能够灵活创建图表、仪表盘等可视化界面。

主要的功能：

- 可视化：快速灵活的客户端图形和多种选项，面板插件支持多种不同的方式来可视化指标和日志，例如：热图、折线图、图表等多种展示方式；
- 动态仪表盘：提供以模板和变量的方式来创建动态且可重复使用的仪表盘
- 浏览指标：通过瞬时查询和动态变化等方式展示数据，可根据不同的时间范围拆分视图
- 浏览日志：可快速搜索所有日志或实时流式传输的数据
- 告警通知：支持以可视化方式定义警报规则，并会不断的计算数据，在指标达到阀值时通过Slack、PagerDuty、VictorOps等系统发送通知。
- 混合数据源：支持Graphite，InfluxDB，OpenTSDB，Prometheus，Elasticsearch，Mysql等多种数据源；



# 2. 部署

```bash
groupadd -g 472 grafana
useradd -g 472 -u 472 grafana

mkdir -p /opt/grafana/{data,log}
chmod -R 777 /opt/grafana

docker run -d --name grafana \
    -p 3000:3000 \
    -v /opt/grafana/data:/var/lib/grafana \
    -v /opt/grafana/log:/var/log/grafana \
    -e GF_SECURITY_ADMIN_USER="admin" \
    -e GF_SECURITY_ADMIN_PASSWORD="Admin@123" \
    -e GF_AUTH_PROXY_ENABLED="true" \
    -e GF_AUTH_ANONYMOUS_ENABLED="true" \
    -e GF_AUTH_ANONYMOUS_ORG_ROLE="Admin" \
    --privileged=true \
    --restart=always grafana/grafana:11.1.4
```



# 3. 基本概念

## 3.1 数据源

为 Grafana 提供数据的对象均称为数据源 (Data Source)。Grafana 官方支持的数据源有 Graphite, InfluxDB, OpenTSDB, Prometheus, ElasticSearch, CloudWatch 等。

**Step 1**：新增数据源：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-datasource.png)



**Step 2**：Prometheus 源

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-prometheus.png)



## 3.2 仪表盘

Grafana 数据可视化图表通过 Dashboard 来组织和管理

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-layout.png)

在一个 Dashboard 中一个最基本的可视化单元为一个 Panel，面板通过如趋势图、热力图等形式展示可视化数据。每个 Panel 是一个完全独立的部分，通过 Panel 的 **Query Editor** 查询数据源。



**Step 1**：创建仪表盘

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard.png)



**Step 2**：新增面板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-panel-new.png)



**Step 3**：配置查询语言，并生效

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-panel-query.png)



## 3.3 组织和用户

在 Grafana 中 Dashboard 属于一个 Organization，通过组织，可更大规模上使用 Grafana。支持创建多个 Organization，其中 User 可以属于一个多个不同的 Organization。在不同的 Organization 下，可以为 User 赋予不同的权限。



# 4. 面板

Panel 是 Grafana 中最基本的可视化单元。每一种类型的面板都提供了相应的查询编辑器 (Query Editor)，让用户可以从不同的数据源中查询出相应的监控数据，并可视化展示。

内置面板类型：Graph，Singlestat, Heatmap, Dashlist, Table, Text



## 4.1 变化趋势：Graph面板

Graph 面板通过折线图或柱状图的形式展示监控样本随时间而变化的趋势。适用于 Prometheus 中 Gauge 和 Counter 类型监控指标数据的可视化。

示例：主机 CPU 使用率变化趋势

```promql
1 - (avg(irate(node_cpu_seconds_total{mode='idle'}[5m])) without (cpu))
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-graph-counter.png)

画图选项：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-graph-options.png)



## 4.2 分布统计：Heatmap 面板

Heatmap 热力图可以直观的查看样本的分布情况

Heatmap Panel 可以对Histogram 类型的监控指标情况进行计划，获取到每个区间范围内的样本个数，并且以颜色的深浅来表示当前区间内样本个数的大小。而图形的高度，则反映出当前时间点，样本分布的离散程度。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-heatmap-histogram.png)



## 4.3 Stat 面板

Stat Panel 侧重展示系统的当前状态而非变化趋势，适合如下场景：

- 当前系统中所有服务的运行状态
- 当前集成设施资源的使用量
- 当前系统中某些事件发生的次数或资源数量等

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-stat-counter.png)



# 5. 监控模板

## 5.1 使用模板

**Step 1**: 到 grafana.com 官网查询适合需求的模板

这里使用node exporter的模板12633 进行测试



**Step 2**：导入模板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-node-import.png)



**Step 3**：加载模板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-node-load.png)



**Step 4**：数据展示

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-node-show.png)



## 5.2 模板问题

问题：**Grafana导入 json 文件的 dashboard 错误 Templating Failed to upgrade legacy queries Datasource xxx not found**

编辑或者修改后的 `dashboard` 保存为 `json` 文件，在其他环境导入使用，报错 `Failed to upgrade legacy queries Datasource xxxxxxx was not found`，无法显示监控数据

问题原因：从其他 `grafana` 导出的 `dashboard` json文件中，数据源是写的固定的，如果当前要显示的监控数据的数据源名称跟这个不同，就会报错。



编辑json文件，增加 Prometheus 数据源：

```json
{
  // 新增 __inputs，配置变量
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "description": "",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
  "__elements": [],
  "__requires": [],
  ...
    
  // 修改数据源为变量
  "datasource": {
     "type": "prometheus",
     "uid": "bdyuq7ym5hedcc"  // 改为 "${DS_PROMETHEUS}"
  },
   
```



编辑json文件，增加 Loki 数据源：

```json
{
  // 新增 __inputs，配置变量
  "__inputs": [
    {
      "name": "DS_LOKI",
      "label": "Loki",
      "description": "",
      "type": "datasource",
      "pluginId": "loki",
      "pluginName": "Loki"
    }
  ],
  "__elements": [],
  "__requires": [],
  ...
    
  // 修改数据源为变量    
  "datasource": {
     "type": "loki",
     "uid": "eejyu5zeqtedcf"   // 改为 "${DS_LOKI}"
   },
    
```

