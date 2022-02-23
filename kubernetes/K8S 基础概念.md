# 1. 概述

Kubernetes，又称为 k8s（首字母为 k、首字母与尾字母之间有 8 个字符、尾字母为 s，所以简称 k8s）或者简称为 "kube" ，是一种可自动实施 Linux 容器 操作的开源平台。它可以帮助用户省去应用容器化过程的许多手动部署和扩展操作。也就是说，您可以将运行 Linux 容器的多组主机聚集在一起，由 Kubernetes 帮助您轻松高效地管理这些集群。而且，这些集群可跨 **公共云**、**私有云**或**混合云**部署主机。因此，对于要求快速扩展的**云原生应用**而言，Kubernetes 是理想的托管平台。

Kubernetes特点：

- 轻量级：消耗资源小
- 开源
- 弹性伸缩
- 负载均衡：IPVS



# 2. 核心组件

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-diagram.png" alt="img" style="zoom: 67%;" /> 

- **Etcd**： 保存整个集群的状态
- **API Server**： 提供了资源操作的唯一入口，并提供认证、授权、访问控制、API 注册和发现等机制
- **Controller Manager**： 负责维护集群的状态，比如故障检测、自动扩展、滚动更新等
- **Scheduler**: 负责资源的调度，按照预定的调度策略将 Pod 调度到相应的机器上
- **Kubelet**: 负责维护容器的生命周期、Volume(CVI) 和网络(CNI)的管理
- **Container Runtime**: 负责镜像管理以及 Pod 和容器的真正运行（CRI）
- **Kube-proxy**: 负责为Service提供cluster内部的服务发现和负载均衡 （四层）
  - iptables
  - ipvs





# 3. 基本概念

## 3.1 Container

Container 是一种轻量级的操作系统级虚拟化技术。它使用 namespace 隔离不同的软件运行环境，并通过镜像自包含软件的运行环境，从而使得容器可以很方便的在任何地方运行。

由于容器体积小且启动快，因此可以在每个容器镜像中打包一个应用程序。使用容器，不需要与外部的基础架构环境绑定, 因为每一个应用程序都不需要外部依赖，更不需要与外部的基础架构环境依赖。完美解决了从开发到生产环境的一致性问题。



## 3.2 Pod

Pod 是一组紧密关联的容器集合，它们共享 PID、IPC、Network 和 UTS namespace，是 Kubernetes 调度的基本单位。Pod 内的多个容器共享网络和文件系统，可以通过进程间通信和文件共享这种简单高效的方式组合完成服务。

Pod 是K8S最小的调度单位。



## 3.3 Node

Node 是 Pod 真正运行的主机，可以是物理机，也可以是虚拟机。为了管理 Pod，每个 Node 节点上至少要运行 container runtime（比如 docker 或者 rkt）、`kubelet` 和 `kube-proxy` 服务。

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-pod.png" alt="img" style="zoom:50%;" /> 



## 3.4 Namespace

Namespace 是**对一组资源和对象的抽象集合**，可以用来将系统内部的对象划分为不同的项目组或用户组。常见的 pods, services, replication controllers 和 deployments 等都是属于某一个 namespace 的（默认是 default），而 node, persistentVolumes 等则不属于任何 namespace。

名称空间通常用于实现租户或项目的资源隔离，从而形成逻辑分组。



## 3.5 Service

**Service 是应用服务的抽象，通过 labels 为应用提供负载均衡和服务发现**。匹配 labels 的 Pod IP 和端口列表组成 endpoints，由 kube-proxy 负责将服务 IP 负载均衡到这些 endpoints 上。

每个 Service 都会自动分配一个 cluster IP（仅在集群内部可访问的虚拟地址）和 DNS 名，其他容器可以通过该地址或 DNS 来访问服务，而不需要了解后端容器的运行。

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-service.png" alt="img" style="zoom:50%;" /> 



## 3.6 Label

标签（Label）是将资源进行分类的标识符。资源标签具体化的就是一个键值型（key/values)数据，使用标签是为了对指定对象进行辨识，比如Pod对象。标签可以在对象创建时进行附加，也可以创建后进行添加或修改。要知道的是一个对象可以有多个标签，一个标签页可以附加到多个对象。

Label 不提供唯一性，并且实际上经常是很多对象（如 Pods）都使用相同的 label 来标志具体的应用。

Label 定义好后其他对象可以使用 Label Selector 来选择一组相同 label 的对象（比如 ReplicaSet 和 Service 用 label 来选择一组 Pod）。Label Selector 支持以下几种方式：

- 等式，如 `app=nginx` 和 `env!=production`
- 集合，如 `env in (production, qa)`
- 多个 label（ AND 关系），如 `app=nginx,env=test`



## 3.7 Annotations

Annotation是另一种附加在对象上的一种键值类型的数据，常用于将各种非标识型元数据（metadata）附加到对象上，但它并不能用于标识和选择对象。**其作用是方便工具或用户阅读及查找**。比如用来记录一些附加信息，用来辅助应用部署、安全策略以及调度策略等。 deployment 使用 annotations 来记录 rolling update 的状态。



## 3.8 Volume

存储卷（Volume）是独立于容器文件系统之外的存储空间，常用于扩展容器的存储空间并为其提供持久存储能力。存储卷在K8S中的分类为：临时卷、本地卷和网络卷。临时卷和本地卷都位于Node本地，一旦Pod被调度至其他Node节点，此类型的存储卷将无法被访问，因为临时卷和本地卷通常用于数据缓存，持久化的数据通常放置于持久卷（persistent volume）之中。



## 3.9 Ingress

K8S将Pod对象和外部的网络环境进行了隔离，Pod和Service等对象之间的通信需要通过内部的专用地址进行，如果需要将某些Pod对象提供给外部用户访问，则需要给这些Pod对象打开一个端口进行引入外部流量，除了Service以外，Ingress也是实现提供外部访问的一种方式。





# 4. 资源清单

k8s中，所有的内容都被抽象为资源，资源实例化后，称为对象

集群资源分类：

- 名称空间级别: 只在本名称空间下可见
- 集群级别: role, 不管在什么名称空间小，均可见
- 元数据级别: HPA(可以CPU利用率平滑扩展)



## 4.1 工作负载

- Pod: 最小资源，共享网络栈、存储卷等

- ReplicaSet：调度器，管理Pod的创建，通过标签的选择去控制Pod的副本数

- Deployment: 控制器，通过控制RS的创建，去创建Pod

- StatefulSet：有状态服务管理器

- DaemonSet：可在每个节点都运行一个Pod组件

- Job: 批量工作

- CronJob: 定时或轮训工作

  

## 4.2 服务发现及负载均衡

- Service
- Ingress



## 4.3 配置与存储

- Volume: 存储卷
- CSI: 容器存储接口，可扩展第三方存储设备

- ConfigMap: 配置中心
- Secret: 敏感数据保存
- DownwardAPI: 外部环境中的信息输出给容器



## 4.4 集群

不指定名称空间，所有节点均能访问：role

- Namespace
- Node
- Role
- ClusterRole
- RoleBinding
- ClusterRoleBinding



## 4.5 元数据

- HPA
- PodTemplate
- LimitRange



# 5. 网络

## 5.1 三层网络

![network](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-network-3-layer.png)

- 节点网络：各主机（Master、Node、ETCD等）自身所属的网络，地址配置在主机的网络接口，用于各主机之间的通信，又称为节点网络。
- Pod网络：专用于Pod资源对象的网络，它是一个虚拟网络，用于为各Pod对象设定IP地址等网络参数，其地址配置在Pod中容器的网络接口上。Pod网络需要借助kubelet插件或CNI插件实现。
- Service网络：专用于Service资源对象的网络，它也是一个虚拟网络，用于为K8S集群之中的Service配置IP地址，但是该地址不会配置在任何主机或容器的网络接口上，而是通过Node上的kube-proxy配置为iptables或ipvs规则，从而将发往该地址的所有流量调度到后端的各Pod对象之上。



## 5.2 网络的通信方式

- 同一个Pod内部：共享同一个网络命名空间，共享同一个Linux协议栈，即lo网卡
- Pod1至Pod2:
  - 同一台主机：由 cni0 网桥转发，不需要经过Flannel等网络插件
  - 不同主机：将Pod的IP和Node的IP关联起来，通过这个关联让Pod可以相互访问。涉及网络封包和拆包，较消耗资源。
- Pod至Service网络：kube-proxy，使用iptables/IPVS维护和转发
- Pod到外网：Pod向外网发送请求，查找路由表，转发数据包到宿主机的网卡，宿主机网卡完成路由选择后，iptables执行Masquerade，把源IP更改为宿主网卡的IP，然后向外网服务器发送请求
- 外网访问Pod：Service



## 5.3 通信端口

Pod Template中的ports: 

- containerPort: 容器对外开发的端口

Service 中的 ports:

- port: 监听请求，接收端口，绑定在ClusterIP上
- targetPort: 指定Pod的接收端口，与containerPort绑定
- nodePort: 类型为NodeType时，绑定在NodeIP上，未指定则随机给一个





