# 1. 边缘计算

边缘计算平台，旨在将边缘端靠近数据源的计算单元纳入到中心云，实现集中管理，将云服务部署其上，及时响应终端请求。然而，成千上万的边缘节点散布于各地，例如银行网点、车载节点、加油站等基于一些边缘设备管理场景，服务器分散在不同城市，无法统一管理，为了优化集群部署以及统一管理，特探索边缘计算场景方案。

“边缘”特指计算资源在地理分布上更加靠近设备，而远离云数据中心的资源节点。典型的边缘计算分为物联网（例如：下一代工业自动化，智慧城市，智能家居，大型商超等）和非物联网（例如：游戏，CDN等）场景。

在现实世界中，边缘计算无法单独存在，它必定要和远程数据中心（云）打通。以IoT（Internet of Things，物联网）为例，边缘设备除了拥有传感器收集周边环境的数据外，还会从云端接收控制指令。

边缘设备与云连接一般有两种模式：直连和通过中继边缘节点连接

![edge-compute](.\images\edge-compute.png)

当前边缘计算领域面临的几个挑战：

- 云边协同：AI/安全等业务在云和边的智能协同、弹性迁移；
- 网络：边缘网络的可靠性和带宽限制；
- 管理：边缘节点的资源管理与边缘应用生命周期管理；
- 扩展：高度分布和大规模的可扩展性；
- 异构：边缘异构硬件和通信协议。



# 2. Kubernetes

Kubernetes已经成为云原生的标准，并且能够在任何基础设施上提供一致的云上体验。

Kubernetes的优点：

- 容器的轻量化和可移植性非常适合边缘计算的场景；
- Kubernetes已经被证明具备良好的可扩展性；
- 能够跨底层基础设施提供一致的体验；
- 同时支持集群和单机运维模式；
- Workload抽象，例如：Deployment和Job等；
- 应用的滚动升级和回滚；
- 围绕Kubernetes已经形成了一个强大的云原生技术生态圈，诸如：监控、日志、CI、存储、网络都能找到现成的工具链；
- 支持异构的硬件配置（存储、CPU、GPU等）；
- 用户可以使用熟悉的kubectl或者helm chart把IoT应用从云端推到边缘；
- 边缘节点可以直接映射成Kubernetes的Node资源，而Kubernetes的扩展 API（CRD）可以实现对边缘设备的抽象。



Kubernetes 在边缘计算方面的不足：

- 网络断连时，节点异常或重启时，内存数据丢失，业务容器无法恢复;
- 网络长时间断连，云端控制器对业务容器进行驱逐;
- 长时间断连后网络恢复时，边缘和云端数据的一致性保障；

- 很多设备边缘的资源规格有限，特别是CPU处理能力较弱，因此无法部署完整的Kubernetes；
- 它非常依赖list/watch机制，不支持离线运行，而边缘节点的离线又是常态，例如：设备休眠重启；
- 特殊的网络协议和拓扑要求。设备接入协议往往非TCP/IP协议，例如，工业物联网的Modbus和OPC UA，消费物联网的Bluetooth和ZigBee等；



# 3. KubeEdge

KubeEdge是首个基于Kubernetes扩展的，提供云边协同能力的开放式智能边缘平台，也是CNCF在智能边缘领域的首个正式项目。

KubeEdge重点要解决的问题：

- 云边协同
- 资源异构
- 大规模
- 轻量化
- 一致的设备管理和接入体验



## 3.1 架构

KubeEdge架构分三层：云端、边缘和设备层。

![kubeedge-arch](.\images\kubeedge-arch.png)



**云端**：k8s-master 运行在云端，用户可通过kubectl命令行在云端管理边缘节点、设备和应用

- **cloud-hub**：接收 edge-hub 同步到云端的信息
- **edge-controller**：用于控制Kubernetes API Server与边缘的节点、应用和配置的状态同步



**边缘**：

- edged：是个重新开发的轻量化Kubelet，实现Pod，Volume，Node等Kubernetes资源对象的生命周期管理;
- metamanager：负责本地元数据的持久化，是边缘节点自治能力的关键;
- edgehub：多路复用的消息通道，提供可靠和高效的云边信息同步;
- devicetwin：用于抽象物理设备并在云端生成一个设备状态的映射;
- eventbus：订阅来自于MQTT Broker的设备数据。



## 3.2 网络

KubeEdge 边云网络访问依赖EdgeMesh：

![img](.\images\edge-mesh.png)

云端是标准的Kubernetes集群，可以使用任意CNI网络插件，比如Flannel、Calico。可以部署任意Kubernetes原生组件，比如kubelet、kube-proxy；同时云端部署KubeEdge云上组件CloudCore，边缘节点上运行KubeEdge边缘组件EdgeCore，完成边缘节点向云上集群的注册。



EdgeMesh 的两个组件：

**EdgeMesh-Server：**

- 运行在云上节点，具有一个公网IP，监听来自EdgeMesh-Agent的连接请求，并协助EdgeMesh-Agent之间完成UDP打洞，建立P2P连接
- 在EdgeMesh-Agent之间打洞失败的情况下，负责中继EdgeMesh-Agent之间的流量，保证100%的流量中转成功率

**EdgeMesh-Agent：**

- DNS模块：内置的轻量级DNS Server，完成Service域名到ClusterIP的转换。
- Proxy模块：负责集群的Service服务发现与ClusterIP的流量劫持。
- Tunnel模块：在启动时，会建立与EdgeMesh-Server的长连接，在两个边缘节点上的应用需要通信时，会通过EdgeMesh-Server进行UDP打洞，尝试建立P2P连接，一旦连接建立成功，后续两个边缘节点上的流量不需要经过EdgeMesh-Server的中转，进而降低网络时延。



## 3.3 部署模型

![img](.\images\kubeedge-deploy-model.png)



# 4. K3S

## 4.1 架构

![img](.\images\k3s-arch.png)

基于一个特定版本Kubernetes直接做了代码修改。架构分为两部分：

- Server：Kubernetes管理面组件 + SQLite和Tunnel Proxy
- Agent：Kubernetes的数据面 + Tunnel Proxy



K3S 对原生 Kubernetes 代码做了以下几个方面的修改：

- 删除旧的、非必须的代码。K3S不包括任何非默认的、Alpha或者过时的Kubernetes功能。除此之外，K3S还删除了所有非默认的Admission Controller，in-tree的cloud provider和存储插件;
- 整合打包进程。为了节省内存，K3S将原本以多进程方式运行的Kubernetes管理面和数据面的多个进程分别合并成一个来运行;
- 使用containderd替换Docker，显著减少运行时占用空间;
- 引入SQLite代替etcd作为管理面数据存储，并用SQLite实现了list/watch接口，即Tunnel Proxy;
- 加了一个简单的安装程序。K3S的所有组件(包括Server和Agent)都运行在边缘，因此不涉及云边协同。如果K3S要落到生产，在K3S之上应该还有一个集群管理方案负责跨集群的应用管理、监控、告警、日志、安全和策略等。



## 4.2 部署模型

![img](.\images\k3s-deploy-model.png)



# 5. KubeEdge 和 K3S 对比

相关对比如下：

| 项目             | KubeEdge   | K3s            |
| :--------------- | :--------- | :------------- |
| 是否CNCF项目     | 是         | 是             |
| 开源时间         | 2018.11    | 2019.2         |
| 架构             | 云管边     | 边缘托管       |
| 边缘自治能力     | 支持       | 暂无           |
| 云边协同         | 支持       | 依赖多集群管理 |
| 原生运维监控能力 | 部分支持   | 支持           |
| 与原生K8s关系    | k8s+addons | 裁剪k8s        |
| iot设备管理能力  | 支持       | octopus        |



**云边协同**:

云边协同是KubeEdge的一大亮点。KubeEdge通过Kubernetes标准API在云端管理边缘节点、设备和工作负载的增删改查。边缘节点的系统升级和应用程序更新都可以直接从云端下发，提升边缘的运维效率。另外，KubeEdge底层优化的多路复用消息通道相对于Kubernetes基于HTTP长连接的list/watch机制扩展性更好，允许海量边缘节点和设备的接入。KubeEdge云端组件完全开源，用户可以在任何公有云/私有云上部署KubeEdge而不用担心厂商锁定，并且自由集成公有云的其他服务。
K3S并不提供云边协同的能力。



**边缘节点离线自治**:

与Kubernetes集群的节点不同，边缘节点需要在完全断开连接的模式下自主工作，并不会定期进行状态同步，只有在重连时才会与控制面通信。此模式与Kubernetes管理面和工作节点通过心跳和list/watch保持状态更新的原始设计非常不同。

KubeEdge通过消息总线和元数据本地存储实现了节点的离线自治。用户期望的控制面配置和设备实时状态更新都通过消息同步到本地存储，这样节点在离线情况下即使重启也不会丢失管理元数据，并保持对本节点设备和应用的管理能力。

K3S也不涉及这方面能力。



**设备管理**:

KubeEdge提供了可插拔式的设备统一管理框架，允许用户在此框架上根据不同的协议或实际需求开发设备接入驱动。当前已经支持和计划支持的协议有：MQTT，BlueTooth，OPC UA，Modbus等，随着越来越多社区合作伙伴的加入，KubeEdge未来会支持更多的设备通信协议。KubeEdge通过device twins/digital twins实现设备状态的更新和同步，并在云端提供Kubernetes的扩展API抽象设备对象，用户可以在云端使用kubectl操作Kubernetes资源对象的方式管理边缘设备。

K3S并不涉及这方面能力。



**轻量化**:

为了将Kubernetes部署在边缘，KubeEdge和K3S都进行了轻量化的改造。区别在于K3S的方向是基于社区版Kubernetes不断做减法（包括管理面和控制面），而KubeEdge则是保留了Kubernetes管理面，重新开发了节点agent。

需要注意的是，K3S在裁剪Kubernetes的过程中导致部分管理面能力的缺失，例如：一些Admission Controller。而KubeEdge则完整地保留了Kubernetes管理面，没有修改过一行代码。

下面我们将从二进制大小、内存和CPU三个维度对比KubeEdge和K3S的资源消耗情况。由于KubeEdge的管理面部署在云端，用户不太关心云端资源的消耗，而K3S的server和agent均运行在边缘，因此下面将对比KubeEdge agent，K3S agent和K3S server这三个不同的进程的CPU和内存的资源消耗。



**大规模**:

Kubernetes原生的可扩展性受制于list/watch的长连接消耗，生产环境能够稳定支持的节点规模是1000左右。KubeEdge作为华为云智能边缘服务IEF的内核，通过多路复用的消息通道优化了云边的通信的性能，压测发现可以轻松支持5000+节点。
而K3S的集群管理技术尚未开源，因为无法得知K3S管理大规模集群的能力。



