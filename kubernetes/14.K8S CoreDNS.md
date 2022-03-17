# 1. Kube-dns

## 1.1 概述

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/kube-dns.png) 

KubeDNS 由三部分构成：

- kube-dns：核心组件
  - KubeDNS：依赖 `client-go` 中的 informer 机制，监听 Service 和 Endpoint 的变化情况，并将相关信息更新到 SkyDNS 中
  - SkyDNS：负责 DNS 解析，监听在 10053 端口，同时也监听在 10055 端口提供 metrics 服务
- dnsmasq：区分 Domain 是集群内部还是外部，**给外部域名提供上游解析，内部域名发往10053端口**，并将解析结构缓存，提高解析效率
  - dnsmasq-nanny：容器里的1号进程，不负责处理 DNS LookUp 请求，只负责管理 dnsmasq
  - dnsmasq：负责处理 DNS LookUp 请求，并缓存结果

- sidecar: 对 kube-dns和dnsmasq进行监控检查和收集监控指标



## 1.2 创建 RBAC

```yaml
# kube-dns-rbac.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-dns
rules:
  - apiGroups:
    - ""
    resources:
    - endpoints
    - services
    verbs:
    - get
    - list
    - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-dns
subjects:
- kind: ServiceAccount
  name: kube-dns
  namespace: kube-system
```



## 1.3 部署 kube-dns

```yaml
# kube-dns-deploy.yml
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.0.0.2
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  # replicas: not specified here:
  # 1. In order to make Addon Manager do not reconcile this replicas parameter.
  # 2. Default is 1.
  # 3. Will be tuned in real time if DNS horizontal auto-scaling is turned on.
  strategy:
    rollingUpdate:
      maxSurge: 10%
      maxUnavailable: 0
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        prometheus.io/port: "10054"
        prometheus.io/scrape: "true"
    spec:
      priorityClassName: system-cluster-critical
      securityContext:
        seccompProfile:
          type: RuntimeDefault
        supplementalGroups: [ 65534 ]
        fsGroup: 65534
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: k8s-app
                    operator: In
                    values: ["kube-dns"]
              topologyKey: kubernetes.io/hostname
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
      volumes:
      - name: kube-dns-config
        configMap:
          name: kube-dns
          optional: true
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: kubedns
        image: k8s.gcr.io/dns/k8s-dns-kube-dns:1.17.3
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        livenessProbe:
          httpGet:
            path: /healthcheck/kubedns
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 3
          timeoutSeconds: 5
        args:
        - --domain=cluster.local.
        - --dns-port=10053
        - --config-dir=/kube-dns-config
        - --v=2
        env:
        - name: PROMETHEUS_PORT
          value: 10055
        ports:
        - containerPort: 10053
          name: dns-local
          protocol: UDP
        - containerPort: 10053
          name: dns-tcp-local
          protocol: TCP
        - containerPort: 10055
          name: metrics
          protocol: TCP
        volumeMounts:
        - name: kube-dns-config
          mountPath: /kube-dns-config
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsUser: 1001
          runAsGroup: 1001
      - name: dnsmasq
        image: k8s.gcr.io/dns/k8s-dns-dnsmasq-nanny:1.17.3
        livenessProbe:
          httpGet:
            path: /healthcheck/dnsmasq
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - -v=2
        - -logtostderr
        - -configDir=/etc/k8s/dns/dnsmasq-nanny
        - -restartDnsmasq=true
        - --
        - -k
        - --cache-size=1000
        - --no-negcache
        - --dns-loop-detect
        - --log-facility=-
        - --server=/cluster.local/127.0.0.1#10053
        - --server=/in-addr.arpa/127.0.0.1#10053
        - --server=/ip6.arpa/127.0.0.1#10053
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        # see: https://github.com/kubernetes/kubernetes/issues/29055 for details
        resources:
          requests:
            cpu: 150m
            memory: 20Mi
        volumeMounts:
        - name: kube-dns-config
          mountPath: /etc/k8s/dns/dnsmasq-nanny
        securityContext:
          capabilities:
            drop:
              - all
            add:
              - NET_BIND_SERVICE
              - SETGID
      - name: sidecar
        image: k8s.gcr.io/dns/k8s-dns-sidecar:1.17.3
        livenessProbe:
          httpGet:
            path: /metrics
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - --v=2
        - --logtostderr
        - --probe=kubedns,127.0.0.1:10053,kubernetes.default.svc.cluster.local,5,SRV
        - --probe=dnsmasq,127.0.0.1:53,kubernetes.default.svc.cluster.local,5,SRV
        ports:
        - containerPort: 10054
          name: metrics
          protocol: TCP
        resources:
          requests:
            memory: 20Mi
            cpu: 10m
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsUser: 1001
          runAsGroup: 1001
      dnsPolicy: Default  # Don't use cluster DNS.
      serviceAccountName: kube-dns
```



## 1.4 验证结果 

```bash
$ kubectl apply -f kube-dns-rbac.yml
$ kubectl apply -f kube-dns-deploy.yml

$ kubectl get pod -n kube-system -o wide | grep kube-dns
kube-dns-594c5b5cb5-6wttp   3/3     Running   0          13m     10.244.2.29     k8s-node1     <none>           <none>

$ kubectl describe pod kube-dns-594c5b5cb5-mdxp6 -n kube-system
...
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  48s   default-scheduler  Successfully assigned kube-system/kube-dns-594c5b5cb5-6wttp to k8s-node1
  Normal  Pulled     47s   kubelet            Container image "k8s.gcr.io/dns/k8s-dns-kube-dns:1.17.3" already present on machine
  Normal  Created    47s   kubelet            Created container kubedns
  Normal  Started    47s   kubelet            Started container kubedns
  Normal  Pulled     47s   kubelet            Container image "k8s.gcr.io/dns/k8s-dns-dnsmasq-nanny:1.17.3" already present on machine
  Normal  Created    47s   kubelet            Created container dnsmasq
  Normal  Started    47s   kubelet            Started container dnsmasq
  Normal  Pulled     47s   kubelet            Container image "k8s.gcr.io/dns/k8s-dns-sidecar:1.17.3" already present on machine
  Normal  Created    47s   kubelet            Created container sidecar
  Normal  Started    47s   kubelet            Started container sidecar
```



## 1.5 私有和上游 DNS 服务器

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {“acme.local”: [“1.2.3.4”]}
  upstreamNameservers: |
    [“8.8.8.8”, “8.8.4.4”]
```

查询请求首先会被发送到 kube-dns 的 DNS 缓存层 (Dnsmasq 服务器)。Dnsmasq 服务器会先检查请求的后缀，带有集群后缀（例如：”.cluster.local”）的请求会被发往 kube-dns，拥有存根域后缀的名称（例如：”.acme.local”）将会被发送到配置的私有 DNS 服务器 [“1.2.3.4”]。最后，不满足任何这些后缀的请求将会被发送到上游 DNS [“8.8.8.8”, “8.8.4.4”] 里。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/kube-dns-upstream.png)

## 1.6 优缺点

**优点**：依赖 dnsmasq ，性能有保障

**缺点**：

- dnsmasq-nanny 通过kill 来重启 dnsmasq，简单粗暴，可能导致这段时间内大量的 DNS 请求失败

- dnsmasq-nanny 检测文件的方式，可能会导致以下问题：

  - 每次遍历目录下的所有文件，然后用 ioutil.ReadFile 读取文件内容。如果目录下文件数量过多，可能出现在遍历的同时文件也在被修改，遍历的速度跟不上修改的速度。 这样可能导致遍历完了，某个配置文件才更新完。那么此时，你读取的一部分文件数据并不是和当前目录下文件数据完全一致，本次会重启 dnsmasq。进而，下次检测，还认为有文件变化，到时候，又重启一次 dnsmasq。

  - 文件的检测，直接使用 ioutil.ReadFile 读取文件内容，也存在问题。如果文件变化，和文件读取同时发生，很可能你读取完，文件的更新都没完成，那么你读取的并非一个完整的文件，而是坏的文件，这种文件，dnsmasq-nanny 无法做解析，不过官方代码中有数据校验，解析失败也问题不大，大不了下个周期的时候，再取到完整数据，再解析一次。



# 2. CoreDNS

## 2.1 概述

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/core-dns.png)

CoreDNS 使用Caddy作为底层的 Web Server，它是一个轻量易用的Web服务器，支持 HTTP、HTTPS、HTTP/2、GRPC 等多种连接方式

与 KubeDNS 相比，CoreDNS 的效率更高，资源占用更小



## 2.2 部署 CoreDNS

```bash
wget https://github.com/coredns/deployment/archive/refs/tags/coredns-1.14.0.tar.gz
tar zxvf coredns-1.14.0.tar.gz
cd deployment-coredns-1.14.0/kubernetes

# 部署
./deploy.sh | kubectl apply -f -
kubectl delete --namespace=kube-system deployment kube-dns

# 卸载
./rollback.sh | kubectl apply -f -
kubectl delete --namespace=kube-system deployment coredns
```



## 2.3 DNS 格式

- Service
  - A record：`${my-svc}.${my-namespace}.svc.cluster.local`
    - 普通 Service 解析为 Cluster IP
    - Headless Service 解析为指定的 Pod IP 列表
  - SRV record: `_${my-port-name}._${my-port-protocol}.${my-svc}.${my-namespace}.svc.cluster.local`

- Pod
  - A record: `${pod-ip-address}.${my-namespace}.pod.cluster.local`
  - 指定 hostname 和 subdomain: `${hostname}.${subdomain}.${my-namespace}.svc.cluster.local`
    - hostname: pod-name
    - subdomain: **same as service.name**

示例：

```yaml
# nginx-dns-test.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      hostname: web
      subdomain: nginx
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
kind: Service
apiVersion: v1
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  clusterIP: None
  ports:
  - protocol: "TCP"
    port: 80
    targetPort: 80
```

验证：

```bash
$ kubectl get pod -l app=nginx -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
nginx-deploy-64bc9cddcf-p56qr   1/1     Running   0          15s   10.244.1.36   k8s-node01   <none>           <none>
nginx-deploy-64bc9cddcf-rq49v   1/1     Running   0          15s   10.244.2.34   k8s-node02   <none>           <none>
nginx-deploy-64bc9cddcf-xdwh6   1/1     Running   0          15s   10.244.1.35   k8s-node01   <none>           <none>

$ kubectl exec -it nginx-deploy-57776d9cd4-vkz7b -- /bin/sh
# cat /etc/resolv.conf
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local 8.8.8.8
options ndots:5
# hostname
web

$ kubectl run -it dns-test --rm --image=e2eteam/dnsutils:1.1 -- /bin/sh
/ # nslookup nginx
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   nginx.default.svc.cluster.local
Address: 10.244.1.35
Name:   nginx.default.svc.cluster.local
Address: 10.244.1.36
Name:   nginx.default.svc.cluster.local
Address: 10.244.2.34

/ # dig @10.96.0.10 -t A nginx.default.svc.cluster.local
...
;; ANSWER SECTION:
nginx.default.svc.cluster.local. 30 IN  A       10.244.1.35
nginx.default.svc.cluster.local. 30 IN  A       10.244.1.36
nginx.default.svc.cluster.local. 30 IN  A       10.244.2.34

/ # dig @10.96.0.10 10-244-1-35.default.pod.cluster.local
...
;; ANSWER SECTION:
10-244-1-35.default.pod.cluster.local. 30 IN A  10.244.1.35

# 指定hostname
/ # dig @10.96.0.10 -t A web.nginx.default.svc.cluster.local
...
;; ANSWER SECTION:
web.nginx.default.svc.cluster.local. 30 IN A    10.244.2.34
web.nginx.default.svc.cluster.local. 30 IN A    10.244.1.35
web.nginx.default.svc.cluster.local. 30 IN A    10.244.1.36
```



## 2.4 Corefile

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/core-dns-corefile.png)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }  
```

CoreDNS [插件](https://coredns.io/plugins/)：

- errors：错误记录输出到标准输出

- health：健康报告 http://localhost:8080/health 

- ready：就绪检测，HTTP访问端口 :8181，返回 200 代表OK

- kubernetes：将基于 Kubernetes 的服务和 Pod 的 IP 答复 DNS 查询
  - `pods insecure`：兼容kube-dns，该选项仅当在相同的命名空间中存在与IP匹配的pod时才返回A记录。如果不使用pod记录，可以使用`pods disabled`选项。
  - ttl：响应的TTL时间，默认5s，范围 0~3600
- prometheus：度量指标值以 Prometheus 格式在 http://localhost:9153/metrics 上提供
- forward: 不在 Kubernetes 集群域内的任何查询都将转发到 预定义的解析器 (/etc/resolv.conf)
- cache：启用前端缓存
- loop：检测到简单的转发环，如果发现死循环，则中止 CoreDNS 进程
- reload：允许自动重新加载已更改的 Corefile。 编辑 ConfigMap 配置后，请等待两分钟，以使更改生效。
- loadbalance：这是一个轮转式 DNS 负载均衡器， 它在应答中随机分配 A、AAAA 和 MX 记录的顺序。



 ## 2.5 CoreDNS 域名解析方案

### 2.5.1 配置存根域

如果集群操作员在 10.150.0.1 处运行了 Consul 域服务器， 且所有 Consul 名称都带有后缀 `.consul.local`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    consul.local:53 {
        errors
        cache 30
        forward . 10.150.0.1
    }   
```



### 2.5.2 Hosts，自定义域名

修改配置文件，将自定义域名添加到hosts中，可以添加任意解析记录，类似在本地/etc/hosts中添加解析记录。

```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |-
    .:53 {
        errors
        health
        hosts {
            192.168.100.1 tplink.cc
            fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        ready
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```



### 2.5.3 Rewrite，服务别名

将指定域名解析到某个 Service 的域名，即给Service取了个别名，指向域名到集群内服务

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |-
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        rewrite name api.elihe.io nginx.default.svc.cluster.local
        prometheus :9153
        ready
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```



### 2.5.4 Forward，级联DNS

修改配置文件，将forward后面的/etc/resolv.conf，改成外部DNS的地址，将自建 DNS 设为上游 DNS

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |-
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        rewrite name example.com nginx.default.svc.cluster.local
        prometheus :9153
        ready
        forward . 192.168.1.1
        cache 30
        loop
        reload
        loadbalance
    }
```



## 2.6 与 KubeDNS 比较

- CoreDNS 每个实例只有一个容器，而 Kube-DNS 有三个
- Kube-DNS 使用 dnsmasq 进行缓存，它是一个 C 线程。Core-DNS 使用 Go 开发，
- CoreDNS 默认使用 negative caching，它的缓存的效率不如 dnsmasq，对集群内部域名解析的速度不如 kube-dns



# 3. 补充：DNS 解析依赖

DNS 解析会依赖 `/etc/host.conf` 、 `/etc/hosts` 和 `/etc/resolv.conf` 这个三个文件

```bash
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

