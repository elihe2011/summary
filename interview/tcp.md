# 1. TIME_WAIT

## 1.1 问题描述

大量连接处于 TIME_WAIT，无法建立新连接，address already in use: connect 异常

```bash
netstat -ant | awk '/^tcp/ {arr[$NF]++} END {for(i in arr) print i, arr[i]}'
```



## 1.2 问题分析

本质原因：

- 大量短链接
- HTTP请求，如果消息头中 **Connection** 被设置为 close，此时**由服务端主动发起关闭连接**

- TCP 四次挥手，关闭机制总，为保证 **ACK重发** 和 **丢弃延迟数据**，TIME_WAIT 为2倍 MSL (报文存活最大时间)

TIME_WAIT 状态：

- TCP 连接中，**主动关闭连接的一方出现的状态** (收到 FIN 命令，进入 TIME_WAIT 状态，并返回 ACK 命令)
- 保持 2个 MSL，即4分钟 （RFC规定一个MSL两分钟，实际常用 30s, 1m 或2m）
  - 尽量让服务端收到最后的ACK
  - 确保当前连接的报文不会出现在下一次连接中



## 1.3 解决方法

- 客户端：HTTP 请求头部，Connection 设置为 keep-alive，保持存活一段实际

- 服务器：

  - 允许 TIME_WAIT 被 socket 重用

  - 缩短 TIME_WAIT 时间，可设置为 1个 MSL

    ```bash
    sysctl net.ipv4.tcp_tw_reuse=1
    
    sysctl net.ipv4.tcp_tw_recycle=1
    sysctl net.ipv4.tcp_timestamps=1
    ```

    

## 1.4 总结

- TCP 连接建立后，「**主动关闭连接**」的一放，收到对方的 FIN 请求后，发送 ACK 响应，此时处于 time_wait 状态

- **time_wait 状态**，存在的`必要性`

  - **可靠的实现 TCP 全双工连接的终止**：四次挥手关闭 TCP 连接过程中，最后的 ACK 是由「主动关闭连接」的一端发出的，如果这个 ACK 丢失，则，对方会重发 FIN 请求，因此，在「主动关闭连接」的一段，需要维护一个 time_wait 状态，处理对方重发的 FIN 请求；

  - **处理延迟到达的报文**：由于路由器可能抖动，TCP 报文会延迟到达，为了避免「延迟到达的 TCP 报文」被误认为是「新 TCP 连接」的数据，则，需要在允许新创建 TCP 连接之前，保持一个不可用的状态，等待所有延迟报文的消失，一般设置为 2 倍的 MSL（报文的最大生存时间），解决「延迟达到的 TCP 报文」问题；



# 2. Wireshark

TCP/IP协议为流控制协议，TCP窗口是其中一个重要的概念。在TCP接受和发送端都有缓存区，用户缓存数据，当缓存区满的时候就不能在向缓存区中写入数据了。发送缓存区满表现为send的返回值不再是指定的字节数，而小于该值的一个值；而接收缓存区满表现为对端发送收到影响。

```bash
[TCP Window Full]：服务端向客户端发送的一种窗口警告，表示已经发送到数据接收端的极限了。

[TCP Window Update]：缓冲区已释放为所示的大小，因此请恢复传输。

[Zero Window]：客户端向服务端发送的一种窗口警告，告诉发送者你的接收窗口已满，暂时停止发送。
```


这三种帧经常出现在以下两种情况中：

- 接收端比发送端数据处理要慢，导致数据堆积。
- 接收端控制了接收速度。



# 3. 滑动窗口

### 3.1 TCP 滑动窗口的作用

TCP 是可靠的传输协议，所以必须要解决可靠的传输以及包乱序的问题。

TCP 滑动窗口主要有两个作用：提供 TCP 可靠性 和 提供 TCP 流控特性。

TCP 滑动窗口默认大小为 4096 个字节。

在 TCP 头部里有一个字段叫 Advertised-Window（即窗口大小）。这个字段是接收端告诉发送端自己还有多少缓冲区可以接收数据，于是发送端就可以根据这个剩余空间来发送数据，而不会导致接收端处理不过来。

### 3.2 TCP 滑动窗口的原理

TCP 滑动窗口分为发送窗口和接收窗口。

发送窗口：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/tcp_sliding_window.png) 



> 对于 TCP 会话的发送方，任何时候在其发送缓存内的数据都可以分为 4 类：

- 已经发送并得到对端 ACK
- 已经发送但还未收到对端 ACK
- 未发送但对端允许发送
- 未发送且对端不允许发送

> 对于 TCP 的接收方，某一时刻在它的接收缓存内存分为 3 类：

- 已接收
- 未接收准备接收 (接收窗口)
- 未接收并未准备接收

### Q & A

**Zero Window：如果接收端处理缓慢，导致发送方的滑动窗口变为 0 了，怎么办？**

这时发送端就不发数据了，但发送端会发 ZWP（即Z ero Window Probe 技术）的包给接收方，让接收方回 ack 更新 Window 尺寸，一般这个值会设置成 3 次，每次大约30-60 秒。如果 3 次过后还是 0 的话，有的 TCP 实现就会发 RST 把连接断了。

**Silly Window Syndrome：即“糊涂窗口综合症”**

当发送端产生数据很慢、或接收端处理数据很慢，导致每次只发送几个字节，也就是我们常说的小数据包 —— 当大量的小数据包在网络中传输，会大大降低网络容量利用率。比如一个 20 字节的 TCP 首部 + 20 字节的 IP 首部+1个字节的数据组成的 TCP 数据报，有效传输通道利用率只有将近 1/40。

为了避免发送大量的小数据包，TCP 提供了 Nagle 算法，Nagle 算法默认是打开的，可以在 Socket 设置 TCP_NODELAY 选项来关闭这个算法。



# 4. 网络内核参数

## 4.1 参数配置

TCP 内核参数配置：`/proc/sys/net/ipv4/tcp_xx`，不区分ipv4或ipv6

临时修改参数：

- `sysctl net.foo=bar`
- `echo bar > /proc/sys/net/foo`

内核参数持久化：`/etc/sysctl.conf`



## 4.2 Linux Ingress

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/linux_network_ingress.png)

- 网卡在收到包后，会将帧存放在硬件的 frame buffer 上，并通过 DMA 同步到内核的一块内存 (称为 ring buffer，即 rx_ring)，查询 ringbuffer 大小：`ethtool -g [nic]`
- 传统中断模式下，每个帧产生一次硬中断，CPU0 收到硬中断后会产生一个软中断，内核切换上下文进行协议栈的处理，理论上这是延迟最低的方案，但大量的软中断会消耗CPU资源，导致其他外设来不及正常响应，因此要启用中断聚合(Interrupt Coalesce)，多帧产生一个中断，查看中断聚合状态：`ethtool -c [nic]`
- NAPI 是一种更先进的处理方式，NAPI模式下网卡收到帧后进入 polling mode 此时网卡不再产生更多的硬中断，内核的 ksoftirqd 咋软中断的上下文中调用 NAPI 的 poll 函数从 ring buffer 收包，直到 rx_ring 为空或执行超过一定时间 （如 ixgbe 驱动中定义超时为2个 CPU 时钟）
- 内核收到的包复制到一块新的内存空间，组织成内核中定义的 skb 数据结构，交上层处理

内核网络栈状态：

```bash
cat /proc/net/softnet_stat
00037edf 00000000 00002981 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
0000140f 00000000 0000003f 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
000006c5 00000000 0000005a 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
0000088e 00000000 00000081 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
```

- 第1列：processed 网络帧的计数
- 第2列：dropped计数，即因为 `input_pkt_queue` 不能处理导致的丢包数（和ring buffer满导致的丢包是两个问题）
- 第3列：NAPI 中因 budget 或 time limit 用完而退出 net_rx_action 循环的此时
- 第4-8列：无意义，默认为0
- 第9列：CPU 为了发送包而获取锁时候的冲突次数
- 第10列：CPU被其他CPU唤醒来处理 backlog 数据的次数
- 第11列：触发 flow_limit 限制的次数



## 4.3 backlog 队列和缓存

### 4.3.1 `net.ipv4.tcp_rmem`

`rmem / wmem` 是 socket buffer，即内核源码中常见的 skb，也是上图中的 kernel recv buffer

默认值：`net.ipv4.tcp_rmem = 4096 87380 621456` 分别表示收包缓冲的最小/默认/最大值，内核会根据可用的内存大小进行动态调整

注意：

- 如果指定了 `SO_RCVBUF`，socket将不受最小和最大参数限制
- 默认值 87380 会覆盖全局参数 `net.core.rmem_default`



### 4.3.2 `net.ipv4.tcp_wmem`

默认值：`net.ipv4.tcp_wmem = 4096 16384 4194304`

- 如果指定了 `SO_SNDBUF`，socket将不受最小和最大参数限制
- 默认值16384 会覆盖全局参数 `net.core.wmem_default`



### 4.3.3 `net.core.rmem & net.core.wmem`

所有协议收发缓冲的全局参数。

注意：buffer 不是越大越好，过大的 buffer 容易影响拥塞控制算法对延迟的估测



### 4.3.4 `net.core.netdev_max_backlog`

所有网络协议栈的收包队列，网卡收到的报文都在 netdev backlog 队列中等待软中断处理，和中断频率一起影响收包速度从而影响收包带宽，以 netdev_backlog=300, 中断频率=100HZ 为例：

```bash
  300    *        100             =     30 000
packets     HZ(Timeslice freq)         packets/s

30 000   *       1000             =      30 M
packets     average (Bytes/packet)   throughput Bytes/s
```

可通过 `/proc/net/softnet_stat` 的第二列来验证, 如果第二列有计数, 则说明出现过 backlog 不足导致丢包



### 4.3.5 `net.ipv4.tcp_max_syn_backlog & net.ipv4.tcp_syncookies`

`tcp_max_syn_backlog` 是内核保持的未被 ACK 的 SYN 包最大队列长度，超过这个数值后，多余的请求会被丢弃。默认值：128，**高并发服务有必要将`netdev_max_backlog`和此参数调整到1000以上**。

 `tcp_syncookies` 启用后，当SYN队列满了后，TCP会通过原地址端口，目的地址端口和时间戳打造一个特别的Sequence Number(又叫cookie发回去，如果是攻击者则不会有响应，如果是正常连接则把这个SYNCookie发回来，然后服务器端可以通过cookie建立连接(即使不在SYN队列)。核心作用：**防 SYN Flood 攻击**



### 4.3.6 net.core.somaxconn

somaxconn 是一个 socket 上等待应用程序 accept() 的最大队列长度，默认值为128，一般会调整到4096
注意：当 `net.core.somaxconn` 设置较大时可能消耗较多内存、增加收发延迟，而不能带来吞吐量的提高



## 4.4 TIME_WAIT

TIME_WAIT：为避免连接没有可靠断开而和后续新建的连接的数据混淆，TIME_WAIT 中的 peer 会给所有来包回 RST。

配置：

- Windows：TIME_WAIT 状态持续的 2MSL 可以通过注册表配置
- Linux： 内核源码中写死60秒



对于会主动关闭请求的服务端（典型应用：non-keepalive HTTP，服务端发送所有数据后直接关闭连接），实际上并不会出现在主动关闭之后再向那个客户端发包的情况，所以 TIME_WAIT 会出现在服务端的80端口上，正常情况下，由于客户端的（source IP, source port）二元组在短时间内几乎不会重复，因此这个 TIME_WAIT 的累积基本不会影响后续连接的建立 。

但在反向代理中，TIME_WAIT 问题则会非常明显，如 nginx 默认行为下会对于 client 传来的每一个 request 都向 upstream server 打开一个新连接，高 QPS 的反向代理将会快速积累 TIME_WAIT 状态的 socket，直到没有可用的本地端口，无法继续向 upstream 打开连接，此时服务将不可用。

实践中，**服务端使用 RST 关闭连接可以避免服务端积累 TIME_WAIT，但更优的设计是服务端告知客户端什么时候应该关闭连接，然后由客户端主动关闭**。



### 4.4.1 net.ipv4.tcp_max_tw_buckets

系统在同一时间允许的最多 TIME_WAIT 连接状态数量，超过这个值时，系统会直接删掉这个 socket 而不会留下 TIME_WAIT 的状态。



### 4.4.2 net.ipv4.tcp_tw_reuse & net.ipv4.tcp_tw_recycle

都依赖 TCP 时间戳，即 `net.ipv4.tcp_timestamps = 1`

tcp_tw_reuse：快速 TIME_WAIT socket 回收。如果tcp_timestamps开启的话，会缓存每个连接的最新时间戳，如果后续请求时间戳小于缓存的时间戳，即视为无效，相应的包被丢弃。所以如果是在NAT(Network Address Translation)网络下，就可能出现数据包丢弃的现象，会导致大量的TCP连接建立错误

tcp_tw_recycle：重用 TIME_WAIT 状态的 socket 用于新连接。 4.12+ 内核已经永久废弃该参数



### 4.4.3 net.ipv4.ip_local_port_range

TCP 客户端临时或动态连接端口范围，即连接建立后，客户端随机使用的通信端口

默认值： `net.ipv4.ip_local_port_range = 32768 60999`

此参数调大可以一定程度上缓解 TIME WAIT 状态 socket 堆积导致无法对外建立连接的问题，但是不是根本性的解决途径。



## 4.5 流控和拥塞控制相关

### 4.5.1 net.ipv4.tcp_congestion_control

TCP 的拥塞控制算法，基于延迟改变、丢包反馈几个设计思路：

- 基于丢包反馈（Reno）：就像计算机网络课本里学到的 AIMD（线性增乘性减），分为 cwnd 指数增长的慢启动阶段、cwnd 超过 ssthresh 后线性增加的拥塞避免阶段、收到 dup ACK 后 cwnd 折半进入快速恢复阶段，如果快速恢复超时则进入慢启动，以此循环
- 基于丢包反馈的改进型（STCP、BIC、Cubic）：基本都通过设定一些参数改进乘性减阶段和快速恢复速度，避免流量和 Reno 一样出现锯齿形波动，以提升高带宽下的链路利用率，如目前 Linux 内核默认使用的 Cubic 就是使用了三次函数代替简单二分而得名
- 基于延迟变化（Vegas 和 Westwood ）：Vegas 通过 RTT 变化判断是否出现拥塞，RTT 增加则 cwnd 减少，RTT 减少则 cwnd 增加，这种算法在与其他算法共用链路时会显得过于“绅士”而吃亏；Westwood 则通过 ACK 达到率判断链路利用率上限，适用于无线网络但无法区分网络拥塞还是无线抖动而普适性较低
- 基于主动探测（BBR）：BBR 旨在通过主动探测消除 bufferbloat 对上述各大算法的误判影响

一般默认：`net.ipv4.tcp_congestion_control = cubic`



#### 4.5.2 net.core.default_qdisc

qdisc (queue disciplines) 其实是 egress traffic control 和 qos 相关的问题而不是 TCP 的拥塞控制问题，下图是一个简化版的 egress 架构，

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/linux_network_egress.png)

网络设备或多或少都有 buffer，初衷是以增大少许延迟来避免丢包，然而 buffer 的存在所导致的延迟可能干扰 TCP 对链接质量的判断，buffer 最终被塞满，丢包不可避免，反而新引入了延迟波动问题，这一现象被称为 bufferbloat，网络开发者们一直致力于研究更好的 qdisc 算法，避免 buffer bloat 带来的影响，这些有基于分类的算法也有无分类算法，其中分类算法最简单的实现有 prio HTB CBQ 等，无分类有 pfifo pfifo_fast tbf 等，针对 bufferbloat 的改进算法有 tail-drop red blue codel 等，其中：

- pfifo_fast 是众多发行版的默认参数，它实现简单，很多网卡可以 offload 而减少 CPU 开销，但它默认队列过长很容易引起 bufferbloat，不能识别网络流可能导致部分流被饿死
- fq (fair queue) 针对了 pfifo 及其衍生算法的缺点，它将每个 socket 的数据称为一个流，以流为单位进行隔离，分别进行 pacing 以期望得到公平发送的效果
- codel 是一种针对 bufferbloat 设计的算法，使用 BQL 动态控制 buffer 大小，自动区分“好流”和“坏流”，fq_codel 对非常小的流进行了优化避免饿死问题
- cake 是 codel / fq_codel 的后继者，内建 HTB 算法进行流量整形而克服了原版 HTB 难以配置的问题，号称能做 fq_codel 能做的一切且比 fq_codel 做得更好，在 4.19 中被引入内核

一个比较笼统但通俗的解释是：终端设备（内容的生产者或最终接收者，而不是转发设备）的 qdisc 更适合 fq，转发设备更适合 codel 及其衍生算法，根据一些不完全的实践，bbr 配合 fq_codel 工作的很好，cake 理论上可作为 fq_codel 的替代



#### 4.5.3 net.ipv4.tcp_window_scaling

该参数为 0 时，TCP 滑动窗口最大值为 (2^16)64KB；将其值设置为 1 时，滑动窗口的最大值可达 (2^30)1GB，大大提升[长肥管道(Long Fat Networks)](https://en.wikipedia.org/wiki/Bandwidth-delay_product)下的 TCP 传输速度。



## 4.6 TCP keepalive

TCP keepalive 是建立 TCP 连接是分配一个计数器，当计数器归零时，发送一个空 ACK（dup ack 是被允许的），主要有两大目的：

- 探测对端存活（避免对端因为断电等突发故障没有发出连接中断通知，而服务器一直傻傻的 hold 连接直到 ESTABLISH 超时）

- 避免网络 idle 超时（比如 lvs、NAT 硬件、代理等流表过期）

需要注意 TCP keepalive 不是 Linux 系统的默认行为，需要显式指定 socket option `so_keepalive`



### 4.6.1 net.ipv4.tcp_keepalive_time

最大闲置时间，从最后一个 data packet（空 ACK 不算 data）之后多长时间开始发送探测包，单位是秒



### 4.6.2 net.ipv4.tcp_keepalive_intvl

发送探测包的时间间隔，在此期间连接上传输了任何内容都不影响探测的发送，单位是秒



### 4.6.3 net.ipv4.tcp_keepalive_probes

最大失败次数，超过此值后将通知应用层连接失效



## 4.7 总结

```bash
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 16384 262144 8388608
net.ipv4.tcp_wmem = 32768 524288 16777216
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.wmem_default = 2097152
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 10240
net.core.netdev_max_backlog = 10240
net.netfilter.nf_conntrack_max = 1000000
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established = 7200
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
```



