# 1. 准备工作

| **角色**   | **IP**       | **组件**                                                     |
| ---------- | ------------ | ------------------------------------------------------------ |
| k8s-master | 192.168.3.34 | kube-apiserver，kube-controller-manager，kube-scheduler，docker, etcd，cloud-core |
| k8s-node01 | 192.168.3.35 | kubelet，kube-proxy，docker，etcd                            |
| ke-edge001 | 192.168.3.36 | docker,  edge-core, mosquitto                                |

软件版本：

| 软件       | 版本               | 备注             |
| ---------- | ------------------ | ---------------- |
| OS         | Ubuntu 18.04.1 LTS |                  |
| Kubernetes | v1.22.6            | GPaaS 版本1.21.4 |
| Etcd       | v3.5.0             |                  |
| Docker     | 20.10.9            |                  |
| KubeEdge   | v1.12.0            |                  |



```bash
# 1. 修改主机名，按规划主机名修改
hostnamectl set-hostname k8s-master
hostnamectl set-hostname k8s-node01
hostnamectl set-hostname ke-edge001

# 2. 相关组件
apt install conntrack ntpdate -y 

# 3. 禁用 swap
swapoff -a && sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab

# 4. 时间同步 
echo '*/30 * * * * /usr/sbin/ntpdate -u ntp1.aliyun.com >> /var/log/ntpdate.log 2>&1' > /tmp/ntp.txt
crontab /tmp/ntp.txt

# 5. 内核参数调整
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_reuse =0     
vm.swappiness=0         
vm.overcommit_memory=1       
fs.inotify.max_user_instances=8192
vm.panic_on_oom=0 
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
EOF

sysctl -p /etc/sysctl.d/kubernetes.conf

# 7. 主机解析
cat >> /etc/hosts <<EOF
192.168.3.34 k8s-master
192.168.3.35 k8s-node01
192.168.3.36 ke-edge001
EOF
```



# 2. docker

```bash
# 1. 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -

# 2. 写入软件源信息
add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"   # x86_64
add-apt-repository "deb [arch=arm64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"   # aarch64

# 3. 更新
apt update

# 4. 查询版本
apt-cache madison docker-ce
#docker-ce | 5:19.03.15~3-0~ubuntu-focal | https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal/stable amd64 Packages

# 5. 安装
apt install docker-ce=5:20.10.21~3-0~ubuntu-bionic -y

# 6. 验证
docker version

# 7. 修改cgroup驱动为systemd，适配k8s默认选项
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

systemctl restart docker
```



# 3. 部署 k8s 集群

:warning: 节点 **k8s-master** 和 **k8s-nodeXX** 上执行



## 3.1 主控节点

:warning: 节点 **k8s-master** 上执行

### 3.1.1 软件安装

```bash
# 1. 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 

# 2. 写入软件源信息
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

# 3. 更新
apt update

# 4. 查询版本
apt-cache madison kubeadm
#kubeadm |  1.22.6-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages

# 5. 安装
apt-get install -y kubeadm=1.22.6-00 kubelet=1.22.6-00 kubectl=1.22.6-00
```



### 3.1.2 集群初始化

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.3.34 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.22.6 \
  --service-cidr=10.96.0.0/16 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all
```

输出结果：

```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.3.34:6443 --token ln5lv8.znu2fqq20ipl6h6w \
        --discovery-token-ca-cert-hash sha256:d3e80a5e58c6d8b38d97c9f9a0f072828186dcbfc6994dc60ad28a80bd37c24a
```

根据提示，创建 `kubectl` 认证文件：

```bash
# 即使是root用户，也采用默认文件方式
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

kubectl 命令补齐：

```bash
echo "source <(kubectl completion bash)" >> ~/.bashrc

# 立即生效
source <(kubectl completion bash)
```



### 3.1.3 kube-proxy

避免 `kube-proxy` 部署在 edge 节点上

```bash
$ kubectl edit ds kube-proxy -n kube-system
    spec:
      ...
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/edge
                    operator: DoesNotExist
```



### 3.1.4 网络插件

```bash
cd /tmp/install
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 确保网络配置与 `--pod-network-cidr=10.244.0.0/16` 一致
$ vi kube-flannel.yml
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
  ...
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
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
              - key: node-role.kubernetes.io/edge   # 避免调度边缘节点
                operator: DoesNotExist
...

$ kubectl apply -f kube-flannel.yml

$ kubectl get node
NAME         STATUS   ROLES                  AGE     VERSION
k8s-master   Ready    control-plane,master   13m     v1.22.6
```



## 3.2 计算节点

:warning: 节点 **k8s-nodeXX** 上执行

### 3.2.1 软件安装

```bash
# 1. 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 

# 2. 写入软件源信息
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

# 3. 更新
apt update

# 4. 查询版本
apt-cache madison kubeadm
#kubeadm |  1.22.6-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 Packages

# 5. 安装
apt-get install -y kubeadm=1.22.6-00 kubelet=1.22.6-00
```



### 3.2.2 加入集群

```bash
kubeadm join 192.168.3.34:6443 --token ln5lv8.znu2fqq20ipl6h6w \
        --discovery-token-ca-cert-hash sha256:d3e80a5e58c6d8b38d97c9f9a0f072828186dcbfc6994dc60ad28a80bd37c24a
```



## 3.3 集群列表

:warning: 节点 **k8s-master** 上执行

```bash
$  kubectl get node
NAME         STATUS   ROLES                  AGE     VERSION
k8s-master   Ready    control-plane,master   13m     v1.22.6
k8s-node01   Ready    <none>                 9m41s   v1.22.6
```



# 4. 部署 kube-edge 

## 4.1 主控节点

:warning: 节点 **k8s-master** 上执行

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

# 证书工具
mkdir -p /etc/kubeedge/{config,ca,certs}
cp kubeedge/build/tools/certgen.sh /etc/kubeedge/
```



### 4.1.2 安装 CloudCore

```bash
mkdir -p /tmp/install && cd $_

wget https://github.com/kubeedge/kubeedge/releases/download/v1.12.1/kubeedge-v1.12.1-linux-amd64.tar.gz

tar zxvf kubeedge-v1.12.1-linux-amd64.tar.gz

cp kubeedge-v1.12.1-linux-amd64/cloud/cloudcore/cloudcore /usr/local/bin/
```



### 4.1.3 生成证书

```bash
# 生成CA证书
./certgen.sh genCA

# 证书请求
./certgen.sh genCsr server

# 生成证书
./certgen.sh genCert server 192.168.3.34

# stream证书
export CLOUDCOREIPS=192.168.3.34
./certgen.sh stream

# 如果遇到错误：../crypto/rand/randfile.c:88:Filename=/root/.rnd
vi /etc/ssl/openssl.cnf
#RANDFILE                = $ENV::HOME/.rnd 
```

:alien: 生成stream证书时，二进制安装的 kubernetes 需要指定证书地址，例如：

```bash
export K8SCA_FILE="/etc/kubernetes/pki/ca.pem"
export K8SCA_KEY_FILE="/etc/kubernetes/pki/ca-key.pem"
```



### 4.1.4 配置文件

```bash
$ cloudcore --defaultconfig > /etc/kubeedge/config/cloudcore.yaml

$ vi /etc/kubeedge/config/cloudcore.yaml
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
    enable: true                     # 开启stream服务，支持 kubectl logs/exec 功能
    streamPort: 10003
...

# 设置转发端口：10003和10350是 CloudStream 和 Edgecore 的默认端口
$ iptables -t nat -A OUTPUT -p tcp --dport 10350 -j DNAT --to $CLOUDCOREIPS:10003
```



### 4.1.5 运行

```bash
# 开机启动配置
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

# 启动服务
systemctl daemon-reload
systemctl start cloudcore
systemctl status cloudcore
systemctl enable cloudcore

# 查看10003和10004端口
$ ss -nutlp |egrep "10003|10004"
tcp    LISTEN   0        4096                    *:10003                *:*      users:(("cloudcore",pid=34703,fd=7))
tcp    LISTEN   0        4096                    *:10004                *:*      users:(("cloudcore",pid=34703,fd=13))
```



### 4.1.6 获取 token

```bash
$ kubectl get secret -n kubeedge tokensecret -o=jsonpath='{.data.tokendata}' | base64 -d
47881cb15eeb52c185ad72eef13f970cc66fb8eb1402b7dc3abb7e9d0a87ee6e.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NzEwOTY2MDl9.8GSzMi660ZMQIJPV09bJiUbjfzHM-A7s6bPWBIabI44
```



### 4.1.7 证书分发

```bash
mkdir -p /tmp/install && cd $_
tar cvf certs.tar /etc/kubeedge/ca /etc/kubeedge/certs 

scp certs.tar root@192.168.3.36:/tmp
```



## 4.2 边缘节点

:warning: 节点 **ke-nodeXXX** 上执行

### 4.2.1 安装 Mosquito

amd64, ubuntu18.04:

```bash
apt install mosquitto mosquitto-clients -y

systemctl status mosquitto
```



arm64, ubuntu18.04:

```bash
apt-add-repository ppa:mosquitto-dev/mosquitto-ppa
apt update

apt install mosquitto mosquitto-clients -y
```



### 4.2.2 安装 EdgeCore

```bash
mkdir -p /tmp/install && cd $_

wget https://github.com/kubeedge/kubeedge/releases/download/v1.12.1/kubeedge-v1.12.1-linux-amd64.tar.gz

tar zxvf kubeedge-v1.12.1-linux-amd64.tar.gz

cp kubeedge-v1.12.1-linux-amd64/edge/edgecore /usr/local/bin/
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
    httpServer: https://192.168.3.34:10002           # 修改为cloudcore的地址
    ...
    token: 47881cb15eeb52c185ad72eef13f970cc66fb8eb1402b7dc3abb7e9d0a87ee6e.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2NzEwOTY2MDl9.8GSzMi660ZMQIJPV09bJiUbjfzHM-A7s6bPWBIabI44           # 添加token
    websocket:
      enable: true
      ...
      server: 192.168.3.34:10000                     # 修改为cloudcore的地址
      ...
  edgeStream:
    enable: true                                     # 开启stream，支持kubectl logs/exec
    handshakeTimeout: 30
    readDeadline: 15
    server: 192.168.3.34:10004                       # 修改为cloudcore的地址
    ...
  edged:
    ...
    hostnameOverride: ke-edge001                      # 修改为本机的主机名称
    ...
    tailoredKubeletConfig:
      address: 127.0.0.1
      cgroupDriver: systemd                          # 统一修改为 systemd
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
NAME         STATUS   ROLES                  AGE   VERSION
k8s-master   Ready    control-plane,master   22h   v1.22.6
k8s-node01   Ready    <none>                 22h   v1.22.6
ke-edge001   Ready    agent,edge             19h   v1.22.6-kubeedge-v1.12.1
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



**步骤3**: 在边缘节点，测试边缘 Kube-API 端点功能是否正常

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

