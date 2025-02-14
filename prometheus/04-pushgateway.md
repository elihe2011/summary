# 1. 概述

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/push-gateway.png)

工作流程：

- 监控源通过 Post 方式，发送数据到 PushGateway，路径 `/metrics`
- Prometheus 设置任务，定时获取 PushGateway 上的监控指标
- Prometheus 收集到指标后，根据告警规则，如果匹配将触发告警到 Alertmanager；同时 Grafana 可配置数据源调用 Prometheus 数据，作为数据展示
- AlertManager 收到告警后，根据规则转发到对应接收人即接收方式



# 2. 部署

为了防止 pushgateway 重启或意外挂掉，导致数据丢失，我们可以通过 -persistence.file 和 -persistence.interval 参数将数据持久化下来。

```bash
mkdir -p /opt/pushgateway/data

docker run -d --name pushgateway \
    -p 9091:9091 \
    -e TZ="Asia/Shanghai" \
    -v /opt/pushgateway/data:/pushgateway \
    --restart=always prom/pushgateway:v1.9.0 \
    --persistence.file=/pushgateway/pushgateway_persist_file \
    --persistence.interval=5m
```



从 PushGateway 中采集数据，在 prometheus.yml 添加如下内容：

```yaml
scrape_configs:
  ...
  - job_name: 'pushgateway'
    scrape_interval: 10s # 每过10秒拉取一次
    honor_labels: true
    static_configs:
      - targets: ['192.168.3.111:9091']
```

刷新配置：`curl -X POST http://192.168.3.111:9090/-/reload`



查看当前主机上容器的运行状态：http://192.168.3.111:9091


```bash

```



# 3. 数据推送

## 3.1 SDK

https://prometheus.io/docs/instrumenting/clientlibs/

以 Python 为例：`pip3 install prometheus-client`

```python
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
import random
import time

if __name__ == '__main__':
    registry = CollectorRegistry()
    g = Gauge('raid_status', '1 if raid array is okay', registry=registry)
    g.labels(method='get',path='/test',instance='aaa').inc(3)

    while True:
        g.set(random.random())
        push_to_gateway('localhost:9091', job='pushgateway', registry=registry)
        time.sleep(15)
```



## 3.2 API

默认 URL 地址：`http://<ip>:9091/metrics/job/<JOBNAME>{/<LABEL_NAME>/<LABEL_VALUE>} `



```bash
echo "request_error_number 99" | curl --data-binary @- http://localhost:9091/metrics/job/link_job

curl --data-binary @- http://localhost:9091/metrics/job/snmp/instance/$ip

cat <<EOF | curl --data-binary @- http://localhost:9091/metrics/job/pushgateway/instance/10.40.80.1
# TYPE http_request_total counter
http_request_total{code="200",path="/pay"} 12
http_request_total{code="200",path="/cart"} 20
EOF
```





