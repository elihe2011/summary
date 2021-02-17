# 1. 微服务概述

## 1.1 单体应用

- 所有的功能都在一个应用程序中
- 维护同一个代码库

- 架构简单，典型的三层架构：前端 -> 后端 -> 数据库



## 1.2 微服务

概念：

- 基本原则：每个服务专注做好一件事

- 每个服务单独开发和部署，服务间是完全隔离的

优势：

- 迭代周期短，极大地提升了开发效率
- 独立部署，独立开发
- 可伸缩性好，能够针对指定的服务进行伸缩
- 故障隔离，不会相互影响

劣势：

- 复杂度增加，一个请求往往要经过多个无法，请求链路比较长
- 监控和定位问题困难
- 服务管理比较复杂



# 2. 微服务架构

分布式存储：

- Consul
- Etcd
- Zookeeper

CAP原理：

- C: consistency, 每次总是能够读到最近写入的数据或者失败
- A: available, 每次请求都能够读到数据
- P: partition tolerance, 系统能够继续工作，不管任意个消息由于网络原因失败

## 2.1 注册中心

etcd注册中心：

- 分布式一致性系统
- 基于raft一致性协议



etcd使用场景：

- 服务注册和发现
- 配置中心
- 分布式锁
- Leader选举



## 2.2 Raft协议

应用场景：

- 解决分布式系统一致性问题
- 基于复制的



工作机制：

- leader选举
- 日志复制
- 安全性



基本概念：

- 角色

  - Leader
  - Follower
  - Candidate

- Term (任期)

  - 在raft协议中，将时间分成一个个任期

- 复制状态机：保证数据的一致性

- 心跳(heartbeat)和超时机制(timeout)

  在Raft算法中，有两个timeout机制来控制leader选举：

  - 选举定时器(election timeout): follower等待成为candidate的等待时间，它被随机设定为150ms~300ms
  - 心跳定时器(heartbeat timeout): 某节点成为leader后，它会发送Append Entries消息个其他节点，这些消息就是通过heartbeat timeout来传递，follower接收到leader的心跳包的同时也重置选举定时器



Leader选举：

- 触发条件：

  - 正常情况下，follower收到leader的心跳后，会把定时器清零，不会触发选举
  - follower的选举定时器超时(可能是leader故障)，会变成candidate，触发leader选举

- 选举过程：

  - 一开始，所有节点都是follower，同时启动选举定时器(随机的，降低冲突概率)
  - 定时器到期，变成candidate
  - 当前任期加+1，并投自己一票
  - 发起RequestVote的RPC请求，要求其他节点为自己投票
  - 如果得到超过半数的节点同意，就成为了leader
  - 如果选举超时，未产生leader，则进入下一个任期，重新选举

- 限制条件：
  - 每个节点最多投一次票，采用先到先服务原则
  - 如果没有投过票，则对比candidate的log与当前节点的log那个最新，**谁的lastLog的term越大谁就越新，如果term相同，谁的index越大谁就越新**。<font color="red">如果当前节点比candidate新，拒绝投票。</font>



日志复制：

- Client向Leader提交指令(如：SET 5)，Leader收到命令后，将命令追加到本地日志中，该目录状态处于"uncommitted"，复制状态机不会执行该命令
- Leader将命令(SET 5)并发复制给其他节点，并等待其他节点将命令写入到日志中，如果此时有些节点失败或者慢，Leader节点会一直重试，直到所有节点将该命令写入到了日志中。之后Leader节点就提交命令，并返回给Client节点

- Leader提交命令后，下一次的心跳包中会通知其他follower也来提交这条命令。收到Leader的消息后，就将命令应用到状态机中(State Machine)，最终保证每个节点的数据一致。

![etcd](https://raw.githubusercontent.com/elihe2011/bedgraph/master/etcd/etcd-sync.png)



## 2.3 RPC 调用

数据传输：

- thrift
- protobuf
- json
- msgpack



负载均衡：

- 随机算法
- 轮询
- 一致性hash



异常容错：

- 健康检查
- 熔断
- 限流



## 2.4 服务监控

日志收集：

- 日志收集器 -> kafka集群 -> 数据处理 -> 日志查询和报警

Metrics打点：

- 实时采样服务的运行状态
- 直观的报表展示



# 3. 注册组件开发

## 3.1 Etcd服务注册



## 3.2 服务发现

服务发现方式：

- 使用DNS进行服务发现 （k8s: coredns）

- 基于SDK的形式进行服务发现



传统DNS方案：

- 非高可用
- 不支持动态变更
- 域名解析生效慢





- 服务注册&发现原理
- 服务发现接口定义
- 基于Etcd的服务发现开发



# 4. 负载均衡

分布式系统：

- 每个服务都有多个实例
- 请求如何路由？



传统解决方案：

- DNS+LVS：
  - 集中式解决方案
  - 单点故障
- 软件负载均衡
  - 通过提供负载均衡的lib库，在调用方实现负载均衡
  - 结合服务发现，实现节点动态增删 (扩容和缩容)



负载均衡的好处：

- 服务水平可扩展（解决性能问题）

- 稳定性大大提升（解决单点故障问题）



常见负载均衡解决方案：

- DNS解决方案：
  - 把一个域名解析到多个IP上
  - 用户访问域名后，dns服务器通过一定策略返回一个IP
  - 具体策略：
    - 随机策略
    - 轮询策略
    - 加权策略
  - 缺点：其中一个IP宕机后，有一定概率失败
- 动态DNS解决方案 （k8s, coredns)
  - 可以通过程序动态的修改dns中域名配置的IP
  - 监控程序发现后端IP宕机后，通过dns进行删除
- Nginx反向代理
  - Nginx负载均衡
  - 扩容后，动态增加web server
  - web server宕机，nginx实时摘除
- LVS 负载均衡 
  - Nginx实时扩容
  - Nginx挂了，实时摘除
  - Lvs通过virtual ip实现高可用 （双机，浮点IP）



负载均衡算法：

- 负载均衡算法本质：
  - 从一系列节点中，通过一定的策略，找到一个节点
  - 然后调用方使用该节点进行连接和调用
- 负载均衡算法
  - 随机算法
  - 轮询算法
  - 加权算法：可将加权二维数组转化为一位数组
    - 加权随机算法
    - 加权轮询算法
  - 一致性hash算法



# 5. 微服务框架

## 5.1 Http2

在http1.1基础上，做了大量改进：

- 多路复用
- 二进制分帧 （传输）
- 头部压缩
- 服务端推送



多路复用：并行发送请求

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/http2/http2_multiplexing.png)

二进制分帧：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/http2/http2_binary_framing_layer.svg)

头部压缩：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/http2/http2_header_compression.jpg)

服务端推送：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/http2/http2_server_push.svg)



## 5.2 使用http2

Go中只要使用https，默认支持http2，如何兼容？

通过客户端协商解决，协商算法：ALPN



协议协商：

- Upgrade机制:

  ```
  GET /index.html HTTP/1.1
  Connection: Upgrade, HTTP2-Settings
  Upgrade: h2c
  
  h2c: http
  h2: https  主流浏览器支持
  ```

- ALPN机制： Application Layer Protocol Negotiation

  在https密钥交换过程中，增加ALPN扩展



# 6. 中间件

中间件：连接软件组件或应用的软件，提供一致性的服务，比如Web服务器、事务监控、消息队列等。



## 6.1 Prometheus

- 分布式监控系统
- 使用go开发，完全开源
- 被广泛用于监控这个云基础架构设施

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/k8s/prometheus-ecosystem.jpg)

度量类型：

- 计数器 Counter采样：只能累积或重置
- Gauges采样：用来处理可能随时间减少的值。可用来记录瞬间的值，如内存变化、温度变化、连接池连接数等

- 柱状图 Histogram采样：
  - 对每个采样点进行统计，打到各个桶中(bucket)
  - 对每个采样点值累积和(sum)
  - 对采样点的次数累积和(count)
- Summary采样：在客户端对于一段时间内(默认10m)的每个采样点进行统计，并形成分位图



## 6.2 Grafana

- 跨平台开源的度量分析可视化工具，可通过将采集的数据查询然后可视化展示，并及时通知
- 展示方式：提供丰富的仪表盘插件，如热土、折线图、图表等
- 数据源：Graphite，InfluxDB，Prometheus，ElasticSearch等
- 通知提醒：可设置视化定义的重要指标的报警规则，达到阀值后进行告警操作

- 混合展示：在同一图表中混合使用不同的数据源，可以居于每个查询指定数据源



# 7. 限流

服务限流：

- 常见限流思路：
  - 排队：秒杀抢购
  - 拒绝：除秒杀外的任何场景
- 限流算法：
  - 计数器限流
  - 漏桶限流
  - 令牌桶限流



计数器限流：

- 在单位时间内进行计数，如果大于阀值，则拒绝服务
- 当过了单位时间，则重新进行计数
- 缺点：
  - 突发流量会出现毛刺现象：比如1秒内限流100个请求，前100ms处理完成了100个请求，后900ms空转
  - 计数不准确



漏桶限流：

- 一个固定大小的水桶
- 以固定速率流出
- 水桶满了，则进行溢出(拒绝)

- 优点：
  - 解决了计数器限流算法的毛刺问题
  - 整体流量控制的比较平稳
- 缺点：
  - 流速固定
  - 无法应对某些突发的流量



令牌桶限流：(流入的速率一样)

- 一个固定大小的水桶
- 以固定速率放入token
- 如果能够拿到token则处理，否则拒绝
- 优点：

- Google已实现`import golang.org/x/time/rate`



# 8. 分布式追踪

微服务架构问题:

- 故障定位难
- 容量预估难
- 资源浪费多
- 链路梳理难



分布式追踪系统：

- trace_id：
  - 为每个请求分配唯一的id
  - 日志聚合
- Span：
  - 每个子系统的详细处理过程
  - 通过span进行抽象, span之间有父子关系
- Span Context:
  - 传播问题
    - 进程内传播
    - 进程间传播
  - http协议
    - 通过http头部进行透明传播
  - Tcp协议
    - Thrift: 需要改造thrift进行支持



技术选型：

- 使用 opentracing 提供的通用接口
- 底层 jeagger 做分布式系统



`google.golang.org/grpc/metadata`: grpc服务元数据



# 9. 熔断机制

核心原理：阻止有潜在失败可能的请求。

- 如果一个请求，有比较大的失败可能，那么就应该及时拒绝这个请求

核心思路：对每一个发送请求的成功率进行预测

最佳方案：

- 采用机器学习的方式进行预测
- 机器学习本质上是统计学，统计学玩的就是大数据

实现思路1：

- 针对每一个请求的结果，比如成功或失败进行统计
- 在一定时间窗口内，如果失败率超过一个比率，那么熔断就打开
- 过一段时间后，熔断器再关闭
- 改进：引入半开状态，Half-Open, 在半开状态下，只有非常有限的请求会正常进行，这些请求任何一个失败，则进入Open状态；这些请求全部成功，熔断器关闭(Closed)

Hystrix

- Netflix实现的容错库
- 功能强大
  - 过载保护：防止雪崩
  - 熔断器：快速失败，快速恢复
  - 并发控制：防止单个依赖把线程全部耗尽
  - 超时控制：防止永远阻塞
- 配置
  - Timeout: 超时时间，默认1000ms
  - MaxConcurrentRequests: 并发控制，默认10
  - SleepWindow: 熔断器打开后，冷却时间，默认500ms
  - RequestVolumeThreshold: 一个统计窗口的请求数量，默认20
  - ErrorPercentThreshold: 失败百分率，默认50%
- 触发条件：
  - 一个统计窗口内，请求数量大于RequestVolumeThreshold,且失败率大于ErrorPercentThreshold才会触发熔断
- 







