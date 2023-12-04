# 1. 准备

## 1.1 安装依赖

```bash
apt update
apt install socat	    # 端口转发
apt install conntrack	# 连接跟踪
apt install ebtables    # 以太网防火墙，类似iptables
apt install ipset       # iptables的扩展，它允许创建匹配整个IP地址集合规则
apt install ipvsadm     


apt update && apt install socat conntrack ebtables ipset ipvsadm -y
```



## 1.2 设置主机名

```bash
hostnamectl set-hostname k8s-master
hostnamectl set-hostname k8s-node01
hostnamectl set-hostname k8s-node02
```



## 1.3 时间同步

```bash
apt install -y chrony
systemctl enable --now chronyd
timedatectl set-timezone Asia/Shanghai
```



# 2. 部署

## 2.1 下载 kubekey

:warning: 主控节点上执行

```bash
curl -sfL https://get-kk.kubesphere.io | sh -
```



## 2.2 创建配置

```bash
./kk create config --with-kubernetes v1.24.7 -f k8s-cluster.yaml
```

修改配置:

```yaml
apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Cluster
metadata:
  name: k8s-install
spec:
  hosts:
  - {name: k8s-master, address: 192.168.3.197, internalAddress: 192.168.3.197, user: root, password: "root"}
  - {name: k8s-node01, address: 192.168.3.198, internalAddress: 192.168.3.198, user: root, password: "root"}
  roleGroups:
    etcd:
    - k8s-master
    control-plane:
    - k8s-master
    worker:
    - k8s-master
    - k8s-node01
  controlPlaneEndpoint:
    ## Internal loadbalancer for apiservers
    # internalLoadbalancer: haproxy

    domain: lb.kubesphere.local
    address: ""
    port: 6443
  kubernetes:
    version: v1.24.7
    clusterName: cluster.local
    autoRenewCerts: true
    containerManager: containerd
  etcd:
    type: kubekey
  network:
    plugin: calico
    kubePodsCIDR: 10.244.0.0/16
    kubeServiceCIDR: 10.96.0.0/16
    ## multus support. https://github.com/k8snetworkplumbingwg/multus-cni
    multusCNI:
      enabled: false
  registry:
    privateRegistry: ""
    namespaceOverride: ""
    registryMirrors: []
    insecureRegistries: []
  addons: []
```



## 2.4 创建集群

```bash
export KKZONE=cn
./kk create cluster -f k8s-cluster.yaml
```



## 2.5 集群维护

```bash
# 添加节点
./kk add nodes -f k8s-cluster.yaml

# 删除节点
./kk delete node k8s-node01 -f k8s-cluster.yaml

# 删除集群
./kk delete cluster -f k8s-cluster.yaml

# 集群升级
./kk upgrade [--with-kubernetes version] [--with-kubesphere version]

./kk upgrade [--with-kubernetes version] [--with-kubesphere version] [(-f | --file) path]
```



## 2.6 携带 kubesphere

```bash
./kk create config --with-kubernetes v1.24.1 --container-manager docker --with-kubesphere v3.3.2 -f k8s-cluster2.yaml
```



aaaa

```bash
apt install conntrack ebtables   ipset   ipvsadm -y


./kk create config --with-kubesphere v3.3.2 -f k8s-cluster2.yaml


apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Cluster
metadata:
  name: k8s-install
spec:
  hosts:
  - {name: k8s-master, address: 192.168.3.197, internalAddress: 192.168.3.197, user: root, password: "root"}
  - {name: k8s-node01, address: 192.168.3.198, internalAddress: 192.168.3.198, user: root, password: "root"}
  - {name: k8s-node02, address: 192.168.3.199, internalAddress: 192.168.3.199, user: root, password: "root"}
  roleGroups:
    etcd:
    - k8s-master
    control-plane:
    - k8s-master
    worker:
    - k8s-master
    - k8s-node01
    - k8s-node02
  controlPlaneEndpoint:
    ## Internal loadbalancer for apiservers
    # internalLoadbalancer: haproxy

    domain: lb.kubesphere.local
    address: ""
    port: 6443
  kubernetes:
    version: v1.23.10
    clusterName: cluster.local
    autoRenewCerts: true
    containerManager: docker
  etcd:
    type: kubekey
  network:
    plugin: calico
    kubePodsCIDR: 10.244.0.0/24
    kubeServiceCIDR: 10.96.0.0/24
    ## multus support. https://github.com/k8snetworkplumbingwg/multus-cni
    multusCNI:
      enabled: false
  registry:
    privateRegistry: ""
    namespaceOverride: ""
    registryMirrors: []
    insecureRegistries: []
  addons: []


systemctl stop containerd
systemctl disable containerd

rm -f /usr/bin/containerd
rm -f /etc/systemd/system/containerd.service
rm -rf /var/lib/containerd

```



# 3. 离线包

https://github.com/kubesphere/kubekey 下 release



## 3.1 准备操作

```bash
mkdir -p kubesphere && cd $_

wget --no-check-certificate https://github.com/kubesphere/kubekey/releases/download/v3.0.12/ubuntu-20.04-debs-amd64.iso
wget --no-check-certificate https://github.com/kubesphere/kubekey/releases/download/v3.0.13/kubekey-v3.0.13-linux-amd64.tar.gz

tar zxvf kubekey-v3.0.13-linux-amd64.tar.gz
```



## 3.2 清单

`manifest-ubuntu20.yaml`

```yaml
---
apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Manifest
metadata:
  name: ubuntu20.04
spec:
  arches:
  - amd64
  operatingSystems:
  - arch: amd64
    type: linux
    id: ubuntu
    version: "20.04"
    repository:
      iso:
        localPath: /root/kubesphere/ubuntu-20.04-debs-amd64.iso
        url:
  kubernetesDistributions:
  - type: kubernetes
    version: v1.23.10
  components:
    helm:
      version: v3.9.0
    cni:
      version: v1.2.0
    etcd:
      version: v3.4.13
    containerRuntimes:
    - type: docker
      version: 20.10.8
    crictl:
      version: v1.24.0
    calicoctl:
      version: v3.23.2
    ##
    # docker-registry:
    #   version: "2"
    harbor:
      version: v2.5.3
    docker-compose:
      version: v2.2.2
  images:
  - docker.io/kubeedge/cloudcore:v1.13.0
  - docker.io/kubeedge/edgemesh-agent:v1.13.2
  - docker.io/kubeedge/pause:3.6
  - docker.io/kubesphere/edgeservice:v0.3.0
  - docker.io/kubesphere/iptables-manager:v1.13.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/alertmanager:v0.23.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/cni:v3.23.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/coredns:1.8.6
  - registry.cn-beijing.aliyuncs.com/kubesphereio/defaultbackend-amd64:1.4
  - registry.cn-beijing.aliyuncs.com/kubesphereio/flannel:v0.12.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/grafana:8.3.3
  - registry.cn-beijing.aliyuncs.com/kubesphereio/k8s-dns-node-cache:1.15.12
  - registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/ks-apiserver:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/ks-console:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/ks-controller-manager:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/ks-upgrade:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-apiserver:v1.23.10
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-controller-manager:v1.23.10
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-controllers:v3.23.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kubectl:v1.22.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-proxy:v1.23.10
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-rbac-proxy:v0.11.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-rbac-proxy:v0.8.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-scheduler:v1.23.10
  - registry.cn-beijing.aliyuncs.com/kubesphereio/kube-state-metrics:v2.5.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/linux-utils:3.3.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/mc:RELEASE.2019-08-07T23-14-43Z
  - registry.cn-beijing.aliyuncs.com/kubesphereio/metrics-server:v0.4.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/minio:RELEASE.2019-08-07T01-59-21Z
  - registry.cn-beijing.aliyuncs.com/kubesphereio/node-exporter:v1.3.1
  - registry.cn-beijing.aliyuncs.com/kubesphereio/node:v3.23.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/notification-manager-operator:v1.4.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/notification-manager:v1.4.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/notification-tenant-sidecar:v3.2.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/openpitrix-jobs:v3.3.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/pause:3.6
  - registry.cn-beijing.aliyuncs.com/kubesphereio/pod2daemon-flexvol:v3.23.2
  - registry.cn-beijing.aliyuncs.com/kubesphereio/prometheus-config-reloader:v0.55.1
  - registry.cn-beijing.aliyuncs.com/kubesphereio/prometheus-operator:v0.55.1
  - registry.cn-beijing.aliyuncs.com/kubesphereio/prometheus:v2.34.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/provisioner-localpv:3.3.0
  - registry.cn-beijing.aliyuncs.com/kubesphereio/snapshot-controller:v4.0.0
```



## 3.3 制品

```bash
export KKZONE=cn

./kk artifact export -m manifest-ubuntu20.yaml -o kubesphere-amd64.tar.gz
```



# 4. 安装操作

## 4.1 Harbor

```bash
./kk init registry -f install-cluster.yaml -a /opt/gpaas-offline-pkgs/kubesphere-amd64.tar.gz

./kk init registry -f install-cluster.yaml -a ./kubesphere-amd64.tar.gz
```





## 4.2 集群

```bash
./kk create cluster -f install-cluster.yaml -a /opt/gpaas-offline-pkgs/kubesphere-amd64.tar.gz --with-packages


./kk create cluster -f install-cluster.yaml -a ./kubesphere-amd64.tar.gz --with-packages

./kk create cluster -f install-cluster.yaml -a /root/kubesphere/kubesphere-amd64.tar.gz --with-packages
```





# 3. CEPH

CEPH的CephFS和RDB的区别
CephFS 是文件系统，rbd 是块设备。

CephFS 很像 NFS。它是一个通过网络共享的文件系统，不同的机器可以同时访问它。

RBD 更像是一个硬盘映像，通过网络共享。将一个普通的文件系统（如 ext2）放在它上面并挂载到一台计算机上很容易，但是如果你一次在多台计算机上挂载相同的 RBD 设备，那么文件系统将会发生非常糟糕的事情。

一般来说，如果你想在多台机器之间共享一堆文件，那么 CephFS 是你最好的选择。

如果你想存储一个磁盘映像，也许是为了与虚拟机一起使用，那么你需要 RBD。

 

RBD是通过创建pools来自动创建的。

用来存储磁盘映像和容器。同时只有一个虚拟机链接这个磁盘映像或容器。

 

CephFS，创建后用来存储ISO文件，并且有挂载目录

至少需要一个元数据服务器才能使用 CephFS





K3S:

```bash
systemctl stop k3s && systemctl disable k3s
rm -f /etc/systemd/system/k3s.service.env /etc/systemd/system/k3s.service

rm -rf /etc/rancher /etc/kubernetes/ /var/lib/rancher/ /root/.kube/ /var/lib/kubelet/ 

rm -rf /usr/local/bin/calicoctl /usr/local/bin/crictl /usr/local/bin/ctr /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/helm
rm -rf /usr/local/bin/k3s /usr/local/bin/k3s-killall.sh /usr/local/bin/k3s-uninstall.sh /usr/local/bin/kubectl /usr/local/bin/kube-scripts

systemctl stop etcd && systemctl disable etcd 
systemctl stop backup-etcd.timer && systemctl disable backup-etcd.timer 
systemctl stop backup-etcd && systemctl disable backup-etcd

rm -rf /var/lib/etcd /etc/ssl/etcd
rm -f /etc/systemd/system/etcd.service.env 
rm -f /etc/systemd/system/k3s.service
rm -f /etc/systemd/system/backup-etcd.timer
rm -f /etc/systemd/system/etcd.service
rm -f /etc/systemd/system/backup-etcd.service
rm -f /etc/etcd.env
```

