# 1. 准备工作

```bash
# kubelet 配置参数开启了 CNI
/usr/bin/kubelet --network-plugin=cni --cni-bin-dir=/opt/cni/bin --cni-conf-dir=/etc/cni/net.d

# 清理已安装的插件
rm -f /etc/cni/net.d/*
ls -l /etc/cni/net.d/
```



# 2. 安装

## 2.1 部署相关 CRD

Kube-OVN 创建了 Subnet 和 IP 两种 CRD 资源方便网络的管理

```bash
mkdir -p $HOME/k8s-install/network/kubeovn && cd $HOME/k8s-install/network/kubeovn

wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.7/yamls/crd.yaml
kubectl apply -f crd.yaml

# 查看CRD
kubectl get crd
NAME                          CREATED AT
ips.kubeovn.io                2021-06-11T06:18:25Z
subnets.kubeovn.io            2021-06-11T06:18:25Z
vlans.kubeovn.io              2021-06-11T06:18:25Z
vpc-nat-gateways.kubeovn.io   2021-06-11T06:18:25Z
vpcs.kubeovn.io               2021-06-11T06:18:25Z
```



## 2.1 部署 OVN

Kube-OVN 底层依赖 Open vSwitch 社区提供的 OVS 和 OVN



### 2.1.1 给部署 ovndb 的机器打标签

ovndb 需要将数据存在宿主机硬盘来持久化状态，选择一个节点增加标签

```bash
kubectl label node k8s-master1 kube-ovn/role=master

kubectl get nodes --show-labels
NAME          STATUS   ROLES    AGE   VERSION    LABELS
k8s-master1   Ready    master   45h   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kube-ovn/role=master,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-master1,kubernetes.io/os=linux,node-role.kubernetes.io/master=
k8s-node01    Ready    node     45h   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node01,kubernetes.io/os=linux,node-role.kubernetes.io/node=
k8s-node02    Ready    node     45h   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node02,kubernetes.io/os=linux,node-role.kubernetes.io/node=
```



### 2.1.2 部署 OVN/OVS

```bash
# 下载 ovn.yaml，将文件中的 $addresses 替换为前面打了标签的节点 IP
wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.7/yamls/ovn.yaml
sed -i 's/\$addresses/192.168.80.45,192.168.80.46,192.168.80.47/g' ovn.yaml

kubectl apply -f ovn.yaml

kubectl get pod -n kube-system
NAME                          READY   STATUS    RESTARTS   AGE
ovn-central-65b48f84c-rggql   1/1     Running   0          17m
ovs-ovn-b5dhn                 1/1     Running   0          17m
ovs-ovn-dwmsz                 1/1     Running   0          17m
ovs-ovn-wv58b                 1/1     Running   0          17m
```



### 2.1.3 安装 Kube-OVN Controller 及 CNIServer

Kube-OVN Controller 和 CNIServer 中有大量可配参数，这里为了快速上手，我们不做更改。默认配置下 Kube-OVN 会使用 10.16.0.0/16 作为默认子网，100.64.0.1/16 作为主机和 Pod 通信子网，使用 Kubernetes 中的 Node 主网卡作为 Pod 流量通信使用网卡，并开启流量镜像功能。

```bash
wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.7/yamls/kube-ovn.yaml
 
# 按需要修改这些值 (本次安装不涉及)
REGISTRY="kubeovn"
POD_CIDR="10.16.0.0/16"                # Do NOT overlap with NODE/SVC/JOIN CIDR
SVC_CIDR="10.96.0.0/12"                # Do NOT overlap with NODE/POD/JOIN CIDR
JOIN_CIDR="100.64.0.0/16"              # Do NOT overlap with NODE/POD/SVC CIDR
LABEL="node-role.kubernetes.io/master" # The node label to deploy OVN DB
IFACE=""                               # The nic to support container network can be a nic name or a group of regex separated by comma, if empty will use the nic that the default route use
VERSION="v1.7.0" 
 
kubectl apply -f kube-ovn.yaml

# 状态检查
kubectl get pod -n kube-system
NAMESPACE     NAME                                   READY   STATUS    RESTARTS   AGE
kube-system   kube-ovn-cni-895qk                     1/1     Running   0          73s
kube-system   kube-ovn-cni-r882f                     1/1     Running   0          72s
kube-system   kube-ovn-cni-tthts                     1/1     Running   0          72s
kube-system   kube-ovn-controller-59c497478d-6zhb9   1/1     Running   0          73s
kube-system   kube-ovn-monitor-7745b94df8-k6jlr      1/1     Running   0          72s
kube-system   kube-ovn-pinger-2w4f4                  1/1     Running   0          72s
kube-system   kube-ovn-pinger-7hgg9                  1/1     Running   0          72s
kube-system   kube-ovn-pinger-vrggx                  1/1     Running   0          72s
kube-system   ovn-central-65b48f84c-rggql            1/1     Running   0          28m
kube-system   ovs-ovn-b5dhn                          1/1     Running   0          28m
kube-system   ovs-ovn-dwmsz                          1/1     Running   0          28m
kube-system   ovs-ovn-wv58b                          1/1     Running   0          28m

# 观察自动创建的 Subnet
kubectl get subnet
NAME          PROVIDER   VPC           PROTOCOL   CIDR            PRIVATE   NAT     EXTERNALEGRESSGATEWAY   POLICYROUTINGPRIORITY   POLICYROUTINGTABLEID   DEFAULT   GATEWAYTYPE   V4USED   V4AVAILABLE   V6USED   V6AVAILABLE
join          ovn        ovn-cluster   IPv4       100.64.0.0/16   false     false                                                                          false     distributed   3        65530         0        0
ovn-default   ovn        ovn-cluster   IPv4       10.16.0.0/16    false     true                                                                           true      distributed   4        65529         0        0
```



### 2.1.4 安装 Kubectl 插件

```bash
wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.7/dist/images/kubectl-ko

chmod +x kubectl-ko
mv kubectl-ko /usr/bin/kubectl-ko

# 检查插件状态
kubectl plugin list
The following compatible plugins are available:
/usr/bin/kubectl-ko

# 对网络质量进行检查
kubectl ko diagnose all
```



# 3. 测试

固定Mac:

```bash
cat > fixed-ip-deploy.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: starter-backend
  labels:
    app: starter-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: starter-backend
  template:
    metadata:
      labels:
        app: starter-backend
      annotations:
        ovn.kubernetes.io/ip_pool: 10.16.0.15,10.16.0.16
    spec:
      containers:
      - name: backend
        image: nginx:alpine
EOF

kubectl apply -f fixed-ip-deploy.yml
```



固定IP和Mac:

```bash
cat > fixed-ip-mac-deploy.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        ovn.kubernetes.io/ip_address: 10.16.0.17
        ovn.kubernetes.io/mac_address: 00:00:00:53:6B:B6
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

```

