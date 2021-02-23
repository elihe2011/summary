#### 1. 可变类型低层结构

```go
type StringHeader struct {
  Data uintptr  // 指向底层字节数组
  Len int
}

func main() {
	s := "hello, world"

	a := len(s)
	b := (*reflect.StringHeader)(unsafe.Pointer(&s)).Len

	fmt.Println(a, b) // 12 12
}
```



```go
type SliceHeader struct {
  Data uintptr
  Len int
  Cap int
}

// 切片高效操作的要点是要降低内存分配的次数，尽量保证append操作不会超出cap的容量，降低触发内存分配的次数和每次分配内存大小。
func TrimSpace(s []byte) []byte {
	// r := s[:0] // 继承s的cap，有利于后续append操作不出现扩容
  r := make([]byte, 0, cap(s)) // 解决 r 和 s 共用底层数组问题
	for _, c := range s {
		if c != ' ' {
			r = append(r, c)
		}
	}
	return r
}

// 避免切片内存泄漏
func FindPhoneNumber(filename string) []byte {
	bs, _ := ioutil.ReadFile(filename)
	// 返回的切片，cap为文件读取时的大小，浪费资源
	return regexp.MustCompile("[0-9]+").Find(bs)
}

func FindPhoneNumberV2(filename string) []byte {
	bs, _ := ioutil.ReadFile(filename)
	bs = regexp.MustCompile("[0-9]+").Find(bs)
	return append([]byte{}, bs...)
}

// 切片类型强制转换
func SortFloat64FastV1(a []float64) {
	// 强制类型转化，先将切片数据的开始地址转换为一个较大的数组的指针，然后对数组指针对应的数组重新做切片操作
	var b []int = ((*[1 << 20]int)(unsafe.Pointer(&a[0])))[:len(a):cap(a)]

	// 排序
	sort.Ints(b)
}

func SortFloat64FastV2(a []float64) {
	var b []int
	aHeader := (*reflect.SliceHeader)(unsafe.Pointer(&a))
	bHeader := (*reflect.SliceHeader)(unsafe.Pointer(&b))

	*bHeader = *aHeader

	// 排序
	sort.Ints(b)
}
```



#### 2. 类型转换

基础类型，不支持隐式转换

接口类型，支持隐式转换

```go
var (
	a io.ReadCloser = (*os.File)(f) // 隐式转换，*io.File 满足 io.ReadCloser 接口
	b io.Reader     = a             // 隐式转换，io.ReadCloser 满足 io.Read 接口
	c io.Closer     = a             // 隐式转换，io.ReadCloser 满足 io.Closer 接口
	d io.Reader     = c.(io.Reader) // 显示转换，io.Closer 不满足 io.Reader 接口
)
```



#### 3. Goroutine

系统线程：会有一个大小固定的栈(2MB)，它用来保存函数递归调用时的参数和局部变量

Goroutine：以一个很小的栈启动(2K/4K)，当遇到深度递归调用导致栈空间不足时，会自动扩展栈（最大1G）

Go调度器：可以在n个系统线程上调度m个goroutine。调度器只关注单独的Go程序中的goroutine，goroutine采用的是半抢占式的协作调度，只有在当前Goroutine发生阻塞时才发生调度；同时发生在用户态，切换代价比系统线程低的多。`runtime.GOMAXPROC`变量，用于控制当前运行正常的非阻塞goroutine的系统线程数量



#### 4. 单例

```go
type singleton struct{}

var (
	instance    *singleton
	initialized uint32
	mu          sync.Mutex
)

func Instance() *singleton {
	if atomic.LoadUint32(&initialized) == 1 {
		return instance
	}

	mu.Lock()
	defer mu.Unlock()

	if instance == nil {
		defer atomic.StoreUint32(&initialized, 1)
		instance = &singleton{}
	}

	return instance
}
```



```go
type Once struct {
	m    sync.Mutex
	done uint32
}

func (o *Once) Do(f func()) {
	if atomic.LoadUint32(&o.done) == 1 {
		return
	}

	o.m.Lock()
	defer o.m.Unlock()

	if o.done == 0 {
		defer atomic.StoreUint32(&o.done, 1)
		f()
	}
}
```

```go
type singleton struct{}

var (
	instance *singleton
	once     sync.Once
)

func Instance() *singleton {
	once.Do(func() {
		instance = &singleton{}
	})

	return instance
}
```



#### 5. 配置文件

```go
func loadConfig() map[string]string {
	return make(map[string]string)
}

func requests() chan int {
	return make(chan int)
}

func main() {
	var config atomic.Value

	// 初始化配置信息
	config.Store(loadConfig())

	// 启动一个协程，刷新配置信息
	go func() {
		for {
			time.Sleep(3 * time.Second)
			config.Store(loadConfig())
		}
	}()

	// 工作线程读取配置信息
	for i := 0; i < 10; i++ {
		go func() {
			for r := range requests() {
				c := config.Load()
				// ...
			}
		}()
	}
}
```



#### 6. 程序初始化顺序

`main.main` --> `import pkg1` --> `pkg1.const` --> `pkg1.var`-->`pkg1.init()` --> `main.X`



#### 7. 订阅和发布

```go
type (
	subscriber chan interface{}
	topicFunc  func(v interface{}) bool
)

type Publisher struct {
	m           sync.RWMutex
	buffer      int                      // 订阅队列缓冲大小
	timeout     time.Duration            // 发布超时时间
	subscribers map[subscriber]topicFunc // 订阅者信息
}

func NewPublisher(timeout time.Duration, buffer int) *Publisher {
	return &Publisher{
		buffer:      buffer,
		timeout:     timeout,
		subscribers: make(map[subscriber]topicFunc),
	}
}

func (p *Publisher) Subscribe() chan interface{} {
	return p.SubscribeTopic(nil)
}

func (p *Publisher) SubscribeTopic(topic topicFunc) chan interface{} {
	ch := make(chan interface{}, p.buffer)
	p.m.Lock()
	defer p.m.Unlock()

	p.subscribers[ch] = topic
	return ch
}

func (p *Publisher) Evict(sub chan interface{}) {
	p.m.Lock()
	defer p.m.Unlock()

	delete(p.subscribers, sub)
	close(sub)
}

func (p *Publisher) Publish(v interface{}) {
	p.m.RLock()
	defer p.m.RUnlock()

	var wg sync.WaitGroup
	for sub, topic := range p.subscribers {
		wg.Add(1)
		go p.sendTopic(sub, topic, v, &wg)
	}

	wg.Wait()
}

func (p *Publisher) sendTopic(
	sub subscriber, topic topicFunc, v interface{}, wg *sync.WaitGroup) {
	defer wg.Done()
	if topic != nil && !topic(v) {
		return
	}

	select {
	case sub <- v:
	case <-time.After(p.timeout):
	}
}

func (p *Publisher) Close() {
	p.m.Lock()
	defer p.m.Unlock()

	for sub := range p.subscribers {
		delete(p.subscribers, sub)
		close(sub)
	}
}

func main() {
	p := NewPublisher(100*time.Millisecond, 10)
	defer p.Close()

	all := p.Subscribe()
	golang := p.SubscribeTopic(func(v interface{}) bool {
		if s, ok := v.(string); ok {
			return strings.Contains(s, "golang")
		}
		return false
	})

	p.Publish("hello, world")
	p.Publish("hello, golang")

	go func() {
		for msg := range all {
			fmt.Println("all:", msg)
		}
	}()

	go func() {
		for msg := range golang {
			fmt.Println("golang:", msg)
		}
	}()

	time.Sleep(3 * time.Second)
}
```



#### 8. 素数筛选

```go
func GenerateNatural(ctx context.Context) chan int {
	ch := make(chan int)
	go func() {
		for i := 2; ; i++ {
			select {
			case <-ctx.Done():
				return
			case ch <- i:
			}
		}
	}()

	return ch
}

func PrimeFilter(ctx context.Context, in <-chan int, prime int) chan int {
	out := make(chan int)

	go func() {
		for {
			if i := <-in; i%prime != 0 {
				select {
				case <-ctx.Done():
					return
				case out <- i:
				}
			}
		}
	}()

	return out
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	ch := GenerateNatural(ctx)
	for i := 0; i < 100; i++ {
		prime := <-ch
		fmt.Printf("%v: %v\n", i+1, prime)
		ch = PrimeFilter(ctx, ch, prime)
	}
}
```



简化版：

```go
func GenerateNatural() chan int {
	ch := make(chan int)
	go func() {
		for i := 2; ; i++ {
			ch <- i
		}
	}()

	return ch
}

func PrimeFilter(in <-chan int, prime int) chan int {
	out := make(chan int)

	go func() {
		for {
			i := <-in
			if i%prime != 0 {
				out <- i
			}
		}
	}()

	return out
}

func main() {
	ch := GenerateNatural()
	for i := 0; i < 5; i++ {
		prime := <-ch
		fmt.Printf("%d ", prime)
		ch = PrimeFilter(ch, prime)
	}

	fmt.Println()
}
```

