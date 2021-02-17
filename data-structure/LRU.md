# 1. LRU

LRU: Least Recently Used

LRU算法是一种缓存淘汰策略，即最近使用过的数据应该是“有用的”，很久都未使用的数据应该是无用的，内存满了优先删除那些无用的数据。

LRU 算法的核心数据结构是使用哈希链表 `LinkedHashMap`，首先借助链表的有序性使得链表元素维持插入顺序，同时借助哈希映射的快速访问能力使得我们可以在 O(1) 时间访问链表的任意元素。

LRU算法设计：

1. cache中的元素必须有时序
2. 可在cache中通过key快速找到对应的值 （HashTable）
3. 每次访问cache中的某个key，需要将该key变为最近使用的，即cache需要支持在任意位置快速插入和删除元素 (LinkedList)

```go
type LRUCache struct {
	capacity   int
	size       int
	head, tail *DLinkedNode
	cache      map[int]*DLinkedNode
}

type DLinkedNode struct {
	key, val   int
	next, prev *DLinkedNode
}

func NewDLinkedNode(key, val int) *DLinkedNode {
	return &DLinkedNode{key: key, val: val}
}

func Constructor(capacity int) LRUCache {
	lru := LRUCache{
		capacity: capacity,
		size:     0,
		head:     NewDLinkedNode(0, 0),
		tail:     NewDLinkedNode(0, 0),
		cache:    map[int]*DLinkedNode{},
	}
	lru.head.next = lru.tail
	lru.tail.prev = lru.head
	return lru
}

func (this *LRUCache) Get(key int) int {
	node, ok := this.cache[key]
	if !ok {
		return -1
	}

	this.moveToHead(node)
	return node.val
}

func (this *LRUCache) Put(key int, value int) {
	node, ok := this.cache[key]

	// 已存在，修改值并移到
	if ok {
		node.val = value
		this.cache[key] = node
		this.moveToHead(node)
		return
	}

	// 不存在，新增一个
	newNode := NewDLinkedNode(key, value)
	this.size++
	this.cache[key] = newNode
	this.addToHead(newNode)

	// 新增节点后，判断容量是否已满
	if this.size > this.capacity {
		this.removeTail()
	}
}

func (this *LRUCache) moveToHead(node *DLinkedNode) {
	// 先移除
	this.removeNode(node)

	// 添加到列表头
	this.addToHead(node)
}

func (this *LRUCache) removeNode(node *DLinkedNode) {
	node.prev.next = node.next
	node.next.prev = node.prev
}

func (this *LRUCache) addToHead(node *DLinkedNode) {
	node.prev = this.head
	node.next = this.head.next

	this.head.next.prev = node
	this.head.next = node
}

func (this *LRUCache) removeTail() {
	last := this.tail.prev
	this.removeNode(last)
	delete(this.cache, last.key)
	this.size--
}
```

# 2. LFU

 LFU 算法的淘汰策略是 Least Frequently Used，也就是每次淘汰那些使用次数最少的数据。

LFU 算法相当于是把数据按照访问频次进行排序

两个哈希表，第一个 freq_table 以频率 freq 为索引，每个索引存放一个双向链表，这个链表里存放所有使用频率为 freq 的缓存，缓存里存放三个信息，分别为键 key，值 value，以及使用频率 freq。第二个 key_table 以键值 key 为索引，每个索引存放对应缓存在 freq_table 中链表里的内存地址，这样我们就能利用两个哈希表来使得两个操作的时间复杂度均为 O(1)O(1)。同时需要记录一个当前缓存最少使用的频率 minFreq，这是为了删除操作服务的。

```go
type LFUCache struct {
	capacity  int
	size      int
	minFreq   int
	keyTable  map[int]*Node
	freqTable map[int]*LinkedList
}

func Constructor(capacity int) LFUCache {
	lfu := LFUCache{
		capacity:  capacity,
		size:      0,
		minFreq:   0,
		keyTable:  map[int]*Node{},
		freqTable: map[int]*LinkedList{},
	}
	return lfu
}

func (this *LFUCache) Get(key int) int {
	if this.capacity == 0 {
		return -1
	}

	// 未找到key
	node, ok := this.keyTable[key]
	if !ok {
		return -1
	}

	// 移动
	this.moveNode(node)

	return node.val
}

func (this *LFUCache) Put(key int, value int) {
	if this.capacity == 0 {
		return
	}

	node, ok := this.keyTable[key]

	// 已存在，直接更新
	if ok {
		node.val = value
		this.moveNode(node)
		return
	}

	// 添加前，先判断容量是否已满
	if this.size == this.capacity {
		// 删除频率最小的
		list := this.freqTable[this.minFreq]
		node := list.getTail()
		if node != nil {
			this.deleteNode(node)
			delete(this.keyTable, node.key)
			this.size--
		}
	}

	// 添加新节点
	newNode := NewNode(key, value)
	this.addNode(newNode)
	this.keyTable[key] = newNode
	this.size++
	this.minFreq = 1
}

func (this *LFUCache) moveNode(node *Node) {
	// 先删除
	this.deleteNode(node)

	// 提升频率
	node.freq++
	this.keyTable[node.key] = node

	// 新增
	this.addNode(node)
}

func (this *LFUCache) deleteNode(node *Node) {
	list := this.freqTable[node.freq]
	list.remove(node)

	// 如果链表为空，删除频率表，并更新minFreq
	if list.isEmpty() {
		delete(this.freqTable, node.freq)
		if this.minFreq == node.freq {
			this.minFreq++
		}
	}
}

func (this *LFUCache) addNode(node *Node) {
	list, ok := this.freqTable[node.freq]
	if !ok {
		// 未找到，先创建新的子链表
		list = NewLinkedList()
		this.freqTable[node.freq] = list
	}

	list.addToHead(node)
}

type Node struct {
	key, val, freq int
	next, prev     *Node
}

func NewNode(key, val int) *Node {
	return &Node{
		key:  key,
		val:  val,
		freq: 1,
	}
}

type LinkedList struct {
	head, tail *Node
}

func NewLinkedList() *LinkedList {
	list := &LinkedList{
		head: NewNode(0, 0),
		tail: NewNode(0, 0),
	}

	list.head.next = list.tail
	list.tail.prev = list.head
	return list
}

func (list *LinkedList) addToHead(node *Node) {
	node.prev = list.head
	node.next = list.head.next

	list.head.next.prev = node
	list.head.next = node
}

func (list *LinkedList) remove(node *Node) {
	node.prev.next = node.next
	node.next.prev = node.prev
}

func (list *LinkedList) getTail() *Node {
	if list.isEmpty() {
		return nil
	}
	return list.tail.prev
}

func (list *LinkedList) isEmpty() bool {
	return list.head.next == list.tail
}

func main() {
	input1 := []string{"LFUCache", "put", "put", "get", "put", "get", "get", "put", "get", "get", "get"}
	input2 := [][]int{{2}, {1, 1}, {2, 2}, {1}, {3, 3}, {2}, {3}, {4, 4}, {1}, {3}, {4}}

	capacity := input2[0][0]
	lfu := Constructor(capacity)

	var ans []string

	for i := 1; i < len(input1); i++ {
		//fmt.Println(input1[i], input2[i])
		if input1[i] == "put" {
			key, val := input2[i][0], input2[i][1]
			lfu.Put(key, val)
			ans = append(ans, "null")
		} else if input1[i] == "get" {
			key := input2[i][0]
			val := lfu.Get(key)
			ans = append(ans, strconv.Itoa(val))
		}
	}

	//fmt.Println(lfu.minFreq)
	//fmt.Println(lfu.keyTable)
	fmt.Println(ans)
}
```



