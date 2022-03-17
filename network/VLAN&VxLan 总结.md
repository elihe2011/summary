# 1. VLAN

## 1.1 概述

LAN (Local Area Network, 本地局域网)，通常使用 Hub 和 Switch 连接 LAN 中的计算机。一个 LAN表示一个广播域，它表示 LAN 中的所有成员都会收到 LAN 中一个成员发出的广播包。因此，LAN 的边界在路由器或者类似的三层设备

VLAN (Virtual LAN)，一个带有 VLAN功能的 Switch 能够同时处于多个 LAN 中。即 VLAN 是一种将一个交换机分成多个交换机的方法。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vlan-packet.png)

IEEE 802.1Q 标准定义了 VLAN Header 的格式。它在普通以太网帧结构 SA （src address）之后 加入了 4bytes 的 VLAN Tag/Header 数据，其中包括 12bits 的 VLAN ID。VLAN ID的最大值是 4096， 但是有效值范围是 1- 4094



## 1.2 交换机端口类型

以太网端口有三种链路类型：

- Access：只能属于一个 VLAN，一般用于连接计算机的端口
- Trunk：可以属于多个 VLAN，可接收和发送多个 VLAN 报文，一般用于交换机之间的连接接口
- Hybird：属于多个 VLAN，可接收和发送多个 VLAN 报文，既可以用于交换机之间的连接，也可以用于连接用户的计算机。

Hybird  vs Trunk：

- Hybird 端口可以允许多个 VLAN的报文发送时不打标签
- Trunk 端口 只允许缺省 VLAN的报文发送时不打标签



## 1.3 VLAN 的不足

- VLAN ID 使用 12-bit 表示，最多支持 `2^12` 即 4096个，有效值 1~ 4094
- VLAN 基于 L2 交换机。同网段主机通信，报文到达交换机后都会查询 `MAC` 地址表进行二层转发。当数据中心虚拟化之后，VM/容器的数量呈指数级增长，而交换机的内存有限，MAC 地址表也是有限的，当VM/容器的网卡 MAC 地址数量的空前增加时，无法满足交互



# 2. VxLAN

## 2.1 概述

VXLAN（Virtual eXtensible Local Area Network，虚拟扩展局域网），是由IETF定义的NVO3（Network Virtualization over Layer 3）标准技术之一，是对传统VLAN协议的一种扩展。VXLAN的特点是将L2的以太帧封装到UDP报文（即L2 over L4）中，并在L3网络中传输。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-tunnel.png)

VXLAN本质上是一种隧道技术，在源网络设备与目的网络设备之间的IP网络上，建立一条逻辑隧道，将用户侧报文经过特定的封装后通过这条隧道转发。从用户的角度来看，接入网络的服务器就像是连接到了一个虚拟的二层交换机的不同端口上（可把蓝色虚框表示的数据中心VXLAN网络看成一个二层虚拟交换机），可以方便地通信。

VXLAN已经成为当前构建数据中心的主流技术，是因为它能很好地满足数据中心里虚拟机动态迁移和多租户等需求。



## 2.2 为什么使用vxlan

- **VLAN ID 数量限制**： VXLAN 的 VNI 有 `24 bit` ，可以支持 `2^24` 个子网，千万级别

- **多租户网络隔离**：不同用户之间需要独立地分配IP和MAC地址。与 VLAN不同的是，它使用 `VTEP` 将二层以太网帧封装在 `UDP` 中，一个 `VTEP` 可以被一个物理机上的所有 VM（或容器）共用，一个物理机对应一个 `VTEP`。从交换机的角度来看，只是不同的 `VTEP` 之间在传递 `UDP` 数据，只需要记录与物理机数量相当的 MAC 地址表条目就可以
- **虚机或容器迁移范围受限**：云计算业务对业务灵活性要求很高，虚拟机可能会大规模迁移，并保证网络一直可用。解决这个问题同时保证二层的广播域不会过分扩大，这也是云计算网络的要求。VXLAN 将二层以太网帧封装在 `UDP` 中，相当于在三层网络上构建了二层网络。不管你物理网络是二层还是三层，都不影响虚拟机/容器 的网络通信，也就无所谓部署在哪台物理设备上了，可以随意迁移



## 2.2 VxLAN 隧道

vxlan 网络模型：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-network-model.png)

### 2.2.1 VTEP

VTEP（VXLAN Tunnel Endpoints，VXLAN隧道端点）是VXLAN网络的边缘设备，是VXLAN隧道的起点和终点，VXLAN对用户原始数据帧的封装和解封装均在VTEP上进行。

VTEP是VXLAN网络中绝对的主角，VTEP既可以是一台独立的网络设备(交换机)，也可以是在服务器中的虚拟交换机。源服务器发出的原始数据帧，在VTEP上被封装成VXLAN格式的报文，并在IP网络中传递到另外一个VTEP上，并经过解封转还原出原始的数据帧，最后转发给目的服务器。

通过VXLAN隧道，“二层域”可以突破物理上的界限，实现大二层网络中VM之间的通信。所以，连接在不同VTEP上的VM之间如果有“大二层”互通的需求，这两个VTEP之间就需要建立VXLAN隧道。换言之，同一大二层域内的VTEP之间都需要建立VXLAN隧道。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vtep-tunnel.png)



### 2.2.2 VNI

VNI（VXLAN Network Identifier，VXLAN 网络标识符），VNI是一种类似于VLAN ID的用户标识，一个VNI代表了一个租户，属于不同VNI的虚拟机之间不能直接进行二层通信。VXLAN报文封装时，给VNI分配了24比特的长度空间，使其可以支持海量租户的隔离。



## 2.3 报文解析

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-packet.png)

VxLAN 报文：

- 内层报文：通信的虚拟机双方要么直接使用 IP 地址，要么通过 DNS 等方式已经获取了对方的 IP 地址，因此网络层地址已经知道。同一个网络的虚拟机需要通信，还需要知道**对方虚拟机的 MAC 地址**，vxlan 需要一个机制来实现传统网络 ARP 的功能
- VxLAN 头部：只需要知道 VNI，这一般是直接配置在 vtep 上的，要么是提前规划写死的，要么是根据内部报文自动生成的
- UDP 头部：最重要的是源地址和目的地址的端口，源地址端口是系统生成并管理的，目的端口也是写死的，比如 IANA 规定的 4789 端口
- IP 头部：IP 头部关心的是 vtep 双方的 IP 地址，源地址可以很简单确定，目的地址是**虚拟机所在地址宿主机 vtep 的 IP 地址**
- MAC 头部：如果 vtep 的 IP 地址确定了，MAC 地址可以通过经典的 ARP 方式来获取



## 2.4 报文转发

### 2.4.1 同子网互通

VM_A、VM_B和VM_C同属于10.1.1.0/24网段，且同属于VNI 5000。此时，VM_A想与VM_C进行通信。由于是首次进行通信，VM_A上没有VM_C的MAC地址，所以会发送ARP广播报文请求VM_C的MAC地址

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vni-same.png)

ARP 请求报文转发：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vni-same-arp-request.png)

ARP 应答报文转发：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vni-same-arp-response.png)



### 2.4.2 跨子网互通

VM_A和VM_B分别属于10.1.10.0/24网段和10.1.20.0/24网段，且分别属于VNI 5000和VNI 6000。VM_A和VM_B对应的三层网关分别是VTEP_3上BDIF 10和BDIF 20的IP地址。VTEP_3上存在到10.1.10.0/24网段和10.1.20.0/24网段的路由。此时，VM_A想与VM_B进行通信

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vni-diff.png)

ARP 请求报文转发：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/vxlan-vni-diff-arp-request.png)



## 2.5 管理 VXLAN 接口

1. 创建点对点的 VXLAN 接口：

```text
$ ip link add vxlan0 type vxlan id 4100 remote 192.168.1.101 local 192.168.1.100 dstport 4789 dev eth0
```

2. 创建多播模式的 VXLAN 接口：

```text
$ ip link add vxlan0 type vxlan id 4100 group 224.1.1.1 dstport 4789 dev eth0
```

3. 查看 VXLAN 接口详细信息：

```text
$ ip -d link show vxlan0
```



## 2.6 FDB 表

`FDB`（Forwarding Database entry，即转发表）是 Linux 网桥维护的一个二层转发表，用于保存远端虚拟机/容器的 MAC地址，远端 VTEP IP，以及 VNI 的映射关系，可以通过 `bridge fdb` 命令来对 `FDB` 表进行操作：

- 条目添加：

  ```text
  $ bridge fdb add <remote_host_mac> dev <vxlan_interface> dst <remote_host_ip>
  ```

- 条目删除：

  ```text
  $ bridge fdb del <remote_host_mac> dev <vxlan_interface>
  ```

- 条目更新：

  ```text
  $ bridge fdb replace <remote_host_mac> dev <vxlan_interface> dst <remote_host_ip>
  ```

- 条目查询：

  ```text
  $ bridge fdb show
  ```



# 3. Tunnel 技术

## 3.1 IP in IP

用IP封装VxLAN，这种tunnel仅仅依靠外层的IP头很难穿越NAT/PAT设备。

如果使用IP封装，VxLAN 协议头需要提供字段支持NAT，即使这样，还需要VxLAN端点之间路径上的NAT设备升级软件，不划算



## 3.2 GRE

在UDP tunnel 流行之前，GRE是最通用的封装方式，比如**PPTP**就是采用GRE来封装用户数据，支持两种格式：

- 标准格式 （Standard）：GRE头一共4个字节，4个字节里也没有哪个字段适合做NAT，所以不便于做NAT穿越。

- 高级格式 （ Enhanced）：GRE头一共8个字节，8个字节里有一个字段：**Key/VRF，**适合做NAT，所以使用的更多，更通用！但有的NAT设备只支持UDP/TCP/ICMP，并不一定支持Enhanced GRE，所以有时也会造成通信障碍。



## 3.3 UDP

UDP tunnel 越来越流行，主要基于几点特质：

- **无障碍穿越任何NAT设备**：无论高端的商用路由器、还是家用路由器，都支持，所以无需额外的配置就可以工作，省时省心。

- **UDP是无状态的**：如果使用 TCP 作 tunnel，由于建立tunnel 之前需要建立连接，然后再建立tunnel，发送数据的初始延迟就会稍大。外层的TCP是有状态的，内层负载如果也是有状态的，双状态机不利于排错、debug。**L2TP、VxLAN、IKEv2 IP Security**都是采用UDP封装。

- **IP Protocol 数量有限**：一个字节，理论上可以提供255种协议复用，空间受限。而采用UDP封装，端口号2个字节，理论上可以提供65535种协议复用

- **UDP天然支持组播**：终端用户的广播（如ARP广播），以及用户的组播，需要VxLAN传输，有两种方式：

  - **组播传输**：需要运营商提供组播支持，需要将用户的广播、组播，全部映射为 VxLAN 组播，而支持组播最天然的协议就是UDP。

  - **单播复制多份传输**：如果运营商不支持用户组播，则需要头端设备将用户的广播、组播，复制为多份进行单播传输，无状态的UDP协议也是一个合适候选者。



