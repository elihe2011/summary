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



# 4. 镜像和容器管理

```bash
# 本地镜像打包成一个tar文件
docker save -o redis-python-save.tar redis python

# 恢复镜像
docker load -i redis-python-save.tar

# 容器打包
docker export -o nginx-export.tar nginx

# 容器恢复 (注意：恢复成镜像，并支持更改镜像的tag)
docker import -i nginx-export.tar nginx:v1.0
```

使用场景：

- `save & load`: 适合 `docker-compose.yml` 编排的组合镜像，进行离线的迁移
- `export & import`: 适合在基础镜像启动的容器中，安装了其他软件或服务后，将该容器导出，形成一个新的镜像。

tar 文件的区别：

- `save`: 是一个 docker 分层文件系统。
- `export`: 是一个 Linux 系统文件目录
- `save`的文件较大：因为它由一层层文件系统叠加起来，各层文件系统存在很多重复的文件，所以较大。



# 5. 安装 

```bash
# 安装 docker
sudo apt install docker.io

# 免 sudo，重新登录后生效
sudo usermod -aG docker $USER
sudo systemctl restart docker

# 安装 docker-compose
$ sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

$ sudo chmod +x /usr/local/bin/docker-compose

$ sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

$ docker-compose --version
docker-compose version 1.29.1, build c34c88b2
```



# 6. Dockerfile

```dockerfile
FROM python:3.8-alpine

MAINTAINER Huitone <hehz@huitone.com>

RUN apk add --virtual .build-dependencies \
    gcc \
    git \
    libffi-dev \
    libgcc \
    libxslt-dev \
    libxml2-dev \
    make \
    musl-dev \
    openssl-dev \
    zlib-dev \
    build-base

COPY . /opt/ryu/

WORKDIR /opt/ryu

RUN pip install -r ./tools/pip-requires && \
    python3 ./setup.py install && \
    chmod u+x ./bin/ryu ./bin/ryu-manager ./docker-entry.sh && \
    rm -rf ~/.cache/pip && \
    apk del .build-dependencies && \
    rm -rf /var/cache/apk/*

EXPOSE 6653 8080

ENTRYPOINT ["./docker-entry.sh"]
```



# 7. docker-compse

```yaml
version: "3"
services:
  sdn-controller:
    image: sdn-controller:latest
    container_name: sdn-controller
    ports:
      - 8080:8080
      - 6653:6653
    environment:
      REDIS_HOST: redis
      REDIS_PORT: 6379
      TZ: Asia/Shanghai
      LANG: en_US.UTF-8
    depends_on:
      - redis
    volumes:
      - ./conf/ryu_app.list:/opt/ryu/ryu_app.list
      - ./log:/opt/ryu/log
  redis:
    image: redis:5.0.12
    container_name: redis
    ports:
      - 6379:6379
    restart: always
    environment:
      TZ: Asia/Shanghai
      LANG: en_US.UTF-8
    volumes:
      - ./data:/data
      - ./conf/redis.conf:/usr/local/redis/redis.conf
    command:
      redis-server /usr/local/redis/redis.conf
```



docker-compose 管理：

```bash
docker-compose up
docker-compose up -d  # 后台方式
docker-compose up --no-recreate -d
docker-compose up -d redis  # 只启动容器 redis

docker-compose stop 
docker-compose start

docker-compose down # 停止并销毁容器
```



# 8. 容器诊断

```bash
# 保存案发现场
docker commit 05dd6f84ddf9 user/debug

# 以命令行方式启动
docker run -it --rm user/debug /bin/sh

docker run --rm --entrypoint="" grafana/grafana:latest /bin/sh -c 'cat /etc/passwd | grep grafana'
```

