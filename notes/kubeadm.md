# Kubeadm原理

```bash
# 创建一个 Master 节点
$ kubeadm init

# 将一个 Node 节点加入到当前集群中
$ kubeadm join <Master 节点的 IP 和端口 >
```

执行 kubeadm init：

- 自动检查集群机器是否合规
- 自动生成集群运行所需的各类证书及各类配置，并将Master节点信息保存在名为cluster-info的ConfigMap中。
- 通过static Pod方式，运行API server, controller manager 、scheduler及etcd组件。
- 生成Token以便其他节点加入集群

执行 kubeadm join时：

- 节点通过token访问kube-apiserver，获取cluster-info中信息，主要是apiserver的授权信息（节点信任集群）。
- 通过授权信息，kubelet可执行TLS bootstrapping，与apiserver真正建立互信任关系（集群信任节点）。

**kubeadm做的事就是把大部分组件都容器化，通过StaticPod方式运行，并自动化了大部分的集群配置及认证等工作，简单几步即可搭建一个可用Kubernetes的集群。**



# Haproxy

```bash
# 安装haproxy
yum install haproxy -y 

# 修改haproxy配置
cat << EOF > /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    retries                 3
    timeout connect         10s
    timeout client          1m
    timeout server          1m

frontend kube-apiserver
    bind *:6443 # 指定前端端口
    mode tcp
    default_backend master

backend master # 指定后端机器及端口，负载方式为轮询
    balance roundrobin
    server master-1  192.168.41.230:6443 check maxconn 2000
    server master-2  192.168.41.231:6443 check maxconn 2000
EOF

# 开机默认启动haproxy，开启服务
systemctl enable haproxy
systemctl start haproxy

# 检查服务端口情况：
# netstat -lntup | grep 6443
tcp        0      0 0.0.0.0:6443            0.0.0.0:*               LISTEN      3110/haproxy
```

