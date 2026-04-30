# 1. Kafka

## 1.1 部署

```bash
mkdir -p /opt/kafka/data
chown 1001:1001 /opt/kafka/data

cat > /opt/kafka/docker-compose.yml <<EOF
version: "3"
networks:
  kafka_net:
    ipam:
      config:
        - subnet: 172.31.80.0/24
services:
  kafka:
    image: bitnami/kafka:3.8.0
    container_name: kafka
    restart: always
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    environment:
      - TZ=Asia/Shanghai
      - KAFKA_CFG_NODE_ID=0
      - KAFKA_CFG_PROCESS_ROLES=controller,broker
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@kafka:9093
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092,EXTERNAL://192.168.3.116:9094
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
    networks:
      - kafka_net
    ports:
      - '9092:9092'
      - '9094:9094'
    volumes:
      - ./data:/bitnami/kafka
EOF

docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/bitnami/kafka:3.8.0
docker tag swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/bitnami/kafka:3.8.0 bitnami/kafka:3.8.0

cd /opt/kafka
docker-compose up -d
docker-compose ps
```



## 1.2 操作

### 1.2.1 创建主题

```bash
docker exec -it kafka kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --replication-factor 1 \
  --partitions 1 \
  --topic telegraf-topic
```



### 1.2.2 生产消息

```bash
docker exec -it kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic telegraf-topic
```



### 1.2.3 消费消息

```bash
docker exec -it kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic telegraf-topic \
  --from-beginning
```



### 1.2.4 查看主题列表

```bash
docker exec -it kafka kafka-topics.sh --list \
  --bootstrap-server localhost:9092
```



# 2. Telegraf

```bash
mkdir -p /opt/telegraf/{etc,mibs}

# prometheus
cat > /opt/telegraf/etc/telegraf.conf <<EOF
[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000

[[inputs.snmp]]
  agents = ["192.168.3.112:161"]
  version = 3
  community = "public"
  retries = 3
  max_repetitions = 10
  sec_name = "tksnmp"
  auth_protocol = "MD5"
  auth_password = "tk@Xdt168"
  sec_level = "authPriv"
  priv_protocol = "DES"
  priv_password = "tk@Xdt168"
  agent_host_tag = "instance"
  
  [inputs.snmp.tags]
    device_type = "server"
    sys = "IGOM"
  
  [[inputs.snmp.field]]
    name = "sysUpTime"
    oid  = "1.3.6.1.2.1.1.3.0"
    conversion = "float(2)"

  [[inputs.snmp.field]]
    oid = "1.3.6.1.2.1.1.5.0"
    name = "sysName"
    is_tag = true

  [[inputs.snmp.table]]
    oid = "1.3.6.1.2.1.2.2"
    name = "ifTable"
    inherit_tags = ["sysName"]
    
    [inputs.snmp.tagdrop]
      ifDescr = ["docker0", "veth*"]

    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.2"
      name = "ifDescr"
      is_tag = true
    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.7"
      name = "ifAdminStatus"
      is_tag = true
    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.8"
      name = "ifOperStatus"
      is_tag = true

[[processors.override]]
  namepass = ["ifTable"]
  fielddrop = ["ifSpeed", "ifLastChange", "ifInUcastPkts", "ifInNUcastPkts", "ifOutUcastPkts", "ifOutNUcastPkts", "ifOutQLen", "ifSpecific", "ifDescr", "ifType", "ifAdminStatus", "ifOperStatus"]

[[outputs.prometheus_client]]
listen = ":9273"
EOF

cat > /opt/telegraf/docker-compose.yml <<EOF
version: "3"
networks:
  telegraf_net:
    ipam:
      config:
        - subnet: 172.31.81.0/24
services:
  telegraf:
    image: telegraf:1.36.4
    container_name: telegraf
    volumes:
      - ./etc/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - ./mibs:/etc/telegraf/.snmp/mibs
    environment:
      - TZ=Asia/Shanghai
    networks:
      - telegraf_net
    ports:
      - '9273:9273'
EOF

docker pull telegraf:1.36.4

cd /opt/telegraf
docker-compose up -d
docker-compose ps
```





```bash
cat > /opt/telegraf/etc/telegraf.conf <<EOF
[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000

[[inputs.snmp]]
  agents = ["192.168.3.112:161"]
  version = 3
  community = "public"
  retries = 3
  max_repetitions = 10
  sec_name = "tksnmp"
  auth_protocol = "MD5"
  auth_password = "tk@Xdt168"
  sec_level = "authPriv"
  priv_protocol = "DES"
  priv_password = "tk@Xdt168"
  agent_host_tag = "instance"
  
  [inputs.snmp.tags]
    device_type = "server"
    sys = "IGOM"
  
  [[inputs.snmp.field]]
    name = "sysUpTime"
    oid  = "1.3.6.1.2.1.1.3.0"
    conversion = "float(2)"

  [[inputs.snmp.field]]
    oid = "1.3.6.1.2.1.1.5.0"
    name = "sysName"
    is_tag = true

  [[inputs.snmp.table]]
    oid = "1.3.6.1.2.1.2.2"
    name = "ifTable"
    inherit_tags = ["sysName"]
    
    [inputs.snmp.tagdrop]
      ifDescr = ["docker0", "veth*"]

    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.2"
      name = "ifDescr"
      is_tag = true
    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.7"
      name = "ifAdminStatus"
      is_tag = true
    [[inputs.snmp.table.field]]
      oid = "1.3.6.1.2.1.2.2.1.8"
      name = "ifOperStatus"
      is_tag = true

[[processors.override]]
  namepass = ["ifTable"]
  fielddrop = ["ifSpeed", "ifLastChange", "ifInUcastPkts", "ifInNUcastPkts", "ifOutUcastPkts", "ifOutNUcastPkts", "ifOutQLen", "ifSpecific", "ifDescr", "ifType", "ifAdminStatus", "ifOperStatus"]
  
[[processors.starlark]]
  namepass = ["ifTable"]
  source = '''
load("json.star", "json")

def apply(metric):   
    # 自定义 JSON 结构
    new_metric = {
        "metric": "server_interface_inoctets",
        "value": metric.fields["ifInOctets"],
        "timestamp_ms": metric.time * 1000,
        "description": "接收总字节",
        "unit": "byte",
        "type": "counter",
        "labels": metric.tags
    }
    
    # 将 JSON 作为单字段发送
    return json.encode(new_metric)
'''

[[outputs.kafka]]
  brokers = ["192.168.3.116:9094"]
  topic = "telegraf-topic"
  data_format = "json"
EOF
```



# 3. Prometheus

注意：**默认安装到 `/opt` 目录下，如果安装到其它目录，需要同步修改如下的目录和配置**



## 3.1 解压安装包

```bash
tar zxvf prometheus-2.53.5-amd64-20251119.tar.gz -C /opt
```



## 3.2 创建用户

```bash

chown -R prometheus:prometheus /opt/prometheus
```



## 3.3 创建启动文件

```bash
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=always
RestartSec=5s
LimitNOFILE=65536
ExecStart=/opt/prometheus/bin/prometheus \
  --config.file=/opt/prometheus/etc/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.console.templates=/opt/prometheus/consoles \
  --web.console.libraries=/opt/prometheus/console_libraries \
  --web.enable-lifecycle \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.retention.time=3d

[Install]
WantedBy=multi-user.target
EOF
```



## 3.4 启动服务

```bash
systemctl enable prometheus.service
systemctl start prometheus.service

systemctl status prometheus.service
```



# 4. snmp_exporter

## 4.1 解压安装包

注意：**默认安装到 `/opt` 目录下，如果安装到其它目录，需要同步修改如下的目录和配置**



## 3.1 解压安装包

```bash
tar zxvf prometheus-2.53.5-amd64-20251119.tar.gz -C /opt
```



## 3.2 创建用户

```bash
useradd --no-create-home --shell /bin/false prometheus
chown -R prometheus:prometheus /opt/prometheus
```



## 3.3 创建启动文件

```bash
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/bin/prometheus \
  --config.file=/opt/prometheus/etc/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.console.templates=/opt/prometheus/consoles \
  --web.console.libraries=/opt/prometheus/console_libraries \
  --web.enable-lifecycle \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.retention.time=3d

Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```



## 3.4 启动服务

```bash
systemctl enable prometheus.service
systemctl start prometheus.service

systemctl status prometheus.service
```

