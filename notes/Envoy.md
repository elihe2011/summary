# 1. 入门

## 1.1 什么是 Envoy

Envoy 是一个 L7 代理和通信总线，专门为大型 面向服务架构 (SOA) 而设计的，其诞生源于以下理念：

**对应用程序而言，网络应该是透明的。当网络和应用程序出现故障时，应该能够很容易确定问题的根源**



**核心功能**：

- **Out of process architecture** (非侵入式架构)：envoy 是一个独立进程，被设计为伴随每个应用程序服务运行。所有的 envoy 形成一个透明的通信网格，每个应用程序发送消息到本地主机或从本地主机接收消息，不需要知道网络拓扑，对服务的实现程序完全无感知，这种模式被称之为 Sidecar。它具有两个实质性的好处：
  - 适用于任何程序语言，单个 envoy 部署可以在 java, c++, go, python 等形成网格
  - 可以透明地跨整个基础设施快速部署和升级
- **L3/L4 filter architecture** ：envoy 的核心是一个L3/L4 网络代理，允许编写过滤器来执行不同的 TCP/UDP 代理任务。自带的过滤器：TCP/UDP代理、HTTP代理、TLS客户端证书认证、Redis、MongoDB、Postgres等
- **HTTP L7 filter architecture** ：envoy 支持额外的 HTTP L7 过滤器，可插入 HTTP 连接管理器子系统，执行不同的任务，如缓冲、速率限制、路由/转发、嗅探Amazon的DynmoDB等
- **First class HTTP/2 support** ：它将 HTTP/2 视为一等公民，并且可以在  HTTP/2 和 HTTP/1.1 直接相互转换，建议使用 HTTP/2
- **HTTP L7 routing** ：HTTP 模式下，支持一个路由子系统，该子系统能够根据路径、权限、内容类型、运行时只等路由和重定向请求。当使用 envoy 作为前端、边缘时，此功能最有用
- **gRPC support** ：支持 gRPC 请求和响应的路由个负载平衡基础所需的所有 HTTP/2 功能
- **Service discovery and dynamic configuration** ：envoy 可选择一组分层的 动态配置API 进行集中管理，它提供的动态更新：后端集群中的主机、后端集群本身、HTTP路由、监听socket和加密材料。对于更简单的部署，后端主机发现可通过 DNS 解析来完成或跳过，将进一步的层替换为静态配置文件
- **Health checking** ：envoy 包含了一个监控检查子系统，可选择性地对接上游服务集群进行主动健康检查。envoy 然后使用服务发现和健康检查信息的联合来确定健康的负载平衡目标
- **Advanced load balancing** ：envoy 包含对 自动重试、断路、通过外部速率限制服务进行全局速率限制、请求阴影和异常值检测的支持
- **Front/edge proxy support** ：在边缘使用相同的软件（可观察性、管理、相同的服务发现和负载均衡算法等）
- **Best in class observability** ：envoy 的主要目标是使网络透明。然而问题出现在网络层和应用层。statsd 是当前支持的统计接收器



**Envoy xDS API** 版本：

- v1：仅使用 JSON/RESTJSON，本质上是轮询
- v2：支持 proto3，同时以 gRPC、REST + JSON/YAML 端点实现
- v3：当前支持的版本，start_tls、拒绝传入的 tcp 连接、4096位 tls 密钥、SkyWalking和 WASM等



## 1.2 架构

### 1.2.1 envoy data path

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-traffic-flow.png) 



### 1.2.2 架构图

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-architecture-diagram.png)



### 1.2.3 基础组件

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-components.png)



## 1.3 部署类型

Envoy 通常用于以容器编排系统为底层环境的服务网络中，并以 sidecar 的形式与主程序运行为单个Pod

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-deploy-type.png)



### 1.3.1 Service to service only

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-deploy-srv2srv.png)

**egress listener**:

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-sidecar-egress.png)

**ingress listener**:

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-sidecar-ingress.png)



### 1.3.2 Service to service Plus front proxy

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-deploy-srv2srv-front.png)



### 1.3.3 Service to service, front proxy, and double proxy

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/servicemesh/envoy-deploy-srv2srv-front-double.png)



# 2. 配置

## 2.1 配置类型

**静态配置**：用户自行提供Listener、Network Filter Chain、Cluster、HTTP Filter，上游端点的发现仅可通过 DNS 服务进行，且配置的重新加载必须通过内置的热启动 (hot restart) 完成

**动态配置**：

- xDS API
  - 从配置文件加载配置
  - 从管理服务器(Management Server) 基于xds协议加载配置
- runtime
  - 某些关键特性保存为 key/value 数据
  - 支持多层配置和覆盖机制

**EDS**：端点发现功能可有效避免DNS的限制（响应中的最大记录数等）

**EDS + CDS**：集群发现功能能够让 envoy 以优雅的方式添加、更新和删除上游集群，初始配置时，envoy 无需事先了解所有上游集群

**EDS + CDS + RDS**：动态发现路由配置，为用户提供了 构建复杂路由拓扑的能力（流量转移、蓝/绿部署等）

**EDS + CDS + RDS + LDS**：动态发现监听器配置，包括内嵌的过滤器链。除了较罕见的配置变动、证书轮替或更新envoy外，几乎无需 热重启 envoy

**EDS + CDS + RDS + LDS + SDS**：动态发现监听器密钥相关的证书、私钥及TLS会话凭证，以及对证书的逻辑验证配置（受信任的根证书和撤销机制等）



## 2.2 配置项

```json
{
    "node":"{...}",              // 节点标识
    "static_resources":"{...}",  // 静态配置 listener, cluster, secret
    "dynamic_resources":"{...}", // 动态配置，用于基于xDS API获取listener, cluster, secret配置的 lds_config, cds_config和ads_config
    "cluster_manager":"{...}",
    "hds_config":"{...}",  // 使用HDS从管理服务器加载上游主机监控状态检测的配置
    "flags_path":"...",
    "stats_sinks":"[...]",
    "stats_config":"{...}",
    "stats_flush_interval":"{...}",
    "stats_flush_on_admin":"...",
    "watchdog":"{...}",
    "watchdogs":"{...}",
    "tracing":"{...}",             // 分布式追踪
    "layered_runtime":"{...}",     // 层次化运行时，支持使用RTDS从管理服务器动态加载
    "admin":"{...}",               // 内置管理接口
    "overload_manager":"{...}",
    "enable_dispatcher_stats":"...",
    "header_prefix":"...",
    "stats_server_version_override":"{...}",
    "use_tcp_for_dns_lookups":"...",
    "bootstrap_extensions":"[...]",
    "fatal_actions":"[...]",
    "default_socket_interface":"..."
}
```



### 2.2.1 监听器 listener

Envoy 的监听地址可以是端口或 `Unix Socket`。Envoy 在单个进程中支持任意数量的监听器。通常建议每台机器只运行一个 Envoy 实例，每个 Envoy 实例的监听器数量没有限制，这样可以简化操作，统计数据也只有一个来源，比较方便统计。目前 Envoy 支持监听 `TCP` 协议和 `UDP` 协议。

Listener 的功能：

- 接收客户端请求的入口端点，通常由监听的套接字及调用的过滤器链所定义

- 代理类的过滤器负责路由请求，例如tcp_proxy和http_connection_manager等

```json
{
    "name":"...",
    "address":"{...}",
    "filter_chains":"[...]",
    "per_connection_buffer_limit_bytes":"{...}",
    "metadata":"{...}",
    "drain_type":"...",
    "listener_filters":"[...]",
    "listener_filters_timeout":"{...}",
    "continue_on_listener_filters_timeout":"...",
    "transparent":"{...}",
    "freebind":"{...}",
    "socket_options":"[...]",
    "tcp_fast_open_queue_length":"{...}",
    "traffic_direction":"...",
    "udp_listener_config":"{...}",
    "api_listener":"{...}",
    "connection_balance_config":"{...}",
    "reuse_port":"...",
    "access_log":"[...]"
}
```



### 2.2.2 

