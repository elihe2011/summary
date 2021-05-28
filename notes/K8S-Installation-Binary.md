# 1. 环境准备

## 1.1 服务器规划

| **角色**    | **IP**        | **组件**                                                     |
| ----------- | ------------- | ------------------------------------------------------------ |
| k8s-master1 | 192.168.80.11 | kube-apiserver，kube-controller-manager，kube-scheduler，docker, etcd |
| k8s-master2 | 192.168.80.12 | kube-apiserver，kube-controller-manager，kube-scheduler，docker, etcd |
| k8s-node1   | 192.168.80.15 | kubelet，kube-proxy，docker，etcd                            |
| k8s-node2   | 192.168.80.16 | kubelet，kube-proxy，docker，etcd                            |



## 1.2 系统设置

```bash
# 1、关闭防火墙 
systemctl stop firewalld 
systemctl disable firewalld 
 
# 2、关闭selinux 
sed -i 's/enforcing/disabled/' /etc/selinux/config 
setenforce 0  
 
# 3、关闭swap 
swapoff -a 
sed -ri 's/.*swap.*/#&/' /etc/fstab  
 
# 4、根据规划设置主机名 
hostnamectl set-hostname <hostname> 
 
# 5、在master添加hosts 
cat >> /etc/hosts << EOF 
192.168.80.11 k8s-master1
192.168.80.12 k8s-master2
192.168.80.15 k8s-node1 
192.168.80.16 k8s-node2 
EOF
 
# 6、将桥接的IPv4流量传递到iptables的链 
cat > /etc/sysctl.d/k8s.conf << EOF 
net.bridge.bridge-nf-call-ip6tables = 1 
net.bridge.bridge-nf-call-iptables = 1 
EOF
sysctl --system 
 
# 7、时间同步 
yum install ntpdate -y 
ntpdate ntp1.aliyun.com

crontab -e
*/30 * * * * /usr/sbin/ntpdate-u ntp1.aliyun.com >> /var/log/ntpdate.log 2>&1
```



## 1.3 内核升级

```bash
uname -r
3.10.0-1160.el7.x86_64

# 内核仓库
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

# 查看可安装的软件包 kernel-lt: long term support， kernel-ml：mainline stable
yum --enablerepo="elrepo-kernel" list --showduplicates | sort -r | grep kernel-lt.x86_64
kernel-lt.x86_64                           5.4.118-1.el7.elrepo        elrepo-kernel
kernel-lt.x86_64                           5.4.117-1.el7.elrepo        elrepo-kernel

# 安装新内核
yum --enablerepo="elrepo-kernel" install kernel-lt-5.4.118-1.el7.elrepo.x86_64 -y
grub2-set-default 0
grub2-mkconfig -o /boot/grub2/grub.cfg
grubby --default-kernel

# 重启系统
reboot
```



## 1.4 安装 Docker

```bash
# 1. 下载并安装
wget http://docker-release-yellow-prod.s3-website-us-east-1.amazonaws.com/linux/static/stable/x86_64/docker-19.03.9.tgz
tar zxvf docker-19.03.9.tgz
mv docker/* /usr/bin
docker version

# 2. 创建配置文件
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://pvjhx571.mirror.aliyuncs.com"]
}
EOF

# 3. 开机启动
cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
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

systemctl daemon-reload
systemctl start docker
systemctl enable docker
systemctl status docker
```



## 1.5 证书工具

只需在主节点上操作

```bash
mkdir ~/cfssl && cd ~/cfssl/

wget https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64
wget https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssljson_1.5.0_linux_amd64
wget https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl-certinfo_1.5.0_linux_amd64

chmod +x *

mv cfssl_1.5.0_linux_amd64 /usr/local/bin/cfssl
mv cfssljson_1.5.0_linux_amd64 /usr/local/bin/cfssljson
mv cfssl-certinfo_1.5.0_linux_amd64 /usr/bin/cfssl-certinfo
```



## 1.6 证书说明

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-certificates.png) 

两套证书：

- <font color="red">访问 `apierver` (红色)</font>
  - 管理节点：指`controller-manager` 和 `scheduler` 连接 `apiserver` 所需的客户端证书。
  - 工作节点：指`kubelet` 和 `kube-proxy` 连接 `apiserver` 所需的客户端证书。它一般启用 Bootstrap TLS 机制，`kubelet`的证书在初次启动时，会向 `apiserver` 申请证书，由 `controller-manager` 组件自动颁发。
- <font color="blue">访问 `Ectd`(蓝色)</font>



# 2. `Etcd` 集群

Etcd 和 Kubernetes 节点合设

| **节点名称** | **IP**        |
| ------------ | ------------- |
| etcd-1       | 192.168.80.11 |
| etcd-2       | 192.168.80.15 |
| etcd-3       | 192.168.80.16 |



## 2.1 Etcd 证书

**注：在 `etcd-1` 上操作**

### 2.1.1 自签 CA 证书

```bash
# 1. 创建工作目录
mkdir -p ~/TLS/etcd && cd ~/TLS/etcd

# 2. 自签 CA
cat > ca-config.json << EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "www": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat > ca-csr.json << EOF
{
    "CN": "etcd",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Nanjing",
            "ST": "Jiangsu"
        }
    ]
}
EOF

# 3. 生成证书: ca.pem & ca-key.pem
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```



### 2.1.2 签发 SSL 证书

```bash
# 1. 证书请求文件
cat > server-csr.json << EOF
{
    "CN": "etcd",
    "hosts": [
        "127.0.0.1",
        "localhost",
        "192.168.80.10",
        "192.168.80.11",
        "192.168.80.12",
        "192.168.80.13",
        "192.168.80.14",
        "192.168.80.15",
        "192.168.80.16",
        "192.168.80.17",
        "192.168.80.18",
        "192.168.80.19"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Nanjing",
            "ST": "Jiangsu"
        }
    ]
}
EOF

# 2. 生成 https 证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server
```



## 2.2 部署 Etcd 集群

### 2.2.1 `etcd-1` 节点

```bash
# 1. 下载并安装
mkdir -p ~/etcd && cd ~/etcd
wget https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz
tar zxvf etcd-v3.4.15-linux-amd64.tar.gz

mkdir -p /opt/etcd/{bin,cfg,ssl}
mv etcd-v3.4.15-linux-amd64/{etcd,etcdctl} /opt/etcd/bin/

# 2. 证书文件
cp ~/TLS/etcd/ca*pem ~/TLS/etcd/server*pem /opt/etcd/ssl/

# 4. 配置文件
cat > /opt/etcd/cfg/etcd.conf << EOF
#[Member]
ETCD_NAME="etcd-1"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.80.11:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.80.11:2379,https://127.0.0.1:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.80.11:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.80.11:2379"
ETCD_INITIAL_CLUSTER="etcd-1=https://192.168.80.11:2380,etcd-2=https://192.168.80.15:2380,etcd-3=https://192.168.80.16:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# 5. 系统管理
cat > /usr/lib/systemd/system/etcd.service << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/opt/etcd/cfg/etcd.conf
ExecStart=/opt/etcd/bin/etcd \
--cert-file=/opt/etcd/ssl/server.pem \
--key-file=/opt/etcd/ssl/server-key.pem \
--peer-cert-file=/opt/etcd/ssl/server.pem \
--peer-key-file=/opt/etcd/ssl/server-key.pem \
--trusted-ca-file=/opt/etcd/ssl/ca.pem \
--peer-trusted-ca-file=/opt/etcd/ssl/ca.pem \
--logger=zap
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 6. 克隆
tar cvf etcd-clone.tar /opt/etcd /usr/lib/systemd/system/etcd.service
scp etcd-clone.tar root@192.168.80.11:/
scp etcd-clone.tar root@192.168.80.15:/
scp etcd-clone.tar root@192.168.80.16:/
```



### 2.2.2 其他节点

```bash
# 1. 解压克隆文件
cd / && tar xvf etcd-clone.tar && rm -f etcd-clone.tar

# 2. 修改配置文件
vi /opt/etcd/cfg/etcd.conf
#[Member]
ETCD_NAME="etcd-2"                                      # change to local
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.80.51:2380"      # change to local
ETCD_LISTEN_CLIENT_URLS="https://192.168.80.51:2379"    # change to local

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.80.51:2380"  # change to local
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.80.51:2379"        # change to local
ETCD_INITIAL_CLUSTER="etcd-1=https://192.168.80.50:2380,etcd-2=https://192.168.80.51:2380,etcd-3=https://192.168.80.52:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
```



### 2.2.3 启动

```bash
# 1. 开机启动
systemctl daemon-reload
systemctl start etcd
systemctl status etcd
systemctl enable etcd

# 2. 将etcd命令加入PATH
cat >> ~/.bash_profile <<EOF
export PATH=$PATH:/opt/etcd/bin
export ETCDCTL_API=3
EOF

source ~/.bash_profile

# 3. 状态查询
etcdctl member list --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --write-out=table
+------------------+---------+--------+----------------------------+----------------------------+------------+
|        ID        | STATUS  |  NAME  |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
+------------------+---------+--------+----------------------------+----------------------------+------------+
| 195fbcb8c0d5200f | started | etcd-1 | https://192.168.80.11:2380 | https://192.168.80.11:2379 |      false |
| 26ff7368c0b1e177 | started | etcd-2 | https://192.168.80.15:2380 | https://192.168.80.15:2379 |      false |
| 53b74f42c4b31a78 | started | etcd-3 | https://192.168.80.16:2380 | https://192.168.80.16:2379 |      false |
+------------------+---------+--------+----------------------------+----------------------------+------------+

etcdctl endpoint health --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.80.11:2379,https://192.168.80.15:2379,https://192.168.80.16:2379" --write-out=table
+----------------------------+--------+-------------+-------+
|          ENDPOINT          | HEALTH |    TOOK     | ERROR |
+----------------------------+--------+-------------+-------+
| https://192.168.80.15:2379 |   true | 15.282007ms |       |
| https://192.168.80.11:2379 |   true | 17.325809ms |       |
| https://192.168.80.16:2379 |   true | 17.455301ms |       |
+----------------------------+--------+-------------+-------+
```



# 4. Master-Node

## 4.1 安装准备

### 4.1.1 下载安装包

https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md

```bash
# 1. 下载安装包
cd ~
wget https://dl.k8s.io/v1.19.11/kubernetes-server-linux-amd64.tar.gz
tar zxvf kubernetes-server-linux-amd64.tar.gz

# 2. 安装
mkdir -p /opt/kubernetes/{bin,cfg,ssl,logs} 
cd kubernetes/server/bin
cp kube-apiserver kube-scheduler kube-controller-manager kubectl /opt/kubernetes/bin
ln -s /opt/kubernetes/bin/kubectl /usr/bin/kubectl
```



### 4.1.2 自签 CA 证书

```bash
mkdir -p ~/TLS/k8s && cd ~/TLS/k8s

# 1. 自签 CA
cat > ca-config.json << EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat > ca-csr.json << EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Nanjing",
            "ST": "Jiangsu",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# 生成证书：ca.pem & ca-key.pem
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```



## 4.2 API-Server

### 4.2.1 签发 SSL 证书

```bash
cd ~/TLS/k8s

# 10.0.0.1 给flannel或calico网络 插件使用
cat > server-csr.json << EOF
{
    "CN": "kubernetes",
    "hosts": [
        "10.0.0.1",
        "127.0.0.1",
        "localhost",
        "192.168.80.10",
        "192.168.80.11",
        "192.168.80.12",
        "192.168.80.13",
        "192.168.80.14",
        "192.168.80.15",
        "192.168.80.16",
        "192.168.80.17",
        "192.168.80.18",
        "192.168.80.19",
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
            "L": "Nanjing",
            "ST": "Jiangsu",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# 生成证书: server.pem & server-key.pem
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson -bare server
```



### 4.2.2 使用证书

```bash
cp ~/TLS/k8s/ca*pem ~/TLS/k8s/server*pem /opt/kubernetes/ssl/
```



### 4.2.3 Token 文件

```bash
token=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

# 格式：token，用户名，UID，用户组
cat > /opt/kubernetes/cfg/token.csv << EOF
$token,kubelet-bootstrap,10001,"system:node-bootstrapper"
EOF
```



### 4.2.4 配置文件

```bash
cat > /opt/kubernetes/cfg/kube-apiserver.conf << EOF
KUBE_APISERVER_OPTS="--logtostderr=false \\
--v=2 \\
--log-dir=/opt/kubernetes/logs \\
--etcd-servers=https://192.168.80.11:2379,https://192.168.80.15:2379,https://192.168.80.16:2379 \\
--bind-address=192.168.80.11 \\
--secure-port=6443 \\
--advertise-address=192.168.80.11 \\
--allow-privileged=true \\
--service-cluster-ip-range=10.0.0.0/24 \\
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction \\
--authorization-mode=RBAC,Node \\
--enable-bootstrap-token-auth=true \\
--token-auth-file=/opt/kubernetes/cfg/token.csv \\
--service-node-port-range=30000-32767 \\
--kubelet-client-certificate=/opt/kubernetes/ssl/server.pem \\
--kubelet-client-key=/opt/kubernetes/ssl/server-key.pem \\
--tls-cert-file=/opt/kubernetes/ssl/server.pem  \\
--tls-private-key-file=/opt/kubernetes/ssl/server-key.pem \\
--client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--service-account-issuer=api \\
--service-account-signing-key-file=/opt/kubernetes/ssl/server-key.pem \\
--etcd-cafile=/opt/etcd/ssl/ca.pem \\
--etcd-certfile=/opt/etcd/ssl/server.pem \\
--etcd-keyfile=/opt/etcd/ssl/server-key.pem \\
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--proxy-client-cert-file=/opt/kubernetes/ssl/server.pem \\
--proxy-client-key-file=/opt/kubernetes/ssl/server-key.pem \\
--requestheader-allowed-names=kubernetes \\
--requestheader-extra-headers-prefix=X-Remote-Extra- \\
--requestheader-group-headers=X-Remote-Group \\
--requestheader-username-headers=X-Remote-User \\
--enable-aggregator-routing=true \\
--audit-log-maxage=30 \\
--audit-log-maxbackup=3 \\
--audit-log-maxsize=100 \\
--audit-log-path=/opt/kubernetes/logs/k8s-audit.log"
EOF
```



**启用 TLS Bootstrapping 机制：**

TLS Bootstraping：Master apiserver启用TLS认证后，Node节点kubelet和kube-proxy要与kube-apiserver进行通信，必须使用CA签发的有效证书才可以，当Node节点很多时，这种客户端证书颁发需要大量工作，同样也会增加集群扩展复杂度。为了简化流程，Kubernetes引入了TLS bootstraping机制来自动颁发客户端证书，kubelet会以一个低权限用户自动向apiserver申请证书，kubelet的证书由apiserver动态签署。所以强烈建议在Node上使用这种方式，目前主要用于kubelet，kube-proxy还是由我们统一颁发一个证书。

`TLS bootstraping` 工作流程：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-tls-bootstrap.png) 



### 4.2.5 开机启动

```bash
# 1. 系统管理
cat > /usr/lib/systemd/system/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kube-apiserver.conf
ExecStart=/opt/kubernetes/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 2. 启动
systemctl daemon-reload
systemctl start kube-apiserver 
systemctl enable kube-apiserver
systemctl status kube-apiserver 
```



## 4.3 Controller-Manager

### 4.3.1 生成 kubeconfig 文件

```bash
# 1. 生成证书
cd ~/TLS/k8s

cat > kube-controller-manager-csr.json << EOF
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
      "L": "Nanjing", 
      "ST": "Jiangsu",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# 2. 生成 kubeconfig 文件
KUBE_CONFIG="/opt/kubernetes/cfg/kube-controller-manager.kubeconfig"
KUBE_APISERVER="https://192.168.80.11:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-controller-manager \
  --client-certificate=./kube-controller-manager.pem \
  --client-key=./kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-controller-manager \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



### 4.3.2 配置文件

```bash
cat > /opt/kubernetes/cfg/kube-controller-manager.conf << EOF
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=false \\
--v=2 \\
--log-dir=/opt/kubernetes/logs \\
--leader-elect=true \\
--kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--bind-address=127.0.0.1 \\
--allocate-node-cidrs=true \\
--cluster-cidr=10.244.0.0/16 \\
--service-cluster-ip-range=10.0.0.0/24 \\
--cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
--cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem  \\
--root-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--cluster-signing-duration=87600h0m0s"
EOF
```



### 4.3.3 开机启动

```bash
cat > /usr/lib/systemd/system/kube-controller-manager.service << EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-controller-manager.conf
ExecStart=/opt/kubernetes/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-controller-manager
systemctl enable kube-controller-manager
systemctl status kube-controller-manager
```



## 4.4 Scheduler

### 4.4.1 生成 kubeconfig 文件

```bash
# 1. 生成证书
cd ~/TLS/k8s

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
      "L": "Nanjing",
      "ST": "Jiangsu",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

# 2. 生成 kubeconfig 文件
KUBE_CONFIG="/opt/kubernetes/cfg/kube-scheduler.kubeconfig"
KUBE_APISERVER="https://192.168.80.11:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-scheduler \
  --client-certificate=./kube-scheduler.pem \
  --client-key=./kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-scheduler \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



### 4.4.2 **配置文件**

```bash
cat > /opt/kubernetes/cfg/kube-scheduler.conf << EOF
KUBE_SCHEDULER_OPTS="--logtostderr=false \
--v=2 \
--log-dir=/opt/kubernetes/logs \
--leader-elect \
--kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \
--bind-address=127.0.0.1"
EOF
```



### 4.4.3 开机启动

```bash
cat > /usr/lib/systemd/system/kube-scheduler.service << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-scheduler.conf
ExecStart=/opt/kubernetes/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-scheduler
systemctl enable kube-scheduler
systemctl status kube-scheduler
```



## 4.5 集群状态

```bash
kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```



## 4.6 集群配置 (admin管理)

```bash
# 1. 生成kubectl连接集群的证书
cd ~/TLS/k8s
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
      "L": "Nanjing",
      "ST": "Jiangsu",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

# 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

# 2. 生成kubeconfig文件
mkdir -p /root/.kube

KUBE_CONFIG=/root/.kube/config
KUBE_APISERVER="https://192.168.80.11:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials cluster-admin \
  --client-certificate=./admin.pem \
  --client-key=./admin-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=cluster-admin \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}

# 3. 查询配置信息
kubectl config view
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://192.168.80.11:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: cluster-admin
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: cluster-admin
  user:
    client-certificate-data: REDACTED
    client-key-data: REDACTED

kubectl config get-contexts
CURRENT   NAME      CLUSTER      AUTHINFO        NAMESPACE
*         default   kubernetes   cluster-admin
```



## 4.7 kubectl 命令补全

```bash
yum install -y epel-release bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```




# 5. Worker-Node

继续在 Master-Node 上操作，先将其视为工作节点



## 5.1 Kubelet

### 5.1.1 kubelet

```bash
cp ~/kubernetes/server/bin/kubelet /opt/kubernetes/bin
```



### 5.1.2 `kubelet` 参数配置

```bash
cat > /opt/kubernetes/cfg/kubelet-config.yml << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS:
- 10.0.0.2
clusterDomain: cluster.local 
failSwapOn: false
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /opt/kubernetes/ssl/ca.pem 
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



### 5.1.3 生成 kubeconfig 文件

初次加入集群的引导文件

```bash
cat /opt/kubernetes/cfg/token.csv
TOKEN="e042aa227dd5ae81469ef4dce43c5a08"     # 与token.csv里保持一致

KUBE_CONFIG="/opt/kubernetes/cfg/bootstrap.kubeconfig"
KUBE_APISERVER="https://192.168.80.11:6443" 

# 生成 kubelet bootstrap kubeconfig 配置文件
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials "kubelet-bootstrap" \
  --token=${TOKEN} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user="kubelet-bootstrap" \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



### 5.1.4 配置文件

```bash
cat > /opt/kubernetes/cfg/kubelet.conf << EOF
KUBELET_OPTS="--logtostderr=false \\
--v=2 \\
--log-dir=/opt/kubernetes/logs \\
--hostname-override=k8s-master1 \\
--network-plugin=cni \\
--kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \\
--bootstrap-kubeconfig=/opt/kubernetes/cfg/bootstrap.kubeconfig \\
--config=/opt/kubernetes/cfg/kubelet-config.yml \\
--cert-dir=/opt/kubernetes/ssl \\
--pod-infra-container-image=mirrorgooglecontainers/pause-amd64:3.1"
EOF
```



### 5.2.4 授权 kubelet-bootstrap 用户允许请求证书

防止错误：`failed to run Kubelet: cannot create certificate signing request: certificatesigningrequests.certificates.k8s.io is forbidden: User "kubelet-bootstrap" cannot create resource "certificatesigningrequests" in API group "certificates.k8s.io" at the cluster scope`

```bash
kubectl create clusterrolebinding kubelet-bootstrap \
--clusterrole=system:node-bootstrapper \
--user=kubelet-bootstrap
```




### 5.2.5 开机启动

```bash
cat > /usr/lib/systemd/system/kubelet.service << EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kubelet.conf
ExecStart=/opt/kubernetes/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet
systemctl status kubelet
```



### 5.2.6 申请加入集群

```bash
# 查看kubelet证书请求
kubectl get csr
NAME                                                   AGE   SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-M-mLMnXvdL-TzEwI1i4LAMjWX1CVJp2LKK1-gowuzzc   44s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending

# 批准申请
kubectl certificate approve node-csr-M-mLMnXvdL-TzEwI1i4LAMjWX1CVJp2LKK1-gowuzzc

# 再次查看证书
kubectl get csr
NAME                                                   AGE   SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-M-mLMnXvdL-TzEwI1i4LAMjWX1CVJp2LKK1-gowuzzc   73s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Approved,Issued

# 查看节点（由于网络插件还没有部署，节点会没有准备就绪 NotReady）
kubectl get node
NAME          STATUS     ROLES    AGE   VERSION
k8s-master1   NotReady   <none>   51s   v1.20.6
```



## 5.2 `kube-proxy`

### 5.2.1 kube-proxy

```bash
cp ~/kubernetes/server/bin/kube-proxy /opt/kubernetes/bin
```



### 5.2.2 生成 kubeconfig 文件

```bash
# 1. 生成证书
cd ~/TLS/k8s

cat > kube-proxy-csr.json << EOF
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
      "L": "Nanjing",
      "ST": "Jiangsu",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy

# 2. 生成kubeconfig文件
KUBE_CONFIG="/opt/kubernetes/cfg/kube-proxy.kubeconfig"
KUBE_APISERVER="https://192.168.80.11:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
```



### 5.2.3 `kube-proxy` 参数配置

```bash
cat > /opt/kubernetes/cfg/kube-proxy-config.yml << EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
metricsBindAddress: 0.0.0.0:10249
clientConnection:
  kubeconfig: /opt/kubernetes/cfg/kube-proxy.kubeconfig
hostnameOverride: k8s-master1
clusterCIDR: 10.0.0.0/24
EOF
```



### 5.2.4 `kube-proxy` 启动配置

```bash
cat > /opt/kubernetes/cfg/kube-proxy.conf << EOF
KUBE_PROXY_OPTS="--logtostderr=false \
--v=2 \
--log-dir=/opt/kubernetes/logs \
--config=/opt/kubernetes/cfg/kube-proxy-config.yml"
EOF
```



### 5.2.5 开机启动

```bash
cat > /usr/lib/systemd/system/kube-proxy.service << EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kube-proxy.conf
ExecStart=/opt/kubernetes/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start kube-proxy
systemctl enable kube-proxy
systemctl status kube-proxy
```



## 5.3 CNI 网络

### 5.3.1 CNI Plugin

```bash
wget https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz

mkdir -p /opt/cni/bin
tar zxvf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin
```



### 5.3.2 Flannel

```bash
# 1. 安装 flannel 网络
mkdir -p ~/yaml && cd ~/yaml
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml

# 2. 节点状态
kubectl get node
NAME          STATUS   ROLES    AGE   VERSION
k8s-master1   Ready    <none>   72m   v1.19.11
```



### 5.3.3 Calico (未使用)

`Calico`是一个纯三层的数据中心网络方案，是目前Kubernetes主流的网络方案。

```bash
mkdir -p ~/cni && cd ~/cni
curl https://docs.projectcalico.org/manifests/calico.yaml -O


wget https://docs.projectcalico.org/v3.14/getting-started/kubernetes/installation/hosted/calico.yaml
kubectl apply -f calico.yaml

# 部署Calico
kubectl apply -f calico.yaml
kubectl get pods -n kube-system

# calicoctl 工具
wget https://github.com/projectcalico/calicoctl/releases/download/v3.14.2/calicoctl-linux-amd64
mv calicoctl-linux-amd64 /usr/local/bin/calicoctl
chmod +x /usr/local/bin/calicoctl

export CALICO_DATASTORE_TYPE=kubernetes
export CALICO_KUBECONFIG=~/.kube/config 

calicoctl get ippool
calicoctl get node


mkdir -p /etc/cni/net.d/


# ETCD 地址
ETCD_ENDPOINTS="https://192.168.80.50:2379,https://192.168.80.51:2379,https://192.168.80.52:2379"
sed -i "s#.*etcd_endpoints:.*#  etcd_endpoints: \"${ETCD_ENDPOINTS}\"#g" calico.yaml
sed -i "s#__ETCD_ENDPOINTS__#${ETCD_ENDPOINTS}#g" calico.yaml

# ETCD 证书信息
ETCD_CA=`cat /opt/etcd/ssl/ca.pem | base64 | tr -d '\n'`
ETCD_CERT=`cat /opt/etcd/ssl/server.pem | base64 | tr -d '\n'`
ETCD_KEY=`cat /opt/etcd/ssl/server-key.pem | base64 | tr -d '\n'`

# 替换修改
sed -i "s#.*etcd-ca:.*#  etcd-ca: ${ETCD_CA}#g" calico.yaml
sed -i "s#.*etcd-cert:.*#  etcd-cert: ${ETCD_CERT}#g" calico.yaml
sed -i "s#.*etcd-key:.*#  etcd-key: ${ETCD_KEY}#g" calico.yaml

sed -i 's#.*etcd_ca:.*#  etcd_ca: "/calico-secrets/etcd-ca"#g' calico.yaml
sed -i 's#.*etcd_cert:.*#  etcd_cert: "/calico-secrets/etcd-cert"#g' calico.yaml
sed -i 's#.*etcd_key:.*#  etcd_key: "/calico-secrets/etcd-key"#g' calico.yaml

sed -i "s#__ETCD_CA_CERT_FILE__#/opt/etcd/ssl/ca.pem#g" calico.yaml
sed -i "s#__ETCD_CERT_FILE__#/opt/etcd/ssl/server.pem#g" calico.yaml
sed -i "s#__ETCD_KEY_FILE__#/opt/etcd/ssl/server-key.pem#g" calico.yaml

sed -i "s#__KUBECONFIG_FILEPATH__#/etc/cni/net.d/calico-kubeconfig#g" calico.yaml


ETCD_ENDPOINTS="https://192.168.80.50:2379,https://192.168.80.51:2379,https://192.168.80.52:2379" calicoctl node run
```




## 5.4 授权 `apiserver` 访问 `kubelet`

```bash
cd ~/yaml
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



## 5.5 准备克隆文件

```bash
cd ~
tar cvf worker-node-clone.tar /opt/kubernetes /usr/lib/systemd/system/{kubelet,kube-proxy}.service /opt/cni/bin

scp worker-node-clone.tar root@192.168.80.15:/
scp worker-node-clone.tar root@192.168.80.16:/
```



# 6. 新增 Worker-Node

## 6.1 克隆操作

```bash
cd / && tar xvf worker-node-clone.tar && rm -f worker-node-clone.tar

# 删除日志文件
rm -f /opt/kubernetes/logs/*

# 删除证书申请审批后自动生成的文件，后面重新生成
rm -f /opt/kubernetes/cfg/kubelet.kubeconfig 
rm -f /opt/kubernetes/ssl/kubelet*
```



## 6.2 修改配置文件

```bash
# kubelet
vi /opt/kubernetes/cfg/kubelet.conf
--hostname-override=k8s-node1

# kube-proxy
vi /opt/kubernetes/cfg/kube-proxy-config.yml
hostnameOverride: k8s-node1
```



## 6.3 开机启动

```bash
systemctl daemon-reload
systemctl start kubelet kube-proxy
systemctl enable kubelet kube-proxy
```



## 6.4  批准新的 `kubelet` 证书申请

Master-Node 上执行：

```bash
kubectl get csr
NAME                                                   AGE     SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-Gbb8v0QTXUNaTWjcbo-R_sAGhUNTp5a9fV75iCWl9xI   3m20s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending
node-csr-hhZfxlbBKcrSNZTFE-aZSiAsgVjsNOaLDMfMf12pPfk   3m25s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending

kubectl certificate approve node-csr-Gbb8v0QTXUNaTWjcbo-R_sAGhUNTp5a9fV75iCWl9xI
kubectl certificate approve node-csr-hhZfxlbBKcrSNZTFE-aZSiAsgVjsNOaLDMfMf12pPfk

kubectl get node
NAME          STATUS   ROLES    AGE     VERSION
k8s-master1   Ready    <none>   110m    v1.19.11
k8s-node1     Ready    <none>   4m11s   v1.19.11
k8s-node2     Ready    <none>   4m12s   v1.19.11
```



# 7. 节点管理

```bash
# 设置标签
kubectl label node k8s-master1 node-role.kubernetes.io/master=
kubectl label node k8s-node1 node-role.kubernetes.io/node=
kubectl label node k8s-node2 node-role.kubernetes.io/node=

# 设置污点：是master节点无法创建pod
kubectl taint nodes k8s-master1 node-role.kubernetes.io/master=:NoSchedule

# 节点信息
kubectl get nodes --show-labels
NAME          STATUS   ROLES    AGE    VERSION    LABELS
k8s-master1   Ready    master   120m   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-master1,kubernetes.io/os=linux,node-role.kubernetes.io/master=
k8s-node1     Ready    node     13m    v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node1,kubernetes.io/os=linux,node-role.kubernetes.io/node=
k8s-node2     Ready    node     13m    v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node2,kubernetes.io/os=linux,node-role.kubernetes.io/node=
```



# 8. Dashboard

```bash
cd ~/ymal
curl https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml -o dashboard.yaml

kubectl apply -f dashboard.yaml

kubectl get pods -n kubernetes-dashboard -o wide
NAME                                             READY   STATUS    RESTARTS   AGE    IP           NODE          NOMINATED NODE   READINESS GATES
dashboard-metrics-scraper-79c5968bdc-62hlk   1/1     Running   0          2m8s   10.244.1.3   k8s-node2     <none>           <none>
kubernetes-dashboard-9f9799597-b8hfr         1/1     Running   0          2m8s   10.244.0.3   k8s-master1   <none>           <none>

kubectl get svc -n kubernetes-dashboard -o wide
NAME                                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE    SELECTOR
dashboard-metrics-scraper   ClusterIP   10.0.0.80    <none>        8000/TCP   2m8s   k8s-app=dashboard-metrics-scraper
kubernetes-dashboard        ClusterIP   10.0.0.59    <none>        443/TCP    2m9s   k8s-app=kubernetes-dashboard

# 改为NodePort方式
kubectl edit svc kubernetes-dashboard  -n  kubernetes-dashboard
type: ClusterIP => type: NodePort
 
kubectl get svc -n kubernetes-dashboard -o wide
NAME                        TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE     SELECTOR
dashboard-metrics-scraper   ClusterIP   10.0.0.80    <none>        8000/TCP        7m39s   k8s-app=dashboard-metrics-scraper
kubernetes-dashboard        NodePort    10.0.0.59    <none>        443:30564/TCP   7m40s   k8s-app=kubernetes-dashboard

# 创建service account并绑定默认cluster-admin管理员集群角色：
kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin

# 访问 token
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
Name:         dashboard-admin-token-zlbzg
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: dashboard-admin
              kubernetes.io/service-account.uid: 98318bbe-6500-4758-ae38-b38d837c83d5

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1310 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6ImtBMkQ1RXVpdm9tTlVBSS1QN1FlUG0zb0xXNFhSbjJHaVB4cXEtb0FRTU0ifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4temxiemciLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiOTgzMThiYmUtNjUwMC00NzU4LWFlMzgtYjM4ZDgzN2M4M2Q1Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.HlPX1mrWe5a5Sg3pu3heOaRNxtVoP8WQH9t1hRzMDFQFfFOKzE1om-NMOuGyx1W56KpuUYOc8-6Ykme3a0-8_XExq1NVV48En-vAqYfGCl_AaQJPsp1N2pOmfOagPDaXl5k5lymBGbrqbSceREWmQlCj2HZiQdI7eLBjmU2ngIKfwglabpqfunYYOeAiQObqcY_pTM6tmq489MDvjEVU5e1cQX6-TWjj37Ee7O9OXhs0ngTjiay2k34OPCmQ-4A-EzZP1uYXg0BKI-LW0IgW3TBXNXhfI1ltNDxtMsOxDSV7KTj1_-a5WrayrQ7XWcmb7G2o8RrowEKH7YtiMMhKnw

# 去访问
https://192.168.80.11:30564
```





# 9. CoreDNS

CoreDNS用于集群内部Service名称解析

```bash
mkdir -p ~/coredns && cd ~/coredns

wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed
wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/deploy.sh

chmod +x deploy.sh

export CLUSTER_DNS_SVC_IP="10.0.0.2"
export CLUSTER_DNS_DOMAIN="cluster.local"

./deploy.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -

# 查询状态
kubectl get pods -n kube-system | grep coredns
coredns-867bfd96bd-264bb   1/1     Running   0          37s

# 验证
kubectl run -it --rm dns-test --image=busybox:1.33.1 /bin/sh
If you don't see a command prompt, try pressing enter.
/ # nslookup kubernetes
Server:         10.0.0.2
Address:        10.0.0.2:53

Name:   kubernetes.default.svc.cluster.local
Address: 10.0.0.1
```



DNS问题排查：

```bash
# dns service
kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.0.0.2     <none>        53/UDP,53/TCP,9153/TCP   14h

# endpoints 是否正常
kubectl get endpoints kube-dns -n kube-system
NAME       ENDPOINTS                                        AGE
kube-dns   10.244.2.10:53,10.244.2.10:53,10.244.2.10:9153   14h

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
        forward . /etc/resolv.conf {
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
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"Corefile":".:53 {\n    errors\n    health {\n      lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      fallthrough in-addr.arpa ip6.arpa\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n      max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"coredns","namespace":"kube-system"}}
  creationTimestamp: "2021-05-13T11:57:45Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "38460"
  selfLink: /api/v1/namespaces/kube-system/configmaps/coredns
  uid: c62a856d-1fc3-4fe9-b5f1-3ca0dbeb39c1
```



# 10. Master-Node 扩容

## 10.1 克隆

```bash
# k8s-master1 上执行
tar zcvf master-node-clone.tar.gz /opt/kubernetes /opt/etcd/ssl /usr/lib/systemd/system/kube* /root/.kube /root/.bash_profile /opt/cni/bin
scp master-node-clone.tar.gz root@192.168.80.12:/

# k8s-master2 执行
cd / && tar zxvf master-node-clone.tar.gz && rm -f master-node-clone.tar.gz
ln -s /opt/kubernetes/bin/kubectl /usr/bin/kubectl

rm -f /opt/kubernetes/logs/*
rm -f /opt/kubernetes/cfg/kubelet.kubeconfig 
rm -f /opt/kubernetes/ssl/kubelet*

source /root/.bash_profile
```



## 10.2 修改配置文件

```bash
vi /opt/kubernetes/cfg/kube-apiserver.conf 
--bind-address=192.168.80.12 \
--advertise-address=192.168.80.12 \

vi /opt/kubernetes/cfg/kubelet.conf
--hostname-override=k8s-master2

vi /opt/kubernetes/cfg/kube-proxy-config.yml
hostnameOverride: k8s-master2
```



## 10.3 开机启动

```bash
systemctl daemon-reload
systemctl start kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy
systemctl enable kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy
```



## 10.4 集群状态

```bash
vi /root/.kube/config
server: https://192.168.80.12:6443

kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```



## 10.5 批准 kubelet 证书申请

```bash
kubectl get csr
NAME                                                   AGE     SIGNERNAME                                    REQUESTOR           CONDITION
node-csr-_rO1et9aMBGp1a12oZpTSwEtoHFQa4-n8IGh0zfJuq4   4m28s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending

# 批准加入
kubectl certificate approve node-csr-_rO1et9aMBGp1a12oZpTSwEtoHFQa4-n8IGh0zfJuq4

kubectl get node
NAME          STATUS   ROLES    AGE     VERSION
k8s-master1   Ready    master   24h     v1.19.11
k8s-master2   Ready    <none>   3m11s   v1.19.11
k8s-node1     Ready    node     23h     v1.19.11
k8s-node2     Ready    node     23h     v1.19.11
```



## 10.6 打标和污点

```bash
# 设置标签
kubectl label node k8s-master2 node-role.kubernetes.io/master=

# 设置污点：是master节点无法创建pod
kubectl taint nodes k8s-master1 node-role.kubernetes.io/master=:NoSchedule

# 节点信息
kubectl get nodes --show-labels
```



# 11. 高可用负载均衡

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-apiserver-keepalived.png) 

`Nginx`: 主流Web服务和反向代理服务器，这里用四层实现对apiserver实现负载均衡。

`Keepalived`: 主流高可用软件，基于VIP绑定实现服务器双机热备。Keepalived主要根据Nginx运行状态判断是否需要故障转移（漂移VIP），例如当Nginx主节点挂掉，VIP会自动绑定在Nginx备节点，从而保证VIP一直可用，实现Nginx高可用。



服务器规划：

| **角色**          | **IP**        | 组件              |
| ----------------- | ------------- | ----------------- |
| k8s-master1       | 192.168.80.11 | kube-apiserver    |
| k8s-master2       | 192.168.80.12 | kube-apiserver    |
| k8s-loadbalancer1 | 192.168.80.13 | nginx, keepalived |
| k8s-loadbalancer2 | 192.168.80.14 | nginx, keepalived |
| VIP               | 192.168.80.10 | 虚拟IP            |



## 11.1 安装软件

```bash
yum install epel-release
yum install nginx keepalived -y
```



## 11.2 配置Nginx

```bash
cat > /etc/nginx/nginx.conf << "EOF"
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

stream {

    log_format  main  '$remote_addr $upstream_addr - [$time_local] $status $upstream_bytes_sent';

    access_log  /var/log/nginx/k8s-access.log  main;

    upstream k8s-apiserver {
       server 192.168.80.11:6443;   # Master1 APISERVER IP:PORT
       server 192.168.80.12:6443;   # Master2 APISERVER IP:PORT
    }
    
    server {
       listen 16443; 
       proxy_pass k8s-apiserver;
    }
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen       80 default_server;
        server_name  _;

        location / {
        }
    }
}
EOF
```



## 11.3 keepalived 配置 (master)

```bash
cat > /etc/keepalived/keepalived.conf << EOF
global_defs { 
   notification_email { 
     acassen@firewall.loc 
     failover@firewall.loc 
     sysadmin@firewall.loc 
   } 
   notification_email_from Alexandre.Cassen@firewall.loc  
   smtp_server 127.0.0.1 
   smtp_connect_timeout 30 
   router_id NGINX_MASTER
} 

# 检查脚本
vrrp_script check_nginx {
    script "/etc/keepalived/check_nginx.sh"
}

vrrp_instance VI_1 { 
    state MASTER 
    interface ens33 # 修改为实际网卡名
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的 
    priority 100    # 优先级，备服务器设置 90 
    advert_int 1    # 指定VRRP 心跳包通告间隔时间，默认1秒 
    authentication { 
        auth_type PASS      
        auth_pass 1111 
    }  
    # 虚拟IP
    virtual_ipaddress { 
        192.168.80.10/24
    } 
    track_script {
        check_nginx
    } 
}
EOF
```



## 11.4 keepalived 配置 (slave)

```bash
cat > /etc/keepalived/keepalived.conf << EOF
global_defs { 
   notification_email { 
     acassen@firewall.loc 
     failover@firewall.loc 
     sysadmin@firewall.loc 
   } 
   notification_email_from Alexandre.Cassen@firewall.loc  
   smtp_server 127.0.0.1 
   smtp_connect_timeout 30 
   router_id NGINX_BACKUP
} 

# 检查脚本
vrrp_script check_nginx {
    script "/etc/keepalived/check_nginx.sh"
}

vrrp_instance VI_1 { 
    state BACKUP 
    interface ens33 # 修改为实际网卡名
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的 
    priority 90     # 优先级，备服务器设置 90 
    advert_int 1    # 指定VRRP 心跳包通告间隔时间，默认1秒 
    authentication { 
        auth_type PASS      
        auth_pass 1111 
    }  
    # 虚拟IP
    virtual_ipaddress { 
        192.168.80.10/24
    } 
    track_script {
        check_nginx
    } 
}
EOF
```



## 11.5 keepalived 检查脚本

```bash
cat > /etc/keepalived/check_nginx.sh  << "EOF"
#!/bin/bash
count=$(ss -antp |grep 16443 |egrep -cv "grep|$$")

if [ "$count" -eq 0 ];then
    exit 1
else
    exit 0
fi
EOF

chmod +x /etc/keepalived/check_nginx.sh
```



## 11.6 启动服务

```bash
systemctl daemon-reload
systemctl start nginx keepalived
systemctl enable nginx keepalived
```



## 11.7 状态检查

```bash
ip addr

curl -k https://192.168.80.10:16443/version


{
  "major": "1",
  "minor": "19",
  "gitVersion": "v1.19.11",
  "gitCommit": "c6a2f08fc4378c5381dd948d9ad9d1080e3e6b33",
  "gitTreeState": "clean",
  "buildDate": "2021-05-12T12:19:22Z",
  "goVersion": "go1.15.12",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```



11.8 Worker Node 连接到 LB VIP

```bash
sed -i 's#192.168.80.11:6443#192.168.80.10:16443#' /opt/kubernetes/cfg/*
systemctl restart kubelet kube-proxy

kubectl get node
NAME          STATUS   ROLES    AGE     VERSION
k8s-master1   Ready    master   3d17h   v1.19.11
k8s-master2   Ready    master   2d16h   v1.19.11
k8s-node1     Ready    node     3d15h   v1.19.11
k8s-node2     Ready    node     3d15h   v1.19.11
```





# 12. 附录

## 12.1 组件日志查询

```bash
journalctl -l -u kube-apiserver
journalctl -l -u kube-controller-manager
journalctl -l -u kube-scheduler
journalctl -l -u kubelet
journalctl -l -u kube-proxy
```

