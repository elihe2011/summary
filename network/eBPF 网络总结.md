# 1. netfilter

netfilter 是 Linux 内核内部的一个框架，允许内核模块再Linux网络堆栈的不同位置注册回调函数，然后对于遍历 Linux 网络堆栈内各个挂钩的每个数据包，将调用以注册的回调函数

## 1.1 netfilter 作用

- 建立基于无状态和有状态的数据包过滤 Internet 防火墙
- 部署高可用性的无状态和有状态防火墙集群
- 没足够公网IP时，可使用 NAT和伪装来共享 Internet 访问
- 使用 NAT 来实现透明代理
- 协助 TC 和 iproute2 系统用于构建复杂的QoS和策略路由器
- 数据包处理，如修改 IP标头的 TOS、DSCP、ECN位



## 1.2 协议栈

网络传输：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/network-transmit-receive.png)



netfilter 模块位置：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/netfilter-module.png)



## 1.3 注册 Hook 函数

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/netfilter-hook.png)

5 个 HOOK 函数：

- PREROUTING: 数据包进入路由表之前
- INPUT: 通过路由表后，目的地为本机
- FORWARD: 通过路由表后，目的地不为本机
- OUTPUT: 由本机产生，向外发送
- POSTROUTING: 发送到网卡接口之前



相关表：

- NAT：实现nat功能，端口或地址映射等
- mangle：修改报文，更改IP标头 TOS、DSCP、ECN位

- filter：过滤报文
- raw：提前标记报文不走一些流程



## 1.4 netfilter 包流程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/netfilter-packet-traversal.png)



## 1.5 iptables

规则下发用户态工具：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/iptables.png)

```bash
--append  -A chain            Append to chain
--delete  -D chain            Delete matching rule from chain
--insert  -I chain [rulenum]  Insert in chain as rulenum (default 1=first)
--replace -R chain rulenum    Replace rule rulenum (1 = first) in chain
--list    -L [chain [rulenum]]  List the rules in a chain or all chains
--list-rules -S [chain [rulenum]]  Print the rules in a chain or all chains
--new     -N chain            Create a new user-defined chain
--policy  -P chain target  Change policy on chain to target
--flush   -F [chain]          Delete all rules in  chain or all chains
--delete-chain  -X [chain]     Delete a user-defined chain
 
--numeric     -n              numeric output of addresses and ports
--exact       -x              expand numbers (display exact values)
--table       -t table        table to manipulate (default: `filter')
--verbose     -v              verbose mode
```

测试：

```bash
$ iptables -L -n -t filter -v
Chain INPUT (policy ACCEPT 132K packets, 25M bytes)
 pkts bytes target     prot opt in     out     source               destination
  16M 3185M CILIUM_INPUT  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cilium-feeder: CILIUM_INPUT */
  27M 5532M KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes health check service ports */
 597K  176M KUBE-EXTERNAL-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
  27M 5539M KUBE-FIREWALL  all  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
 184K   94M CILIUM_FORWARD  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cilium-feeder: CILIUM_FORWARD */
    0     0 KUBE-FORWARD  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */
    0     0 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes service portals */
    0     0 KUBE-EXTERNAL-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
    0     0 DOCKER-USER  all  --  *      *       0.0.0.0/0            0.0.0.0/0
    0     0 DOCKER-ISOLATION-STAGE-1  all  --  *      *       0.0.0.0/0            0.0.0.0/0
    0     0 ACCEPT     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0
    0     0 ACCEPT     all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0
    0     0 ACCEPT     all  --  docker0 docker0  0.0.0.0/0            0.0.0.0/0

Chain OUTPUT (policy ACCEPT 133K packets, 28M bytes)
 pkts bytes target     prot opt in     out     source               destination
  16M 3396M CILIUM_OUTPUT  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cilium-feeder: CILIUM_OUTPUT */
 620K   98M KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes service portals */
  27M 5847M KUBE-FIREWALL  all  --  *      *       0.0.0.0/0            0.0.0.0/0
```



## 1.6 缺点

1. 路径太长：netfilter 框架在 IP 层，报文需要经过链路层，IP层才能被处理，如果需要丢弃报文，会白白浪费很多CPU资源，影响整体性能
2. 匹配规则太多，报文处理复杂



# 2. eBPF

BPF （Berkeley Packet Filter）是 Linux 内核中高度灵活和高效的类似虚拟机的技术，允许以安全的方式在各个挂钩点执行字节码，它用于许多 Linux 内核子系统，最多的是网络、追踪和安全。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/ebpf.png)

BPF 是一个通用目的 RISC 指令集，最初设计目标：用 C 编写程序，然后将其编译成 BPF 指令，稍后内核再通过一个位于内核中的 (in-kernel) 即时编译器 (JIT Compiler) 将 BPF 指令映射成处理器的原生指令 (opcode)，以取得在内核中的最佳执行性能。

eBPF 应用：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/ebpf-use.png)



# 3. XDP

eXpress Data Path, 快速数据路径，是内核中提供高性能、可编程的网络数据包处理框架

## 3.1 整体框架

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/xdp-arch.png)

- 直接接管网卡的 RX 数据包（类似DPDK用户态驱动）处理
- 通过运行 BPF 指令快速处理报文
- 和 Linux 协议栈无缝对接



## 3.2 总体设计

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/xdp-design.png)

- XDP驱动：网卡中的 XDP 程序的一个挂载点，没得网卡收到一个数据包就会执行这个 XDP 程序；XDP程序可以对数据包进行逐层继续、按规则进行过滤，或对数据包进行封装或解封，修改字段对数据包进行转发等
- BPF虚拟机：XDP程序由用户使用C语言编写，然后编译成BPF字节码，字节码加载到内核后运行在 eBPF 虚拟机上，虚拟机通过即时编译将字节码转换成底层二进制指令；eBPF 虚拟机支持 XDP 程序的动态加载和卸载。

- BPF maps: 存储键值对，作为用户态和内核态XDP、内核态XDP程序直接的通信媒介

- BPF 程序校验器：在将XDP程序加载到内核之前进行字节码安全校验，比如是否有循环、程序长度超过限制等等

- XDP Action: 处理报文

  ```c
  enum xdp_action {
      XDP_ABORTED = 0,
      XDP_DROP,
      XDP_PASS,
      XDP_TX,
      XDP_REDIRECT,
  };
  ```

- AF_XDP: 为改下你数据包处理而优化的地址簇，AF_XDP 套接字使 XDP程序可以将帧重定向到用户空间应用程序中的内存缓冲区。



**XDP 设计原则**：

- 专为高性能设计
- 可编程。无需修改内核即可实现新功能
- 不是内核旁路，而是内核协议的快速路径
- 不替代 TCP/IP 协议栈，以协议栈协同工作
- 不需要专门硬件



**XDP 工作模式**：

- Native XDP: 默认，XDP BPF 程序直接运行在网络驱动的早期接收路径上
- Offloaded XDP: XDP BPF 程序直接 offloaded 到网卡

- Generic XDP：内核提供的 XDP API 来编写和测试程序，一般只用于测试





# 4. Berkeley packet filters

Berkeley Packet Filters (BPF) provide a powerful tool for intrusion detection analysis. Use BPF filtering to quickly reduce large packet captures to a reduced set of results by filtering based on a specific type of traffic. Both admin and non-admin users can create BPF filters.

Review the following sections to learn more about creating BPF filters:

- [Primitives](https://www.ibm.com/docs/en/qsip/7.4?topic=queries-berkeley-packet-filters#concept_y2f_g5z_mfb__primitives)
- [Protocols and operators](https://www.ibm.com/docs/en/qsip/7.4?topic=queries-berkeley-packet-filters#concept_y2f_g5z_mfb__prot_operators)
- [BPF filter examples](https://www.ibm.com/docs/en/qsip/7.4?topic=queries-berkeley-packet-filters#concept_y2f_g5z_mfb__bpf_examples)

## Primitives

Primitives are references to fields in a network protocol header, such as host, port, or TCP port. The BPF syntax consists of one or more primitives, which usually consist of an ID, typically a name or number, which is preceded by one or more qualifiers.

- Type qualifiers

  `Type` qualifiers identify the kind of information that the ID name or number refers to. For example, the type might refer to host, net, port, or portrange. When no type qualifier exists, host is assumed.

- Dir qualifiers

  `Dir` qualifiers specify the transfer direction in relation to the ID. For example, the dir qualifier might be src, dst, or src or dst.

- Proto qualifiers

  The `proto` qualifier restricts the match to a particular protocol. Possible protocols are ether, fddi, tr, wlan, ip, ip6, arp, rarp, decnet, TCP, or UDP.

| Primitive filter                                             | Description                                                  |
| :----------------------------------------------------------- | :----------------------------------------------------------- |
| `[src|dst] host <host>`                                      | Matches a host as the IP source, destination, or either.The following list shows examples of host expressions:`dst host 192.168.1.0``src host 192.168.1``dst host 172.16``src host 10``host 192.168.1.0``host 192.168.1.0/24``src host 192.168.1/24`The host expressions can be used with other protocols like `ip`, `arp`, `rarp` or `ip6`. |
| `ether [src|dst] host <ehost>`                               | Matches a host as the Ethernet source, destination, or either.The following list shows examples of host expressions:`ether host <MAC>``ether src host <MAC>``ether dst host <MAC>` |
| `[src|dst] net <network>`                                    | Matches packets to or from the source and destination, or either.An IPv4 network number can be specified as:Dotted quad (for example, 192.168.1.0)Dotted triple (for example, 192.168.1)Dotted pair (for example, 172.16)Single number (for example, 10)The following list shows some examples:`dst net 192.168.1.0``src net 192.168.1``dst net 172.16``src net 10``net 192.168.1.0``net 192.168.1.0/24``src net 192.168.1/24` |
| `[src|dst] net <network> mask <netmask> or [src|dst] net <network>/<len>` | Matches packets with specific netmask.You can also use `/len` to capture traffic from range of IP addresses.Netmask for dotted quad (for example, 192.168.1.0) is 255.255.255.255Netmask for dotted triple (for example, 192.168.1) is 255.255.255.0Netmask for dotted pair (for example, 172.16) is 255.255.0.0Netmask for a single number (for example, 10) is 255.0.0.0The following list shows some examples:`dst net 192.168.1.0 mask 255.255.255.255 or dst net 192.168.1.0/24``src net 192.168.1 mask 255.255.255.0 or src net 192.168.1/24``dst net 172.16 mask 255.255.0.0 src net 10 mask 255.0.0.0` |
| `[src|dst] port <port> or [tcp|udp] [src|dst] port <port>`   | Matches packets that are sent to or from a port.Protocols, such as TCP, UDP, and IP, can be applied to a port to get specific results.The following list shows some examples:`src port 443``dst port 20``port 80` |
| `[src|dst] portrange <p1>-<p2> or [tcp|udp] [src|dst] portrange <p1>-<p2>` | Matches packets to or from a port in a specific range.Protocols can be applied to port range to filter specific packets within the rangeThe following list shows some examples:`src portrange 80-88``tcp portrange 1501-1549` |
| `less <length>`                                              | Matches packets less than or equal to length, for example, `len <= length`. |
| `greater <length>`                                           | Matches packets greater than or equal to length, for example, `len >= length`. |
| `(ether|ip|ip6) proto <protocol>`                            | Matches an Ethernet, IPv4, or IPv6 protocol.The protocol can be a number or name, for example,`ether proto 0x888e``ip proto 50` |
| `(ip|ip6) protochain <protocol>`                             | Matches IPv4, or IPv6 packets with a protocol header in the protocol header chain, for example `ip6 protochain 6`. |
| `(ether|ip) broadcast`                                       | Matches Ethernet or IPv4 broadcasts                          |
| `(ether|ip|ip6) multicast`                                   | Matches Ethernet, IPv4, or IPv6 multicasts. For example, `ether[0] & 1 != 0`. |
| `vlan [<vlan>]`                                              | Matches 802.1Q frames with a VLAN ID of `vlan`.Here are some examples:`vlan 100 && vlan 200` filters on vlan 200 encapsulated within vlan 100.`vlan && vlan 300 && ip` filters IPv4 protocols encapsulated in vlan 300 encapsulated within any higher-order vlan. |
| `mpls [<label>]`                                             | Matches MPLS packets with a label.The MPLS expression can be used more than once to filter on MPLS hierarchies.This list shows some examples:`mpls 100000 && mpls 1024` filters packets with outer label 100000 and inner label 1024.`mpls && mpls 1024 && host 192.9.200.1` filters packets to and from 192.9.200.1 with an inner label of 1024 and any outer label. |


## Protocols and operators

You can build complex filter expressions by using modifiers and operators to combine protocols with primitive BPF filters.

The following list shows protocols that you can use:

- `arp`
- `ether`
- `fddi`
- `icmp`
- `ip`
- `ip6`
- `link`
- `ppp`
- `radio`
- `rarp`
- `slip`
- `tcp`
- `tr`
- `udp`
- `wlan`

| Description   | Syntax         |
| :------------ | :------------- |
| Parentheses   | ( )            |
| Negation      | !=             |
| Concatenation | '&&' or 'and'  |
| Alteration    | '\|\|' or 'or' |


## BPF filter examples

The following table shows examples of BPF filters that use operators and modifiers:

| BPF filter example                       | Description                                                  |
| :--------------------------------------- | :----------------------------------------------------------- |
| `udp dst port not 53`                    | UDP not bound for port 53.                                   |
| `host 10.0 .0.1 && host 10.0 .0.2`       | Traffic between these hosts.                                 |
| `tcp dst port 80 or 8080`                | Packets to either of the specified TCP ports.                |
| `ether[0:4] & 0xffffff0f > 25`           | Range based mask that is applied to bytes greater than 25.   |
| `ip[1] != 0`                             | Captures packets for which the `Types of Service` (TOS) field in the IP header is not equal to 0. |
| `ether host 11:22:33:44:55:66`           | Matches a specific host with that Mac address.               |
| `ether[0] & 1 = 0 and ip[16] >= 224`     | Captures IP broadcast or multicast broadcast that were not sent via Ethernet broadcast or multicast. |
| `icmp[icmptype] != icmp-echo`            | Captures all icmp packets that are not echo requests.        |
| `ip[0] & 0xf !=5`                        | Captures all IP packets with options.                        |
| `ip[6:2] & 0x1fff = 0`                   | Captures only unfragmented IPv4 datagrams, and frag zero of fragmented IPv4 datagrams. |
| `tcp[13] & 16 != 0`                      | Captures TCP-ACK packets.                                    |
| `tcp[13] & 32 !=0`                       | Captures TCP-URG packets.                                    |
| `tcp[13] & 8!=0`                         | Captures TCP-PSH packets.                                    |
| `tcp[13] & 4!=0`                         | Captures TCP-RST packets.                                    |
| `TCP[13] & 2!=0`                         | Captures TCP-SYN packets.                                    |
| `tcp[13] & 1!=0`                         | Captures TCP-FIN packets.                                    |
| `tcp[tcpflags] & (tcp-syn|tcp-fin) != 0` | Captures start and end packets (the SYN and FIN packets) of each TCP conversation. |
