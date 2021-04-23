# 1. Stack

栈： 只能从一端插入或删除的线性表

特点：后进先出 LIFO, Last Input First Output

```go
type Stack struct {
	items []string
	lock  sync.RWMutex
}

func (s *Stack) IsEmpty() bool {
	if len(s.items) == 0 {
		return true
	}
	return false
}

func (s *Stack) Push(v string) {
	s.lock.Lock()
	defer s.lock.Unlock()

	s.items = append(s.items, v)
}

func (s *Stack) Pop() string {
	if s.IsEmpty() {
		panic("empty")
	}
	s.lock.Lock()
	defer s.lock.Unlock()

	v := s.items[len(s.items)-1]
	s.items = s.items[:len(s.items)-1]

	return v
}

func (s *Stack) Peek() string {
	if s.IsEmpty() {
		panic("empty")
	}

	s.lock.RLock()
	defer s.lock.RUnlock()

	v := s.items[len(s.items)-1]
	return v
}

func main() {
	s := new(Stack)
	s.Push("abc")
	s.Push("123")
	s.Push("xyz")

	x := s.Peek()
	fmt.Println(x)

	for !s.IsEmpty() {
		fmt.Println(s.Pop())
	}
}
```



# 2. Queue

队列：只能在一端进行插入，再另一端进行删除的线性表

特点：先进先出 FIFO

```go
type Queue struct {
	items []int
	lock  sync.RWMutex
}

func (q *Queue) IsEmpty() bool {
	if len(q.items) == 0 {
		return true
	}
	return false
}

func (q *Queue) EnQueue(v int) {
	q.lock.Lock()
	defer q.lock.Unlock()

	q.items = append(q.items, v)
}

func (q *Queue) DeQueue() int {
	if q.IsEmpty() {
		panic("empty")
	}

	q.lock.Lock()
	defer q.lock.Unlock()

	v := q.items[0]
	q.items = q.items[1:]
	return v
}

func (q *Queue) Peek() int {
	if q.IsEmpty() {
		panic("empty")
	}

	q.lock.RLock()
	defer q.lock.RUnlock()

	v := q.items[len(q.items)-1]
	return v
}

func main() {
	q := new(Queue)
	q.EnQueue(1)
	q.EnQueue(2)
	q.EnQueue(3)

	fmt.Println(q.Peek())

	for !q.IsEmpty() {
		fmt.Println(q.DeQueue())
	}
}
```

# 3. 相关问题

## 3.1 有效的括号

```go
func isValid(s string) bool {
    stack := new(Stack)

    for i := 0; i < len(s); i++ {
        switch s[i] {
            case '(', '{', '[':
                stack.Push(s[i])
            case ')':
                if stack.IsEmpty() || stack.Pop() != '(' {
                    return false
                }
            case '}':
                if stack.IsEmpty() || stack.Pop() != '{' {
                    return false
                }
            case ']':
                if stack.IsEmpty() || stack.Pop() != '[' {
                    return false
                }
        }
    }
    return stack.IsEmpty()
}
```

## 3.2 基本计算器

*逆波兰*表示法（Reverse Polish notation，RPN，或*逆波兰*记法）

```go
func main() {
	s := "(1+(4+5*2)-3)+(6+8/2)"
	e := reversePolish(s)
	fmt.Println(e)

	ans := evalRPN(e)
	fmt.Println(ans)
}

type stack []interface{}

func (s *stack) isEmpty() bool {
	return len(*s) == 0
}

func (s *stack) push(v interface{}) {
	*s = append(*s, v)
}

func (s *stack) pop() interface{} {
	if s.isEmpty() {
		panic("empty")
	}

	v := (*s)[len(*s)-1]
	*s = (*s)[:len(*s)-1]
	return v
}

func (s *stack) peek() interface{} {
	if s.isEmpty() {
		panic("empty")
	}

	v := (*s)[len(*s)-1]
	return v
}

func reversePolish(s string) []string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "-") {
		s = "0" + s
	}

	ops := new(stack)
	var tokens []string

	for i := 0; i < len(s); i++ {
		if isDigit(s[i]) {
			num := 0
			for i < len(s) && isDigit(s[i]) {
				num = num*10 + int(s[i]-'0')
				i++
			}
			i--
			tokens = append(tokens, strconv.Itoa(num))
		} else if isOperator(s[i]) {
			// 操作符优先级选择
			for !ops.isEmpty() && priority(ops.peek().(byte)) >= priority(s[i]) {
				op := ops.pop().(byte)
				tokens = append(tokens, string([]byte{op}))
			}
			ops.push(s[i])
		} else if s[i] == '(' {
			ops.push(s[i])
		} else if s[i] == ')' {
			// 括号中的操作符出栈
			for !ops.isEmpty() && ops.peek().(byte) != '(' {
				op := ops.pop().(byte)
				tokens = append(tokens, string([]byte{op}))
			}
			ops.pop() // '(' 出栈
		}
	}

	// 剩余操作符
	for !ops.isEmpty() {
		op := ops.pop().(byte)
		tokens = append(tokens, string([]byte{op}))
	}

	return tokens
}

func isDigit(c byte) bool {
	return c >= '0' && c <= '9'
}

func isOperator(c byte) bool {
	switch c {
	case '+', '-', '*', '/':
		return true
	}
	return false
}

func priority(c byte) int {
	switch c {
	case '+', '-':
		return 1
	case '*', '/':
		return 2
	}
	return 0
}

func evalRPN(tokens []string) int {
	nums := new(stack)

	for _, v := range tokens {
		switch v {
		case "+":
			a, b := nums.pop().(int), nums.pop().(int)
			nums.push(b + a)
		case "-":
			a, b := nums.pop().(int), nums.pop().(int)
			nums.push(b - a)
		case "*":
			a, b := nums.pop().(int), nums.pop().(int)
			nums.push(b * a)
		case "/":
			a, b := nums.pop().(int), nums.pop().(int)
			nums.push(b / a)
		default:
			num, _ := strconv.Atoi(v)
			nums.push(num)
		}
	}

	return nums.pop().(int)
}
```



## 3.3 单调栈

单调栈实际上就是栈，只是利用了一些巧妙的逻辑，使得每次新元素入栈后，栈内的元素都保持有序（单调递增或单调递减）。

单调栈用途不太广泛，只处理一种典型的问题，叫做 Next Greater Element。

### 3.3.1 [下一个更大元素 I](https://leetcode-cn.com/problems/next-greater-element-i/)

```txt
输入: nums1 = [4,1,2], nums2 = [1,3,4,2].
输出: [-1,3,-1]
解释:
    对于num1中的数字4，你无法在第二个数组中找到下一个更大的数字，因此输出 -1。
    对于num1中的数字1，第二个数组中数字1右边的下一个较大数字是 3。
    对于num1中的数字2，第二个数组中没有下一个更大的数字，因此输出 -1。
```

```go
func nextGreaterElement(nums1 []int, nums2 []int) []int {
    m := make(map[int]int)

    s := &stack{} // 暂存较大的数
    for i := 0; i < len(nums2); i++ {
        for !s.empty() &&  nums2[i] > s.peek(){
            // 当前值大于暂时的较大数，弹出
            m[s.pop()] = nums2[i]
        }
        s.push(nums2[i])
    }

    // 未找到比它们大的数
    for !s.empty() {
        m[s.pop()] = -1
    }

    res := make([]int, len(nums1))
    for i := 0; i < len(nums1); i++ {
        res[i] = m[nums1[i]]
    }

    return res
}

type stack []int
func (s *stack) len() int {return len(*s)}
func (s *stack) empty() bool {return s.len() == 0}
func (s *stack) peek() int {return (*s)[s.len()-1]}
func (s *stack) push(x int) {*s = append(*s, x)}
func (s *stack) pop() int {
    n := s.len()
    x := (*s)[n-1]
    *s = (*s)[:n-1]
    return x
}
```

### 3.3.2 [下一个更大元素 II](https://leetcode-cn.com/problems/next-greater-element-ii/)

```txt
输入: [1,2,1]
输出: [2,-1,2]
解释: 第一个 1 的下一个更大的数是 2；
数字 2 找不到下一个更大的数； 
第二个 1 的下一个最大的数需要循环搜索，结果也是 2。
```

```go
func nextGreaterElements(nums []int) []int {
	n := len(nums)
	res := make([]int, n)

	s := &stack{}
	for i := 0; i < 2*n-1; i++ {
		for !s.empty() && nums[i%n] > nums[s.peek()] {
			res[s.pop()] = nums[i%n]
		}
		// 只在栈中存储一遍
		if i < n {
			s.push(i)
		}
	}
    
    for !s.empty() {
		res[s.pop()] = -1
	}

	return res
}
```

### 3.3.3 [每日温度](https://leetcode-cn.com/problems/daily-temperatures/)

```txt
请根据每日 气温 列表，重新生成一个列表。对应位置的输出为：要想观测到更高的气温，至少需要等待的天数。如果气温在这之后都不会升高，请在该位置用 0 来代替。

例如，给定一个列表 temperatures = [73, 74, 75, 71, 69, 72, 76, 73]，你的输出应该是 [1, 1, 4, 2, 1, 1, 0, 0]
```

```go
func dailyTemperatures(T []int) []int {
    res := make([]int, len(T))

    s := &stack{}
    for i := 0; i < len(T); i++ {
        for !s.empty() && T[i] > T[s.peek()] {
            res[s.peek()] = i - s.pop()
        }
        s.push(i)
    }

    return res
}
```

### 3.3.4 [去除重复字母](https://leetcode-cn.com/problems/remove-duplicate-letters/)

```txt
给你一个字符串 s ，请你去除字符串中重复的字母，使得每个字母只出现一次。需保证 返回结果的字典序最小（要求不能打乱其他字符的相对位置）。

输入：s = "cbacdcbc"
输出："acdb"
```

```go
func removeDuplicateLetters(s string) string {
	lastIndex := [26]int{}
	for i := range s {
		ch := s[i]
		lastIndex[ch-'a'] = i
	}

	visited := [26]bool{}

	st := &stack{}
	for i := range s {
		ch := s[i]
		if visited[ch-'a'] {
			continue
		}

		// 单调递增栈 + 栈顶元素还会在当前元素后面再次出现
		for !st.empty() && st.peek() > ch && lastIndex[st.peek()-'a'] > i {
			c := st.pop()
			visited[c-'a'] = false
		}

		st.push(ch)
		visited[ch-'a'] = true
	}

	return string(*st)
}
```







## 3.4 单调队列

队列中的元素全都是单调递增（或递减）的

### 3.4.1 [滑动窗口最大值](https://leetcode-cn.com/problems/sliding-window-maximum/)

```txt
输入：nums = [1,3,-1,-3,5,3,6,7], k = 3
输出：[3,3,5,5,6,7]
解释：
滑动窗口的位置                最大值
---------------               -----
[1  3  -1] -3  5  3  6  7       3
 1 [3  -1  -3] 5  3  6  7       3
 1  3 [-1  -3  5] 3  6  7       5
 1  3  -1 [-3  5  3] 6  7       5
 1  3  -1  -3 [5  3  6] 7       6
 1  3  -1  -3  5 [3  6  7]      7
```

#### 3.4.1.1 优先队列

```go
var a []int
type hp struct{ sort.IntSlice }

func (h hp) Less(i, j int) bool  { return a[h.IntSlice[i]] > a[h.IntSlice[j]] }
func (h *hp) Push(v interface{}) { h.IntSlice = append(h.IntSlice, v.(int)) }
func (h *hp) Pop() interface{} {
	a := h.IntSlice
	v := h.IntSlice[len(a)-1]
	h.IntSlice = h.IntSlice[:len(a)-1]
	return v
}

func maxSlidingWindow(nums []int, k int) []int {
	a = nums
	q := &hp{make([]int, k)}
	for i := 0; i < k; i++ {
		q.IntSlice[i] = i
	}
	heap.Init(q)

	n := len(nums)
	ans := make([]int, 1, n-k+1)
	ans[0] = nums[q.IntSlice[0]]
	for i := k; i < n; i++ {
		heap.Push(q, i)
		for q.IntSlice[0] <= i-k {
			heap.Pop(q)
		}
		ans = append(ans, nums[q.IntSlice[0]])
	}
	return ans
}
```

#### 3.4.1.2 单调队列

Monotonic Queue

```go
func maxSlidingWindow(nums []int, k int) []int {
	var q []int
	push := func(i int) {
		// 去除队列中较小的数
		for len(q) > 0 && nums[i] >= nums[q[len(q)-1]] {
			q = q[:len(q)-1]
		}
		q = append(q, i)
	}

	for i := 0; i < k; i++ {
		push(i)
	}

	n := len(nums)
	ans := make([]int, 1, n-k+1)
	ans[0] = nums[q[0]]
	for i := k; i < n; i++ {
		push(i)
		// 去除不满足当前位置的下标
		for q[0] <= i-k {
			q = q[1:]
		}
		ans = append(ans, nums[q[0]])
	}
	return ans
}
```

独立数据结构：

```go
var a []int

type MonotonicQueue []int

func (mq *MonotonicQueue) Len() int      { return len(*mq) }
func (mq *MonotonicQueue) IsEmpty() bool { return mq.Len() == 0 }
func (mq *MonotonicQueue) First() int    { return (*mq)[0] }
func (mq *MonotonicQueue) Last() int     { return (*mq)[mq.Len()-1] }
func (mq *MonotonicQueue) EnQueue(i int) {
	for !mq.IsEmpty() && a[i] >= a[mq.Last()] {
		*mq = (*mq)[:mq.Len()-1]
	}
	*mq = append(*mq, i)
}
func (mq *MonotonicQueue) DeQueue() int {
	i := (*mq)[0]
	*mq = (*mq)[1:]
	return i
}

func maxSlidingWindow(nums []int, k int) []int {
	a = nums

	mq := &MonotonicQueue{}

	for i := 0; i < k; i++ {
		mq.EnQueue(i)
	}

	n := len(nums)
	ans := make([]int, 1, n-k+1)
	ans[0] = nums[mq.First()]

	for i := k; i < n; i++ {
		mq.EnQueue(i)
		if mq.First() <= i-k {
			mq.DeQueue()
		}
		ans = append(ans, nums[mq.First()])
	}

	return ans
}
```



















