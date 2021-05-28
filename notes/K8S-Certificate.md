# 1. Etcd

## 1.1 证书列表

```bash
ExecStart=/opt/etcd/bin/etcd \ 
--cert-file=/opt/etcd/ssl/server.pem \         # 服务器TLS证书
--key-file=/opt/etcd/ssl/server-key.pem \      # 服务器TLS证书私钥
--peer-cert-file=/opt/etcd/ssl/server.pem \    # 对端服务器TLS证书
--peer-key-file=/opt/etcd/ssl/server-key.pem \ # 对端服务器TLS证书私钥
--trusted-ca-file=/opt/etcd/ssl/ca.pem \       # CA证书
--peer-trusted-ca-file=/opt/etcd/ssl/ca.pem \  # 对端CA证书
```

综上，各类访问Etcd，可归并为同一套证书：

- 根证书：ca.pem 

- TLS证书：server.pem

- TLS证书私钥：server-key.pem

  

## 1.2 证书生成

### 1.2.1 CA 证书

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



### 1.2.2 签发 TLS 证书

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



# 2. Api-Server


## 2.1 证书列表

```bash
# token 认证方式
--enable-bootstrap-token-auth=true \\
--token-auth-file=/opt/kubernetes/cfg/token.csv \\

# kubelet 访问 api-server 所需要证书
--kubelet-client-certificate=/opt/kubernetes/ssl/server.pem \\
--kubelet-client-key=/opt/kubernetes/ssl/server-key.pem \\

# api-server 互联证书
--tls-cert-file=/opt/kubernetes/ssl/server.pem  \\
--tls-private-key-file=/opt/kubernetes/ssl/server-key.pem \\

# CA 证书
--client-ca-file=/opt/kubernetes/ssl/ca.pem \\

# Service Account 证书
--service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--service-account-issuer=api \\
--service-account-signing-key-file=/opt/kubernetes/ssl/server-key.pem \\

# 访问 etcd 的证书
--etcd-cafile=/opt/etcd/ssl/ca.pem \\
--etcd-certfile=/opt/etcd/ssl/server.pem \\
--etcd-keyfile=/opt/etcd/ssl/server-key.pem \\

# 代理访问证书，使用 kubectl proxy 时用到
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--proxy-client-cert-file=/opt/kubernetes/ssl/server.pem \\
--proxy-client-key-file=/opt/kubernetes/ssl/server-key.pem \\
```

综上，各类访问Api-Server，可归并为两种认证方式：

- token 认证
- 证书认证。它可使用同一套证书：
  - 根证书：ca.pem 
  - TLS证书：server.pem
  - TLS证书私钥：server-key.pem


## 2.2 token 认证

```bash
token=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')

# 格式：token，用户名，UID，用户组
cat > /opt/kubernetes/cfg/token.csv << EOF
$token,kubelet-bootstrap,10001,"system:node-bootstrapper"
EOF
```


## 2.3 证书认证

### 2.3.1 CA 证书

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



### 2.3.2 签发 TLS 证书

```bash
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







# 3. Controller-Manager

## 3.1 证书列表

```bash
# 集群内访问 api-server 的证书
--cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
--cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem  \\
--root-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \\

# 认证文件
--kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
```



## 3.2 证书生成

### 3.2.1 签发 TLS 证书

```bash
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
```



### 3.2.2 kubeconfig 认证文件

```bash
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



# 4. Scheduler

## 4.1 证书列表

```bash
--kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \
```



## 4.2 证书生成

### 4.2.1 签发 TLS 证书

```bash
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
```



### 4.2.2 kubeconfig 认证文件

```bash
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



# 5. 集群管理

## 5.1 签发 TLS 证书

```bash
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
```



## 5.2 kubeconfig 认证文件

```bash
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
```



# 6. TLS bootstrapping

授权 kubelet-bootstrap 用户允许请求证书

防止错误：`failed to run Kubelet: cannot create certificate signing request: certificatesigningrequests.certificates.k8s.io is forbidden: User "kubelet-bootstrap" cannot create resource "certificatesigningrequests" in API group "certificates.k8s.io" at the cluster scope`

```bash
kubectl create clusterrolebinding kubelet-bootstrap \
--clusterrole=system:node-bootstrapper \
--user=kubelet-bootstrap
```

 [TLS bootstrapping ](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/)的方式来简化 Kubelet 证书的生成过程。其原理是预先提供一个 bootstrapping token，kubelet 采用该 bootstrapping token 进行客户端验证，调用 kube-apiserver 的证书签发 API 来生成 自己需要的证书。要启用该功能，需要在 kube-apiserver 中启用 `--enable-bootstrap-token-auth` ，并创建一个 kubelet 访问 kube-apiserver 使用的 bootstrap token secret。如果使用 kubeadmin 安装，可以使用 `kubeadm token create`命令来创建 token。

采用TLS bootstrapping 生成证书的流程如下：

1. 调用 kube-apiserver 生成一个 bootstrap token。
2. 将该 bootstrap token 写入到一个 kubeconfig 文件中，作为 kubelet 调用 kube-apiserver 的客户端验证方式。
3. 通过 `--bootstrap-kubeconfig` 启动参数将 bootstrap token 传递给 kubelet 进程。
4. Kubelet 采用bootstrap token 调用 kube-apiserver API，生成自己所需的服务器和客户端证书。
5. 证书生成后，Kubelet 采用生成的证书和 kube-apiserver 进行通信，并删除本地的 kubeconfig 文件，以避免 bootstrap token 泄漏风险。



# 7. 加入集群

初次加入集群的引导文件：

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



# 8. 总结

- 整个k8s集群中，主要使用两套证书
  - etcd
  - api-server

- 另外，api-server 额外提供使用 token 方式认证，主要用于集群节点初次加入时的认证和Dashboard登录认证
- controller-manager, scheduler, kubelet 等对 api-server 的访问，均采用kubeconfig文件方式认证

