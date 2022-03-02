# 1. 概述

Calico是一个基于 BGP 的纯三层网络方案。它在每个计算节点都利用 Linux kernel 实现了一个高效的虚拟路由器 **vRouter 来进行数据转发**。每个 vRouter 都通过 BGP 协议将本节点上运行容器的路由信息向整个 Calico 网络广播，并自动设置到达其他节点的路由转发规则。

Calico 保证所有容器之间的数据流量都通过 IP 路由的方式完成互联互通。Calico 节点组网可以直接利用数据中心的网络结构 (L2/L3)，不需要额外的 NAT，隧道或者 Overlay 网络，没有额外的封包解包，节省 CPU 资源，提高网络效率。



# 2. 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/calico-arch.png) 

工作组件：

- **Felix**：运行在每台节点上的 agent 进程。主要负责路由维护和ACLs(访问控制列表)，使得该主机上的 endpoints 资源正常运行提供所需的网络连接
- **Etcd**：持久化存储 calico 网络状态数据
- **BIRD** (BGP Client)：将 BGP 协议广播告诉剩余的 calico 节点，从而实现网络互通
- **BGP Route Reflector**：BGP 路由反射器，可选组件，用于较大规模组网



# 3. 部署

清理cni相关配置：

```bash
ip link set cni0 down
ip link delete cni0

rm -rf /etc/cni/net.d
rm -rf /var/lib/cni
```

安装 Calico：

```bash
# 1. 下载插件
$ wget https://docs.projectcalico.org/v3.20/manifests/calico.yaml

# CIDR的值，与 kube-controller-manager中“--cluster-cidr=10.244.0.0/16” 一致
$ vi calico.yaml
...
spec:
  ...
  template:
    ...
    spec:
      ...
      containers:
        ...
        - name: calico-node
          ...
          env:
            - name: DATASTORE_TYPE
              value: "kubernetes"
            - name: IP_AUTODETECTION_METHOD  # new add, multi interfaces
              value: interface=ens33
		    ...
		    # Auto-detect the BGP IP address.
            - name: IP
              value: "autodetect"
            # Enable IPIP
            - name: CALICO_IPV4POOL_IPIP     # IPIP mode by default
              value: "Always"
            # Enable or Disable VXLAN on the default IP pool.
            - name: CALICO_IPV4POOL_VXLAN
              value: "Never"
            ...
            - name: CALICO_IPV4POOL_CIDR
              value: "10.244.0.0/16"

# 2. 安装网络插件
$ kubectl apply -f calico.yaml

# 3. 检查是否启动
$ kubectl get pod -n kube-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-654b987fd9-cq26z   1/1     Running   0          11m
calico-node-fkcvj                          1/1     Running   0          11m
calico-node-np65c                          1/1     Running   0          11m
calico-node-p8g9t                          1/1     Running   0          11m

# 4. 节点状态正常
$ kubectl get node
NAME         STATUS   ROLES                  AGE     VERSION
k8s-master   Ready    control-plane,master   7d18h   v1.21.4
k8s-node01   Ready    <none>                 7d18h   v1.21.4
k8s-node02   Ready    <none>                 7d18h   v1.21.4

# 5. 安装管理工具
$ wget -O /usr/local/bin/calicoctl https://github.com/projectcalico/calicoctl/releases/download/v3.20.4/calicoctl-linux-amd64
$ chmod +x /usr/local/bin/calicoctl

# 6. 节点状态
$ calicoctl node status
Calico process is running.

IPv4 BGP status
+----------------+-------------------+-------+----------+-------------+
|  PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+----------------+-------------------+-------+----------+-------------+
| 192.168.80.101 | node-to-node mesh | up    | 06:15:16 | Established |
| 192.168.80.102 | node-to-node mesh | up    | 06:15:15 | Established |
+----------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```



创建测试应用：

```yaml
# busybox-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
    spec:
      containers:
      - name: busybox
        image: busybox:1.28.4
        command:
        - sleep
        - "86400"
```



# 4. IPIP 模式

将一个IP数据包封装到另一个IP包中，即把IP层封装到IP层的一个tunnel。其作用基本相当于一个基于IP层的网桥。一般来说，普通的网桥是基于mac层的，不需要IP，而这个IPIP则通过两端的路由做一个 tunnel，把两个本来不通的网络通过点对点连接起来。

<font color="red">**配置环境变量**</font>：`CALICO_IPV4POOL_IPIP=Always`

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/calico-ipip-flow.png)

**流量**：tunl0设备封装数据，形成隧道，承载流量。

**适用网络类型**：适用于互相访问的pod不在同一个网段中，跨网段访问的场景。外层封装的ip能够解决跨网段的路由问题。

**效率**：流量需要tunl0设备封装，效率略低。



## 4.1 Pod 网络

```bash
$ kubectl get pod -l app=busybox -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE         NOMINATED NODE   READINESS GATES
busybox-deploy-5c8bbcc5f7-ddmm9   1/1     Running   0          68s   10.244.58.193   k8s-node02   <none>           <none>
busybox-deploy-5c8bbcc5f7-fhqvh   1/1     Running   0          68s   10.244.85.194   k8s-node01   <none>           <none>
busybox-deploy-5c8bbcc5f7-ksr4z   1/1     Running   0          68s   10.244.58.194   k8s-node02   <none>           <none>

$ kubectl exec -it busybox-deploy-5c8bbcc5f7-ddmm9 -- /bin/sh
/ # ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if13: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1480 qdisc noqueue
    link/ether 06:bf:22:76:89:a9 brd ff:ff:ff:ff:ff:ff
    inet 10.244.58.193/32 brd 10.244.58.193 scope global eth0
       valid_lft forever preferred_lft forever
/ # ip route
default via 169.254.1.1 dev eth0   # 默认写死的路由IP地址
169.254.1.1 dev eth0 scope link
```



## 4.2 宿主机网络

节点：k8s-node02

```bash
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.80.2    0.0.0.0         UG    0      0        0 ens33
10.244.1.0      192.168.80.101  255.255.255.0   UG    0      0        0 tunl0
10.244.58.192   0.0.0.0         255.255.255.192 U     0      0        0 *
10.244.58.193   0.0.0.0         255.255.255.255 UH    0      0        0 cali918b33f2bbe
10.244.58.194   0.0.0.0         255.255.255.255 UH    0      0        0 cali54491a66381
10.244.85.192   192.168.80.101  255.255.255.192 UG    0      0        0 tunl0  # 使用隧道tunl0, 访问10.244.85.192/26网络
10.244.235.192  192.168.80.100  255.255.255.192 UG    0      0        0 tunl0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.70.0    0.0.0.0         255.255.255.0   U     0      0        0 ens38
192.168.80.0    0.0.0.0         255.255.255.0   U     0      0        0 ens33
```

补充：路由Flags含义

- U: up
- H: host，主机路由，多为达到数据包的路由
- G: gateway，网络路由，如果没有说明目的地是直连的
- D: Dynamically 该路是重定向报文修改
- M: 该路由已被重定向报文修改

ping包流程：10.244.85.195/26 => 10.244.85.192 =>192.168.80.241，即通过tul0发到k8s-node01



## 4.3 抓包分析

节点 k8s-node01 上的 pod 访问 k8s-node02 上的pod：

```bash
$ kubectl exec -it busybox-deploy-5c8bbcc5f7-ddmm9 -- /bin/sh
# ping 10.244.85.194
```

节点 k8s-node02 上：

```bash
$ tcpdump -i ens33 -vvv -w ipip.pcap
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/calico-ipip-tcpdump.png)



# 5. BGP 模式

边界网关协议（Border Gateway Protocol）是互联网上一个核心的去中心化自治路由协议。它通过维护IP路由表或前缀来实现自治系统（AS）之间的可达性，属于矢量路由协议。BGP不使用传统的内部网关协议（IGP）的指标，而使用基于路径、网络策略或规则集来决定路由。因此，它更适合称为矢量性协议，而不是路由协议。

BGP通俗讲就是接入到机房的多条线路融合为一体，实现多线单IP。BGP机房优点：服务器只需要设置一个IP地址，最佳访问路由是由网络上的骨干路由器根据路由跳数与其他技术指标来确定的，不会占用服务器的任何系统。

<font color="red">**配置环境变量**</font>：`CALICO_IPV4POOL_IPIP=Never`

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/calico-bgp-flow.png)

**流量**：使用主机路由表信息导向流量

**适用网络类型**：适用于互相访问的pod在同一个网段，适用于大型网络。

**效率**：原生hostGW，效率高。



## 5.1 Pod 网络

```bash
$ kubectl get pod -l app=busybox -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE         NOMINATED NODE   READINESS GATES
busybox-deploy-5c8bbcc5f7-94fqh   1/1     Running   0          15s   10.244.58.192   k8s-node02   <none>           <none>
busybox-deploy-5c8bbcc5f7-m2h72   1/1     Running   0          15s   10.244.58.193   k8s-node02   <none>           <none>
busybox-deploy-5c8bbcc5f7-rxmcc   1/1     Running   0          15s   10.244.85.193   k8s-node01   <none>           <none>

$ kubectl exec -it busybox-deploy-5c8bbcc5f7-94fqh -- /bin/sh
/ # route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         169.254.1.1     0.0.0.0         UG    0      0        0 eth0
169.254.1.1     0.0.0.0         255.255.255.255 UH    0      0        0 eth0
/ # ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if17: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 4e:77:d1:be:6c:fc brd ff:ff:ff:ff:ff:ff
    inet 10.244.58.192/32 brd 10.244.58.192 scope global eth0
       valid_lft forever preferred_lft forever
```



## 5.2 宿主机网络

节点 k8s-node02:

```bash
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.80.2    0.0.0.0         UG    0      0        0 ens33
10.244.1.0      192.168.80.101  255.255.255.0   UG    0      0        0 ens33
10.244.58.192   0.0.0.0         255.255.255.255 UH    0      0        0 cali86c3817fabd
10.244.58.192   0.0.0.0         255.255.255.192 U     0      0        0 *
10.244.58.193   0.0.0.0         255.255.255.255 UH    0      0        0 calib35fb91ccc9
10.244.85.192   192.168.80.101  255.255.255.192 UG    0      0        0 ens33     # 10.244.85.192 网段走路由
10.244.235.192  192.168.80.100  255.255.255.255 UGH   0      0        0 ens33
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.70.0    0.0.0.0         255.255.255.0   U     0      0        0 ens38
192.168.80.0    0.0.0.0         255.255.255.0   U     0      0        0 ens33

$ ip route
default via 192.168.80.2 dev ens33 proto static
10.244.1.0/24 via 192.168.80.101 dev ens33 proto bird
10.244.58.192 dev cali86c3817fabd scope link
blackhole 10.244.58.192/26 proto bird     # 黑洞路由，如果没有其他优先级更高的路由，主机会将所有目的地址为10.244.58.192/26的网络数据丢弃掉
10.244.58.193 dev calib35fb91ccc9 scope link
10.244.85.192/26 via 192.168.80.101 dev ens33 proto bird
10.244.235.192 via 192.168.80.100 dev ens33 proto bird
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.70.0/24 dev ens38 proto kernel scope link src 192.168.70.102
192.168.80.0/24 dev ens33 proto kernel scope link src 192.168.80.102
```



## 5.3 互通

calico使用BGP网络模式通信网络传输速率较好，但是跨节点后pod不能通信。

k8s-node02 上的 pod 尝试访问 k8s-node01 上的pod，失败：

```bash
$ kubectl exec -it busybox-deploy-5c8bbcc5f7-94fqh -- /bin/sh
/ # ping -c 3 10.244.85.193
PING 10.244.85.193 (10.244.85.193): 56 data bytes

--- 10.244.85.193 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
```



# 6. 总结

## 6.1 IPIP vs BGP

|          | IPIP                              | BGP                         |
| -------- | --------------------------------- | --------------------------- |
| 流量     | tunl0封装数据，形成隧道，承载流量 | 路由信息导向流量            |
| 适用场景 | Pod跨网段互访                     | Pod同网段互访，适合大型网络 |
| 效率     | 需要tunl0设备封装，效率略低       | 原生hostGW, 效率高          |
| 类型     | overlay                       | underlay          |



## 6.2 Calico 问题

- 缺乏租户隔离

  Calico的三层方案是直接在host上进行路由寻址，多租户如果想使用同一个 CIDR网络将面临地址冲突问题

- 路由规模

  路由规模和pod分布有关，如果pod离散分布在host集群中，势必产生较多的额路由项

- iptables规则规模

  每个容器实例都会产生iptables规则，当实例多时，过多的iptables规则会造成负责性和不可调试性，同时也存在性能损耗

- 跨子网时的网关路由问题

  当对端网络不为二层可达时，需要通过三层路由器，此时网关要支持自定义路由配置，即Pod的目的地址为本网段的网关地址，再由网关进行跨三层转发



















