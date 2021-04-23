# 1. 二叉树

## 1.1 翻转二叉树

```
     4
   /   \
  2     7
 / \   / \
1   3 6   9

     4
   /   \
  7     2
 / \   / \
9   6 3   1
```

```go
func reverseTree(root *TreeNode) *TreeNode {
	if root == nil {
		return nil
	}

	left := reverseTree(root.Right)
	right := reverseTree(root.Left)

	root.Left = left
	root.Right = right
	return root
}
```

## 1.2 二叉树展开为链表

```
    1
   / \
  2   5
 / \   \
3   4   6

1
 \
  2
   \
    3
     \
      4
       \
        5
```



```go
func flatten(root *TreeNode) {
	if root == nil {
		return
	}

	// 辗平左右树
	flatten(root.Left)
	flatten(root.Right)

	left := root.Left
	right := root.Right

	// 左子树变右子树，
	root.Right = left
	root.Left = nil

	// 右子树走到末尾，拼接原有右子树部分
	p := root
	for p.Right != nil {
		p = p.Right
	}
	p.Right = right
}
```

## 1.3 填充每个节点的下一个右侧节点指针

```go
/**
 * Definition for a Node.
 * type Node struct {
 *     Val int
 *     Left *Node
 *     Right *Node
 *     Next *Node
 * }
 */

func connect(root *Node) *Node {
    if root == nil {
        return root
    }

	connectTwoNode(root.Left, root.Right)
    return root
}

func connectTwoNode(node1, node2 *Node) {
    if node1 == nil || node2 == nil {
        return
    }

    node1.Next = node2
    connectTwoNode(node1.Left, node1.Right)
    connectTwoNode(node2.Left, node2.Right)

    connectTwoNode(node1.Right, node2.Left)
}
```

## 1.4 最大二叉树

给定一个不含重复元素的整数数组。一个以此数组构建的最大二叉树定义如下：

1. 二叉树的根是数组中的最大元素。
2. 左子树是通过数组中最大值左边部分构造出的最大二叉树。
3. 右子树是通过数组中最大值右边部分构造出的最大二叉树。

通过给定的数组构建最大二叉树，并且输出这个树的根节点。

```
输入：[3,2,1,6,0,5]
输出：返回下面这棵树的根节点：

      6
    /   \
   3     5
    \    / 
     2  0   
       \
        1
```

```go
func constructMaximumBinaryTree(nums []int) *TreeNode {
	if len(nums) == 0 {
		return nil
	}

	// 找到最大值的 index
	index := 0
	for i := 1; i < len(nums); i++ {
		if nums[index] < nums[i] {
			index = i
		}
	}

	// 递归构建左右子节点
	root := &TreeNode{Val: nums[index]}
	root.Left = constructMaximumBinaryTree(nums[:index])
	root.Right = constructMaximumBinaryTree(nums[index+1:])

	return root
}
```

## 1.5 恢复二叉树

### 1.5.1 前序 & 中序

```txt
前序遍历 preorder = [3,9,20,15,7]
中序遍历 inorder = [9,3,15,20,7]

    3
   / \
  9  20
    /  \
   15   7
```



```go
func buildTree(preorder []int, inorder []int) *TreeNode {
    preStart, preEnd := 0, len(preorder)-1
    inStart, inEnd := 0, len(inorder)-1

    return build(preorder, preStart, preEnd, inorder, inStart, inEnd)
}

func build(preorder []int, preStart, preEnd int, inorder []int, inStart, inEnd int) *TreeNode {
    if preStart > preEnd || inStart > inEnd {
        return nil
    }

    // 根节点
    val := preorder[preStart]
    root := &TreeNode{Val: val}

    // 中序中根节点位置
    var k int
    for i := inStart; i <= inEnd; i++ {
        if inorder[i] == val {
            k = i
            break
        }
    }

    // 左子树长度 k-inStart, preorder区间 [preStart+1, preStart+1+(k-inStart)-1]
    root.Left = build(preorder, preStart+1, preStart+(k-inStart), inorder, inStart, k-1)
    
    // preorder 区间 [preStart+1+(k-inStart), preEnd]
    root.Right = build(preorder, preStart+1+(k-inStart), preEnd, inorder, k+1, inEnd)

    return root
}
```



### 1.5.2 后序 & 中序

```txt
中序遍历 inorder = [9,3,15,20,7]
后序遍历 postorder = [9,15,7,20,3]

    3
   / \
  9  20
    /  \
   15   7
```

```go
func buildTree(inorder []int, postorder []int) *TreeNode {
    inStart, inEnd := 0, len(inorder)-1
    postStart, postEnd := 0, len(postorder)-1

    return build(inorder, inStart, inEnd, postorder, postStart, postEnd)
}

func build(inorder []int, inStart, inEnd int, postorder []int, postStart, postEnd int) *TreeNode {
    if inStart > inEnd || postStart > postEnd {
        return nil
    }

    // 根节点
    val := postorder[postEnd]
    root := &TreeNode{Val: val}

    // 中序中找到根节点位置
    var k int
    for i := inStart; i <= inEnd; i++ {
        if inorder[i] == val {
            k = i
            break
        }
    }

    // 左子树长度 k-inStart, postorder区间 [postStart, postStart+(k-inStart)-1]
    root.Left = build(inorder, inStart, k-1, postorder, postStart, postStart+(k-inStart)-1)
    
    // postorder区间 [postStart+(k-inStart), postEnd-1]
    root.Right = build(inorder, k+1, inEnd, postorder, postStart+(k-inStart), postEnd-1)

    return root
}
```



### 1.5.3 层序 & 中序

![1](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/bitree-level-in-order.png)

## 1.6 寻找重复的子树

```txt
        1
       / \
      2   3
     /   / \
    4   2   4
       /
      4

重复的子树：
      2
     /
    4    
    
    4
```

使用深度优先搜索，其中递归函数返回当前子树的序列化结果。把每个节点开始的子树序列化结果保存在 map 中，然后判断是否存在重复的子树。

```go
var count map[string]int
var ans []*TreeNode

func findDuplicateSubtrees(root *TreeNode) []*TreeNode {
    count = make(map[string]int)
    ans = ans[:0]
    collect(root)
    return ans
}

func collect(node *TreeNode) string {
    if node == nil {
        return "#"
    }

    serial := fmt.Sprintf("%d.%s.%s", node.Val, collect(node.Left), collect(node.Right))
    c, ok := count[serial]
    if ok {
        if c == 1 {
            ans = append(ans, node)
        }
        count[serial] = c+1
    } else {
        count[serial] = 1
    }

    return serial
}
```

## 1.7 [二叉树的最近公共祖先](https://leetcode-cn.com/problems/lowest-common-ancestor-of-a-binary-tree/)

最近公共祖先（Lowest Common Ancestor，简称 LCA）。

给定一个二叉树, 找到该树中两个指定节点的最近公共祖先。

百度百科中最近公共祖先的定义为：“对于有根树 T 的两个结点 p、q，最近公共祖先表示为一个结点 x，满足 x 是 p、q 的祖先且 x 的深度尽可能大（一个节点也可以是它自己的祖先）。”

**说明:**

- 所有节点的值都是唯一的。
- p、q 为不同节点且均存在于给定的二叉树中。

```txt
输入: root = [3,5,1,6,2,0,8,null,null,7,4], p = 5, q = 1
输出: 3
解释: 节点 5 和节点 1 的最近公共祖先是节点 3。
```

```go
func lowestCommonAncestor(root, p, q *TreeNode) *TreeNode {
    if root == nil {
        return nil
    }

    // 与根节点相同
    if p == root || q == root {
        return root
    }

    // 各种左右子树中查找
    left := lowestCommonAncestor(root.Left, p, q)
    right := lowestCommonAncestor(root.Right, p, q)

    // 左子树未找到，返回右子树的搜索结果
    if left == nil {
        return right
    }

    // 右子树未找到，返回左子树的搜索结果
    if right == nil {
        return left
    }

    // 左右子树均找到，返回根
    return root
}
```

## 1.8 [完全二叉树的节点个数](https://leetcode-cn.com/problems/count-complete-tree-nodes/)

完全二叉树的定义如下：在完全二叉树中，除了最底层节点可能没填满外，其余每层节点数都达到最大值，并且最下面一层的节点都集中在该层最左边的若干位置。若最底层为第 h 层，则该层包含 1~ 2h 个节点。

完全二叉树：Complete Binary Tree

满二叉树：Perfect Binary Tree

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/tree/diff-binary-tree.png)

```go
// 普通二叉树节点总数
func countNodes(root *TreeNode) int {
	if root == nil {
		return 0
	}

	return 1 + countNodes(root.Left) + countNodes(root.Right)
}

// 满二叉树
func countNodes(root *TreeNode) int {
	var h float64

	node := root
	for node != nil {
		h++
		node = node.Left
	}

	return int(math.Pow(2, h)) - 1
}

// 完全二叉树
func countNodes(root *TreeNode) int {
	var hl, hr float64

	left, right := root, root

	for left != nil {
		hl++
		left = left.Left
	}

	for right != nil {
		hr++
		right = right.Right
	}

	// 是否满二叉树
	if hl == hr {
		return int(math.Pow(2, hl)) - 1
	}

	return 1 + countNodes(root.Left) + countNodes(root.Right)
}
```





# 2. 二叉搜索树

## 2.1 [二叉搜索树中第K小的元素](https://leetcode-cn.com/problems/kth-smallest-element-in-a-bst/)

```txt
输入: root = [5,3,6,2,4,null,null,1], k = 3
       5
      / \
     3   6
    / \
   2   4
  /
 1
输出: 3
```

```go
var count int
var ans int

func kthSmallest(root *TreeNode, k int) int {
    count = 0
    ans = -1

    inorder(root, k)
    return ans
}

func inorder(root *TreeNode, k int) {
    if root == nil {
        return
    }

    inorder(root.Left, k)

    // 中序
    count++
    if count == k {
        ans = root.Val
        return
    }

    inorder(root.Right, k)
}
```

## 2.2 [把二叉搜索树转换为累加树](https://leetcode-cn.com/problems/convert-bst-to-greater-tree/)

![t](https://assets.leetcode-cn.com/aliyun-lc-upload/uploads/2019/05/03/tree.png)

```txt
输入：[4,1,6,0,2,5,7,null,null,null,3,null,null,null,8]
输出：[30,36,21,36,35,26,15,null,null,null,33,null,null,null,8]
```

```go
var num int // 记录上个root节点的值

func convertBST(root *TreeNode) *TreeNode {
    num = 0
    return reverseInOrder(root)
}

func reverseInOrder(root *TreeNode) *TreeNode {
    if root == nil {
        return nil
    }

    // 反向中序遍历
    reverseInOrder(root.Right)

    root.Val = root.Val + num
    num = root.Val

    reverseInOrder(root.Left)
    
    return root
}
```

更优秀解法：

```go
func bstToGst(root *TreeNode) *TreeNode {
    sum := 0
    var dfs func(*TreeNode)
    dfs = func(node *TreeNode) {
        if node != nil {
            dfs(node.Right)
            sum += node.Val
            node.Val = sum
            dfs(node.Left)
        }
    }
    
    dfs(root)
    return root
}
```

## 2.3 判断BST的合法性

```txt
       10
       / \
      5   15
         / \
        6   20
```

```go
// 错误：root 的整个左子树都要小于 root.val，整个右子树都要大于 root.val
func isValidBST(root *TreeNode) bool {
	if root == nil {
		return true
	}

	if root.Left != nil {
		if root.Left.Val >= root.Val {
			return false
		}
	}

	if root.Right != nil {
		if root.Right.Val <= root.Val {
			return false
		}
	}

	return isValidBST(root.Left) && isValidBST(root.Right)
}

func isValidBSTOK(root *TreeNode) bool {
	var isValid func(*TreeNode, *TreeNode, *TreeNode) bool

	isValid = func(root, min, max *TreeNode) bool {
		if root == nil {
			return true
		}

		if min != nil {
			if min.Val >= root.Val {
				return false
			}
		}

		if max != nil {
			if max.Val <= root.Val {
				return false
			}
		}

		return isValid(root.Left, min, root) && isValid(root.Right, root, max)
	}

	return isValid(root, nil, nil)
}

func isValidBSTOK2(root *TreeNode) bool {
	var isValid func(*TreeNode, int, int) bool

	isValid = func(root *TreeNode, min, max int) bool {
		if root == nil {
			return true
		}

		if root.Val <= min || root.Val >= max {
			return false
		}

		return isValid(root.Left, min, root.Val) && isValid(root.Right, root.Val, max)
	}

	return isValid(root, math.MinInt64, math.MaxInt64)
}
```

## 2.4 BST 元素管理

### 2.4.1 插入元素

```go
func insertIntoBST(root *TreeNode, val int) *TreeNode {
	if root == nil {
		return &TreeNode{Val: val}
	}

	if root.Val > val {
		root.Left = insertIntoBST(root.Left, val)
	} else if root.Val < val {
		root.Right = insertIntoBST(root.Right, val)
	}

	return root
}
```

### 2.4.2 删除元素

三种情况：

1. 被删除节点没有子节点，直接删除
2. 被删除节点有一个子节点，使用该子节点替换
3. 被删除节点左右子节点均在
   - 使用左子树的最大值替换，并删除原有最大值节点
   - 使用右子树的最小值替换，并删除原有最小值节点

```go
func removeFromBST(root *TreeNode, val int) *TreeNode {
	if root == nil {
		return root
	}

	if root.Val > val {
		root.Left = removeFromBST(root.Left, val)
	} else if root.Val < val {
		root.Right = removeFromBST(root.Right, val)
	} else {
		if root.Left == nil {
			return root.Right
		}
		if root.Right == nil {
			return root.Left
		}

		// 用右子树的最小节点替换root
		minNode := getMin(root.Right)
		root.Val = minNode.Val

		// 删除原有节点
		removeFromBST(root.Right, minNode.Val)
	}

	return root
}

func getMin(node *TreeNode) *TreeNode {
	for node.Left != nil {
		node = node.Left
	}

	return node
}
```

# 3. 二叉树序列化

```go
type Codec struct {
	L []string
}

func Constructor() Codec {
	return Codec{}
}

// Serializes a tree to a single string.
func (this *Codec) serialize(root *TreeNode) string {
	var f func(*TreeNode, string) string

	f = func(node *TreeNode, s string) string {
		if node == nil {
			s += "null,"
			return s
		}

		s += strconv.Itoa(node.Val) + ","
		s = f(node.Left, s)
		s = f(node.Right, s)
		return s
	}

	return f(root, "")
}

// Deserializes your encoded data to tree.
func (this *Codec) deserialize(data string) *TreeNode {
	a := strings.Split(data, ",")
	for i := 0; i < len(a); i++ {
		if a[i] != "" {
			this.L = append(this.L, a[i])
		}
	}

	var f func() *TreeNode
	f = func() *TreeNode {
		if this.L[0] == "null" {
			this.L = this.L[1:]
			return nil
		}

		v, _ := strconv.Atoi(this.L[0])
		this.L = this.L[1:]
		root := &TreeNode{Val: v}

		root.Left = f()
		root.Right = f()
		return root
	}

	return f()
}

func main() {
	root := initTree()

	ser := Constructor()
	deser := Constructor()

	data := ser.serialize(root)
	fmt.Println(data)

	ans := deser.deserialize(data)
	var result []int
	levelOrder(ans, &result)
	fmt.Println(result)
}
```

