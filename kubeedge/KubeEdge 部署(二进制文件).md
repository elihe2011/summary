# 1. 环境准备

## 1.1 安装规划

| 角色       | IP            | 组件                                                         |
| ---------- | ------------- | ------------------------------------------------------------ |
| k8s-master | 192.168.3.194 | etcd, api-server, controller-manager, scheduler, kubelet, kube-proxy,docker, cloudcore |
| k8s-node01 | 192.168.3.195 | kubelet, kube-proxy, docker                                  |
| ke-edge001 | 192.168.3.196 | docker, edgecore, mosquitto                                  |



软件版本：

| 软件       | 版本               | 备注             |
| ---------- | ------------------ | ---------------- |
| OS         | Ubuntu 18.04.1 LTS |                  |
| Kubernetes | v1.22.6            | GPaaS 版本1.21.4 |
| Etcd       | v3.5.0             |                  |
| Docker     | 20.10.9            |                  |
| KubeEdge   | v1.12.0            |                  |



## 1.2 系统设置

```bash
# 1. 修改主机名
hostnamectl set-hostname k8s-master
hostnamectl set-hostname k8s-node01
hostnamectl set-hostname ke-edge001

# 2. 禁用 swap
swapoff -a && sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab

# 3. 将桥接的IPv4流量传递到iptables的链 
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
#net.ipv4.tcp_tw_recycle=0           # 表示开启TCP连接中TIME-WAIT sockets的快速回收，默认为0，表示关闭
vm.swappiness=0                     # 禁止使用 swap 空间，只有当系统 OOM 时才允许使用它
vm.overcommit_memory=1              # 不检查物理内存是否够用
fs.inotify.max_user_instances=8192  # 开启 OOM
vm.panic_on_oom=0 
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
EOF

sysctl -p /etc/sysctl.d/kubernetes.conf

# 4. 时间同步 
apt install ntpdate -y 
ntpdate ntp1.aliyun.com

crontab -e
*/30 * * * * /usr/sbin/ntpdate -u ntp1.aliyun.com >> /var/log/ntpdate.log 2>&1

# 5. 开启 ipvs
lsmod|grep ip_vs

for i in $(ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*"); do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i; done

ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" >> /etc/modules

# 6. 安装 ipvsadm
apt install ipvsadm ipset -y

# 7. 主机解析
cat >> /etc/hosts <<EOF
192.168.3.194 k8s-master
192.168.3.195 k8s-node01
192.168.3.196 ke-edge001
EOF
```



# 2. 安装 docker


```bash
mkdir -p $HOME/k8s-install && cd $_

# 1. 下载安装包 (注意选择安装包)
wget https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz 
wget https://download.docker.com/linux/static/stable/aarch64/docker-20.10.21.tgz

tar zxvf docker-20.10.21.tgz
mv docker/* /usr/local/bin
docker version

# 2. 开机启动配置
cat > /lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

# 3. 启动
systemctl daemon-reload
systemctl start docker
systemctl status docker
systemctl enable docker
```



# 3. 安装 Kubernetes 集群

## 3.1 证书

:warning: 以下操作在 **k8s-master** 节点上操作



### 3.1.1 证书类型


| 组件               | 证书                                | 密钥                                        | 备注             |
| ------------------ | ----------------------------------- | ------------------------------------------- | ---------------- |
| etcd               | ca.pem、etcd.pem                    | etcd-key.pem                                |                  |
| apiserver          | ca.pem、apiserver.pem               | apiserver-key.pem                           |                  |
| controller-manager | ca.pem、kube-controller-manager.pem | ca-key.pem、kube-controller-manager-key.pem | kubeconfig       |
| scheduler          | ca.pem、kube-scheduler.pem          | kube-scheduler-key.pem                      | kubeconfig       |
| kubelet            | ca.pem                              |                                             | kubeconfig+token |
| kube-proxy         | ca.pem、kube-proxy.pem              | kube-proxy-key.pem                          | kubeconfig       |
| kubectl            | ca.pem、admin.pem                   | admin-key.pem                               |                  |



### 3.1.2 证书工具

下载地址：https://github.com/cloudflare/cfssl/releases， 注意：arm64 平台的工具需要自行编译

已编译好的工具包：`\\192.168.3.239\share\04-软件部归档\OICT系统集成\ARM64\pkgs\cfssl-1.6.0-arm64.tar.gz`

```bash
tar zxvf cfssl-1.6.0-arm64.tar.gz -C /

chmod +x /usr/local/bin/cfssl*
```




### 3.1.3 CA 证书 

CA: Certificate Authority

```bash
mkdir -p ~/ssl && cd $_

# 1. CA 配置文件
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF

# 2. CA 证书签名请求文件
cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ],
    "ca": {
       "expiry": "87600h"
    }
}
EOF

# 3. 生成CA证书和密钥
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

ls  ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```



### 3.1.4 etcd 证书

注意：hosts 中的IP地址，分别指定了 `etcd` 集群的主机 IP

```bash
# 1. 证书签名请求文件
cat > etcd-csr.json <<EOF
{
    "CN": "etcd",
    "hosts": [
      "127.0.0.1",
      "localhost",
      "192.168.3.194",
      "192.168.3.195",
      "192.168.3.196"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "etcd",
            "OU": "System"
        }
    ]
}
EOF

# 2. 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
```



### 3.1.5 kube-apiserver 证书

注意：hosts 中的IP地址，分别指定了 `kubernetes master` 集群的主机 IP 和 **`kubernetes` 服务的服务 IP**（一般是 `kube-apiserver` 指定的 `service-cluster-ip-range` 网段的第一个IP，如 10.96.0.1）

```bash
# 1. 证书签名请求文件
cat > kube-apiserver-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "localhost",
      "192.168.3.194",
      "192.168.3.195",
      "192.168.3.196",
      "10.96.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# 2. 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-apiserver-csr.json | cfssljson -bare kube-apiserver
```



### 3.1.6 kube-controller-manager 证书

```bash
# 1. 证书签名请求文件
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

# 2. 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
```



### 3.1.8 kube-scheduler 证书

```bash
# 1. 证书签名请求文件
cat > kube-scheduler-csr.json << EOF
{
  "CN": "system:kube-scheduler",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

# 2. 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```



### 3.1.9 admin 证书

- 后续 `kube-apiserver` 使用 `RBAC` 对客户端(如 `kubelet`、`kube-proxy`、`Pod`)请求进行授权；
- `kube-apiserver` 预定义了一些 `RBAC` 使用的 `RoleBindings`，如 `cluster-admin` 将 Group `system:masters` 与 Role `cluster-admin` 绑定，该 Role 授予了调用`kube-apiserver` 的**所有 API**的权限；
- O 指定该证书的 Group 为 `system:masters`，`kubelet` 使用该证书访问 `kube-apiserver` 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 `system:masters`，所以被授予访问所有 API 的权限；

```bash
# 1. 证书签名请求文件
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

# 2. 生成证书 
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

搭建完 kubernetes 集群后，可以通过命令: `kubectl get clusterrolebinding cluster-admin -o yaml` ,查看到 `clusterrolebinding cluster-admin` 的 subjects 的 kind 是 Group，name 是 `system:masters`。 `roleRef` 对象是 `ClusterRole cluster-admin`。 即 `system:masters Group` 的 user 或者 `serviceAccount` 都拥有 `cluster-admin` 的角色。 因此在使用 kubectl 命令时候，才拥有整个集群的管理权限。

```bash
kubectl get clusterrolebinding cluster-admin -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: 2017-04-11T11:20:42Z
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
  resourceVersion: "52"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/cluster-admin
  uid: e61b97b2-1ea8-11e7-8cd7-f4e9d49f8ed0
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:masters
```



### 3.1.10 kube-proxy 证书

- CN 指定该证书的 User 为 `system:kube-proxy`；
- `kube-apiserver` 预定义的 RoleBinding `system:node-proxier` 将User `system:kube-proxy` 与 Role `system:node-proxier` 绑定，该 Role 授予了调用 `kube-apiserver` Proxy 相关 API 的权限；

```bash
# 1. 证书签名请求文件
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

# 2. 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
```



### 3.1.11 分发证书

```bash
mkdir -p /etc/kubernetes/pki
cp *.pem /etc/kubernetes/pki
```



## 3.2 安装 etcd  (单节点)

:warning: 以下操作在 **k8s-master** 节点上操作

```bash
# 1. 下载并安装
wget https://github.com/etcd-io/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-arm64.tar.gz
tar zxvf etcd-v3.5.0-linux-arm64.tar.gz

mv etcd-v3.5.0-linux-arm64/{etcd,etcdctl} /usr/local/bin/

# 2. 配置文件
mkdir -p /etc/etcd
cat > /etc/etcd/etcd.conf.yml << EOF
name: 'etcd-1'
data-dir: /var/lib/etcd/default.etcd
wal-dir:
snapshot-count: 10000
heartbeat-interval: 100
election-timeout: 1000
quota-backend-bytes: 0
listen-peer-urls: 'https://localhost:2380,https://192.168.3.194:2380'
listen-client-urls: 'https://localhost:2379,https://192.168.3.194:2379'
max-snapshots: 5
max-wals: 5
cors:
initial-advertise-peer-urls: 'https://localhost:2380,https://192.168.3.194:2380'
advertise-client-urls: 'https://localhost:2379,https://192.168.3.194:2379'
discovery:
discovery-fallback: 'proxy'
discovery-proxy:
discovery-srv:
strict-reconfig-check: false
enable-v2: true
enable-pprof: true
proxy: 'off'
proxy-failure-wait: 5000
proxy-refresh-interval: 30000
proxy-dial-timeout: 1000
proxy-write-timeout: 5000
proxy-read-timeout: 0

client-transport-security:
  cert-file: /etc/kubernetes/pki/etcd.pem
  key-file: /etc/kubernetes/pki/etcd-key.pem
  client-cert-auth: true
  trusted-ca-file: /etc/kubernetes/pki/ca.pem
  auto-tls: true

peer-transport-security:
  cert-file: /etc/kubernetes/pki/etcd.pem
  key-file: /etc/kubernetes/pki/etcd-key.pem
  client-cert-auth: true
  trusted-ca-file: /etc/kubernetes/pki/ca.pem
  auto-tls: true

log-level: debug
logger: zap
log-outputs: [stderr]
force-new-cluster: false
auto-compaction-mode: periodic
auto-compaction-retention: "1"
EOF

# 3. 开机启动
cat > /lib/systemd/system/etcd.service << EOF
[Unit]
Description=Etcd Server
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd --config-file=/etc/etcd/etcd.conf.yml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 4. 启动
systemctl daemon-reload
systemctl start etcd
systemctl status etcd
systemctl enable etcd

# 5. 运行状态
etcdctl member list --cacert=/etc/kubernetes/pki/ca.pem --cert=/etc/kubernetes/pki/etcd.pem --key=/etc/kubernetes/pki/etcd-key.pem --write-out=table

# 6. 健康状态
etcdctl endpoint health --cacert=/etc/kubernetes/pki/ca.pem --cert=/etc/kubernetes/pki/etcd.pem --key=/etc/kubernetes/pki/etcd-key.pem --cluster --write-out=table
```



## 3.3 Master 节点

:warning: 以下操作在 **k8s-master** 节点上操作

kubernetes master 节点组件：

- kube-apiserver
- kube-scheduler
- kube-controller-manager
- kubelet （非必须，但必要）
- kube-proxy（非必须，但必要）



### 3.3.1 安装准备

https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.22.md

```bash
wget https://dl.k8s.io/v1.22.17/kubernetes-server-linux-arm64.tar.gz
tar zxvf kubernetes-server-linux-arm64.tar.gz

cd kubernetes/server/bin
cp kube-apiserver kube-scheduler kube-controller-manager kubectl kubelet kube-proxy /usr/bin
cp kube-{apiserver,scheduler,controller-manager,proxy} kubectl kubelet /usr/local/bin
```



### 3.3.2 apiserver

#### 3.3.2.1 TLS Bootstrapping Token

**启用 TLS Bootstrapping 机制：**

TLS Bootstraping：Master apiserver启用TLS认证后，Node节点kubelet和kube-proxy要与kube-apiserver进行通信，必须使用CA签发的有效证书才可以，当Node节点很多时，这种客户端证书颁发需要大量工作，同样也会增加集群扩展复杂度。为了简化流程，Kubernetes引入了TLS bootstraping机制来自动颁发客户端证书，kubelet会以一个低权限用户自动向apiserver申请证书，kubelet的证书由apiserver动态签署。所以强烈建议在Node上使用这种方式，目前主要用于kubelet，kube-proxy还是由我们统一颁发一个证书。

`TLS bootstraping` 工作流程：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-tls-bootstrap.png)

```bash
BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

# 格式：token，用户名，UID，用户组
cat > /etc/kubernetes/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:node-bootstrapper"
EOF
```



#### 3.3.2.2 开机启动

`--service-cluster-ip-range=10.96.0.0/16`: Service IP 段

```bash
KUBE_APISERVER_OPTS="--enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --anonymous-auth=false \
  --bind-address=192.168.3.194 \
  --secure-port=6443 \
  --advertise-address=192.168.3.194 \
  --authorization-mode=Node,RBAC \
  --runtime-config=api/all=true \
  --enable-bootstrap-token-auth \
  --service-cluster-ip-range=10.96.0.0/16 \
  --token-auth-file=/etc/kubernetes/token.csv \
  --service-node-port-range=30000-50000 \
  --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.pem  \
  --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver-key.pem \
  --client-ca-file=/etc/kubernetes/pki/ca.pem \
  --kubelet-client-certificate=/etc/kubernetes/pki/kube-apiserver.pem \
  --kubelet-client-key=/etc/kubernetes/pki/kube-apiserver-key.pem \
  --service-account-key-file=/etc/kubernetes/pki/ca-key.pem \
  --service-account-signing-key-file=/etc/kubernetes/pki/ca-key.pem  \
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \
  --etcd-cafile=/etc/kubernetes/pki/ca.pem \
  --etcd-certfile=/etc/kubernetes/pki/etcd.pem \
  --etcd-keyfile=/etc/kubernetes/pki/etcd-key.pem \
  --etcd-servers=https://192.168.3.194:2379 \
  --allow-privileged=true \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/kubernetes/kube-apiserver-audit.log \
  --event-ttl=1h \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/var/log/kubernetes \
  --v=2"

cat > /lib/systemd/system/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver $KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 2. 启动
systemctl daemon-reload
systemctl start kube-apiserver 
systemctl status kube-apiserver 
systemctl enable kube-apiserver
```



#### 3.3.2.3 kubectl 管理集群

```bash
mkdir -p /root/.kube

KUBE_CONFIG=/root/.kube/config
KUBE_APISERVER="https://192.168.3.194:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials cluster-admin \
  --client-certificate=/etc/kubernetes/pki/admin.pem \
  --client-key=/etc/kubernetes/pki/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=cluster-admin \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



### 3.3.2.4 授权 kubelet-bootstrap 用户允许请求证书

防止错误：`failed to run Kubelet: cannot create certificate signing request: certificatesigningrequests.certificates.k8s.io is forbidden: User "kubelet-bootstrap" cannot create resource "certificatesigningrequests" in API group "certificates.k8s.io" at the cluster scope`

```bash
kubectl create clusterrolebinding kubelet-bootstrap \
--clusterrole=system:node-bootstrapper \
--user=kubelet-bootstrap
```



#### 3.3.2.5 授权 `apiserver` 访问 `kubelet`

```bash
cat > apiserver-to-kubelet-rbac.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
      - pods/log
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

kubectl apply -f apiserver-to-kubelet-rbac.yaml
```



### 3.3.3 controller-manager

#### 3.3.3.1 kubeconfig

```bash
KUBE_CONFIG="/etc/kubernetes/kube-controller-manager.kubeconfig"
KUBE_APISERVER="https://192.168.3.194:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-controller-manager \
  --client-certificate=/etc/kubernetes/pki/kube-controller-manager.pem \
  --client-key=/etc/kubernetes/pki/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-controller-manager \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



#### 3.3.3.2 开机启动

`--cluster-cidr=10.244.0.0/16`: Pod IP  段

`--service-cluster-ip-range=10.96.0.0/16`: Service IP 段

```bash
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=false \
--v=2 \
--log-dir=/var/log/kubernetes \
--leader-elect=true \
--kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
--bind-address=127.0.0.1 \
--allocate-node-cidrs=true \
--cluster-cidr=10.244.0.0/16 \
--service-cluster-ip-range=10.96.0.0/16 \
--cluster-signing-cert-file=/etc/kubernetes/pki/ca.pem \
--cluster-signing-key-file=/etc/kubernetes/pki/ca-key.pem  \
--root-ca-file=/etc/kubernetes/pki/ca.pem \
--service-account-private-key-file=/etc/kubernetes/pki/ca-key.pem \
--cluster-signing-duration=87600h0m0s"


cat > /lib/systemd/system/kube-controller-manager.service << EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager $KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-controller-manager
systemctl status kube-controller-manager
systemctl enable kube-controller-manager
```



### 3.3.4 scheduler

#### 3.3.4.1 kubeconfig

```bash
KUBE_CONFIG="/etc/kubernetes/kube-scheduler.kubeconfig"
KUBE_APISERVER="https://192.168.3.194:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-scheduler \
  --client-certificate=/etc/kubernetes/pki/kube-scheduler.pem \
  --client-key=/etc/kubernetes/pki/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-scheduler \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



#### 3.3.4.2 开机启动

```bash
KUBE_SCHEDULER_OPTS="--logtostderr=false \
--v=2 \
--log-dir=/var/log/kubernetes \
--leader-elect \
--kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \
--bind-address=127.0.0.1"


cat > /lib/systemd/system/kube-scheduler.service << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler $KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-scheduler
systemctl status kube-scheduler
systemctl enable kube-scheduler
```



### 3.3.5 kubelet

#### 3.3.5.1 参数配置

```bash
cat > /etc/kubernetes/kubelet-config.yml << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS:
- 10.96.0.2
clusterDomain: cluster.local 
failSwapOn: false
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.pem 
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
maxOpenFiles: 1000000
maxPods: 110
EOF
```



#### 3.3.5.2 kubeconfig

```bash
BOOTSTRAP_TOKEN=$(cat /etc/kubernetes/token.csv | awk -F, '{print $1}')

KUBE_CONFIG="/etc/kubernetes/bootstrap.kubeconfig"
KUBE_APISERVER="https://192.168.3.194:6443" 

# 生成 kubelet bootstrap kubeconfig 配置文件
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials "kubelet-bootstrap" \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user="kubelet-bootstrap" \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



#### 3.3.5.3 开机启动

其中：`--kubeconfig=/etc/kubernetes/kubelet.kubeconfig` 在加入集群时自动生成

```bash
KUBELET_OPTS="--logtostderr=false \
--v=2 \
--log-dir=/var/log/kubernetes \
--hostname-override=k8s-master \
--network-plugin=cni \
--kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
--config=/etc/kubernetes/kubelet-config.yml \
--cert-dir=/etc/kubernetes/pki \
--pod-infra-container-image=kubeedge/pause:3.1"

cat > /lib/systemd/system/kubelet.service << EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet $KUBELET_OPTS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kubelet
systemctl status kubelet
systemctl enable kubelet
```



#### 3.3.5.4 加入集群

```bash
# 查看kubelet证书请求
kubectl get csr
NAME                                                   AGE   SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-ghWG-AWFM9sxJbr5A-BIq9puVIRxfFHrQlwDjYbHba8   25s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending

# 批准申请
kubectl certificate approve node-csr-ghWG-AWFM9sxJbr5A-BIq9puVIRxfFHrQlwDjYbHba8

# 再次查看证书
kubectl get csr
NAME                                                   AGE   SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-ghWG-AWFM9sxJbr5A-BIq9puVIRxfFHrQlwDjYbHba8   53m   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Approved,Issued

# 查看节点（由于网络插件还没有部署，节点会没有准备就绪 NotReady）
kubectl get node
NAME          STATUS     ROLES    AGE   VERSION
k8s-master   NotReady   <none>   4m8s   v1.21.4
```



### 3.3.6 kube-proxy

#### 3.3.6.1 kubeconfig 文件

```bash
KUBE_CONFIG="/etc/kubernetes/kube-proxy.kubeconfig"
KUBE_APISERVER="https://192.168.3.194:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/pki/kube-proxy.pem \
  --client-key=/etc/kubernetes/pki/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



#### 3.3.6.2 开机启动

`--cluster-cidr=10.96.0.0/16`: Service IP 段，与apiserver & controller-manager 的`--service-cluster-ip-range` 一致

```bash
KUBE_PROXY_OPTS="--logtostderr=false \
--v=2 \
--bind-address=0.0.0.0 \
--metrics-bind-address=0.0.0.0:10249 \
--hostname-override=k8s-master \
--cluster-cidr=10.96.0.0/16 \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \
--proxy-mode=ipvs \
--ipvs-scheduler=rr \
--ipvs-sync-period=30s \
--ipvs-min-sync-period=5s \
--masquerade-all=true \
--log-dir=/var/log/kubernetes"

cat > /lib/systemd/system/kube-proxy.service << EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-proxy $KUBE_PROXY_OPTS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-proxy
systemctl status kube-proxy
systemctl enable kube-proxy
```



### 3.3.7 安装CNI插件

```bash
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-arm64-v1.1.1.tgz

mkdir -p /opt/cni/bin
tar zxvf cni-plugins-linux-arm64-v1.1.1.tgz -C /opt/cni/bin
```



### 3.3.8 网络插件

以 flannel 作为例，**其中涉及的IP段，要与 kube-controller-manager中  “--cluster-cidr”  一致**

```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 检查是否和
vi kube-flannel.yml
 "Network": "10.244.0.0/16",

kubectl apply -f kube-flannel.yml

kubectl get pod -n kube-system
kubectl get pod -A
NAMESPACE      NAME                    READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-7vgdj   1/1     Running   0          10m

kubectl get node
NAME         STATUS   ROLES    AGE   VERSION
k8s-master   Ready    master   35m   v1.22.17
```



### 3.3.9 CoreDNS

CoreDNS用于集群内部Service名称解析

```bash
mkdir -p ~/coredns && cd $_

wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed
wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/deploy.sh

chmod +x deploy.sh

export CLUSTER_DNS_SVC_IP="10.96.0.2"
export CLUSTER_DNS_DOMAIN="cluster.local"

./deploy.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -

# 查询状态
kubectl get pods -n kube-system | grep coredns
coredns-746fcb4bc5-nts2k                   1/1     Running   0          6m2s

# 验证 busybox1.33.1有问题
kubectl run -it --rm dns-test --image=busybox:1.28.4 /bin/sh
If you don't see a command prompt, try pressing enter.
/ # nslookup kubernetes
Server:    10.96.0.2
Address 1: 10.96.0.2 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```



回滚操作：

```bash
wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/rollback.sh
chmod +x rollback.sh

export CLUSTER_DNS_SVC_IP="10.96.0.2"
export CLUSTER_DNS_DOMAIN="cluster.local"

./rollback.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -

kubectl delete --namespace=kube-system deployment coredns
```



问题排查：

```bash
# dns service
$ kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.2   <none>        53/UDP,53/TCP,9153/TCP   13m

# endpoints 是否正常
$ kubectl get endpoints kube-dns -n kube-system
NAME       ENDPOINTS                                        AGE
kube-dns   10.244.85.194:53,10.244.85.194:53,10.244.85.194:9153   13m

# coredns 增加解析日志
CoreDNS 配置参数说明：
errors: 输出错误信息到控制台。
health：CoreDNS 进行监控检测，检测地址为 http://localhost:8080/health 如果状态为不健康则让 Pod 进行重启。
ready: 全部插件已经加载完成时，将通过 endpoints 在 8081 端口返回 HTTP 状态 200。
kubernetes：CoreDNS 将根据 Kubernetes 服务和 pod 的 IP 回复 DNS 查询。
prometheus：是否开启 CoreDNS Metrics 信息接口，如果配置则开启，接口地址为 http://localhost:9153/metrics
forward：任何不在Kubernetes 集群内的域名查询将被转发到预定义的解析器 (/etc/resolv.conf)。
cache：启用缓存，30 秒 TTL。
loop：检测简单的转发循环，如果找到循环则停止 CoreDNS 进程。
reload：监听 CoreDNS 配置，如果配置发生变化则重新加载配置。
loadbalance：DNS 负载均衡器，默认 round_robin。

$ kubectl get pod -n kube-system
NAME                       READY   STATUS             RESTARTS      AGE
coredns-697ffc488f-ws6sm   0/1     CrashLoopBackOff   8 (87s ago)   17m

$ kubectl logs -f coredns-697ffc488f-ws6sm -n kube-system
.:53
[INFO] plugin/reload: Running configuration SHA512 = 165c2220dade77166d5aa3508a7dd59a865dbb9a90ca5af87e487b4217222b80d5b35bedd2640b4c4895a10c969c81b9d1ff90d2592ccccc0307eebe5469b6ab
CoreDNS-1.9.4
linux/arm64, go1.19.1, 1f0a41a
[FATAL] plugin/loop: Loop (127.0.0.1:53263 -> :53) detected for zone ".", see https://coredns.io/plugins/loop#troubleshooting. Query: "HINFO 5105007174763724602.5236889870439867564."


# 编辑 coredns 配置
kubectl edit configmap coredns -n kube-system
apiVersion: v1
data:
  Corefile: |
    .:53 {
        log     # new add
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        #forward . /etc/resolv.conf {   # 第三种方案
        forward . 114.114.114.114 {
          max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  annotations:
  ...
```

查询文档：https://coredns.io/plugins/loop#troubleshooting

A common cause of forwarding loops in Kubernetes clusters is an interaction with a local DNS cache on the host node (e.g. `systemd-resolved`). For example, in certain configurations `systemd-resolved` will put the loopback address `127.0.0.53` as a nameserver into `/etc/resolv.conf`. Kubernetes (via `kubelet`) by default will pass this `/etc/resolv.conf` file to all Pods using the `default` dnsPolicy rendering them unable to make DNS lookups (this includes CoreDNS Pods). CoreDNS uses this `/etc/resolv.conf` as a list of upstreams to forward requests to. Since it contains a loopback address, CoreDNS ends up forwarding requests to itself.

There are many ways to work around this issue, some are listed here:

- Add the following to your `kubelet` config yaml: `resolvConf: <path-to-your-real-resolv-conf-file>` (or via command line flag `--resolv-conf` deprecated in 1.10). Your “real” `resolv.conf` is the one that contains the actual IPs of your upstream servers, and no local/loopback address. This flag tells `kubelet` to pass an alternate `resolv.conf` to Pods. For systems using `systemd-resolved`, `/run/systemd/resolve/resolv.conf` is typically the location of the “real” `resolv.conf`, although this can be different depending on your distribution.
- Disable the local DNS cache on host nodes, and restore `/etc/resolv.conf` to the original.
- A quick and dirty fix is to edit your Corefile, replacing `forward . /etc/resolv.conf` with the IP address of your upstream DNS, for example `forward . 8.8.8.8`. But this only fixes the issue for CoreDNS, kubelet will continue to forward the invalid `resolv.conf` to all `default` dnsPolicy Pods, leaving them unable to resolve DNS.



### 3.3.10 命令补全

```bash
apt install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```



### 3.3.11 克隆准备

```bash
tar cvf worker-node-clone.tar /opt/cni/bin /usr/local/bin/{kubelet,kube-proxy} /lib/systemd/system/{kubelet,kube-proxy}.service /etc/kubernetes/kubelet* /etc/kubernetes/kube-proxy* /etc/kubernetes/pki /etc/kubernetes/bootstrap.kubeconfig

scp worker-node-clone.tar root@192.168.3.195:/root
```



## 3.4 Node 节点

:warning: 以下操作在 **k8s-nodeXX** 节点上操作

Kubernetes node节点组件：

- kubelet
- kube-proxy



### 3.4.1 克隆节点

```bash
# 解压克隆包
cd /root && tar xvf worker-node-clone.tar -C / && rm -f worker-node-clone.tar

# 删除证书申请审批后自动生成的文件，后面重新生成
rm -f /etc/kubernetes/kubelet.kubeconfig 
rm -f /etc/kubernetes/pki/kubelet*

# 日志目录
mkdir -p /var/log/kubernetes
```



### 3.4.2 修改配置

按实际节点名称修改

```bash
# kubelet
sed -i 's/k8s-master/k8s-node01/g' /lib/systemd/system/kubelet.service

# kube-proxy
sed -i 's/k8s-master/k8s-node01/g' /lib/systemd/system/kube-proxy.service
```



### 3.4.4 开机启动

```bash
systemctl daemon-reload
systemctl start kubelet kube-proxy
systemctl status kubelet kube-proxy
systemctl enable kubelet kube-proxy
```



### 3.4.5 批准加入集群 

:warning: 以下操作在 **k8s-master** 节点上操作

```bash
# 1. 节点信息
kubectl get csr
NAME                                                   AGE   SIGNERNAME                                    REQUESTOR           REQUESTEDDURATION   CONDITION
node-csr-itkkIT8SsMxI2If2EPF0UkavzOrTm2jv52b1bicFkZA   20s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   <none>              Pending
node-csr-kHQAw4aTmxCXv55Y2uvaQEFvyhXHdumFcMLGu89XM5w   16m   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   <none>              Approved,Issued


# 2. 批准加入
kubectl certificate approve node-csr-itkkIT8SsMxI2If2EPF0UkavzOrTm2jv52b1bicFkZA

# 3. 集群节点
kubectl get node
NAME         STATUS     ROLES    AGE   VERSION
k8s-master   NotReady   <none>   16m   v1.22.17
k8s-node01   NotReady   <none>   9s    v1.22.17

# 4. 设置标签，即更改节点角色
kubectl label node k8s-master node-role.kubernetes.io/master=
kubectl label node k8s-node01 node-role.kubernetes.io/node=

# 5. 设置污点：是master节点无法创建pod
kubectl taint nodes k8s-master node-role.kubernetes.io/master=:NoSchedule

kubectl describe node k8s-master | grep -A 1 Taint
Taints:             node-role.kubernetes.io/master:NoSchedule
                    node.kubernetes.io/not-ready:NoSchedule
```



# 4. 安装 KubeEdge

## 4.1 部署 CloudCore

:warning: 以下操作在 **k8s-master** 节点上操作

### 4.1.1 创建 CRDs

```bash
mkdir -p /tmp/install && cd $_

# 拉取代码
git clone --depth 1 --branch v1.12.1 https://github.com/kubeedge/kubeedge.git
cd kubeedge/build/crds

# CRD生效
kubectl apply -f devices/devices_v1alpha2_device.yaml
kubectl apply -f devices/devices_v1alpha2_devicemodel.yaml

kubectl apply -f reliablesyncs/cluster_objectsync_v1alpha1.yaml
kubectl apply -f reliablesyncs/objectsync_v1alpha1.yaml

kubectl apply -f router/router_v1_ruleEndpoint.yaml
kubectl apply -f router/router_v1_rule.yaml

kubectl apply -f apps/apps_v1alpha1_edgeapplication.yaml
kubectl apply -f apps/apps_v1alpha1_nodegroup.yaml

kubectl apply -f operations/operations_v1alpha1_nodeupgradejob.yaml
```



### 4.1.2 安装 CloudCore

```bash
mkdir -p /tmp/install && cd $_

wget https://github.com/kubeedge/kubeedge/releases/download/v1.12.1/kubeedge-v1.12.1-linux-arm64.tar.gz

tar zxvf kubeedge-v1.12.1-linux-arm64.tar.gz

cp kubeedge-v1.12.1-linux-arm64/cloud/cloudcore/cloudcore /usr/local/bin/
```



### 4.1.3 生成证书

```bash
# 生成CA证书
./certgen.sh genCA

# 证书请求
./certgen.sh genCsr server

# 生成证书，指定正确的主控IP地址
./certgen.sh genCert server 192.168.3.194

# stream证书，通过 kubectl logs/exec 调试 pod，二进制安装的k8s集群需要指定CA证书地址
export K8SCA_FILE="/etc/kubernetes/pki/ca.pem"
export K8SCA_KEY_FILE="/etc/kubernetes/pki/ca-key.pem"
export CLOUDCOREIPS="192.168.3.194"
./certgen.sh stream
```



### 4.1.4 配置文件

```bash
mkdir -p /etc/kubeedge/config
cloudcore --defaultconfig > /etc/kubeedge/config/cloudcore.yaml

vi /etc/kubeedge/config/cloudcore.yaml
...
kubeAPIConfig:
  ...
  kubeConfig: "/root/.kube/config"   # 管理的kubeconfig配置
  ...
modules:
  cloudHub:
    advertiseAddress:
    - 192.168.3.194                  # 改成实际的监听地址
  ...
  cloudStream:
    enable: true                     # 开启stream服务
    streamPort: 10003
...
```



### 4.1.5 运行

```bash
cat > /lib/systemd/system/cloudcore.service <<EOF
[Unit]
Description=cloudcore.service

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudcore
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start cloudcore
systemctl status cloudcore
systemctl enable cloudcore
```



### 4.1.6 获取 token

```bash
$ kubectl get secret -n kubeedge tokensecret -o=jsonpath='{.data.tokendata}' | base64 -d
3f6376e9b294e85a49d41e3c797cf66ff790121ee839df0df38ed5c885f62e64.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NzExNzU5ODV9.tg8XM0ySP79gwrGm9PCXKV-lRf4EoC7KxJFDb1PABSw
```



### 4.1.7 证书分发

```bash
mkdir -p /tmp/install && cd $_
tar cvf certs.tar /etc/kubeedge/ca /etc/kubeedge/certs 

scp certs.tar root@192.168.3.196:/tmp
```



### 4.1.9 边缘节点避免调度

像 flannel 等 daemonset 组件，增加反亲和性，避免调度

```bash
kubectl edit daemonsets.apps -n kube-system flannel
...
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: flannel
        tier: node
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
              - key: node-role.kubernetes.io/edge      # 避免调度
                operator: DoesNotExist
      containers:
      - args:
...
```



## 4.2 部署 EdgeCore

:warning: 以下操作在 **edge-nodeXX** 节点上操作



### 4.2.1 安装 Mosquito

离线安装包：`\\192.168.3.239\share\04-软件部归档\Mosquitto\mosquitto_arm64.ubuntu18.tar.gz`

```bash
tar zxvf mosquitto_arm64.ubuntu18.tar.gz

dpkg -i *.deb
```



### 4.2.2 安装 EdgeCore

```bash
mkdir -p /tmp/install && cd $_

wget https://github.com/kubeedge/kubeedge/releases/download/v1.12.1/kubeedge-v1.12.1-linux-arm64.tar.gz

tar zxvf kubeedge-v1.12.1-linux-arm64.tar.gz

cp kubeedge-v1.12.1-linux-arm64/edge/edgecore /usr/local/bin/
```



### 4.2.3 证书文件

```bash
cd /tmp
tar xvf certs.tar -C /
```



### 4.2.4 配置

修改 token, podSandboxImage 等字段的配置值

```bash
$ mkdir -p /etc/kubeedge/config 

$ edgecore --defaultconfig > /etc/kubeedge/config/edgecore.yaml

$ vi /etc/kubeedge/config/edgecore.yaml
...
modules:
  dbTest:
    enable: false
  deviceTwin:
    enable: true
  edgeHub:
    enable: true
    ...
    httpServer: https://192.168.3.194:10002           # 修改为cloudcore的地址
    ...
    token: f2444db842c939800f87855d1736369c8a460a888d3a1dbca83afdbea6d61212.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NzA5MDk5OTR9.D0sRkO9S5ZXoRelszp7Eqfvx5oGmUNqyI9cU1dLoKfQ           # 添加token，上面获取到的
    websocket:
      enable: true
      ...
      server: 192.168.3.194:10000                     # 修改为cloudcore的地址
      ...
  edgeStream:
    enable: true                                     # 开启stream，支持kubectl logs/exec
    handshakeTimeout: 30
    readDeadline: 15
    server: 192.168.3.194:10004                       # 修改为cloudcore的地址
    ...
  edged:
    ...
    hostnameOverride: ke-edge001                      # 修改为本机的主机名称
    ...
    tailoredKubeletConfig:
      address: 127.0.0.1
      cgroupDriver: cgroupfs                  
      clusterDNS:                                    # 增加 clusterDNS 和 clusterDomain 非常重要
      - 169.254.96.16
      clusterDomain: cluster.local
      ...
```



### 4.2.5 运行

```bash
cat > /lib/systemd/system/edgecore.service <<EOF
[Unit]
Description=edgecore.service

[Service]
Type=simple
ExecStart=/usr/local/bin/edgecore
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start edgecore
systemctl status edgecore
systemctl enable edgecore
```



## 4.3 节点列表

:warning: 节点 **k8s-master** 上执行

```bash
$ kubectl get node
NAME          STATUS   ROLES        AGE    VERSION
ke-edge001   Ready    agent,edge   3d     v1.22.6-kubeedge-v1.12.1
k8s-master    Ready    master       4d1h   v1.22.17
k8s-node01    Ready    node         4d     v1.22.17
```



## 4.4 启用 Metric

### 4.4.1 部署 metrics 服务

```bash
# 下载组件
$ wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.2/components.yaml

# 增加亲和性和容忍
$ vi components.yaml
...
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  ...
  template:
    ...
    spec:
     affinity:    # 新增亲和性
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: Exists
      tolerations:  # 新增容忍
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      hostNetwork: true   # 使用宿主机网络
      containers:
      - args:
        ...
        - --kubelet-insecure-tls   # 新增参数，跳过 TLS 安全认证
      image: registry.aliyuncs.com/google_containers/metrics-server:v0.6.2   # 修改镜像地址
      ...
      
# 部署
kubectl apply -f components.yaml
```



### 4.4.2 查询节点

```bash
$ kubectl get pod -l k8s-app=metrics-server -n kube-system
NAME                             READY   STATUS    RESTARTS   AGE
metrics-server-864f68879-qw2h5   1/1     Running   0          62s

$ kubectl top node
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k8s-master   111m         2%     932Mi           24%
k8s-node01   32m          0%     336Mi           8%
ke-edge001   13m          0%     186Mi           4%
```



### 4.4.3 证书问题

二进制安装的 k8s 集群，使用 metrics 服务时，会出现错误

```bash
$ kubectl top nodes
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)

$ kubectl logs -f metrics-server-99df67d65-fbfcw -n kube-system
E1215 07:48:09.066441       1 configmap_cafile_content.go:242] key failed with : missing content for CA bundle "client-ca::kube-system::extension-apiserver-authentication::requestheader-client-ca-file"

# 缺失 requestheader-client-ca-file 等项
$ kubectl get cm extension-apiserver-authentication -n kube-system -o yaml
apiVersion: v1
data:
  client-ca-file: |
    -----BEGIN CERTIFICATE-----
    MIIDmjCCAoKgAwIBAgIUcQgOHWGQlmgo0u5PRwuPYENM0VcwDQYJKoZIhvcNAQEL
    BQAwZTELMAkGA1UEBhMCQ04xEDAOBgNVBAgTB0JlaUppbmcxEDAOBgNVBAcTB0Jl
    aUppbmcxDDAKBgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwpr
    dWJlcm5ldGVzMB4XDTIyMTIxMTA1NDUwMFoXDTMyMTIwODA1NDUwMFowZTELMAkG
    A1UEBhMCQ04xEDAOBgNVBAgTB0JlaUppbmcxEDAOBgNVBAcTB0JlaUppbmcxDDAK
    BgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwprdWJlcm5ldGVz
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv+rtHScC9gabpA3D8eHU
    C7MCXnjndGkSwFDxxQVRfCtzbMzzVjZgG/ub3la/fvdue0cQuHHuZgReK8ZXeYbW
    cB2EE241RasyXr+fXZEra5KgPuxutI/B5LGSEH31lorLj0wcIQF3C2Hrapbf+H3a
    /HX6E55tjkiBv7rW8ZPRDY4HZTxr+frYQOyoDxHDkL55d1wPLVqpejeMzrLNVs+s
    8ipWBszOS67Oz18cuIxMvOp8FNuWfioMC0ogYQWK7919Pz3otAgs1Lo5fRUPgU7+
    B0bqvYimGbHITzGDmyVeVD9Vdag44i5En29vBT5EZXFXMDXLZwNSGc68aOrzyX6f
    hwIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNV
    HQ4EFgQUTxmlhhIDLqzdRfNDJEKOjZAfaOswDQYJKoZIhvcNAQELBQADggEBAIuo
    dYBDFRGh4I35DLCcakk9sSueTe1Efvpn7/FYUgTW723trlaJhF1/NGUw8xdjtANA
    KhFriNOLOkXT8Q81AeTkZQHUEaPVHlAIxzIDKu17RAV2KsWs6PwxUPQINwpQhXTo
    87WF7aFp6RV7CBrOeYyIGvCQw8vPJ3rwRt48OO2+ykU5DPWEEnEnchX/C0IvBdRL
    t7s2n0gL8q64B1fGVh0vUrWLGvewO3kSh8d48RtsLe/sVVmaM2Nh3CjJncy/RCZf
    oTOn6qKh+96oCNtk4GyZRN+L2TPgZMbJHR7qCEaiuE1X6ZlWAYX8pF7W4ShdSxsk
    IQRd1AMExoesngeAR2s=
    -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  creationTimestamp: "2022-12-11T06:19:53Z"
  name: extension-apiserver-authentication
  namespace: kube-system
  resourceVersion: "37"
  uid: 166d461c-c40f-438f-b470-1fd8638d039f
```



解决办法：

- 生成 API 聚合证书

  ```bash
  cd ~/ssl
  
  cat >  proxy-client-csr.json <<EOF
  {
    "CN": "aggregator",
    "hosts": [],
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:masters",
        "OU": "System"
      }
    ]
  }
  EOF
  
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes proxy-client-csr.json | cfssljson -bare proxy-client
  
  cp proxy-client.pem proxy-client-key.pem /etc/kubernetes/pki 
  ```

  

- 重设 kube-apiserver 启动项

  新增 requestheader 及 proxy-client 配置

  ```bash
  KUBE_APISERVER_OPTS="--enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
    --anonymous-auth=false \
    --bind-address=192.168.3.194 \
    --secure-port=6443 \
    --advertise-address=192.168.3.194 \
    --authorization-mode=Node,RBAC \
    --runtime-config=api/all=true \
    --enable-bootstrap-token-auth \
    --service-cluster-ip-range=10.96.0.0/16 \
    --token-auth-file=/etc/kubernetes/token.csv \
    --service-node-port-range=30000-50000 \
    --tls-cert-file=/etc/kubernetes/pki/kube-apiserver.pem  \
    --tls-private-key-file=/etc/kubernetes/pki/kube-apiserver-key.pem \
    --client-ca-file=/etc/kubernetes/pki/ca.pem \
    --kubelet-client-certificate=/etc/kubernetes/pki/kube-apiserver.pem \
    --kubelet-client-key=/etc/kubernetes/pki/kube-apiserver-key.pem \
    --service-account-key-file=/etc/kubernetes/pki/ca-key.pem \
    --service-account-signing-key-file=/etc/kubernetes/pki/ca-key.pem  \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --etcd-cafile=/etc/kubernetes/pki/ca.pem \
    --etcd-certfile=/etc/kubernetes/pki/etcd.pem \
    --etcd-keyfile=/etc/kubernetes/pki/etcd-key.pem \
    --etcd-servers=https://192.168.3.194:2379 \
    --allow-privileged=true \
    --audit-log-maxage=30 \
    --audit-log-maxbackup=3 \
    --audit-log-maxsize=100 \
    --audit-log-path=/var/log/kubernetes/kube-apiserver-audit.log \
    --event-ttl=1h \
    --alsologtostderr=true \
    --logtostderr=false \
    --log-dir=/var/log/kubernetes \
    --runtime-config=api/all=true \
    --v=2 \
    --requestheader-allowed-names=aggregator \
    --requestheader-group-headers=X-Remote-Group \
    --requestheader-username-headers=X-Remote-User \
    --requestheader-extra-headers-prefix=X-Remote-Extra- \
    --requestheader-client-ca-file=/etc/kubernetes/pki/ca.pem \
    --proxy-client-cert-file=/etc/kubernetes/pki/proxy-client.pem \
    --proxy-client-key-file=/etc/kubernetes/pki/proxy-client-key.pem"
  
  cat > /lib/systemd/system/kube-apiserver.service << EOF
  [Unit]
  Description=Kubernetes API Server
  Documentation=https://github.com/kubernetes/kubernetes
  
  [Service]
  ExecStart=/usr/local/bin/kube-apiserver $KUBE_APISERVER_OPTS
  Restart=on-failure
  
  [Install]
  WantedBy=multi-user.target
  EOF
  
  # 2. 启动
  systemctl daemon-reload
  systemctl restart kube-apiserver 
  systemctl status kube-apiserver 
  ```

  

- 检查

  ```bash
  $ kubertl top node
  NAME          CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
  ke-edge001   49m          1%     1111Mi          28%
  k8s-master    278m         6%     2568Mi          66%
  k8s-node01    107m         2%     637Mi           16%
  ```

  

## 4.5 部署 EdgeMesh

做为 KubeEdge 集群的数据面组件，为应用程序提供了简单的服务发现与流量代理功能，从而屏蔽了边缘场景下复杂的网络结构。它并不依赖于 KubeEdge，它仅与标准 Kubernetes API 交互

**EdgeMesh 限制**：依赖 docker0 网桥，意味着只支持 docker CRI



### 4.5.1 服务过滤

给 Kubernetes API 服务添加过滤标签， 正常情况下不希望 EdgeMesh 去代理 Kubernetes API 服务

```bash
kubectl label services kubernetes service.edgemesh.kubeedge.io/service-proxy-name=""
```



### 4.5.2 边缘 Kube-API 端点

Kubernetes 通过 CRD 和 Controller 机制极大程度的提升了自身的可扩展性，使得众多应用能轻松的集成至 Kubernetes 生态。众所周知，大部分 Kubernetes 应用会通过访问 kube-apiserver 获取基本的元数据，比如 Service、Pod、Job 和 Deployment 等等，以及获取基于自身业务扩展的 CRD 的元数据。

然而，在边缘计算场景下由于网络不互通，导致边缘节点通常无法直接连接到处于云上的 kube-apiserver 服务，使得部署在边缘的 Kubernetes 应用无法获取它所需要的元数据。比如，被调度到边缘节点的 Kube-Proxy 和 Flannel 通常是无法正常工作的。



**步骤1**: 在云端，开启 dynamicController 模块

```bash
$ vi /etc/kubeedge/config/cloudcore.yaml
modules:
  ...
  dynamicController:
    enable: true           #  开启服务
...

$ systemctl restart cloudcore
```



**步骤2**: 在边缘节点，打开 metaServer 模块

```bash
$ vi /etc/kubeedge/config/edgecore.yaml
modules:
 ...
  metaManager:
    metaServer:
      enable: true
      
$ systemctl restart edgecore
```



**步骤3**: 在边缘节点，配置 clusterDNS 和 clusterDomain

```bash
$ vim /etc/kubeedge/config/edgecore.yaml
modules:
  ...
  edged:
    ...
    tailoredKubeletConfig:
      ...
      clusterDNS:
      - 169.254.96.16
      clusterDomain: cluster.local
...
```



**步骤4**: 在边缘节点，测试边缘 Kube-API 端点功能是否正常

```bash
$ curl 127.0.0.1:10550/api/v1/services
{"apiVersion":"v1","items":[{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"kubectl.kubernetes.io/last-applied-
```



### 4.5.3 部署 EdgeMesh

:warning: 以下操作在 **k8s-master** 节点上操作

```bash
mkdir -p /tmp/install && cd $_

# 1. 获取
$ git clone --depth 1 --branch v1.12.0 https://github.com/kubeedge/edgemesh.git
$ cd edgemesh

# 2. 安装 CRDs
$ kubectl apply -f build/crds/istio/

# 3. 设置 relayNodes，并重新生成 PSK 密码
$ vi build/agent/resources/04-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edgemesh-agent-cfg
  namespace: kubeedge
  labels:
    k8s-app: kubeedge
    kubeedge: edgemesh-agent
data:
  edgemesh-agent.yaml: |
    # For more detailed configuration, please refer to: https://edgemesh.netlify.app/reference/config-items.html#edgemesh-agent-cfg
    modules:
      edgeProxy:
        enable: true
      edgeTunnel:
        enable: true
        relayNodes:       # 设置中继节点
        - nodeName: k8s-master
          advertiseAddress:
          - 192.168.3.34
          - 2.2.2.2
        #- nodeName: <your relay node name2>
        #  advertiseAddress:
        #  - 2.2.2.2
        #  - 3.3.3.3
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: edgemesh-agent-psk
  namespace: kubeedge
  labels:
    k8s-app: kubeedge
    kubeedge: edgemesh-agent
data:
  # Generated by `openssl rand -base64 32`
  # NOTE: Don't use this psk, please regenerate it!!! Please refer to: https://edgemesh.netlify.app/guide/security.html
  psk: TpKJ7tJVJklr9iNpgUi7RayBo6uy/vDVo92d5aOsRv8=    # 更新psk


# 4. 支持在主控节点上部署 edgemesh-agent
$ vi build/agent/resources/05-daemonset.yaml
...
spec:
  ...
  template:
    ...
    spec:
      tolerations:              # 新增容忍
        - effect: NoSchedule
          operator: Exists
      containers:
      - name: edgemesh-agent
        securityContext:
          privileged: true
        image: kubeedge/edgemesh-agent:v1.12.0   # 镜像指定
        ...
        
# 5. 部署 edgemesh-agent
kubectl apply -f build/agent/resources/

# 6. 检验部署结果
$ kubectl get pod -n kubeedge -o wide
NAME                   READY   STATUS    RESTARTS   AGE   IP             NODE         NOMINATED NODE   READINESS GATES
edgemesh-agent-h9t5h   1/1     Running   0          47s   192.168.3.35   k8s-node01   <none>           <none>
edgemesh-agent-tvkwd   1/1     Running   0          47s   192.168.3.36   ke-edge001   <none>           <none>
edgemesh-agent-zlg5x   1/1     Running   0          47s   192.168.3.34   k8s-master   <none>           <none>
```



### 4.5.5 测试

**跨云边通信**：处于 edgezone 的 busybox-edge 应用能够访问云上的 tcp-echo-cloud 应用，处于 cloudzone 的 busybox-cloud 应用能够访问边缘的 tcp-echo-edge 应用

**部署**：

```bash
kubectl apply -f examples/cloudzone.yaml

kubectl apply -f examples/edgezone.yaml
```



**云访问边**：

```bash
# 通过云端容器访问边端应用
$ kubectl exec -it $(kubectl get pod -n cloudzone | grep busybox | awk '{print $1}') -n cloudzone -- sh
/ # nslookup  tcp-echo-edge-svc.edgezone
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      tcp-echo-edge-svc.edgezone
Address 1: 10.96.150.181 tcp-echo-edge-svc.edgezone.svc.cluster.local

/ # telnet tcp-echo-edge-svc.edgezone 2701
Welcome, you are connected to node ke-edge001.
Running on Pod tcp-echo-edge-95649b6d8-b27pj.
In namespace edgezone.
With IP address 172.17.0.2.
Service default.
```



**边访问云**：

```bash
# 通过边端容器访问云端应用
$ kubectl exec -it $( kubectl get pod -n edgezone | grep busybox | awk '{print $1}') -n edgezone -- sh
/ # cat /etc/resolv.conf
nameserver 169.254.96.16
search edgezone.svc.cluster.local svc.cluster.local cluster.local
options ndots:5

# nslookup  tcp-echo-cloud-svc.cloudzone
Server:    169.254.96.16
Address 1: 169.254.96.16 ke-edge001

Name:      tcp-echo-cloud-svc.cloudzone
Address 1: 10.96.187.136 tcp-echo-cloud-svc.cloudzone.svc.cluster.local

/ # telnet tcp-echo-cloud-svc.cloudzone 2701
Welcome, you are connected to node k8s-node01.
Running on Pod tcp-echo-cloud-75bcbbf95b-z46tm.
In namespace cloudzone.
With IP address 10.244.1.14.
Service default.
```



# 5. 问题总结

## 5.1 No route to host

原因：iptables 配置中 kube-proxy 根链插在了 edgemesh 根链的前面，导致流量劫持转发错误

规避方法：

- 卸载edgemesh

- 清理iptables规则

```bash
iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X
```

- 新建一个SVC，它将触发kube-proxy重建自己的链

- 重新部署edgemesh，确保了edgemesh根链插入到kube-proxy根链前面



## 5.2 failed to find any peer in table

现象：无法转发流量

规避方法：

- 将主控节点设置为中继节点



## 5.3 边缘Pod无法访问云端Pod

现象：边缘节点无法 telnet 云端Pod

规避方法：

- 检查 edgecore.yaml 是否已配置 clusterDNS & clusterDomain，重启 edgecore 服务

- 某些情况下，是[KubeEdge issue 3445](https://link.zhihu.com/?target=https%3A//github.com/kubeedge/kubeedge/issues/3445) 导致的，临时解决方法

  ```bash
  a. 删除service
  b. kubectl delete objectsync --all
  c. 重启cloudcore、edgecore，重新部署edgemesh
  d. 重新创建service
  ```

  

参考资料：

https://zhuanlan.zhihu.com/p/585749690



