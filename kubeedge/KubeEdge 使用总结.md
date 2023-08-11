# 1. 基础概念

KubeEdge 是一个开源系统，用于将本机容器化的应用程序编排功能扩展到 Edge 边缘设备上，它基于 kubernetes 构建，并为网络、应用程序提供基本的架构支持，云和边缘之间的部署和元数据同步。

KubeEdge 重点解决的问题：

- 云边协同
- 资源异构
- 大规模
- 轻量化
- 一致的设备管理和接入体验



## 1.1 特点

- 完全开放：EdgeCore 和 CloudCore 都是开源的
- 离线模式：即使与Cloud断开连接，Edge也可以运行
- 基于Kubernetes：节点、集群、应用程序和设备管理；可扩展、容器化、微服务
- 资源优化：可以在资源不足的情况下运行，边缘云上资源的优化利用
- 跨平台：无感知，可在私有、共有和混合云上工作
- 数据和分析：支持数据管理、数据跟新管道引擎
- 异构：可支持 x86, arm
- 简化开发：基于DK的设备加成，应用程序部署等开发
- 易于维护：升级、回滚、监视、警报等



## 1.2 功能

kubeedge 云上部分和k8s功能无差别，主要为k8s 功能。

在kubeedge概念中，edge设备与cloud设备无法双向互通，其假设cloud端开发一个用于公开访问的端点（即cloudcore的websocket端点），edge设备通过该端点与cloud 同步，上报节点信息，接受cloud任务下发。

其中运行在edge边的部分由edgecore实际控制，edgecore还向更下层设备提供http/mqtt接口用于更下层设备接入。其本身亦可为执行工作负载。

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-status-update.png)

**核心能力**：

- 支持复杂的边云网络环境：双向多路复用边云消息通道提供应用层可靠增量同步机制，支持高时延、低质量网络环境。

- 应用/数据边缘自治：支持边缘离线自治及边缘数据处理工作流

- 边云一体资源调度和流量协同：支持边云节点混合管理、应用流量统一调度

- 支持海量边缘设备管理：资源占用业界同类最小；提供可插拔设备管理框架，支持自定义插件扩展

- 开放生态：100%兼容 Kubernetes 原生能力；支持 MQTT、Modbus、Bluetooth、Wifi、ZigBee 等业界主流设备通信协议。



## 1.3 核心理念

- 云边协同
  - 双向多路复用消息通道，支持边缘节点位于私有网络
  - Websocket + 消息封装，大幅减少通信压力，高时延下任可正常工作
- 边缘离线自治
  - 节点元数据持久化，实现节点级离线自治
  - 节点故障恢复无需List-watch，降低网络压力，快速ready
- 极致轻量
  - 重组kubelet功能模块(移除内嵌存储驱动，通过CSI接入)，极致轻量化 (约10mb内存占用)
  - 支持CRI集成 Containerd、CRI-O，优化 runtime 资源消耗



## 1.4 总结

### 1.4.1 解决的问题

- 解决了云边网络不对等问题。精简/重新设计的edgehub，解决了云无法直接访问边缘设备的问题。将原kubelet的通信和功能使用websocket进行实现。由边缘设备发起链接，通过云中的配套服务转换注册进入云集群。
- 边缘设备管理与消息处理。
  - 设备型号注册。将一个型号的设备和其属性以k8s自定义资源注册进入云端，支持定义其属性，属性定义用于确定消息下发的数据结构。
  - 设备实例管理。将实际运行的边缘设备实例以k8s自定义资源注册进入云端，在云端对属性进行更改后，通过边缘设备mqtt将消息推送至边缘设备，边缘设备针对属性更改进行实际处理。
  - 设备实例操作。提供http接口对已经注册的边缘设备属性进行更改，更改会通过kubeedge转换为mqtt消息下发至对应设备。



### 1.4.2 优势

- **边缘自治：**通过增加节点元数据缓存，可以规避云边断网状态下，边缘业务或者节点重启时，边缘组件可以利用本地缓存数据进行业务恢复，这就带来了边缘自治的好处。

- **轻量化:** 削减了部分kubelet功能(如CSI，CNI等)，从而使边缘EdgeCore组件相比原生kubelet组件更加轻量。同时因为节点上增加了SQLite数据库，所以节点维度相比原生节点轻量。
- **Kubernetes 原生支持**：借助 KubeEdge，用户可以在 Edge节点上编排应用，管理设备并监视应用和设备状态，可轻松将现有复杂的机器学习、图像识别和事件处理即其他高级应用部署到 Edge
- **简化开发**：开发人员可以编写基于常规http、mqtt的应用程序，对其进行容器化，然后在 Edge 或 Cloud 中的任何位置运行他们中更合适的一个



### 1.4.3 劣势

- **云原生生态兼容性不足：**

  - 边缘节点无法运行Operator：因为云边通信机制的修改，Cloud Hub只能往边缘推送有限的几种资源(如Pod，ConfigMap等)。而Operator既需要自定义CRD资源，又需要list/watch云端获取关联资源，因此社区的Operator无法运行的KubeEdge的边缘节点上。

  - 边缘节点不适合运行需要list/watch云端的应用: 因为云边通信机制的修改，导致原来需要使用list/watch机制访问kube-apiserver的应用，都无法通过hub tunnel 通道访问kube-apiserver，导致云原生的能力在边缘侧大打折扣。

- **运维监控能力支持有限：**

  目前云边通信链路是`kube-apiserver --> controller --> Cloud Hub -->EdgeHub -->MetaManager`等，而原生Kubernetes运维操作(如kubectl proxy/logs/exec/port-forward/attch等)是kube-apiserver直接请求kubelet。目前KubeEdge社区最新版本也仅支持kubectl logs/exec/metric，其他运维操作目前还不支持。

- **系统稳定性提升待确定:**

  - 基于增量数据的云边推送模式：可以解决边缘watch失败时的重新全量list从而引发的kube-apiserver 压力问题，相比原生Kubernetes架构可以提升系统稳定性。

  - **Infra管控数据和业务管控数据耦合：Kubernetes集群的管控数据(如Pod，ConfigMap数据)和边缘业务数据(设备管控数据)使用同一条websocket链路，如果边缘管理大量设备或者设备更新频率过高，大量的业务数据将可能影响到集群的正常管控，从而可能降低系统的稳定性**。



最大的问题：**控制流和数据流未进行解耦，导致系统无法承接持续性数据，或对数据进行持久化操作**



# 2. 架构

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-arch.png)

## 2.1 云端 （CloudCore）

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/cloudcore.png)

- **CloudHub**: 云端通信模块。websocket服务端，负责监听云端的变化, 缓存和向 EdgeHub 发送消息

- **EdgeController**：管理edge节点。一种扩展的 Kubernetes 控制器，它管理边缘节点和 Pod元数据
- **DeviceController**:  设备管理。一种扩展的 Kubernetes 控制器，用于管理边缘设备，确保设备元数据、状态等可以在云边之间同步。



### 2.1.1 CloudHub

CloudHub 是 Controller 和 Edge 端之间的中介，负责下行分发消息（其内封装了k8s资源事件，如pod update等），也负责接收并发送边缘节点上行消息到 controllers。其下行的消息在应用层增强了传输的可靠性，以应对云边的弱网络环境

与边缘的的通信(EdgeHub)通过 websocket 或 quic 协议完成。在 CloudCore 内部，CloudHub 直接与 Controller 通信。Controller 发送到 CloudHub的所有请求，与用于存储这个边缘节点的事件对象的通道一起存储在 channelq 中

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/cloudhub.png)

主要组件：

- MessageDispatcher：下行消息分发中心，也是下行消息队列的生产者，DispatchMessage函数中实现
- NodeMessageQueue：每个边缘节点有一个专属的消息对了，总体构成一个队列池，以 Node + UID 作为区分，ChannelMessageQueue 结构体实现
- WriteLoop：负责将消息写入底层连接，消息队列的消费者
- Connection Server：接收边缘节点访问，支持 websocket 或 quic 协议
- HTTP Server：为边缘节点提供证书服务，如证书签发与证书轮转

下行数据流：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/cloudcore-downstream.png)

上行数据流：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/cloudcore-upstream.png)



### 2.1.2 EdgeController

EdgeController 是 kube-apiserver 和 edgecore 之间的桥梁：

- 边缘节点管理
- 应用状态元数据云边协同

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edge-controller.png)



下行数据流控制：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edge-downstream-controller.png)

上行数据流控制：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edge-upstream-controller.png)



### 2.1.3 DeviceController

通过 k8s CRD 来描述设备的 metadata 和 status：

- 接入和管理边缘设备
- 设备元数据云边协同

它由两个 goroutine 来实现：upstream controller 和  downstream controller



#### 2.1.3.1 device crd model

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-crd-model.png)

KubeEdge 相关的 CRD：

```bash
$ kubectl get CustomResourceDefinition | grep kubeedge
clusterobjectsyncs.reliablesyncs.kubeedge.io   2022-03-02T10:10:55Z
devicemodels.devices.kubeedge.io               2022-03-02T10:10:54Z
devices.devices.kubeedge.io                    2022-03-02T10:10:53Z
objectsyncs.reliablesyncs.kubeedge.io          2022-03-02T10:10:56Z
ruleendpoints.rules.kubeedge.io                2022-03-02T10:10:59Z
rules.rules.kubeedge.io                        2022-03-02T10:10:57Z
```

设备模型抽象：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-model-paraphrase.png)

设备实例：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-instance-paraphrase.png)



#### 2.1.3.2 云端下发更新边缘设备

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-downstream-controller.png)

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-updates-cloud-edge.png)



#### 2.1.3.3 边缘端设备更新上报云端

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-upstream-controller.png)

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-updates-edge-cloud.png)



### 2.1.4 SyncController

SyncController 将定期将保存的对象资源验证与k8s中的对象进行比较，然后触发重试和删除等事件

当 CloudHub 向 NodeMessageQueue 添加事件时，它将与 NodeMessageQueue 中的相应对象进行比较，如果 NodeMessageQueue 中的对象较新，它将直接丢弃这些事件

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/sync-controller.png)



### 2.1.5 CSI Driver

同步存储数据到边缘



### 2.1.6 Admission Webhook

校验进入KubeEdge对象的合法性



## 2.2 边缘端（EdgeCore）

在 Edge 端部署，一般不能同时运行 kubelet 和 kube-proxy 组件，不建议关闭 edgecore 的环境检查来运行它们

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-edgecore.png)

- **EdgeHub**: 边缘端通信模块。websocket客户端，负责同步云端的资源更新、报告边缘主机和设备状态变化到云端等功能

- **Edged**：在边缘节点上运行并管理容器化应用程序的代理，用于管理容器化的应用程序。
- **EventBus**：MQTT 客户端，负责与 MQTT 服务器（mosquitto）交互，为其他组件提供订阅和发布功能。
- **ServiceBus**：运行在边缘的HTTP客户端，接收来自云上服务的请求、和边缘应用进行 http 交互
- **DeviceTwin**: 负责存储设备状态和同步设备状态到云，它还为应用程序提供查询接口
- **MetaManager**: edged 和 edgehub 之间的消息处理器，它负责向轻量级数据库（SQLite）存储/检索元数据。



### 2.2.1 EdgeHub

edgehub 负责与 cloudhub 组件交互，支持 websocket 或 quic 协议。主要用于同步元端资源更新，报告边缘端主机和设备状态变更等功能

主要功能：

- Keep alive
- Publish Client Info.
- Route to Cloud
- Route to Edge

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgehub.png)

EdgeHub 的两类客户端：

- HTTP client：用于 EdgeCore 和 CloudCore 通信所需证书的申请
- Websocket/QUIC client：用于 EdgeCore 和 CloudCore 之间消息交互，如资源下发，状态上传等

#### 2.2.1.1 状态上报

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgehub-route-to-edge.png)

#### 2.2.1.2 消息下发

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgehub-route-to-cloud.png)



### 2.2.2 Edged

kubelet 的裁剪版，去掉一些用不上的功能，然后就成为`Edged`模块，该模块就是保障cloud端下发的pod以及其对应的各种配置、存储（后续会支持函数式计算）能够在edge端稳定运行，并在异常之后提供自动检测、故障恢复等能力。当然，由于k8s本身运行时的发展，该模块对应支持各种CRI应该也比较容易。

edged 是一个轻量化的 kubelet，负责在边缘节点上管理 pod 等相关资源

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edged-modules.png)

Pod 创建流程：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edged-pod-create.png)



### 2.2.3 EventBus

EventBus就是一个MQTT broker的客户端，主要功能是将edge端各模块通信的message与设备mapper上报到MQTT的event做转换的组件；



#### 2.2.3.1 三种模式

- internalMqttMode
- externalMqttMode
- bothMqttMode



#### 2.2.3.2 topics

| Topic                                    | Publisher | Subscriber | 用途                       |
| ---------------------------------------- | --------- | ---------- | -------------------------- |
| $hw/events/node/+/membership/updated     | edgecore  | mapper     | 订阅设备列表的变化         |
| $hw/events/node/+/membership/get         | mapper    | edgecore   | 查询设备列表               |
| $hw/events/node/+/membership/get/result  | edgecore  | mapper     | 获取查询设备列表的结果     |
| $hw/events/device/+/updated              | edgecore  | mapper     | 订阅设备属性描述的变化     |
| $hw/events/device/+/twin/update/result   | edgecore  | mapper     | 获取设备属性更新是否成功   |
| $hw/events/device/+/twin/update/delta    | edgecore  | mapper     | 获取设备属性更新的值       |
| $hw/events/device/+/twin/update/document | edgecore  | mapper     | 获取设备属性更新的操作记录 |
| $hw/events/device/+/twin/get/result      | edgecore  | mapper     | 返回获取设备属性的值       |
| $hw/events/device/+/twin/update          | edgecore  | mapper     | 通知设备属性的值更新       |
| $hw/events/device/+/twin/get             | mapper    | edgecore   | 获取设备属性的值           |
| $hw/events/device/+/state/update         | mapper    | edgecore   | 通知设备状态更新           |
| $hw/events/device/+/state/update/result  | edgecore  | mapper     | 获取设备状态更新结果       |
| $hw/events/upload/#                      | -         | edgecore   | 发向云端                   |
| SYS/dis/upload_records+                  | -         | edgecore   | 发送云端                   |



#### 2.2.3.3 messages flow

1. 从MQTT客户端接收请求消息

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/eventbus-msg-from-client.png)

2. 发送响应消息到MQTT客户端

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/eventbus-msg-to-client.png)

数据监控：

```json
Topic: $hw/events/device/dht11/twin/update/resultQoS: 0
{"event_id":"","timestamp":1649387604120,"twin":{"humidity":{"actual":{"value":"","metadata":{"timestamp":1649387604123}},"optional":false,"metadata":{"type":"string"}},"status":{"actual":{"value":"0","metadata":{"timestamp":1649387604126}},"optional":false,"metadata":{"type":"string"}},"temperature":{"actual":{"value":"","metadata":{"timestamp":1649387604130}},"optional":false,"metadata":{"type":"string"}}}}
```



### 2.2.4 MetaManager

`MetaManager`模块后端对应一个本地的数据库（sqlLite），所有其他模块需要与cloud端通信的内容都会被保存到本地DB种一份，当需要查询数据时，如果本地DB中存在该数据，就会从本地获取，这样就避免了与cloud端之间频繁的网络交互；同时，在网络中断的情况下，本地的缓存的数据也能够保障其稳定运行（比如你的智能汽车进入到没有无线信号的隧道中），在通信恢复之后，重新同步数据。

支持的操作：

- Insert
- Update
- Delete
- Query
- Response
- NodeConnection
- MetaSync

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/meta-manager-update.png)



### 2.2.5 DeviceTwin

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-devicetwin.png)

设备相关概念：

- **设备属性(device attribute/property)**：设备属性可以理解为设备的元数据（或称之为静态属性），负责描述设备的详细信息，定义好之后一般是不会变的。比如说温度计设备，它的作用是负责采集环境温度。显然，这种设备一般会有一个名为“temperature”的属性，该属性的类型也许是“float”类型，表示温度的数据类型，等等。
- **设备状态(device status)**：设备状态指的是设备是否在线，一般有“online”、“offline”和“unknown”3种定义。
- **设备孪生(device twin)**：设备孪生则是设备的动态属性，表示具体设备的专有实时数据，例如灯的开/关状态、温度计真实采集到的温度值，等等。在设备孪生（twin）中，进一步定义了“desired value(期望值)”和“reported value(真实值)”。其中，“desired value”指的是控制面希望设备达到的状态，比如，用户远程打开灯，由用户发出的指令即属于期望值；而“reported value”指的是设备上报给控制面的真实值，比如，温度计采集的温度值。需要注意的是，并不是每种设备都必须存在“desired value”，但一般都会有“reported value”。对于灯这类读写（readwrite）设备而言，我们既可以读取其上报的真实值（开或关），也可以控制它的状态（开或关）；而对于温度计这类只读（readonly）设备而言，我们只能读取其上报的真实值，而无需设置其期望值。

DeviceTwin 负责存储设备状态、处理设备属性、处理 DeviceTwin 操作。在边缘设备和边缘节点之间创建成员关系，将设备状态同步到云已经在边缘和云之间同步 DeviceTwin 信息，还为应用程序提供查询接口。

DeviceTwin组件负责沟通协调四个子模块的工作，具体包含4个方面，即：1）同步设备数据；2）注册并启动子模块；3）根据消息类型分别向子模块进行消息分发；4）对子模块进行健康检查。更具体的，四个子模块的作用分别如下：

- **Membership Module**：该模块主要负责绑定新加入的设备与指定的边缘节点（其实就是NodeSelector的体现）。比如温度传感器关联在边缘节点node-A上，蓝牙音箱关联在了节点node-B上，如果云端要控制蓝牙音箱，那就要把数据准确的推到node-B上。
- **Twin Module**：该模块主要负责所有设备孪生相关的操作。比如，设备孪生更新（device twin update）、设备孪生获取（device twin get）和设备孪生同步至云端（device twin sync-to-cloud）。
- **Communication Module**：该模块主要负责各个子模块之间的通信。
- **Device Module**：该模块主要负责执行设备相关的操作，比如处理设备状态（device status）更新和设备属性（device attribute）更新。

设备数据存储到 sqlite 中，包含三张表：device、device_attr 和 device_twin



### 2.2.6 ServiceBus

ServiceBus 外部 HTTP-REST-API 接入时的转换组件



# 3. 模块通信

## 3.1 Beehive

Beehive 是 KubeEdge 的通信框架，用于 KubeEdge 模块之间的通信。beehive 实现了两种通信机制：unixsocket 和 go-channel

beehive模块在整个kubeedge中扮演了非常重要的作用，它实现了一套Module管理的接口，程序中各个模块的启动、运行、模块间的通信等都是由其统一封装管理



## 3.2 边缘端

### 3.2.1 入口

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-edgecore.png)

- 初始化的时候，分别加载edge端 modules 的 init 函数，注册 modules 到 beehive 框架中 

- 在 core.Run 中遍历启动 StartModules



### 3.2.2 EdgeHub

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-edgehub.png)

- 重点在启动两个 go routine，实现往两个方向的消息接收和发送

- `go ehc.routeToEdge` 接收cloud端转发至edge端的消息，然后调用`ehc.dispatch` 解析出消息的目标 module 并基于 beehive 模块 module 间消息的通信机制转发出去
- `go ehc.routeToCloud` 将edge端消息转发到CloudHub。另外还实现了对同步消息的response等到超时处理的逻辑：未超时则转发response给消息发送端模块；消息发送失败，该goroutine退出，通知所有模块，当前与 cloud 端未连接状态，然后重新发起连接
- metaManager 在与 cloud 断开期间，使用本地sqlite的数据，不会发往cloud端查询



### 3.2.3 Edged

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-edged.png)

调用kubelet的代码，实现了较多的启动流程。另外，将之前kubelet的client作为fake接口，转而将数据都通过metaClient存储到metaManager，从而代理之前直接访问 api-server 的操作

差异在`e.syncPod`的实现，通过metaManager和EdgeController的pod任务列表，来执行本地pod的操作。同时，这些pod关联的configmap和secret也会随着处理pod的过程一并处理。对pod的操作也是基于一个操作类别的 queue，比如`e.podAddWorkerRun`就启动了一个用于消费加pod的queue的goroutine。外部封装成这样，内部完全通过引用kubelet原生包来处理



### 3.2.4 MetaManager

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-metamanager.png)

- 外层按照一定周期给自己发送消息，触发定时同步pod状态到 cloud 端
- mainLoop 中，启动一个独立的goroutine接收外部消息，并执行处理逻辑，处理逻辑基于消息类型分类：
  - cloud 端发起的增删改查
  - edge 端模块发起的查询请求 （当与cloudhub的连接是disconnect时，本地查询）
  - cloud 端返回的查询响应的结果
  - edgeHub发来的用于更新与cloudHub连接状态的消息
  - 自己发给自己，定期同步edge端pod状态到cloud端的消息
  - 函数式计算相关的消息



### 3.2.5 EventBus

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-eventbus.png)

EventBus 用于对接 MQTT Broker 和 beehive，主要有两种启动模式：

- 使用内嵌 MQTT Broker
- 使用外部 MQTT Broker

在内嵌 MQTT Broker模式下，EventBus 启动了Golang实现的 broker 包 `gomqtt` 作为外部 MQTT 设备的接入，其操作主要有：

- 向 broker 订阅关注的 topic

  ```go
  SubTopics = []string{
  	"$hw/events/upload/#",
  	"$hw/events/device/+/state/update",
  	"$hw/events/device/+/twin/+",
  	"$hw/events/node/+/membership/get",
  	"SYS/dis/upload_records",
  }
  ```

- 当接收到对应的event时，触发回调函数 onSubscribe

- 回调函数中，对event做了简单的分类，分别发到不同的目的地(DeviceTwin或EventHub)

  - `$hw/events/device/+/twin/+` 和`$hw/events/node/+/membership/get`类型的topic的event发送到 DeviceTwin
  - 其他的event直接发送到EventHub再同步到 cloud 端

  

### 3.2.6 ServiceBus

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-servicebus.png)

ServiceBus 启动一个 goroutine 来接收来自 beehive 的消息，然后基于消息中带的参数，通过调用 http client 将消息通过 REST-API 发送到本地地址127.0.0.1上目的APP。它相当于一个客户端，而APP时一个 HTTP Rest-API server，所有的操作和设备状态都需要客户端调用接口来下发和获取



### 3.2.7 DeviceTwin

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-devicetwin.png)

- 数据存储到本地sqlite中，包含三张表：`device`，`deviceAttr`，`deviceTwin`

- 处理其他模块发送到 twin module 的消息，然后调用 `dtc.distributeMsg` 来处理消息。在消息处理逻辑里面，消息被分为四类，分别由对应的action处理
  - membership
  - device
  - communication
  - twin



## 3.3 云端

### 3.3.1 入口

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-cloudcore.png)



### 3.3.2 CloudHub

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-cloudhub.png)

`handler.WebSocketHandler.ServeEvent` 在 websocket server 上接收新边缘节点的连接，并为该节点分配 channel queue，然后将消息交给负责内容读写的逻辑处理

`channelq.NewChannelEventQueue` 为每个边缘节点维护一个对应的 channel queue(默认10个消息缓存)，然后调用`go q.dispatchMessage` 来接收由 controller 发送到 CloudHub 的消息，基于消息内容解析其目的节点，然后将消息发送到节点对应的 channel queue 处理

CloudHub 的核心逻辑：

- `handler.WebSocketHandler.EventWriteLoop` 在channel中读取，并负责通过 ws 隧道发送到对应的节点上，如果节点不存在或 offline将终止发送
- `handler.WebSocketHandler.EventReadLoop` 从 ws 隧道读取来自边缘节点的消息，然后将消息发送到 controller 模块处理（如果是 keepalive 心跳消息直接忽略）

- 如果 CloudHub发往边缘节点的消息失败，将触发 EventHandler 的 CancelNode 操作；结合EdgeHub端的行为，我们知道EdgeHub会重新发起到Cloud端的新连接，然后重新走一遍同步流程



### 3.3.3 EdgeController

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-edgecontroller.png)

核心逻辑：

- upstream：接收由 beehive 转发的消息，然后基于消息的资源类型，通过 `go uc.dispatchMessage` 转发到不同的 goroutine 处理。其中的操作包括 nodeStatus、podStatus、queryConfigMap、querySecret、queryService、queryEndpoint 等，它们均通过k8s client来调用 api-server 来更新状态
- downstream：通过 k8s client 来监听各种资源的变化，比如pod通过 `dc.podManager.Events` 来读取消息，然后调用`dc.messageLayer.Send` 将消息发送到 edge 端处理。资源包括pod、confimap、secret、node、service、endpoint等



### 3.3.4 DeviceController

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-code-devicecontroller.png)

与 EdgeController 类似，但不关注 k8s 的 workload 的子资源，而是为 device 定义 CRD，即 device 和 deviceModel





# 4. 可靠的消息传递机制

云与边缘之间的不稳定网络，会导致边缘节点频繁断开。如果 CloudCore 或 EdgeCore 重启或脱机一段时间，可能会导致发送到边缘节点的消息丢失。如果没有新的事件成功传递到边缘，将导致云和边缘之间的不一致

三种消息传递机制：

- At-Most-Once：不可靠
- Exactly-Once：性能差，代价高
- At-Lease Once：建议采用



## 4.1 At-Least-Once Delivery

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/reliable-message-workflow.png)

- 使用 CRD 存储资源的最新版本，该资源已成功发送到 edge，当 cloudcore 启动时，它将检查 ResourceVersion 以避免发送旧消息
- EdgeController 和 DeviceController 将消息发送到 CloudHub，MessageDispatcher 将根据消息中的节点名称向相应的 NodeMessageQueue 中发送消息
- CloudHub 顺序地将数据从 NodeMessageQueue 发送到相应的边缘节点，并将消息ID存储在ACK通道中。当从边缘节点收到 ACK 消息时，ACK通道将触发将消息版本保持到k8s 作为 CRD，并发送下一条消息
- 当 EdgeCore 收到消息时，它将首先将消息保存到本地数据存储，然后将 ACK 消息返回给云
- 如果 CloudHub 在间隔内没有收到 ACK 消息，它将持续发送 5 次，如果都失败，CloudHub 将放弃该事件。交由 SyncController 来处理这个失败事件
- 计算边缘节点接收到消息，返回的 ACK 消息也可能在传输期间丢失。在这种情况下，CloudHub 将再次发送消息，边缘可以处理重复的消息



## 4.2 SyncController

SyncController 将定期将保存的对象资源验证与k8s中的对象进行比较，然后触发重试和删除等事件

当 CloudHub 向 NodeMessageQueue 添加事件时，它将与 NodeMessageQueue 中的相应对象进行比较，如果 NodeMessageQueue 中的对象较新，它将直接丢弃这些事件

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/sync-controller.png)



## 4.3 Message Queue

当每个边缘节点成功连接到云时，将创建一个消息队列，该队列将缓存发送到边缘节点的所有消息。可使用 client-go 中的 workQueue 和 cacheStore 来实现消息队列和对象存储。为了提高队列操作性能，队列中排列的是message key

```go
// ChannelMessageQueue is the channel implementation of MessageQueue
type ChannelMessageQueue struct {
    queuePool sync.Map
    storePool sync.Map

    listQueuePool sync.Map
    listStorePool sync.Map

    objectSyncLister        reliablesyncslisters.ObjectSyncLister
    clusterObjectSyncLister reliablesyncslisters.ClusterObjectSyncLister
}

// Add message to the queue:
key,_:=getMsgKey(&message)
nodeStore.Add(message)
nodeQueue.Add(message)

// Get the message from the queue:
key,_:=nodeQueue.Get()
msg,_,_:=nodeStore.GetByKey(key.(string))

// Structure of the message key:
Key = resourceType/resourceNamespace/resourceName


// ACK message Format
AckMessage.ParentID = receivedMessage.ID
AckMessage.Operation = "response"
```



## 4.4 ReliableSync CRD

两种持久化CRD:

- ClusterObjectSync：用于保存集群作用域对象
- ObjectSync：用于保存命名空间作用域对象

名称规则：

```go
// BuildObjectSyncName builds the name of objectSync/clusterObjectSync
func BuildObjectSyncName(nodeName, UID string) string {
    return nodeName + "." + UID
}
```



### 4.4.1 ClusterObjectSync

```go
type ClusterObjectSync struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   ClusterObjectSyncSpec   `json:"spec,omitempty"`
    Status ClusterObjectSyncStatus `json:"spec,omitempty"`
}

// ClusterObjectSyncSpec stores the details of objects that sent to the edge.
type ClusterObjectSyncSpec struct {
    ObjectGroupVerion string `json:"objectGroupVerion,omitempty"`
    ObjectKind string `json:"objectKind,omitempty"`
    ObjectName string `json:"objectName,omitempty"`
}

// ClusterObjectSyncSpec stores the resourceversion of objects that sent to the edge.
type ClusterObjectSyncStatus struct {
    ObjectResourceVersion string `json:"objectResourceVersion,omitempty"`
}
```



### 4.4.2 ObjectSync

```go
type ClusterObjectSync struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   ObjectSyncSpec   `json:"spec,omitempty"`
    Status ObjectSyncStatus `json:"spec,omitempty"`
}

// ObjectSyncSpec stores the details of objects that sent to the edge.
type ObjectSyncSpec struct {
    ObjectGroupVerion string `json:"objectGroupVerion,omitempty"`
    ObjectKind string `json:"objectKind,omitempty"`
    ObjectName string `json:"objectName,omitempty"`
}

// ClusterObjectSyncSpec stores the resourceversion of objects that sent to the edge.
type ObjectSyncStatus struct {
    ObjectResourceVersion string `json:"objectResourceVersion,omitempty"`
}
```



### 4.4.3 ObjectSync CR 示例

```bash
$  kubectl get ObjectSync -n kubeedge
NAME                                             AGE
ke-edge01.0eafe1ea-ce13-4591-91db-8b66499f4075   17d
ke-edge01.14bc751f-aac9-40a8-849c-7e30cb38d635   17d
ke-edge01.223d853e-134a-4bd2-bac5-d91b28c1cea0   40d
ke-edge01.2b3bfd10-3009-4d09-bfda-df3621291786   40d
ke-edge01.3ab873f6-ad6b-4dca-abd8-7a97d37adc96   40d
ke-edge01.83399ac3-a5ee-4b5f-8224-cf4ce47212c9   40d
ke-edge01.c01e73a2-abfc-46c2-a03f-6d14c23151b9   40d
ke-edge01.d037bb27-51c5-49a9-8149-b6bf7c8d764d   40d
ke-edge01.ef1f6a8a-5e11-4f63-8007-ed56f76b91dc   40d
ke-edge03.0eafe1ea-ce13-4591-91db-8b66499f4075   17d
ke-edge03.223d853e-134a-4bd2-bac5-d91b28c1cea0   19d
ke-edge03.2b3bfd10-3009-4d09-bfda-df3621291786   19d
ke-edge03.3ab873f6-ad6b-4dca-abd8-7a97d37adc96   19d
ke-edge03.83399ac3-a5ee-4b5f-8224-cf4ce47212c9   19d
ke-edge03.9793c9bf-faca-4918-9a9d-1b95f4d42d5e   17d
ke-edge03.c01e73a2-abfc-46c2-a03f-6d14c23151b9   19d
ke-edge03.d037bb27-51c5-49a9-8149-b6bf7c8d764d   19d
ke-edge03.ef1f6a8a-5e11-4f63-8007-ed56f76b91dc   19d

$ kubectl describe ObjectSync ke-edge03.ef1f6a8a-5e11-4f63-8007-ed56f76b91dc -n kubeedge
Name:         ke-edge03.ef1f6a8a-5e11-4f63-8007-ed56f76b91dc
Namespace:    kubeedge
Labels:       <none>
Annotations:  <none>
API Version:  reliablesyncs.kubeedge.io/v1alpha1
Kind:         ObjectSync
Metadata:
  Creation Timestamp:  2022-03-24T06:17:30Z
  Generation:          1
  Managed Fields:
    API Version:  reliablesyncs.kubeedge.io/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:objectAPIVersion:
        f:objectKind:
        f:objectName:
      f:status:
        .:
        f:objectResourceVersion:
    Manager:         cloudcore
    Operation:       Update
    Time:            2022-03-24T06:17:30Z
  Resource Version:  6477138
  Self Link:         /apis/reliablesyncs.kubeedge.io/v1alpha1/namespaces/kubeedge/objectsyncs/ke-edge03.ef1f6a8a-5e11-4f63-8007-ed56f76b91dc
  UID:               e989679b-fdb2-42e6-aabc-35356c230ae8
Spec:
  Object API Version:  v1
  Object Kind:         secrets
  Object Name:         edgemesh-server-token-nx6cg
Status:
  Object Resource Version:  135023
Events:                     <none>
```



## 4.5 异常场景处理

### 4.5.1 CloudCore 重启

- 当 CloudCore 启动时，将检查 ResourceVersion 以避免发送旧消息
- 在 CloudCore 重启期间，如果删除了某些对象，可能会丢失 DELETE 事件。SyncController 将处理此类情况。这里需要对象GC机制来确保删除：比较CRD中存储的对象是否存在于K8s中。如果没有，则SyncController将生成并发送一个DELETE事件到边缘，并在ACK接收到时删除CRD中的对象



### 4.5.2 EdgeCore 重启

- 当 EdgeCore 重启或脱机一段数据后，节点消息队列将缓存所有消息；当该节点联机时，消息将被发送
- 当边缘节点脱机时，CloudHub 将停止发送消息，直到边缘节点恢复联机才重试



### 4.5.3 EdgeNode 删除

- 当删除 edge 节点时，CloudCore 将删除相应的消息队列和存储



### 4.5.4 ObjectSync CR  垃圾回收

当 Edge Node 不在集群中时，应删除 EdgeNode 的所有 ObjectSync CRS

触发垃圾回收的主要方法由两种：CloudCore启动 和 EdgeNode 删除事件

- 当 CloudCore 启动时，它将首先检查是否存在旧的 ObjectSync CRS 并删除它们
- 当 CloudCore 运行时，EdgeNode 被删除事件将触发来讲回收



# 5. 设备管理

设备管理是边缘计算中物联网用例所需的关键功能。

CRD 提供的功能：

- 用于从云中管理设备的API
- 在云节点和边缘节点之间同步设备更新

同时做到：

- 设计安全的设备提供
- 解决 OTA 设备固件升级问题
- 解决设备自动发现如何发生的问题
- 解决设备迁移场景



设备控制流程：

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-creation-process.png)

在实际使用场景里，还存在一些待优化，待完善的内容:

1）海量设备数据难以处理。

2）设备通信协议比较多，很难维护。

3）设备安全性的问题，设备安全性其实在目前的设备管理里面并没有设计进来，我们更多的是对云端与边端的通信进行维护，从而保障安全性。

4）缺少设备监控指标。在实际使用中，比如说每个设备上传了多少数据，什么时候上传最近存活的状态，目前是缺失的。

5）上手难度大，需要自写操作设备应用。



## 5.1 设备模型

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-model-crd.png)



### 5.1.1 类型定义

```go
type DeviceModelSpec struct {
	Properties       []DeviceProperty        `json:"properties,omitempty"`
	PropertyVisitors []DevicePropertyVisitor `json:"propertyVisitors,omitempty"`
}

type DeviceProperty struct {
	Name        string        `json:"name,omitempty"`
	Description string        `json:"description,omitempty"`
	Type        PropertyType  `json:"type,omitempty"`
}

type PropertyType struct {
	Int    PropertyTypeInt64  `json:"int,omitempty"`
	String PropertyTypeString `json:"string,omitempty"`
}

type PropertyTypeInt64 struct {
	AccessMode   PropertyAccessMode `json:"accessMode,omitempty"`
	DefaultValue int64              `json:"defaultValue,omitempty"`
	Minimum      int64              `json:"minimum,omitempty"`
	Maximum      int64              `json:"maximum,omitempty"`
	Unit         string             `json:"unit,omitempty"`
}

type PropertyTypeString struct {
	AccessMode   PropertyAccessMode `json:"accessMode,omitempty"`
	DefaultValue string             `json:"defaultValue,omitempty"`
}

type PropertyAccessMode string

const (
	ReadWrite PropertyAccessMode = "ReadWrite"
	ReadOnly  PropertyAccessMode = "ReadOnly"
)

type DevicePropertyVisitor struct {
	PropertyName string `json:"propertyName,omitempty"`
	VisitorConfig       `json:",inline"`
}

type VisitorConfig struct {
	OpcUA VisitorConfigOPCUA   `json:"opcua,omitempty"`
	Modbus VisitorConfigModbus `json:"modbus,omitempty"`
	Bluetooth VisitorConfigBluetooth `json:"bluetooth,omitempty"`
}

type VisitorConfigBluetooth struct {
	CharacteristicUUID string `json:"characteristicUUID,omitempty"`
	DataWriteToBluetooth map[string][]byte `json:"dataWrite,omitempty"`
	BluetoothDataConverter BluetoothReadConverter `json:"dataConverter,omitempty"`
}

type BluetoothReadConverter struct {
	StartIndex int `json:"startIndex,omitempty"`
	EndIndex int `json:"endIndex,omitempty"`
	ShiftLeft uint `json:"shiftLeft,omitempty"`
	ShiftRight uint `json:"shiftRight,omitempty"`
	OrderOfOperations []BluetoothOperations `json:"orderOfOperations,omitempty"`
}

type BluetoothOperations struct {
	BluetoothOperationType BluetoothArithmaticOperationType `json:"operationType,omitempty"`
	BluetoothOperationValue float64 `json:"operationValue,omitempty"`
}

type BluetoothArithmeticOperationType string

const (
	BluetoothAdd      BluetoothArithmeticOperationType = "Add"
	BluetoothSubtract BluetoothArithmeticOperationType = "Subtract"
	BluetoothMultiply BluetoothArithmeticOperationType = "Multiply"
	BluetoothDivide   BluetoothArithmeticOperationType = "Divide"
)

type VisitorConfigOPCUA struct {
	NodeID     string     `json:"nodeID,omitempty"`
	BrowseName string     `json:"browseName,omitempty"`
}

type VisitorConfigModbus struct {
	Register       ModbusRegisterType `json:"register,omitempty"`
	Offset         *int64              `json:"offset,omitempty"`
	Limit          *int64              `json:"limit,omitempty"`
	Scale          float64            `json:"scale,omitempty"`
	IsSwap         bool               `json:"isSwap,omitempty"`
	IsRegisterSwap bool               `json:"isRegisterSwap,omitempty"`
}

type ModbusRegisterType string

const (
	ModbusRegisterTypeCoilRegister          ModbusRegisterType = "CoilRegister"
	ModbusRegisterTypeDiscreteInputRegister ModbusRegisterType = "DiscreteInputRegister"
	ModbusRegisterTypeInputRegister         ModbusRegisterType = "InputRegister"
	ModbusRegisterTypeHoldingRegister       ModbusRegisterType = "HoldingRegister"
)

type DeviceModel struct {
	metav1.TypeMeta      `json:",inline"`
	metav1.ObjectMeta    `json:"metadata,omitempty"`
	Spec DeviceModelSpec `json:"spec,omitempty"`
}

type DeviceModelList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []DeviceModel `json:"items"`
}
```



### 5.1.2 配置实例

```yaml
apiVersion: devices.kubeedge.io/v1alpha1
kind: DeviceModel
metadata:
  labels:
    description: 'TI Simplelink SensorTag Device Model'
    manufacturer: 'Texas Instruments'
    model: CC2650
  name: sensor-tag-model
spec:
  properties:
  - name: temperature
    description: temperature in degree celsius
    type:
      int:
        accessMode: ReadOnly
        maximum: 100
        unit: Degree Celsius
  - name: temperature-enable
    description: enable data collection of temperature sensor
    type:
      string:
        accessMode: ReadWrite
        defaultValue: OFF
  - name: pressure
    description: barometric pressure sensor in hectopascal
    type:
      int:
        accessMode: ReadOnly
        unit: hectopascal
  - name: pressure-enable
    description: enable data collection of barometric pressure sensor
    type:
      string:
        accessMode: ReadWrite
        defaultValue: OFF
  propertyVisitors:
  - propertyName: temperature
    modbus:
      register: CoilRegister
      offset: 2
      limit: 1
      scale: 1.0
      isSwap: true
      isRegisterSwap: true
  - propertyName: temperature-enable
    modbus:
      register: DiscreteInputRegister
      offset: 3
      limit: 1
      scale: 1.0
      isSwap: true
      isRegisterSwap: true
  - propertyName: pressure-enable
    bluetooth:
      characteristicUUID: f000aa4204514000b000000000000000
      dataWrite:
        ON: [1]
        OFF: [0]
  - propertyName: pressure
    bluetooth:
      characteristicUUID: f000aa4104514000b000000000000000
      dataConverter:
        startIndex: 3
        endIndex: 5
        orderOfOperations:
        - operationType: Divide
          operationValue: 100
```



## 5.2 设备实例

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/device-crd.png)



### 5.2.1 类型定义

```go
type DeviceSpec struct {
	DeviceModelRef *core.LocalObjectReference `json:"deviceModelRef,omitempty"`
	Protocol       ProtocolConfig             `json:"protocol,omitempty"`
	NodeSelector   *core.NodeSelector         `json:"nodeSelector,omitempty"`
}

type ProtocolConfig struct {
	OpcUA  *ProtocolConfigOpcUA  `json:"opcua,omitempty"`
	Modbus *ProtocolConfigModbus `json:"modbus,omitempty"`
}

type ProtocolConfigOpcUA struct {
	Url            string `json:"url,omitempty"`
	UserName       string `json:"userName,omitempty"`
	Password       string `json:"password,omitempty"`
	SecurityPolicy string `json:"securityPolicy,omitempty"`
	SecurityMode   string `json:"securityMode,omitempty"`
	Certificate    string `json:"certificate,omitempty"`
	PrivateKey     string `json:"privateKey,omitempty"`
	Timeout        int64  `json:"timeout,omitempty"`
}

type ProtocolConfigModbus struct {
	RTU *ProtocolConfigModbusRTU `json:"rtu,omitempty"`
	TCP *ProtocolConfigModbusTCP `json:"tcp,omitempty"`
}

type ProtocolConfigModbusTCP struct {
	IP string      `json:"ip,omitempty"`
	Port int64     `json:"port,omitempty"`
	SlaveID string `json:"slaveID,omitempty"`
}

type ProtocolConfigModbusRTU struct {
	SerialPort string `json:"serialPort,omitempty"`
	// Required. BaudRate 115200|57600|38400|19200|9600|4800|2400|1800|1200|600|300|200|150|134|110|75|50
	BaudRate   int64  `json:"baudRate,omitempty"`
	// Required. Valid values are 8, 7, 6, 5.
	DataBits   int64  `json:"dataBits,omitempty"`
	// Required. Valid options are "none", "even", "odd". Defaults to "none".
	Parity     string `json:"parity,omitempty"`
	// Required. Bit that stops 1|2
	StopBits   int64  `json:"stopBits,omitempty"`
	// Required. 0-255
	SlaveID    int64  `json:"slaveID,omitempty"`
}

type DeviceStatus struct {
	Twins []Twin      `json:"twins,omitempty"`
}

type Twin struct {
	PropertyName string       `json:"propertyName,omitempty"`
	Desired      TwinProperty `json:"desired,omitempty"`
	Reported     TwinProperty `json:"reported,omitempty"`
}

type TwinProperty struct {
	Value    string            `json:"value,omitempty"`
	Metadata map[string]string `json:"metadata,omitempty"`
}

type Device struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DeviceSpec   `json:"spec,omitempty"`
	Status DeviceStatus `json:"status,omitempty"`
}

type DeviceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Device `json:"items"`
}
```



### 5.2.2 配置实例

```yaml
apiVersion: devices.kubeedge.io/v1alpha1
kind: Device
metadata:
  name: sensor-tag01
  labels:
    description: 'TI Simplelink SensorTag 2.0 with Bluetooth 4.0'
    manufacturer: 'Texas Instruments'
    model: CC2650
spec:
  deviceModelRef:
    name: sensor-tag-model
  protocol:
    modbus:
      rtu:
        serialPort: '1'
        baudRate: 115200
        dataBits: 8
        parity: even
        stopBits: 1
        slaveID: 1
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: ''
        operator: In
        values:
        - node1
status:
  twins:
    - propertyName: temperature-enable
      reported:
        metadata:
          timestamp: '1550049403598'
          type: string
        value: OFF
      desired:
        metadata:
          timestamp: '1550049403598'
          type: string
        value: OFF
```



## 5.3 设备生命周期

物联网设备生命周期管理包括以下几个步骤：

- 设备入职/供应
  - 设备需要注册(通过授权或准入控制机制)。目前不在本设计的范围内。
- 设备配置
  - 设备在其生命周期中需要多次重新配置。没有添加新功能。设备CRD具有包含控制属性所需值的Device Twin。通过更改控件属性的期望值（desired），可以重新配置设备行为。
- 设备更新
  - 需要对设备进行固件更新或一些错误修复。这可以是计划更新或临时更新。当前的设计不支持应用此类更新。可以支持将来执行此类任务的其他操作。
- 设备监控
  - 需要监控设备状态，以支持正确的管理操作。目前依靠Mapper在设备CRD状态中报告当前设备状态。可以进一步探索额外的运行状况检查或探测，以增强平台的监控和故障排除能力。
- 设备取消置备
  - 如果设备不再需要管理，则需要从平台中注销。目前不在本设计的范围内。
- 设备退役
  - 如果设备损坏，则需要报废。目前不在本设计的范围内。



## 5.4 Mapper

Mapper是KubeEdge和设备之间的接口。它可以set/get设备数据，get设备状态并上报。

KubeEdge使用Device Controller、Device Twin和Mapper来共同控制设备。Device Controller在云端，它使用 CRD 定义和控制设备。Device Twin位于边缘端，它存储来自Mapper的值/状态，并通过Device Controller和Mapper传输消息。

Mapper的设备控制和数据：一个Mapper可以用于一类设备，意味着可以同时控制多个设备。

控制设备的第一步是配置DeviceModel和DeviceInstance。

设备控制/数据有三种类型:

- Twin值

  ```json
  "twins":[{
      "propertyName":"io-data",
      "desired":{
          "value":"1",
          "metadata":{
              "type":"int"
          }
      },
      "reported":{
          "value":"unknown"
      }
  }]
  ```

- Data

  ```json
  "data":{
      "dataProperties":[
      {
          "metadata":{
              "type":"string"
          },
              "propertyName":"temperature"
      }
      ],
      "dataTopic":"$ke/events/device/+/customized/update"
  }
  ```

- 设备状态：将定期收集并发送至设备控制器。



## 5.5 开发实例

野火开发板，DHT11 温湿度传感器

### 5.5.1 设备模型

```yaml
apiVersion: devices.kubeedge.io/v1alpha2
kind: DeviceModel
metadata:
  name: dht11-model
  namespace: default
spec:
  properties:
  - name: temperature
    description: Temperature collected from the edge device
    type:
      string:
        accessMode: ReadOnly
        defaultValue: ''
  - name: humidity
    description: Humidity collected from the edge device
    type:
      string:
        accessMode: ReadOnly
        defaultValue: ''
```



### 5.5.2 设备实例

```yaml
apiVersion: devices.kubeedge.io/v1alpha2
kind: Device
metadata:
  name: dht11
  labels:
    description: 'temperature-humidity'
    manufacturer: 'embedfire'
spec:
  deviceModelRef:
    name: dht11-model
  nodeSelector:
    nodeSelectorTerms:
      - matchExpressions:
          - key: ''
            operator: In
            values:
              - ke-edge03
status:
  twins:
  - propertyName: temperature
    desired:
      metadata:
        type: string
      value: ''
    reported:
      metadata:
        type: string
      value: ''
  - propertyName: humidity
    desired:
      metadata:
        type: string
      value: ''
    reported:
      metadata:
        type: string
      value: ''
```



### 5.5.3 device-mapper

设备控制器，主要实现对设备的控制，接收和上传数据

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: dht11-app
  name: dht11-app
  namespace: default
spec:
  selector:
    matchLabels:
      k8s-app: dht11-app
  template:
    metadata:
      labels:
        k8s-app: dht11-app
    spec:
      hostNetwork: true
      containers:
        - name: dht11-app
          image: dht11-app:v1.0.0
          imagePullPolicy: IfNotPresent
          securityContext:
            privileged: true
      nodeName: ke-edge03
      restartPolicy: Always
```



### 5.5.4 控制器 app

部署在云端，提供对边缘设备的操作接口/交换界面等功能

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: dht11-controller-app
  name: dht11-controller-app
  namespace: default
spec:
  selector:
    matchLabels:
      k8s-app: dht11-controller-app
  template:
    metadata:
      labels:
        k8s-app: dht11-controller-app
    spec:
      hostNetwork: true
      nodeSelector:
        node-role.kubernetes.io/master: ""
      containers:
      - name: dht11-controller-app
        image: dht11-controller-app:v1.0.0
        imagePullPolicy: IfNotPresent
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      restartPolicy: Always
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dht11
  namespace: default
rules:
- apiGroups: ["devices.kubeedge.io"]
  resources: ["devices"]
  verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dht11-rbac
  namespace: default
subjects:
  - kind: ServiceAccount
    name: default
roleRef:
  kind: Role
  name: dht11
  apiGroup: rbac.authorization.k8s.io
```



# 6. EdgeMesh

EdgeMesh主要用来做边缘侧微服务的互访。



## 6.1 架构

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-arch.png)

edgemesh 负责边缘侧流量转发，它实现了CNI接口，支持跨节点流量转发。

- APP 的流量会被导入到 edgemesh 中，edgemesh里面有Listener负责监听；

- Resolver 负责域名解析，里面实现了一个 DNS server；

- Dispather 负责流量转发

- RuleMgr 负责把 endpoint、service、pod的信息通过 MetaManager 从数据库取出来



特点：

- edgemesh-proxy 负责边缘侧流量转发
- 边缘内置域名解析能力，不依赖中心DNS
- 支持 L4, L7流量治理
- 支持跨边和云的一致的服务发现和访问体验
- 使用标准的 istio 进行服务治理控制
- P2P计算跨子网通信



和kube-proxy的对比

- kube-proxy： 需要list-watch service，从而进行服务发现 容器化部署在每个节点(daemonset) service with cluster IP
- edgemesh： 从cloudcore接收service信息，从而进行服务发现 嵌入到edgecore headless service



**为什么域名解析会放到边缘？**

在k8s中，域名解析由coreDNS完成，它一般部署在主节点或某个独立的节点上。但是在边缘计算场景下，边缘与云的连接可能经常断开，这导致域名解析服务不能正常使用。因此需要将域名解析放到边缘上，云上的 service, endpoint, pod信息同步到边缘。



## 6.2 设计原理

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-principle.png)

-  edgemesh通过kubeedge边缘侧list-watch的能力，监听service、endpoints等元数据的增删改，再根据service、endpoints的信息创建iptables规则
-  edgemesh使用域名的方式来访问服务，因为fakeIP不会暴露给用户。fakeIP可以理解为clusterIP，每个节点的fakeIp的CIDR都是9.251.0.0/16网段(service网络)
-  当client访问服务的请求到达节点后首先会进入内核的iptables
-  edgemesh之前配置的iptables规则会将请求重定向，全部转发到edgemesh进程的40001端口里（数据包从内核台->用户态）
-  请求进入edgemesh程序后，由edgemesh程序完成后端pod的选择（负载均衡在这里发生），然后将请求发到这个pod所在的主机上



## 6.3 流量转发

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-flow.png)

client pod是请求方，service pod是服务方。client pod里面有一个init container，类似于istio的init container。client先把流量打入到init container，init container这边会做一个流量劫持，它会把流量转到edge mesh里面去，edge mesh根据需要进行域名解析后转到对应节点的pod里面去。

优点：init container现在在每一个client pod里面都有一个，而它的功能作用在每一个pod里面都是一样的，后续会考虑把init container接耦出来。



## 6.4 工作原理

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-communication-flow.png)

云端是标准的Kubernetes集群，可以使用任意CNI网络插件，比如Flannel、Calico。可以部署任意Kubernetes原生组件，比如kubelet、kube-proxy；同时云端部署KubeEdge云上组件CloudCore，边缘节点上运行KubeEdge边缘组件EdgeCore，完成边缘节点向云上集群的注册。



EdgeMesh 的两个组件：

**EdgeMesh-Server：**

- 运行在云上，具有一个公网IP，监听来自EdgeMesh-Agent的连接请求，并协助EdgeMesh-Agent之间完成UDP打洞，建立P2P连接
- 在EdgeMesh-Agent之间打洞失败的情况下，负责中继EdgeMesh-Agent之间的流量，保证100%的流量中转成功率

**EdgeMesh-Agent：**

- DNS模块：内置的轻量级DNS Server，完成Service域名到ClusterIP的转换。
- Proxy模块：负责集群的Service服务发现与ClusterIP的流量劫持。
- Tunnel模块：在启动时，会建立与EdgeMesh-Server的长连接，在两个边缘节点上的应用需要通信时，会通过EdgeMesh-Server进行UDP打洞，尝试建立P2P连接，一旦连接建立成功，后续两个边缘节点上的流量不需要经过EdgeMesh-Server的中转，进而降低网络时延。



核心优势：

- 跨子网边边/边云服务通信：无论应用部署在云上，还是在不同子网的边缘节点，都能够提供通Kubernetes Service一致的使用体验。

- 低时延：通过UDP打洞，完成EdgeMesh-Agent之间的P2P直连，数据通信无需经过EdgeMesh-Server中转。

- 轻量化：内置DNS Server、EdgeProxy，边缘侧无需依赖CoreDNS、KubeProxy、CNI插件等原生组件。

- 非侵入：使用原生Kubernetes Service定义，无需自定义CRD，无需自定义字段，降低用户使用成本。

- 适用性强：不需要边缘站点具有公网IP，不需要用户搭建VPN，只需要EdgeMesh-Server部署节点具有公网IP且边缘节点可以访问公网。



## 6.5 应用场景

### 6.5.1 子网内边边服务发现与流量转发

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-e2e-intra-subnet.png)

子网内边边服务发现与流量转发是EdgeMesh最先支持的特性，为同一个局域网内的边缘节点上的应用提供服务发现与流量转发能力。

智慧园区是典型的边缘计算场景。在同一个园区内，节点位于同一个子网中，园区中的摄像头、烟雾报警器等端侧设备将数据上传到节点上的应用，节点上的应用需要互相的服务发现与流量转发。这种场景下的用户使用流程如下：

- 如上图所示，EdgeNode1和EdgeNode2位于同一个子网中，用户在EdgeNode1上部署了一个Video Server，用于对外提供摄像头采集上来的视频流，并通过标准的Kubernetes Service形式暴露出来，比如video.cluster.local.service。
- 用户在同一个子网内的EdgeNode2上，通过video.cluster.local.service的形式对该Server发起访问，希望获取视频流信息并进行分析处理。
- 位于EdgeNode2上的EdgeMesh-Agent对域名进行解析，并对该访问进行流量劫持。
- EdgeNode1上的EdgeMesh-Agent与Video Server建立连接， Client与Video Server之间的数据通过EdgeMesh-Agent进行中转，从而获取视频流信息。



### 6.5.2 跨子网边边服务发现与流量转发

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-e2e-cross-subnet.png)

跨子网边边服务发现与流量转发是EdgeMesh1.8.0版本支持的特性，为位于不同子网内的边缘节点上的应用提供服务发现与流量转发能力。

智慧园区场景中，不同的园区之间通常需要共享一些信息，比如车库停车位数量、视频监控数据等，不同的园区通常位于不同的子网中，因此需要跨子网节点间的服务发现与流量转发能力。这种场景下的用户使用流程如下：

- 如上图所示，EdgeNode1与EdgeNode2位于不同的子网中，用户在EdgeNode1上部署了一个Park Server，用于实时提供园区内停车位的使用情况，并通过标准的Kubernetes Service形式暴露出来，比如park.cluster.local.service。
- EdgeNode2希望可以获取EdgeNode1所在园区的停车位使用情况，从而为车主提供更全面的停车信息。当位于EdgeNode2上的client以service域名的方式发起访问时，流量会被EdgeMesh-Agent劫持，但是因为EdgeNode1与EdgeNode2位于不同的子网中，两个节点上的EdgeMesh-Agent不能够直接建立连接，因此会出现获取停车位使用信息失败的情况。



### 6.5.3 **跨边云服务发现与流量转发**

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/edgemesh-e2c.png)

跨边云服务发现与流量转发是EdgeMesh1.8.0版本支持的特性，为位于云上和边缘节点上的应用提供服务发现与流量转发能力。下面介绍边访问云的情形，云访问边会遇到和边访问云同样的问题，这里不做赘述。

智慧园区场景中，园区入口需要对访问人员进行人脸识别去决定是否放行，受限于边侧算力，通常会在边侧进行人脸数据的采样，并将采样的数据上传到云端进行运算，因此需要跨边云的服务发现与流量转发。这种场景下的用户使用流程如下：

- 如上图所示，CloudNode1和EdgeNode2分别位于云上和边缘，用户在CloudNode1上部署了一个Face Server，对边侧上报上来的人脸数据进行处理，并返回是否放行的结果，Face Server通过标准的Kubernetes Service形式暴露出来，比如face.cluster.local.service。
- 在边缘侧的EdgeNode2上，用户通过face.cluster.local.service的形式对该Face Server发起访问并上报人脸数据，希望获得是否放行的结果。
- 位于EdgeNode2上的EdgeMesh-Agent对该域名进行解析，并对该访问进行劫持，因为CloudNode1和EdgeNode2位于不同的子网中，两个节点上的EdgeMesh-Agent不能够直接建立连接，因此会出现无法获取是否放行结果的情况。



# 7. 部署KubeEdge

## 7.1 准备工作

| **角色**  | **IP**         | **组件**                |
| --------- | -------------- | ----------------------- |
| ke-cloud  | 192.168.80.100 | k8s-cluster，cloud-core |
| ke-edge01 | 192.168.80.101 | docker,  edge-core      |
| ke-edge02 | 192.168.80.102 | docker,  edge-core      |

kube-edge版本：1.9.1

kuberenetes 版本：1.19.3  （配套kube-edge）

docker 版本：docker-ce 19.03  （配套kuberenetes）



```bash
# 1. 修改主机名，按规划主机名修改
hostnamectl set-hostname ke-cloud
hostnamectl set-hostname ke-edge01
hostnamectl set-hostname ke-edge02

# 2. 相关组件
apt install conntrack ntpdate -y 

# 3. 禁用 swap
swapoff -a && sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab

# 4. 时间同步 
echo '*/30 * * * * /usr/sbin/ntpdate -u ntp1.aliyun.com >> /var/log/ntpdate.log 2>&1' > /tmp/ntp.txt
crontab /tmp/ntp.txt

# 5. 内核参数调整
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_reuse =0     
vm.swappiness=0         
vm.overcommit_memory=1       
fs.inotify.max_user_instances=8192
vm.panic_on_oom=0 
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
EOF

sysctl -p /etc/sysctl.d/kubernetes.conf
```



## 7.2 安装 docker

```bash
# 1. 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -

# 2. 写入软件源信息
add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"   # x86_64
add-apt-repository "deb [arch=arm64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"   # aarch64

# 3. 更新
apt update

# 4. 查询版本
apt-cache madison docker-ce
#docker-ce | 5:19.03.15~3-0~ubuntu-focal | https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal/stable amd64 Packages

# 5. 安装
apt install docker-ce=5:19.03.15~3-0~ubuntu-focal -y

# 6. 验证
docker version

# 7. 修改cgroup驱动为systemd，适配k8s默认选项
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
  ]
}
EOF

systemctl restart docker
```



## 7.3 安装 keadm

安装 kube-edge 工具

```bash
# x86_64
wget https://github.com/kubeedge/kubeedge/releases/download/v1.9.1/keadm-v1.9.1-linux-amd64.tar.gz  
tar zxvf keadm-v1.9.1-linux-amd64.tar.gz
cp keadm-v1.9.1-linux-amd64/keadm/keadm /usr/local/bin/

# aarch64
wget https://github.com/kubeedge/kubeedge/releases/download/v1.9.1/keadm-v1.9.1-linux-arm64.tar.gz   
tar zxvf keadm-v1.9.1-linux-arm64.tar.gz
cp keadm-v1.9.1-linux-arm64/keadm/keadm /usr/local/bin/
```



## 7.4 部署 k8s 集群 (ke-cloud)

### 7.4.1 安装软件

```bash
# 1. 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 

# 2. 写入软件源信息
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

# 3. 更新
apt update

# 4. 查询版本
apt-cache madison kubeadm
#kubeadm |  1.19.3-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages

# 5. 安装
apt-get install -y kubeadm=1.19.3-00 kubelet=1.19.3-00 kubectl=1.19.3-00
```



### 7.4.2 集群初始化

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.80.100 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.19.3 \
  --service-cidr=10.96.0.0/16 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all
```

输出结果：

```bash
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.80.100:6443 --token 52ctux.c1811camg50koyg0 \
    --discovery-token-ca-cert-hash sha256:1944d025f095a847bd1f8e7adf518f7078c85370cd77271257870c64467634d1
```

根据提示，创建 `kubectl` 认证文件：

```bash
# 即使是root用户，也采用默认文件方式
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

kubectl 命令补齐：

```bash
echo "source <(kubectl completion bash)" >> ~/.bashrc

# 立即生效
source <(kubectl completion bash)
```



### 7.4.3 集群状态

集群状态异常：

```bash
$ kubectl get cs
NAME                 STATUS      MESSAGE                                           ERROR
scheduler            Unhealthy   Get "http://127.0.0.1:10251/healthz": dial tcp 127.0.0.1:10251: connect: connection refused
controller-manager   Unhealthy   Get "http://127.0.0.1:10252/healthz": dial tcp 127.0.0.1:10252: connect: connection refused
etcd-0               Healthy     {"health":"true"}
```



原因：使用了非安全端口。按如下方法修改

```bash
$ vi /etc/kubernetes/manifests/kube-scheduler.yaml 
...
spec:
  containers:
  - command:
    - kube-scheduler
    - --kubeconfig=/etc/kubernetes/scheduler.conf
    - --leader-elect=true
    #- --port=0    # 注释掉
    image: k8s.gcr.io/kube-scheduler:v1.18.6

$ vi /etc/kubernetes/manifests/kube-controller-manager.yaml
...
spec:
  containers:
  - command:
    - kube-controller-manager
    - --node-cidr-mask-size=24
    #- --port=0   # 注释掉
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt

# 重启kubelet
$ systemctl restart kubelet

# 再次查询状态
$ kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
```



### 7.4.4 kube-proxy

避免 `kube-proxy` 部署在 edge 节点上

```bash
$ kubectl edit ds kube-proxy -n kube-system
    spec:
      ...
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/edge
                    operator: DoesNotExist
```



### 7.4.5 网络插件

注意：**可选，但如果部署，需要跳过 edge 节点**

```bash
$ wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 确保网络配置与 `--pod-network-cidr=10.244.0.0/16` 一致
$ vi kube-flannel.yml
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
  ...
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
              - key: node-role.kubernetes.io/edge   # new add
                operator: DoesNotExist

$ kubectl apply -f kube-flannel.yml

$ kubectl get node
NAME       STATUS   ROLES                  AGE     VERSION
ke-cloud   Ready    control-plane,master   4m18s   v1.21.4

$ kubectl get pod -n kube-system
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
kube-system   coredns-6d56c8448f-jv8ht           1/1     Running   0          23m
kube-system   coredns-6d56c8448f-kjjqv           1/1     Running   0          23m
kube-system   etcd-ke-cloud                      1/1     Running   0          23m
kube-system   kube-apiserver-ke-cloud            1/1     Running   0          23m
kube-system   kube-controller-manager-ke-cloud   1/1     Running   0          19m
kube-system   kube-flannel-ds-s88db              1/1     Running   0          54s
kube-system   kube-proxy-svvqc                   1/1     Running   0          8m2s
kube-system   kube-scheduler-ke-cloud            1/1     Running   0          19m
```



## 7.5 部署 kube-edge 

### 7.5.1 部署 cloud-core  (ke-cloud)

注意：**需要开 https 代理，否则可能无法正常从 github 下载相关的组件**。如果没有代理，可自行配置`/etc/hosts`文件，参照 https://github.com/ineo6/hosts

```bash
# 安装 cloudcore，生成证书并安装CRD
keadm init --advertise-address="192.168.80.100"

# 默认启动方式：pkill cloudcore ; nohup /usr/local/bin/cloudcore > /var/log/kubeedge/cloudcore.log 2>&1 &
# 使用 systemctl 管理 cloudcore
pkill cloudcore
cp /etc/kubeedge/cloudcore.service /lib/systemd/system/

systemctl daemon-reload
systemctl start cloudcore.service
systemctl status cloudcore.service
systemctl enable cloudcore.service

# 获取token令牌，该令牌将在加入边缘节点时使用
$ keadm gettoken
43183b3d3342bb4c314e008410c744d06129f2d70d871c4067044b6b373e10e1.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NDYyOTA5NjZ9.8fRNeTTA_uarmvMMTwT5DGgOH6kPkUSf4OUM_X3LnA0
```



### 7.5.2  部署 edge-core  (ke-edgeXX)

**需要开 https 代理，否则可能无法正常从 github 下载相关的组件**。如果没有代理，可自行配置`/etc/hosts`文件，参照 https://github.com/ineo6/hosts

```bash
# ke-edge01
keadm join --cloudcore-ipport=192.168.80.100:10000 --edgenode-name=ke-edge01 --token=43183b3d3342bb4c314e008410c744d06129f2d70d871c4067044b6b373e10e1.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NDYyOTA5NjZ9.8fRNeTTA_uarmvMMTwT5DGgOH6kPkUSf4OUM_X3LnA0

# ke-edge02
keadm join --cloudcore-ipport=192.168.80.100:10000 --edgenode-name=ke-edge02 --token=43183b3d3342bb4c314e008410c744d06129f2d70d871c4067044b6b373e10e1.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NDYyOTA5NjZ9.8fRNeTTA_uarmvMMTwT5DGgOH6kPkUSf4OUM_X3LnA0

# edgecore启动失败
$ journalctl -u edgecore.service -b
...
Mar 01 15:16:04 ke-edge01 edgecore[12510]: E0301 15:16:04.969118   12510 edged.go:272] init new edged error, misconfiguration: kubelet cgroup driver: "cgroupfs" is different from docker cgroup driver: "syst>
Mar 01 15:16:04 ke-edge01 systemd[1]: edgecore.service: Main process exited, code=exited, status=1/FAILURE

# 修改配置
$ vi /etc/kubeedge/config/edgecore.yaml
modules:
  ...
  edged:
    cgroupDriver: systemd    # 解决 edgecore启动失败
    
# 重启 edgecore
$ systemctl restart edgecore
```



### 7.5.3 节点列表

```bash
$ kubectl get node
NAME        STATUS   ROLES        AGE     VERSION
ke-cloud    Ready    master       23m     v1.19.3
ke-edge01   Ready    agent,edge   5m15s   v1.19.3-kubeedge-v1.9.1
ke-edge02   Ready    agent,edge   117s    v1.19.3-kubeedge-v1.9.1
```



## 7.6 启用 `kubectl logs` 功能

### 7.6.1 ke-cloud

```bash
export CLOUDCOREIPS="192.168.80.100"

# 1. 生成证书
$ cd /etc/kubeedge
$ wget https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/tools/certgen.sh
$ chmod +x certgen.sh
$ ./certgen.sh stream

# 2. 设置转发端口：10003和10350是 CloudStream 和 Edgecore 的默认端口
$ iptables -t nat -A OUTPUT -p tcp --dport 10350 -j DNAT --to $CLOUDCOREIPS:10003

# 3. 修改配置
$ vi /etc/kubeedge/config/cloudcore.yaml
modules:
  ..
  cloudStream:
    enable: true
 
# 4. 重启 cloudcore
$ systemctl restart cloudcore

# 5. 查看10003和10004端口
$ ss -nutlp |egrep "10003|10004"
tcp    LISTEN   0        4096                    *:10003                *:*      users:(("cloudcore",pid=34703,fd=7))
tcp    LISTEN   0        4096                    *:10004                *:*      users:(("cloudcore",pid=34703,fd=13))
```



### 7.6.2 ke-edgeXX

```bash
# 1. 修改配置
$ vi /etc/kubeedge/config/edgecore.yaml
modules:
  ...
  edgeStream:
    enable: true   
   
# 重启 edgecore
$ systemctl restart edgecore
```



## 7.7 启用 Metric

下载配置：

```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.1/components.yaml
```

增加亲和性和容忍:

```yaml
spec:
  template:
    spec:
     affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: Exists
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
```

启用 hostnetwork 模式：

```yaml
spec:
  template:
    spec:
      hostNetwork: true
```

跳过 TLS 安全认证：

```yaml
spec:
  template:
    spec:
      containers:
      - args:
        - --kubelet-insecure-tls
```

部署：

```bash
$ kubectl apply -f components.yaml

$ kubectl get pod -l k8s-app=metrics-server -n kube-system
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-5b8c944689-8m4fm   1/1     Running   0          12m

$ kubectl top node
NAME        CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
ke-cloud    615m         15%    2129Mi          55%
ke-edge01   52m          1%     1471Mi          38%
ke-edge03   309m         30%    273Mi           70%
```



## 7.8 安装 EdgeMesh 

做为 KubeEdge 集群的数据面组件，为应用程序提供了简单的服务发现与流量代理功能，从而屏蔽了边缘场景下复杂的网络结构。它并不依赖于 KubeEdge，它仅与标准 Kubernetes API 交互

EdgeMesh 限制：依赖 docker0 网桥，意味着只支持 docker CRI



环境检查：

```bash
# DNS Order：dns必选是第一个
$ grep hosts /etc/nsswitch.conf
hosts:          dns files

$ sysctl -a | grep ip_forward
net.ipv4.ip_forward = 1

```



### 7.8.1 修改 KubeEdge 配置

修改云端配置：(ke-cloud)

```bash
$ vi /etc/kubeedge/config/cloudcore.yaml
modules:
  ..
  dynamicController:
    enable: true
..

$ systemctl restart cloudcore
```



修改边缘端配置：(ke-edgeXX)

```bash
$ vi /etc/kubeedge/config/edgecore.yaml
modules:
 ..
  edged:
    clusterDNS: 169.254.96.16      # edgemesh-agent的commonConfig.dummyDeviceIP
    clusterDomain: cluster.local
  ..
  metaManager:
    metaServer:
      enable: true
      
$ systemctl restart edgecore
```



### 7.8.2 部署 EdgeMesh

```bash
# 1. 获取
$ git clone https://github.com/kubeedge/edgemesh.git
$ cd edgemesh

# 2. 安装 CRDs
$ kubectl apply -f build/crds/istio/

# 3. 部署 edgemesh-server
$ vi build/server/edgemesh/05-deployment.yaml
spec:
  ..
  template:
    ...
    spec:
      hostNetwork: true
      # use label to selector node
      nodeName: ke-cloud   # change to k8s-cluster node name

$ kubectl apply -f build/server/edgemesh/

# 4. 部署 edgemesh-agent
$ kubectl apply -f build/agent/kubernetes/edgemesh-agent/


# 5. 检验部署结果
$ kubectl get all -n kubeedge -o wide
NAME                                   READY   STATUS    RESTARTS   AGE    IP               NODE        NOMINATED NODE   READINESS GATES
pod/edgemesh-agent-5x794               1/1     Running   0          66s    192.168.80.101   ke-edge01   <none>           <none>
pod/edgemesh-agent-g4458               1/1     Running   0          66s    192.168.80.102   ke-edge02   <none>           <none>
pod/edgemesh-server-6bc996cf54-fcw5s   1/1     Running   0          101s   192.168.80.100   ke-cloud    <none>           <none>

NAME                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE   CONTAINERS       IMAGES                           SELECTOR
daemonset.apps/edgemesh-agent   2         2         2       2            2           <none>          66s   edgemesh-agent   kubeedge/edgemesh-agent:latest   k8s-app=kubeedge,kubeedge=edgemesh-agent

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS        IMAGES                            SELECTOR
deployment.apps/edgemesh-server   1/1     1            1           101s   edgemesh-server   kubeedge/edgemesh-server:latest   k8s-app=kubeedge,kubeedge=edgemesh-server

NAME                                         DESIRED   CURRENT   READY   AGE    CONTAINERS        IMAGES                            SELECTOR
replicaset.apps/edgemesh-server-6bc996cf54   1         1         1       101s   edgemesh-server   kubeedge/edgemesh-server:latest   k8s-app=kubeedge,kubeedge=edgemesh-server,pod-template-hash=6bc996cf54
```



### 7.8.3 测试

```bash
$ cat > nginx-deploy.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          hostPort: 80     # 通过宿主机暴露，每个节点上，只能安装一个
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - name: http
      port: 12345
      protocol: TCP
      targetPort: 80
EOF

$ kubectl apply -f nginx-deploy.yaml 

$ kubectl get pod -l app=nginx -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP           NODE        NOMINATED NODE   READINESS GATES
nginx-deploy-77f96fbb65-g9fdp   1/1     Running   0          3m32s   172.17.0.2   ke-edge01   <none>           <none>

$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)     AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP     22d
nginx-svc    ClusterIP   None         <none>        12345/TCP   3m32s

$ kubectl get ep
NAME         ENDPOINTS            AGE
kubernetes   192.168.3.191:6443   22d
nginx-svc    172.17.0.2:80        3m32s

# curl on node ke-edge01
$ curl 172.17.0.2
<!DOCTYPE html>
<html>
...
```



# 7.9 集群部署

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-cluster-deploy.png)



# 8. 脑图

详情地址：https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-summary.png

![img](https://fastly.jsdelivr.net/gh/elihe2011/bedgraph@master/kubeedge/kubeedge-summary.png)

