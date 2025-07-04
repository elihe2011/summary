# 1. 简介

VictoriaMetrics 是一个快速、支持该可用且可扩展的开源时序数据库和监控解决方案，可以作为 Prometheus 的远端存储。

优点：

- 兼容 Prometheus 的API，可直接用作 Grafana 的数据源
- 内存占用率低
- 查询速度快
- 设置和操作简单
- 支持水平扩容和HA
- 高压缩比



版本选择：

- 单机版：官方建议采集数据点(data points)低于 100w/s，推荐 VM 单节点版，简单好维护，但不支持告警
- 集群版：支持水平拆分，根据功能拆分为不同的组件 vmselect、vminsert、vmstoarge，如果替换 Prometheus 还可以加上 vmagent 和 vmalert.



集群版架构图：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/victoria-metrics-arch.png)



核心组件：

- vmstorage：数据存储
- vminsert：接收写入请求，并根据数据的 hash 结果将数据写入后端不同的 vmstorage 上，实现数据分片
- vmselect：接收查询请求，从后端 vmstorage 检索数据



可选组件：

- vmagent：类似 Prometheus，负责从各种数据源收集指标数据

- vmalert：类似 AlertManager，负责告警处置和转发
- vmctl：命令行工具



# 2. 部署

## 2.1 单机版

```bash
mkdir -p /opt/victoria-metrics/storage

docker run -d \
   --name victoria-metrics \
   -p 8428:8428 \
   -v /opt/victoria-metrics/storage:/storage \
   --restart=always \
   victoriametrics/victoria-metrics:v1.120.0 \
   --storageDataPath=/storage \
   --retentionPeriod=365d \
   --httpListenAddr=:8428 \
   --loggerTimezone=Asia/Shanghai
```



Prometheus-Remote-Write：http://192.168.3.108:8428/api/v1/write

Grafana-DataSource: http://192.168.3.108:8482

VMUI：http://192.168.3.108:8428/vmui



## 2.2 集群版

```bash
mkdir -p /opt/victoria-metrics/storage
cd /opt/victoria-metrics

cat > docker-compose.yml <<EOF
version: '3'

networks:
  vm-network:
    driver: bridge

services:
  vmstorage:
    image: victoriametrics/vmstorage:v1.120.0-cluster
    container_name: vmstorage
    restart: always
    ports:
      - "8482:8482"
      - "8400:8400"
      - "8401:8401"
    volumes:
      - ./storage:/storage
    command:
      - "--httpListenAddr=:8482"
      - "--vminsertAddr=:8400"
      - "--vmselectAddr=:8401"
      - "--retentionPeriod=30d"
      - "--storageDataPath=/storage"
      - "--loggerTimezone=Asia/Shanghai"
    networks:
      - vm-network
      
  vminsert:
    image: victoriametrics/vminsert:v1.120.0-cluster
    container_name: vminsert
    restart: always
    ports:
      - "8480:8480"
    command:
      - "--httpListenAddr=:8480"
      - "--storageNode=vmstorage:8400"
      - "--loggerTimezone=Asia/Shanghai"
    networks:
      - vm-network

  vmselect:
    image: victoriametrics/vmselect:v1.120.0-cluster
    container_name: vmselect
    restart: always
    ports:
      - "8481:8481"
    command:
      - "--httpListenAddr=:8481"
      - "--storageNode=vmstorage:8401"
      - "--loggerTimezone=Asia/Shanghai"
    networks:
      - vm-network
EOF

docker-compose up -d
```



Prometheus-Remote-Write：http://192.168.3.108:8481/insert/0/prometheus

Grafana-DataSource: http://192.168.3.108:8481/select/0/prometheus

VMUI：http://192.168.3.108:8481/select/0/vmui/



# 3. 其他问题

## 3.1 开启数据复制

默认情况下，数据被 vmselect 组件基于 hash 算法分别写入到不同的 vmstorage 节点，数据只保留一份，如果有 vmstorage 节点宕机会造成部分数据丢失，可以启用 vminsert 组件的 `-replicationFactor=N` 参数启用复制功能，将数据分别在 N 个节点上都写入，以实现数据的高可用。

但复制功能会增加 vminsert 和 vminsert 组件的资源使用率，因为 vminsert 需要写入多份数据，vmselect 从多个 vmstorage 读取数据后需要去重。官方建议将数据的高可用交给 vmstorage 数据存储路径的磁盘，并定期备份数据。











































