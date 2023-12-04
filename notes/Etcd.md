# 1. 简介

A highly-available key value store for shared configuration and service discovery.

专注点：

- 简单：基于 HTTP+JSON 的 API
- 安全：可选 SSL 认证
- 快速：每个实例支持 1000+ QPS 写操作
- 可信：使用 Raft 算法充分实现了分布式



# 2. 应用场景





# 3. 集群安装

- `Client certificate` 是服务器用于认证客户端的证书，例如， etcdctl, etcd proxy 或者 docker客户端都需要使用
- `Server certificate` 是服务器使用，客户端用来验证服务器真伪的。例如 docker服务器或者kube-apiserver使用这个证书。
- `Peer certificate` 是etcd服务器成员彼此通讯的证书。



