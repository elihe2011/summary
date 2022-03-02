# 1. 简介

Flannel 由CoreOS开发，用于解决**docker集群跨主机通讯**的覆盖网络(overlay network)，它的主要思路是：预先留出一个网段，每个主机使用其中一部分，然后每个容器被分配不同的ip；让所有的容器认为大家在同一个直连的网络，底层通过UDP/VxLAN/Host-GW等进行报文的封装和转发。



实现原理：

- 集群中的不同节点上，创建的Pod具有全集群唯一的虚拟IP地址。

- 建立一个覆盖网络（overlay network），通过这个覆盖网络，将数据包原封不动的传递到目标容器。覆盖网络通过将一个分组封装在另一个分组内来将网络服务与底层基础设施分离。在将封装的数据包转发到端点后，将其解封装。
- 创建一个新的虚拟网卡flannel0接收docker网桥的数据，通过维护路由表，对接收到的数据进行封包和转发（vxlan）。
- etcd保证了所有node上flanned所看到的配置是一致的。同时每个node上的flanned监听etcd上的数据变化，实时感知集群中node的变化。



# 2. Vxlan 模式

## 2.1 通信流程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph/kubernetes/k8s-flannel-vxlan.png)

**不同node上的pod通信流程：**

1. pod中的数据，根据pod的路由信息，发送到网桥 cni0
2. cni0 根据节点路由表，将数据发送到隧道设备flannel.1
3. flannel.1 查看数据包的目的ip，从flanneld获取对端隧道设备的必要信息，封装数据包
4. flannel.1 将数据包发送到对端设备。对端节点的网卡接收到数据包，发现数据包为overlay数据包，解开外层封装，并发送内层封装到flannel.1 设备
5. Flannel.1 设备查看数据包，根据路由表匹配，将数据发送给cni0设备
6. cni0匹配路由表，发送数据到网桥



## 2.2 部署

```bash
$ wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 配置 Pod CIDR 
$ vi kube-flannel.yml
  "Network": "10.244.0.0/16", 
  
# 多网卡时，可指定网卡
vi kube-flannel.yml
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=ens38    # 指定网卡
        
$ kubectl apply -f kube-flannel.yml

$ kubectl get pod -n kube-system
NAME                    READY   STATUS    RESTARTS   AGE
kube-flannel-ds-8qnnx   1/1     Running   0          10s
kube-flannel-ds-979lc   1/1     Running   0          16m
kube-flannel-ds-kgmgg   1/1     Running   0          16m
```



集群节点上网络分配：

```bash
$ ip addr
6: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default
    link/ether b6:95:2a:cd:01:c3 brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.0/32 brd 10.244.0.0 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::b495:2aff:fecd:1c3/64 scope link
       valid_lft forever preferred_lft forever
7: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default qlen 1000
    link/ether 16:ac:e9:68:a4:c0 brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.1/24 brd 10.244.0.255 scope global cni0
       valid_lft forever preferred_lft forever
    inet6 fe80::14ac:e9ff:fe68:a4c0/64 scope link
       valid_lft forever preferred_lft forever

$ ethtool -i cni0
driver: bridge

$ ethtoo -i flannel.1
driver: vxlan

$ ps -ef | grep flanneld
root       15300   15275  0 10:21 ?        00:00:19 /opt/bin/flanneld --ip-masq --kube-subnet-mgr

$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.80.2    0.0.0.0         UG    0      0        0 ens33
10.244.0.0      10.244.0.0      255.255.255.0   UG    0      0        0 flannel.1
10.244.1.0      10.244.1.0      255.255.255.0   UG    0      0        0 flannel.1
10.244.2.0      0.0.0.0         255.255.255.0   U     0      0        0 cni0
192.168.80.0    0.0.0.0         255.255.255.0   U     0      0        0 ens33

$ brctl show
bridge name     bridge id               STP enabled     interfaces
cni0            8000.e2ee89678398       no              veth28b04daf
                                                        vethe6d4a6b8
```

**cni0**: 网桥设备，每创建一个pod都会创建一对 veth pair。其中一段是pod中的eth0，另一端是cni0网桥中的端口。

**flannel.1**: vxlan网关设备，用户 vxlan 报文的解包和封包。不同的 pod 数据流量都从overlay设备以隧道的形式发送到对端。flannel.1不会发送arp请求去获取目标IP的mac地址，而是由Linux kernel将一个"L3 Miss"事件请求发送到用户空间的flanneld程序，flanneld程序收到内核的请求事件后，从etcd中查找能够匹配该地址的子网flannel.1设备的mac地址，即目标pod所在host中flannel.1设备的mac地址。

**flanneld**: 在每个主机中运行flanneld作为agent，它会为所在主机从集群的网络地址空间中，获取一个小的网段subnet，本主机内所有容器的IP地址都将从中分配。同时Flanneld监听K8s集群数据库，为flannel.1设备提供封装数据时必要的mac，ip等网络数据信息。

**VXLAN**：Virtual eXtensible Local Area Network，虚拟扩展局域网。**采用L2 over L4（MAC-in-UDP）的报文封装模式，将二层报文用三层协议进行封装，实现二层网络在三层范围内进行扩展**，同时满足数据中心大二层虚拟迁移和多租户的需求。

flannel只使用了vxlan的部分功能，VNI被固定为1。**容器跨网络通信解决方案：如果集群的主机在同一个子网内，则通过路由转发过去；若不在一个子网内，就通过隧道转发过去。**



## 2.3 相关配置

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph/kubernetes/k8s-flannel-cni.png)

```bash
$ cat /etc/cni/net.d/10-flannel.conflist
{
  "name": "cbr0",
  "cniVersion": "0.3.1",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}

$ cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true

# Bridge CNI 插件
$ cat /var/lib/cni/flannel/462cf658ef71d558b36884dfb6d068e100a3209d36ba2602ad04dd9445e63684 | python3 -m json.tool
{
    "cniVersion": "0.3.1",
    "hairpinMode": true,
    "ipMasq": false,
    "ipam": {
        "routes": [
            {
                "dst": "10.244.0.0/16"
            }
        ],
        "subnet": "10.244.2.0/24",
        "type": "host-local"
    },
    "isDefaultGateway": true,
    "isGateway": true,
    "mtu": 1450,
    "name": "cbr0",
    "type": "bridge"
}
```



## 2.4 卸载

```bash
# 主节点
kubectl delete -f kube-flannel.yml

# 所有节点上
ip link set cni0 down
ip link set flannel.1 down

ip link delete cni0
ip link delete flannel.1

rm -rf /var/lib/cni/
rm -f /etc/cni/net.d/*
```



# 3. Host-GW 模式

## 3.1 通信流程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph/kubernetes/k8s-flannel-hostgw.png)

**host-gw采用纯静态路由的方式，要求所有宿主机都在一个局域网内，跨局域网无法进行路由**。如果需要进行跨局域网路由，需要在其他设备上添加路由，但已超出flannel的能力范围。可选择calico等使用动态路由技术，通过广播路由的方式将本机路由公告出去，从而实现跨局域网路由学习。

所有的子网和主机的信息，都保存在Etcd中，flanneld只需要watch这些数据的变化 ，实时更新路由表。
核心：**IP包在封装成桢的时候，使用路由表的“下一跳”设置上的MAC地址，这样可以经过二层网络到达目的宿主机。**



## 3.2 部署

```bash
$ vi kube-flannel.yml
      "Backend": {
        "Type": "host-gw"
      }

$ kubectl apply -f kube-flannel.yml

$ kubectl get pod -n kube-system
NAMESPACE     NAME                    READY   STATUS    RESTARTS   AGE
kube-system   kube-flannel-ds-l2dg7   1/1     Running   0          7s
kube-system   kube-flannel-ds-tj2vg   1/1     Running   0          7s
kube-system   kube-flannel-ds-xxhfm   1/1     Running   0          7s
```



集群节点上网络分配：

```bash
$ ip addr
7: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 2a:00:05:23:3f:5e brd ff:ff:ff:ff:ff:ff
    inet 10.244.2.1/24 brd 10.244.2.255 scope global cni0
       valid_lft forever preferred_lft forever
    inet6 fe80::2800:5ff:fe23:3f5e/64 scope link
       valid_lft forever preferred_lft forever

$ kubectl logs kube-flannel-ds-l2dg7 -n kube-system
I1227 12:09:56.991787       1 route_network.go:86] Subnet added: 10.244.2.0/24 via 192.168.80.240
I1227 12:09:56.992305       1 route_network.go:86] Subnet added: 10.244.0.0/24 via 192.168.80.241

$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.80.2    0.0.0.0         UG    0      0        0 ens33
10.244.0.0      192.168.80.241  255.255.255.0   UG    0      0        0 ens33
10.244.1.0      192.168.80.242  255.255.255.0   UG    0      0        0 ens33
10.244.2.0      0.0.0.0         255.255.255.0   U     0      0        0 cni0
192.168.80.0    0.0.0.0         255.255.255.0   U     0      0        0 ens33
```



## 3.3 相关配置

```bash
$ cat /etc/cni/net.d/10-flannel.conflist
{
  "name": "cbr0",
  "cniVersion": "0.3.1",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}

$ cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1500  # 路由方式下，MTU值使用默认值
FLANNEL_IPMASQ=true

# Bridge CNI 插件
$ cat /var/lib/cni/flannel/46c76c1d50d61494d6d95e0171667ec705bbcdcaeeafa859e25ac4749979bd76 | python3 -m json.tool
{
    "cniVersion": "0.3.1",
    "hairpinMode": true,
    "ipMasq": false,
    "ipam": {
        "ranges": [
            [
                {
                    "subnet": "10.244.2.0/24"
                }
            ]
        ],
        "routes": [
            {
                "dst": "10.244.0.0/16"
            }
        ],
        "type": "host-local"
    },
    "isDefaultGateway": true,
    "isGateway": true,
    "mtu": 1500,
    "name": "cbr0",
    "type": "bridge"
}
```



## 3.4 卸载

```bash
# 主节点
kubectl delete -f kube-flannel.yml

# 所有节点上
ip link set cni0 down
ip link delete cni0

rm -rf /var/lib/cni/
rm -f /etc/cni/net.d/*
```



# 4. 总结

## 4.1 Flanneld 作用

Flanneld 收到 EventAdded 事件后，从 etcd 将其他主机上报的各种信息，在本机上进行配置，主要分下列三种信息：

- **ARP**: IP和MAC的对应关系，**三层转发**
- **FDB**: MAC+VLAN和PORT的对应关系，**二层转发**，即使两个设备不在同一网段或者没配置IP，只要两者之间的链路层是连通的，就可以通过FDB表进行数据转发。它作用就在于告诉设备从某个端口出去就可以到某个目的MAC
- **Routing Table**: 通往目标地址的封包，通过网关方式发送出去



## 4.2 模式对比

- udp模式：使用设备flannel.0进行封包解包，不是内核原生支持，上下文切换较大，性能非常差
- vxlan模式：使用flannel.1进行封包解包，内核原生支持，性能损失在20%~30%左右
- host-gw模式：无需flannel.1这样的中间设备，直接宿主机当作子网的下一跳地址，性能损失大约在10%左右



# 5. 故障分析

## 5.1 `kube-proxy 配置错误`

**1. 现象：**

```bash
root@k8s-master:~# kubectl get pod -A -o wide -l app=flannel
NAMESPACE     NAME                    READY   STATUS             RESTARTS   AGE     IP              NODE         NOMINATED NODE   READINESS GATES
kube-system   kube-flannel-ds-5whpv   0/1     CrashLoopBackOff   5          6m53s   192.168.3.114   k8s-node01   <none>           <none>
kube-system   kube-flannel-ds-l7msr   1/1     Running            2          16d     192.168.3.113   k8s-master   <none>           <none>
kube-system   kube-flannel-ds-rvvhv   0/1     CrashLoopBackOff   10         33m     192.168.3.115   k8s-node02   <none>           <none>
root@k8s-master:~# kubectl logs  kube-flannel-ds-5whpv -n kube-system
I0211 02:04:21.358127       1 main.go:520] Determining IP address of default interface
I0211 02:04:21.359211       1 main.go:533] Using interface with name enp1s0 and address 192.168.3.118
I0211 02:04:21.359295       1 main.go:550] Defaulting external address to interface address (192.168.3.118)
W0211 02:04:21.359364       1 client_config.go:608] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
E0211 02:04:51.456912       1 main.go:251] Failed to create SubnetManager: error retrieving pod spec for 'kube-system/kube-flannel-ds-5whpv': Get "https://10.96.0.1:443/api/v1/namespaces/kube-system/pods/kube-flannel-ds-5whpv": dial tcp 10.96.0.1:443: i/o timeout
root@k8s-master:~# kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   16d
```



**2. 排查节点 k8s-node01:**

```bash
root@k8s-node01:~# ip addr show kube-ipvs0
5: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether a6:99:85:4e:ba:35 brd ff:ff:ff:ff:ff:ff
	inet 10.96.0.1/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever

# 本地节点无法连接到kube-apiserver, 说明是kube-proxy 故障
root@k8s-node01:~# telnet 10.96.0.1 443
Trying 10.96.0.1...
telnet: Unable to connect to remote host: Connection timed out

# 检查 kube-proxy 日志，发现其配置有问题
root@k8s-node01:/var/log/kubernetes# vi kube-proxy.ERROR
...
E0211 09:13:56.135807    1842 node.go:161] Failed to retrieve node info: Get "https://192.168.3.113:6443/api/v1/nodes/k8s-node01": dial tcp 192.168.3.113:6443: connect: connection refused

root@k8s-node01:/var/log/kubernetes# vi kube-proxy.WARNING
...
: v1alpha1.KubeProxyConfiguration.IPTables: v1alpha1.KubeProxyIPTablesConfiguration.MasqueradeBit: ReadObject: found unknown field: masqueradeAl, error found in #10 byte of ...|queradeAl":"","masqu|..., bigger context ...|eOverride":"k8s-node01","iptables":{"masqueradeAl":"","masqueradeBit":14,"minSyncPeriod":"5s","syncP|...

# 修改 Kube-proxy 配置
vi /etc/kubernetes/kube-proxy-config.yml
...
iptables:
  masqueradeAll: true

# 重启 Kube-proxy
root@k8s-node01:/var/log/kubernetes# systemctl restart kube-proxy

# 再次检查，已正常
root@k8s-node01:/var/log/kubernetes# vi kube-proxy.INFO
...
I0211 10:25:30.297232    2754 service.go:421] Adding new service port "default/kubernetes:https" at 10.96.0.1:443/TCP
...
I0211 10:32:52.626926    3155 proxier.go:1034] Not syncing ipvs rules until Services and Endpoints have been received from master

# 重启flannel
root@k8s-master:~# kubectl delete pod kube-flannel-ds-5whpv -n kube-system
root@k8s-master:~# kubectl get pod -A -o wide -l app=flannel
NAMESPACE     NAME                    READY   STATUS             RESTARTS   AGE     IP              NODE         NOMINATED NODE   READINESS GATES
kube-system   kube-flannel-ds-lld4b   0/1     Running            0          6m53s   192.168.3.114   k8s-node01   <none>           <none>
kube-system   kube-flannel-ds-l7msr   1/1     Running            2          16d     192.168.3.113   k8s-master   <none>           <none>
kube-system   kube-flannel-ds-rvvhv   0/1     CrashLoopBackOff   10         33m     192.168.3.115   k8s-node02   <none>           <none>

# 确认OK
root@k8s-node01:/var/log/kubernetes# vi kube-proxy.INFO
I0211 02:36:07.555531       1 main.go:520] Determining IP address of default interface
I0211 02:36:07.556543       1 main.go:533] Using interface with name enp1s0 and address 192.168.3.118
I0211 02:36:07.556615       1 main.go:550] Defaulting external address to interface address (192.168.3.118)
W0211 02:36:07.556688       1 client_config.go:608] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I0211 02:36:08.057730       1 kube.go:116] Waiting 10m0s for node controller to sync
I0211 02:36:08.057858       1 kube.go:299] Starting kube subnet manager
I0211 02:36:09.058115       1 kube.go:123] Node controller sync successful
I0211 02:36:09.058511       1 main.go:254] Created subnet manager: Kubernetes Subnet Manager - k8s-node01
I0211 02:36:09.058524       1 main.go:257] Installing signal handlers
I0211 02:36:09.152670       1 main.go:392] Found network config - Backend type: host-gw
I0211 02:36:09.254550       1 main.go:357] Current network or subnet (10.244.0.0/16, 10.244.0.0/24) is not equal to previous one (0.0.0.0/0, 0.0.0.0/0), trying to recycle old iptables rules
I0211 02:36:09.853007       1 iptables.go:172] Deleting iptables rule: -s 0.0.0.0/0 -d 0.0.0.0/0 -j RETURN
I0211 02:36:09.858096       1 iptables.go:172] Deleting iptables rule: -s 0.0.0.0/0 ! -d 224.0.0.0/4 -j MASQUERADE --random-fully
I0211 02:36:09.952777       1 iptables.go:172] Deleting iptables rule: ! -s 0.0.0.0/0 -d 0.0.0.0/0 -j RETURN
I0211 02:36:09.955497       1 iptables.go:172] Deleting iptables rule: ! -s 0.0.0.0/0 -d 0.0.0.0/0 -j MASQUERADE --random-fully
I0211 02:36:09.962242       1 main.go:307] Setting up masking rules
I0211 02:36:09.964711       1 main.go:315] Changing default FORWARD chain policy to ACCEPT
I0211 02:36:09.965035       1 main.go:323] Wrote subnet file to /run/flannel/subnet.env
I0211 02:36:09.965050       1 main.go:327] Running backend.
I0211 02:36:09.965069       1 main.go:345] Waiting for all goroutines to exit
I0211 02:36:09.965099       1 route_network.go:53] Watching for new subnet leases
I0211 02:36:09.965579       1 route_network.go:86] Subnet added: 10.244.2.0/24 via 192.168.3.117
I0211 02:36:09.966182       1 route_network.go:86] Subnet added: 10.244.1.0/24 via 192.168.3.119
I0211 02:36:10.152723       1 iptables.go:148] Some iptables rules are missing; deleting and recreating rules
I0211 02:36:10.152782       1 iptables.go:172] Deleting iptables rule: -s 10.244.0.0/16 -d 10.244.0.0/16 -j RETURN
I0211 02:36:10.153844       1 iptables.go:148] Some iptables rules are missing; deleting and recreating rules
I0211 02:36:10.153886       1 iptables.go:172] Deleting iptables rule: -s 10.244.0.0/16 -j ACCEPT
I0211 02:36:10.155194       1 iptables.go:172] Deleting iptables rule: -s 10.244.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE --random-fully
I0211 02:36:10.156970       1 iptables.go:172] Deleting iptables rule: -d 10.244.0.0/16 -j ACCEPT
I0211 02:36:10.252675       1 iptables.go:172] Deleting iptables rule: ! -s 10.244.0.0/16 -d 10.244.0.0/24 -j RETURN
I0211 02:36:10.255063       1 iptables.go:160] Adding iptables rule: -s 10.244.0.0/16 -j ACCEPT
I0211 02:36:10.255399       1 iptables.go:172] Deleting iptables rule: ! -s 10.244.0.0/16 -d 10.244.0.0/16 -j MASQUERADE --random-fully
I0211 02:36:10.353644       1 iptables.go:160] Adding iptables rule: -s 10.244.0.0/16 -d 10.244.0.0/16 -j RETURN
I0211 02:36:10.452443       1 iptables.go:160] Adding iptables rule: -d 10.244.0.0/16 -j ACCEPT
I0211 02:36:10.456201       1 iptables.go:160] Adding iptables rule: -s 10.244.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE --random-fully
I0211 02:36:10.555203       1 iptables.go:160] Adding iptables rule: ! -s 10.244.0.0/16 -d 10.244.0.0/24 -j RETURN
I0211 02:36:10.655121       1 iptables.go:160] Adding iptables rule: ! -s 10.244.0.0/16 -d 10.244.0.0/16 -j MASQUERADE --random-fully
```



## 5.2 ipvs 模式下，路由表错误

```bash
# 无法访问 kube-apiserver
$ kubectl logs -f kube-flannel-ds-ntwh4 -n kube-system
I1108 10:48:00.864770       1 main.go:520] Determining IP address of default interface
I1108 10:48:00.865795       1 main.go:533] Using interface with name ens33 and address 192.168.80.241
I1108 10:48:00.865827       1 main.go:550] Defaulting external address to interface address (192.168.80.241)
W1108 10:48:00.865861       1 client_config.go:608] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
E1108 10:48:30.960762       1 main.go:251] Failed to create SubnetManager: error retrieving pod spec for 'kube-system/kube-flannel-ds-ntwh4': Get "https://10.96.0.1:443/api/v1/namespaces/kube-system/pods/kube-flannel-ds-ntwh4": dial tcp 10.96.0.1:443: i/o timeout

# 切换到相关主机，测试网络，无法连通
$ curl 10.96.0.1:443

# 查询网络
$ ip addr
3: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether c6:14:f7:ad:b6:c8 brd ff:ff:ff:ff:ff:ff
    inet 10.96.92.170/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.96.0.1/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
       
# 尝试删除 ip, 发现删除后，自动生成；进一步发现，该设备默认down，设置IP地址，不影响通信
$ ip addr delete 10.96.0.1/32 dev kube-ipvs0

# 查询路由表，发现路由表错误
$ ip route show table local
local 10.96.0.1 dev kube-ipvs0 proto kernel scope host src 10.96.0.1

# 删除路由表
$ ip route del table local local 10.96.0.1 dev kube-ipvs0 proto kernel scope host src 10.96.0.1
```

























































