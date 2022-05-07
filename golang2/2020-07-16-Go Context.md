---
layout: post
title: Go Context
date:  2020-07-16 11:20:08
comments: true
photos: 
tags: 
categories: Golang
---

# 1. 简介

context 管理了一组呈现树状结构的 Goroutine, 让每个Goroutine 都拥有相同的上下文, 并且可以在这个上下文中传递数据

## 1.1 结构图

![go_context](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/go_context.png)

<!-- more -->

## 1.2 Context interface

```go
type Context interface {
    // 标识deadline是否已经设置了, 没有设置时, ok的值是false, 并返回初始的time.Time
	Deadline() (deadline time.Time, ok bool)
	
    // 返回一个channel, 当返回关闭的channel时可以执行一些操作
	Done() <-chan struct{}
	
    // 描述context关闭的原因,通常在Done()收到关闭通知之后才能知道原因
	Err() error
	
    // 获取上游Goroutine 传递给下游Goroutine的某些数据
    Value(key interface{}) interface{}
}
```

方法说明：

- Deadline: 设置截止时间。第一个参数表示截止时间点，第二个参数是否设置了截止时间。未设置截止时间，需要通过cancel()来取消
- Done(): 在被cancel时返回的一个只读通道
- Err(): 被cancel的原因
- Value(): 绑定到Context上的值

## 1.3 emptyCtx

```go
// An emptyCtx is never canceled, has no values, and has no deadline. It is not
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
// initialization, and tests, and as the top-level Context for incoming
// requests.
func Background() Context {
    return background
}

// TODO returns a non-nil, empty Context. Code should use context.TODO when
// it's unclear which Context to use or it is not yet available (because the
// surrounding function has not yet been extended to accept a Context
// parameter).
func TODO() Context {
    return todo
}
```

## 1.4 cancelCtx

对外暴露了 Err() Done() String() 方法

```go
// A cancelCtx can be canceled. When canceled, it also cancels any children
// that implement canceler.
type cancelCtx struct {
    Context

    mu       sync.Mutex            // protects following fields
    done     chan struct{}         // created lazily, closed by first cancel call
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
// removeFromParent is true, removes c from its parent's children.
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
        // NOTE: acquiring the child's lock while holding parent's lock.
        child.cancel(false, err)
    }
    c.children = nil
    c.mu.Unlock()

    if removeFromParent {
        removeChild(c.Context, c)
    }
}
```

## 1.5 valueCtx

通过 valueCtx 结构知道仅是在Context 的基础上增加了元素 key 和 value

```go
// A valueCtx carries a key-value pair. It implements Value for that key and
// delegates all other calls to the embedded Context.
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

## 1.6 timerCtx

在cancelCtx 基础上增加了字段 timer 和 deadline

```go
type timerCtx struct {
    cancelCtx
    timer *time.Timer // Under cancelCtx.mu.

    deadline time.Time
}

func (c *timerCtx) Deadline() (deadline time.Time, ok bool) {
    return c.deadline, true
}

func (c *timerCtx) String() string {
    return fmt.Sprintf("%v.WithDeadline(%s [%s])", c.cancelCtx.Context, c.deadline, time.Until(c.deadline))
}

func (c *timerCtx) cancel(removeFromParent bool, err error) {
    c.cancelCtx.cancel(false, err)
    if removeFromParent {
        // Remove this timerCtx from its parent cancelCtx's children.
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

# 2. 使用示例

- 通过 Background() 和 TODO() 创建最 emptyCtx 实例 ,通常是作为根节点
- 通过 WithCancel() 创建 cancelCtx 实例
- 通过 WithValue() 创建 valueCtx 实例
- 通过 WithDeadline 和 WithTimeout 创建 timerCtx 实例

## 2.1 WithCancel

```go
func Operate1(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("Operate1 done.")
			return
		default:
			fmt.Println("Operate1", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func Operate2(ctx context.Context) {
	fmt.Println("Operate2")
}

func Do1(ctx context.Context) {
	go Do2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Do1 done.")
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("Do1:", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func Do2(ctx context.Context) {
	go Operate1(ctx)
	go Operate2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Do2 done.")
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("Do2:", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())

	go Do1(ctx)

	time.Sleep(5 * time.Second)

	fmt.Println("Stop all goroutines")
	cancel()

	time.Sleep(2 * time.Second)
}
```

## 2.2 WithDeadline

```go
func task1(ctx context.Context) {
	n := 1

	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("task1:", n)
			n++
			time.Sleep(time.Second)
		}
	}
}

func task2(ctx context.Context) {
	n := 1

	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("task2:", n)
			n++
			time.Sleep(time.Second)
		}
	}
}

func main() {
	after5Sec := time.Now().Add(5 * time.Second)

	ctx, cancel := context.WithDeadline(context.Background(), after5Sec)
	defer cancel()

	go task1(ctx)
	go task2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Main done:", ctx.Err())
			return
		}
	}
}
```

## 2.3 WithTimeout

```go
func task(ctx context.Context) {
	n := 1

	for {
		select {
		case <-ctx.Done():
			fmt.Println("task is done.")
			return
		default:
			fmt.Println("task:", n)
			n++
			time.Sleep(time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	go task(ctx)

	n := 1
	for {
		select {
		case <-time.Tick(2 * time.Second):
			if n == 9 {
				return
			}
			fmt.Printf("n=%d\n", n)
			n++
			//case <-ctx.Done():
			//	fmt.Println("Main done:", ctx.Err())
			//	return
		}
	}
}
```

## 2.4 WithValue

```go
func v1(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("v1 done:", ctx.Err())
			return
		default:
			fmt.Println(ctx.Value("key"))
			time.Sleep(3 * time.Second)
		}
	}
}

func v2(ctx context.Context) {
	fmt.Println(ctx.Value("key"))
	fmt.Println(ctx.Value("v3"))

	ctx = context.WithValue(ctx, "key", "modify from v2")
	go v1(ctx)
}

func v3(ctx context.Context) {
	if v := ctx.Value("key"); v != nil {
		fmt.Println("Key =", v)
	}

	ctx = context.WithValue(ctx, "v3", "value of v3")
	go v2(ctx)

	for {
		select {
		case <-ctx.Done():
			fmt.Println("v3 done:", ctx.Err())
			return
		default:
			fmt.Println("v3")
			time.Sleep(2 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	ctx = context.WithValue(ctx, "key", "main")

	go v3(ctx)

	time.Sleep(10 * time.Second)
	cancel()
	time.Sleep(3 * time.Second)
}
```

# 3. 其他示例

## 3.1 关闭协程

### 3.1.1 使用channel

```go
func main() {
	c := make(chan bool)

	for i := 0; i < 5; i++ {
		go monitor(c, i)
	}

	time.Sleep(time.Second)

	// 关闭channel
	close(c)

	time.Sleep(5 * time.Second)

	fmt.Println("Done")
}

func monitor(c chan bool, num int) {
	for {
		select {
		case v := <-c:
			fmt.Printf("Monitor[%d], receive [%v], stopping.\n", num, v)
			return
		default:
			fmt.Printf("Monitor[%d] is running now.\n", num)
			time.Sleep(2 * time.Second)
		}
	}
}
```

### 3.1.2 使用Context

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())

	for i := 0; i < 5; i++ {
		go monitor(ctx, i)
	}

	time.Sleep(time.Second)

	// 取消操作
	cancel()

	time.Sleep(5 * time.Second)

	fmt.Println("Done")
}

func monitor(ctx context.Context, num int) {
	for {
		select {
		case v := <-ctx.Done():
			fmt.Printf("Monitor[%d], receive [%v], stopping.\n", num, v)
			return
		default:
			fmt.Printf("Monitor[%d] is running now.\n", num)
			time.Sleep(2 * time.Second)
		}
	}
}
```

## 3.2 WithDeadline 和 WithTimeout

```go
func main() {
    //ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(time.Second))
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	for i := 0; i < 5; i++ {
		go monitor(ctx, i)
	}

	time.Sleep(5 * time.Second)

	if err := ctx.Err(); err != nil {
		fmt.Printf("Reason: %v\n", err)
	}

	fmt.Println("Done")
}

func monitor(ctx context.Context, num int) {
	for {
		select {
		case <-ctx.Done():
			fmt.Printf("Monitor[%d] stopped.\n", num)
			return
		default:
			fmt.Printf("Monitor[%d] is running...\n", num)
			time.Sleep(2 * time.Second)
		}
	}
}
```

## 3.3 WithValue

```go
func main() {
	ctx1, cancel := context.WithCancel(context.Background())
	ctx2, cancel := context.WithTimeout(ctx1, time.Second)
	ctx3 := context.WithValue(ctx2, "name", "jack")
	defer cancel()

	for i := 0; i < 5; i++ {
		go monitor(ctx3, i)
	}

	time.Sleep(5 * time.Second)

	if err := ctx3.Err(); err != nil {
		fmt.Printf("Reason: %v\n", err)
	}

	fmt.Println("Done")
}

func monitor(ctx context.Context, num int) {
	for {
		select {
		case <-ctx.Done():
			fmt.Printf("Monitor[%d] stopped.\n", num)
			return
		default:
			value := ctx.Value("name")
			fmt.Printf("Monitor[%d] is running, value is %v\n", num, value)
			time.Sleep(2 * time.Second)
		}
	}
}
```

