# 1. 简介

Scheduler负责Pod调度，在整个系统中起“承上启下”作用

**承上**：负责接收Controller Manager 创建的新的Pod，并为其选择合适的Node

**启下**：Node上的kubelet接管Pod的生命周期



**Scheduler 集群分发调度器:**

1) 通过调度算法，选择合适的Node，将待调度的Pod在该Node上创建，并将信息写入etcd中

2) kubelet 通过API Server监听到 Scheduler 产生的Pod绑定信息，然后获取对应的Pod清单，下载image，并启动容器

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-scheduler.png)



# 2. 调度流程

- 预选调度过程：即遍历所有目标Node，筛选出符合要求的候选节点。k8s 内置了多种预选策略(Predicates) 供用户选择
- 确定最优节点：采用优选策略（Priority）计算出每个候选节点的积分，取最高分

调度流程通过插件式加载的“调度算法提供者(Algorithm Provider)” 具体实现，一个调度算法提供者就是包括一组预选策略与一组优选策略的结构体。



# 3. 预选策略

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



# 4. 优选策略

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



# 5. 高级调度

## 5.1 `nodeSelector` 

```bash
# 1. 创建 redis 集群
cat > redis-deploy.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  selector:
    matchLabels:
      app: redis
  replicas: 2
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6.2.3
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
      nodeSelector:
        disk: ssd  # 限定磁盘类型
EOF

kubetcl apply -f redis-deploy.yml

# 检查pod状态
kubectl get pod
NAME                   READY   STATUS    RESTARTS   AGE
redis-9fc84569-2jlxh   0/1     Pending   0          60s
redis-9fc84569-q78jd   0/1     Pending   0          60s

kubectl describe pod redis-9fc84569-2jlxh
Events:
  Type     Reason            Age                From               Message
  ----     ------            ----               ----               -------
  Warning  FailedScheduling  20s (x3 over 76s)  default-scheduler  0/4 nodes are available: 4 node(s) didn't match node selector.

# k8s-node2 增加标签 disk=ssd 
kubectl label node k8s-node2 disk=ssd 

kubectl get  nodes --show-labels | grep disk=ssd
k8s-node2     Ready      node     4d21h   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,disk=ssd,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node2,kubernetes.io/os=linux,node-role.kubernetes.io/node=

# 再次检查 pod 是否创建成功
kubectl get pod -o wide
NAME                   READY   STATUS    RESTARTS   AGE     IP           NODE        NOMINATED NODE   READINESS GATES
redis-9fc84569-2jlxh   1/1     Running   0          5m20s   10.244.1.8   k8s-node2   <none>           <none>
redis-9fc84569-q78jd   1/1     Running   0          5m20s   10.244.1.7   k8s-node2   <none>           <none>
```



## 5.2 亲和性 (affinity)

### 5.2.1 `preferredDuringSchedulingIgnoredDuringExecution` 

**软亲和**：选择条件匹配多的，就算都不满足条件，还是会生成pod

```bash
cat > preferred-affinity-pod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: preferred-affinity-pod
  labels:
    app: my-pod
spec:
  containers:
  - name: preferred-affinity-pod
    image: nginx
    ports:
    - name: http
      containerPort: 80
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - preference:
          matchExpressions:
          - key: apps 	# 标签键名
            operator: In
            values:
            - mysql     # apps=mysql
            - redis     # apps=redis
        weight: 60 		# 匹配相应nodeSelectorTerm相关联的权重,1-100
EOF

kubectl apply -f preferred-affinity-pod.yml

# 不满足依旧创建成功
kubectl get pod -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
preferred-affinity-pod   1/1     Running   0          61s   10.244.2.18   k8s-node1   <none>           <none>
```



### 5.2.2 `requiredDuringSchedulingIgnoredDuringExecution ` 

**硬亲和**：选择条件匹配多的，必须满足一项，才会生成pod

```bash
cat > required-affinity-pod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: required-affinity-pod
  labels:
    app: my-pod
spec:
  containers:
  - name: required-affinity-pod
    image: nginx
    ports:
    - name: http
      containerPort: 80
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            - key: apps 	# 标签键名
              operator: In
              values:
                - mysql     # apps=mysql
                - redis     # apps=redis          
EOF

kubectl apply -f required-affinity-pod.yml

# 不满足无法创建成功
kubectl  get pod -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
required-affinity-pod    0/1     Pending   0          18s   <none>        <none>      <none>           <none>

# 修改 k8s-node1 的标签
kubectl label node k8s-node1 apps=mysql 

# 创建成功
kubectl  get pod -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP            NODE        NOMINATED NODE   READINESS GATES
required-affinity-pod    1/1     Running   0          2m31s   10.244.2.19   k8s-node1   <none>           <none>
```



## 5.3 反亲和性

```bash
cat > anti-affinity.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: myapp1
  labels:
    app: myapp1
      
spec:
  containers:
  - name: myapp1
    image: nginx
    ports:
    - name: http
      containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: myapp2
  labels:
    app: myapp2
      
spec:
  containers:
  - name: myapp2
    image: nginx
    ports:
    - name: http
      containerPort: 80
  affinity:
    podAntiAffinity: 
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - myapp1   # app=myapp1
        topologyKey: kubernetes.io/hostname  #kubernetes.io/hostname的值一样代表pod不处于同一位置  
EOF

kubectl apply -f anti-affinity.yml

# 分属不同的节点上
kubectl get pod -o wide
NAME     READY   STATUS    RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
myapp1   1/1     Running   0          43s   10.244.2.20   k8s-node1   <none>           <none>
myapp2   1/1     Running   0          43s   10.244.1.9    k8s-node2   <none>           <none>
```



# 6. 污点和容忍

taint的effect定义对Pod排斥效果：

- NoSchedule：只影响调度过程，对现存的Pod对象不产生影响，即不驱离
- NoExecute：既影响调度过程，也影响现在的Pod对象，即现存的Pod对象将被驱离
- PreferNoSchedule： 最好不部署Pod，但如果实在找不到节点，也可以在此节点上部署



## 6.1 污点管理

```bash
kubectl describe node k8s-master1 | grep Taints
Taints:             node-role.kubernetes.io/master:NoSchedule

kubectl describe node k8s-node1 | grep Taints
Taints:             <none>

# 打污点
kubectl taint node k8s-node1 node-role.kubernetes.io/node=:NoSchedule

kubectl describe node k8s-node1 | grep Taints
Taints:             node-role.kubernetes.io/node:NoSchedule

# 去除污点
kubectl taint node k8s-node1 node-role.kubernetes.io/node-
```



## 6.2 容忍

```bash
# 节点全部加上node-type污点
kubectl taint node k8s-node1 node-type=:NoSchedule
kubectl taint node k8s-node2 node-type=:NoSchedule

cat > toleration-pod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: toleration-pod
  labels:
    app: toleration-pod
      
spec:
  containers:
  - name: toleration-pod
    image: nginx
    ports:
    - name: http
      containerPort: 80
  tolerations:
  - key: "node-type"           # 污点名称
    operator: "Equal"          # Exists/Equal
    value: "PreferNoSchedule"  # 污点值
    effect: "NoSchedule"       # 
    #tolerationSeconds: 3600    # 如果被驱逐的话，容忍时间 effect和tolerationSeconds不能同时存在
EOF

kubectl apply -f toleration-pod.yml

# 无法正常创建
kubectl get pod
NAME             READY   STATUS    RESTARTS   AGE
toleration-pod   0/1     Pending   0          5s

kubectl describe pod toleration-pod
Events:
  Type     Reason            Age                From               Message
  ----     ------            ----               ----               -------
  Warning  FailedScheduling  26s (x2 over 26s)  default-scheduler  0/4 nodes are available: 1 node(s) had taint {node-role.kubernetes.io/master: }, that the pod didn't tolerate, 3 node(s) had taint {node-type: }, that the pod didn't tolerate.

# k8s-node1 污点增加 PreferNoSchedule，并删除NoSchedule
kubectl taint node k8s-node1 node-type=:PreferNoSchedule
kubectl taint node k8s-node1 node-type=:NoSchedule-    

# 调度成功
kubectl get pod -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP            NODE        NOMINATED NODE   READINESS GATES
toleration-pod   1/1     Running   0          11m   10.244.2.21   k8s-node1   <none>           <none>
```

