# 1. 二叉树

```go
type BinaryTree struct {
	Value int
	Left  *BinaryTree
	Right *BinaryTree
}
```



```
             1
          /     \
        2        6
      /   \    /   \
     3     5  7     8
      \
       4
```



# 2. 二叉树遍历

## 2.1 深度优先遍历 (DFS)

DFS: Depth First Search。从根节点出发，沿着左子树方向进行纵向遍历，直到找到叶子节点为止。然后回溯到前一个节点，进行右子树节点的遍历，直到遍历完所有可达节点为止

数据类型：Stack

```go
type Stack struct {
	Items []interface{}
	lock  sync.RWMutex
}

func NewStack() *Stack {
	return &Stack{Items: []interface{}{}}
}

func (s *Stack) Push(v interface{}) {
	s.lock.Lock()
	defer s.lock.Unlock()

	s.Items = append(s.Items, v)
}

func (s *Stack) Pop() interface{} {
	s.lock.Lock()
	defer s.lock.Unlock()

	item := s.Items[len(s.Items)-1]
	s.Items = s.Items[:len(s.Items)-1]
	return item
}

func (s *Stack) Length() int {
	return len(s.Items)
}

func (s *Stack) IsEmpty() bool {
	return s.Length() == 0
}
```

### 2.1.1 先序遍历

```go
func (root *BinaryTree) DFS() {
	stack := NewStack()

	// 根节点入堆
	stack.Push(root)

	for !stack.IsEmpty() {
		node := stack.Pop().(*BinaryTree)
		fmt.Printf("%d ", node.Value)

		// FILO: 先进后出
		if node.Right != nil {
			stack.Push(node.Right)
		}

		if node.Left != nil {
			stack.Push(node.Left)
		}
	}
}
```

先序递归遍历：

```go
func (root *BinaryTree) PreOrder() {
	if root != nil {
		fmt.Printf("%d ", root.Value)
		root.Left.PreOrder()
		root.Right.PreOrder()
	}
}
```

### 2.1.2 中序遍历

```go
func (root *BinaryTree) InOrder() {
	if root != nil {
		root.Left.InOrder()
		fmt.Printf("%d ", root.Value)
		root.Right.InOrder()
	}
}
```


### 2.1.3 后序遍历

```go
func (root *BinaryTree) PostOrder() {
	if root != nil {
		root.Left.PostOrder()
		root.Right.PostOrder()
		fmt.Printf("%d ", root.Value)
	}
}

// 使用后序遍历思想
func (root *BinaryTree) treeDepth() int {
	if root == nil {
		return 0
	}

	l := root.Left.treeDepth()
	r := root.Right.treeDepth()

	if l > r {
		return l + 1
	} else {
		return r + 1
	}
}
```



## 2.2 广度优先遍历 (BFS)

BFS: Breadth First Search。从根节点出发，在横向遍历二叉树层段节点的基础上纵向遍历二叉树的层次。

广度优先遍历，也叫层次遍历

数据类型：Queue

```go
type Queue struct {
	Items []interface{}
	lock  sync.RWMutex
}

func NewQueue() *Queue {
	return &Queue{Items: []interface{}{}}
}

func (queue *Queue) EnQueue(v interface{}) {
	queue.lock.Lock()
	defer queue.lock.Unlock()

	queue.Items = append(queue.Items, v)
}

func (queue *Queue) DeQueue() interface{} {
	queue.lock.Lock()
	defer queue.lock.Unlock()

	item := queue.Items[0]
	queue.Items = queue.Items[1:]
	return item
}

func (queue *Queue) Front() interface{} {
	queue.lock.RLock()
	defer queue.lock.RUnlock()

	item := queue.Items[0]
	return item
}

func (queue *Queue) Size() int {
	return len(queue.Items)
}

func (queue *Queue) IsEmpty() bool {
	return queue.Size() == 0
}
```

实现层次遍历：

```go
func (root *BinaryTree) LevelOrder() {
	queue := NewQueue()

	// 根节点入队
	queue.EnQueue(root)

	for !queue.IsEmpty() {
		node := queue.DeQueue().(*BinaryTree)
		fmt.Printf("%d ", node.Value)

		// FIFO：先进先出
		if node.Left != nil {
			queue.EnQueue(node.Left)
		}
		if node.Right != nil {
			queue.EnQueue(node.Right)
		}
	}
}
```

通过递归调用实现广度优先遍历：

```go
func (root *BinaryTree) printLevel(level int) bool {
	if root == nil {
		return false
	}

	if level == 1 {
		fmt.Printf("%d ", root.Value)
		return true
	}

	left := root.Left.printLevel(level - 1)
	right := root.Right.printLevel(level - 1)
	return left || right
}

func (root *BinaryTree) LevelOrder() {
	level := 1

	for root.printLevel(level) {
		level++
	}
}
```





# 3. 恢复二叉树

## 3.1 前序 & 中序

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/bitree-pre-in-order.png)

```go
func buildTree(preOrder, inOrder []int) *BinaryTree {
	preStart, preEnd := 0, len(preOrder)-1
	inStart, inEnd := 0, len(inOrder)-1

	return construct(preOrder, preStart, preEnd, inOrder, inStart, inEnd)
}

func construct(preOrder []int, preStart, preEnd int, inOrder []int, inStart, inEnd int) *BinaryTree {
	if preStart > preEnd || inStart > inEnd {
		return nil
	}

	// 根节点值
	val := preOrder[preStart]
	root := &BinaryTree{Value: val}

	// 在inOrder中，找到根节点的位置
	var k int
	for i := 0; i < len(inOrder); i++ {
		if val == inOrder[i] {
			k = i
			break
		}
	}

	// 构建左子树 & 右子树, 其中k-inStart为中序前半部分长度
	root.Left = construct(preOrder, preStart+1, preStart+(k-inStart), inOrder, inStart, k-1)
	root.Right = construct(preOrder, preStart+(k-inStart)+1, preEnd, inOrder, k+1, inEnd)

	return root
}
```



## 3.2 后序 & 中序

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/bitree-post-in-order.png)

```go
func construct(postOrder []int, postStart, postEnd int, inOrder []int, inStart, inEnd int) *BinaryTree {
	if postStart > postEnd || inStart > inEnd {
		return nil
	}

	// 根节点值
	val := postOrder[postEnd]
	root := &BinaryTree{Value: val}

	// 在inOrder中，找到根节点的位置
	var k int
	for i := 0; i < len(inOrder); i++ {
		if val == inOrder[i] {
			k = i
			break
		}
	}

	// k 不是后序左子树长度，左子树长度为 k - (inStart+1), 后序右子树结束位置为 postStart + k - (inStart+1)
	root.Left = construct(postOrder, postStart, postStart+k-(inStart+1), inOrder, inStart, k-1)

	// 后序右子树起始位置为 postStart + k - (inStart+1) + 1
	root.Right = construct(postOrder, postStart+k-inStart, postEnd-1, inOrder, k+1, inEnd)

	return root
}
```



## 3.3 层序 & 中序

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/bitree-level-in-order.png)



# 4. 二叉排序树 （BST）

Binary Search Tree, 二叉查找树：左子树结点值 < 根结点值 < 右子树结点值

## 4.1 二叉查找树实现

```go
type TreeNode struct {
	Value int
	Left  *TreeNode
	Right *TreeNode
}

type BinarySearchTree struct {
	Root *TreeNode
}

func NewBTS(v int) *BinarySearchTree {
	return &BinarySearchTree{
		Root: &TreeNode{Value: v},
	}
}

func (tree *BinarySearchTree) Insert(v int) {
	tree.Root.Insert(v)
}

func (root *TreeNode) Insert(v int) {
	if root.Value > v {
		if root.Left == nil {
			root.Left = &TreeNode{Value: v}
		} else {
			root.Left.Insert(v)
		}
	} else {
		if root.Right == nil {
			root.Right = &TreeNode{Value: v}
		} else {
			root.Right.Insert(v)
		}
	}
}

func (tree *BinarySearchTree) InOrder() []int {
	var result []int
	tree.Root.InOrder(&result)
	return result
}

func (root *TreeNode) InOrder(result *[]int) {
	if root == nil {
		return
	}

	root.Left.InOrder(result)
	*result = append(*result, root.Value)
	root.Right.InOrder(result)
}

func (tree *BinarySearchTree) FindMin() int {
	return tree.Root.FindMin()
}

func (root *TreeNode) FindMin() int {
	if root.Left == nil {
		return root.Value
	} else {
		return root.Left.FindMin()
	}
}

func (tree *BinarySearchTree) FindMax() int {
	return tree.Root.FindMax()
}

func (root *TreeNode) FindMax() int {
	if root.Right == nil {
		return root.Value
	} else {
		return root.Right.FindMax()
	}
}

func (tree *BinarySearchTree) Contains(v int) bool {
	return tree.Root.Contains(v)
}

func (root *TreeNode) Contains(v int) bool {
	if root.Value == v {
		return true
	} else if root.Value > v {
		if root.Left == nil {
			return false
		} else {
			return root.Left.Contains(v)
		}
	} else {
		if root.Right == nil {
			return false
		} else {
			return root.Right.Contains(v)
		}
	}
}

func (tree *BinarySearchTree) Remove(v int) {
	tree.Root = tree.Root.Remove(v)
}

func (root *TreeNode) Remove(v int) *TreeNode {
	if root.Value > v {
		if root.Left != nil {
			root.Left = root.Left.Remove(v)
		}
	} else if root.Value < v {
		if root.Right != nil {
			root.Right = root.Right.Remove(v)
		}
	} else {
		// 没有孩子，或者只有一个孩子
		if root.Left == nil || root.Right == nil {
			if root.Left != nil {
				return root.Left
			} else {
				return root.Right
			}
		} else {
			// 在右子树中，找到最小的值，即该子树最底端的左节点
			node := root.Right
			for node.Left != nil {
				node = node.Left
			}

			// root节点替换
			root.Value = node.Value

			// 在右子树中删除替换的节点
			root.Right = root.Right.Remove(node.Value)
		}
	}
	return root
}

func main() {
	a := []int{5, 1, 7, 2, 4, 6, 3}

	tree := NewBTS(a[0])

	for i := 1; i < len(a); i++ {
		tree.Insert(a[i])
	}

	b := tree.InOrder()
	fmt.Println(b)

	min := tree.FindMin()
	max := tree.FindMax()
	fmt.Println(min, max)

	b1, b2 := tree.Contains(4), tree.Contains(9)
	fmt.Println(b1, b2)

	tree.Remove(7)
	c := tree.InOrder()
	fmt.Println(c)
}
```

## 4.2 二叉查找树判断

```go
type TreeNode struct {
	Value int
	Left  *TreeNode
	Right *TreeNode
}

func (root *TreeNode) IsBST(min, max int) bool {
	if root == nil {
		return true
	}

	if root.Value <= min || root.Value >= max {
		return false
	}

	return root.Left.IsBST(min, root.Value) && root.Right.IsBST(root.Value, max)
}

func main() {
	node1 := &TreeNode{Value: 1}
	node2 := &TreeNode{Value: 2}
	node3 := &TreeNode{Value: 3}
	node4 := &TreeNode{Value: 4}
	node5 := &TreeNode{Value: 5}

	node1.Left = node2
	node1.Right = node3
	node2.Left = node4
	node2.Right = node5

	b1 := node1.IsBST(math.MinInt64, math.MaxInt64)
	fmt.Println(b1)

	node1.Left = nil
	node1.Right = nil
	node2.Left = node1
	node2.Right = nil
	node3.Left = node2
	node3.Right = node4
	node4.Left = nil
	node4.Right = node5

	b2 := node3.IsBST(math.MinInt64, math.MaxInt64)
	fmt.Println(b2)
}
```





# 5. 平衡二叉树 （AVL）

Balanced Binary Tree特点：树上任一个节点的左子树和右子树的高度差不超过1

平衡二叉树：基于二分法的策略提高数据的查找效率的搜索二叉树(BST)

调整最小不平衡子树：

- LL: 在A的左孩子的左子树中插入导致不平衡，将A的左孩子右上旋
- RR: 在A的右孩子的右子树中插入导致不平衡，将A的右孩子左上旋
- LR: 在A的左孩子的右子树中插入导致不平衡，将A的左孩子的右孩子，先左上旋再右上旋
- RL: 在A的右孩子的左子树中插入导致不平衡，将A的右孩子的左孩子，先右上旋再左上旋

```
实现 f 向右下旋转，p 向右下旋转：其中f是父亲、p为左孩子、gf为f的父亲
1) f->lchild = p->rchild
2) p->rchild = f
3) gf->lchild/rchild = p

实现 f 向左下旋转，p 向左上旋转
1) f->rchild = p->lchild
2) p->lchild = f
3) gf->lchild/rchild = p
```

平衡因子(bf): 节点右孩子高度减去左孩子的高度

- bf=0: 左右孩子高度相等
- bf=1: 右孩子比左孩子高度大1
- bf=-1: 左孩子比右孩子高度大1
- bf=2/-2: 需要进行平衡化

```go
type AVLTreeNode struct {
	Value  int
	Height int
	Left   *AVLTreeNode
	Right  *AVLTreeNode
}

func (root *AVLTreeNode) Contains(v int) bool {
	if root == nil {
		return false
	}

	if root.Value > v {
		return root.Left.Contains(v)
	} else if root.Value < v {
		return root.Right.Contains(v)
	} else {
		return true
	}
}

func (root *AVLTreeNode) leftRotate() *AVLTreeNode {
	head := root.Right
	root.Right = head.Left
	head.Left = root

	root.Height = max(root.Left.getHeight(), root.Right.getHeight()) + 1
	head.Height = max(head.Left.getHeight(), head.Right.getHeight()) + 1

	return head
}

func (root *AVLTreeNode) rightRotate() *AVLTreeNode {
	head := root.Left
	root.Left = head.Right
	head.Right = root

	root.Height = max(root.Left.getHeight(), root.Right.getHeight()) + 1
	head.Height = max(head.Left.getHeight(), head.Right.getHeight()) + 1

	return head
}

func (root *AVLTreeNode) leftRightRotate() *AVLTreeNode {
	// 失衡点的左节点先左转
	root.Left = root.Left.leftRotate()

	// 失衡点 右旋
	return root.rightRotate()
}

func (root *AVLTreeNode) rightLeftRotate() *AVLTreeNode {
	// 失衡点的右节点先右转
	root.Right = root.Right.rightRotate()

	// 失衡点 左旋
	return root.leftRotate()
}

func (root *AVLTreeNode) adjust() *AVLTreeNode {
	if root.Left.getHeight()-root.Right.getHeight() == 2 {
		if root.Left.Left.getHeight() > root.Left.Right.getHeight() {
			return root.rightRotate()
		} else {
			return root.leftRightRotate()
		}
	} else if root.Right.getHeight()-root.Left.getHeight() == 2 {
		if root.Right.Right.getHeight() > root.Right.Left.getHeight() {
			return root.leftRotate()
		} else {
			return root.rightLeftRotate()
		}
	}
	return root
}

func (root *AVLTreeNode) Insert(v int) *AVLTreeNode {
	if root == nil {
		return &AVLTreeNode{v, 1, nil, nil}
	}

	if root.Value > v {
		root.Left = root.Left.Insert(v)
		head := root.adjust()
		head.Height = max(head.Left.getHeight(), head.Right.getHeight()) + 1
		return head
	} else if root.Value < v {
		root.Right = root.Right.Insert(v)
		head := root.adjust()
		head.Height = max(head.Left.getHeight(), head.Right.getHeight()) + 1
		return head
	} else {
		return root
	}
}

func (root *AVLTreeNode) Remove(v int) *AVLTreeNode {
	if root == nil {
		return nil
	}

	head := root
	if root.Value > v {
		root.Left = root.Left.Remove(v)
	} else if root.Value < v {
		root.Right = root.Right.Remove(v)
	} else {
		if root.Left != nil && root.Right != nil {
			// 使用右子树的最小值替换根节点，并将右子树中的最小节点删除
			root.Value = root.Right.getMin()
			root.Right = root.Right.Remove(root.Value)
		} else if root.Left != nil {
			// 只有一个左孩子，直接返回
			head = root.Left
		} else {
			// 只有一个右孩子，或者左右孩子均为nil
			head = root.Right
		}
	}

	if head != nil {
		head = head.adjust()
		head.Height = max(head.Left.getHeight(), head.Right.getHeight()) + 1
	}

	return head
}

func (root *AVLTreeNode) getMin() int {
	if root == nil {
		return -1
	}

	if root.Left == nil {
		return root.Value
	}

	return root.Left.getMin()
}

func (root *AVLTreeNode) getHeight() int {
	if root == nil {
		return 0
	}

	return root.Height
}

func (root *AVLTreeNode) InOrder(result *[]int) {
	if root == nil {
		return
	}

	root.Left.InOrder(result)
	*result = append(*result, root.Value)
	root.Right.InOrder(result)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	root := &AVLTreeNode{100, 1, nil, nil}
	root = root.Insert(60)
	root = root.Insert(120)
	root = root.Insert(110)
	root = root.Insert(130)
	root = root.Insert(105)

	var result []int
	root.InOrder(&result)
	fmt.Println(result)

	result = result[:0]
	root.Remove(120)
	root.InOrder(&result)
	fmt.Println(result)
}
```







# 6. 红黑树

AVL树要求每个节点的左子树和右子树的高度差不能大于1，这会导致在插入和删除节点时，几乎都会破坏平衡树的规则，需要通过左旋或右旋操作进行调整，使之符合平衡树要求

红黑树：

- 每个节点或是黑色，或是红色
- 根节点是黑色
- 节点为黑色，子节点则为红色，反之亦然
- NIL节点为黑色
- 从一个节点到该节点的子孙节点的所有路径上，包含相同数目的黑节点

包含 n 个内部节点的红黑树高度为 O(logN)

使用红黑树的目的：**红黑树是一种平衡树，复杂的定义和规则都是为了保证树的平衡性**

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/black-red-tree.png)



# 7. BTree

B树和AVL树的不同是：B树属于多叉树，又名平衡多路查找树。数据库的索引技术中大量使用B树和B+树

B树相对于平衡二叉树的不同是，每个节点包含的关键字增多了，特别是在B树应用到数据库中的时候，数据库充分利用了磁盘块的原理(磁盘数据存储是采用块的形式存储的，每个块的大小为4K，每次IO进行数据读取时，同一个磁盘块的数据可以一次性读取出来)把节点大小限制和充分使用在磁盘快大小范围；把树的节点关键字增多后树的层级比原来的二叉树少了，减少数据查找的次数和复杂度。

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/btree-1.png)

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/btree-2.png)

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/btree-3.png)



# 8. B+树

B+树是B树的一个升级版，B+树更充分的利用了节点的空间，让查询速度更加稳定，其速度完全接近于二分法查找

- **B+树的层级更少**：相较于B树B+每个非叶子节点存储的关键字数更多，树的层级更少所以查询数据更快。
-  **B+树查询速度更稳定**：B+所有关键字数据地址都存在叶子节点上，所以每次查找的次数都相同所以查询速度要比B树更稳定。
-  **B+树天然具备排序功能**：B+树所有的叶子节点数据构成了一个有序链表，在查询大小区间的数据时候更方便，数据紧密性很高，缓存的命中率也会比B树高。
-  **B+树全节点遍历更快**：B+树遍历整棵树只需要遍历所有的叶子节点即可，而不需要像B树对每一层进行遍历，这有利于数据库做全表扫描。
-  **B树相对于B+树的优点是**，如果经常访问的数据离根节点很近，而B树的非叶子节点本身存有关键字其数据的地址，所以这种数据检索的时候会要比B+树快。

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/b-plus-tree.png)




# 9. B\*数

在B+树的基础上因其初始化的容量变大，使得节点空间使用率更高，而又存有兄弟节点的指针，可以向兄弟节点转移关键字的特性使得B*树额分解次数变得更少

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/b-star-tree.png)



# 10. 总结

- 相同思想和策略
 从平衡二叉树、B树、B+树、B*树总体来看它们的贯彻的思想是相同的，都是采用二分法和数据平衡策略来提升查找数据的速度。

- 不同的方式的磁盘空间利用
 不同点是它们一个一个在演变的过程中通过IO从磁盘读取数据的原理进行一步步的演变，每一次演变都是为了让节点的空间更合理的运用起来，从而使树的层级减少达到快速查找数据的目的。





