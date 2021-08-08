# 1. 简介

每个Node节点上都运行一个 Kubelet 服务进程，默认监听 10250 端口，接收并执行 Master 发来的指令，管理 Pod 及 Pod 中的容器。每个 Kubelet 进程会在 API Server 上注册所在Node节点的信息，定期向 Master 节点汇报该节点的资源使用情况，并通过 cAdvisor 监控节点和容器的资源。可以把kubelet理解成【Server-Agent】架构中的agent，是Node上的**Pod管家**。



# 2. 节点管理

节点管理主要是节点自注册和节点状态更新：

- 通过启动参数“-register-node” 来确定是否向API Server注册自己
- 没有选择自注册模式，则需要用户自己配置Node资源信息，同时配置API Server的地址
- 启动时，通过API Server注册节点信息，并定时向API Server发送节点新消息，API Server在接收到新消息后，将信息写入 etcd



主要参数：

- `--kubeconfig`: 指定kubeconfig的路径，该文件常用来指定证书
- `--hostname-override`: 配置该节点在集群中显示的主机名
- `--node-status-update-frequency`:  kubelet向API Server上报心跳的频率，默认10s



# 3. Pod 管理

## 3.1 获取 Pod 清单

 kubelet 通过 API Server Client 使用Watch加List的方式，监听 "/registry/csinodes" 和 “/registry/pods” 目录，将获取到的信息同步到本地缓存中

```bash
etcdctl  get /registry/csinodes --prefix --keys-only
/registry/csinodes/k8s-master1
/registry/csinodes/k8s-master2
/registry/csinodes/k8s-node1
/registry/csinodes/k8s-node2

# 节点详细信息
etcdctl get /registry/csinodes/k8s-master1
/registry/csinodes/k8s-master1
k8s

storage.k8s.io/v1CSINode⚌
⚌

k8s-master1"*$cc45d1d2-dde9-4740-ac49-878a971ef0852⚌⚌⚌j=
Node
    k8s-master1"$5e851f78-5bfc-4acb-b5c3-4a10cf353237*v1z⚌⚌
kubeletUpdatestorage.k8s.io/v⚌⚌⚌FieldsV1:⚌
⚌{"f:metadata":{"f:ownerReferences":{".":{},"k:{\"uid\":\"5e851f78-5bfc-4acb-b5c3-4a10cf353237\"}":{".":{},"f:apiVersion":{},"f:kind":{},"f:name":{},"f:uid":{}}}}}"

# pods信息
etcdctl  get /registry/pods --prefix --keys-only
/registry/pods/kube-system/coredns-867bfd96bd-264bb
/registry/pods/kube-system/kube-flannel-ds-48kz2
/registry/pods/kube-system/kube-flannel-ds-bsfpp
/registry/pods/kube-system/kube-flannel-ds-h5shb
/registry/pods/kube-system/kube-flannel-ds-qpvlt
/registry/pods/kubernetes-dashboard/dashboard-metrics-scraper-79c5968bdc-62hlk
/registry/pods/kubernetes-dashboard/kubernetes-dashboard-9f9799597-b8hfr
```

所有针对 Pod 的操作都将会被 kubelet 监听到，kubelet会根据监听到的指令，创建、修改或删除本节点的Pod。



## 3.2 Pod 创建流程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-pod-start-procedure.png) 

 kubelet 读取监听到的信息，如果是创建或修改 Pod，则执行如下处理：

- 为Pod创建一个数据目录
- 从API Server读取该 Pod 清单
- 为该 Pod 挂载外部卷
- 下载 Pod 用到的 Secret
- 检查节点上是否已运行Pod，如果 Pod 没有容器或 Pause容器 没有启动，则先停止 Pod 里的所有容器进程。如果在Pod中有需要删除的容器，则删除这些容器
- 用 "kubernetes/pause" 镜像为每个Pod创建一个容器。Pause容器用于接管 Pod 中所有其他容器的网络。没创建一个新的Pod，kubelet 都会先创建一个 Pause容器，然后再创建其他容器。
- Pod 中每个容器的处理：
  - 为容器计算一个hash值，然后用容器名字去docker查询对应容器的hash值。若查找到容器，但两者hash值不同，则停止docker中的容器进程，并停止与之管理的Pause容器；若两者相同，则不做任何处理
  - 如果容器被终止了，且容器未指定 restartPolicy，则不做任何处理
  - 调用 Docker Client 下载容器镜像，然后运行容器



## 3.3 容器状态检查

Pod 通过两类探针检查容器的监控状态：

- LivenessProbe: 生存检查。如果检查到容器不健康，则删除该容器，并根据容器的重启策略做响应处理。
- ReadinessProbe: 就绪检查。如果检查的容器未就绪，将删除关联 Service 的 Endpoints 中关联条目。



LivenessProbe 的三种实现方式：

- ExecAction：容器中执行命令，如果命令退出状态码是0，则表示容器健康
- TCPSocketAction: 通过容器的 IP:PORT 执行 TCP 检查，如果端口能够被访问，则表示容器健康
- HTTPGetAction：通过容器的 http://IP:PORT/path 调用HTTP GET方法，如果响应状态码表示成功(2xx, 3xx)，则认为容器健康



## 3.4 Static Pod

所有以非 API Server 方式创建的 Pod 都叫 Static Pod。Kubelet 将 Static Pod 的状态汇报给 API Server，API Server 为该 Static Pod 创建一个 Mirror Pod 和其相匹配。Mirror Pod 的状态将真实反映 Static Pod 的状态。当 Static Pod 被删除时，与之相对应的 Mirror Pod 也会被删除。



# 4. cAdvisor 资源监控

资源监控级别：容器，Pod，Service，整个集群

Heapster: 为k8s提供了一个级别的监控平台，它是集群级别的监控和事件数据集成器(Aggregator)。它以Pod方式运行在集群中，并通过 kubelet 发现所有运行在集群中的节点，查看来自这些节点的资源使用情况。kubelet 通过 cAdvisor 获取其所在节点即容器的数据。Heapster通过带着关联标签的 Pod 分组信息，它们被推送到一个可配置的后端，用于存储和可视化展示。

cAdvisor: 一个开源的分析容器资源使用率和性能特征的代理工具，集成到 kubelet，当 kubelet 启动时会同时启动 cAdvisor，且一个cAdvidsor 只监控一个Node节点的信息。cAdvisor 自动查找所有在其节点上的容器，自动采集 CPU、内存、文件系统和网络使用的统计信息。cAdvisor 通过它所在节点的 Root 容器，采集并分析该节点的全面使用情况。

cAdvisor 通过其所在节点的 4149 端口暴露一个简单的 UI。



# 5. 工作原理

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kubelet-diagram.png)

kubelet 内部组件：

- kubelet API：认证API (10250)，cAdvisor API (4194)，只读 API (10255)，健康检查API (10248)
- syncLoop: 从 API 或者 manifest 目录接收 Pod 跟新，发送到 podWorkers 处理，大量使用 channel 来处理异步请求
- 辅助的 Manager: cAdvisor, PLEG, Volume Manager等，处理 syncLoop 以外的工作
- CRI：容器执行引擎接口，负责与 container runtime shim 通信
- 容器执行引擎：dockershim, rkt等
- 网络插件：CNI， kubenet



# 6. Kubelet Eviction

kubelet 会健康资源的使用情况，并通过驱逐机制防止计算和存储资源耗尽。在驱逐时，Pod中的容器全部停止，并将 PodPhase 设置为 Failed

定期 (housekeeping-interval) 检查系统的资源是否达到了预先配置的驱逐阈值：

| Eviction Signal      | Condition     | Description                                                  |
| -------------------- | ------------- | ------------------------------------------------------------ |
| `memory.available`   | MemoryPressue | `memory.available` := `node.status.capacity[memory]` - `node.stats.memory.workingSet` |
| `nodefs.available`   | DiskPressure  | `nodefs.available` := `node.stats.fs.available`（Kubelet Volume以及日志等） |
| `nodefs.inodesFree`  | DiskPressure  | `nodefs.inodesFree` := `node.stats.fs.inodesFree`            |
| `imagefs.available`  | DiskPressure  | `imagefs.available` := `node.stats.runtime.imagefs.available`（镜像以及容器可写层等） |
| `imagefs.inodesFree` | DiskPressure  | `imagefs.inodesFree` := `node.stats.runtime.imagefs.inodesFree` |

驱逐阈值可以使用百分比，也可以使用绝对值:

```sh
--eviction-hard=memory.available<500Mi,nodefs.available<1Gi,imagefs.available<100Gi
--eviction-minimum-reclaim="memory.available=0Mi,nodefs.available=500Mi,imagefs.available=2Gi"`
--system-reserved=memory=1.5Gi
```

驱逐信号分类：

- 软驱逐 (Soft Eviction): 配合驱逐宽限期 (eviction-soft-grace-period 和 eviction-max-pod-grace-period) 一起使用。系统资源达到软驱逐阈值且超过宽限期之后才会执行驱逐动作
- 硬驱逐 (Hard Eviction): 系统资源达到硬驱逐阈值时理解执行驱逐动作

驱逐动作：

- 回收节点资源
  - 配置了 imagefs 阈值
    - 达到 nodefs 阈值：删除已停止的 Pod
    - 达到 imagefs 阈值：删除未使用的镜像
  - 未配置 imagefs 阈值
    - 达到 nodefs 阈值：先删除已停止的 Pod，后删除未使用的镜像，顺序清理
- 驱逐用户 Pod
  - 驱逐顺序：BestEffort, Burstable, Guaranteed
  - 配置了 imagefs 阈值
    - 达到 nodefs 阈值：基于nodefs用量驱逐 (local volume + logs)
    - 达到 imagefs 阈值：基于imagefs用量驱逐 (容器可写层)
  - 未配置 imagefs 阈值
    - 达到 nodefs 阈值：安装总磁盘使用驱逐 (local volume + logs + 容器可写层)

其他容器和镜像垃圾回收选项：

| 垃圾回收参数                              | 驱逐参数                                | 解释                                       |
| ----------------------------------------- | --------------------------------------- | ------------------------------------------ |
| `--image-gc-high-threshold`               | `--eviction-hard` 或 `--eviction-soft`  | 现存的驱逐回收信号可以触发镜像垃圾回收     |
| `--image-gc-low-threshold`                | `--eviction-minimum-reclaim`            | 驱逐回收实现相同行为                       |
| `--minimum-image-ttl-duration`            |                                         | 由于驱逐不包括TTL配置，所以它还会继续支持  |
| `--maximum-dead-containers`               |                                         | 一旦旧日志存储在容器上下文之外，就会被弃用 |
| `--maximum-dead-containers-per-container` |                                         | 一旦旧日志存储在容器上下文之外，就会被弃用 |
| `--minimum-container-ttl-duration`        |                                         | 一旦旧日志存储在容器上下文之外，就会被弃用 |
| `--low-diskspace-threshold-mb`            | `--eviction-hard` or `eviction-soft`    | 驱逐回收将磁盘阈值泛化到其他资源           |
| `--outofdisk-transition-frequency`        | `--eviction-pressure-transition-period` | 驱逐回收将磁盘压力转换到其他资源           |



# 7. 容器运行时

容器运行时 (Container Runtime)，负责真正管理镜像和容器的生命周期。kubelet 通过容器运行时接口 (Container Runtime Interface, CRI) 与容器运行时交互，以管理镜像和容器。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-cri-diagram.png)

CRI 容器引擎：

- Docker：dockershim
- OCI (Open Container Initiative) 开放容器标准
  - Containerd
  - CRI-O
  - runc, OCI 标准容器引擎
- PouchContainer：阿里巴巴开源的胖容器引擎



# 8. Node 汇总指标

- 集群内部：`curl http://k8s-master1:10255/stats/summary`

- 集群外部：（暂未成功）

  ```bash
  kubectl proxy &
  curl http://localhost:8001/api/v1/proxy/csinodes/k8s-master1:10255/stats/summary
  ```

  



















