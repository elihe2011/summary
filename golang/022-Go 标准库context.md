
# 1. 基本概念

context 管理了一组呈现树状结构的 Goroutine, 让每个Goroutine 都拥有相同的上下文, 并且可以在这个上下文中传递数据

context相关函数和方法：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/go_context.png)

| 类型            | 名称   | 作用                                                         |
| :-------------- | :----- | :----------------------------------------------------------- |
| Context         | 接口   | 定义了 Context 接口的四个方法                                |
| emptyCtx        | 结构体 | 实现了 Context 接口，它其实是个空的 context                  |
| CancelFunc      | 函数   | 取消函数                                                     |
| canceler        | 接口   | context 取消接口，定义了两个方法                             |
| cancelCtx       | 结构体 | 可以被取消                                                   |
| timerCtx        | 结构体 | 超时会被取消                                                 |
| valueCtx        | 结构体 | 可以存储 k-v 对                                              |
| Background      | 函数   | 返回一个空的 context，常作为根 context                       |
| TODO            | 函数   | 返回一个空的 context，常用于重构时期，没有合适的 context 可用 |
| WithCancel      | 函数   | 基于父 context，生成一个可以取消的 context                   |
| newCancelCtx    | 函数   | 创建一个可取消的 context                                     |
| propagateCancel | 函数   | 向下传递 context 节点间的取消关系                            |
| parentCancelCtx | 函数   | 找到第一个可取消的父节点                                     |
| removeChild     | 函数   | 去掉父节点的孩子节点                                         |
| init            | 函数   | 包初始化                                                     |
| WithDeadline    | 函数   | 创建一个有 deadline 的 context                               |
| WithTimeout     | 函数   | 创建一个有 timeout 的 context                                |
| WithValue       | 函数   | 创建一个存储 k-v 对的 context                                |

整体类图：

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/stdlib_context.png)

# 2. 实现说明

## 2.1 Context

```go
type Context interface {
  // 设置截至时间，参数deadline表示截止时间点，ok表示是否已设置截至时间。
  // 未设置，需要cancel来取消
  Deadline() (deadline time.Time, ok bool)
  
  // 被cancel时返回的一个只读通道
  Done() <-chan struct{}
  
  // 被cancel的原因
  Err() error
  
  // 绑定到Context上的值，可在goroutine上下游传递
  Value(key interface{}) interface{}
}
```



## 2.2 emptyCtx

```go
// An emptyCtx is never canceled, has no values, and has no deadline. It's not
// struct{}, since vars of this type must have distinct addresses.
type emptyCtx int

func (*emptyCtx) Deadline() (deadline time.Time, ok bool) {
  return
}

func (*emptyCtx) Done() <-chan struct{} {
  return nil
}

func (*emptyCtx) Err() error {
  return nil
}

func (*emptyCtx) Value(key interface{}) interface{} {
  return nil
}

func (e *emptyCtx) String() string {
  switch e {
    case background:
    	return "context.Background"
    case todo:
    	return "context.TODO"
  }
  return "unknown empty Context"
}

var (
  background = new(emptyCtx)
  todo       = new(emptyCtx)
)

// Background returns a non-nil, empty Context. It is never canceled, has no
// values, and has no deadline. It is typically used by the main function,
// initialization, and tests, and as the top-level Context for incoming requests.
func Background() Context {
  return background
}

// TODO returns a non-nil, empty Context. Code should use context.TODO when
// it's unclear which Context to use or it is not ye available (because the
// surrounding function has not yet been extended to accept a Context parameter)
func TODO() Context {
  return todo
}
```



## 2.3 cancelCtx

对外曝露 `Err()`, `Done()`, `String()`方法

```go
// A cancelCtx can be canceled. When canceled, it also cancels any children
// that implement canceler
type cancelCtx struct {
  Context
  
  mu       sync.Mutex           // protects following fields
  done     chan struct{}        // created lazily, closed by first cancel call
  children map[canceler]struct{} // set to nil by the first cancel call
  err      error                 // set to non-nil by the first cancel call
}

func (c *cancelCtx) Done() <-chan struct{} {
  c.mu.Lock()
  if c.done == nil {
    c.done = make(chan struct{})
  }
  d := c.done
  c.mu.Unlock()
  return d
}

func (c *cancelCtx) Err() error {
  c.mu.Lock()
  err := c.err
  c.mu.Unlock()
  return err
}

func (c *cancelCtx) String() string {
  return fmt.Sprintf("%v.WithCancel", c.Context)
}

// cancel closes c.done, cancels each of c's children, and, if
// removeFromParent is true, removes c from its parent's children
func (c *cancelCtx) cancel(removeFromParent bool, err error) {
  if err == nil {
    panic("context: internal error: missing cancel error")
  }
  c.mu.Lock()
  if c.err != nil {
    c.mu.Unlock()
    return // already canceled
  }
  c.err = err
  if c.done == nil {
    c.done = closedchan
  } else {
    close(c.done)
  }
  for child := range c.children {
    // NOTE: acquiring the child's lock while holding parent's
    child.cancel(false, err)
  }
  c.children = nil
  c.mu.Unlock()
  
  if removeFromParent {
    removeChild(c.Context, c)
  }
}
```



## 2.4 valueCtx

仅在 Context 的基础上，增加元素 key 和 value

```go
// A valueCtx carries a key-value pair. It implements Value for that key
// and delegates all other calls to the embeded Context.
type valueCtx struct {
  Context
  key, val interface{}
}

func (c *valueCtx) String() string {
  return fmt.Sprintf("%v.WithValue(%#v, %#v)", c.Context, c.key, c.val)
}

func (c *valueCtx) Value(key interface{}) interface{} {
  if c.key == key {
    return c.val
  }
  return c.Context.Value(key)
}
```

**valueCtx查找过程：**

```go
func WithValue(parent Context, key, val interface{}) Context {
  if key == nil {
    panic("nil key")
  }
  if !reflect.TypeOf(key).Comparable() {
    panic("key is not comparable")
  }
  return &valueCtx{parent, key, val}
}
```

![image](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/stdlib_context_tree.png)



## 2.5 timerCtx

在 cancelCtx 基础上，增加 timer 和 deadline

```go
type timerCtx struct {
  cancelCtx
  
  timer    *time.Timer // under cancelCtx.mu
  deadline time.Time
}

func (c *timerCtx) Deadline() (deadline time.Time, ok bool) {
  return c.deadline, true
}

func (c *timerCtx) String() string {
  return fmt.Sprintf("%v.WithDeadline(%s [%s])", c.cancelCtx.Context, c.deadline, time.Until(c.deadline))
}

func (c *timerCtx) cancel(removeFromParent bool, err error) {
  c.cacnelCtx.cancel(false, err)
  if removeFromParent {
    // Remove this timerCtx from it's parent cancelCtx's children
    removeChild(c.cancelCtx.Context, c)
  }
  c.mu.Lock()
  if c.timer != nil {
    c.timer.Stop()
    c.timer = nil
  }
  c.mu.Unlock()
}
```



# 3. 实例

| 函数           | 实例      | 说明         |
| -------------- | --------- | ------------ |
| Background()   | emptyCtx  | 通常做根节点 |
| TODO()         | emptyCtx  |              |
| WithCancel()   | cancelCtx |              |
| WithValue()    | valueCtx  |              |
| WithDeadline() | timerCtx  |              |
| WithTimeout()  | timerCtx  |              |



## 3.1 WithCancel

```go
func Task1(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("Task1 has done.")
			return
		default:
			fmt.Println("Task1:", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func Task2(ctx context.Context) {
	fmt.Println("Task2 has done.")
}

func Task3(ctx context.Context) {
	go Task1(ctx)
	go Task2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Task3 is done.")
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("Task3:", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func Task4(ctx context.Context) {
	go Task3(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Task4 is done.")
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("Task4:", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())

	go Task4(ctx)

	time.Sleep(5 * time.Second)

	fmt.Println("Stop all goroutines...")
	cancel()

	time.Sleep(2 * time.Second)
}
```



## 3.2 WithDeadline

```go
func task(ctx context.Context, n int) {
	i := 1

	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Printf("task %d: %d\n", n, i)
			i++
			time.Sleep(time.Second)
		}
	}
}

func main() {
	after5Sec := time.Now().Add(5 * time.Second)
	ctx, cancel := context.WithDeadline(context.Background(), after5Sec)
	defer cancel()

	for i := 0; i < 3; i++ {
		go task(ctx, i)
	}

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Main done:", ctx.Err())
			return
		}
	}
}
```



## 3.3 WithTimeout

```go
func task(ctx context.Context) {
	i := 1

	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Printf("task: %d\n", i)
			i++
			time.Sleep(time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	go task(ctx)

	n := 1
	for {
		select {
		case <-ctx.Done():
			fmt.Println("Main done", ctx.Err())
			return
    // 强制退出  
		case <-time.Tick(2 * time.Second):
			if n == 5 {
				fmt.Println("force exit")
				return
			}
			fmt.Println("main:", n)
			n++
		}
	}
}
```



## 3.4 WithValue

```go
func task1(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("task1 done:", ctx.Err())
			return
		default:
			fmt.Println("task1: key=", ctx.Value("key"))
			time.Sleep(3 * time.Second)
		}
	}
}

func task2(ctx context.Context) {
	fmt.Println("task2: key=", ctx.Value("key"))
	fmt.Println("task2: key=", ctx.Value("key2"))

	ctx = context.WithValue(ctx, "key", "modify from task2")
	go task1(ctx)
}

func task3(ctx context.Context) {
	ctx = context.WithValue(ctx, "key2", "value of task3")
	go task2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("task3 done:", ctx.Err())
			return
		default:
			fmt.Println("task3: key=", ctx.Value("key"))
			time.Sleep(2 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	ctx = context.WithValue(ctx, "key", "main")

	go task3(ctx)

	time.Sleep(10 * time.Second)
	cancel()
	time.Sleep(3 * time.Second)
}
```



# 4. 总结

**context的作用：**

- 传递共享的数据
- 取消goroutine
- 防止goroutine泄漏

**context在实际项目中如何使用:**

Step1: 创建background根节点，background是一个空context，它不能被取消，没有值，也没有超时时间

```go
func Background() Context
```

Step2: 创建子节点

```go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc)
func WithDeadline(parent Context, deadline time.Time) (Context, CancelFunc)
func WithTimeout(parent Context, timeout time.Time) (Context, CancelFunc)
func WithValue(parent Context, key, val interface{}) Context
```



## 4.1 传递共享的数据

```go
const requestIDKey int = 0

func WithRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(
		func(rw http.ResponseWriter, req *http.Request) {
			reqID := req.Header.Get("X-Request-ID")

			// 创建valueCtx, 使用自定义类型，不容易冲突
			ctx := context.WithValue(req.Context(), requestIDKey, reqID)

			// 创建新的请求
			req = req.WithContext(ctx)

			next.ServeHTTP(rw, req)
		})
}

func GetRequestID(ctx context.Context) string {
	return ctx.Value(requestIDKey).(string)
}

func Handle(rw http.ResponseWriter, req *http.Request) {
	reqID := GetRequestID(req.Context())
	fmt.Println(reqID)
	// ...
}

func main() {
	handler := WithRequestID(http.HandlerFunc(Handle))
	http.ListenAndServe("/", handler)
}
```



## 4.2 取消goroutine

```go
func Perform(ctx context.Context) {
  for {
    calculatePos()
    sendResult()
    
    select {
    case <-ctx.Done():
      return
      case <-time.After(time.Second):
    }
  }
}

// 取消查看
ctx, cancel := context.WithTimeout(context.Background(), time.Hour)
go Perform(ctx)

// app端返回页面，调用cancel函数
cancel()
```



## 4.3 防止goroutine泄漏

```go
func gen(ctx context.Context) <-chan int {
	ch := make(chan int)
	go func() {
		var n int
		for {
			select {
			case <-ctx.Done():
				return
			case ch <- n:
				n++
				time.Sleep(time.Second)
			}
		}
	}()

	return ch
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	for n := range gen(ctx) {
		fmt.Println(n)
		if n == 5 {
			cancel()
			break
		}
	}
}
```



# 5. Context使用原则

- 不要把Context放在结构体中，要以参数形式传递
- 做函数参数时，应该作为第一个参数
- 给一个函数传递Context时，不要传递nil，如果不知道传递什么，就使用context.TODO
- Context的Value相关方法应该传递必须的数据，不要什么数据都传递
- Context是线程安全的，可以放心的在多个goroutine中传递

```go
func monitor(ctx context.Context, num int) {
	for {
		select {
		case <-ctx.Done():
			fmt.Printf("Monitor[%d] stopped.\n", num)
			return
		default:
			val := ctx.Value("name")
			fmt.Printf("Monitor[%d] is running, value is %v\n", num, val)
			time.Sleep(2 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	ctx, cancel = context.WithTimeout(ctx, time.Second)
	ctx = context.WithValue(ctx, "name", "jack")
	defer cancel()

	for i := 0; i < 5; i++ {
		go monitor(ctx, i)
	}

	time.Sleep(5 * time.Second)

	if err := ctx.Err(); err != nil {
		fmt.Printf("Reason: %v\n", err)
	}

	fmt.Println("Done.")
}
```
