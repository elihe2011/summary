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



























