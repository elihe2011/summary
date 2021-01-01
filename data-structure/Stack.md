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











