# 1. API-Server

## 1.1 核心功能

核心功能：**资源操作入口**

- 提供集群管理的 **REST API 接口**，包括认证授权、准入控制、数据校验以及集群状态变更等
- 其他模块之间的**数据交互和通信的枢纽**。只有 ApiServer 能直接操作 Etcd，其他模块均需要通过它来查询或修改数据

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-api-server.png" alt="img" style="zoom: 67%;" /> 

## 1.2 集群接入

### 1.2.1 集群配置

```bash
$ kubectl config view
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://192.168.80.240:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: cluster-admin
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: cluster-admin
  user:
    client-certificate-data: REDACTED
    client-key-data: REDACTED
```



### 1.2.2 REST API

```bash
# 方式1：kubectl proxy
$ kubectl proxy --port=8081 &

$ curl http://localhost:8081/api/
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "192.168.80.240:6443"
    }
  ]
}

# 方式2：header token
$ kubectl config view -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
https://192.168.80.240:6443

$ kubectl get secrets
NAME                  TYPE                                  DATA   AGE
certification         Opaque                                1      19d
default-token-x77wb   kubernetes.io/service-account-token   3      29d
login-credential      Opaque                                2      19d

$ TOKEN=$(kubectl get secrets default-token-x77wb -o jsonpath='{.data.token}' | base64 --decode)

$ curl --insecure -X GET https://192.168.80.240:6443/api --header "Authorization: Bearer $TOKEN"
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "192.168.80.240:6443"
    }
  ]
}
```



### 1.2.3 client-go

```bash
$ go get k8s.io/client-go@v0.21.4
$ go get k8s.io/apimachinery@v0.21.4
```



```go
func main() {
	config, _ := clientcmd.BuildConfigFromFlags("", "./.kube/config")

	clientset, _ := kubernetes.NewForConfig(config)

	pods, _ := clientset.CoreV1().Pods("").List(context.TODO(), v1.ListOptions{})
	log.Printf("number of pods: %d\n", len(pods.Items))

	for _, pod := range pods.Items {
		log.Println(pod.Name, pod.ClusterName)
	}
}
```



## 1.3 API 资源

```bash
# 所有支持的资源
$ kubectl api-resources
NAME                              SHORTNAMES   APIGROUP                       NAMESPACED   KIND
bindings                                                                      true         Binding
componentstatuses                 cs                                          false        ComponentStatus
configmaps                        cm                                          true         ConfigMap
endpoints                         ep                                          true         Endpoints
events                            ev                                          true         Event
limitranges                       limits                                      true         LimitRange
namespaces                        ns                                          false        Namespace
nodes                             no                                          false        Node
persistentvolumeclaims            pvc                                         true         PersistentVolumeClaim
persistentvolumes                 pv                                          false        PersistentVolume
pods                              po                                          true         Pod
podtemplates                                                                  true         PodTemplate
replicationcontrollers            rc                                          true         ReplicationController
resourcequotas                    quota                                       true         ResourceQuota
secrets                                                                       true         Secret
serviceaccounts                   sa                                          true         ServiceAccount
services                          svc                                         true         Service
mutatingwebhookconfigurations                  admissionregistration.k8s.io   false        MutatingWebhookConfiguration
validatingwebhookconfigurations                admissionregistration.k8s.io   false        ValidatingWebhookConfiguration
customresourcedefinitions         crd,crds     apiextensions.k8s.io           false        CustomResourceDefinition
apiservices                                    apiregistration.k8s.io         false        APIService
controllerrevisions                            apps                           true         ControllerRevision
daemonsets                        ds           apps                           true         DaemonSet
deployments                       deploy       apps                           true         Deployment
replicasets                       rs           apps                           true         ReplicaSet
statefulsets                      sts          apps                           true         StatefulSet
tokenreviews                                   authentication.k8s.io          false        TokenReview
localsubjectaccessreviews                      authorization.k8s.io           true         LocalSubjectAccessReview
selfsubjectaccessreviews                       authorization.k8s.io           false        SelfSubjectAccessReview
selfsubjectrulesreviews                        authorization.k8s.io           false        SelfSubjectRulesReview
subjectaccessreviews                           authorization.k8s.io           false        SubjectAccessReview
horizontalpodautoscalers          hpa          autoscaling                    true         HorizontalPodAutoscaler
cronjobs                          cj           batch                          true         CronJob
jobs                                           batch                          true         Job
certificatesigningrequests        csr          certificates.k8s.io            false        CertificateSigningRequest
leases                                         coordination.k8s.io            true         Lease
endpointslices                                 discovery.k8s.io               true         EndpointSlice
events                            ev           events.k8s.io                  true         Event
ingresses                         ing          extensions                     true         Ingress
ingressclasses                                 networking.k8s.io              false        IngressClass
ingresses                         ing          networking.k8s.io              true         Ingress
networkpolicies                   netpol       networking.k8s.io              true         NetworkPolicy
runtimeclasses                                 node.k8s.io                    false        RuntimeClass
poddisruptionbudgets              pdb          policy                         true         PodDisruptionBudget
podsecuritypolicies               psp          policy                         false        PodSecurityPolicy
clusterrolebindings                            rbac.authorization.k8s.io      false        ClusterRoleBinding
clusterroles                                   rbac.authorization.k8s.io      false        ClusterRole
rolebindings                                   rbac.authorization.k8s.io      true         RoleBinding
roles                                          rbac.authorization.k8s.io      true         Role
priorityclasses                   pc           scheduling.k8s.io              false        PriorityClass
csidrivers                                     storage.k8s.io                 false        CSIDriver
csinodes                                       storage.k8s.io                 false        CSINode
storageclasses                    sc           storage.k8s.io                 false        StorageClass
volumeattachments                              storage.k8s.io                 false        VolumeAttachment

# 获取特定组 apps 的资源
$ kubectl api-resources --api-group apps
kubectl api-resources --api-group apps
NAME                  SHORTNAMES   APIGROUP   NAMESPACED   KIND
controllerrevisions                apps       true         ControllerRevision
daemonsets            ds           apps       true         DaemonSet
deployments           deploy       apps       true         Deployment
replicasets           rs           apps       true         ReplicaSet
statefulsets          sts          apps       true         StatefulSet

# 资源详细解释
$ kubectl explain svc
KIND:     Service
VERSION:  v1

DESCRIPTION:
     Service is a named abstraction of software service (for example, mysql)
     consisting of local port (for example 3306) that the proxy listens on, and
     the selector that determines which pods will answer requests sent through
     the proxy.

FIELDS:
   apiVersion   <string>
     APIVersion defines the versioned schema of this representation of an
     object. Servers should convert recognized schemas to the latest internal
     value, and may reject unrecognized values. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources

   kind <string>
     Kind is a string value representing the REST resource this object
     represents. Servers may infer this from the endpoint the client submits
     requests to. Cannot be updated. In CamelCase. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds

   metadata     <Object>
     Standard object's metadata. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata

   spec <Object>
     Spec defines the behavior of a service.
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status

   status       <Object>
     Most recently observed status of the service. Populated by the system.
     Read-only. More info:
     https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status
     
# 集群支持的API版本
$ kubectl api-versions
admissionregistration.k8s.io/v1
admissionregistration.k8s.io/v1beta1
apiextensions.k8s.io/v1
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1
apiregistration.k8s.io/v1beta1
apps/v1
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
autoscaling/v2beta2
batch/v1
batch/v1beta1
certificates.k8s.io/v1
certificates.k8s.io/v1beta1
coordination.k8s.io/v1
coordination.k8s.io/v1beta1
discovery.k8s.io/v1beta1
events.k8s.io/v1
events.k8s.io/v1beta1
extensions/v1beta1
networking.k8s.io/v1
networking.k8s.io/v1beta1
node.k8s.io/v1beta1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
scheduling.k8s.io/v1
scheduling.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
```



# 2. Controller-Manager

Controller Manager 由 kube-controller-manager 和 cloud-controller-manager 组成，**是 Kubernetes 的大脑**，它通过 apiserver 监控整个集群的状态，并确保集群处于预期的工作状态。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-controller-manager.png) 

Controller Manager作为**集群内部的管理控制中心**，负责集群内的Node、Pod副本、服务端点（Endpoint）、命名空间（Namespace）、服务账号（ServiceAccount）、资源定额（ResourceQuota）的管理，当某个Node意外宕机时，Controller Manager会及时发现并执行自动化修复流程，确保集群始终处于预期的工作状态。



## 2.1 控制器分类

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

**cloud-controller-manager:** 启用 Cloud Provider 时才需要，用来配合云服务提供商的控制

- Node Controller
- Route Controller
- Service Controller



## 2.2 ReplicaSet (RS)

RS 是Replication Controller (RC)的替代者，它使用Deployment管理，比RC更强大

副本控制器，其作用是保证集群中一个RS所关联的Pod副本数始终保持预设值

- 只有当Pod的重启策略`RestartPolicy=Always`时，RS才会管理该Pod的操作（创建、销毁、重启等）
- 创建Pod的RS模板，只在创建Pod时有效，一旦Pod创建完成，模板的变化，不会影响到已创建好的Pod
- 可通过修改Pod的Label，使该Pod脱离RC的管理。该方法可用于Pod从集群中迁移，数据修复等调试
- 删除一个RS不影响它所创建的Pod，如果要删除Pod，需要将RS的副本数属性设置为0
- 不要越过RC创建Pod，因为RS实现了自动化管理Pod，提高容灾能力



### 2.2.1 RS 的职责

- 维护集群中Pod的副本数
- 通过调整RC中的`spec.replicas`属性值来实现系统的扩容或缩容
- 通过改变RC中的Pod模板来实现系统的滚动升级



### 2.2.2 存活探针

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



## 2.3 Node Controller

kubelet 在启动时，会通过API Server注册自身的节点信息，并定时向API Server汇报状态信息；API Server接收到信息后，将信息更新到etcd中。

Controller Manager 在启动时，如果设置了`--cluster-cidr` 参数，对于没有设置`Sepc.PodCIDR`的Node节点生成一个CIDR地址，并用该CIDR地址设置节点的`Spec.PodCIDR`属性，防止不同的节点的CIDR地址发生冲突。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-node-controller.png) 

### 2.3.1 Node Eviction

Node 控制器在节点异常后，会按照默认的速率（`--node-eviction-rate=0.1`，即每10秒一个节点的速率）进行 Node 的驱逐。Node 控制器按照 Zone 将节点划分为不同的组，再跟进 Zone 的状态进行速率调整：

- Normal：所有节点都 Ready，默认速率驱逐。

- PartialDisruption：即超过33% 的节点 NotReady 的状态。当异常节点比例大于`--unhealthy-zone-threshold=0.55`时开始减慢速率：

  - 小集群（即节点数量小于 `--large-cluster-size-threshold=50`）：停止驱逐
  - 大集群，减慢速率为 `--secondary-node-eviction-rate=0.01`

- FullDisruption：所有节点都 NotReady，返回使用默认速率驱逐。但当所有 Zone 都处在 FullDisruption 时，停止驱逐。



## 2.4 ResourceQuota Controller

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

### 2.4.1 Pod 资源限制

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 0.1
            memory: 256Mi
          limits:
            cpu: 0.5
            memory: 512Mi
```

### 2.4.2 名称空间 资源限制

1. 计算资源配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resource
  namespace: spark-cluster
spec:
  hard:
    pods: 20
    requests.cpu: 20
    requests.memory: 100Gi
    limits.cpu: 40
    limits.memory: 200Gi
```

2. 配置对象数量配额限制

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: spark-cluster
spec:
  hard:
    configmaps: 10
    persistentvolumeclaims: 4
    replicationcontrollers: 20
    secrets: 10
    services: 10
    services.loadbalancer: 2
```

3. 配置CPU 和 内存的 LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
spec:
  limits:
  - default:
      memory: 50Gi
      cpu: 5
    defaulyRequest:
      memory: 1Gi
      cpu: 1
    type: Container
```



## 2.5 Namespace Controller

用户通过API Server创建新的Namespace并保存在etcd中，Namespace Controller定时通过API Server 读取这些Namespace信息。

如果Namespace被API标记为优雅删除(即设置删除期限，DeletionTimestamp)，则将该Namespace状态设置为"Terminating"，并保存到etcd中，同时Namespace Controller删除该Namespace下的ServiceAccount, RS, Pod等资源对象。



## 2.6 Endpoint Controller

**Service, Endpoint, Pod的关系：**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-svc-endpoint-pod.png) 

Endpoints 表示一个Service对应的所有Pod副本的访问地址，而Endpoints Controller负责生成和维护所有Endpoints对象的控制器，它负责监听Service和对应的Pod副本变化：

- Service被删除，则删除和该Service同名的Endpoints对象
- Service被创建或修改，则根据该Service信息获得相关的Pod列表，然后创建或更新Service对应的Endpoints对象
- Pod事件，则更它对应的Service的Endpoints对象

**kube-proxy** 进程获取每个Service的Endpoints，实现Service的负载均衡功能



## 2.7 Service Controller

Service Controller 属于kubernetes集群与外部云平台之间的一个接口控制器。它监听Service变化，如果一个LoadBalancer类型的Service，则确保外部的云平台上对该Service对应的Load Balancer实例相应地创建、删除及更新路由转发表。



# 3. Scheduler

Scheduler负责Pod调度，在整个系统中起“承上启下”作用

**承上**：负责接收Controller Manager 创建的新的Pod，并为其选择合适的Node

**启下**：Node上的kubelet接管Pod的生命周期



**Scheduler 集群分发调度器:**

1) 通过调度算法，选择合适的Node，将待调度的Pod在该Node上创建，并将信息写入etcd中

2) kubelet 通过API Server监听到 Scheduler 产生的Pod绑定信息，然后获取对应的Pod清单，下载image，并启动容器

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-scheduler.png)



## 3.1 调度流程

- 预选调度过程：即遍历所有目标Node，筛选出符合要求的候选节点。k8s 内置了多种预选策略(Predicates) 供用户选择
- 确定最优节点：采用优选策略（Priority）计算出每个候选节点的积分，取最高分

调度流程通过插件式加载的**调度算法提供者(Algorithm Provider)** 具体实现，一个调度算法提供者就是包括一组预选策略与一组优选策略的结构体。



## 3.2 预选策略

```
CheckNodeCondition：检查节点是否正常（如ip，磁盘等）
GeneralPredicates
  HostName：检查Pod对象是否定义了pod.spec.hostname
  PodFitsHostPorts：pod要能适配node的端口 pods.spec.containers.ports.hostPort（指定绑定在节点的端口上）
  MatchNodeSelector：检查节点的NodeSelector的标签 pods.spec.nodeSelector
  PodFitsResources：检查Pod的资源需求是否能被节点所满足
NoDiskConflict: 检查Pod依赖的存储卷是否能满足需求（默认未使用）
PodToleratesNodeTaints：检查Pod上的spec.tolerations可容忍的污点是否完全包含节点上的污点
PodToleratesNodeNoExecuteTaints：不能执行（NoExecute）的污点（默认未使用）
CheckNodeLabelPresence：检查指定的标签再上节点是否存在
CheckServiceAffinity：将相同services相同的pod尽量放在一起（默认未使用）
MaxEBSVolumeCount： 检查EBS（AWS存储）存储卷的最大数量
MaxGCEPDVolumeCount GCE存储最大数
MaxAzureDiskVolumeCount: AzureDisk 存储最大数
CheckVolumeBinding：检查节点上已绑定或未绑定的pvc
NoVolumeZoneConflict：检查存储卷对象与pod是否存在冲突
CheckNodeMemoryPressure：检查节点内存是否存在压力过大
CheckNodePIDPressure：检查节点上的PID数量是否过大
CheckNodeDiskPressure： 检查内存、磁盘IO是否过大
MatchInterPodAffinity: 检查节点是否能满足pod的亲和性或反亲和性
```



## 3.3 优选策略

```
LeastRequested： 空闲量越高得分越高
(cpu((capacity-sum(requested))*10/capacity)+memory((capacity-sum(requested))*10/capacity))/2

BalancedResourceAllocation：CPU和内存资源被占用率相近的胜出
NodePreferAvoidPods: 节点注解信息“scheduler.alpha.kubernetes.io/preferAvoidPods”
TaintToleration：将Pod对象的spec.tolerations列表项与节点的taints列表项进行匹配度检查，匹配条目越，得分越低

SeletorSpreading：标签选择器分散度，（与当前pod对象通选的标签，所选其它pod越多的得分越低）
InterPodAffinity：遍历pod对象的亲和性匹配项目，项目越多得分越高
NodeAffinity：节点亲和性 、
MostRequested：空闲量越小得分越高，和LeastRequested相反 （默认未启用）
NodeLabel：节点是否存在对应的标签 （默认未启用）
ImageLocality：根据满足当前Pod对象需求的已有镜像的体积大小之和（默认未启用）
```



## 3.4 调度细节

参看文档：[K8S 集群调度](https://blog.csdn.net/elihe2011/article/details/122078860)



# 4. Kubelet

## 4.1 核心功能

每个Node节点上都运行一个 Kubelet 服务进程，默认监听 10250 端口，接收并执行 Master 发来的指令，管理 Pod 及 Pod 中的容器。每个 Kubelet 进程会在 API Server 上注册所在Node节点的信息，定期向 Master 节点汇报该节点的资源使用情况，并通过 cAdvisor 监控节点和容器的资源。可以把kubelet理解成**Server-Agent** 架构中的agent，是Node上的**Pod管家**。

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kubelet-diagram.png" alt="img" style="zoom: 50%;" />

kubelet 内部组件：

- kubelet API：认证API (10250)，cAdvisor API (4194)，只读 API (10255)，健康检查API (10248)
- syncLoop: 从 API 或者 manifest 目录接收 Pod 跟新，发送到 podWorkers 处理，大量使用 channel 来处理异步请求
- 辅助的 Manager: cAdvisor, PLEG, Volume Manager等，处理 syncLoop 以外的工作
- CRI：容器执行引擎接口，负责与 container runtime shim 通信
- 容器执行引擎：dockershim, rkt等
- 网络插件：CNI， kubenet



## 4.2 Node 管理

节点管理主要是节点自注册和节点状态更新：

- 通过启动参数“-register-node” 来确定是否向API Server注册自己
- 没有选择自注册模式，则需要用户自己配置Node资源信息，同时配置API Server的地址
- 启动时，通过API Server注册节点信息，并定时向API Server发送节点新消息，API Server在接收到新消息后，将信息写入 etcd



主要参数：

- `--kubeconfig`: 指定kubeconfig的路径，该文件常用来指定证书
- `--hostname-override`: 配置该节点在集群中显示的主机名
- `--node-status-update-frequency`:  kubelet向API Server上报心跳的频率，默认10s



**Node 汇总指标：**

```bash
curl http://k8s-master:10255/stats/summary
```



## 4.3 Pod 管理

所有针对 Pod 的操作都将会被 kubelet 监听到，kubelet会根据监听到的指令，创建、修改或删除本节点的Pod。



### 4.3.1 获取 Pod 清单

 kubelet 通过 API Server Client 使用Watch加List的方式，监听 "/registry/csinodes" 和 “/registry/pods” 目录，将获取到的信息同步到本地缓存中

```bash
$ alias etcdctl='etcdctl --cacert=/etc/kubernetes/pki/ca.pem --cert=/etc/kubernetes/pki/etcd.pem --key=/etc/kubernetes/pki/etcd-key.pem'

$ etcdctl get /registry/csinodes --prefix --keys-only
/registry/csinodes/k8s-master
/registry/csinodes/k8s-node01
/registry/csinodes/k8s-node02

# 节点详细信息
$ etcdctl get /registry/csinodes/k8s-master
/registry/csinodes/k8s-master
k8s

storage.k8s.io/v1CSINode⚌
⚌

k8s-master"*$44b1f1da-80fd-47e8-94e7-2f60a627efbf2⚌⚌⚌bD
,storage.alpha.kubernetes.io/migrated-pluginskubernetes.io/cinderj<
Node
k8s-master"$c70e06df-a676-47ca-a1ef-04250601ca7c*v1z⚌⚌
kubeletUpdatestorage.k8s.io/v⚌⚌⚌FieldsV1:⚌
⚌{"f:metadata":{"f:annotations":{".":{},"f:storage.alpha.kubernetes.io/migrated-plugins":{}},"f:ownerReferences":{".":{},"k:{\"uid\":\"c70e06df-a676-47ca-a1ef-04250601ca7c\"}":{".":{},"f:apiVersion":{},"f:kind":{},"f:name":{},"f:uid":{}}}}}"

# pods信息
$ etcdctl get /registry/pods --prefix --keys-only
/registry/pods/kube-system/coredns-867bfd96bd-264bb
/registry/pods/kube-system/kube-flannel-ds-48kz2
/registry/pods/kube-system/kube-flannel-ds-bsfpp
/registry/pods/kube-system/kube-flannel-ds-h5shb
/registry/pods/kube-system/kube-flannel-ds-qpvlt
/registry/pods/kubernetes-dashboard/dashboard-metrics-scraper-79c5968bdc-62hlk
/registry/pods/kubernetes-dashboard/kubernetes-dashboard-9f9799597-b8hfr
```



### 4.3.2 Pod 创建流程

<img src="https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-pod-start-procedure.png" alt="img" style="zoom: 80%;" /> 

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



### 4.3.3 容器状态检查

Pod 通过两类探针检查容器的监控状态：

- **LivenessProbe**: 生存检查。如果检查到容器不健康，则删除该容器，并根据容器的重启策略做响应处理。
- **ReadinessProbe**: 就绪检查。如果检查的容器未就绪，将删除关联 Service 的 Endpoints 中关联条目。



LivenessProbe 的三种实现方式：

- **ExecAction**：容器中执行命令，如果命令退出状态码是0，则表示容器健康
- **TCPSocketAction**: 通过容器的 IP:PORT 执行 TCP 检查，如果端口能够被访问，则表示容器健康
- **HTTPGetAction**：通过容器的 http://IP:PORT/path 调用HTTP GET方法，如果响应状态码表示成功(2xx, 3xx)，则认为容器健康



### 4.3.4 Static Pod

**所有以非 API Server 方式创建的 Pod 都叫 Static Pod**。Kubelet 将 Static Pod 的状态汇报给 API Server，API Server 为该 Static Pod 创建一个 Mirror Pod 和其相匹配。Mirror Pod 的状态将真实反映 Static Pod 的状态。当 Static Pod 被删除时，与之相对应的 Mirror Pod 也会被删除。



## 4.4 cAdvisor 资源监控

资源监控级别：容器，Pod，Service，整个集群

Heapster: 为k8s提供了一个级别的监控平台，它是集群级别的监控和事件数据集成器(Aggregator)。它以Pod方式运行在集群中，并通过 kubelet 发现所有运行在集群中的节点，查看来自这些节点的资源使用情况。kubelet 通过 cAdvisor 获取其所在节点即容器的数据。Heapster通过带着关联标签的 Pod 分组信息，它们被推送到一个可配置的后端，用于存储和可视化展示。

cAdvisor: 一个开源的分析容器资源使用率和性能特征的代理工具，集成到 kubelet，当 kubelet 启动时会同时启动 cAdvisor，且一个cAdvidsor 只监控一个Node节点的信息。cAdvisor 自动查找所有在其节点上的容器，自动采集 CPU、内存、文件系统和网络使用的统计信息。cAdvisor 通过它所在节点的 Root 容器，采集并分析该节点的全面使用情况。

cAdvisor 通过其所在节点的 4149 端口暴露一个简单的 UI。





## 4.5 Eviction

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



## 4.6 容器运行时

容器运行时 (Container Runtime)，负责真正管理镜像和容器的生命周期。kubelet 通过容器运行时接口 (Container Runtime Interface, CRI) 与容器运行时交互，以管理镜像和容器。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-cri-diagram.png)

CRI 容器引擎：

- Docker：dockershim
- OCI (Open Container Initiative) 开放容器标准
  - Containerd
  - CRI-O
  - runc, OCI 标准容器引擎
- PouchContainer：阿里巴巴开源的胖容器引擎



# 5. Kube-proxy

## 5.1 核心功能

kube-proxy 监听 API server 中 service 和 endpoint 的变化情况，并通过 userspace、iptables、ipvs 或 winuserspace 等 proxier 来为服务配置**负载均衡**（仅支持 TCP & UDP）

kube-proxy 可以直接运行在物理机上，也可以以 static pod 或者daemonset的方式运行

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-diagram.png) 

kube-proxy 的实现：

- userspace： 早期方案，它在用户空间监听一个端口，所有服务通过 iptables 转发到这个端口，然后再其内部负载均衡器到实际的Pod。该方式最主要的问题时效率低，有明显的性能瓶颈。

- iptables: 推荐方案，完全以iptables规则的方式来实现 service 负载均衡。该方式的最主要问题是创建了太多的 iptables 规则，非增量式更新会引入一定的时延，大规模情况下有明显的性能问题

- ipvs: 解决了 iptables 的性能问题，采用增量式更新，可以保证 service 更新期间连接保持不断开

  ```bash
  # ipvs 模式需要加载内核模块
  modprobe -- ip_vs
  modprobe -- ip_vs_rr
  modprobe -- ip_vs_wrr
  modprobe -- ip_vs_sh
  modprobe -- nf_conntrack_ipv4
  
  # to check loaded modules, use
  lsmod | grep -e ip_vs -e nf_conntrack_ipv4
  
  # or
  cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4
  ```

  

## 5.2 Iptables 示例

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-iptables.png) 



## 5.3 ipvs 示例

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-ipvs.png) 



## 5.4 kube-proxy 的不足

只支持 TCP 和 UDP，不支持 HTTP 路由，也没有健康检查机制。这些可以通过自定义 [Ingress Controller](https://feisky.gitbooks.io/kubernetes/content/plugins/ingress.html) 的方法来解决。

























