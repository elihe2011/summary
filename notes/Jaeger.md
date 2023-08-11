# 1. 介绍

Jaeger 是 Uber 开源的一款**分布式追踪系统**，兼容 OpenTracing API，适用于如下场景：

- 分布式追踪信息传递
- 分布式事务监控
- 问题分析
- 服务依赖性分析
- 性能优化



Jaeger 全链路追踪功能的三个角色：

- client：负责全链路上各个调用点的计时、采样，并将 tracing 数据发往本地 agent
- agent：负责收集 client 发来的 tracing 数据，并以 thrift 协议转发给 collector
- collector：负责收集所有 agent 上报的 tracing 数据，统一存储



# 2. 安装

```bash
docker run -d --name jaeger \
  -e TZ=Asia/Shanghai \
  -e COLLECTOR_ZIPKIN_HOST_PORT=:9412 \
  -p 16686:16686 \
  -p 14268:14268 \
  -p 9412:9412 \
  --restart=always \
  jaegertracing/all-in-one:1.36
```

http://localhost:16686



# 3. 架构

all-in-one 包含 Jaeger UI（query）、收集器（collector）、查询（query）和代理（agent）， 它将收集到的追踪数据存储在内存中，因此，重启容器后会丢失所有的数据。

为了便于后续的数据分析，需要将追踪数据进行持久化存储，Jaeger 支持 cassandra、elasticsearch、kafka（缓存）、grpc-plugin、badger（仅适用 all-in-one）、memory（仅适用 all-in-one）。对于大规模的生产部署，Jaeger 团队推荐 Elasticsearch 后端，而不是 Cassandra 。

根据 Jaeger 架构，没有缓存的情况下收集器（collector）直接将数据写入存储。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/jaeger-arch.png) 

也可以将 kafka 作为初始缓存区，这个之后再加。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/jaeger-arch-with-kafka.png) 

使用 elasticsearch(+kibana) 作为存储后端：

1. 直接使用 all-in-one 容器部署
2. 单独部署 Jaeger 的各个组件
   - agent：Jaeger 客户端要求 jaeger-agent 进程在每个主机上本地运行。
   - collector：收集器是无状态的，可以并行运行多个 jaeger-collector 实例。
   - query：jaeger-query 服务于 API 端点和 React/Javascript UI。该服务是无状态的，通常运行在负载均衡器之后，比如 NGINX。
   - ingester：jaeger-ingester 能够从 Kafka 读取数据，然后将其写入存储后端（Elasticsearch/Cassandra）。

使用 docker 容器运行，并挂载卷（将数据存储到本机而不是容器内）；从 elasticsearch 获取数据，使用 kibana 查看数据情况。



## 3.1 all-in-one

按顺序创建容器，使用 `--link` 进行链接，非常容易构建。

```bash
# elasticsearch
docker run -d --name=elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:7.12.1

# kibana
docker run -d --name=kibana --link=elasticsearch -p 5601:5601
docker.elastic.co/kibana/kibana:7.12.1

# all-in-one
docker run -d --name jaeger \
  --link=elasticsearch \
  -e SPAN_STORAGE_TYPE=elasticsearch \
  -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
  -e ES_SERVER_URLS=http://elasticsearch:9200 \
  -e ES_TAGS_AS_FIELDS_ALL=true \
  -p 5775:5775/udp \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 14268:14268 \
  -p 14250:14250 \
  -p 9411:9411 \
  jaegertracing/all-in-one
```



## 3.2 elasticsearch  挂载

本地目录：

```bash
# 创建目录
sudo mkdir -p /usr/share/elasticsearch/config /usr/share/elasticsearch/data /usr/share/elasticsearch/logs

# 挂载
docker run -d --name=test \
-e "discovery.type=single-node" \
-e "xpack.security.enabled=false" \
--mount type=bind,source=/usr/share/elasticsearch/config,target=/usr/share/elasticsearch/config \
--mount type=bind,source=/usr/share/elasticsearch/data,target=/usr/share/elasticsearch/data \
--mount type=bind,source=/usr/share/elasticsearch/logs,target=/usr/share/elasticsearch/logs \
docker.elastic.co/elasticsearch/elasticsearch:7.12.1
```



1. 挂载卷

卷空时不会覆盖掉容器内原有的数据。

```bash
# 创建卷
docker volume create my-vol

# 查看卷
docker inspect my-vol

# 删除卷
docker volume rm my-vol

# 挂载卷
docker volume create es-config
docker volume create es-data
docker volume create es-logs

docker run -d --name=test \
-p 9201:9200 -p 9301:9300 \
-e "discovery.type=single-node" \
-e "xpack.security.enabled=false" \
--mount source=es-config,target=/usr/share/elasticsearch/config \
--mount source=es-data,target=/usr/share/elasticsearch/data \
--mount source=es-logs,target=/usr/share/elasticsearch/logs \
docker.elastic.co/elasticsearch/elasticsearch:7.12.1

# 测试
curl -X GET "localhost:9201/_cat/nodes?v=true&pretty"
```



