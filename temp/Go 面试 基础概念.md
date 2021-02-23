#### 1. 死锁

死锁产生原因：

1. 一个线程两次申请加锁
2. 两个线程相互申请对方的锁，但双方都不释放锁

产生死锁的四个必要条件：

1. 互斥：一个资源每次只能被一个线程使用
2. 请求与保持：一个线程因请求资源而阻塞，但对已获得资源保存不放
3. 不剥夺：线程获取的资源，在未使用完成前，不能强行剥夺
4. 循环等待：若干线程之间形成一种头尾相接的循环等待资源关系

处理死锁的四种方法：

1. 死锁预防：通过确保死锁的一个必要条件不满足，保证不会发生死锁
2. 死锁检测：允许发生死锁，但可通过系统设置的检查结构检测死锁的发生，采取措施将死锁清除掉
3. 死锁避免：在资源分配过程中，使用某些方法避免系统进入不安全状态，从而避免发生死锁
4. 死锁解除：当检测到系统中发生死锁，将进程从死锁中解脱出来

避免死锁的算法：

1. 进程启动拒绝：如果一个进程的请求会导致死锁，则不启动该进程
2. 资源分配拒绝：如果一个进程增加的资源请求会导致死锁，则不允许分配资源

解除死锁的方法：

1. 资源剥夺：挂起某些死锁进程，并抢占它的资源，将这些资源分配给其他死锁进程
2. 撤销进程法：强制撤销部分、甚至全部死锁进程的资源。



#### 5. nil slice 和 empty slice

```go
// nil slice, jsonify => null
var slice []int

// empty slice, jsonify => []
slice := make([]int, 0)
slice := []int{}
```



#### 6. 互斥锁、读写锁、死锁

- 互斥锁 (sync.Mutex) : 最简单的一种锁，读写均需要Lock/Unlock

- 读写锁 (sync.RWMutex) : 写独占、读共享、写锁优先级高




#### 7. Data Race问题怎么解决？

检测方法：`go run -race` 或 `go build -race`

解决办法：

- 互斥锁 sync.Mutex
- 使用channel，效率更高



#### 8. channel

channel是Golang的核心类型， 先进先出

可以通过channel进行goroutine间数据通信

channel的三种状态：

> - nil: 只声明，未初始化
> - active: 可正常读写
> - closed: 不是nil
>   - close操作原则上应由发送者完成。因为如果仍然向一个已关闭的channel发送数据，会导致程序抛出panic。而如果由接受者关闭channel，可能会遇到这个风险
>   - 从一个已关闭的channel中读取数据不会报错。但是，接受者不会被一个已关闭的channel的阻塞，而且接受者从关闭的channel中仍然可以读取出数据，只不过是这个channel的数据类型的默认值。可通过**`i, ok := <-c`，则ok为false时，则代表channel已经被关闭。**

总结：空(nil)读写阻塞，写关闭异常，读关闭空值

> 给一个 nil channel 发送数据，永久阻塞
>
> 从一个 nil channel 接收数据，永久阻塞
>
> 给一个已关闭的 channel 发送数据，panic
>
> 从一个已关闭的 channel 接收数据，如果缓冲区已无数据，返回一个零值
>
> 无缓存的channel是同步的，有缓冲的channel是异步的





#### 10. http 包

```go
// 客户端
http.Get()
http.Client{}
http.NewRequest()
httputil.DumpResponse()

// 服务端
http.ListenAndServe()
http.HandleFunc(endpoint, handler)
func Handler(w http.ResponseWriter, r *http.Request) {} // 请求处理函数
func HTTPInterceptor(h http.HandlerFunc) http.HandlerFunc {} // 中间件

mux := http.NewServeMux()  // http 请求路由，多路复用器Multiplexor，它把收到的请求与一组预先定义的URL路由路径做对比，然后匹配合适的路径关联到处理器Handler

// http包自带的常用处理器
http.FileServer()
http.NoFoundHandler()
http.RedirectHandler()

// 处理函数
ServeHTTP(http.ResponseWriter, *http.Request)

// 默认请求路由
func main1() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Println(r.Header.Get("User-Agent"))
		w.Write([]byte("Hello World!"))
	})

	http.ListenAndServe(":8080", nil)
}

// 自定义请求路由
func main() {
	mux := http.NewServeMux()

	mux.Handle("/", http.RedirectHandler("http://baidu.com", 307))
	http.ListenAndServe(":8080", mux)
}
```



#### 11. RPC

```go
// 服务端
rpc.Register()
rpc.RegisterName()

rpc.HandleHTTP()
             
             
// 客户端
rpc.DialHTTP()
client.Call()

// telnet 模拟调用格式
{"method": "JsonRpc.Add", "params": [{"X":5,"Y":3}], "id": 1}
```

GRPC: 

> - 使用HTTP/2协议
> - 使用Protocol Buffers作为序列化工具
> - 实现动态代理，客户端可像调用本地服务一样直接调用另一台服务器的应用方法
> - 使用静态路径，性能高



#### 12. select

语言层面的select：监听多个描述符的读写事件，一旦某个描述符就绪（一般是读写事件发生），就能够将发生的事件通知给相关的的应用程序去处理该事件

golang的select：监听多个channel，每个case都是一个事件，这些事件可以读也可以写，随机选择一个执行，可以设置default，它的作用是当被监听的多个事件都阻塞时，执行default逻辑

goroutine 优雅退出的三种方法：

> 1. for-range: 能够感知channel的关闭，自动结束
>
> 2. for-select, ok: 注意使用ok-idiom去检测channel是否已关闭
>
> 3. 使用独立的退出通道
>
>    ```go
>    for worker(done <-chan bool) {
>      go func() {
>        defer fmt.Println("worker done.")
>        for {
>          select {
>            case <-done:
>            	fmt.Println("Recv stop signal.")
>            case <-t.C:
>            	fmt.Println("Working...")
>          }
>        }
>      }()
>    }
>    ```



#### 13. Context 包 （done)

管理一组呈现树状结构的Goroutine，让每个Goroutine都拥有相同的上下文，并且可以在这个上下文中传递数据

```go
type Context interface {
  Done() <-chan struct{}
  
  Err() error
  
  Deadline() (deadline time.Time, ok bool)
  
  Value(key interface{}) interface{}
}

// 返回一个空的context，通常作为树的根节点，不能被取消，没有值，也没有过期时间
func Background() Context

// 取消函数
func CancelFunc func()

func WithCancel(parent Context) (ctx Context, cancel CancelFunc)

func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)

func WithDeadline(parent Context, t time.Time) (Context, CancelFunc)
```

示例：

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

注意：context上下文数据不是全局的，它只查询本节点及父节点的数据，不能查询兄弟节点数据

Context使用原则：

- 不要把Context放在结构体中，要以参数形式传递
- 做函数参数时，应该作为第一个参数
- 给一个函数传递Context时，不要传递nil，如果不知道传递什么，就使用context.TODO
- Context的Value相关方法应该传递必须的数据，不要什么数据都传递
- Context是线程安全的，可以放心的在多个goroutine中传递



#### 15. 复合类型所占字节

| 类型    | 所占字节 | 备注                |
| ------- | -------- | ------------------- |
| slice   | 24       |                     |
| map     | 8        |                     |
| struct  | 8        |                     |
| array   | -        | Sizeof(a[0])*len(a) |
| string  | 16       |                     |
| channel | 8        |                     |

```go
// 类型所占空间大小
unsafe.Sizeof(T) // string: 16, slice: 24, array: Sizeof(a[0])*len(a)

// 类型对齐值 (除了bool、byte、int32等，其余基本都是8)
unsafe.Alignof(T) 
// bool/byte: 1, int32: 4, int64: 8, string: 8, map: 8, slice: 8

// 结构体字段偏移
unsafe.Offset()

// 指针转换中介
unsafe.Pointer(ptr)

p := &a[0]
ptr := uintptr(unsafe.Pointer(p)) + unsafe.Sizeof(a[0])
p = (*int)(unsafe.Pointer(ptr))

// slice
type slice struct {
	array unsafe.Pointer
	len   int
	cap   int
}

// string

// map

// channel

```

![slice](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/slice-malloc.png)

#### 16. 检测是否 goroutine 泄露 

使用runtime.Stack()在测试代码前后计算goroutine的数量，代码运行完毕会触发gc，如果触发gc后，发现还有goroutine未被回收，那么这个goroutine很可能是被泄漏的

打印堆栈：

> - 当前堆栈
>
>   ```go
>   log.Info("stack %s", debug.Stack())
>   ```
>
> - 全局堆栈
>
>   ```go
>   buf := make([]byte, 1<<16)
>   runtime.Stack(buf, true)
>   log.Info("stack %s", buf)
>   ```
>

goroutine 泄漏：一个程序不断地产生新的goroutine，且又不结束它们，会造成泄漏

```go
func main() {
	for i := 0; i < 10000; i++ {
		go func() {
			select {}
		}()
	}
}
```





#### 17. 复合体反射 (done)

```go
func walk(x interface{}, fn func(string)) {
	val := getValue(x)

	walkValue := func(value reflect.Value) {
		walk(value.Interface(), fn)
	}

	switch val.Kind() {
	case reflect.String:
		fn(val.String())
	case reflect.Struct:
		for i := 0; i < val.NumField(); i++ {
			walkValue(val.Field(i))
		}
	case reflect.Slice, reflect.Array:
		for i := 0; i < val.Len(); i++ {
			walkValue(val.Index(i))
		}
	case reflect.Map:
		for _, key := range val.MapKeys() {
			walkValue(val.MapIndex(key))
		}
	}
}

func getValue(x interface{}) reflect.Value {
	val := reflect.ValueOf(x)

	if val.Kind() == reflect.Ptr {
		val = val.Elem()
	}

	return val
}

func TestWalk(t *testing.T) {
	cases := []struct {
		Name     string
		Input    interface{}
		Expected []string
	}{
		{
			"test struct",
			struct {
				Name string
			}{"Daniel"},
			[]string{"Daniel"},
		},
		{
			"test map",
			map[int]string{1: "a"},
			[]string{"a"},
		},
	}

	for _, test := range cases {
		t.Run(test.Name, func(t *testing.T) {
			var got []string
			walk(test.Input, func(s string) {
				got = append(got, s)
			})

			if !reflect.DeepEqual(got, test.Expected) {
				t.Fatalf("expected: %v, but got %v\n", test.Expected, got)
			}
		})
	}
}
```





#### 19. CAS 原子操作 (done)

原子操作：指的是一个操作或一系列操作在被CPU调度的时候不可中断

原子操作的实现方式：

> 1. 总线加锁：CPU和其他硬件的通信通过总线控制，所以可以通过Lock总线的方式实现原子操作，但这样会阻塞其他硬件对CPU的访问，开销太大
> 2. 缓存锁定：频繁使用的内存会被处理器放进高速缓存中，那么原子操作就可以直接在处理器的高速缓存中进行，主要依靠缓存的一致性来确保其原子性

Golang 中的原子操作，`sync/atomic` 中的CAS函数：

```go
func CompareAndSwapInt64(addr *int64, old, new int64) (swapped bool)
```

```go
var G_INT int64
var WG sync.WaitGroup
var ThreadCnt int

func AtomicOperation() {
	var tempInt int64
	for {
		if ThreadCnt == 100 {
			break
		}
	}

	/*	// 错误操作
		tempInt = G_INT
		result := atomic.CompareAndSwapInt64(&G_INT, tempInt, tempInt+1)
		fmt.Println(tempInt, "try to CAS:", result)*/

	// 正常操作
	for {
		tempInt = atomic.LoadInt64(&G_INT)
		result := atomic.CompareAndSwapInt64(&G_INT, tempInt, tempInt+1)
		if result {
			fmt.Println(tempInt, "try to CAS:", result)
			break
		}
	}

	WG.Done()
}

func main() {
	G_INT = 0
	ThreadCnt = 0

	for i := 0; i < 100; i++ {
		go AtomicOperation()
		WG.Add(1)
		ThreadCnt++
		fmt.Println("ThreadCnt is", ThreadCnt)
	}

	WG.Wait()
	time.Sleep(2 * time.Second)
}
```



#### 20. 对象拷贝

```go
/*** slice ***/
src := []int{1, 2, 3, 4, 5}
dst := make([]int, 5)
copy(dst, src) // 深拷贝

dst := src[:] // 浅拷贝

/*** map ***/
// 1. json转换 
jsonStr, _ := json.Marshal(src)
var dst map[string]int
json.Unmarshal(jsonStr, &dst)

// 2. for-range
func DeepCopy(o interface{}) interface{} {
	if m, ok := o.(map[string]interface{}); ok {
		newMap := make(map[string]interface{})
		for k, v := range m {
			newMap[k] = DeepCopy(v)
		}
		return newMap
	} else if s, ok := o.([]interface{}); ok {
		newSlice := make([]interface{}, len(s))
		for i, v := range s {
			newSlice[i] = DeepCopy(v)
		}
		return newSlice
	}

	return o
}
```



#### 21. map 数据结构

map底层是一个散列表，有两部分组成：

- hmap (header): 包含多个字段，最重要的字段为 buckets 数组指针， 类型unsafe.Pointer
- bmap (bucket): 存储key和value的数组

Golang 把求得的哈希值按照用途一分为二：高位和低位。低位用于寻找当前key属于哪个hmap的那个bucket，高位用于寻找bucket中哪个key

map中的key和value值都存到同一个数组中，这样做的好处是，在key和value的长度不同时，可以消除padding带来的空间浪费

map扩容：当map的长度增长到大于加载因子所需要的map长度时，将会产生一个新的bucket数组，然后把旧的bucket数组迁移到一个属性字段oldbucket中。注意不会立即迁移，只有当访问到具体某个bucket时，才可能发生转移



![hashmap](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/hmap-and-buckets.png)



#### 22. 方法集合指针接收者和值接收者

| Method Receiver | Value        |
| --------------- | ------------ |
| (t T)           | T & T*       |
| (t *T)          | *T & T(新版) |

统一规则：接收者不在意传入的参数到底是对象或指针，只在意方法接收者定义的参数，如果是指针，不管传入指针或者对象，都能修改对象

```go
func main() {
	e1 := T{"jackson"}
	e1.foo()
	fmt.Println(e1.name) // 未改变

	e1.bar()
	fmt.Println(e1.name) // 改变

	e2 := &T{"sara"}
	e2.foo()
	fmt.Println(e2.name) // 未改变

	e2.bar()
	fmt.Println(e2.name) // 改变
}

type T struct {
	name string
}

func (e T) foo() {
	e.name += " abc"
}

func (e *T) bar() {
	e.name += " xyz"
}
```



#### 23. sync 包

sync.Once: 只运行一次

```
func main() {
   var once sync.Once
   done := make(chan bool)

   for i := 0; i < 5; i++ {
      go func() {
         once.Do(func() {
            fmt.Println(i)
         })

         time.Sleep(time.Second)
         done <- true
      }()
   }

   for i := 0; i < 5; i++ {
      <-done
   }
}
```

sync.Pool: 保存和复用临时对象，以减少内存分配，降低GC压力

> 获取对象过程：
>
> 1. 固定到某个P，尝试从私有对象获取，如果私有对象非空则返回该对象，并将私有对象清掉
> 2. 如果私有对象为空，就去当前子池的共享列表中获取(需要加锁)
> 3. 如果当前子池列表也为空，就尝试去其他P的子池的共享列表偷一个(需要加锁)
> 4. 如果其他子池都是空的，直接返回用户指定的New 函数对象

```go
// GC 回收
func main() {
	p := &sync.Pool{
		New: func() interface{} {
			return 0
		},
	}

	a := p.Get().(int)
	p.Put(1)
	runtime.GC() // 缓存对象可能被删除

	b := p.Get().(int)
	fmt.Println(a, b)
}
```

```go
func main() {
	bufferPool := &sync.Pool{
		New: func() interface{} {
			return new(bytes.Buffer)
		},
	}

	// 获取缓冲区，存储字节序列
	buf := bufferPool.Get().(*bytes.Buffer)

	var a uint32 = 121
	var b uint32 = 3434

	// 将数据转为字节序列
	err := binary.Write(buf, binary.LittleEndian, a)
	if err != nil {
		panic(err)
	}

	err = binary.Write(buf, binary.LittleEndian, b)
	if err != nil {
		panic(err)
	}

	// 拼接后的结果
	fmt.Printf("% x\n", buf.Bytes())

	// 缓冲使用完毕，必须重置并放回Pool中
	buf.Reset()
	bufferPool.Put(buf)
}
```



#### 24. nil

只有引用类型能够nil空值：interface, function, pointer, map, slice, channel

string的空值为“”，不能赋值nil





#### 26. Map 使用 （done)

##### 26.1 初始化赋值问题

值为复杂类型时，推荐使用指针

```go
// 不推荐, 值拷贝，无法直接修改Student的值
m := map[string]Student

// 推荐，地址拷贝
m := map[string]*Student
```

##### 26.2 遍历问题

```go
// 不推荐：采用range方式赋值
for _, stu := range stus {
  m[stu.Name] = &stu
}
// why?
// for-range 创建每个元素的副本，而不直接返回每个元素的引用

// 推荐：采用索引方式赋值
for i := 0; i < len(stus); i++ {
  m[stu.Name] = &stus[i]
}
```

```go
func main() {
	stus := []Student{
		{"Sam", 23},
		{"Jack", 41},
		{"Daniel", 34},
	}

	m := make(map[string]*Student)

	/*	for _, stu := range stus {
		// stu所占的地址，将指向最后一个元素的副本地址
		fmt.Printf("%p\n", &stu)
		m[stu.Name] = &stu
	}*/

	// 正确
	for i := 0; i < len(stus); i++ {
		m[stus[i].Name] = &stus[i]
	}

	for k, v := range m {
    fmt.Println(k, "=>", v)
	}
}
```



#### 27. len函数和移位问题

```go
//const s = "Go101.org" // 4 0
//var s = "Go101.org" // 0 0
var s = [9]byte{'G', 'o', '1', '0', '1', '.', 'o', 'r', 'g'} // 4 0

var a byte = 1 << len(s) / 128
var b byte = 1 << len(s[:]) / 128

func main() {
	fmt.Println(a, b)
}
```

len函数：

> For some arguments, such as a string literal or a simple array expression, the result can be constant.
>
> ```go
> const s = "Go101.org"
> len(s)    // const
> len(s[:]) // var
> 
> var s = "Go101.org"
> len(s)    // var
> len(s[:]) // var
> 
> var s = [9]byte{'G', 'o', '1', '0', '1', '.', 'o', 'r', 'g'}
> len(s)    // const
> len(s[:]) // var
> ```
>
> 

位移操作：

> The right operand in a shift expression must have integer type or be an untyped constant representable by a value of type uint.
>
> If the left operand of a non-constant shift expression is an untyped const, it is first implicity converted to the type it would assume if the shift expression were replaced by it's left operand alone.
>
> `var a byte = 1 << len(s) / 128`: `1 << len(s)`是常量表达式，它的结果为512，除以128，结果4
>
> `var b byte = 1 << len(s[:]) / 128` : `1 << len(s[:])`不是常量表达式，操作数1为无类型常量，会先将其转化为byte，然后再进行位移操作。byte类型的1，移位操作后，越界变成0，除以128，结果0 