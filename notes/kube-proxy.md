# 1. 简介

kube-proxy 监听 API server 中 service 和 endpoint 的变化情况，并通过 userspace、iptables、ipvs 或 winuserspace 等 proxier 来为服务配置**负载均衡**（仅支持 TCP & UDP）

kube-proxy 可以直接运行在物理机上，也可以以 static pod 或者daemonset的方式运行

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-diagram.png) 

kube-proxy 的实现：

- userspace： 早期方案，它在用户空间监听一个端口，所有服务通过 iptables 转发到这个端口，然后再其内部负载均衡器到实际的Pod。该方式最主要的问题时效率低，有明显的性能瓶颈。

- iptables: 推荐方案，完全以iptables规则的方式来实现 service 负载均衡。该方式的最主要问题是创建了太多的 iptables 规则，非增量式更新会引入一定的时延，大规模情况下有明显的性能问题

- ipvs: 解决了 iptables 的性能问题，采用增量式更新，可以保证 service 更新期间连接保持不断开

  ```bash
  # ipvs 模式需要加载内核模块
  modprobe -- ip_vs
  modprobe -- ip_vs_rr
  modprobe -- ip_vs_wrr
  modprobe -- ip_vs_sh
  modprobe -- nf_conntrack_ipv4
  
  # to check loaded modules, use
  lsmod | grep -e ip_vs -e nf_conntrack_ipv4
  
  # or
  cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4
  ```

  

# 2. Iptables 示例

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-iptables.png) 



# 3. ipvs 示例

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/kubernetes/k8s-kube-proxy-ipvs.png) 



# 4. kube-proxy 的不足

只支持 TCP 和 UDP，不支持 HTTP 路由，也没有健康检查机制。这些可以通过自定义 [Ingress Controller](https://feisky.gitbooks.io/kubernetes/content/plugins/ingress.html) 的方法来解决。