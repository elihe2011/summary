# 1. 安装规划

| 角色       | IP            | 组件                                                         |
| ---------- | ------------- | ------------------------------------------------------------ |
| k8s-master | 192.168.80.10 | kube-apiserver, kube-controller-manager, kube-scheduler, etcd, docker |
| k8s-node1  | 192.168.80.11 | kubelet, kube-proxy, etcd, docker                            |
| k8s-node2  | 192.168.80.12 | kubelet, kube-proxy, etcd, docker                            |

# 2. 操作系统初始化

```bash
# 防火墙
systemctl stop firewalld
systemctl disable firewalld

# selinux
setenforce 0
sed -i 's/enforcing/disabled/' /etc/selinux/config 

# hostname
hostnamectl set-hostname <hostname>

# hosts
cat >> /etc/hosts << EOF
192.168.80.10 k8s-master
192.168.80.11 k8s-node1
192.168.80.12 k8s-node2
EOF

# 流量走 iptables 链路
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

# 时间同步
yum install ntpdate -y
ntpdate ntp.aliyun.com
crontab -e
*/10 * * * *  /usr/sbin/ntpdate-u ntp.aliyun.com >/dev/null 2>&1
```



# 3. Etcd 集群

## 3.1 **cfssl证书工具**

```bash
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64

mv cfssl_linux-amd64 /usr/local/bin/cfssl
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
mv cfssl-certinfo_linux-amd64 /usr/bin/cfssl-certinfo
```

## 3.2 生成证书

### 3.2.1 自签证书颁发机构（CA）

**在 k8s-master 节点生成：**

```bash
# 证书目录
mkdir -p ~/cert/{etcd,k8s}
cd ~/cert/etcd

# 自签CA
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
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF

# 生成证书
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

ls *pem
ca-key.pem  ca.pem
```

### 3.2.2 使用 CA 签发 Etcd https 证书

```bash
# 证书申请文件
cat > server-csr.json << EOF
{
    "CN": "etcd",
    "hosts": [
    "192.168.80.10",
    "192.168.80.11",
    "192.168.80.12"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "NJ",
            "ST": "JS"
        }
    ]
}
EOF

# 生成证书
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server

ls server*pem
server-key.pem  server.pem
```

## 3.3 部署 Etcd 集群

### 3.3.1 安装 Etcd

```bash
wget https://github.com/etcd-io/etcd/releases/download/v3.4.9/etcd-v3.4.9-linux-amd64.tar.gz

mkdir -p /opt/etcd/{bin,cfg,ssl}

tar zxvf etcd-v3.4.9-linux-amd64.tar.gz
mv etcd-v3.4.9-linux-amd64/{etcd,etcdctl} /opt/etcd/bin/
```



### 3.3.2 添加证书

**k8s-master 节点 **

```bash
# master
cp ~/cert/etcd/ca*pem ~/cert/etcd/server*pem /opt/etcd/ssl/

# node1 & node2
scp ~/cert/etcd/ca*pem root@k8s-node1:/opt/etcd/ssl/
scp ~/cert/etcd/server*pem root@k8s-node1:/opt/etcd/ssl/

scp ~/cert/etcd/ca*pem root@k8s-node2:/opt/etcd/ssl/
scp ~/cert/etcd/server*pem root@k8s-node2:/opt/etcd/ssl/
```



### 3.3.3 配置 Etcd

```bash
# 注意 ETCD_INITIAL_CLUSTER_STATE 的取值 new or existing

# k8s-master
cat > /opt/etcd/cfg/etcd.conf << EOF
#[Member]
ETCD_NAME="etcd-0"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.80.10:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.80.10:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.80.10:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.80.10:2379"
ETCD_INITIAL_CLUSTER="etcd-0=https://192.168.80.10:2380,etcd-1=https://192.168.80.11:2380,etcd-2=https://192.168.80.12:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new" 
EOF

# k8s-node1
cat > /opt/etcd/cfg/etcd.conf << EOF
#[Member]
ETCD_NAME="etcd-1"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.80.11:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.80.11:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.80.11:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.80.11:2379"
ETCD_INITIAL_CLUSTER="etcd-0=https://192.168.80.10:2380,etcd-1=https://192.168.80.11:2380,etcd-2=https://192.168.80.12:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# k8s-node2
cat > /opt/etcd/cfg/etcd.conf << EOF
#[Member]
ETCD_NAME="etcd-2"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.80.12:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.80.12:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.80.12:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.80.12:2379"
ETCD_INITIAL_CLUSTER="etcd-0=https://192.168.80.10:2380,etcd-1=https://192.168.80.11:2380,etcd-2=https://192.168.80.12:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new" 
EOF
```



### 3.3.4 启动 Etcd

```bash
# systemd
cat > /usr/lib/systemd/system/etcd.service << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=/opt/etcd/cfg/etcd.conf
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

# 启动
systemctl daemon-reload
systemctl start etcd
systemctl enable etcd
```



### 3.3.5 集群状态

```bash
ETCDCTL_API=3 /opt/etcd/bin/etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.80.10:2379,https://192.168.80.11:2379,https://192.168.80.12:2379" endpoint health

https://192.168.80.11:2379 is healthy: successfully committed proposal: took = 14.139038ms
https://192.168.80.10:2379 is healthy: successfully committed proposal: took = 47.604691ms
https://192.168.80.12:2379 is healthy: successfully committed proposal: took = 48.199917ms
```



# 4. 安装 docker

## 4.1 安装

```bash
wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz

tar zxvf docker-19.03.9.tgz

mv docker/* /usr/bin
```



## 4.2 配置

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://pvjhx571.mirror.aliyuncs.com"]
}
EOF
```



## 4.3 启动

```bash
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
```

