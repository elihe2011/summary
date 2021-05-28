# 1. Pod

Pod 是一组紧密关联的容器集合，它们共享 IPC、Network 和 UTS namespace，是 Kubernetes 调度的基本单位。



## 1.1 Pod 的特征

- 包含多个共享 IPC、Network 和 UTS namespace 的容器，容器间可直接通过 localhost 通信
- 可访问共享的 Volume，共享数据
- 无容错性：直接创建的 Pod，和 Node 是绑定的，即使 Node 挂掉也不会重新被调度。推荐使用 Deployment、DaemonSet等来容错
- 优雅终止：Pod 删除时，先给其内部进程发送 SIGTERM 信号，等待一段时间 (grace period) 后才强制停止依然在运行的进程
- 特权容器：通过 SecurityContext 配置，具有改变系统配置的权限 (网络插件中大量使用)



## 1.2 Pod 定义

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
```



## 1.3  Pod 生命周期

- Pending：正在创建 Pod
- Running： 正在运行
- Succeeded：成功运行结束，不会重启
- Failed：所有容器都被终止，但至少有一个容器退出失败
- Unknown：未知，通常是由于 apiserver 无法与 kubelet 通信导致

```bash
kubectl get pod nginx -o jsonpath="{.status.phase}"
Running
```



## 1.4 使用 Volume

### 1.4.1 emptyDir

创建空目录。只要Pod在Node上，即使Pod挂掉，也不会导致 emptyDir 丢失数据；但是 Pod 从 Node删除或迁移，emptyDir 将被删除，数据永久丢失。

`/var/lib/kubelet/pods/238a2d68-b12c-4920-95b4-4dc21a79452f/volumes/kubernetes.io~empty-dir/tmp-volume`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis
spec:
  containers:
  - name: redis
    image: redis
    restartPolicy: Always  # OnFailure, Never 只在当前Node重启，不会调度到其他节点
    volumeMounts:
    - name: redis-storage
      mountPath: /data/redis
  volumes:
  - name: redis-storage
    emptyDir: {}
```



### 1.4.2 hostPath

允许挂载 Node 上的文件系统到 Pod 中。

```bash
apiVersion: v1
kind: Pod
metadata:
  name: redis-hostpath
spec:
  containers:
  - name: redis-hostpath
    image: redis
    volumeMounts:
    - name: redis-storage
      mountPath: /data/redis
  volumes:
  - name: redis-storage
    hostPath:
      path: /data
```



### 1.4.3 NFS

```yaml
volumes:
- name: nfs
  nfs:
    # FIXME: use the right hostname
    server: 10.254.234.223
    path: "/"
```



### 1.4.4 subPath

Pod 中 多个容器使用同一个 Volume，按需要使用子目录

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-nginx-pv
  labels: 
    release: stable
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  local:
    path: /mysql-nginx
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-node1
          - k8s-node2
          
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mysql-nginx-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
  volumeName: mysql-nginx-pv
  selector:
    matchLabels:
      release: stable
---

apiVersion: v1
kind: Pod
metadata:
  name: mysql-nginx
spec:
    containers:
    - name: mysql
      image: mysql
      volumeMounts:
      - mountPath: /var/lib/mysql
        name: site-data
        subPath: mysql
      env:
      - name: MYSQL_ROOT_PASSWORD
        value: "123456"
      ports:
      - name: mysql
        containerPort: 3306
    - name: nginx
      image: nginx
      volumeMounts:
      - mountPath: /var/www/html
        name: site-data
        subPath: html
      ports:
      - name: nginx
        containerPort: 80
    volumes:
    - name: site-data
      persistentVolumeClaim:
        claimName: mysql-nginx-pvc
```



## 1.5 资源限制

通过 cgroups 限制容器的 CPU 和内存等计算资源，包括 调度请求requests (**调度器保证调度到资源充足的 Node 上，无法满足则调度失败**) 和 调度上限limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  containers:
    - image: nginx
      name: nginx
      resources:
        requests:
          cpu: "300m"
          memory: "56Mi"
        limits:
          cpu: "1"
          memory: "128Mi"
```



## 1.6 健康检查

两种检查探针：

- LivenessProbe: 生存检查，不健康则删除并重新创建容器
- ReadinessProbe: 就绪检查，不正常则不接收来自SVC的流量，即将Pod从Service的endpoint中移除

执行探针的三种方式：

- exec: 容器中执行命令，命令返回码为0，表示成功
- tcpSocket: 对指定容器的 IP:PORT 执行一个 TCP检查，端口开放则表示成功

- httpGet: 对指定容器的 IP:PORT/path 发送一个 HTTP GET 请求，返回状态码 2xx, 3xx 表示成功

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
  name: nginx
spec:
    containers:
    - name: nginx
      image: nginx
      livenessProbe:
        httpGet:
          path: /
          port: 80
          httpHeaders:
          - name: X-Custom-Header
            value: Awesome
        initialDelaySeconds: 15
        timeoutSeconds: 1
      readinessProbe:
        exec:
          command:
          - cat
          - /usr/share/nginx/html/index.html
        initialDelaySeconds: 5
        timeoutSeconds: 1
    - name: goproxy
      image: gcr.io/google_containers/goproxy:0.1
      ports:
      - containerPort: 8080
      readinessProbe:
        tcpSocket:
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 10
      livenessProbe:
        tcpSocket:
          port: 8080
        initialDelaySeconds: 15
        periodSeconds: 20
```



## 1.7 InitC 容器

InitC 容器在所有容器运行前执行，常用于做初始化配置。

如果为一个 Pod 指定了多个 InitC 容器，那这些容器会按顺序串行执行。当所有 InitC 容器运行完成后，才运行应用容器。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-initC
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: workdir
      mountPath: /usr/share/nginx/html
  # These containers are run during pod initialization
  initContainers:
  - name: install
    image: busybox
    command:
    - wget
    - "-O"
    - "/work-dir/index.html"
    - http://kubernetes.io
    volumeMounts:
    - name: workdir
      mountPath: "/work-dir"
  dnsPolicy: Default
  volumes:
  - name: workdir
    emptyDir: {}
```



InitC 容器的作用：

- 出于安全考虑，不建议在应用容器中包含的实用工具，可放入 InitC 中
- 使用 Namespace，所以对应用容器具有不同的文件系统视图。因此，它能够具有访问 Secret 的权限，而应用容器不能访问
- 在应用容器之前运行完成，可阻塞或延迟应用容器的启动，直到满足了一些先决条件才运行应用容器



## 1.8 生命周期钩子

Container Lifecycle Hooks: 监听容器生命周期的特定事件，并在事件发生时，执行已注册的回调函数。支持两种钩子：

- postStart: 容器创建后立即执行。异步执行，无法保证一定在 ENTRYPOINT 之前运行。如果失败，容器将被杀死。
- preStop: 容器终止前执行。常用于资源清理，如果失败，容器同样被杀死。

钩子的回调函数：

- exec：执行命令，退出码是0表示成功
- httpGet: 向指定 URL发起 GET 请求，返回状态码 2xx, 3xx 为成功

```bash
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-nginx
spec:
  containers:
  - name: lifecycle-nginx
    image: nginx
    lifecycle:
      postStart:
        httpGet:
          path: /
          port: 80
      preStop:
        exec:
          command: ["/usr/sbin/nginx","-s","quit"]
```



## 1.9 自定义 hosts

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostaliases-pod
spec:
  hostAliases:
  - ip: "127.0.0.1"
    hostnames:
    - "foo.local"
    - "bar.local"
  - ip: "10.1.2.3"
    hostnames:
    - "foo.remote"
    - "bar.remote"
  containers:
  - name: cat-hosts
    image: busybox
    command:
    - cat
    args:
    - "/etc/hosts"
```



## 1.10 Pod 时区

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: timezone
spec:
  containers:
  - name: alpine
    image: alpine
    stdin: true
    tty: true
    volumeMounts:
    - mountPath: /etc/localtime
      name: time
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/localtime
      type: ""
    name: time
```



# 2. Deployment

为 Pod 和 ReplicaSet 提供一个声明式定义 (declarative) 方法，用以替代 ReplicationController，方便管理运用。典型使用场景：

- 定义 Deployment 来创建 Pod 和 ReplicaSet
- 滚动升级和回滚应用
- 扩容和缩容
- 暂停和继续 Deployment



## 2.1 定义

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

```bash
# --record 记录版本升级操作命令详情
kubectl apply -f deploy-nginx.yaml --record
```



## 2.2 扩/缩容

```bash
kubectl scale deployment nginx-deployment --replicas 10
```



## 2.3 水平自动扩容

Horizontal Pod Autoscaling，Pod中，资源使用达到一定阈值时，自动触发

```bash
kubectl autoscale deployment nginx-deployment --min=10 --max=30 --cpu-percent=80

# 取消自动扩容
kubectl delete horizontalpodautoscalers.autoscaling nginx-deployment
```



## 2.4 升级

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.17.9
```



## 2.5 回滚

```bash
# 升级记录
kubectl rollout history deployment/nginx-deployment

# 回滚到最近一次
kubectl rollout undo deployment/nginx-deployment

# 升级/回滚状态
kubectl rollout status deployment/nginx-deployment
```



## 2.6 暂停和恢复

```bash
# 暂停，后续操作将不会立即重建Pod
kubectl rollout pause deployment/nginx-deployment

# 不会立即升级
kubectl set image deployment/nginx-deployment nginx=nginx:1.18.1

# 未新增 rollout 记录
kubectl rollout history deployment/nginx-deployment

# 设置资源
kubectl set resources deployment nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi

# 恢复
kubectl rollout resume deploy nginx
```



# 3. DaemonSet

Daemonset 保证在每个Node上，都运行一个容器副本，典型的应用：

- 日志收集：fluentd，logstash
- 系统监控：Prometheus Node Exporter， collectd
- 系统程序：kube-proxy，kube-dns，ceph

```bash
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: gcr.io/google-containers/fluentd-elasticsearch:1.20
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers       
```



# 4. ConfigMap

可实现应用和配置分离，避免因为修改配置项而重新构建镜像

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
data:
  special.how: very
  special.type: charm
---
# kubectl create configmap env-config --from-literal=log_level=INFO
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
data:
  log_level: INFO
  special.type: charm
---
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["/bin/sh", "-c", "echo $(SPECIAL_LEVEL_KEY) $(SPECIAL_TYPE_KEY) ${LOG_LEVEL}" ]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.how
        - name: SPECIAL_TYPE_KEY
          valueFrom:
            configMapKeyRef:
              name: special-config
              key: special.type
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: log_level
  restartPolicy: Never
```



```bash
kubectl create configmap env-config --from-literal=log_level=INFO

kubectl get configmap env-config -o go-template="{{.data}}"
map[log_level:INFO]

kubectl edit configmap env-config 
```



# 5. Secret



# 6. ServiceAccount



