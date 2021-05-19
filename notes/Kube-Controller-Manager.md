# 1. 简介

**内部管理控制中心**

Controller Manager 由 kube-controller-manager 和 cloud-controller-manager 组成，**是 Kubernetes 的大脑**，它通过 apiserver 监控整个集群的状态，并确保集群处于预期的工作状态。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-controller-manager.png) 

Controller Manager作为集群内部的管理控制中心，负责集群内的Node、Pod副本、服务端点（Endpoint）、命名空间（Namespace）、服务账号（ServiceAccount）、资源定额（ResourceQuota）的管理，当某个Node意外宕机时，Controller Manager会及时发现并执行自动化修复流程，确保集群始终处于预期的工作状态。



## 1.1 控制器分类

kube-controller-manager 由一系列的控制器组成

- Replication Controller
- Node Controller
- CronJob Controller
- Daemon Controller
- Deployment Controller
- Endpoint Controller
- Garbage Collector
- Namespace Controller
- Job Controller
- Pod AutoScaler
- RelicaSet
- Service Controller
- ServiceAccount Controller
- StatefulSet Controller
- Volume Controller
- Resource quota Controller

cloud-controller-manager 在 Kubernetes 启用 Cloud Provider 的时候才需要，用来配合云服务提供商的控制，也包括一系列的控制器，如

- Node Controller
- Route Controller
- Service Controller



## 1.2 Node Eviction

Node 控制器在节点异常后，会按照默认的速率（`--node-eviction-rate=0.1`，即每10秒一个节点的速率）进行 Node 的驱逐。Node 控制器按照 Zone 将节点划分为不同的组，再跟进 Zone 的状态进行速率调整：

- Normal：所有节点都 Ready，默认速率驱逐。

- PartialDisruption：即超过33% 的节点 NotReady 的状态。当异常节点比例大于`--unhealthy-zone-threshold=0.55`时开始减慢速率：

  - 小集群（即节点数量小于 `--large-cluster-size-threshold=50`）：停止驱逐
  - 大集群，减慢速率为 `--secondary-node-eviction-rate=0.01`
  
- FullDisruption：所有节点都 NotReady，返回使用默认速率驱逐。但当所有 Zone 都处在 FullDisruption 时，停止驱逐。



# 2. Replication Controller (RC)

简称RC，即副本控制器，它的作用是保证集群中一个RC所关联的Pod副本数始终保持预设值

- 只有当Pod的重启策略`RestartPolicy=Always`时，RC才会管理该Pod的操作（创建、销毁、重启等）
- 创建Pod的RC模板，只在创建Pod时有效，一旦Pod创建完成，模板的变化，不会影响到已创建好的Pod
- 可通过修改Pod的Label，使该Pod脱离RC的管理。该方法可用于Pod从集群中迁移，数据修复等调试
- 删除一个RC不影响它所创建的Pod，如果要删除Pod，需要将RC的副本数属性设置为0
- 不要越过RC创建Pod，因为RC实现了自动化管理Pod，提高容灾能力



## 2.1 RC 的职责

- 维护集群中Pod的副本数
- 通过调整RC中的`spec.replicas`属性值来实现系统的扩容或缩容
- 通过改变RC中的Pod模板来实现系统的滚动升级



## 2.2 存活探针

Kubemetes有以下三种探测容器的机制：

- HTTPGET探针：对容器的地址`http://ip:port/path`执行HTTPGET请求
  - 成功：探测器收到响应，且响应状态码不代表错误（2xx、3xx)
  - 失败：未收到响应，或收到错误响应状态码
- TCP套接字探针：尝试与容器指定端口建立TCP连接。如果连接成功建立，则探测成功；否则，容器重新启动。
- Exec探针：在容器内执行任意命令，并检查命令的退出状态码。如果状态码是0, 则探测成功；其他状态码都被认为失败。

```yaml
spec:
  containers:
    - name: nginx
      image: nginx:latest
      # 一个基于HTTP GET的存活探针
      livenessProbe:
        # 第一次检测在容器启动15秒后
        initialDelaySeconds: 15
        httpGet:
          port: 8080
          path: /
```



## 2.3 ReplicaSet (RS)

RS 是RC的替代者，它使用Deployment管理，比RC更强大



# 3. Node Controller

kubelet 在启动时，会通过API Server注册自身的节点信息，并定时向API Server汇报状态信息；API Server接收到信息后，将信息更新到etcd中。

Controller Manager 在启动时，如果设置了`--cluster-cidr` 参数，对于没有设置`Sepc.PodCIDR`的Node节点生成一个CIDR地址，并用该CIDR地址设置节点的`Spec.PodCIDR`属性，防止不同的节点的CIDR地址发生冲突。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-controller.png) 



# 4. ResourceQuota Controller

资源配额管理，确保指定的资源对象在任何适合都不会超量占用系统物理资源。

支持三个级别的资源配置管理：

- 容器级别：对CPU和Memory进行限制
- Pod级别：对一个Pod内所有容器的可用资源进行限制
- Namespace级别：
  - Pod数量
  - RS 数量
  - SVC 数量
  - ResourceQuota 数量
  - Secret 数量
  - 可持有的PV（Persistent Volume）数量

说明：

1. 配额管理通过 Admission Control (准入控制) 来管理
2. Admission Control 提供两针配额约束方式
   - LimitRanger：作用于Pod和Container
   - ResourceQuota：作用于Namespace，限定一个Namespace中的各种资源的使用总额

ResourceQuota Controller流程图：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-resource-quota-controller.png) 



# 5. Namespace Controller

用户通过API Server创建新的Namespace并保存在etcd中，Namespace Controller定时通过API Server 读取这些Namespace信息。

如果Namespace被API标记为优雅删除(即设置删除期限，DeletionTimestamp)，则将该Namespace状态设置为"Terminating"，并保存到etcd中，同时Namespace Controller删除该Namespace下的ServiceAccount, RS, Pod等资源对象。



# 6. Endpoint Controller

**Service, Endpoint, Pod的关系：**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-svc-endpoint-pod.png) 

Endpoints 表示一个Service对应的所有Pod副本的访问地址，而Endpoints Controller负责生成和维护所有Endpoints对象的控制器，它负责监听Service和对应的Pod副本变化：

- Service被删除，则删除和该Service同名的Endpoints对象
- Service被创建或修改，则根据该Service信息获得相关的Pod列表，然后创建或更新Service对应的Endpoints对象
- Pod事件，则更它对应的Service的Endpoints对象

**kube-proxy** 进程获取每个Service的Endpoints，实现Service的负载均衡功能





# 7. Service Controller

Service Controller 属于kubernetes集群与外部云平台之间的一个接口控制器。它监听Service变化，如果一个LoadBalancer类型的Service，则确保外部的云平台上对该Service对应的Load Balancer实例相应地创建、删除及更新路由转发表。





