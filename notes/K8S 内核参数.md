```bash

modprobe br_netfilter
lsmod | grep br_netfilter


net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
```



# rp_filter

Reverse Path Filtering，参数定义了网卡对接收到的数据包进行反向路由验证的规则。取值如下：

- 0：关闭反向路由校验
- 1：开启严格的反向路由校验。对每个进来的数据包，校验其反向路由是否是最佳路由。如果反向路由不是最佳路由，则直接丢弃该数据包。
- 2：开启松散的反向路由校验。对每个进来的数据包，校验其源地址是否可达，即反向路由是否能通（通过任意网口），如果反向路径不通，则直接丢弃该数据包。



**反向路由校验**，就是在一个网卡收到数据包后，把源地址和目标地址对调后查找路由出口，从而得到反身后路由出口。然后根据反向路由出口进行过滤。

- 当rp_filter的值为1时，要求反向路由的出口必须与数据包的入口网卡是同一块，否则就会丢弃数据包。
- 当rp_filter的值为2时，要求反向路由必须是可达的，如果反路由不可达，则会丢弃数据包。

```bash
$ vi /etc/sysctl.d/10-network-security.conf
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
```

