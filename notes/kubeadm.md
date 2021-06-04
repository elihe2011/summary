# 1. Kubeadm原理

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



# 2. Haproxy

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



# 3. 集群安装

| **角色**   | **IP**        | **组件**                                                     |
| ---------- | ------------- | ------------------------------------------------------------ |
| k8s-master | 192.168.80.40 | kube-apiserver，kube-controller-manager，kube-scheduler，docker, etcd |
| k8s-node1  | 192.168.80.41 | kubelet，kube-proxy，docker，etcd                            |
| k8s-node2  | 192.168.80.42 | kubelet，kube-proxy，docker，etcd                            |



K8S 版本：1.19.11



## 3.1 准备工作

```bash
# 1. 修改主机名
hostnamectl set-hostname k8s-master
hostnamectl set-hostname k8s-node01
hostnamectl set-hostname k8s-node02

# 2. 主机名解析
cat >> /etc/hosts <<EOF
192.168.80.40  k8s-master
192.168.80.41  k8s-node01
192.168.80.42  k8s-node02
EOF

# 3. 禁用 swap
swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. 将桥接的IPv4流量传递到iptables的链 
cat > /etc/sysctl.d/k8s.conf << EOF 
net.bridge.bridge-nf-call-ip6tables = 1 
net.bridge.bridge-nf-call-iptables = 1 
EOF
sysctl --system 
 
# 5. 时间同步 
apt install ntpdate -y 
ntpdate ntp1.aliyun.com

crontab -e
*/30 * * * * /usr/sbin/ntpdate-u ntp1.aliyun.com >> /var/log/ntpdate.log 2>&1
```



## 3.2 安装 kubeadm

```bash
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

apt-get update

# 查询可用版本
apt-cache policy kubeadm
1.19.11-00

# 安装 docker 19.03.15~3-0~ubuntu-xenial
apt-get install kubeadm=1.19.11-00~ubuntu-xenial -y

# master
apt-get install -y  kubeadm 
apt-get install -y kubeadm=1.19.11-00 kubelet=1.19.11-00 kubectl=1.19.11-00

# node
apt-get install -y kubeadm=1.19.11-00 kubelet=1.19.11-00
```



## 3.3 Master 节点

**初始化：**

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.80.40 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.19.11 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all
```

输出结果，用于节点加入集群：

```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.80.40:6443 --token a6jcpy.a33lzoxwxs0zx0fr \
    --discovery-token-ca-cert-hash sha256:986154509030b5a816cd6afc796d104c0f3fe24ff1e59bf769cb89b72f904112
```



**kubectl 连接 k8s 认证：**

```bash
# 不配置
kubectl get node
The connection to the server localhost:8080 was refused - did you specify the right host or port?

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```



## 3.3 Node 节点

**加入集群:**

```bash
kubeadm join 192.168.80.40:6443 --token a6jcpy.a33lzoxwxs0zx0fr \
    --discovery-token-ca-cert-hash sha256:986154509030b5a816cd6afc796d104c0f3fe24ff1e59bf769cb89b72f904112
```



## 3.4 安装网络插件

```bash
# 节点状态
kubectl get node
NAME         STATUS     ROLES    AGE    VERSION
k8s-master   NotReady   master   7m4s   v1.19.11
k8s-node01   NotReady   <none>   8s     v1.19.11
k8s-node02   NotReady   <none>   4s     v1.19.11

# 检查日志，发现网络插件未安装
journalctl -u kubelet -f
Jun 02 14:24:29 k8s-master kubelet[75636]: W0602 14:24:29.172144   75636 cni.go:239] Unable to update cni config: no networks found in /etc/cni/net.d
Jun 02 14:24:32 k8s-master kubelet[75636]: E0602 14:24:32.958021   75636 kubelet.go:2129] Container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
```

安装 calico 网络插件：

```bash
mkdir -p $HOME/k8s-install && cd $HOME/k8s-install

wget https://docs.projectcalico.org/manifests/calico.yaml

# CIDR的值，与 kubeadm中“--pod-network-cidr=10.244.0.0/16” 一致
vi calico.yaml
   3680             # The default IPv4 pool to create on startup if none exists. Pod IPs will be
   3681             # chosen from this range. Changing this value after installation will have
   3682             # no effect. This should fall within `--cluster-cidr`.
   3683             - name: CALICO_IPV4POOL_CIDR
   3684               value: "10.244.0.0/16"

# 安装网络插件
kubectl apply -f calico.yaml
```

检查 网络插件状态：

```bash
kubectl get pod -n kube-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-7f4f5bf95d-22gcz   1/1     Running   0          88s
calico-node-cj7fv                          1/1     Running   0          89s
calico-node-n26cx                          1/1     Running   0          89s
calico-node-rcqrf                          1/1     Running   0          89s
coredns-6d56c8448f-hn5h4                   1/1     Running   0          21m
coredns-6d56c8448f-wfwlf                   1/1     Running   0          21m
etcd-k8s-master                            1/1     Running   0          21m
kube-apiserver-k8s-master                  1/1     Running   0          21m
kube-controller-manager-k8s-master         1/1     Running   0          21m
kube-proxy-5pvd8                           1/1     Running   0          14m
kube-proxy-bqfkf                           1/1     Running   0          21m
kube-proxy-mdc4h                           1/1     Running   0          14m
kube-scheduler-k8s-master                  1/1     Running   0          21m

kubectl get node
NAME         STATUS   ROLES    AGE   VERSION
k8s-master   Ready    master   22m   v1.19.11
k8s-node01   Ready    <none>   15m   v1.19.11
k8s-node02   Ready    <none>   15m   v1.19.11
```



## 3.5 节点角色

```bash
 kubectl get node --show-labels
NAME         STATUS   ROLES    AGE   VERSION    LABELS
k8s-master   Ready    master   25m   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-master,kubernetes.io/os=linux,node-role.kubernetes.io/master=
k8s-node01   Ready    <none>   18m   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node01,kubernetes.io/os=linux
k8s-node02   Ready    <none>   18m   v1.19.11   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node02,kubernetes.io/os=linux

kubectl label node k8s-node01 node-role.kubernetes.io/node=
kubectl label node k8s-node02 node-role.kubernetes.io/node=
```



## 3.6 token 过期

kubeadm join 加入集群时，需要2个参数，--token与--discovery-token-ca-cert-hash。其中，token有限期一般是24小时，如果超过时间要新增节点，就需要重新生成token。

```bash
# token
kubeadm token create
s058gw.c5x6eeze2875sza1

# discovery-token-ca-cert-hash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
986154509030b5a816cd6afc796d104c0f3fe24ff1e59bf769cb89b72f904112

# 新节点加入
kubeadm join api-serverip:port --token s058gw.c5x6eeze28**** --discovery-token-ca-cert-hash 9592464b295699696ce35e5d1dd155580ee29d9bd0884b*****

kubeadm join 192.168.80.40:6443 --token s058gw.c5x6eeze2875sza1 \
    --discovery-token-ca-cert-hash sha256:986154509030b5a816cd6afc796d104c0f3fe24ff1e59bf769cb89b72f904112
```



# 4. 问题汇总

## 4.1 kubelet 无法正常启动

kubelet无法正常启动，导致执行kubeadm时出现如下错误：

```bash
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[kubelet-check] Initial timeout of 40s passed.

        Unfortunately, an error has occurred:
                timed out waiting for the condition

        This error is likely caused by:
                - The kubelet is not running
                - The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)

        If you are on a systemd-powered system, you can try to troubleshoot the error with the following commands:
                - 'systemctl status kubelet'
                - 'journalctl -xeu kubelet'

        Additionally, a control plane component may have crashed or exited when started by the container runtime.
        To troubleshoot, list all containers using your preferred container runtimes CLI.

        Here is one example how you may list all Kubernetes containers running in docker:
                - 'docker ps -a | grep kube | grep -v pause'
                Once you have found the failing container, you can inspect its logs with:
                - 'docker logs CONTAINERID'
```

解决办法，修改 docker 的cgroupdriver:

```bash
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

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
systemctl restart docker
```

重做初始化：

```bash
kubeadm reset

kubeadm init xxx
```



## 4.2 ubuntu 16 默认内核

```bash
uname -r
4.4.0-142-generic

# 内核参数告警
systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2021-06-02 14:11:22 CST; 10s ago
     Docs: https://docs.docker.com
 Main PID: 52488 (dockerd)
    Tasks: 10
   Memory: 57.5M
      CPU: 1.767s
   CGroup: /system.slice/docker.service
           └─52488 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.031860026+08:00" level=warning msg="Your kernel does not support swap memory limit"
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.031910601+08:00" level=warning msg="Your kernel does not support cgroup rt period"
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.031917871+08:00" level=warning msg="Your kernel does not support cgroup rt runtime"
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.032178268+08:00" level=info msg="Loading containers: start."
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.118451062+08:00" level=info msg="Default bridge (docker0) is assigned with an IP address 172.17.0.0/16. Daemon option --bip c
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.146043534+08:00" level=info msg="Loading containers: done."
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.614147613+08:00" level=info msg="Docker daemon" commit=99e3ed8919 graphdriver(s)=overlay2 version=19.03.15
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.614842390+08:00" level=info msg="Daemon has completed initialization"
Jun 02 14:11:22 k8s-node01 dockerd[52488]: time="2021-06-02T14:11:22.654911232+08:00" level=info msg="API listen on /var/run/docker.sock"
```

