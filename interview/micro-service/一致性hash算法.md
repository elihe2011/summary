# 1. hash 算法

哈希算法：将任意长度的二进制值映射为**较短的固定长度的二进制值**，即哈希值，它是一段**数据唯一且紧凑**的数值表现形式。

普通 hash 算法在分布式应用中的不足：

- 采用普通的hash算法进行路由，将数据映射到具体的节点上
- **如果有一个机器加入或者退出这个集群，则所有的映射数据都无效**
- 如果是持久化存储要做数据迁移，如果是分布式缓存，其他缓存就失效了



# 2. 一致性 hash 算法

一致性哈希提出在动态变化的 Cache 环境中，hash 算法应该满足4个适应条件

- **平衡性 (Balance)**: 哈希结果能够尽可能分布到所有的缓冲中去，这样可以使得所有的缓冲空间都得到利用。
- **单调性 (Monotonicity)**: 已通过哈希分派到相应缓冲中的内容，在系统新增缓冲区后，哈希的结果应该能够保证原有分配的内容可以被映射到新的缓冲区。
- **分散性 (Spread)**: 分布式系统中，终端可能看不到所有的缓冲，当终端希望通过哈希过程将内容映射大缓冲上时，由于不同终端所见的缓冲区可能不同，从而导致哈希结果不一致，相同内容被分配到了不同的缓冲区。应尽量降低分散性。
- **负载 (Load)**: 不同的终端，可能将相同的内容映射到不同的缓冲区中，对于一个特定的缓冲区，可能被不同的用户映射为不同的内容。应尽量降低缓冲的负荷。



# 3. 一致性 hash 设计

## 3.1 环形 hash 空间

使用 hash 算法将对应的 key 哈希到一个具有 2^32 个节点的数字空间中。将这些数字首尾相连，形成一个闭合的环形。

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-ring.jpg)

## 3.2 映射服务器节点

将各个服务器的 ip 或 唯一主机名 作为关键字进行 hash，这样每台机器就能确定其在哈希环上的位置。

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-mapping-node.jpg)

## 3.3 映射数据

将 Object A, B, C, D 四个对象通过特定的 hash 函数计算出对应的 key 值，然后散列到 hash 环上，**沿环顺时针“行走”，第一个遇到的服务器就是其应该定位到的服务器**。

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-mapping-data.jpg)



## 3.4 服务器删除和添加

- Node C 宕机，Object A, B, D 不会受影响，只有 Object C会重新分配到Node D上
- 新增Node X，通过hash算法映射到环中，通过按照顺时针迁移规则，Object C 被迁移到了Node X 中，其他对象保持原有存储位置不变。
- **一致性哈希算法，保持了单调性同时，还保证了数据迁移达到最小。**

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-node-mantenance.jpg)



## 3.5 虚拟节点

服务器节点较少时，会造成大量数据集中到一个节点上面，极少数据集中到另外的节点上面：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-virtual-1.jpg)

为解决这种数据倾斜问题，一致性hash算法引入虚拟节点机制，即对每个服务节点计算多个哈希，每个计算结果位置都放置一个服务节点，称为虚拟节点。

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/microservice/consistency-hash-virtual-2.jpg)



# 4. 实现一致性 hash 算法

```go
type Consistency struct {
	nodesReplicas int               // 虚拟节点数量
	hashSortNodes []uint32          // 节点数组
	circle        map[uint32]string // hash 环
	nodes         map[string]bool   // 节点状态
}

func NewConsistency() *Consistency {
	return &Consistency{
		nodesReplicas: 20,
		circle:        make(map[uint32]string),
		nodes:         make(map[string]bool),
	}
}

func (c *Consistency) Add(node string) error {
	if _, ok := c.nodes[node]; ok {
		return fmt.Errorf("%s already existed", node)
	}

	c.nodes[node] = true
	for i := 0; i < c.nodesReplicas; i++ {
		replicaKey := getReplicaKey(i, node)
		c.circle[replicaKey] = node
		c.hashSortNodes = append(c.hashSortNodes, replicaKey)
	}

	sort.Slice(c.hashSortNodes, func(i, j int) bool {
		return c.hashSortNodes[i] < c.hashSortNodes[j]
	})

	return nil
}

func (c *Consistency) Remove(node string) error {
	if _, ok := c.nodes[node]; !ok {
		return fmt.Errorf("%s not existed", node)
	}

	delete(c.nodes, node)
	for i := 0; i < c.nodesReplicas; i++ {
		replicaKey := getReplicaKey(i, node)
		delete(c.circle, replicaKey)
	}
	c.refreshHashSortNodes()
	return nil
}

func (c *Consistency) GetNodes() (nodes []string) {
	for v := range c.nodes {
		nodes = append(nodes, v)
	}
	return
}

func (c *Consistency) Get(key string) (string, error) {
	if len(c.nodes) == 0 {
		return "", errors.New("not found")
	}

	index := c.searchNearbyIndex(key)
	host := c.circle[c.hashSortNodes[index]]
	return host, nil
}

func (c *Consistency) refreshHashSortNodes() {
	c.hashSortNodes = nil
	for v := range c.circle {
		c.hashSortNodes = append(c.hashSortNodes, v)
	}

	sort.Slice(c.hashSortNodes, func(i, j int) bool {
		return c.hashSortNodes[i] < c.hashSortNodes[j]
	})
}

func (c *Consistency) searchNearbyIndex(key string) int {
	hashKey := hashKey(key)
	index := sort.Search(len(c.hashSortNodes), func(i int) bool {
		return c.hashSortNodes[i] >= hashKey
	})

	if index >= len(c.hashSortNodes) {
		index = 0
	}

	return index
}

func getReplicaKey(i int, node string) uint32 {
	return hashKey(fmt.Sprintf("%s#%d", node, i))
}

func hashKey(host string) uint32 {
	return crc32.ChecksumIEEE([]byte(host))
}
```

