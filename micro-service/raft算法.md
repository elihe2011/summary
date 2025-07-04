# 1. 简介

Paxos 一直是分布式一致性算法的标准，但它难以理解，更难以实现。

Raft 设计的目标是简化 Paxos，使得算法更易理解和实现。

Raft 解决了分布式 CAP 理论中的 CP：

- Consistency：一致性
- Partition Tolerance：分区容忍
- Availability：可用性



**分布式一致性**：指的是多个服务器保持状态一致，保证一个分布式系统的可靠性及容错能力。只要超过半数以上的服务器达成容错一致性，即任务达成一致状态



**复制状态机**：Replicated State Machines，指一组服务器上的状态机产生相同的状态副本，并在一些服务器宕机后可继续保持运行。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-state-machine.png)

复制状态机通常基于复制日志实现，每个服务器存储一个包含一系列指令的日志，并且按照日志顺序进行执行。每一个日志都按照相同的顺序执行相同的指令，最终产生相同的状态



一致性算法的特性：

- 安全性保证：在非宕机错误情况下，包括网络延迟、分区、丢包、冗余和乱序错误都可以保证正确
- 可用性：集群中只要大多数的机器可运行并且能够相互特性，就可保证可用
- 不依赖时序来保证一致性：物理时钟错误或极端的消息延迟只在最坏情况下才会导致可用性问题



通过 raft 提供的复制状态机，可解决分布式系统的复制、修复、节点管理等问题。基于这一点，可使用 raft 实现如下应用：

- 分布式锁
- 分布式存储。如分布式消息队列、分布式块系统、分布式文件系统、分布式表格系统等。Redis 就是基于 raft 是实现分布式一致性
- 高可靠元数据管理。如各类 master 模块的 HA



# 2. 基础

raft 一致性问题可分解成个子问题：

- 选举 leader
- 日志复制
- 安全性



**服务器角色**：

- Leader：负责处理所有的客户端请求
- Follower：不发送任何请求，只简单地响应来自 Leader 或 Candidate 的请求
- Candidate：选举新 Leader 时的临时角色

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-election-role.png)

流程：

- Follower 只响应来自 Leader 或 Candidate 的请求。在一定时限内，如果 Follower 未接收到消息，将自动转变成 Candidate，发起选举投票
- Candidate 如果获得集群半数以上的选票，将转换为 Leader
- 在一个 Term 内，Leader 始终保持不变，直到下线。Leader 需要周期性向所有的 Follower 发起心跳消息，以阻止 Follower 变成 Candidate



**任期**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-term.png)

raft 把事件分割成任意长度的 term，任期用连续的整数标记。每一段任期从一次选举开始。raft 保证在一个给定的任期内，最多只有一个 leader

- 选举成功：leader 管理这个集群直到任期结束
- 选举失败：该任期将因为没有 leader 而结束

任期在 raft 算法中充当逻辑时钟的作用，使得服务器节点可以查明一些过期的信息。每个服务器节点都会存储一个当前任期，任期变化在整个时期内单调增长。当服务器之间通信时会交换当前任期号。

- 接收到的任期号比当前任期号大，将接受，并更新当前的任期号
- 接收到的任期号比当前任期号小，将拒绝
- Candidate 或 Leader 发现自己的任期号已过期，它将立即恢复为 Follower



节点通信 RPC：

- `RequestVote RPC`：请求投票 RPC，由 Candidate 在选举期间发起
- `AppendEntries RPC`：附加条目 RPC，由 Leader 发起，用来复制日志和提供一种心跳机制



## 3. 选举 Leader

选举规则：

- Leader 周期性向所有 Follower 发送心跳消息 (AppendEntries RPC)，以维持自己的权威并阻止新 Leader 产生；

- Follower 设置一个随机的竞选超时事件，一般 150ms ~ 300ms，如果在这段区间内未收到 Leader 的心跳消息，就会认为当前 Term 没有可用的 Leader，并增加自己当前的 Term 号和转换为 Candidate，向其他节点发起投票请求 (RequestVote RPC)，可能会出现三种结果

  - **成为 Leader**：每个服务器最多会对一个 term 投一张选票，按照先进先出（FIFO）原则，如果该 Candidate 获得集群中半数以上的选票，它将成为该 term 的 leader
  - **其他 Candidate 成为 Leader**：等待投票期间，可能会收到一个 Leader 的 AppendEntries RPC 请求，如果该 Leader 的 Term 号，不小于当前 Candidate 的 term，那么它将承认 Leader 的合法性，并变回 Follower；如果 term 号小于当前的，将拒绝承认 Leader，继续 Candidate，等待投票
  - **没有产生 Leader**：没有一个 Candidate 获得半数以上选票，将增加当前 Term，发起下一轮选举，直到产生 Leader。

  其中：竞选超时时间 （150ms ~ 300ms) 随机产生，这样就将选举发起的时间分开，再加入每个 Term 每个节点只能投票一次，大大降低了一次选举僵持不下的概率。 



# 4. 日志复制

**日志格式**：

- log index
- log entry
  - term 号
  - 复制状态机指令

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-log-structure.png)

如果不同日志中的两个日志条目有相同的日志索引和 Term，则他们所存储的命令时相同的。

在发送 AppendEntries RPC 时，Leader 会把新日志条目之前的日志条目的日志索引和 term 号一起发送。如果 Follower 在它日志中找不到包含相同日志索引和 term 号的日志条目，它就会拒绝接收新的日志条目



**日志复制流量**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-log-duplicate.png)

- Leader 负责处理所有客户端请求。它把请求作为日志条目加到自己的日志中，然后并行向其他服务器发送 AppendEntries RPC 请求
- Follower 复制成功后，返回确认消息
- 当半数以上服务器复制成功，Leader提交这个日志条目到它的复制状态机，并向客户端返回执行结果
- 如果 Follower 崩溃或运行缓慢，Leader 会不断地重复发送 AppendEntris RPC 请求，直到所有的 Follower 最终复制了所有日志条目



**日志一致性**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-log-inconsistent.png)

成功当选 Leader 后，Follower 不一致性：

- 存在未更新日志条目：a、b
- 存在未提交日志条目：c、d
- 两个情况都存在：e、f

一致性保证：

- Leader 强制 Follower 复制日志，覆盖不一致的日志
- Leader 需要找到 Follower 与自己日志一致的地方，返回从该位置之后进行覆盖
- Leader 从后向前尝试找到与自己日志相同的位点，然后从该位点之后逐条覆盖 Follower 的日志



# 5. 安全性

确保安全性的措施：

- 选举限制：拥有最新的已提交的日志条目的 Follower 才有资格成为 Leader

- 永远不会通过计算副本数目的方式去提交一个之前 term 内的日志条目。只有 leader 当前 term 里的日志条目通过计算副本数目可以被提交；一旦当前 term 的日志条目以这种方式被提交，那么由于日志匹配特性，之前的日志也都会被间接提交
- 使用的方法更加容易辨认出日志，因为它可以随着时间和日志的变化对日志维护同一个任期编号



# 6. 日志压缩

日志不能无限制膨胀，否则系统重启恢复需要很长的时间进行，从而影响可用性。

raft 采用对整个系统进行快照来解决，快照之前的日志都可以被丢弃

**每个副本独立的对自己的系统状态生成快照，并且只能对已经提交的日志条目生成快照**，快照日志包含：

- 日志元数据：最后一条已提交日志条目的 index 和 term。这两个值在快照之后的第一条日志条目的 AppendEntries RPC 的完整性检查的时候会被用上
- 系统当前状态



当 Leader 要发送某个日志条目，落后太多的 Follower 的日志条目会被丢弃，Leader 会将快照发给 Follower。新上线的节点，也会发送快照给他

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/raft-log-snapshot.png)



生成快照的频率要适中。频率过高会消耗大量的 I/O 带宽；频率过低，一旦需要执行恢复操作，会丢失大量数据，影响可用性。

生成一次快照可能耗时过长，影响正常日志同步，可通过使用 copy-on-write 技术避免快照过程影响正常日志同步。

















