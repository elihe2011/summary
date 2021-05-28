# 1. kube-dns 

## 1.1 工作原理

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-dns-procedure.png) 

kube-dns 由三个容器构成：

- kube-dns: 核心组件
  - KubeDNS：负责监听 Service 和 Endpoint 的变化情况，并将相关信息更新到 Sky DNS 中
  - SkyDNS: 负责 DNS 解析，监听在 10053 端口，同时也监听在 10055 端口提供 metrics 服务
  - kube-dns 还监听在 8081 端口，提供健康检查使用
- dnsmasq-nanny: 负责启动 dnsmasq，配置发生变化时，重启 dnsmasq
  - dnsmasq 的 upstream 为 SkyDNS，即集群内部的 DNS 解析由 SkyDNS 负责
- sidecar: 负责健康检查和 提供 DNS metrics （10054端口）



## 1.1 使用 kube-dns

### 1.1.1 创建 kube-dns

```bash
cat > kube-dns.yaml <<EOF
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
          value: "10055"
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
EOF

kubectl apply -f kube-dns.yaml
kubectl get pod -n kube-system
```



### 1.1.2 问题定位

```bash
# 发现问题
kubectl describe pod kube-dns-594c5b5cb5-mdxp6 -n kube-system
...
  Normal   Pulled     13m                   kubelet            Container image "k8s.gcr.io/dns/k8s-dns-kube-dns:1.17.3" already present on machine
  Warning  Unhealthy  12m (x2 over 13m)     kubelet            Liveness probe failed: HTTP probe failed with statuscode: 503
  Warning  Unhealthy  9m32s (x25 over 13m)  kubelet            Readiness probe failed: Get "http://10.244.2.28:8081/readiness": dial tcp 10.244.2.28:8081: connect: connection refused
  Warning  BackOff    4m30s (x19 over 10m)  kubelet            Back-off restarting failed container

# 查看容器日志
kubectl logs  kube-dns-594c5b5cb5-mdxp6 kubedns -n kube-system
...
I0520 05:59:53.947378       1 server.go:195] Skydns metrics enabled (/metrics:10055)
I0520 05:59:53.947996       1 log.go:172] skydns: ready for queries on cluster.local. for tcp://0.0.0.0:10053 [rcache 0]
I0520 05:59:53.948005       1 log.go:172] skydns: ready for queries on cluster.local. for udp://0.0.0.0:10053 [rcache 0]
E0520 05:59:53.957842       1 reflector.go:125] pkg/mod/k8s.io/client-go@v0.0.0-20190620085101-78d2af792bab/tools/cache/reflector.go:98: Failed to list *v1.Service: services is forbidden: User "system:serviceaccount:kube-system:kube-dns" cannot list resource "services" in API group "" at the cluster scope: RBAC: clusterrole.rbac.authorization.k8s.io "system:kube-dns" not found
E0520 05:59:53.957894       1 reflector.go:125] pkg/mod/k8s.io/client-go@v0.0.0-20190620085101-78d2af792bab/tools/cache/reflector.go:98: Failed to list *v1.Endpoints: endpoints is forbidden: User "system:serviceaccount:kube-system:kube-dns" cannot list resource "endpoints" in API group "" at the cluster scope: RBAC: clusterrole.rbac.authorization.k8s.io "system:kube-dns" not found
I0520 05:59:54.447988       1 dns.go:220] Waiting for [endpoints services] to be initialized from apiserver...
```

**问题根因**：rbac "system:kube-dns" 未找到，导致无法访问apiserver



### 1.1.3 解决办法

```
# 创建 rbac
cat > kube-dns-rbac.yaml <<EOF
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
EOF

kubectl apply -f kube-dns-rbac.yaml

kubectl describe clusterrole system:kube-dns
kubectl describe clusterrolebinding system:kube-dns
```



### 1.1.4 验证成功

```bash
kubectl apply -f kube-dns.yaml
kubectl apply -f kube-dns.yaml

kubectl get pod -n kube-system -o wide | grep kube-dns
kube-dns-594c5b5cb5-6wttp   3/3     Running   0          13m     10.244.2.29     k8s-node1     <none>           <none>

kubectl describe pod kube-dns-594c5b5cb5-mdxp6 -n kube-system
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



# 2. CoreDNS

kube-dns 的升级版。CoreDNS 的效率更高，资源占用更小



## 2.1 安装 coredns

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



## 2.2 支持的 DNS 格式

- Service
  - A record：`${my-svc}.${my-namespace}.svc.cluster.local`，解析分两种情况
    - 普通 Service 解析为 Cluster IP
    - Headless Service 解析为指定的 Pod IP 列表
  - SRV record: `_${my-port-name}._${my-port-protocol}${my-svc}.${my-namespace}.svc.cluster.local`

- Pod
  - A record: `${pod-ip-address}.${my-namespace}.pod.cluster.local`
  - 指定 hostname 和 subdomain: `${hostname}.${custom-subdomain}.default.svc.cluster.local`

示例：

```bash
cat > dns-test.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  hostname: nginx
  subdomain: default-subdomain
  containers:
  - name: nginx
    image: nginx
    ports:
    - name: http
      containerPort: 80 
---
apiVersion: v1
kind: Pod
metadata:
  name: dnsutils
  labels:
    name: dnsutils
spec:
  containers:
  - image: tutum/dnsutils
    command:
      - sleep
      - "7200"
    name: dnsutils
EOF

kubectl apply -f nginx-pod.yaml

kubectl exec -it dnsutils /bin/sh
```



# 3. 私有和上游 DNS 服务器

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

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-dns-upstream.png) 





































