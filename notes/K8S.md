# 1. 基本概念

## 1.1 Container

Container（容器）是一种便携式、轻量级的操作系统级虚拟化技术。它使用 namespace 隔离不同的软件运行环境，并通过镜像自包含软件的运行环境，从而使得容器可以很方便的在任何地方运行。

由于容器体积小且启动快，因此可以在每个容器镜像中打包一个应用程序。这种一对一的应用镜像关系拥有很多好处。使用容器，不需要与外部的基础架构环境绑定, 因为每一个应用程序都不需要外部依赖，更不需要与外部的基础架构环境依赖。完美解决了从开发到生产环境的一致性问题。



## 1.2 Pod

Pod 是一组紧密关联的容器集合，它们共享 PID、IPC、Network 和 UTS namespace，是 Kubernetes 调度的基本单位。Pod 内的多个容器共享网络和文件系统，可以通过进程间通信和文件共享这种简单高效的方式组合完成服务。

Pod 是K8S最小的调度单位。



## 1.3 Node

Node 是 Pod 真正运行的主机，可以是物理机，也可以是虚拟机。为了管理 Pod，每个 Node 节点上至少要运行 container runtime（比如 docker 或者 rkt）、`kubelet` 和 `kube-proxy` 服务。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-pod.png) 



## 1.4 Namespace

Namespace 是**对一组资源和对象的抽象集合**，比如可以用来将系统内部的对象划分为不同的项目组或用户组。常见的 pods, services, replication controllers 和 deployments 等都是属于某一个 namespace 的（默认是 default），而 node, persistentVolumes 等则不属于任何 namespace。

名称空间通常用于实现租户或项目的资源隔离，从而形成逻辑分组。



## 1.5 Service

**Service 是应用服务的抽象，通过 labels 为应用提供负载均衡和服务发现**。匹配 labels 的 Pod IP 和端口列表组成 endpoints，由 kube-proxy 负责将服务 IP 负载均衡到这些 endpoints 上。

每个 Service 都会自动分配一个 cluster IP（仅在集群内部可访问的虚拟地址）和 DNS 名，其他容器可以通过该地址或 DNS 来访问服务，而不需要了解后端容器的运行。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-service.png) 



## 1.6 Label

标签（Label）是将资源进行分类的标识符，就好像超市的商品分类一般。资源标签具体化的就是一个键值型（key/values)数据，使用标签是为了对指定对象进行辨识，比如Pod对象。标签可以在对象创建时进行附加，也可以创建后进行添加或修改。要知道的是一个对象可以有多个标签，一个标签页可以附加到多个对象。

Label 不提供唯一性，并且实际上经常是很多对象（如 Pods）都使用相同的 label 来标志具体的应用。

Label 定义好后其他对象可以使用 Label Selector 来选择一组相同 label 的对象（比如 ReplicaSet 和 Service 用 label 来选择一组 Pod）。Label Selector 支持以下几种方式：

- 等式，如 `app=nginx` 和 `env!=production`
- 集合，如 `env in (production, qa)`
- 多个 label（ AND 关系），如 `app=nginx,env=test`



## 1.7 Annotations

Annotation是另一种附加在对象上的一种键值类型的数据，常用于将各种非标识型元数据（metadata）附加到对象上，但它并不能用于标识和选择对象。其作用是方便工具或用户阅读及查找。比如用来记录一些附加信息，用来辅助应用部署、安全策略以及调度策略等。 deployment 使用 annotations 来记录 rolling update 的状态。



## 1.8 Volume

存储卷（Volume）是独立于容器文件系统之外的存储空间，常用于扩展容器的存储空间并为其提供持久存储能力。存储卷在K8S中的分类为：临时卷、本地卷和网络卷。临时卷和本地卷都位于Node本地，一旦Pod被调度至其他Node节点，此类型的存储卷将无法被访问，因为临时卷和本地卷通常用于数据缓存，持久化的数据通常放置于持久卷（persistent volume）之中。



## 1.9 Ingress

K8S将Pod对象和外部的网络环境进行了隔离，Pod和Service等对象之间的通信需要通过内部的专用地址进行，如果需要将某些Pod对象提供给外部用户访问，则需要给这些Pod对象打开一个端口进行引入外部流量，除了Service以外，Ingress也是实现提供外部访问的一种方式。



# 2. 核心组件

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-diagram.png) 

- etcd 保存了整个集群的状态；
- API Server 提供了资源操作的唯一入口，并提供认证、授权、访问控制、API 注册和发现等机制；
- Controller Manager 负责维护集群的状态，比如故障检测、自动扩展、滚动更新等；
- Scheduler 负责资源的调度，按照预定的调度策略将 Pod 调度到相应的机器上；
- Kubelet 负责维护容器的生命周期，同时也负责 Volume（CVI）和网络（CNI）的管理；
- Container Runtime 负责镜像管理以及 Pod 和容器的真正运行（CRI）；
- Kube-proxy 负责为 Service 提供 cluster 内部的服务发现和负载均衡；



## 2.1 Etcd





## 2.2 API Server

- 提供集群管理的 REST API 接口，包括认证授权、数据校验以及集群状态变更等
- 提供其他模块之间的数据交互和通信的枢纽（其他模块通过 API Server 查询或修改数据，只有 API Server 才直接操作 etcd）











# 3. 网络

K8S集群包含三个网络：

- 节点网络：各主机（Master、Node、ETCD等）自身所属的网络，地址配置在主机的网络接口，用于各主机之间的通信，又称为节点网络。
- Pod网络：专用于Pod资源对象的网络，它是一个虚拟网络，用于为各Pod对象设定IP地址等网络参数，其地址配置在Pod中容器的网络接口上。Pod网络需要借助kubelet插件或CNI插件实现。
- Service网络：专用于Service资源对象的网络，它也是一个虚拟网络，用于为K8S集群之中的Service配置IP地址，但是该地址不会配置在任何主机或容器的网络接口上，而是通过Node上的kube-proxy配置为iptables或ipvs规则，从而将发往该地址的所有流量调度到后端的各Pod对象之上。

































k8s 对象：

| 类别     | 名称                                                         |
| :------- | ------------------------------------------------------------ |
| 资源对象 | Pod、ReplicaSet、ReplicationController、Deployment、StatefulSet、DaemonSet、Job、CronJob、HorizontalPodAutoscaler |
| 配置对象 | Node、Namespace、Service、Secret、ConfigMap、Ingress、Label、CustomResourceDefinition、 ServiceAccount |
| 存储对象 | Volume、Persistent Volume                                    |
| 策略对象 | SecurityContext、ResourceQuota、LimitRange                   |



资源限制与配额：

- Pod 级别：最小的资源调度单位
- Namespace 级别：限制资源配额和每个 Pod 的资源使用区间



