# 1. 网络问题

## 1.1 Pod IP地址分配错误

### 1.1.1 现象

pod-cidr: 10.244.0.0/16，但pod的ip地址为172.17.0.2

```bash
root@k8s-master:~# kubectl run -it --rm dns-test --image=busybox:1.28.4 /bin/sh
If you don't see a command prompt, try pressing enter.
/ # ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
8: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

检查发现：pod使用了docker0的网段

```bash
root@k8s-master:/opt/oict/yml# ip addr
6: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:50:5e:69:21 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:50ff:fe5e:6921/64 scope link
       valid_lft forever preferred_lft forever
8: vethebd7975@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default
    link/ether 4e:9d:d6:d3:ac:22 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::4c9d:d6ff:fed3:ac22/64 scope link
       valid_lft forever preferred_lft forever
```

### 1.1.2 问题根源

kubelet 启动，未指定参数`--network-plugin`

### 1.1.3 解决方案

- 方案一：修改docker的bip等参数，使其与pod-cir在一个网段中

  ```bash
  DOCKER_OPTS=" --bip=10.244.0.1/24 --ip-masq=false --mtu=1450"
  ```

- 方案二：kubelet启动参数，指定cni网络

  ```bash
  # 修改kubelet启动配置，增加
  kubelet ... --network-plugin=cni
  
  # 重启
  systemctl restart kubelet
  
  # 创建cni0网桥
  kubectl delete -f kube-flannel.yml
  rm -rf /etc/cni/
  ip link del flannel.1 cni0
  
  
  ifconfig  cni0 down
  brctl delbr cni0
  ip link delete flannel.1
  ```

  

## 1.2 kube-proxy 问题

### 1.2.1 现象

kube-proxy 启动日志

```bash
I1209 20:24:25.923109   14968 proxier.go:1055] Stale udp service kube-system/kube-dns:dns -> 10.96.0.2
I1209 20:24:26.103211   14968 proxier.go:1472] Opened local port "nodePort for kube-system/grafana" (:30000/tcp4)
E1209 20:24:26.204991   14968 proxier.go:1689] Failed to delete stale service IP 10.96.0.2 connections, error: error deleting connection tracking state for UDP service IP: 10.96.0.2, error: error looking for path of conntrack: exec: "conntrack": executable file not found in $PATH
I1209 20:24:26.205484   14968 proxier.go:1034] Not syncing ipvs rules until Services and Endpoints have been received from master
```

kubedns启动成功，运行正常，但是service之间无法解析，kubernetes中的DNS解析异常

### 1.2.2 问题根源

**缺失 conntrack 可执行文件**

conntrack：是一个用户态的命令，用于控制内核中ip_conntrack模块的，该模块是用于处理链路追踪的工具。就是iptables和netfilter的关系。
ip_conntrack模块：数据包(a -> b)经过网关，发生了SNAT，地址信息成为了(m -> b)，虽然发生了nat，(a -> b)和(m -> b)应该是属于同一个数据流conntrack的，ip_conntrack需要作记录，以便将两个流绑定在一起，数据从a到b的方向在网关处成了由m到b的方向，属于一个方向，都是源到目的，发生了SNAT后，数据就可以出去了，既然数据离开了网关，我们也就不必关心它了，我们关心的是从b发出的回应a数据到达网关后如何将之绑定到流conntrack，数据回来后由于发生过snat流标示显然是(b -> m)，于是ip_conntrack需要将(b-m)也绑定到conntrack，这样才能将数据返回。由于ip_conntrack帮助，可以将两个连接捆绑到一起，通过ip_conntrack来帮助netfilter进行流量转发。

### 1.2.3 解决方案

```bash
apt install conntrack

systemctl restart kube-proxy

# 检查：ok
I1210 11:14:40.245388     915 service.go:421] Adding new service port "default/kubernetes:https" at 10.96.0.1:443/TCP
I1210 11:14:40.245424     915 service.go:421] Adding new service port "kube-system/kube-dns:dns" at 10.96.0.2:53/UDP
I1210 11:14:40.245441     915 service.go:421] Adding new service port "kube-system/kube-dns:dns-tcp" at 10.96.0.2:53/TCP
I1210 11:14:40.245466     915 service.go:421] Adding new service port "kube-system/kube-dns:metrics" at 10.96.0.2:9153/TCP
I1210 11:14:40.245481     915 service.go:421] Adding new service port "kube-system/prometheus" at 10.96.197.236:9090/TCP
I1210 11:14:40.245494     915 service.go:421] Adding new service port "kube-system/grafana" at 10.96.168.225:3000/TCP
I1210 11:14:40.245522     915 service.go:421] Adding new service port "kube-system/alertmanager" at 10.96.60.105:9093/TCP
I1210 11:14:40.245693     915 proxier.go:1055] Stale udp service kube-system/kube-dns:dns -> 10.96.0.2
I1210 11:14:40.326045     915 proxier.go:1472] Opened local port "nodePort for kube-system/grafana" (:30000/tcp4)
```



## 1.3 VIP 问题

### 1.3.1 现象

网卡配置多个IP地址，NodePort访问集群，不支持VIP

My environment has changed, in simple terms:
kube-proxy bind 0.0.0.0, proxyMode is ipvs

interface's real ip:nodeport can access the nodeport
interface's vip:nodeport cannot access the nodeport

```bash
# ip addr show enp1s0
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:34:a8:fd brd ff:ff:ff:ff:ff:ff
    inet 192.168.3.182/24 brd 192.168.3.255 scope global enp1s0
       valid_lft forever preferred_lft forever
    inet 192.168.3.187/24 scope global secondary enp1s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe34:a8fd/64 scope link
       valid_lft forever preferred_lft forever
       
# ipvsadm -Ln
TCP  192.168.3.182:30000 rr
  -> 10.244.1.15:3000             Masq    1      0          7
```



### 1.3.2 问题根源

ipvs 模式下，不支持kube-proxy不支持vip绑定，临时解决方法如下：

```bash
# ip route show table local
local 192.168.3.182 dev enp1s0 proto kernel scope host src 192.168.3.182
local 192.168.3.187 dev enp1s0 proto kernel scope host src 192.168.3.182

this is caused by the vip worked in secondary interface.
wrong: inet 172.16.1.240/24 scope global secondary eth0
correct: inet 172.16.1.240/24 scope global eth0
so you should change vip mask to 32 not 24, like 172.16.1.240/32 to avoid in secondary or slave status.

# ip addr del 192.168.3.187/24 dev enp1s0
# ip addr add 192.168.3.187/32 dev enp1s0
# ip route show table local
local 192.168.3.182 dev enp1s0 proto kernel scope host src 192.168.3.182
local 192.168.3.187 dev enp1s0 proto kernel scope host src 192.168.3.187
```



### 1.3.3 解决方案

[kube-proxy 代码](https://github.com/kubernetes/kube-proxy/blob/master/config/v1alpha1/types.go#L158)：

```go
type KubeProxyConfiguration struct {
    ...
	// nodePortAddresses is the --nodeport-addresses value for kube-proxy process. Values must be valid
	// IP blocks. These values are as a parameter to select the interfaces where nodeport works.
	// In case someone would like to expose a service on localhost for local visit and some other interfaces for
	// particular purpose, a list of IP blocks would do that.
	// If set it to "127.0.0.0/8", kube-proxy will only select the loopback interface for NodePort.
	// If set it to a non-zero IP block, kube-proxy will filter that down to just the IPs that applied to the node.
	// An empty string slice is meant to select all network interfaces.
	NodePortAddresses []string `json:"nodePortAddresses"`
	...
}

```



修改配置：

```bash
# vi /etc/kubernetes/kube-proxy-config.yml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 192.168.3.187
metricsBindAddress: 0.0.0.0:10249
clientConnection:
  kubeconfig: /etc/kubernetes/kube-proxy.kubeconfig
hostnameOverride: k8s-master
clusterCIDR: 10.96.0.0/16
iptables:
  masqueradeAll: true
  masqueradeBit: 14
  minSyncPeriod: 5s
  syncPeriod: 30s
ipvs:
  scheduler: rr
  minSyncPeriod: 5s
  syncPeriod: 30s
mode: ipvs
nodePortAddresses:      # 新增
- 127.0.0.1/8
- 192.168.3.187/24
- 10.20.10.203/24

# systemctl restart kube-proxy

# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.3.182:30000 rr
  -> 10.244.1.18:3000             Masq    1      0          14
TCP  192.168.3.187:30000 rr
  -> 10.244.1.18:3000             Masq    1      0          13
TCP  10.20.10.203:30000 rr
  -> 10.244.1.18:3000             Masq    1      0          0
TCP  127.0.0.1:30000 rr
  -> 10.244.1.18:3000             Masq    1      0          0
```

