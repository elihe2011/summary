# 1. 配置文件

创建相关目录：

```bash
mkdir -p monitor && cd $_
mkdir -p rules
mkdir -p prometheus && chmod 777 prometheus
mkdir -p grafana && chmod 777 grafana
```



## 1.1 prometheus

`prometheus.yml`：

```yaml
global:
  scrape_interval:     15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - 192.168.3.107:9093

rule_files:
  - "rules/*_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
    - targets: ['192.168.3.107:9100']

  - job_name: 'cadvisor'
    static_configs:
    - targets: ['192.168.3.107t:8080']
      labels:
        group: docker

  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
    - targets: ['192.168.3.107:9091']

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



``rules/node_rules.yml`:

```yaml
groups:
- name: node_alert
  rules:
  - alert: cpu_alert
    expr: 100 - avg(irate(node_cpu_seconds_total{mode="idle"}[1m])) by (instance)* 100 > 10
    for: 1m
    labels:
      level: warning
    annotations:
      description: "instance: {{ $labels.instance }}, cpu usage is too high! value: {{ $value }}"
      summary: "cpu usage is too high"
```



## 1.2 alertmanager

`alertmanager_webhook.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alert']
  group_wait: 30s
  group_interval: 1m
  repeat_interval: 30s
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  webhook_configs:
    - url: http://192.168.3.107:5001/
```

`alertmanager_email.yml`:

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.sina.com:25'
  smtp_from: 'xxx@sina.com'
  smtp_auth_username: 'xxx@sina.com'
  smtp_auth_password: '***'
  smtp_require_tls: false
  smtp_hello: 'sina.com'

route:
  group_by: ['alert']
  group_wait: 30s
  group_interval: 1m
  repeat_interval: 30s
  receiver: 'mail-receiver'

receivers:
- name: 'mail-receiver'
  email_configs:
  - to: 'xxx@live.cn'
```



## 1.3 blackbox-exporter

`blackbox-exporter.yml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200, 301, 302]
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      method: GET
```



# 2. docker-compose.yml

```yaml
version: '3'

networks:
  monitor-net:
    driver: bridge
        
services: 
  prometheus:
    image: prom/prometheus:v2.37.0
    container_name: prometheus
    volumes:
      - /etc/localtime:/etc/localtime
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus:/prometheus
    command:
      - '--web.enable-lifecycle'
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports: 
      - 9090:9090
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
      
  node-exporter:
    image: prom/node-exporter:v1.3.1
    container_name: node-exporter
    volumes:
      - /etc/localtime:/etc/localtime
      - /proc:/host/proc
      - /sys:/host/sys
      - /:/rootfs
    command: 
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
    ports: 
      - 9100:9100
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
      
  alertmanager:
    image: prom/alertmanager:v0.24.0
    container_name: alertmanager
    volumes:
      - /etc/localtime:/etc/localtime
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    ports: 
      - 9093:9093
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"

  cAdvisor:
    image: gcr.io/cadvisor/cadvisor:v0.45.0
    container_name: cAdvisor
    privileged: true
    volumes:
      - /etc/localtime:/etc/localtime
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro 
    devices: 
      - /dev/kmsg:/dev/kmsg
    ports: 
      - 8080:8080
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"

  pushgateway:
    image: prom/pushgateway:v1.4.3
    container_name: pushgateway
    ports: 
      - 9091:9091
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
      
  blackbox-exporter:
    image: prom/blackbox-exporter:v0.22.0
    container_name: blackbox-exporter
    volumes:
      - /etc/localtime:/etc/localtime
      - ./blackbox-exporter.yml:/etc/blackbox_exporter/config.yml
    ports: 
      - 9115:9115
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
      
  grafana:
    image: grafana/grafana:9.0.6
    container_name: grafana
    volumes:
      - /etc/localtime:/etc/localtime
      - ./grafana:/var/lib/grafana
    environment:
      - GF_DEFAULT_INSTANCE_NAME=grafana
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports: 
      - 3000:3000
    networks: 
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
```



# 3. 管理

```bash
docker-compose up -d

docker-compose down
```

