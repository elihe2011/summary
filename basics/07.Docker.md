# 1. 常用 docker 镜像

```bash
docker pull mysql:5.7
docker run --name mysql-server -p 3306:3306 -v /data/mysql/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=123456 -d mysql:5.7

docker pull redis:6.0.10
docker run --name reids-server -p 6379:6379 -d redis:6.0.10

docker pull docker.elastic.co/elasticsearch/elasticsearch:7.10.2
docker run --name es -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" -d docker.elastic.co/elasticsearch/elasticsearch:7.10.2

# jaegertracing
docker run -d -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 -p 5775:5775/udp -p 6831:6831/udp -p 6832:6832/udp -p 5778:5778  -p 16686:16686 -p 14268:14268  -p 14269:14269   -p 9411:9411 jaegertracing/all-in-one:1.21
http://192.168.31.200:16686/
```



# 2. `k8s.gcr.io`

阿里云代理仓库：**registry.aliyuncs.com/google_containers**

```bash
docker pull registry.aliyuncs.com/google_containers/coredns:1.6.5

docker tag registry.aliyuncs.com/google_containers/coredns:1.6.5 k8s.gcr.io/coredns:1.6.5

docker rmi registry.aliyuncs.com/google_containers/coredns:1.6.5
```



# 3. 清理环境

```bash
docker kill $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
docker volume rm $(docker volume ls -q)
```



