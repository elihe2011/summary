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

docker最主要的三项特性：

- 镜像化  unionfs
- 空间隔离   namespace
- 资源隔离   cgroup



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/docker-components.png) 



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

docker 程序是一个客户端工具，用来把用户的请求发送给 docker daemon(dockerd)



## 14.2 dockerd

docker daemon(dockerd)，即 docker engine。运行于服务器上的后台守护进程，负责实现容器镜像的拉取和管理以及容器创建、运行等各类操作。dockerd向外提供RESTful API，其他程序（如docker客户端）可以通过API来调用dockerd的各种功能，实现对容器的操作。



## 14.3 containerd

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/docker-component-architecture.png)

**Containerd 是一个工业级标准的容器运行时，它强调简单性、健壮性和可移植性**。主要负责：

- 管理容器的生命周期(从创建到销毁)
- 拉取/推送容器镜像
- 存储管理(管理镜像及容器数据的存储)
- 调用 runC 等容器运行时
- 管理容器网络



### 14.3.1 为什么 containerd 要独立

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/containerd-standardization.png)

**Containerd 被设计成嵌入到一个更大的系统中，而不是直接由开发人员或终端用户使用**。表现如下：

- 彻底从docker引擎中分离
- 可被 Kubernetes CRI 等项目直接调用

- 当 containerd 和 runC 成为标准化容器服务的基石后，上层应用可以直接建立在 containerd 和 runC 之上。

### 14.3.2 containerd 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/containerd-architecture.png)

containerd 被设计成 snapshotter 的模式，这也使得它对于 overlay 文件系、snapshot 文件系统的支持比较好。
storage、metadata 和 runtime 的三大块划分非常清晰，通过抽象出 events 的设计，网络层面的复杂度交给了上层处理，仅提供 network namespace 相关的一些接口添加和配置 API。这样保留最小功能集合的纯粹和高效，将更多的复杂性及灵活性交给了插件及上层系统。



## 14.4 containerd-shim

containerd 的组件，是容器的运行时载体，在 docker 宿主机上看到的 shim 也正是代表着一个个通过调用 containerd 启动的 docker 容器

containerd-shim 的作用：

- 允许 runC 在启动容器之后退出，即不必为每个容器一直运行一个容器运行时
- 即使 containerd 和 dockerd 都挂掉，容器的标准 IO 和其它的文件描述符也都是可用的
- 向 containerd 报告容器的退出状态



## 14.5 runC

RunC 是一个轻量级的工具，它是用来运行容器的，只用来做这一件事，并且这一件事要做好。runC 是标准化的产物，它根据 OCI 标准来创建和运行容器。

RunC 默认要支持 seccomp ( secure computing mode，即安全计算模型)，编译时，先安装 libseccomp-dev

容器的状态转移：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/oci-container-status.png)



## 14.6 K8S 引入的新组件

k8s 调用 docker：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-invoke-docker-legacy.png)

**kubelet**：k8s 工作节点上的服务进程，负责管理该节点上的容器。k8s系统对容器的创建、删除等调度行为都需要通过节点上的kubelet来完成。

**dockershim**：kubelet和dockerd交互的中间接口。dockershim 提供了一个标准接口，让kubelet能够专注于容器调度逻辑本身，而不用去适配 dockerd 接口变动。而其他实现了相同标准接口的容器技术也可以被kubelet集成使用，这个接口称作CRI。dockershim 是对 CRI 接口调用 dockerd 的一种实现。**dockershim并不是docker技术的一部分，而是k8s系统的一部分**。



k8s 1.20+ 默认不再使用dockershim，并将在后续版本中删除dockershim，这意味着kubelet不再通过dockerd操作容器。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-invoke-docker-new.png)

在新的架构中，kubelet直接与containerd交互，跳过了dockershim和dockerd这两个步骤。containerd通过其内置的CRI插件提供了CRI兼容接口。

**cri-containerd**：在k8s和containerd的适配过程中，还曾经出现过cri-containerd这个组件。在containerd1.0版本中，containerd提供了cri-containerd作为独立进程来实现CRI接口，其定位和dockershim类似。但在containerd1.1版本中，就将这个功能改写成了插件形式直接集成到了containerd进程内部，使containerd可以直接支持CRI接口，cri-containerd也被合入了containerd，作为其一个内置插件包存在。



## 14.6 其他技术名词

**LXC**：LinuX Containers ，它是一个加强版的Chroot。其作用是将不同的应用隔离开来，有点类似于chroot，chroot是将应用隔离到一个虚拟的私有root下，而LXC在这之上更进了一步。LXC依赖 Kernel 的3种隔离机制(isolation infrastructure)：**Chroot、Cgroups、Namespaces**。

**libcontainer**：docker0.9 开发了 libcontainer 模块来作为 LXC 的替代品实现容器底层特性，并在1.10版本彻底去除了LXC。在1.11版本拆分出runc后，libcontainer 也随之成为了runc的核心功能模块。

**moby**：docker公司发起的开源项目，其中最主要的部分就是同名组件moby，事实上这个moby就是dockerd目前使用的开源项目名称，docker项目中的engine（dockerd）仓库现在就是从moby仓库fork而来的。

**docker-ce**：docker的开源版本，CE指Community Edition。docker-ce中的组件来自于moby、containerd等其他项目。

**docker-ee**：docker的收费版本，EE指Enterprise Edition。

**CRI**：Container Runtime Interface，容器运行时接口。它是容器操作接口标准，符合CRI标准的容器模块才能集成到k8s体系中与kubelet交互。符合CRI的容器技术模块包括dockershim（用于兼容dockerd）、rktlet（用于兼容rkt）、containerd(with CRI plugin)、CRI-O等。

**rkt与rktlet**：CoreOS公司主导的容器技术，在早期得到了k8s的支持成为k8s集成的两种容器技术之一。随着CRI接口的提出，k8s团队也为rkt提供了rktlet模块用于与rkt交互，rktlet和dockersim的意义基本相同。随着CoreOS被Redhat收购，rkt已经停止了研发，rktlet已停止维护了。

**CRI-O**：Redhat公司推出的容器技术。从名字就能看出CRI-O的出发点就是一种原生支持CRI接口规范的容器技术。CRI-O同时兼容OCI接口和docker镜像格式。CRI-O的设计目标和特点在于它是一项轻量级的技术，k8s可以通过使用CRI-O来调用不同的底层容器运行时模块，例如runc。

**OCI**：Open Container Initiative，开放容器倡议。容器相关标准的制定组织。OCI标准主要包括两部分：镜像标准和运行时标准。符合OCI运行时标准的容器底层实现模块能够被containerd、CRI-O等容器操作模块集成调用。runc就是从docker中拆分出来捐献给OCI组织的底层实现模块，也是第一个支持OCI标准的模块。除了runc外，还有gVisor（runsc）、kata等其他符合OCI标准的实现。

**gVisor**：google开源的一种容器底层实现技术，对应的模块名称是runsc。其特点是安全性，runsc中实现了对linux系统调用的模拟实现，从而在用户态实现应用程序需要的内核功能，减小了恶意程序通过内核漏洞逃逸或攻击主机的可能性。

**kata**：Hyper和Intel合作开源的一种容器底层实现技术。kata通过轻量级虚拟机的方式运行容器，容器内的进程都运行在一个kvm虚拟机中。通过这种方式，kata实现了容器和物理主机间的安全隔离。



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
