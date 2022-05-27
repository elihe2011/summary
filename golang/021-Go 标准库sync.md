# 1. `sync.Once`

**只运行一次**

```go
func main() {
   var once sync.Once
   done := make(chan bool)

   for i := 0; i < 5; i++ {
      go func() {
         once.Do(func() {
            fmt.Println(i)   // i 的值可能 [0-5]
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



# 2. `sync.Mutex`

互斥锁

```go
func (m *Mutex) Lock()
func (m *Mutex) Unlock()
```



# 3. `sync.RWMutex`

读写锁：写互斥，读共享

```go
func (rw *RWMutex) Lock()
func (rw *RWMutex) RLock()
func (rw *RWMutex) RUnlock()
func (rw *RWMutex) Unlock()
```



# 4. `sync.WaitGroup`

用于等待一组 goroutine 结束：

```go
func (wg *WaitGroup) Add(delta int)
func (wg *WaitGroup) Done()
func (wg *WaitGroup) Wait()
```



# 5. `sync.Cond`

**条件变量:**

```go
func NewCond(l Locker) *Cond
func (c *Cond) Broadcast()   // 唤醒所有等待 c 的 goroutine
func (c *Cond) Signal()      // 唤醒一个等待 c 的 goroutine
func (c *Cond) Wait()        // 释放 c.L, 挂起调用者的 goroutine
```

![hashmap](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/sync-cond.png)

```go
func main() {
	cond := sync.NewCond(new(sync.Mutex))
	num := 0

	// Consumer
	go func() {
		for {
			cond.L.Lock()
			for num == 0 {
				cond.Wait()
			}

			num--
			fmt.Printf("Consumer: %d\n", num)
			cond.Signal()
			cond.L.Unlock()
		}
	}()

	// Producer
	for {
		time.Sleep(time.Second)
		cond.L.Lock()
		for num == 3 {
			cond.Wait()
		}

		num++
		fmt.Printf("Producer: %d\n", num)
		cond.Signal()
		cond.L.Unlock()
	}
}
```



# 6. `sync.Pool` 

本质用途：增加 **临时对象** 的重用率，减少 GC 负担



## 6.1 使用 `sync.Pool`

1. 初始化 Pool 实例 New，声明 Pool 元素创建的方法

    ```go
    bufferPool := &sync.Pool {
    	New: func() interface{} {
        	println("Create new instance")
        	return struct{}{}
    	}
    }
    ```

2. 申请对象 Get

   `Get`方法返回 Pool 中已存在的对象，如果没有则先调用 `New` 方法来初始化一个对象。
   
   ```go
   buffer := bufferPool.Get()
   ```

3. 释放对象 Put

   使用对象后，调用Put方法将对象放回池子。但仅仅是把它放回池子，至于池中的对象什么时候真正释放，不受外部控制。

   ```go
   bufferPool.Put(buffer)
   ```



## 6.2 原理分析

1. 数据结构

```go
type Pool struct {
    // 用于检测 Pool 池是否被 copy，因为 Pool 不希望被 copy；
    // 有了这个字段之后，可用用 go vet 工具检测，在编译期间就发现问题；
    noCopy noCopy   
    
    // 数组结构，对应每个 P，数量和 P 的数量一致；
    local     unsafe.Pointer 
    localSize uintptr        

    // GC 到时，victim 和 victimSize 会分别接管 local 和 localSize；
    // victim 的目的是为了减少 GC 后冷启动导致的性能抖动，让分配对象更平滑；
    victim     unsafe.Pointer 
    victimSize uintptr      

    // 对象初始化构造方法，使用方定义
    New func() interface{}
}

// Pool.local 指向的数组元素类型
type poolLocal struct {
    poolLocalInternal

    // 把 poolLocal 填充至 128 字节对齐，避免 false sharing 引起的性能问题
    pad [128 - unsafe.Sizeof(poolLocalInternal{})%128]byte
}

// 管理 cache 的内部结构，跟每个 P 对应，操作无需加锁
type poolLocalInternal struct {
    // 每个 P 的私有，使用时无需加锁
    private interface{}
    // 双链表结构，用于挂接 cache 元素
    shared  poolChain
}

type poolChain struct {
    head *poolChainElt
    tail *poolChainElt
}

type poolChainElt struct {
    // 本质是个数组内存空间，管理成 ringbuffer 的模式；
    poolDequeue

    // 链表指针
    next, prev *poolChainElt
}

type poolDequeue struct {
    headTail uint64

    // vals is a ring buffer of interface{} values stored in this
    // dequeue. The size of this must be a power of 2.
    vals []eface
}
```



2. Get 操作，尝试的路径

   1) 当前 P 对应的 `local.private` 字段

   2) 当前 P 对应的 `local` 双向链表

   3) 其他 P对应的 `local` 列表

   4) victim cache 中的元素

   5) New 现场构造



3. GC 操作

   1) 每轮 GC 开始都会调用 `poolCleanup` 函数

   2) 使用两轮清理过程来抵抗波动，即 local cache 和 victim cache 配合



## 6.3 相关问题

1. 为什么用 Pool，而不是在运行时直接初始化对象？

   根本原因：Go 的内存释放由runtime来自动处理的，有 GC 过程。

   ```go
   var (
   	numCalcCreated int32
   	wg             sync.WaitGroup
   )
   
   func createBuffer() interface{} {
   	atomic.AddInt32(&numCalcCreated, 1)
   	buffer := make([]byte, 1024)
   	return &buffer
   }
   
   func main() {
   	bufferPool := &sync.Pool{
   		New: createBuffer,
   	}
   
   	// 多 goroutine 并发测试
   	numWorkers := 1024 * 1024
   	wg.Add(numWorkers)
   
   	for i := 0; i < numWorkers; i++ {
   		go func() {
   			defer wg.Done()
   
   			// 申请 buffer 实例
   			buffer := bufferPool.Get()
   			_ = buffer.(*[]byte)
   
   			// 释放 buffer 实例
   			defer bufferPool.Put(buffer)
   		}()
   	}
   
   	wg.Wait()
   	fmt.Printf("%d buffer objects were created.\n", numCalcCreated)
   }
   ```



2. `sync.Pool` 是并发安全的吗？

      它本身是并发安全的，但 **New 函数对象有可能被并发调用**，需要自己去保证该函数对象线程安全，比如使用原子操作等。

   

3. 为什么 `sync.Pool` 不适合像 socket 长连接或者数据库连接池？

   `sync.Pool`中的缓存元素，外部完全不可控：

   - Pool 池中的元素随时可能被释放掉，它完全取决于 runtime 内部机制
   - Get 获取元素对象，可能是刚创建的，也可能是之前创建好 cache 的，使用者无法区分
   - Pool 池中的元素个数你无法知道



4. 如果不先 `Pool.Get`申请对象，直接调用 Put 会怎么样？

   不会有任何异常，因为：

   - `Put(x interface{})`  接口没有对x类型做判断和断言
   - Pool 内部也没有对类型做断言，无法追究元素是否来自 Get 方法的返回



5. `Pool.Get` 出来的对象，为什么要 `Pool.Put` 放回 Pool 池，是为了不变成垃圾？

   `Pool.Get` 和 `Pool.Put` 通常要配套使用。但如果只 `Pool.Get` 而不 `Pool.Put` ，那么每次`Pool.Get`的时候，都要执行 New 函数，Pool 也将失去最本质的功能：**复用临时对象**



6. Pool 本身允许复制使用吗？

   不允许。Pool 结构中有一个字段`noCopy`明确限制不要 copy，但它只有在运行静态检查 `go vet` 时才能被检测出来




# 7. `sync.Map`

**线程安全map**

```go
func (m *Map) Delete(key interface{})
func (m *Map) Load(key interface{}) (value interface{}, ok bool)
func (m *Map) LoadAndDelete(key interface{}) (value interface{}, loaded bool)
func (m *Map) LoadOrStore(key, value interface{}) (actual interface{}, loaded bool)
func (m *Map) Range(f func(key, value interface{}) bool)
func (m *Map) Store(key, value interface{})
```


