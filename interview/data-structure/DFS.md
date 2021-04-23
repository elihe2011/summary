# 1. DFS (回溯算法)

解决一个回溯问题，实际上就是一个决策树的遍历过程，要思考 3 个问题：

1、路径：也就是已经做出的选择。

2、选择列表：也就是你当前可以做的选择。

3、结束条件：也就是到达决策树底层，无法再做选择的条件。

回溯算法框架：

```python
result = []
def backtrack(路径, 选择列表):
    if 满足结束条件:
        result.add(路径)
        return

    for 选择 in 选择列表:
        做选择
        
        backtrack(路径, 选择列表)
        
        撤销选择
```

## 1.1 [全排列](https://leetcode-cn.com/problems/permutations/)

```txt
给定一个 没有重复 数字的序列，返回其所有可能的全排列。

输入: [1,2,3]
输出:
[
  [1,2,3],
  [1,3,2],
  [2,1,3],
  [2,3,1],
  [3,1,2],
  [3,2,1]
]
```

```go
func permute(nums []int) [][]int {
	n := len(nums)
	result = make([][]int, 0, factorial(n))
	track := make([]int, 0, n)
	trackMap := make(map[int]bool, n)

	backtrack(nums, track, trackMap)

	return result
}

func factorial(n int) int {
	res := 1
	for i := 2; i <= n; i++ {
		res *= i
	}
	return res
}

var result [][]int

func backtrack(nums, track []int, trackMap map[int]bool) {
	// 触发结束条件
	if len(track) == len(nums) {
		temp := make([]int, len(nums))
		copy(temp, track)
		result = append(result, temp)
		return
	}

	for _, num := range nums {
		// 排除不合法的
		if _, ok := trackMap[num]; ok {
			continue
		}

		// 做选择
		track = append(track, num)
		trackMap[num] = true

		// 进入下一层决策树
		backtrack(nums, track, trackMap)

		// 取消选择
		track = track[:len(track)-1]
		delete(trackMap, num)
	}
}
```

## 1.2 [N 皇后](https://leetcode-cn.com/problems/n-queens/)

```txt
n 皇后问题 研究的是如何将 n 个皇后放置在 n×n 的棋盘上，并且使皇后彼此之间不能相互攻击。
给你一个整数 n ，返回所有不同的 n 皇后问题 的解决方案。
每一种解法包含一个不同的 n 皇后问题 的棋子放置方案，该方案中 'Q' 和 '.' 分别代表了皇后和空位。

输入：n = 4
输出：[[".Q..","...Q","Q...","..Q."],["..Q.","Q...","...Q",".Q.."]]
解释：如上图所示，4 皇后问题存在两个不同的解法。
```

![queens](https://assets.leetcode.com/uploads/2020/11/13/queens.jpg)

```go
func solveNQueens(n int) [][]string {
	board := make([][]byte, n)
	for i := 0; i < n; i++ {
		board[i] = make([]byte, n)
		for j := 0; j < n; j++ {
			board[i][j] = '.'
		}
	}

	result = make([][]string, 0, n)

	backtrack(board, 0)
	return result
}

var result [][]string

func backtrack(board [][]byte, row int) {
	// 满足结束条件
	if row == len(board) {
		temp := make([]string, row)
		for i := 0; i < row; i++ {
			temp[i] = string(board[i])
		}
		result = append(result, temp)
	}

	for i := 0; i < len(board); i++ {
		// 检测非法性
		if !isValid(board, row, i) {
			continue
		}

		// 做选择
		board[row][i] = 'Q'

		// 进入下一级回溯
		backtrack(board, row+1)

		// 取消选择
		board[row][i] = '.'
	}
}

func isValid(board [][]byte, row, col int) bool {
	n := len(board)
	// 同一列上只能有一个Q
	for i := 0; i < n; i++ {
		if board[i][col] == 'Q' {
			return false
		}
	}

	// 左上角不能为Q
	for i, j := row-1, col-1; i >= 0 && j >= 0; i, j = i-1, j-1 {
		if board[i][j] == 'Q' {
			return false
		}
	}

	// 右上角不能为Q
	for i, j := row-1, col+1; i >= 0 && j < len(board); i, j = i-1, j+1 {
		if board[i][j] == 'Q' {
			return false
		}
	}

	return true
}
```

## 1.3 [子集](https://leetcode-cn.com/problems/subsets/)

```txt
给你一个整数数组 nums ，数组中的元素 互不相同 。返回该数组所有可能的子集（幂集）。
解集 不能 包含重复的子集。你可以按 任意顺序 返回解集。

输入：nums = [1,2,3]
输出：[[],[1],[2],[1,2],[3],[1,3],[2,3],[1,2,3]]
```

```go
func subsets(nums []int) [][]int {
	result = [][]int{{}}

	sub := make([]int, 0)

	backtrack(nums, sub, 0)

	return result
}

var result [][]int

func backtrack(nums []int, sub []int, start int) {
	if len(sub) != 0 {
		temp := make([]int, len(sub))
		copy(temp, sub)
		result = append(result, temp)
	}

	for i := start; i < len(nums); i++ {
		sub = append(sub, nums[i])

		backtrack(nums, sub, i+1)

		sub = sub[:len(sub)-1]
	}
}
```

## 1.4 [组合](https://leetcode-cn.com/problems/combinations/)

```txt
给定两个整数 n 和 k，返回 1 ... n 中所有可能的 k 个数的组合。

输入: n = 4, k = 2
输出:
[
  [2,4],
  [3,4],
  [2,3],
  [1,2],
  [1,3],
  [1,4],
]
```

```go
func combine(n int, k int) [][]int {
	result = make([][]int, 0)

	track := make([]int, 0, k)

	backtrack(n, k, track, 1)

	return result
}

var result [][]int

func backtrack(n, k int, track []int, start int) {
	// 满足结束条件
	if len(track) == k {
		temp := make([]int, k)
		copy(temp, track)
		result = append(result, temp)
		return
	}

	for i := start; i <= n; i++ {
		// 选择
		track = append(track, i)

		// 继续下一轮回溯
		backtrack(n, k, track, i+1)

		// 取消选择
		track = track[:len(track)-1]
	}
}
```

## 1.5 [解数独](https://leetcode-cn.com/problems/sudoku-solver/)

```txt
编写一个程序，通过填充空格来解决数独问题。
一个数独的解法需遵循如下规则：
数字 1-9 在每一行只能出现一次。
数字 1-9 在每一列只能出现一次。
数字 1-9 在每一个以粗实线分隔的 3x3 宫内只能出现一次。
空白格用 '.' 表示。
```

红色为答案：

![sudoku](http://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Sudoku-by-L2G-20050714_solution.svg/250px-Sudoku-by-L2G-20050714_solution.svg.png)

```go
func solveSudoku(board [][]byte) {
	backtrack(board, 0, 0)
}

func backtrack(board [][]byte, i, j int) bool {
	m, n := 9, 9

	// 穷举到了最后一列，换下一行
	if j == n {
		return backtrack(board, i+1, 0)
	}

	// 穷举到了最后一行，完毕
	if i == m {
		return true
	}

	// 当前位置已预设, 去后一个位置
	if board[i][j] != '.' {
		return backtrack(board, i, j+1)
	}

	var ch byte
	for ch = '1'; ch <= '9'; ch++ {
		if !isValid(board, i, j, ch) {
			continue
		}

		// 选择
		board[i][j] = ch

		// 下一轮回溯，如果找到，则返回
		if backtrack(board, i, j) {
			return true
		}

		// 取消选择
		board[i][j] = '.'

	}

	return false
}

func isValid(board [][]byte, row, col int, ch byte) bool {
	for i := 0; i < 9; i++ {
		// 同一行只能出现一次
		if board[row][i] == ch {
			return false
		}

		// 同一行只能出现一次
		if board[i][col] == ch {
			return false
		}

		// 同一个 3 X 3 小方格中只能出现一次
		x := row/3*3 + i/3
		y := col/3*3 + i%3
		if board[x][y] == ch {
			return false
		}
	}

	return true
}
```

## 1.6 [括号生成](https://leetcode-cn.com/problems/generate-parentheses/)

```txt
数字 n 代表生成括号的对数，请你设计一个函数，用于能够生成所有可能的并且 有效的 括号组合。

输入：n = 3
输出：["((()))","(()())","(())()","()(())","()()()"]
```

```go
func generateParenthesis(n int) []string {
	result = make([]string, 0)
	if n == 0 {
		return result
	}

	track := make([]byte, 0, 2*n)
	backtrack(n, n, track)
	return result
}

var result []string

func backtrack(left, right int, track []byte) {
	if left > right {
		return
	}

	// 超出边界
	if left < 0 || right < 0 {
		return
	}

	// 满足结束条件
	if left == 0 && right == 0 {
		result = append(result, string(track))
		return
	}

	// 左边放入 '('
	track = append(track, '(')
	backtrack(left-1, right, track)
	track = track[:len(track)-1]

	// 右边放入 ')'
	track = append(track, ')')
	backtrack(left, right-1, track)
	track = track[:len(track)-1]
}
```



# 2. BFS

**BFS 问题的本质就是让你在一幅「图」中找到从起点 `start`到终点 `target` 的最近距离**

BFS 相对 DFS 的主要区别：**BFS 找到的路径一定是最短的，但代价就是空间复杂度比 DFS 大很多**

BFS 算法框架：

```cpp
// 计算从起点 start 到终点 target 的最近距离
int BFS(Node start, Node target) {
    Queue<Node> q; // 核心数据结构
    Set<Node> visited; // 避免走回头路

    q.offer(start); // 将起点加入队列
    visited.add(start);
    int step = 0; // 记录扩散的步数

    while (q not empty) {
        int sz = q.size();
        /* 将当前队列中的所有节点向四周扩散 */
        for (int i = 0; i < sz; i++) {
            Node cur = q.poll();
            /* 划重点：这里判断是否到达终点 */
            if (cur is target)
                return step;
            /* 将 cur 的相邻节点加入队列 */
            for (Node x : cur.adj())
                if (x not in visited) {
                    q.offer(x);
                    visited.add(x);
                }
        }
        /* 划重点：更新步数在这里 */
        step++;
    }
}
```

## 2.1 [二叉树的最小深度](https://leetcode-cn.com/problems/minimum-depth-of-binary-tree/)

```txt
给定一个二叉树，找出其最小深度。
最小深度是从根节点到最近叶子节点的最短路径上的节点数量。
说明：叶子节点是指没有子节点的节点。

输入：root = [3,9,20,null,null,15,7]
输出：2
```

![bt](https://assets.leetcode.com/uploads/2020/10/12/ex_depth.jpg)

```go
func minDepth(root *TreeNode) int {
	queue := list.New()

	queue.PushBack(root)
	var step = 1

	for queue.Len() > 0 {
		size := queue.Len()
		for i := 0; i < size; i++ {
			elem := queue.Front()
			queue.Remove(elem) // dequeue

			cur := elem.Value.(*TreeNode)
			if cur.Left == nil && cur.Right == nil {
				return step
			}

			if cur.Left != nil {
				queue.PushBack(cur.Left)
			}
			if cur.Right != nil {
				queue.PushBack(cur.Right)
			}
		}
		step++
	}

	return step
}
```

## 2.2 [打开转盘锁](https://leetcode-cn.com/problems/open-the-lock/)

```txt
你有一个带有四个圆形拨轮的转盘锁。每个拨轮都有10个数字： '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' 。每个拨轮可以自由旋转：例如把 '9' 变为  '0'，'0' 变为 '9' 。每次旋转都只能旋转一个拨轮的一位数字。
锁的初始数字为 '0000' ，一个代表四个拨轮的数字的字符串。
列表 deadends 包含了一组死亡数字，一旦拨轮的数字和列表里的任何一个元素相同，这个锁将会被永久锁定，无法再被旋转。
字符串 target 代表可以解锁的数字，你需要给出最小的旋转次数，如果无论如何不能解锁，返回 -1。

输入：deadends = ["0201","0101","0102","1212","2002"], target = "0202"
输出：6
解释：
可能的移动序列为 "0000" -> "1000" -> "1100" -> "1200" -> "1201" -> "1202" -> "0202"。
注意 "0000" -> "0001" -> "0002" -> "0102" -> "0202" 这样的序列是不能解锁的，因为当拨动到 "0102" 时这个锁就会被锁定。
```

思路：从"0000"开始，转一次，可穷举出8种密码："1000", "0100", "0010", "0001", "9000", "0900", "0090", "0009"。即可将它看成一个图，每个节点有8个与之相连的节点，找它的最近距离。

```go
func openLock(deadends []string, target string) int {
	deads := make(map[string]bool, len(deadends))
	for _, v := range deadends {
		deads[v] = true
	}

	visited := make(map[string]bool)
	queue := list.New()
	queue.PushBack("0000")
	visited["0000"] = true

	var step int

	for queue.Len() > 0 {
		size := queue.Len()
		for i := 0; i < size; i++ {
			elem := queue.Front()
			queue.Remove(elem)
			cur := elem.Value.(string)

			// 无法继续向下走
			if _, ok := deads[cur]; ok {
				continue
			}

			// 找到
			if cur == target {
				return step
			}

			// 继续向下扩展，将未被访问的节点加入队列
			for j := 0; j < 4; j++ {
				plus := plusOne(cur, j)
				if _, ok := visited[plus]; !ok {
					queue.PushBack(plus)
					visited[plus] = true
				}

				minus := minusOne(cur, j)
				if _, ok := visited[minus]; !ok {
					queue.PushBack(minus)
					visited[minus] = true
				}
			}
		}

		step++
	}

	return -1
}

func plusOne(s string, i int) string {
	arr := []byte(s)
	if arr[i] == '9' {
		arr[i] = '0'
	} else {
		arr[i] += 1
	}
	return string(arr)
}

func minusOne(s string, i int) string {
	arr := []byte(s)
	if arr[i] == '0' {
		arr[i] = '9'
	} else {
		arr[i] -= 1
	}
	return string(arr)
}
```

## 2.3 双向BFS

**传统的 BFS 框架就是从起点开始向四周扩散，遇到终点时停止；而双向 BFS 则是从起点和终点同时开始扩散，当两边有交集的时候停止**。

**双向 BFS 也有局限，因为你必须知道终点在哪里**。如果一开始根本就不知道终点在哪里，也就无法使用双向 BFS

使用双向BFS 重写“打开转盘锁”

```go
func openLock2(deadends []string, target string) int {
	deads := make(map[string]bool, len(deadends))
	for _, v := range deadends {
		deads[v] = true
	}

	visited := make(map[string]bool)
	q1 := make(map[string]bool)
	q2 := make(map[string]bool)

	q1["0000"] = true
	q2[target] = true

	var step int
	for len(q1) != 0 && len(q2) != 0 {
		// 临时存储下一轮的扩散结果
		temp := make(map[string]bool)

		for cur := range q1 {
			// 到达终点，不再继续
			if _, ok := deads[cur]; ok {
				continue
			}

			// 扩散相遇
			if _, ok := q2[cur]; ok {
				return step
			}

			visited[cur] = true

			// 向下扩散
			for i := 0; i < 4; i++ {
				plus := plusOne(cur, i)
				if _, ok := visited[plus]; !ok {
					temp[plus] = true
				}

				minus := minusOne(cur, i)
				if _, ok := visited[minus]; !ok {
					temp[minus] = true
				}
			}
		}

		step++

		q1 = q2
		q2 = temp
	}

	return -1
}
```

## 2.4 [滑动谜题](https://leetcode-cn.com/problems/sliding-puzzle/)

```txt
在一个 2 x 3 的板上（board）有 5 块砖瓦，用数字 1~5 来表示, 以及一块空缺用 0 来表示.
一次移动定义为选择 0 与一个相邻的数字（上下左右）进行交换.
最终当板 board 的结果是 [[1,2,3],[4,5,0]] 谜板被解开。
给出一个谜板的初始状态，返回最少可以通过多少次移动解开谜板，如果不能解开谜板，则返回 -1 。

输入：board = [[1,2,3],[4,0,5]]
输出：1
解释：交换 0 和 5 ，1 步完成

输入：board = [[1,2,3],[5,4,0]]
输出：-1
解释：没有办法完成谜板
```

对于这种计算最小步数的问题，要敏感地想到 BFS 算法
这个题目转化成 BFS 问题是有一些技巧的，我们面临如下问题：
1、一般的 BFS 算法，是**从一个起点start开始，向终点target进行寻路**，但是拼图问题不是在寻路，而是在不断交换数字，这应该怎么转化成 BFS 算法问题呢？
2、即便这个问题能够转化成 BFS 问题，如何处理起点start和终点target？
首先回答第一个问题，BFS 算法并不只是一个寻路算法，而是一种暴力搜索算法，只要涉及暴力穷举的问题，BFS 就可以用，而且可以最快地找到答案。明白了这个道理，我们的问题就转化成了：如何穷举出board当前局面下可能衍生出的所有局面？这就简单了，看数字 0 的位置呗，和上下左右的数字进行交换就行了：

![a](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/algorithm/bfs-sliding-puzzle.png)

```go
func slidingPuzzle(board [][]int) int {
	m, n := 2, 3
	var target = "123450"
	var start string
	for i := 0; i < m; i++ {
		for j := 0; j < n; j++ {
			start += strconv.Itoa(board[i][j])
		}
	}

	// 扁平化二维数组的邻居关系
	neighbor := [][]int{
		{1, 3},
		{0, 2, 4},
		{1, 5},
		{0, 4},
		{1, 3, 5},
		{2, 4},
	}

	queue := list.New()
	visited := make(map[string]bool)
	queue.PushBack(start)
	visited[start] = true

	var step int
	for queue.Len() > 0 {
		size := queue.Len()
		for i := 0; i < size; i++ {
			elem := queue.Front()
			queue.Remove(elem)

			cur := elem.Value.(string)

			// 找到目标
			if cur == target {
				return step
			}

			// 找到 0 的位置
			var pos0 int
			for i := 0; i < len(cur); i++ {
				if cur[i] == '0' {
					pos0 = i
					break
				}
			}

            // 进行交换操作
			for _, v := range neighbor[pos0] {
				arr := []byte(cur)
				arr[v], arr[pos0] = arr[pos0], arr[v]
				next := string(arr)
				if _, ok := visited[next]; !ok {
					queue.PushBack(next)
					visited[next] = true
				}
			}

		}

		step++
	}

	return -1
}
```

