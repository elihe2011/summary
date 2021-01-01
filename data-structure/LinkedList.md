# 1. 单向链表

数据存储的两种方式：

- 数组：顺序存储
- 链表：链式存储

## 1.1 定义单向链表

```go
type Node struct {
	Data int
	Next *Node
}

type LinkedList struct {
	head *Node
}

func (l *LinkedList) IsEmpty() bool {
	if l.head == nil {
		return true
	}
	return false
}

func (l *LinkedList) Length() int {
	cur := l.head

	count := 0
	for cur != nil {
		count++
		cur = cur.Next
	}

	return count
}

func (l *LinkedList) Traverse() {
	cur := l.head

	for cur != nil {
		fmt.Printf("%d ", cur.Data)
		cur = cur.Next
	}
	fmt.Println()
}

func (l *LinkedList) Contains(v int) bool {
	cur := l.head
	for cur != nil {
		if cur.Data == v {
			return true
		}
		cur = cur.Next
	}
	return false
}
```

## 1.2 链表头插入元素

```go
func (l *LinkedList) Add(v int) {
	node := &Node{Data: v}

	if l.head == nil {
		l.head = node
	} else {
		node.Next = l.head
		l.head = node
	}
}
```

## 1.3 链表尾插入元素

```go
func (l *LinkedList) Append(v int) {
	node := &Node{Data: v}

	if l.head == nil {
		l.head = node
	} else {
		cur := l.head
		// 找到链表最后一个元素
		for cur.Next != nil {
			cur = cur.Next
		}
		cur.Next = node
	}
}
```

## 1.4 固定位置插入元素

```go
func (l *LinkedList) Insert(index int, v int) {
	if index <= 0 {
		// 头部插入
		l.Add(v)
	} else if index > l.Length() {
		// 尾部追加
		l.Append(v)
	} else {
		cur := l.head
		count := 0
		// 找到插入位置的前一个元素
		for count < index-1 {
			cur = cur.Next
			count++
		}
		node := &Node{Data: v}
		node.Next = cur.Next
		cur.Next = node
	}
}
```

## 1.5 删除元素

```go
func (l *LinkedList) Remove(v int) {
	head := l.head
	if head == nil {
		return
	}

	if head.Data == v {
		// 重置头元素，并再次迭代，尝试删除相同的元素
		l.head = head.Next
		l.Remove(v)
	} else {
		cur := head
		for cur.Next != nil {
			if cur.Next.Data == v {
				cur.Next = cur.Next.Next
			} else {
				cur = cur.Next
			}
		}
	}
}
```

## 1.6 删除固定位置元素

```go
func (l *LinkedList) RemoveAtIndex(index int) {
	head := l.head
	if head == nil {
		return
	}

	if index <= 0 {
		l.head = head.Next
	} else if index > l.Length() {
		fmt.Println("Out of length")
		return
	} else {
		count := 0

		prev := head
		for count != index-1 && prev.Next != nil {
			count++
			prev = prev.Next
		}
		prev.Next = prev.Next.Next
	}
}
```

## 1.7 链表反转

### 1.7.1 迭代反转

```go
func (l *LinkedList) Reverse() {
	cur := l.head
	var prev *Node
	for cur != nil {
		prev, cur, cur.Next = cur, cur.Next, prev
	}

	l.head = prev
}
```

### 1.7.2 递归反转

```go
func (l *LinkedList) ReverseV2() {
	l.head = l.head.Reverse()
}

func (head *Node) Reverse() *Node {
	if head == nil || head.Next == nil {
		return head
	}

	last := head.Next.Reverse()
	head.Next.Next = head // 反向链接
	head.Next = nil       // 断开原有链接
	return last
}
```



# 3. 相关问题

```go
type ListNode struct {
	Val  int
	Next *ListNode
}

func appendNode(head *ListNode, v int) *ListNode {
	node := &ListNode{Val: v}

	if head == nil {
		return node
	} else {
		cur := head
		for cur.Next != nil {
			cur = cur.Next
		}
		cur.Next = &ListNode{Val: v}
	}
	return head
}

func traverse(head *ListNode) {
	for head != nil {
		fmt.Printf("%d ", head.Val)
		head = head.Next
	}
	fmt.Println()
}

func main() {
	a := []int{1, 2, 3, 4, 5, 6}

	var head *ListNode
	for _, v := range a {
		head = appendNode(head, v)
	}
	traverse(head)
}
```

## 3.1 链表反转

### 3.1.1 反转整个链表

```go
func reverse(head *ListNode) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}

	last := reverse(head.Next)
	head.Next.Next = head // 指向反转
	head.Next = nil       // 断开原有指向
	return last
}

// 迭代法
func reverse(head *ListNode) *ListNode {
	var pre *ListNode
	for head != nil {
		pre, head, head.Next = head, head.Next, pre
	}

	return pre
}
```

### 3.1.2 反转链表前N个节点

```go
var successor *ListNode

func reverseN(head *ListNode, n int) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}

	// 反转一个元素，即本身，记录后驱节点
	if n == 1 {
		successor = head.Next
		return head
	}

	last := reverseN(head.Next, n-1)
	head.Next.Next = head
	head.Next = successor
	return last
}
```

### 3.1.3 反转链表的一部分

```go
func reverseBetween(head *ListNode, m, n int) *ListNode {
	// 从第一个元素反转
	if m == 1 {
        successor = nil // leetcode 中需要清除
		return reverseN(head, n)
	}

	// 前进到反转触发点
	head.Next = reverseBetween(head.Next, m-1, n-1)
	return head
}
```

### 3.1.4 K个一组反转

```go
// 反转区间 [a, b)
func reverse(a, b *ListNode) *ListNode {
	var pre *ListNode
	for a != b {
		pre, a, a.Next = a, a.Next, pre
	}

	return pre
}

func reverseKGroup(head *ListNode, k int) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}

	a := head
	b := head

	for i := 0; i < k; i++ {
		// 不足k个，不反转
		if b == nil {
			return head
		}
		b = b.Next
	}

	// 反转前k个元素
	newHead := reverse(a, b)

	// 递归反转后的链表链接起来
	a.Next = reverseKGroup(b, k)

	return newHead
}
```

## 3.2 回文单链表 （Palindrome）

### 3.2.1 判断回文单链表

时间复杂度：O(N), 空间复杂度：O(N)

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/list/list-palindrome-judge.gif)

```go
var left *ListNode

func isPalindrome(head *ListNode) bool {
	left = head
	return judge(head)
}

func judge(right *ListNode) bool {
	if right == nil {
		return true
	}

	ans := judge(right.Next)

	// 后续遍历
	ans = ans && left.Val == right.Val
	left = left.Next
	return ans
}
```

### 3.2.2 优化空间复杂度

时间复杂度：O(N), 空间复杂度：O(1)

```go
func reverse(head *ListNode) *ListNode {
	var pre *ListNode
	for head != nil {
		pre, head, head.Next = head, head.Next, pre
	}
	return pre
}

func isPalindrome(head *ListNode) bool {
	// 通过快慢指针，找到中点
	slow, fast := head, head
	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
	}

	// 链表长度为奇数时，slow指针下移一位
	if fast != nil {
		slow = slow.Next
	}

	// 左半部分保持不变，右半部分反转
	left := head
	right := reverse(slow)

	for right != nil {
		if left.Val != right.Val {
			return false
		}
		left = left.Next
		right = right.Next
	}

	return true
}
```

## 3.3 检查链表是否有环

```go
func detectCycle(head *ListNode) *ListNode {
	slow, fast := head, head
	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next

        // 找到入环点
		if fast != nil && fast == slow {
			fast = head
			for fast != slow {
				fast = fast.Next
				slow = slow.Next
			}
			return fast
		}
	}
	return nil
}
```

## 3.4 删除链表元素

### 3.4.1 删除给定节点

```go
func deleteNode(node *ListNode) {
    node.Val = node.Next.Val
    node.Next = node.Next.Next
}
```

### 3.4.2 删除从尾部起第N个元素

```go
func removeNthFromEnd(head *ListNode, n int) *ListNode {
	slow, fast := head, head

	// 先让 fast 指针领先 n 步
	for i := 0; i < n; i++ {
		fast = fast.Next
	}

	// fast 指针为空，已走到末尾
	if fast == nil {
		return head.Next
	}

	// fast 指针继续行走，直到尾部
	for fast.Next != nil {
		fast = fast.Next
		slow = slow.Next
	}

	// slow 指针，直接跳过下一个元素
	slow.Next = slow.Next.Next
	return head
}
```

## 3.5 合并两个有序列表

```go
func mergeTwoList(l1, l2 *ListNode) *ListNode {
	head := new(ListNode)
	p := head

	for l1 != nil && l2 != nil {
		if l1.Val < l2.Val {
			p.Next = l1
			p = p.Next
			l1 = l1.Next
		} else {
			p.Next = l2
			p = p.Next
			l2 = l2.Next
		}
	}

	if l1 == nil {
		p.Next = l2
	}

	if l2 == nil {
		p.Next = l1
	}

	return head.Next
}
```




