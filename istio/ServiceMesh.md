# 1. 概念

## 1.1 简介

**Service Mesh 是微服务时代的 TCP/IP 协议。**

微服务（Microservices）是一种软件架构风格，它以专注于单一责任与功能的小型功能区块（Small Building Blocks）为基础，利用模块化的方式组合复杂的大型应用程序，各功能区块使用与语言无关（Language-Independent/Language agnostic）的API集相互通信

微服务平台和框架：Spring Cloud，Service Fabric, Linkerd, Envoy, Istio



## 1.2 发展历史

**时代0**：早期想象中的两台或多台计算机的交互模式

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-1.png)

加上网络栈：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-2.png)

**时代1**：原始通信时代

通信需要底层能够传递字节码和电子信号的物理层来完成，在TCP协议出现之前，服务需要自己处理网络通信中的丢包、乱序、重试等一序列流控问题。因此在服务实现中，除了业务逻辑，还需要处理网络传输问题

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-3.png)

**时代2**：TCP时代

TCP 协议解决了网络传输中的流量控制问题，服务实现不在需要处理网络传输问题，它被集成到了操作系统的网络层中

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-4.png)

**时代3**：第一代微服务

以GFS、BigTable、MapReduce等为代表的分布式系统蓬勃发展后，出现了熔断策略、负载均衡、服务发现、认证和授权、quota限制，trace和监控通信语义等，此时服务需要根据业务需求来实现一部分通信语义

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-5.png)

**时代4**：第二代微服务

随着一些微服务开发框架（SpringCloud）的出现，它们实现了分布式系统通信需要的各种语义功能，如负载均衡和服务发现等，在一定程度上屏蔽了这些通信细节，使得开发人员使用较少的框架代码就能开发出健壮的分布式系统

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-5-a.png)



**时代5**：第一代ServiceMesh

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-6.png)

第二代微服务模式的问题：

- 虽然框架屏蔽了分布式通信的一些通用功能的实现细节，但开发者需要花更多精力去掌握和管理复杂的框架本身，在实际应用中，去追踪和解决框架出现的问题绝非易事
- 开发框架通常只支持一种或几种特定语言，无法做到在微服务架构中使用多种不同的语言
- 框架以lib库的形式或服务联编，复杂项目依赖的库版本兼容性问题非常棘手，同时框架库的升级也无法对服务透明，服务会因为和业务无关的lib库升级到导致被迫升级

因此以Linkerd、Envoy及NginxMesh为代表的代理模式（边车模式）应运而生，即第一代Service Mesh。它将分布式服务的通信抽象为单独一层，在这一层中实现负载均衡、服务发现、认证授权、监控追踪，流量控制等分布式系统所需要的功能，作为一个和服务对等的代理模式，和服务部署在一起，接管服务的流量，通过代理之间的通信间接完成服务之间的通信请求

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-6-a.png)

从一个全局视角来看，部署图如下:

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-mesh1.png)

略去服务，Service Mesh的单机组件组成的网络：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-mesh2.png)



**时代6**：第二代Service Mesh

第一代Service Mesh由一系列独立运行的单机代理服务构成，为了提供统一的上传运维入口，演化出了集中式的控制面板，所有的单机代理组件通过和控制面板交互进行网络拓扑策略的更新和单机数据的汇报。以 Istio 为代表的第二代 Service Mesh

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-6-b.png)

**SideCar**: 与服务部署在一起的轻量级网络代理即为SideCar，它的作用是实现服务框架的各项功能（服务发现、负载均衡、限流熔断等）。而服务只做自己的业务逻辑处理。



只看单机代理组件(数据面板)和控制面板的Service Mesh全局部署视图:

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/servicemesh-mesh3.png)

**Control Plane**：用来从全局角度上控制 SideCar 的，比如它负责所有 SideCar 的注册，存储一个统一的路由表，帮助各个 SideCar 进行服务均衡和请求调度。另外它还收集所有 SideCar 的监控信息和日志数据。它相当于 Service Mesh 架构的大脑，控制着 SideCar 来实现服务治理的各项功能



# 2. Service Mesh

服务网格是一个**基础设施层**，用于处理服务间通信。云原生应用有着复杂的服务拓扑，服务网络保证**请求在这些拓扑中可靠地穿梭**。在实际应用中，服务网格通常是由一系列轻量级的**网络代理**组成的，它们与应用程序部署在一起，但对**应用程序透明**。

**基础设施层+请求在这些拓扑中可靠穿梭**：微服务时代的 TCP 协议

**网络代理**：Service Mesh的实现形式

**对应用透明**：解决以Spring Cloud为代表的第二代微服务架构所面临的三个本质问题



Service Mesh的优点：

- 屏蔽分布式系统通信的复杂性（负载均衡、服务发现、认证授权、监控追踪、流量控制等），服务只关注业务逻辑
- 真正的语言无关，服务可以使用任何语言编写，只需和Service Mesh通信即可
- 对应用透明，Service Mesh组件可单独升级



Service Mesh的缺点：

- 以代理模式计算转发请求，一定程度上会降低通信系统性能，并增加系统资源开销
- 接管了网络流量，服务的整体稳定性依赖于Service Mesh，同时额外引入大量Service Mesh服务实例的运维和管理也是一大挑战



为了解决端到端的字节码通信问题，TCP协议诞生，让多机通信变得简单可靠；微服务时代，Service Mesh应运而生，屏蔽了分布式系统的诸多复杂性，让开发者可以回归业务，聚焦真正的价值。



Service Mesh的核心价值：

- **微服务基础设施下沉**：微服务架构支撑、网络通信、治理等相关能力下沉到基础设施层，业务部门无需投入专人开发与维护，可以有效降低微服务架构下研发与维护成本
- **降低升级成本**：SideCar支持热更新，降低中间件和计算框架客户端、SDK升级成本
- **语言无关**：提供多语言服务治理能力
- **降低复杂测试、演练成本**：降低全链路压测、故障演练成本和业务侵入性



Google、IBM主推的 Istio 框架，器对Service Mesh的核心功能：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/istio-core-function.png)

- **连接**：智能控制服务之间的流量和API调用，进行一序列测试，并通过红、黑部署逐步升级
- **保护**：通过托管身份验证、授权和服务之间通信加密自动保护服务
- **控制**：应用策略并确保其执行使得资源在消费者之间公平分配
- **观测**：通过丰富的自动追踪、监控和记录所有服务，了解正在发生的情况



# 3. Envoy & Istio

## 3.1 核心方案

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-istio-arch.jpg)

- Istio 由 Google、IBM和Lyft联合开发，Go语言实现。它与Kubernetes一脉相承，提供了完整的Service Mesh方案。核心组件包含**数据面 Envoy**(云原生数据面事实标准组件、具备高性能和丰富的数据面功能)、**控制面 Pilot、Mixer、Citadel、Galley**等

- **数据面以 Envoy Proxy** 作为代理组件。通过 Outbound 流量拦截或显示指向 Envoy Proxy 地址的方式代理发起请求流量，经过Envoy Proxy的服务发现、负载均衡、路由等数据面逻辑后，选择目标服务实例地址进行流量转发；在 Inbound 流量接收端进行流量拦截（可配置是否拦截），对Inbound流量进行处理后转发至目标服务实例
- **控制面以 Polit** 为核心组件。通过建立与 Envoy Proxy双向GRPC连接，实现服务注册信息、服务治理策略的实时下发和同步。其他控制面组件 Mixer（策略检查、监控、日志审计等）、Citadel（认证与授权）、Galley（配置检查）可在实际场景中配置关闭
- 平台开发和扩展主要通过 Kubernetes CRD 与 Mesh Configuration Protocol （MCP，标准GRPC协议）。平台默认支持Kuberenets基于Etcd的注册中心机制，可通过MCP机制对接更多诸如Consul、Eueka、ZooKeeper等多注册中；对服务治理策略的配置可用过定义Kuberenetes CRD或实现MCP GRPC服务对接实现
- 高可用设计主要基于Kubernetes及Istio机制实现。数据面 Envoy Proxy以Init-Container方式与业务Container同时启动，Istio提供了 Pilot-agent组件实现对 Envoy Proxy生命周期、升级的支持，保证 Envoy proxy 的高可用。控制面所有Istio组件均由Kubernetes多个服务探针机制保证高可用性

## 3.2 注册中心

Kubernetes 基于 Etcd 的注册中心机制是默认方案。对于其他注册中心，可通过 Istio 的MCP机制接入（Consul、Eureka、ZooKeeper）

传统服务框架下，微服务的注册通常用过服务架构SDK将微服务注册到注册中，通过SDK中的发现方法从注册中心发现服务和实例列表，即**通过客户端SDK完成注册发现**

ServiceMesh 架构，控制面组件（如Istio Pilot）负责对接注册中心。服务在创建 Kubernetes Service、Depployment时会完成自动注册；服务的发现则由控制面组件拉取或监听注册中心，将获取到的服务与实现信息转换为统一服务模型，再通过GRPC推送到SideCar，这样SideCar就获取到了服务与实例信息，即**通过控制面组件完成服务发现**。通过控制面组件完成服务发现的模式，控制面组件可以通过实现不同注册中的适配器，同时获取多种注册中心的服务和实例信息，即可实现多注册中心服务的相互发现：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-istio-multi-registry.jpg)



## 3.3 灰度引流

在业务完成容器化+Service Mesh改造和迁移后，已经可以在容器化服务范围内相互发现、调用、治理策略分发与生效。

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-istio-loadbalancer.jpg)

在两个环境之间引入了**边缘网关**进行跨环境方案代理、服务发现、访问控制。

- 服务间调用灰度引流
  即原有云外服务的互相调用，通过服务框架的权重或参数分流功能，引部分服务间调用流量至云内，实现服务间调用灰度引流的测试验证。
- 用户调用灰度引流
  即在终端USER访问负载均衡组件处进行灰度引流，如整体方案图中USER访问负载均衡部分。这种方式下同样可以按权重或参数控制用户流量，实现终端用户调用灰度引流的测试验证。





# 4. Envoy

## 4.1 简介

Envoy 是一个高性能的 Service Mesh 软件，其目标：对于应用程序而言，网络应该是透明的，当发生网络和应用程序故障时，能够很容易定位出问题的根源

Envoy 核心功能：

- 非侵入性架构：Envoy 和应用服务并行运行的，透明地代理应用服务发出、接收的流量。应用服务只需要和 Envoy 通信，无需直到其他微服务应用在哪里

- 基于 C++ 11实现，性能优异
- L3/L4 过滤器架构：Envoy的核心是一个 L3/L4 代理，然后通过插件式的过滤器（network filters，类似 netfilter, servlet filter）的链条来执行 TCP/UDP 的相关任务，例如TCP转发，TLS认证等工作
- HTTP L7 过滤器架构：Envoy 内置了一个非常核心的过滤器 `http_connection_manager`，它支持复杂而丰富的配置，以及本身也是过滤器架构，可以通过一系列 http 过滤器来实现 http 协议层面的任务，如：http路由，重定向，CORS支持等

- HTTP/2 协议升级：支持双向、透明的 HTTP/1 to HTTP/2 代理能力

- gRPC 支持：因为对 HTTP/2 的良好支持，Envoy 可以方便的支持 gRPC，特别是在负载和代理上
- 其他能力
  - 服务发现：符合最终一致性，支持包括 DNS、EDS 在内的多种服务发现方案
  - 健康检查：内置健康检查子系统
  - 负载均衡：支持区域感知。除一般的负载均衡，还支持基于 rate limit 服务的多种告警负载均衡方案，包括：`automatic retries`，`circuit breaking`，`global rate limiting`
  - Tracing：方便集成 Open Tracing 系统，追踪请求
  - 统计和监控：内置 stats 模块，方便集成诸如 prometheus/statsd 等监控方案
  - 动态配置：通过API实现配置的动态调整，无需重启 Envoy 服务



## 4.2 基础知识

### 4.2.1 配置

**资源**：接口配置，静态API

```yaml
static_resources:
```



**监听器**: 

```yaml
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }
```



**过滤器**：

```yaml
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }
      
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          access_log:
          - name: envoy.access_loggers.stdout
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
          http_filters:
          - name: envoy.filters.http.router
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  host_rewrite_literal: www.baidu.com
                  cluster: service_baidu
```

内置过滤器：`envoy.http_connection_manager`

- `stat_prefix`：统计前缀
- `route_config`：路由配置，如果虚拟主机匹配上则检查路由。当前配置中，无论请求的主机域名是什么，`route_config` 都匹配所有传入的 HTTP 请求
- `routes`：如果 URL 前缀匹配，则一组路由规则定义了下一步将发生的状况。"/" 表示匹配根路由
- `host_rewrite`：更改 HTTP 请求的入站 host 头信息
- `cluster`：将要处理请求的集群名称，下面会有相应的实现
- `http_filters`：该过滤器允许 Envoy 在处理请求时去适应和修改请求



**集群**：

当请求匹配过滤器时，该请求将会传递到集群。如下将主机定义为访问 HTTPS 的 baidu.com 域名，如果定义了多个主机，则 Envoy 将执行轮询 (Round Robin) 策略

```yaml
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 10000

    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          access_log:
          - name: envoy.access_loggers.stdout
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
          http_filters:
          - name: envoy.filters.http.router
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  host_rewrite_literal: www.baidu.com
                  cluster: service_baidu

  clusters:
  - name: service_baidu
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: service_baidu
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: www.baidu.com
                port_value: 443
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.baidu.com
```



**管理**：

```yaml
admin:
  access_log_path: /tmp/admin_access.log
  address:
    socket_address: { address: 0.0.0.0, port_value: 9901 }
```



### 4.2.2 开启代理

使用 docker 运行 envoy：

```bash
docker run --name=envoy -d \
  -p 80:10000 -p 9901:9901\
  -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml \
  envoyproxy/envoy:v1.20.3
```



## 4.3 整体架构

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-arch.png)

- 进程无关架构：Envoy 时一个自组织的模块，与应用服务无直接依赖，所有的 Envoy 构建了一个透明的服务网格，处于其中的应用只需要简单地与本地的 envoy 进行收发信息，并不需要关注整个网络拓扑。
  - 可以让任何语言编写的服务通信，协同规则，屏蔽了服务之间的沟壑
  - 以一种透明的方式快速的发布更新这个服务架构中的版本
- 高级负载均衡：分布式系统中不同模块间的负载均衡是一个复杂的问题。因为Envoy是一个自组织的代理，所以它能在一个地方实现高级负载均衡技术并使它们可被访问。当前Envoy支持自动重试、断路器、全局限速、阻隔请求、异常检测等功能

- 动态配置：Envoy 提供了一序列可选的分层动态配置 API，使用这些API可构建出复杂的集中式部署管理
- 正向代理：Envoy 包含了足够多的特性为大多数 web 服务做正向代理。另外还支持 HTTP/2，L3/L4/L7代理，可实现 TCP Proxy， HTTP Proxy等功能
- 多线程：Envoy 使用单进程多线程架构，其中主线程负责协调任务，而工作线程负责监听、过滤和转发。一旦某个链接被监听器 listener 接受，那么这个链接将会剩余的生命周期绑定在这个 Worker 线程，它是非阻塞的
- Listener 监听器
  - 一个 Envoy 进程可是在多个不同的 Listener
  - 每个 Listener 在 L3/L4 的过滤器是独立配置的，并且一个 Listener 可以通过配置来完成多种任务。比如：访问限制，TLS客户端检验、HTTP链接管理等
  - Listener 有自己的非网络层过滤器，它可以修改链接的 Metadata 信息，通常用来影响接下里链接是如何被网络层过滤器处理的
  - 无论网络层过滤器还是 Listener 过滤器都可以提前终止后续的过滤器链的执行
- HTTP 连接管理器
  - Envoy 支持 HTTP/1.1、HTTP/2、Websocket，但不支持 SPDY
  - 该层过滤器主要是将原始传递数据转变成 HTTP 层级的信息和事件。如收到 Headers， Body数据，同样它也可以做接入日志，Request ID 生成和追踪、Req/Resp Header修改、路由表管理、统计分析等
  - 每个 HTTP 链接管理器有一个相匹配的路由表，路由表可静态指定，也可动态地通过 RDS API 来设置 `route-dynamic`
  - 内部的 HTTP 过滤器，可支持在 HTTP 层，无需关注协议的情况下，操作HTTP等内容，支持Encode、Decode、Encode/Decode 三种过滤器
- HTTP 路由器
  - 在做边缘、反向代理和构建内部 Envoy Mesh 发挥巨大作用
  - 支持请求重试配置：最大重试次数、重试条件等，比如某些 5XX错误和具有冥等性操作的 4XX 错误
  - HTTP/2 链路管理器实现了 gRPC 协议，内置了重试、超时、服务发现、负载均衡、健康检查等功能
- Cluster 管理器
  - 暴露API给过滤器，并允许过滤器可以得到链接到上游集群的 L3/L4 链接或维持一个抽象的 HTTP 连接池 来链接上游集群。过滤器决定使用 L3/L4 链接还是 HTTP Stream 来链接上游集群。对集群管理器来说，它负责所有集群内主机的可用性、负载均衡、健康度、线程安全的上游链接数据，上游链接类型 TCP/UDP，上游可接受的协议 HTTP 1.1/2
  - 支持静态配置和动态配置（`CDS, Cluster-Discovery-Service API`）。集群在正式使用前有一个 ”加热“（Warming）过程：先做服务发现必要的初始化，比如DNS记录更新、EDS更新，然后做健康检查，成功后进入 `Becoming available` 状态，该阶段 Envoy 不会把流量指向它；在更新集群时，也不会把正在处理的流量的集群处理掉，而是用新的去替换老的那些还未进行任何流量的集群

**Envoy vs Nginx**:

- Envoy 对 HTTP/2 的支持比 Nginx 更好，支持 upstream、downstream 在内的双向通信；而 Nginx 只支持 downstream 连接
- Envoy 高级负载均衡功能免费；Nginx的高级负载功能需要付费 `Nginx Plus`支持
- Envoy 支持热更新，Nginx 配置更新后需要 reload
- Envoy 更贴近 Service Mesh 的使用习惯；Nginx 更贴近传统服务的使用习惯



## 4.4 Envoy 术语

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-mesh.png)

Downstream：下游主机连接到 Envoy，发送请求并接收响应

Upstream：Envoy 连接到上游主机，接收请求并返回响应

Listener：可被下游客户端连接的命名网络(端口、unix-socket)，每个 envoy 进程可启动任意数量的 Listener，每个监听器都独立配置一定数量的 L3/L4 网络过滤器

Cluster：Envoy 连接到的一组逻辑上相似的上游主机

Listener Filter：用来操作metadata，在不改变 Envoy 核心功能的情况下添加更多的集成功能

Http Route Table：HTTP 路由规则，如请求域名、Path符合什么规则，转发给哪个Cluster



## 4.5 配置文件

### 4.5.1 静态配置

```yaml
admin:
  access_log_path: /tmp/admin_access.log
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address: { address: 0.0.0.0, port_value: 10000 }
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          codec_type: AUTO
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match: { prefix: "/" }
                route: { cluster: some_service }
          http_filters:
          - name: envoy.filters.http.router
  clusters:
  - name: some_service
    connect_timeout: 0.25s
    type: STATIC
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: some_service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 80
```

**模拟SideCar**:

```bash
docker run -d -p 10000:10000 -v $(pwd)/envoy_nginx.yaml:/etc/envoy/envoy.yaml --name envoy envoyproxy/envoy:v1.20.3

docker run -d --name nginx --network=container:envoy nginx
```



### 4.5.3 动态配置

动态配置可实现全动态，即

- LDS：Listener Discovery Service
- CDS：Cluster Discovery Service
- RDS：Route Discovery Service
- EDS：Endpoint Discovery Service
- ADS：Aggregated Discovery Service。它不是一个实际的 XDS，它提供了汇聚功能，来实现需要多个同步 XDS 访问的时候可以在一个 Stream 中完成的作用

静态配置的发现服务：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-static-config.png)

动态配置：

```yaml
admin:
  access_log_path: /tmp/admin_access.log
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }

dynamic_resources:
  cds_config:
    ads: {}
  lds_config:
    ads: {}
  ads_config:
    api_type: GRPC
    cluster_names: [xds_cluster]

static_resources:
  clusters:
  - name: xds_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    hosts: [{ socket_address: { address: envoy-server, port_value: 50051 }}]
```



# 5. Pilot 组件

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/istio-pilot-arch.png)

Pilot 组件时 Istio 服务网格的”领航员“，负责管理数据平面的流量规则和服务发现。典型应用场景时灰度发布（金丝雀发布、蓝绿部署）：开发者通过 Pilot 提供的规则 API，下发路由规则到数据平面的 Envoy 代理，从而实现精准的多版本流量分配



# 6. Mixer 组件

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/istio-mixer.png)

Mixer组件是 Istio 服务网格中的”调音师“，负责落实各种流量策略（如访问控制、限速），也负责对流量进行观测分析（如日志、监控、追踪）。它是Envoy Filter Chain扩展机制实现：Mixer 会分别在”请求路由前（Pre-routing）“扩展点和”请求路由后（Post-routing）“扩展点挂载自己的 Filter 实现



# 7. Auth 组件

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/istio-auth.png)

Auth组件是Istio服务网格中的“安全员”，负责处理服务节点之间通信的认证（Authentification）和鉴权（Authorization）问题。对于认证，Auth支持服务之间的双向SSL认证，可以让通讯的双方都彼此认可对方的身份；对于鉴权，Auth支持流行的RBAC鉴权模型，可以实现便捷和细粒度的“用户-角色-权限”多级访问控制。





