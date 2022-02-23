# 1. 集群调度

k8s 调度器 scheduler，它以独立的程序允许，启动后和一直和 APIServer 连接，获取 `PodSpec.NodeName` 为空的 pod， 然后将其 binding 调度到合适的的节点上。需考虑如下问题：

- **公平**： 如何确保每个节点都被分配
- **资源高利用率**：集群资源最大化被使用
- **效率**：调度性能要好，能够快速完成大批量的 pod 调度
- **灵活**：允许用户个性化调度需求



# 2. 调度过程

**总结：预选 + 优选**

## 2.1 Predicate 预选

作用：**首先过滤掉不满足条件的节点**

过程：如果在 predicate 过程中没有合适的节点，pod 会一直在 pending 状态，不断重试调度，直到有节点满足条件

Predicate 算法：

- PodFitsResources: 节点资源满足 pod 的请求资源
- PodFitsHost: 节点名称和 Pod 指定的 NodeName 一致
- PodFitsHostPorts:  pod 申请的 port 在节点上未被占用
- PodSelectorMatches: 节点的label 要与 pod指定的一致
- NoDiskConflict: 已挂载的 volume 和 pod 指定的不冲突，除非它们都是只读的



## 2.2 Priorities 优选

作用：多个节点同时满足条件，**按照优选级大小对节点排序**

优先级选项：

- LeastRequestedPriority: 计算 CPU 和 Memory 的使用率来决定权重，使用率越低权重越高
- BalancedResourceAllocation: CPU 和 Memory 的使用率接近，权重越高。通常和上一个一起使用
- ImageLocalityPriority: 本地已下载镜像，镜像总大小越大，权重越高



# 3. 调度亲和性

## 3.1 node亲和性

`pod.spec.affinity.nodeAffinity`:

- preferredDuringSchedulingIgnoredDuringExecution: 软策略
- requiredDuringSchedulingIgnoredDuringExecution: 硬策略

```bash
# 获取节点 label
kubectl get nodes --show-labels

# 设置节点 label
kubectl label nodes k8s-node01 disktype=ssd
```



```yaml
apiVersion: v1
kind: Pod
metadata: 
  name: node-affinity
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "sleep 600"]
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: NotIn
            values:
            - k8s-node02
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```



## 3.2 pod 亲和性

用途：解决 pod 可以和哪些 pod 部署在同一个 **拓扑域** 问题

`pod.spec.affinity.podAffinity/PodAntiAffinity`:

- preferredDuringSchedulingIgnoredDuringExecution: 软策略
- requiredDuringSchedulingIgnoredDuringExecution: 硬策略



```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-affinity
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "sleep 600"]
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - pod-1
        topologyKey: kubernetes.io/hostname
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - pod-2
          topologyKey: kubernetes.io/hostname
```

```bash
$ kubectl get pod
NAME            READY   STATUS    RESTARTS   AGE
node-affinity   1/1     Running   0          9m22s
pod-affinity    0/1     Pending   0          10s

# 注意node-affinity必须是running的，否则即使修改了的label满足条件，也不会创建
$ kubectl label pod node-affinity app=pod-1 --overwrite=true
pod/node-affinity labeled

$ kubectl get pod --show-labels
NAME            READY   STATUS    RESTARTS   AGE   LABELS
node-affinity   1/1     Running   2          24m   app=pod-1
pod-affinity    1/1     Running   0          81s   <none>
```



## 3.3 调度策略对比

| 调度策略        | 匹配标签 | 操作符                                  | 拓扑域支持 | 调度目标                |
| --------------- | -------- | --------------------------------------- | ---------- | ----------------------- |
| nodeAffinity    | Node     | In, NotIn, Exists, DoesNotExist, Gt, Lt | No         | 指定主机                |
| podAffinity     | Pod      | In, NotIn, Exists, DoesNotExist         | Yes        | 指定Pod在同一个拓扑域   |
| podAntiAffinity | Pod      | In, NotIn, Exists, DoesNotExist         | Yes        | 指定Pod不在同一个拓扑域 |



## 3.4 示例：同节点调度

相同类型pod，不在同一个节点上调度；不同类型的pod，关联调度到同一节点

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
spec:
  selector:
    matchLabels:
      app: store
  replicas: 3
  template:
    metadata:
      labels:
        app: store
    spec:
      containers:
      - name: redis-server
        image: redis:5.0.14-alpine3.15
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - store
            topologyKey: "kubernetes.io/hostname"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
spec:
  selector:
    matchLabels:
      app: web-store
  replicas: 3
  template:
    metadata:
      labels:
        app: web-store
    spec:
      containers:
      - name: web-app
        image: nginx:1.20.2-alpine
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web-store
            topologyKey: "kubernetes.io/hostname"
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - store
            topologyKey: "kubernetes.io/hostname"
```



# 4. 污点和容忍

- 亲和性：Pod的一种偏好或硬性要求，它使 Pod 能被吸引到一类特定的节点

- 污点：与亲和性相反，它使节点能够排斥一类特定的Pod
  - Taint：用来避免pod节点被分配到不合适的节点上

  - Toleration：表示pod可以(容忍)被分配到Taint节点上

## 4.1 Taint

污点的作用，支持三种策略：

- NoSchedule: 不调度
- PreferNoSchedule: 避免调度
- NoExecute: 不调度，且驱离已存在的Pod

```bash
# 设置污点
$ kubectl taint node k8s-node01 key1=value1:NoSchedule

# 查看污点
$ kubectl describe node k8s-node01 | grep -i taint
Taints:             key1=value1:NoSchedule

# 去除污点
$ kubectl taint node k8s-node01 key1=value1:NoSchedule-
```



## 4.2 Toleration

容忍污点的存在，可以被调度到存在污点的节点上

`pod.spec.tolerations`

```yaml
tolerations:
# 容忍key1-value1:NoSchedule污点，且驱离前保留3600s
- key: key1
  operator: Equal
  value: value1
  effect: NoSchedule
  tolerationSeconds: 3600

# 容忍key2-value2:NoExecute污点
- key: key2
  operator: Equal
  value: value2
  effect: NoExecute
  
# 容忍key3:NoSchedule污点
- key: key3
  operator: Exists
  effect: NoSchedule
  
# 容忍key4的所有污点，operator等于 Exists 时，忽略value值
- key: key4
  operator: Exists
  
# 容忍所有key的所有污点
- operator: Exists
```



多 master 节点时，可开启一些节点调度：

```bash
$ kubectl describe node k8s-master2 | grep -i taint
Taints:             node-role.kubernetes.io/master:NoSchedule

$ kubectl taint nodes k8s-master2 node-role.kubernetes.io/master=:NoSchedule-

$ kubectl taint nodes k8s-master2 node-role.kubernetes.io/master=:PreferNoSchedule
```



示例：

```yaml
# taint-toleration.yml
apiVersion: v1
kind: Pod
metadata: 
  name: pod-1
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "sleep 600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "sleep 600"]
  tolerations:
  - key: kickoff
    operator: Equal
    value: test
    effect: NoSchedule
```



```bash
# 节点都打上污点标识
$ kubectl taint nodes k8s-node01 kickoff=test:NoSchedule
$ kubectl taint nodes k8s-node02 kickoff=test:NoSchedule

$ kubectl apply -f taint-toleration.yml

$ kubectl  get pod -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
pod-1   0/1     Pending   0          58s   <none>        <none>       <none>           <none>
pod-2   1/1     Running   0          58s   10.244.2.55   k8s-node02   <none>           <none>

# 去除污点
$ kubectl taint nodes k8s-node01 kickoff=test:NoSchedule-

# 不再Pending
$ kubectl  get pod -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
pod-1   1/1     Running   0          2m    10.244.1.40   k8s-node01   <none>           <none>
pod-2   1/1     Running   0          2m    10.244.2.55   k8s-node02   <none>           <none>
```



# 5. 指定节点

- 会跳过Scheduler的调度策略
- 该匹配规则是强制匹配

## 5.1 nodeName

`pod.spec.nodeName`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: 
  name: schedule-nodename
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tools
  template:
    metadata:
      labels:
        app: tools
    spec:
      nodeName: k8s-node02  # 指定节点名称
      containers:
      - name: busybox
        image: busybox
        command: ["/bin/sh", "-c", "sleep 600"]
```

```bash
$ kubectl get pod -o wide
NAME                      READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
schedule-nodename-dbf489fb4-jm8qr   1/1     Running   0          27s     10.244.1.27   k8s-node02   <none>           <none>
schedule-nodename-dbf489fb4-jtps9   1/1     Running   0          27s     10.244.1.26   k8s-node02   <none>           <none>
schedule-nodename-dbf489fb4-jv7fd   1/1     Running   0          27s     10.244.1.28   k8s-node02   <none>           <none>
```



## 5.2 nodeSelector

`pod.spec.nodeSelector`, 通过label-selector机制选择节点，由调度器调度策略匹配label，然后调度到目标节点

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: 
  name: schedule-nodeselector
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      nodeSelector:  # 指定标签
        type: backendNode1
      containers:
      - name: web
        image: busybox
        command: ["/bin/sh", "-c", "sleep 600"]
```

```bash
$ kubectl get pod -o wide
NAME                      READY   STATUS    RESTARTS   AGE
schedule-nodeselector-68b5b454d6-9dlgm   0/1     Pending   0          14s     <none>        <none>       <none>           <none>
schedule-nodeselector-68b5b454d6-prp8t   0/1     Pending   0          14s     <none>        <none>       <none>           <none>

# 给node打标签
$ kubectl label node k8s-node01 type=backendNode1

$ kubectl get pod -o wide
NAME                      READY   STATUS    RESTARTS   AGE     IP            NODE         NOMINATED NODE   READINESS GATES
schedule-nodeselector-68b5b454d6-9dlgm   1/1     Running   0          59s     10.244.0.26   k8s-node01   <none>           <none>
schedule-nodeselector-68b5b454d6-prp8t   1/1     Running   0          59s     10.244.0.27   k8s-node01   <none>           <none>
```