# 1. 概述

## 1.1 netfilter

**netfilter/iptables** 组成 Linux 平台下的包过滤防火墙，它完成封包过滤、封包重定向和网络地址转换 (NAT) 等功能

- **iptbales**: 命令行工具，位于用户空间，用于操作 netfilter

- **netfilter**: 防火墙真正得安全框架，位于内核空间，具有如下功能：

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

- filter：定义允许或者不允许的，支持的链 INPUT，FORAWRD，OUTPUT
- nat： 定义地址转换，支持的链 PREROUTING，OUTPUT，POSTROUTING
- mangle：修改报文原数据，支持的链 PREROUTING，INPUT，FORWARD，OUTPUT，POSTROUTING



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

## 2.1 参数说明

```bash
# 表
-t, --table 选定要操作的表，默认filter

# 规则管理
-A, --append chain rule            追加规则
-I, --insert chain [rulenum] rule  插入规则，默认规则号是1，即在头部插入
-D, --delete chain rule|rulenum    删除规则，默认规则号是1，即在头部删除
-R, --replace chain rulenum        替换规则，默认规则号是1，即在头部替换
-L, --list   [chain [rulenum]]     列出规则
-F, --flush                        清空规则

# 网卡名
-i, --in-interface [!] iface       指定数据包来源网络接口，只对PREROUTING，INPUT，FORWARD 三个链起有效
-o, --out-interface [!] iface      指定数据包目的网络接口，只对OUTPUT，FORWARD，POSTROUTING 三个链有效

# 协议名
-p：指定数据包协议类型

# 源和目标
-s, --source [!] address[/mask]       指定的一个或一组(携带mask)地址作为源地址
-d, --destination [!] address[/mask]  指定的一个或一组(携带mask)地址作为目标地址
--sport   源端口
--dport   目标端口

# 操作动作
-j, --jump target <指定目标>    满足某条件时该执行什么样的动作。target 可以是内置的目标，比如ACCEPT，也可以是用户自定义的链。

# 链管理命令
-P, --policy chain target    为指定的链设置策略 target，只有内置的链才允许有策略，用户自定义的是不允许的
-N, --new-chain chain        创建一个新的链
-X, --delete-chain [chain]   删除指定的链，该链必须没有被其它任何规则引用且没有任何规则。如果没有指定链名，则会删除该表中所有非内置的链
-E, --rename-chain old-chain new-chain  重命名指定的链，并不会对链内部造成任何影响
-Z, --zero [chain]           把指定链，或者表中的所有链上的所有计数器清零

# 其他
-m module    指定扩展模块，如tcp、multiport

-h：显示帮助信息
```



## 2.2 备份恢复

```bash
iptables-save > iptables.bak.$(date +%Y%m%d%H%M%S)

iptables-restore < iptables.bak
```



# 3. 操作实例

## 3.1 列出规则

```bash
# filter
iptables -L
iptables -L -nv     # 更详细

# nat
iptables -L -t nat
iptables -L -t nat --line-numbers   # 规则带编号

# INPUT
iptables -L INPUT
```



## 3.2 清空规则

```bash
# 清空所有防火墙规则
iptables -F    
iptables -F INPUT  # 清空INPUT链的所有规则

# 删除自定义的空链
iptables -X 
iptables -X KUBE-PORTALS-HOST   # 删除自定义链KUBE-PORTALS-HOST，但它必须是空链

# 清空计数
iptables -Z    
iptables -Z INPUT   # INPUT链上的所有计数器清零
```



## 3.3 端口放通

```bash
# ssh
iptables -A INPUT -s 192.168.3.0/24 -p tcp --dport 22 -j ACCEPT

# 开启80端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT   

# 允许192.168.3.3访问7890端口
iptables -A INPUT -p tcp -s 192.168.3.3 --dport 7890 -j ACCEPT 
```



## 3.4 全局规则

```bash
# 不允许任何外部访问
iptables -P INPUT -j DROP

# 不允许任何转发
iptables -P FORWARD -j DROP

# 允许本机的所有向外访问
iptables -P OUTPUT -j ACCEPT 

# 不允许任何外部访问（明确拒绝对方）
iptables -P INPUT -j REJECT    

# 不允许任何转发（明确拒绝对方）
iptables -P FORWARD -j REJECT  

# 拒接ping
iptables -A INPUT -p icmp --icmp-type 8 -j DROP

# 允许已建立的连接继续访问
iptbales -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT  
```

REJECT & DROP:

- **REJECT：会返回一个拒绝(终止)数据包(TCP FIN或UDP-ICMP-PORT-UNREACHABLE)，明确拒绝对方的连接动作**。连接马上断开，客户端认为主机不存在。
- **DROP：直接掉包，不做任何响应**。需要客户端超时等待，容易发现自己被防火墙阻挡。



## 3.5 访问控制

```bash
# 允许网段内机器访问
iptables -A INPUT -p all -s 192.168.3.0/24 -j ACCEPT  

# 屏蔽恶意IP
iptables -A INPUT -p tcp -s 114.123.12.11 -j DROP  

# 屏蔽整段IP访问
iptables -I INPUT -s 10.0.0.0/8 -j DROP            
```



## 3.6 删除规则

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



## 3.7 网络转发

内网节点 `10.40.1.0/24` 网段通过 中转节点上网（内网：ens38 10.40.1.10；外网：ens33 192.168.3.6）

**1. 中转节点**

```bash
# 启用IP转发
sysctl -w net.ipv4.ip_forward=1

# 方法一：将内部网络IP转换为外部网络IP
iptables -t nat -A POSTROUTING -s 10.40.1.0/24 -j SNAT --to-source 192.168.3.6

# 方法二：使用 MASQUERADE 动态转换源地址为可用的IP地址（公网NIC ens33) 适合外网IPd
iptables -t nat -I POSTROUTING -s 10.40.1.0/24 -o ens33 -j MASQUERADE
```



**2. 内网节点**

```bash
# 配置路由
ip route add 192.168.100.0/24 via 10.40.1.10

# 全局访问，配置默认路由
ip route delete default
ip route add default via 10.40.1.10
```



## 3.8 端口映射

内网 22 端口映射为公网 1022 端口

```bash
# 启用IP转发
sysctl -w net.ipv4.ip_forward=1

# 配置转发
iptables -t nat -A PREROUTING -d 192.168.3.6 -p tcp --dport 30022 -j DNAT --to-destination 10.40.1.12:22

iptables -t nat -A PREROUTING -d 10.40.1.10 -p tcp --dport 10022 -j DNAT --to-destination 10.40.1.12:22
```



本机内端口映射：

```bash
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
```

