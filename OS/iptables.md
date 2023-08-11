# 1. 概述

## 1.1 netfilter

**netfilter**: 防火墙真正得安全框架，位于内核空间

**iptbales**: 命令行工具，位于用户空间，用于操作 netfilter

**netfilter/iptables** 组成 Linux 平台下的包过滤防火墙，它完成封包过滤、封包重定向和网络地址转换 (NAT) 等功能

**netfilter** 是操作系统 kernel 内的一个数据包处理模块，具有如下功能：

- 网络地址转换(NAT, Network Address Translate)
- 数据包内容修改
- 数据包过滤的防火墙功能



## 1.2 工作机制

iptables 按照规则办事，规则即网络管理员预定义的条件，当数据包头符合条件时，处理这个数据包。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/iptables-5-chains.png) 

规则链名 (即五个钩子函数):

- **PREROUTING**：用于目标地址转换 (DNAT)
- **INPUT**：处理输入数据包
- **OUTPUT**：处理输出数据包
- **FORWARD**：处理转发数据包
- **POSTROUTING**：用于源地址转换 (SNAT)



## 1.3 防火墙策略

防火墙策略一般分为两种：

- **通** 策略：默认门关闭，必须定义谁能进入。

- **堵** 策略：大门敞开，但你必须有身份认证，否则不能进



使用较多的功能：

- filter 定义允许或者不允许的，能使用的链：INPUT，FORAWRD，OUTPUT
- nat 定义地址转换，能使用的链：PREROUTING，OUTPUT，POSTROUTING
- mangle 修改报文原数据，能使用的链：PREROUTING，INPUT，FORWARD，OUTPUT，POSTROUTING



规则的次序非常关键，**谁的规则越严格，应该放在越靠前**，规则检查时，安装从上往下的方式检查。



**”表“：具有相同功能的规则集合**

| 表     | 功能                              | 内核模块        |
| ------ | --------------------------------- | --------------- |
| filter | 包过滤，用于防火墙规则            | iptables_filter |
| nat    | 地址转换，用于网关路由器          | iptables_nat    |
| mangle | 数据包修改(QOS)，用于实现服务质量 | iptables_mangle |
| raw    | 高级功能，如：网址过滤等          | iptables_raw    |



操作动作：

- **ACCEPT**：接收数据包
- **DROP**：丢弃数据包
- **REDIRECT**：重定向、映射、透明代理
- **SNAT**：源地址转换
- **DNAT**：目标地址转换
- **MASQUERADE**：IP 伪装 (NAT)，用于 ADSL
- **LOG**：日志记录
- **SEAMRK**：添加SEMARK 标记以供网域内强制访问控制(MAC)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/network/iptables-packet-flow.png) 



# 2. iptables 

## 2.1 命令行

```bash
iptables -t 表名 <-A/I/D/R> 规则链名 [规则号] <-i/o 网卡名> -p 协议名 <-s 源IP/源子网> --sport 源端口 <-d 目标IP/目标子网> --dport 目标端口 -j 动作
```



**选项:**

```bash
# 表
-t, --table 选定要操作的表，默认为filter

# 规则管理
-A, --append chain rule            在链的末尾追加规则，即该规则会被放到最后，最后才会被执行。
-I, --insert chain [rulenum] rule  在链的指定位置插入一条规则。默认规则号是1，即则在链头部插入。
-D, --delete chain rule|rulenum    从链中删除规则。
-R num：Replays                    替换/修改第几条规则

# 网卡名
-i, --in-interface [!] iface       指定数据包来自的网络接口，比如eth0。注意：它只对 INPUT，FORWARD，PREROUTING 三个链起作用。如果未指定此选项， 说明可以来自任何一个网络接口。"!" 表示取反。
-o, --out-interface [!] iface      指定数据包出去的网络接口。只对 OUTPUT，FORWARD，POSTROUTING 三个链起作用。

# 协议名
-p：指定要匹配的数据包协议类型；

# 源和目标
-s, --source [!] address[/mask]       指定的一个或一组(携带mask)地址作为源地址
-d, --destination [!] address[/mask]  指定的一个或一组(携带mask)地址作为目标地址
--sport   源端口
--dport   目标端口

# 操作动作
-j, --jump target <指定目标>    满足某条件时该执行什么样的动作。target 可以是内置的目标，比如ACCEPT，也可以是用户自定义的链。

# 查看管理命令
-L, --list [chain]     列出链上面的所有规则，如果没有指定链，列出表上所有链的所有规则。

# 链管理命令
-P, --policy chain target    为指定的链设置策略 target。注意，只有内置的链才允许有策略，用户自定义的是不允许的。
-F, --flush [chain]          清空指定链上面的所有规则。如果没有指定链，清空该表上所有链的所有规则。
-N, --new-chain chain        用指定的名字创建一个新的链。
-X, --delete-chain [chain]   删除指定的链，这个链必须没有被其它任何规则引用，而且这条上必须没有任何规则。如果没有指定链名，则会删除该表中所有非内置的链。
-E, --rename-chain old-chain new-chain  重命名指定的链，并不会对链内部造成任何影响。
-Z, --zero [chain]           把指定链，或者表中的所有链上的所有计数器清零。

# 其他
-m module    指定扩展模块，如tcp、multiport

-h：显示帮助信息
```



操作前，先备份：

```bash
iptables-save > iptables.bak.$(date +%Y%m%d%H%M%S)

iptables-restore < iptables.bak
```



## 2.2 示例

### 2.2.1 列出规则

```bash
iptables -L         # filter表的所有规则
iptables -L -nv     # filter表的所有规则，但更详细

iptables -L -t nat  # nat表的所有规则
iptables -L -t nat --line-numbers   # 规则带编号

iptables -L INPUT   # INPUT链的所有规则
```



### 2.2.2 清空规则

```bash
iptables -F    # 清空所有防火墙规则
iptables -X    # 删除自定义的空链
iptables -Z    # 清空计数

iptables -F INPUT  # 清空INPUT链的所有规则
iptables -X KUBE-PORTALS-HOST   # 删除自定义链KUBE-PORTALS-HOST，但它必须是空链
iptables -Z INPUT  # INPUT链上的所有计数器清零
```



### 2.2.3 回环地址放通

```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT  # 允许本地回环接口（即本机访问自己）
```



### 2.2.4 端口放通

```bash
iptables -A INPUT -s 192.168.3.0/24 -p tcp --dport 22 -j ACCEPT   # ssh

iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # 开启80端口
iptables -A INPUT -p tcp -s 192.168.3.3 --dport 7890 -j ACCEPT  # 允许192.168.3.3访问7890端口
```



### 2.2.5 全局规则

```bash
iptables -P INPUT -j DROP    # 不允许任何外部访问
iptables -P FORWARD -j DROP  # 不允许任何转发
iptables -P OUTPUT -j ACCEPT # 允许本机的所有向外访问

iptables -P INPUT -j REJECT    # 不允许任何外部访问（明确拒绝对方）
iptables -P FORWARD -j REJECT  # 不允许任何转发（明确拒绝对方）

iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT     # 允许ping
iptbales -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT  # 允许已建立的连接继续访问
```

REJECT & DROP:

- **REJECT：会返回一个拒绝(终止)数据包(TCP FIN或UDP-ICMP-PORT-UNREACHABLE)，明确拒绝对方的连接动作**。连接马上断开，客户端认为主机不存在。
- **DROP：直接掉包，不做任何响应**。需要客户端超时等待，容易发现自己被防火墙阻挡。



### 2.2.6 访问控制

```bash
iptables -A INPUT -p all -s 192.168.3.0/24 -j ACCEPT  # 允许网段内机器访问

iptables -A INPUT -p tcp -s 114.123.12.11 -j DROP  # 屏蔽恶意IP
iptables -I INPUT -s 10.0.0.0/8 -j DROP            # 屏蔽整段IP访问
```



### 2.2.7 删除规则

```bash
# 添加规则
ipatbles -A INPUT -s 192.168.1.10 -j DROP

# 查询规则，带序号
iptables -L -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    KUBE-NODEPORT-NON-LOCAL  all  --  0.0.0.0/0            0.0.0.0/0            /* Ensure that non-local NodePort traffic can flow */
2    KUBE-FIREWALL  all  --  0.0.0.0/0            0.0.0.0/0
3    DROP       all  --  192.168.1.10         0.0.0.0/0

# 删除规则
iptables -D INPUT 3
```



### 2.2.8 网络转发

内网 `192.168.3.0/24` 网段通过公网 `153.3.118.156` 上网

```bash
iptables -t nat -A POSTROUTING -s 192.168.3.0/24 -j SNAT --to-source 153.3.118.156

# 使用 MASQUERADE 动态转换源地址为可用的IP地址
iptables -t nat -I POSTROUTING -s 192.168.3.0/24 -o ens33 -j MASQUERADE
```



### 2.2.9 端口映射

内网 22 端口映射为公网 1022 端口

```bash
iptables -t nat -A PREROUTING -p tcp -d 153.3.118.156 --dport 2222 -j DNAT --to-dest 192.168.3.194:22
```

本机内端口映射：

```bash
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
```



### 2.2.10 字符串匹配

比如，过滤所有TCP连接中的字符串 `hack`，一旦出现就终止连接

```bash
iptables -A INPUT -p tcp -m string --algo kmp --string "hack" -j REJECT --reject-with tcp-reset

iptables -L -nv
Chain INPUT (policy ACCEPT 233 packets, 73652 bytes)
 pkts bytes target     prot opt in     out     source               destination
6713K 3670M KUBE-NODEPORT-NON-LOCAL  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* Ensure that non-local NodePort traffic can flow */
6710K 3670M KUBE-FIREWALL  all  --  *      *       0.0.0.0/0            0.0.0.0/0
    0     0 REJECT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            STRING match  "hack" ALGO name kmp TO 65535 reject-with tcp-reset
```



### 2.2.11 防止 SYN 洪水攻击

```bash
iptables -A INPUT -p tcp --sync -m limit --limit 5/second -j ACCEPT
```



### 2.2.12 添加SECMARK记录

向从 192.168.3.3:443 以TCP方式发出到本机的包添加MAC安全上下文 system_u:object_r:myauth_packet_t

```bash
ipatbles -t mangle -A INPUT -p tcp --src 192.168.3.3 --dport 443 -j SECMARK --selctx system_u:object_r:myauth_packet_t
```



### 2.2.13 限制连接数

```bash
iptables -I INPUT -p tcp --syn --dport 80 -m connlimit --connlimit-above 100 -j REJECT # 限制并发连接访问数

iptables -I INPUT -m limit --limit 3/hour --limit-burst 10 -j ACCEPT # limit模块; --limit-burst 默认为5
```



# 3. 总结

## 3.1 规则管理

```bash
$ iptables -t nat -A OUTPUT -p tcp --dport 10350 -j DNAT --to 192.168.3.103:30003

$ iptables -L -t nat -n --line-number | grep OUTPUT -A 5
Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
1    KUBE-PORTALS-HOST  all  --  0.0.0.0/0            0.0.0.0/0            /* handle ClusterIPs; NOTE: this must be before the NodePort rules */
2    DOCKER     all  --  0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL
3    KUBE-NODEPORT-HOST  all  --  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL /* handle service NodePorts; NOTE: this must be the last rule in the chain */
4    DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:10350 to:192.168.3.103:30003

$ iptables -t nat -D OUTPUT 4
```

