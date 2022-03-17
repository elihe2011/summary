# 1. 卷

Kubernetes 中卷的本质是目录，给 pod 中的容器使用，至于卷的类型，它不关心。

它解决的问题：

- 容器磁盘上的文件生命周期是短暂的，容器重启后，之前新增的文件将丢失，即以干净的初始状态启动
- pod 中多个容器可能需要共享文件



生命周期：

- 容器重启，volume 数据还在
- Pod重启，volume 数据可能丢失



常见的 volume 类型：

- emptyDir: 初始内容为空的卷
- hostPath: 挂载宿主机文件或目录
- nfs: 挂载 NFS 卷
- cephfs：挂载 CephFS 卷
- secret：使用一个 secret 为 pod 提供加密信息
- configMap: 使用一个 configMap 为 pod 提供配置信息
- downwardAPI：用于使向下 API 数据（downward API data）对应用程序可用。它挂载一个目录，并将请求的数据写入纯文本文件



Pod 使用存储卷：

- **spec.volumes**: 声明存储卷
- **spec.containers.volumeMounts**: 使用存储卷



## 1.1 emptyDir

创建 Pod 时，会自动创建 `emptyDir`  卷，Pod 中的容器可以在该数据卷中进行文件的写入和读取操作。当删除 Pod 时，emptyDir将自动删除。容器崩溃不会导致 Pod 被删除，因此 emptyDir 卷中的数据在容器崩溃时是安全的。

**用途**：

- 暂存空间，多个容器可共享
- 用于长时间计算崩溃恢复时的检查点
- Web服务器容器提供数据时，保存内容管理容器提取的文件



示例：Pod 中目录共享

```yaml
# volume-emptyDir.yml
apiVersion: v1 
kind: Pod 
metadata:
  name: emptydir-pod 
spec:
  containers:
  - image: busybox
    name: c1
    command: ["sleep", "86400"]
    volumeMounts:
    - mountPath: /path1 
      name: cache-volume
  - image: busybox
    name: c2
    command: ["sleep", "86400"]
    volumeMounts:
    - mountPath: /path2
      name: cache-volume
  volumes:
  - name: cache-volume 
    emptyDir: {}
```

验证：

```bash
$ kubectl exec -it emptydir-pod -c c1 -- touch /path1/abc.txt

$ kubectl exec -it emptydir-pod -c c2 -- ls /path2
abc.txt
```



## 1.2 hostPath

挂载宿主机文件系统到Pod中，挂载类型检查：

| 值                | 行为                                                      |
| ----------------- | --------------------------------------------------------- |
| “”                | 空字符串(默认)，挂载时不做任何检查                        |
| DirectoryOrCreate | 目录不存在自动创建，权限0755，与kubectl具有相同组和所有权 |
| Directory         | 目录必须存在                                              |
| FileOrCreate      | 文件不存在自动创建，权限0644，与kubectl具有相同组和所有权 |
| File              | 文件必须存在                                              |
| Socket            | Unix 套接字必须存在                                       |
| CharDevice        | 字符设备必须存在                                          |
| BlockDevice       | 块设备必须存在                                            |

示例：挂载宿主机目录到Pod

```yaml
# volume-hostPath.yml
apiVersion: v1 
kind: Pod 
metadata:
  name: hostpath-pod
spec:
  containers:
  - image: busybox
    name: busybox
    command: ["sleep", "86400"]
    volumeMounts:
    - name: data-volume
      mountPath: /data  
  volumes:
  - name: data-volume 
    hostPath: 
      path: /data
      type: Directory
```

验证：

```bash
$ kubectl exec -it hostpath-pod -- touch /data/abc.txt

$ kubectl get pod hostpath-pod -o wide
NAME           READY   STATUS    RESTARTS   AGE    IP            NODE         NOMINATED NODE   READINESS GATES
hostpath-pod   1/1     Running   0          114s   10.244.2.13   k8s-node02   <none>           <none>

# k8s-node02
$ ls -l /data
total 0
-rw-r--r-- 1 root root 0 Feb 18 13:28 abc.txt
```



## 1.3 nfs

将现有的 NFS（网络文件系统）共享挂载到您的容器中

```yaml
# nginx-nfs.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
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
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data
        nfs:
          path: /mnt/nfs_share
          server: 192.168.3.103
```

验证：

```bash
# nfs服务器
$ echo '<h1>Hello World!</h1>' > /mnt/nfs_share/index.html

# 获取 nginx 应用
$ kubectl get pod -l app=nginx
NAME                    READY   STATUS    RESTARTS   AGE
nginx-6fd47969f-bhskh   1/1     Running   0          4m7s
nginx-6fd47969f-mt7ch   1/1     Running   0          4m7s
nginx-6fd47969f-nq4dg   1/1     Running   0          4m7s

# 端口转发
$ kubectl port-forward --address 127.0.0.1 pod/nginx-6fd47969f-bhskh 8081:80 &

$ curl 127.0.0.1:8081
Handling connection for 8081
<h1>Hello World!</h1>
```



## 1.4 ConfigMap

```yaml
# volume-configmap.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: log-config
data:
  log_level: "INFO"
  ui.properties: |
    color.good=purple
    color.bad=yellow
    allow.textmode=true
    how.nice.to.look=fairlyNice
---
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["sleep", "86400"]
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
  volumes:
    - name: config-vol
      configMap:
        name: log-config
        items:
          - key: log_level
            path: log_level
          - key: ui.properties
            path: ui.properties
```

验证：

```bash
$ kubectl exec -it configmap-pod -- ls -l /etc/config
total 0
lrwxrwxrwx    1 root     root            16 Feb 18 06:27 log_level -> ..data/log_level
lrwxrwxrwx    1 root     root            20 Feb 18 06:27 ui.properties -> ..data/ui.properties

$ kubectl exec -it configmap-pod -- cat /etc/config/log_level
INFO

$ kubectl exec -it configmap-pod -- cat /etc/config/ui.properties
color.good=purple
color.bad=yellow
allow.textmode=true
how.nice.to.look=fairlyNice
```



## 1.5 DownwardAPI

downwardAPI 支持获取 Pod 自身相关信息

```yaml
# volume-downwardApi.pod
apiVersion: v1
kind: Pod
metadata:
  name: dwapi-pod
  labels:
    app: dnsutils
    version: 1.1
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/scheme: "http"
    prometheus.io/port: "80"
spec:
  containers:
    - name: dnsutils
      image: e2eteam/dnsutils:1.1
      command: ["sh", "-c"]
      args:
      - while true; do
          if [[ -e /etc/podinfo/labels ]]; then
            echo -en '\n\n'; cat /etc/podinfo/labels; fi;
          if [[ -e /etc/podinfo/annotations ]]; then
            echo -en '\n\n'; cat /etc/podinfo/annotations; fi;
          sleep 5;
        done;
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
```

验证：

```bash
$ kubectl logs dwapi-pod
app="dnsutils"
version="1.1"

kubectl.kubernetes.io/last-applied-configuration="{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"prometheus.io/port\":\"80\",\"prometheus.io/scheme\":\"http\",\"prometheus.io/scrape\":\"true\"},\"labels\":{\"app\":\"dnsutils\",\"version\":\"1.1\"},\"name\":\"dwapi-pod\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"args\":[\"while true; do if [[ -e /etc/podinfo/labels ]]; then echo -en '\\\\n\\\\n'; cat /etc/podinfo/labels; fi; if [[ -e /etc/podinfo/annotations ]]; then echo -en '\\\\n\\\\n'; cat /etc/podinfo/annotations; fi; sleep 5; done;\"],\"command\":[\"sh\",\"-c\"],\"image\":\"e2eteam/dnsutils:1.1\",\"name\":\"dnsutils\",\"volumeMounts\":[{\"mountPath\":\"/etc/podinfo\",\"name\":\"podinfo\"}]}],\"volumes\":[{\"downwardAPI\":{\"items\":[{\"fieldRef\":{\"fieldPath\":\"metadata.labels\"},\"path\":\"labels\"},{\"fieldRef\":{\"fieldPath\":\"metadata.annotations\"},\"path\":\"annotations\"}]},\"name\":\"podinfo\"}]}}\n"
kubernetes.io/config.seen="2022-02-18T13:51:25.433545445+08:00"
kubernetes.io/config.source="api"
prometheus.io/port="80"
prometheus.io/scheme="http"
```



# 2. 持久卷

集群中，通常不使用 `emptyDir` 和 `hostPath`，一般只在测试环境中使用。

**`PersistentVolume`**：持久化存储卷，是对底层共享存储的一种抽象。共享存储被定义为**一种集群级别的资源**，不属于任何 Namespace，用户使用 PV 需要通过 PVC 申请。PV 由管理员进行创建和配置的，与底层的共享存储技术实现方式有关，比如 Ceph， Gluster FS， NFS等，都是通过插件机制完成与共享存储的对接，且不同存储的PV配置参数也不同

**`PersistentVolumeClaim`**：用户申请存储资源，它属于某**一个 Namespace 的资源**。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-pv-pvc-bound.png)

总结：

- PV 针对不同的共享存储，使用不同的配置，屏蔽它们之间的差异
- PVC 寻找和是的 PV 进行绑定



## 2.1 PV

PersistentVolume 的类型实现为插件，目前 Kubernetes 支持以下插件：

- RBD：Ceph 块存储
- FC：光纤存储设备
- NFS：网络数据存储卷
- iSCSI：iSCSI 存储设备
- CephFS：开源共享存储系统
- Glusterfs：一种开源共享存储系统。
- HostPath：宿主机目录，仅能用于单机
- ...



**PV 的生命周期**：

- Available：可用状态，尚未被 PVC 绑定
- Bound： 绑定状态，已被 PVC 绑定
- Failed：删除 PVC 清理资源，自动回收卷失败
- Released: 绑定的 PVC 已被删除，但资源尚未被集群回收

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-pv-life-cycle.png)



**PV 类型**: 

- 静态 PV：集群管理员创建的 PV，等待 PVC 消费
- 动态 PV：当管理员创建的静态 PV 都不匹配用户的 PersistentVolumeClaim时，集群可能会尝试动态地为 PVC创建卷。此配置基于`StorageClasses` （PVC必须请求存储类），并且管理员必须创建并配置该类才能够尽兴动态创建。



创建 NFS 类型 PV：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  label:
    app: nfs
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.2
  nfs:
    path: /mnt/nfs_share
    server: 192.168.3.103
```



配置参数说明：

- `volumeMode`:

  - Filesystem: 文件系统，默认选项
  - Block: 块设备。仅有FC、iSCSI、RBD 等支持

- `accessModes`:

  - RWO, ReadWriteOnce：单节点读写模式

  - ROX, ReadOnlyMany：多节点只读模式

  - RWX, ReadWriteMany：多节点读写模式

- storageClassName: 存储类名称。如果设置了它，PVC也必须做相同的设置才能匹配绑定

- persistentVolumeReclaimPolicy: 回收策略

  - Retain：保留数据，由管理手动清理

  - Recycle：删除数据，`rm -rf /thevolume/*`，目前只有 NFS 和 HostPath 支持

  - Delete：删除存储资源，仅部分云存储支持，如AWS EBS、GCE PD、Azure Disk 等



## 2.2 PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 5Gi
  storageClassName: slow
  selector:
    matchLabels:
      app: nfs
```

PVC 匹配 PV：

- storage 大小筛选
- storageClassName 存储类型筛选
- accessModes 访问类型筛选
- selector 选择器筛选，一般根据 label 等



## 2.3 StorageClass

**Static Provisioning**：PV 由存储管理员创建，开发操作PVC，但大规模集群中，存储管理员为满足开发的需求，要手动创建很多个PV，管理起来相当繁琐。

**Dynamic Provisioning**：通过 StorageClass创建一个PV模板，在创建 PVC 时指定 StorageClass，与 StorageClass 关联的存储插件会自动创建对应的 PV 与该 PVC 进行绑定

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: nfs-client
mountOptions: 
  - hard
  - nfsvers=4.2
parameters:
  archiveOnDelete: "true"
```

参数说明：

- provisioner: 存储分配提供者，如果集群中没有先创建它，那么创建的 `StorageClass` 只能作为标记，而不能提供创建 `PV` 的作用

- archiveOnDelete：删除 PV 后是否保留数据
- `storageclass.kubernetes.io/is-default-class: "true"`: 创建 PVC 时如果未指定 StorageClass 则会使用默认的 StorageClass



# 3. 存储类延迟绑定

**Step 1**：准备存储

节点 k8s-node01 上操作

```bash
$ mkdir -p /data/nginx
$ echo '<h1>hello storage class</h1>' > /data/nginx/index.html
```

**Step 2**: 创建 SC, PV, PVC

```yaml
# delay-bound-storage.yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /data/nginx
  nodeAffinity: # local 类型需要设置节点亲和
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-node01
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
```

**Step 3**: 检查存储状态

```bash
$  kubectl get storageclasses
NAME            PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-storage   kubernetes.io/no-provisioner   Delete          WaitForFirstConsumer   false                  79s

$ kubectl get pv nginx-pv
NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    REASON   AGE
nginx-pv   5Gi        RWO            Delete           Available           local-storage            101s

$ kubectl get pvc nginx-pvc
NAME        STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS    AGE
nginx-pvc   Pending                                      local-storage   106s

$ kubectl describe pvc nginx-pvc
Name:          nginx-pvc
Namespace:     default
StorageClass:  local-storage
Status:        Pending
Volume:
Labels:        <none>
Annotations:   <none>
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type    Reason                Age                 From                         Message
  ----    ------                ----                ----                         -------
  Normal  WaitForFirstConsumer  5s (x10 over 2m6s)  persistentvolume-controller  waiting for first consumer to be created before binding
```

**Step 4**: 创建应用

```yaml
# delay-bound-nginx.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      appname: nginx
  template:
    metadata:
      name: nginx
      labels:
        appname: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        volumeMounts:
          - name: data
            mountPath : /usr/share/nginx/html
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: nginx-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

**Step 5**: 验证

```bash
# 已绑定
$ kubectl get pvc
NAME        STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
nginx-pvc   Bound    nginx-pv   5Gi        RWO            local-storage   19m

# 本地卷挂载成功
$ curl 192.168.80.100:30080
<h1>hello storage class</h1>
```



# 4. 动态存储分配(NFS)

https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner



## 4.1 创建 RBAC

```yaml
# nfs-rbac.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
```



## 4.2 部署 NFS Provisioner

```yaml
# nfs-provisioner-deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 192.168.3.103
            - name: NFS_PATH
              value: /mnt/nfs_share
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.3.103
            path: /mnt/nfs_share
```



## 4.3 创建 StorageClass

```yaml
# nfs-storageclass.yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
```



## 4.4 部署 StatefulSet 应用

```go
# nfs-nginx-deploy.yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx"
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "nfs-storage"
      resources:
        requests:
          storage: 1Gi
```



## 4.5 验证

```bash
# 应用已启动
$ kubectl get pod
NAME                                     READY   STATUS              RESTARTS   AGE
nfs-client-provisioner-5444cbbb6-jjv2l   1/1     Running             0          20m
web-0                                    1/1     Running             0          2m39s
web-1                                    1/1     Running             0          16s
web-2                                    0/1     ContainerCreating   0          8s

# PV 自动创建
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS          REASON   AGE
pvc-4e8413aa-51bd-4d74-bb88-0856b974394f   1Gi        RWO            Delete           Bound    default/data-web-0       nfs-storage                    32s
pvc-ab9ba91d-4cbc-4dbd-a977-b1d1aa63b047   1Gi        RWO            Delete           Bound    default/data-web-2       nfs-storage                    11s
pvc-c6e64d66-33c5-4e79-8e0c-20db8f003731   1Gi        RWO            Delete           Bound    default/data-web-1       nfs-storage                    19s

# PVC 自动绑定
$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-web-0   Bound    pvc-4e8413aa-51bd-4d74-bb88-0856b974394f   1Gi        RWO            nfs-storage    2m44s
data-web-1   Bound    pvc-c6e64d66-33c5-4e79-8e0c-20db8f003731   1Gi        RWO            nfs-storage    21s
data-web-2   Bound    pvc-ab9ba91d-4cbc-4dbd-a977-b1d1aa63b047   1Gi        RWO            nfs-storage    13s
```


