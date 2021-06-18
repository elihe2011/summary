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



 ENTRYPOINT 与 CMD 的关系

1. 如果没有定义 ENTRYPOINT， CMD 将作为它的 ENTRYPOINT
2. 定义了 ENTRYPOINT 的话，CMD 只为 ENTRYPOINT 提供参数
3. CMD 可由 docker run <image> 后的命令覆盖，同时覆盖参数 



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



**docker-compose & docker stack 对比**：

```bash
docker-compose -f docker-compose.yml up

docker stack deploy -c docker-compose.yml somestackname
```

docker stack 兼容 docker-compose v3的yaml语法，但不支持 build 操作，关注于容器的编排



# 8. 容器诊断

```bash
# 保存案发现场
docker commit 05dd6f84ddf9 user/debug

# 以命令行方式启动
docker run -it --rm user/debug /bin/sh

docker run --rm --entrypoint="" grafana/grafana:latest /bin/sh -c 'cat /etc/passwd | grep grafana'
```



# 9. 获取宿主机root权限

```bash
docker run --privileged=true  

docker run -d --name zookeeper --publish 2181:2181 zookeeper
```



# 10. 网络类型

docker五种网络模式：

-  bridge: 桥接式网络模式(默认)
-  host(open):  开放式网络模式，和宿主机共享网络
-  container(join):  联合挂载式网络模式，和其他容器共享网络
-  none(Close):  封闭式网络模式，不为容器配置网络
-  user-defined: 主要可选的网络驱动有三种：bridge、overlay、macvlan。bridge驱动用于创建类似于前面提到的bridge网络；overlay和macvlan驱动用于创建跨主机的网络。



docker run --network=container:mysql 



# 11. 私有仓库 


## 11.1 Registry

官方私有仓库，优点：简单；缺点：部署无法进行复杂的管理操作

### 11.1.1 镜像

```bash
docker pull refistry:2.7.1
docker pull joxit/docker-registry-ui:latest   # 非必须，简单的界面
```

### 11.1.2 配置私有仓库

```bash
cat > /etc/docker/registry/config.yml <<EOF
version: 0.1
log:
  accesslog:
    disabled: true
  level: debug
  formatter: text
  fields:
    service: registry
    environment: staging
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['http://192.168.80.250']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
  http2:
    disabled: false
health:
  storagedriver:
    enabled: true
    interval: 10s
threshold: 3
EOF
```

### 11.1.3 启动

```bash
cat > docker-compose.yaml <<EOF
version: '2.0'
services:
  registry:
    image: registry:2.7.1
    ports:
      - 5000:5000
    volumes:
      - /opt/registry:/var/lib/registry
      - /etc/docker/registry/config.yml:/etc/docker/registry/config.yml

  ui:
    image: joxit/docker-registry-ui:latest
    ports:
      - 80:80
    environment:
      - REGISTRY_TITLE=My Private Docker Registry
      - REGISTRY_URL=http://192.168.80.250:5000
      - SINGLE_REGISTRY=true
    depends_on:
      - registry
EOF

docker-compose  up -d
```

### 11.1.4 镜像推送

```bash
docker tag nginx:latest 192.168.80.250:5000/nginx:latest

docker push 192.168.80.250:5000/nginx:latest
The push refers to repository [192.168.80.250:5000/nginx]
075508cf8f04: Pushed
5c865c78bc96: Pushed
134e19b2fac5: Pushed
83634f76e732: Pushed
766fe2c3fc08: Pushed
02c055ef67f5: Pushed
latest: digest: sha256:61191087790c31e43eb37caa10de1135b002f10c09fdda7fa8a5989db74033aa size: 1570
```

### 11.1.5 登录界面

http://192.168.80.250



## 11.2 Harbor

VMware 中国出品，优点：大而全；缺点：过于庞大，安装很多组件，如redis， nginx，较好资源

### 11.2.1 下载

```bash
cd $HOME
wget https://github.com/goharbor/harbor/releases/download/v2.2.2/harbor-offline-installer-v2.2.2.tgz 
tar xzvf harbor-offline-installer-v2.2.2.tgz
```

### 11.2.2 配置

```bash
cd harbor
cp harbor.yml.tmpl harbor.yml

vi harbor.yml
hostname: 192.168.80.250
port: 8080
harbor_admin_password: Harbor12345
data_volume: /data
location: /var/log/harbor
```

### 11.2.3 安装

```bash
./install.sh
...
[Step 5]: starting Harbor ...
Creating network "harbor_harbor" with the default driver
Creating harbor-log ... done
Creating harbor-portal ... done
Creating harbor-db     ... done
Creating redis         ... done
Creating registry      ... done
Creating registryctl   ... done
Creating harbor-core   ... done
Creating nginx             ... done
Creating harbor-jobservice ... done
✔ ----Harbor has been installed and started successfully.----
```

### 11.2.4 镜像推送

```bash
# 先登录
docker login http://192.168.80.250:8080
Username: admin
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

# 更改镜像tag，注意默认的项目为library，可自行创建其他项目
docker tag golang:1.16-alpine3.12 192.168.80.250:8080/library/golang:1.16-alpine3.12

# 推送镜像
docker push 192.168.80.250:8080/library/golang:1.16-alpine3.12
The push refers to repository [192.168.80.250:8080/library/golang]
bf6a690b6c8b: Pushed
1b3fa7002e97: Pushed
41fa69f8f706: Pushed
09338b69a694: Pushed
32f366d666a5: Pushed
1.16-alpine3.12: digest: sha256:d3a6ef40d7b68a94b5f4299e1aab22d54c08b60e6d707e59f29ca9d00e78b7f0 size: 1365
```

### 11.2.5 登录界面

http://192.168.80.250:8080/    admin/Harbor12345



## 11.3 nexus3

### 11.3.1 安装

```bash
mkdir -p /opt/nexus3 && chown -R 200 /opt/nexus3
docker run -d --name nexus3 --restart=always -p 8081:8081 -v /opt/nexus3:/nexus-data sonatype/nexus3
    
docker logs -f nexus3

2021-06-07 02:41:05,185+0000 INFO  [jetty-main-1] *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer -
-------------------------------------------------
Started Sonatype Nexus OSS 3.30.1-01
-------------------------------------------------
```

### 11.3.2 登录

```bash
# 获取密码
docker exec nexus3 cat /nexus-data/admin.password
6ec95425-7966-4582-ad0d-e39a00c0775c

http://192.168.80.250:8081  admin/6ec95425-7966-4582-ad0d-e39a00c0775c

# 按向导修改密码
admin/admin123

# 开启匿名登录
```

### 11.3.3 创建仓库

创建一个私有仓库的方法： `Repository->Repositories` 点击右边菜单 `Create repository` 选择 `docker (hosted)`

- **Name**: 仓库的名称
- **HTTP**: 仓库单独的访问端口（例如：**8082**）
- **Hosted -> Deplioyment policy**: 请选择 **Allow redeploy** 否则无法上传 Docker 镜像。

其它的仓库创建方法请各位自己摸索，还可以创建一个 `docker (proxy)` 类型的仓库链接到 DockerHub 上。再创建一个 `docker (group)` 类型的仓库把刚才的 `hosted` 与 `proxy` 添加在一起。主机在访问的时候默认下载私有仓库中的镜像，如果没有将链接到 DockerHub 中下载并缓存到 Nexus 中。

### 11.3.4 添加访问权限

菜单 `Security->Realms` 把 Docker Bearer Token Realm 移到右边的框中保存。

添加用户规则：菜单 `Security->Roles`->`Create role` 在 `Privlleges` 选项搜索 docker 把相应的规则移动到右边的框中然后保存。

添加用户：菜单 `Security->Users`->`Create local user` 在 `Roles` 选项中选中刚才创建的规则移动到右边的窗口保存。

### 11.3.5 镜像管理

```bash
# 登录仓库
docker login http://192.168.80.250:8082
Username: admin
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

# 上传镜像
docker tag nginx 192.168.80.250:8082/repository/library/nginx:latest
docker push 192.168.80.250:8082/repository/library/nginx:latest
The push refers to repository [192.168.80.250:8082/repository/library/nginx]
075508cf8f04: Pushed
5c865c78bc96: Pushed
134e19b2fac5: Pushed
83634f76e732: Pushed
766fe2c3fc08: Pushed
02c055ef67f5: Pushed
latest: digest: sha256:61191087790c31e43eb37caa10de1135b002f10c09fdda7fa8a5989db74033aa size: 1570

```




# 12. 配置 daemon.json

```bash
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "insecure-registries" : [ "192.168.80.250:5000" ]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
systemctl restart docker
```



# 14. Docker 组件

````mermaid
graph LR
    A(docker) -->B(dockerd)
    B --grpc--> C(containerd)
    C --exec--> D(docker-shim)
    D --exec--> E(runC)
````

OCI 标准化的产物：

- containerd: 高性能容器运行时
- containerd-ctr: containerd的命令行客户端
- runc: 运行容器的命令行工具



Docker 如何运行一个容器？

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/docker-component-architecture.png) 

- dockerd是docker engine守护进程，dockerd启动时会启动containerd子进程，dockerd与containerd通过rpc进行通信

- ctr是containerd的cli

- containerd通过shim操作runc，runc真正控制容器生命周期，启动一个容器就会启动一个shim进程

- shim直接调用runc的包函数,shim与containerd之前通过rpc通信

- 真正用户想启动的进程由runc的init进程启动，即runc init [args ...]

  ```
  docker        ctr
   |             |
   V             V
   dockerd -> containerd ---> shim -> runc -> runc init -> process
                        |-- > shim -> runc -> runc init -> process
                        +-- > shim -> runc -> runc init -> process
  ```

  

组件通信流程：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/docker-component-comunication.png)

1. docker daemon 模块通过 grpc 和 containerd模块通信：dockerd 由libcontainerd负责和containerd模块进行交换， dockerd 和 containerd 通信socket文件：docker-containerd.sock

2. containerd 在dockerd 启动时被启动，启动时，启动grpc请求监听。containerd处理grpc请求，根据请求做相应动作；

3. 若是start或是exec 容器，containerd 拉起一个container-shim , 并通过exit 、control 文件（每个容器独有）通信；

4. container-shim被拉起后，start/exec/create拉起runC进程，通过exit、control文件和containerd通信，通过父子进程关系和SIGCHLD监控容器中进程状态；

5. 若是top等命令，containerd通过runC二级制组件直接和容器交换；

6. 在整个容器生命周期中，containerd通过epoll 监控容器文件，监控容器的OOM等事件；



## 14.1 docker

docker命令，是一个客户端(CLI)工具，用来执行容器的各种操作。它将用户输入的命令和参数转换为后端服务的调用参数，通过调用后端服务来实现各类容器操作。



## 14.2 dockerd

运行于服务器上的后台守护进程（daemon），负责实现容器镜像的拉取和管理以及容器创建、运行等各类操作。dockerd向外提供RESTful API，其他程序（如docker客户端）可以通过API来调用dockerd的各种功能，实现对容器的操作。但时至今日，在dockerd中实现的容器管理功能也已经不多，主要是镜像下载和管理相关的功能，其他的容器操作能力已经分离到containerd组件中，通过grpc接口来调用。又被称为docker engine、docker daemon。



## 14.3 containerd

另一个后台守护进程，是真正实现容器创建、运行、销毁等各类操作的组件，它也包含了独立于dockerd的镜像下载、上传和管理功能。containerd向外暴露grpc形式的接口来提供容器操作能力。dockerd在启动时会自动启动containerd作为其容器管理工具，当然containerd也可以独立运行。containerd是从docker中分离出来的容器管理相关的核心能力组件。但是为了支持容器功能实现的灵活性和开放性，更底层的容器操作实现（例如cgroup的创建和管理、namespace的创建和使用等）并不是由containerd提供的，而是通过调用另一个组件runc来实现。



## 14.4 runc

实现了容器的底层功能，例如创建、运行等。runc通过调用内核接口为容器创建和管理cgroup、namespace等Linux内核功能，来实现容器的核心特性。runc是一个可以直接运行的二进制程序，对外提供的接口就是程序运行时提供的子命令和命令参数。runc内通过调用内置的libcontainer库功能来操作cgroup、namespace等内核特性。



## 14.5 containerd-shim

containerd-shim位于containerd和runc之间，当containerd需要创建运行容器时，它没有直接运行runc，而是运行了shim，再由shim间接的运行runc。shim主要有3个用途：

1. 让runc进程可以退出，不需要一直运行。这里有个疑问，为了让runc可以退出所以再启动一个shim，听起来似乎没什么意义。我理解这样设计的原因还是想让runc的功能集中在容器核心功能本身，同时也便于runc的后续升级。shim作为一个简单的中间进程，不太需要升级，其他组件升级时它可以保持运行，从而不影响已运行的容器。
2. 作为容器中进程的父进程，为容器进程维护stdin等管道fd。如果containerd直接作为容器进程的父进程，那么一旦containerd需要升级重启，就会导致管道和tty master fd被关闭，容器进程也会执行异常而退出。
3. 运行容器的退出状态被上报到docker等上层组件，又避免上层组件进程作为容器进程的直接父进程来执行wait4等待。这一条没太理解，可能与shim实现相关，或许是shim有什么别的方式可以上报容器的退出状态从而不需要直接等待它？需要阅读shim的实现代码来确认。



## 14.5 其他技术名词

**LXC**：LinuX Containers ，它是一个加强版的Chroot。LXC就是将不同的应用隔离开来，这其有点类似于chroot，chroot是将应用隔离到一个虚拟的私有root下，而LXC在这之上更进了一步。LXC内部依赖Linux内核的3种隔离机制（isolation infrastructure）：**Chroot、Cgroups、Namespaces**。 LXC是最早的linux容器技术，早期版本的docker直接使用lxc来实现容器的底层功能。虽然使用者相对较少，但lxc项目仍在持续开发演进中。

**libcontainer**：docker从0.9版本开始自行开发了libcontainer模块来作为lxc的替代品实现容器底层特性，并在1.10版本彻底去除了lxc。在1.11版本拆分出runc后，libcontainer也随之成为了runc的核心功能模块。



# 15. 端口开放

## 15.1 iptables

```bash
docker inspect nexus3 | grep 
"IPAddress": "172.17.0.2",

iptables -t nat -vnL
Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0
    0     0 RETURN     all  --  br-ba60ba30e207 *       0.0.0.0/0            0.0.0.0/0
    0     0 RETURN     all  --  br-d23f80b29ce9 *       0.0.0.0/0            0.0.0.0/0
    0     0 RETURN     all  --  br-cd186e54925b *       0.0.0.0/0            0.0.0.0/0
    0     0 DNAT       tcp  --  !br-d23f80b29ce9 *       0.0.0.0/0            127.0.0.1            tcp dpt:1514 to:172.21.0.3:10514
    0     0 DNAT       tcp  --  !br-d23f80b29ce9 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.21.0.6:8080
  851 44508 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8081 to:172.17.0.2:8081

# 新增
iptables -t nat -A  DOCKER -p tcp --dport 8082 -j DNAT --to-destination 172.17.0.2:8082
iptables -t nat -A  DOCKER -p tcp ! -i docker0 --dport 8082 -j DNAT --to-destination 172.17.0.2:8082

# 删除
iptables -t nat -vnL DOCKER --line-number
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0
2        0     0 RETURN     all  --  br-ba60ba30e207 *       0.0.0.0/0            0.0.0.0/0
3        0     0 RETURN     all  --  br-d23f80b29ce9 *       0.0.0.0/0            0.0.0.0/0
4        0     0 RETURN     all  --  br-cd186e54925b *       0.0.0.0/0            0.0.0.0/0
5        0     0 DNAT       tcp  --  !br-d23f80b29ce9 *       0.0.0.0/0            127.0.0.1            tcp dpt:1514 to:172.21.0.3:10514
6        0     0 DNAT       tcp  --  !br-d23f80b29ce9 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.21.0.6:8080
7     1199 62604 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8081 to:172.17.0.2:8081
8       42  2520 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8082 to:172.17.0.2:8082

iptables -t nat -D DOCKER 8
```



## 15.2 修改配置文件

停止容器，修改 `/var/lib/docker/containers/{CONTAINER_ID}` 下的 `hostconfig.json`和`config.v2.json` 后重启 

注意：需要停止容器和dockerd服务，否则无法生效。不推荐

```bash
vi hostconfig.json
"PortBindings":{"8081/tcp":[{"HostIp":"","HostPort":"8081"}],"8082/tcp":[{"HostIp":"","HostPort":"8082"}]},

vi config.v2.json
"ExposedPorts":{"8081/tcp":{},"8082/tcp":{}},
```



## 15.3 生成新镜像

```
docker commit fda688b2565a nexus3:test
docker run -rm -p 8081:8081 -p 8082:8082 nexus3:test /bin/sh
```



# 16. 容器自动启动

```bash
# 创建容器时
--restart=always

# 容器运行时更新
docker update --restart=always 07fb7442f813
```

`--restart` 参数值：

- no: 不自动重启，默认值
- on-failure: 容器错误退出，即退出码不为0时，重启容器
- always：容器停止，自动重启。如果手动停止，需要重启dockerd进程或者重启容器本身才生效。主要用于宿主机重启后，自动启动容器
- unless-stopped：同always，但当手动停止，即使重启dockerd进程，也无法自动启动容器
