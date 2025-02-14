# 1. Prometheus

## 1.1 权限

Prometheus 通过 `kube-apiserver` 获取数据，需要先创建特定RBAC

```yaml
# prometheus-rbac.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["nodes","nodes/proxy","services","endpoints","pods"]
  verbs: ["get", "list", "watch"] 
- apiGroups: ["extensions"]
  resources: ["ingress"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
  namespace: kube-system
roleRef: 
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: kube-system
```



## 1.2 存储

使用 NFS 做存储介质

```bash
$ mkdir -p /data/nfsshare/prometheus
$ chmod 777 /data/nfsshare/prometheus
```

分配存储

```yaml
# prometheus-storage.yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: prom-nfs-storage
  mountOptions:
  - hard
  - nfsvers=4.2
  nfs:
    server: 192.168.3.200
    path: /data/nfsshare/prometheus
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: prom-nfs-storage
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      k8s-app: prometheus
```



## 1.3 配置

```yaml
# prometheus-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: kube-system
data:
  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s
      external_labels:
        cluster: "kubernetes"
        
    scrape_configs:
    - job_name: prometheus
      static_configs:
      - targets: ['127.0.0.1:9090']
        labels:
          instance: prometheus 
```



## 1.4 应用

```yaml
# prometheus-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  type: NodePort
  ports:
  - name: http
    port: 9090
    targetPort: 9090
    nodePort: 30090
  selector:
    k8s-app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: prometheus
  template:
    metadata:
      labels:
        k8s-app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.53.2
        ports:
        - name: http
          containerPort: 9090
        securityContext:
          runAsUser: 65534
          privileged: true
        command:
        - "/bin/prometheus"
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        - "--web.enable-lifecycle"
        - "--storage.tsdb.path=/prometheus"
        - "--storage.tsdb.retention.time=15d"
        - "--web.console.libraries=/etc/prometheus/console_libraries"
        - "--web.console.templates=/etc/prometheus/consoles"
        resources:
          limits:
            cpu: 2000m
            memory: 1024Mi
          requests:
            cpu: 1000m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
        volumeMounts:
        - name: data
          mountPath: /prometheus
          subPath: prometheus
        - name: config
          mountPath: /etc/prometheus
      - name: configmap-reload
        image: bitnami/configmap-reload:0.13.1
        args:
        - "--volume-dir=/etc/config"
        - "--webhook-url=http://localhost:9090/-/reload"
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
          requests:
            cpu: 10m
            memory: 10Mi
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: prometheus
      - name: config
        configMap:
          name: prometheus-config
```



## 1.5 页面

访问地址：http://192.168.80.100:30090/

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-ui.png) 



# 2. Grafana

## 2.1 存储

暂时使用 NFS 做存储介质

```bash
$ mkdir -p /data/nfsshare/grafana
$ chmod 777 /data/nfsshare/grafana
```



```yaml
# grafana-storage.yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana
  namespace: kube-system
  labels:
    k8s-app: grafana
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: grafana-nfs-storage
  mountOptions:
  - hard
  - nfsvers=4.2
  nfs:
    server: 192.168.3.200
    path: /data/nfsshare/grafana
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: grafana
  namespace: kube-system
  labels:
    k8s-app: grafana
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: grafana-nfs-storage
  resources:
    requests:
      storage: 1Gi
  selector:
    matchLabels:
      k8s-app: grafana
```



## 2.2 应用

```yaml
# grafana-deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: kube-system
  labels:
    k8s-app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: grafana
  template:
    metadata:
      labels:
        k8s-app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:11.1.4
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
          name: grafana
        env:
        #- name: GF_SECURITY_ADMIN_USER
        #  value: admin
        #- name: GF_SECURITY_ADMIN_PASSWORD
        #  value: admin321
        - name: GF_AUTH_PROXY_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        readinessProbe:
          failureThreshold: 10
          httpGet:
            path: /api/health
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 30
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /api/health
            port: 3000
            scheme: HTTP
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          limits:
            cpu: 200m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi
        volumeMounts:
        - mountPath: /var/lib/grafana
          subPath: grafana
          name: storage
      securityContext:
        fsGroup: 472
        runAsUser: 472
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: grafana 
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: kube-system
  labels:
    k8s-app: grafana
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000  
    nodePort: 30010
  selector:
    k8s-app: grafana
```



## 2.3 数据源

访问地址：http://192.168.3.200:30010/   admin/admin

**新增数据源：**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-prometheus.png)



```bash
# 获取数据源 dns 地址
$ kubectl run dns -it --rm --image=e2eteam/dnsutils:1.1 -- /bin/sh
/ # nslookup prometheus.kube-system
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   prometheus.kube-system.svc.cluster.local
Address: 10.109.159.64
```

数据源地址：`http://prometheus.kube-system.svc.cluster.local:9090` 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-ds-prometheus.png)



# 3. Node Exporter

集群节点监控



## 3.1 部署

```yaml
# node-exporter-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: kube-system
  labels:
    k8s-app: node-exporter
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 9100
    targetPort: 9100
  selector:
    k8s-app: node-exporter
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: kube-system
  labels:
    k8s-app: node-exporter
spec:
  selector:
    matchLabels:
      k8s-app: node-exporter
  template:
    metadata:
      labels:
        k8s-app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.2.2
        ports:
        - name: metrics
          containerPort: 9100
        args:
        - "--path.procfs=/host/proc"
        - "--path.sysfs=/host/sys"
        - "--path.rootfs=/host"
        volumeMounts:
        - name: dev
          mountPath: /host/dev
        - name: proc
          mountPath: /host/proc
        - name: sys
          mountPath: /host/sys
        - name: rootfs
          mountPath: /host
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: rootfs
          hostPath:
            path: /
      hostPID: true
      hostNetwork: true
      tolerations:
      - operator: "Exists"
```



收集数据测试：

```bash
$ curl -kL http://127.0.0.1:9100/metrics
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0
go_gc_duration_seconds{quantile="0.25"} 0
go_gc_duration_seconds{quantile="0.5"} 0
go_gc_duration_seconds{quantile="0.75"} 0
go_gc_duration_seconds{quantile="1"} 0
go_gc_duration_seconds_sum 0
go_gc_duration_seconds_count 0
...
```



## 3.2 集成

每个节点上的 `Node Exporter` 都会通过 `9100` 端口和 `/metrics` 接口暴露节点节点监控指标数据。要想采集这些指标数据，需要在 `Prometheus` 配置文件中，添加全部的 `Node Exporter` 的 `地址` 与 `端口` 这样的静态配置：

```yaml
scrape_configs:
- job_name: 'node-exporter'
  kubernetes_sd_configs: # 服务发现配置
  - role: node           # 服务发现模式为node， 即从kubernetes集群中的每个节点发现目标，默认地址为kubelet的HTTP端口
  relabel_configs:       # 对采集的标签进行重新标记
  - action: replace
    source_labels: [__address__] # 从得到的标签列表中找到 __address__ 标签的值，即 kueblet 的地址
    regex: '(.*):10250'          # 使用正则表达式截取标签值中的IP部分
    replacement: '${1}:9100'     # {1} 上述正则表达截取的IP地址
    target_label: __address__
```



**更新配置后，强制刷新**：

```bash
curl -X POST http://192.168.80.100:30090/-/reload
```



## 3.3 看板

步骤1： 新增看板 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard.png)

步骤2：导入 ID为 **8919** 的 `Node Exporter` 模板，然后加载到配置数据库

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-load-8919.png)

步骤3：选择使用上面配置的 `Prometheus` 数据库，之后点击 `Import` 按钮进入看板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-import.png)

步骤4：监控信息页面

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-node-exporter.png)



# 4. StateMetrics+cAdvisor

**`cAdvisor`**: Container Advisor，Google开源的容器监控工具，可用于对容器资源的使用情况和性能进行监控。它以守护进程方式运行，用于收集、聚合、处理和导出容器的运行信息，包含完整历史资源使用情况和网络统计等信息。在 K8S 中，`kubelet` 组件集成了 `cAdvisor`，无需单独安装。

**`KubeStateMetrics`**: 是一个独立服务，支持从 `Kubernetes API` 对象中获取指标数据，这个过程不会对这些原始数据进行修改。



## 4.1 前线

KubeStateMetrics 通过 `kube-apiserver` 获取数据，需要先创建特定RBAC

```yaml
# kube-state-metrics-rbac.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["configmaps","secrets","nodes","pods",
              "services","resourcequotas",
              "replicationcontrollers","limitranges",
              "persistentvolumeclaims","persistentvolumes",
              "namespaces","endpoints"]
  verbs: ["list","watch"]
- apiGroups: ["extensions"]
  resources: ["daemonsets","deployments","replicasets"]
  verbs: ["list","watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets","daemonsets","deployments","replicasets"]
  verbs: ["list","watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs","jobs"]
  verbs: ["list","watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list","watch"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["list","watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["list","watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses","volumeattachments"]
  verbs: ["list","watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations","validatingwebhookconfigurations"]
  verbs: ["list","watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies","ingresses"]
  verbs: ["list","watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
```



## 4.2 部署

```yaml
# kube-state-metrics-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
    app.kubernetes.io/name: kube-state-metrics   # prometheus自动发现
spec:
  type: ClusterIP
  ports:
  - name: http-metrics
    port: 8080
    targetPort: 8080
  - name: telemetry
    port: 8081
    targetPort: 8081
  selector:
    k8s-app: kube-state-metrics
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kube-state-metrics
  template:
    metadata:
      labels:
        k8s-app: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: bitnami/kube-state-metrics:2.2.4
        securityContext:
          runAsUser: 65534
        ports:
        - name: http-metrics
          containerPort: 8080
        - name: telemetry 
          containerPort: 8081
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 5
          timeoutSeconds: 5
```



**访问 KubeStateMetrics 暴露的指标数据**:

```bash
$ curl -kL $(kubectl get service -n kube-system | grep kube-state-metrics | awk '{print $3}'):8080/metrics
...
# TYPE kube_configmap_info gauge
kube_configmap_info{namespace="kube-system",configmap="extension-apiserver-authentication"} 1
kube_configmap_info{namespace="kube-system",configmap="kube-proxy"} 1
kube_configmap_info{namespace="kube-system",configmap="kube-root-ca.crt"} 1
kube_configmap_info{namespace="kube-system",configmap="kubeadm-config"} 1
kube_configmap_info{namespace="kube-public",configmap="kube-root-ca.crt"} 1
kube_configmap_info{namespace="kube-system",configmap="kube-flannel-cfg"} 1
kube_configmap_info{namespace="kube-system",configmap="kubelet-config-1.21"} 1
kube_configmap_info{namespace="kube-public",configmap="cluster-info"} 1
kube_configmap_info{namespace="kube-system",configmap="coredns"} 1
kube_configmap_info{namespace="kube-system",configmap="prometheus-config"} 1
kube_configmap_info{namespace="default",configmap="kube-root-ca.crt"} 1
kube_configmap_info{namespace="kube-node-lease",configmap="kube-root-ca.crt"} 1
...
```



## 4.3 集成

### 4.3.1 cAdvisor

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-cadvisor.png)

获取 kubelet 的metrics 数据，需要通过 `kube-apiserver` 提供的 api 做代理: `https://kube-apiserver:443/api/v1/nodes/${NODE_NAME}/proxy/metrics/cadivisor`

```yaml
- job_name: 'kubernetes-cadvisor'
  scheme: https
  metrics_path: /metrics/cadvisor
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  kubernetes_sd_configs: # 服务发现配置
  - role: node           # 服务发现模式为node， 即从kubernetes集群中的每个节点发现目标，默认地址为kubelet的HTTP端口
  relabel_configs:       # 对采集的标签进行重新标记
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)  # 截取正则表达匹配部分，替换原有标签，即去除标签前缀__meta_kubernetes_node_label_
  - target_label: __address__                 # 修改指标数据采集address为 kubernetes.default.svc:443
    replacement: kubernetes.default.svc:443   
  - source_labels: [__meta_kubernetes_node_name]
    target_label: __metrics_path__            
    replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor  # ${1} 获取从标签列表中获取到的 node_name

  ## 用于适配对应的Grafana Dashboard图表，编号13105
  metric_relabel_configs:
  - source_labels: [instance]
    separator: ;
    regex: (.+)
    target_label: node
    replacement: $1
    action: replace
  - source_labels: [pod_name]
    separator: ;
    regex: (.+)
    target_label: pod
    replacement: $1
    action: replace
  - source_labels: [container_name]
    separator: ;
    regex: (.+)
    target_label: container
    replacement: $1
    action: replace
```



### 4.3.2 KubeStateMetrics

```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
  - role: endpoints  # 服务发现模式为endpoints，它调用kube-apiserver的接口获取指标数据
    namespaces:      # 限定只获取命名空间为kube-system的endpoint信息
      names: ["kube-system"]
  relabel_configs:
  ## 指定从 app.kubernetes.io/name 标签等于 kube-state-metrics 的 service 服务获取指标信息
  - action: keep
    source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
    regex: kube-state-metrics
  ## 配置为了适配 Grafana Dashboard 模板(编号1310)
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - action: replace
    source_labels: [__meta_kubernetes_namespace]
    target_label: k8s_namespace
  - action: replace
    source_labels: [__meta_kubernetes_service_name]
    target_label: k8s_sname
```

相关的标签：

http://192.168.80.100:30090/service-discovery

```bash
__meta_kubernetes_service_label_app_kubernetes_io_name="kube-state-metrics"

__meta_kubernetes_service_label_app="kube-state-metrics"
__meta_kubernetes_service_label_app_kubernetes_io_name="kube-state-metrics"
__meta_kubernetes_service_label_app="node-exporter"
__meta_kubernetes_service_label_k8s_app="kube-dns"
__meta_kubernetes_service_label_kubernetes_io_cluster_service="true"
__meta_kubernetes_service_label_kubernetes_io_name="CoreDNS"
__meta_kubernetes_service_label_app="grafana"

__meta_kubernetes_namespace="kube-system"

__meta_kubernetes_service_name="kube-state-metrics"
__meta_kubernetes_service_name="node-exporter"
__meta_kubernetes_service_name="kube-dns"
__meta_kubernetes_service_name="prometheus"
_meta_kubernetes_service_name="grafana"
```



## 4.4 看板

步骤1： 新增看板 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard.png)

步骤2：导入 ID为 **13105** 的 `cAdvisor` 模板，然后加载到配置数据库

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-load-13105.png)

步骤3：选择使用上面配置的 `Prometheus` 数据库，之后点击 `Import` 按钮进入看板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-import.png)

步骤4：监控信息页面

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-kubestatemetrics-cadvisor.png)



# 5. 监控 Service

## 5.1 服务数据采集

Prometheus 自动采集 kuberenets 服务数据方式：

- **静态配置**：将要采集的 目标地址、端口、接口等添加到 Prometheus 配置中

- **动态配置**：使用服务发现机制，动态发现指定的服务。Prometheus 支持 Consule、DNS、Kubernetes 等动态服务发现。可根据指定条件获取要采集的目标地址、端口、接口等信息，然后添加到 Prometheus Target 目标中

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-service-discovery.png)



## 5.2 配置 Prometheus

在 Prometheus 配置文件中，添加 kubernetes endpoints 服务发现机制，并且配置标签，这样服务发现只会去找指定了特定 annotations 的 Service 资源

补充：**`relabel_config` action** 解释

- `replace`: Match `regex` against the concatenated `source_labels`. Then, set `target_label` to `replacement`, with match group references (`${1}`, `${2}`, ...) in `replacement` substituted by their value. If `regex` does not match, no replacement takes place.
- `keep`: Drop targets for which `regex` does not match the concatenated `source_labels`.
- `drop`: Drop targets for which `regex` matches the concatenated `source_labels`.
- `hashmod`: Set `target_label` to the `modulus` of a hash of the concatenated `source_labels`.
- `labelmap`: Match `regex` against all label names. Then copy the values of the matching labels to label names given by `replacement` with match group references (`${1}`, `${2}`, ...) in `replacement` substituted by their value.
- `labeldrop`: Match `regex` against all label names. Any label that matches will be removed from the set of labels.
- `labelkeep`: Match `regex` against all label names. Any label that does not match will be removed from the set of labels.

```yaml
# prometheus-config.yml
kind: ConfigMap
apiVersion: v1
metadata:
  name: prometheus-config
  namespace: kube-system
data:
  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s
      external_labels:
        cluster: "kubernetes"
    scrape_configs:    
    ############################### kubernetes-service-endpoints #########################################
    - job_name: 'kubernetes-service-endpoints'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        regex: "true"
      - action: replace
        source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
        regex: (https?)
        target_label: __scheme__
      - action: replace
        source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
        regex: ([^:]+)(?::\d+)?;(\d+)
        target_label: __address__
        replacement: $1:$2
      - action: replace
        source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        regex: (.+)
        target_label: __metrics_path__
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      - action: replace
        source_labels: [__meta_kubernetes_service_name]
        target_label: kubernetes_name
      - action: replace
        source_labels: [__address__]
        target_label: instance
        regex: (.+):(.+)    
```

**更新配置后，强制刷新**：

```bash
curl -X POST http://192.168.80.100:30090/-/reload
```



## 5.3 CoreDNS 指标

### 5.3.1 添加标签

```yaml
# coredns-svc-patch.yml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/scheme: "http"
    prometheus.io/port: "9153"
    prometheus.io/path: "/metrics"
```

CoreDNS 服务打上 patch：

```bash
kubectl patch svc kube-dns -n kube-system --type merge --patch-file coredns-svc-patch.yml
```



### 5.3.2 采集指标

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-service-targets.png)



# 6. 监控 ETCD

## 6.1 采集 ETCD 指标数据

在 Kuberenetes 集群的 ETCD 默认时开启暴露 metrics 数据，但在 ETCD 部署在集群外，并且其暴露的接口是基于 HTTPS 协议。为统一管理，需要将 ETCD 服务代理到 Kuberetnets 集群中，然后使用 Prometheus 的 Kubernetes 动态服务发现机制。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-etcd-metrics.png)



## 6.2 服务代理

```yaml
# etcd-proxy.yml
apiVersion: v1
kind: Service
metadata:
  name: etcd
  namespace: kube-system
  labels:
    k8s-app: etcd
    app.kubernetes.io/name: etcd
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: port
    port: 2379          
    protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: etcd
  namespace: kube-system
  labels:
    k8s-app: etcd
subsets:
- addresses:
  - ip: 192.168.80.100   
  ports:
  - port: 2379
```



## 6.3 导入证书

### 6.3.1 证书存入 ConfigMap

```bash
kubectl create secret generic etcd-certs \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  --from-file=/etc/kubernetes/pki/etcd/ca.crt \
  -n kube-system
```



### 6.3.2 修改 Prometheus 部署参数

增加 etcd 证书挂载

```yaml
# prometheus-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  type: NodePort
  ports:
  - name: http
    port: 9090
    targetPort: 9090
    nodePort: 30090
  selector:
    k8s-app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: kube-system
  labels:
    k8s-app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: prometheus
  template:
    metadata:
      labels:
        k8s-app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.26.1
        ports:
        - name: http
          containerPort: 9090
        securityContext:
          runAsUser: 65534
          privileged: true
        command:
        - "/bin/prometheus"
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        - "--web.enable-lifecycle"
        - "--storage.tsdb.path=/prometheus"
        - "--storage.tsdb.retention.time=10d"
        - "--web.console.libraries=/etc/prometheus/console_libraries"
        - "--web.console.templates=/etc/prometheus/consoles"
        resources:
          limits:
            cpu: 2000m
            memory: 1024Mi
          requests:
            cpu: 1000m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
        volumeMounts:
        - name: data
          mountPath: /prometheus
          subPath: prometheus
        - name: config
          mountPath: /etc/prometheus
        - name: certs   # new add
          readOnly: true
          mountPath: /certs
      - name: configmap-reload
        image: jimmidyson/configmap-reload:v0.7.1
        args:
        - "--volume-dir=/etc/config"
        - "--webhook-url=http://localhost:9090/-/reload"
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
          requests:
            cpu: 10m
            memory: 10Mi
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: prometheus
      - name: config
        configMap:
          name: prometheus-config
      - name: certs   # new add
        secret:      
          secretName: etcd-certs      
```



## 6.4 配置 Prometheus

```yml
# prometheus-config.yml
kind: ConfigMap
apiVersion: v1
metadata:
  name: prometheus-config
  namespace: kube-system
data:
  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s
      external_labels:
        cluster: "kubernetes"
    scrape_configs:
    ###################### kubernetes-etcd ######################
    - job_name: "kubernetes-etcd"
      scheme: https
      tls_config:
        ca_file: /certs/ca.crt
        cert_file: /certs/healthcheck-client.crt
        key_file: /certs/healthcheck-client.key
        insecure_skip_verify: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:               
          names: ["kube-system"]         
      relabel_configs:
      - action: keep
        source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
        regex: etcd    
```

**更新配置后，强制刷新**：

```bash
curl -X POST http://192.168.80.100:30090/-/reload
```



## 6.5 观察采集指标

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-etcd-targets.png)



## 6.6 看板

步骤1： 新增看板 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard.png)

步骤2：导入 ID为 **9733** 的 `ETCD` 模板，然后加载到配置数据库

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-load-9733.png)

步骤3：选择使用上面配置的 `Prometheus` 数据库，之后点击 `Import` 按钮进入看板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-import.png)

步骤4：监控信息页面

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-etcd.png)



# 7. BlackBox Expertor

## 7.1 配置

```yaml
# blackbox-exporter-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-exporter
  namespace: kube-system
  labels:
    k8s-app: blackbox-exporter
data:
  blackbox.yml: |-
    modules:
      ## ----------- DNS 探针 -----------
      dns_tcp:  
        prober: dns
        dns:
          transport_protocol: "tcp"
          preferred_ip_protocol: "ip4"
          query_name: "kubernetes.default.svc.cluster.local"
          query_type: "A" 
      ## ----------- TCP 探针 -----------
      tcp_connect:
        prober: tcp
        timeout: 5s
      ## ----------- ICMP 探针 -----------
      ping:
        prober: icmp
        timeout: 5s
        icmp:
          preferred_ip_protocol: "ip4"
      ## ----------- HTTP GET 2xx 探针 -----------
      http_get_2xx:  
        prober: http
        timeout: 10s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1","HTTP/2"]
          valid_status_codes: [200] 
          no_follow_redirects: false  
      ## ----------- HTTP GET 3xx 探针 -----------
      http_get_3xx:  
        prober: http
        timeout: 10s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1","HTTP/2"]
          valid_status_codes: [301,302,304,305,306,307] 
          no_follow_redirects: false          
      ## ----------- HTTP POST 探针 -----------
      http_post_2xx: 
        prober: http
        timeout: 10s
        http:
          method: POST
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          headers:
             Content-Type: application/json
          body: '{"username": "admin", "password": "123456"}'  
```



## 7.2 部署

```yaml
# blackbox-exporter-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: blackbox-exporter
  namespace: kube-system
  labels:
    k8s-app: blackbox-exporter
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 9115
    targetPort: 9115
  selector:
    k8s-app: blackbox-exporter
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blackbox-exporter
  namespace: kube-system
  labels:
    k8s-app: blackbox-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: blackbox-exporter
  template:
    metadata:
      labels:
        k8s-app: blackbox-exporter
    spec:
      containers:
      - name: blackbox-exporter
        image: prom/blackbox-exporter:v0.19.0
        args:
        - --config.file=/etc/blackbox_exporter/blackbox.yml
        - --web.listen-address=:9115
        - --log.level=info
        ports:
        - name: http
          containerPort: 9115
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          tcpSocket:
            port: 9115
          initialDelaySeconds: 5
          timeoutSeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        readinessProbe:
          tcpSocket:
            port: 9115
          initialDelaySeconds: 5
          timeoutSeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/blackbox_exporter
      volumes:
      - name: config
        configMap:
          name: blackbox-exporter
          defaultMode: 420
```



## 7.3 集成

### 7.3.1 创建 DNS 探测配置

```yaml
################ DNS 服务器监控 ###################
- job_name: "kubernetes-dns"
  metrics_path: /probe
  params:
    ## DNS 探针
    module: [dns_tcp]
  static_configs:
    - targets:
      - kube-dns.kube-system:53
      - 114.114.114.114
      - 8.8.8.8
      - 1.1.1.1
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-exporter.kube-system:9115
```



### 7.3.2 创建 Service 探测配置

创建用于探测 Kubernetes 服务的配置，对那些配置了 `prometheus.io/http-probe: "true"` 标签的 **Kubernetes Service** 资源的健康状态进行探测

```yaml
- job_name: "kubernetes-services"
  metrics_path: /probe
  ## 使用HTTP_GET_2xx与HTTP_GET_3XX模块
  params: 
    module:
    - "http_get_2xx"
    - "http_get_3xx"
  ## 使用Kubernetes动态服务发现,且使用Service类型的发现
  kubernetes_sd_configs:
  - role: service
  relabel_configs:
    ## 设置只监测Kubernetes Service中Annotation里配置了注解prometheus.io/http_probe: true的service
  - action: keep
    source_labels: [__meta_kubernetes_service_annotation_prometheus_io_http_probe]
    regex: "true"
  - action: replace
    source_labels: 
    - "__meta_kubernetes_service_name"
    - "__meta_kubernetes_namespace"
    - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_port"
    - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_path"
    target_label: __param_target
    regex: (.+);(.+);(.+);(.+)
    replacement: $1.$2:$3$4
  - target_label: __address__
    replacement: blackbox-exporter.kube-system:9115
  - source_labels: [__param_target]
    target_label: instance
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_service_name]
    target_label: kubernetes_name
```



### 7.3.3 Prometheus 集成

```yaml
# prometheus-config.yml
kind: ConfigMap
apiVersion: v1
metadata:
  name: prometheus-config
  namespace: kube-system
data:
  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s
      external_labels:
        cluster: "kubernetes"
    scrape_configs:
    ################################## Kubernetes BlackBox DNS ###################################
    - job_name: "kubernetes-dns"
      metrics_path: /probe
      params:
        module: [dns_tcp]
      static_configs:
        - targets:
          - kube-dns.kube-system:53
          - 114.114.114.114
          - 8.8.8.8
          - 1.1.1.1
      relabel_configs:
        - source_labels: [__address__]
          target_label: __param_target
        - source_labels: [__param_target]
          target_label: instance
        - target_label: __address__
          replacement: blackbox-exporter.kube-system:9115
    ################################## Kubernetes BlackBox Services ###################################
    - job_name: 'kubernetes-services'
      metrics_path: /probe
      params:
        module:
        - "http_get_2xx"
        - "http_get_3xx"
      kubernetes_sd_configs:
      - role: service
      relabel_configs:
      - action: keep
        source_labels: [__meta_kubernetes_service_annotation_prometheus_io_http_probe]
        regex: "true"
      - action: replace
        source_labels: 
        - "__meta_kubernetes_service_name"
        - "__meta_kubernetes_namespace"
        - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_port"
        - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_path"
        target_label: __param_target
        regex: (.+);(.+);(.+);(.+)
        replacement: $1.$2:$3$4
      - target_label: __address__
        replacement: blackbox-exporter.kube-system:9115
      - source_labels: [__param_target]
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        target_label: kubernetes_name    
```

**更新配置后，强制刷新**：

```bash
curl -X POST http://192.168.80.100:30090/-/reload
```



## 7.4 部署探测 Service 示例

```yaml
# nginx-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
  annotations:
    prometheus.io/http-probe: "true"        ### 设置该服务执行HTTP探测
    prometheus.io/http-probe-port: "80"     ### 设置HTTP探测的接口
    prometheus.io/http-probe-path: "/"      ### 设置HTTP探测的地址
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 80
  selector:
    k8s-app: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: nginx
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```





## 7.5 采集指标

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-blackbox-targets.png)



## 7.6 看板

步骤1： 新增看板 

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard.png)

步骤2：导入 ID为 **`9965`** 的 `ETCD` 模板，然后加载到配置数据库

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-load-9965.png)

步骤3：选择使用上面配置的 `Prometheus` 数据库，之后点击 `Import` 按钮进入看板

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-import.png)

步骤4：监控信息页面

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/grafana-dashboard-blackbox.png)



# 8. AlertManager

## 8.1 配置

```yaml
# alertmanager-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: kube-system
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    route:
      group_by: ['instance']
      group_wait: 10s
      group_interval: 30s
      repeat_interval: 30m
      receiver: 'webhook'
    receivers:
    - name: 'webhook'
      webhook_configs:
      - url: 'http://192.168.3.3:8999'
```



## 8.2 应用

```yaml
# alertmanager-deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: kube-system
  labels:
    k8s-app: alertmanager
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: alertmanager
  template:
    metadata:
      labels:
        k8s-app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.27.0
        ports:
        - name: http
          containerPort: 9093
        args:
        - "--config.file=/etc/alertmanager/alertmanager.yml"
        - "--storage.path=/alertmanager"
        resources:
          limits:
            cpu: 1
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9093
          initialDelaySeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9093
          initialDelaySeconds: 30
          timeoutSeconds: 30
        volumeMounts:
        - name: data
          mountPath: /alertmanager 
        - name: config
          mountPath: /etc/alertmanager
      - name: configmap-reload
        image: bitnami/configmap-reload:0.13.1
        args:
        - "--volume-dir=/etc/config"
        - "--webhook-url=http://localhost:9093/-/reload"
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
          requests:
            cpu: 10m
            memory: 10Mi
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: data
        emptyDir: {}
      - name: config
        configMap:
          name: alertmanager-config
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: kube-system
  labels:
    k8s-app: alertmanager
spec:
  type: NodePort
  ports:
  - name: http
    port: 9093
    targetPort: 9093
    nodePort: 30093
  selector:
    k8s-app: alertmanager
```



## 8.3 验证

访问地址：http://192.168.3.200:30093/

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/alertmanager-ui.png)



## 8.4 告警配置

添加告警配置：

```yaml
alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets: ["alertmanager.kube-system.svc:9093"]
    
rule_files:
- /etc/prometheus/*-rule.yml  
```



更新 prometheus 配置：

```yaml
# prometheus-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: kube-system
data:
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: kube-system
data:
  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s
      external_labels:
        cluster: "kubernetes"
        
    scrape_configs:
    - job_name: prometheus
      static_configs:
      - targets: ['127.0.0.1:9090']
        labels:
          instance: prometheus
          
    - job_name: 'tke'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        replacement: '${1}:9100'
        target_label: __address__
        action: replace
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
          
    - job_name: 'cvm'
      static_configs:
      - targets: ['192.168.3.112:9100']

    - job_name: 'doris'
      static_configs: 
      - targets: ['192.168.3.126:8030']
        labels:
          group: fe 
      - targets: ['192.168.3.126:8040']
        labels:
          group: be

    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets: ["alertmanager.kube-system.svc:9093"]
        
    rule_files:
    - /etc/prometheus/*-rules.yml
    
  alert-node-rules.yml: |
    groups:
    - name: hostStats
      rules:
      - alert: HostDown
        expr: up {job=~"tke|cvm"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          description: "实例 {{ $labels.instance }} 已宕机"
          summary:  "实例 {{ $labels.instance }} 已宕机"
      - alert: HostCpuUsageAlert
        expr: sum(avg without (cpu)(irate(node_cpu_seconds_total{mode!='idle'}[5m]))) by (instance) > 0.9
        for: 1m  
        labels:
          severity: critical
        annotations:
          summary: "实例 {{ $labels.instance }} CPU 使用率过高"
          description: "实例{{ $labels.instance }} CPU 使用率超过 90% (当前值为: {{ $value }})"
      - alert: HostMemUsageAlert
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes > 0.9
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "实例 {{ $labels.instance }} 内存使用率过高"
          description: "实例 {{ $labels.instance }} 内存使用率 90% (当前值为: {{ $value }})"
      - alert: HostDiskUsageAlert
        expr: 100 - (node_filesystem_free_bytes{fstype=~"ext3|ext4|xfs"} / node_filesystem_size_bytes{fstype=~"ext3|ext4|xfs"} * 100) > 95
        for: 5m  
        labels:
          severity: critical
        annotations:
          summary: "实例 {{ $labels.instance }} 磁盘使用率过高"
          description: "实例 {{ $labels.instance }} 磁盘使用率超过95% (当前值为: {{ $value }})"

  alert-doris-rules.yml: |
    groups:
    - name: dorisBeAlert
      rules:
      - alert: BeDown
        expr: up {group="be", job="doris"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Doris BE {{ $labels.instance }} 宕机"
          description: "Doris BE {{ $labels.instance }} 宕机"
      - alert: TcMalloc
        expr: doris_be_memory_allocated_bytes / 1024 / 1024 / 1024 > 80
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} TcMalloc 占用的虚拟内存的大小过高"
          description: "Doris BE {{ $labels.instance }} TcMalloc 占用的虚拟内存的大小超过80%，(当前值为: {{ $value }})"
      - alert: CompactionScore
        expr: max by(instance, backend, job) (doris_fe_tablet_max_compaction_score) > 80
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} compaction score 超过80%"
          description: "Doris BE {{ $labels.instance }} compaction score 超过80%，(当前值为: {{ $value }})"
      - alert: BatchTaskQueue
        expr: doris_be_add_batch_task_queue_size{group="be"} > 10
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} 接收导入batch的线程池队列大小超过10"
          description: "Doris BE {{ $labels.instance }} 接收导入batch的线程池队列大小超过10，(当前值为: {{ $value }})"
      - alert: CompactionTaskNum
        expr: sum by(instance) (doris_be_disks_compaction_num{group="be",job="doris"}) > 15
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} 目录下的compaction任务总数超过15"
          description: "Doris BE {{ $labels.instance }} 目录下的compaction任务总数超过15，(当前值为: {{ $value }})"
      - alert: LoadTaskChannels
        expr: doris_be_load_channel_count{group="be",job="doris"} > 10
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} 打开导入任务的Channel数超过10个"
          description: "Doris BE {{ $labels.instance }} 打开导入任务的Channel数超过10个，(当前值为: {{ $value }})"
      - alert: BeRateOfCacheMoreThan0.8
        expr: doris_be_cache_usage_ratio > 0.8
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} LRU Cache 的使用率大于80%"
          description: "Doris BE {{ $labels.instance }} LRU Cache 的使用率大于80%，(当前值为: {{ $value }})"
      - alert: BeDiskAvailCapacityLessThan1G
        expr: node_filesystem_free_bytes{mountpoint="/data"} < (1024*1024*1024)
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris BE {{ $labels.instance }} 数据目录所在磁盘的剩余空间小于1G"
          description: "Doris BE {{ $labels.instance }} 数据目录所在磁盘的剩余空间小于1G，(当前值为: {{ $value }})"
      - alert: BeDiskStatusAbnormal
        expr: doris_be_disks_state == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Doris BE {{ $labels.instance }} 数据目录的磁盘状态异常"
          description: "Doris BE {{ $labels.instance }} 数据目录的磁盘状态异常"
    - name: dorisFeAlert
      rules:
      - alert: FeDown
        expr: up {group="fe", job="doris"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Doris FE {{ $labels.instance }} 宕机"
          description: "Doris FE {{ $labels.instance }} 宕机"
      - alert: FeConnectionMoreThan1000
        expr: doris_fe_connection_total > 1000       
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris FE {{ $labels.instance }} MySQL客户端连接数超过1000"
          description: "Doris FE {{ $labels.instance }} MySQL客户端连接数超过1000，(当前值为: {{ $value }})"
      - alert: FeQpsMoreThan500
        expr: rate(doris_fe_query_total[1m])>500 
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris FE {{ $labels.instance }} QPS超过500"
          description: "Doris FE {{ $labels.instance }} QPS超过500，(当前值为: {{ $value }})"
      - alert: FeRateOfActiveThreadMoreThan0.8
        expr: (doris_fe_thread_pool_active_threads/doris_fe_thread_pool_size) > 0.8 
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris FE {{ $labels.instance }} 线程池使用占用比例超过80%"
          description: "Doris FE {{ $labels.instance }} 线程池使用占用比例超过80%，(当前值为: {{ $value }})"
      - alert: FeRateOfJVMUsedMemMoreThan0.8
        expr: (jvm_memory_heap_used_bytes/jvm_memory_heap_max_bytes) > 0.8
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris FE {{ $labels.instance }} JVM内存使用占用比例超过80%"
          description: "Doris FE {{ $labels.instance }} JVM内存使用占用比例超过80%，(当前值为: {{ $value }})"
      - alert: FeRateOfNodeAvailableMemLessThan0.2
        expr: (node_memory_MemAvailable/node_memory_MemTotal)<0.2
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Doris FE {{ $labels.instance }} 可用内存占比少于20%"
          description: "Doris FE {{ $labels.instance }} 可用内存占比少于20%，(当前值为: {{ $value }})"
```



