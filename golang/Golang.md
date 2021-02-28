# 1.  标准输入

## 1.1 `fmt`

`Scanf`: 空格作为分隔符，占位符与输入格式一样

`Scanln`: 空格作为分隔符, 换行符结束

`Scan`: 空格或换行符作为分隔符

`Sscanf`: 从字符串输入，空格做分隔符

`Fscanf`: 从文件输入

```go
var a int
var b string

// 不支持换行
fmt.Scanf("%d", &a)
fmt.Scanf("%s", &b)

// 同上
fmt.Scanln(&a, &b)

// 支持换行
fmt.Scanf("%d\n", &a)
fmt.Scanf("%s\n", &b)

// 同上
fmt.Scan(&a, &b)

s := "10 abc"
fmt.Sscanf(s, "%d %s", &a, &b)

s = "5\n\nxyz"
fmt.Sscan(s, &a, &b)

fmt.Fscanf(os.Stdin, "%d %s", &a, &b)
```

## 1.2 `os`

`File.Read(b []byte)`

`File.Write(b []byte)`

`File.WriteString(s string)`

```go
func main() {
	var buf [8]byte

	os.Stdin.Read(buf[:])

	//fmt.Printf("%s\n", buf)
    os.Stdout.Write(buf[:])
}
```

## 1.3 `bufio`

读取一整行

```go
func main() {
	reader := bufio.NewReader(os.Stdin)
	s, _ := reader.ReadString('\n')
	fmt.Println(s)
}
```



# 2. 命令行参数

## 2.1 `os.Args`

```go
func main() {
	for i, v := range os.Args {
		fmt.Printf("Args[%d]=%v\n", i, v)
	}
}
```

## 2.2 `flag`

```go
func main() {
	var local bool
	var schema string
	var port int

	flag.BoolVar(&local, "l", false, "whether local protocol")
	flag.StringVar(&schema, "s", "http", "schema")
	flag.IntVar(&port, "p", 80, "port")
	flag.Parse()

	fmt.Println(local, schema, port)
}
```



# 3. defer

`return`: `RETVAL=x` --> `RETURN`

`defer`:  `RETVAL=x` --> `defer` --> `RETURN`

```go
func demo1() int {
	x := 5
	defer func() {
		x += 1
	}()
	return x
}

func demo2() (x int) {
	defer func() {
		x += 1
	}()
	return 5
}

func demo3() (x int) {
	defer func(x int) {
		x += 1
	}(x)
	return 5
}

func main() {
	fmt.Println(demo1()) // 5
	fmt.Println(demo2()) // 6
	fmt.Println(demo3()) // 5
}
```



# 4. channel

## 4.1 队列满

```go
// 如果队列满了，直接丢弃
select {
    case ch <- 1:
    default:
}
```



# 5. 反射

## 5.1 设置值

```go
// 不能直接设置
v := reflect.Value(x)
v.SetInt(10)  // panic: unaddressable

// 需要通过地址
v := reflect.Value(&x)
v.Elem().SetInt(10)
```



# 6. 测试

## 6.1 `go test` 

```bash
go test .              # 所有单元测试用例
go test -run TestAdd   # 指定单元测试用例

go test -bench .
go test -bench BenchmarkAdd
```

## 6.2 delve 调试工具

追踪程序中的异常代码

```bash
go get github.com/go-delve/delve/cmd/dlv

dlv debug github.com/elihe2011/mytest
b main.main  打断点
c 运行
n 下一步
s 进入
p a 打印
r 重新启动进程

dlv attach 12601
b main.go:11

dlv debug ./main.go
b func1  # 进入 func1 函数
goroutines # 列出所有的协程
goroutine 16 # 切换线程
bt  # 打印堆栈
```



# 7. 包管理

## 7.1 godep

```bash
go get github.com/tools/godep

执行命令：
godep save # 将程序所有依赖的第三方包存下来

目录Godeps: 保存第三方依赖包的版本信息
目录vendor: 保存所有依赖的第三方包

go build时，优先搜索vendor目录，相关包不存在后，才去GOPATH下查找
```

## 7.2 `go mod`

```go
go mod edit -replace google.golang.org/grpc@v1.35.0=google.golang.org/grpc@v1.26.0
go mod tidy

go list -m all
go list -m -u all    // 可升级的

go clean -modcache  清除所有mod缓存
```

### 7.3 `GO111MODULE` 

- `GO111MODULE = auto` 默认模式，此种模式下，Go 会表现

  - 当您在 `GOPATH` 外部时， 设置为 `GO111MODULE = on`
  - 当您在 `GOPATH` 内部时，即使存在 `go.mod`, 设置为 `GO111MODULE = off`
- `GO111MODULE = on`, 即使在`GOPATH`内部，任然强制使用`go.mod`
- `GO111MODULE = off` 强制使用`GOPATH` 方式，即使在 `GOPATH` 之外。



# 8. 第三方库

```bash
# mysql
go get -u github.com/go-sql-driver/mysql

sqlx 库
go get github.com/jmoiron/sqlx
查询：sqlx.DB.Get & sqlx.DB.Select
更新、插入和删除：sqlx.DB.Exec
事务：sql.DB.Begin()/Commit()/Rollback()
```


# 10. 性能优化

常见性能优化手段：

- 尽可能减少HTTP的请求数，合并css和js及图片
- 使用CDN，实现就近访问
- 启用gzip压缩，降低网页传输的大小
- 优化后端api服务的性能



当pprof开启后，每隔一段时间(10ms)收集当前堆栈信息，获取各个函数占用的cpu以及内存资源；当pprof完成后，通过对这些采样数据进行分析；形成一个性能分析报告！



## 10.1 CPU

```go
import (
	"runtime/pprof"
)

pprof.StartCPUProfile(w io.Writer)
pprof.StopCPUProfile()
```

```go
func logicCode() {
	var c chan int
	for {
		select {
		case v := <-c:
			fmt.Printf("read from chan, v: %v\n", v)
		default:

		}
	}
}

func main() {
	var isCpuPprof bool
	flag.BoolVar(&isCpuPprof, "cpu", false, "turn cpu pprof on")
	flag.Parse()

	if isCpuPprof {
		file, err := os.Create("cpu.pprof")
		if err != nil {
			fmt.Printf("create cpu pprof failed, error: %v\n", err)
			return
		}
		pprof.StartCPUProfile(file)
		defer pprof.StopCPUProfile()
	}

	for i := 0; i < 10; i++ {
		go logicCode()
	}

	time.Sleep(30 * time.Second)
}
```

### 10.1.1 命令行

```bash
go tool pprof .\cpu.exe .\cpu.pprof

# topN: 列出cpu消耗前N的函数
(pprof) top3
Showing nodes accounting for 111.41s, 99.08% of 112.44s total
Dropped 42 nodes (cum <= 0.56s)
      flat  flat%   sum%        cum   cum%
    47.02s 41.82% 41.82%     87.85s 78.13%  runtime.selectnbrecv
    40.60s 36.11% 77.93%     40.68s 36.18%  runtime.chanrecv
    23.79s 21.16% 99.08%    111.88s 99.50%  main.logicCode

flat: cpu耗时 （最重要项）
flat%: cpu耗时占比
sum%: cpu耗时的累积占比
cum: 当前函数及调用者该的cpu耗时之和
cum%: cpu耗时总占比

(pprof) list main.logicCode
Total: 1.87mins
ROUTINE ======================== main.logicCode in C:\Users\Administrator\go\src\gitee.com\elihe\golearn\pprof\cpu\main.go
    23.79s   1.86mins (flat, cum) 99.50% of Total
         .          .     10:
         .          .     11:func logicCode() {
         .          .     12:   var c chan int
         .          .     13:   for {
         .          .     14:           select {
    23.79s   1.86mins     15:           case v := <-c:
         .          .     16:                   fmt.Printf("read from chan, v: %v\n", v)
         .          .     17:           default:
         .          .     18:
         .          .     19:           }
         .          .     20:   }
         
# 安装Graphviz工具，生成svg文件分析
(pprof) web
```

### 10.1.2 结合基准测试

```go
func BenchmarkLogicCode(b *testing.B) {
	for i := 0; i < b.N; i++ {
		logicCode()
	}
}
```

```bash
# 生成测试程序
go test -c .

.\cpu.test.exe --test.bench=BenchmarkLogicCode --test.cpuprofile=cpu.pprof2
```



## 10.2 Memory

```go
pprof.WriteHeapProfile(w io.Writer)
```

`go tool pprof`默认使用`--inuse_space`进行统计，可以使用`--inuse-objects`查看对象数量



## 10.3 火焰图

是一种性能分析图表，pprof数据可转化为火焰图

```bash
go tool pprof -http=":8081" .\cpu.exe .\cpu.pprof
```



## 10.4 Web服务 pprof

- 导入： `import _ "net/http/pprof"`
- 查看：`http://localhost:8080/debug/pprof"` (默认30s采样)
  - `/debug/pprof/profile`: cpu
  - `/debug/pprof/heap`: memory
  - `/debug/pprof/goroutines`: goroutine
  - `/debug/pprof/threadcrrate`: 系统线程

## 10.5 gin框架

```go
go get github.com/DeanThompson/ginpprof

import "github.com/DeanThompson/ginpprof"

func main() {
	router := gin.Default()

	router.GET("/ping", func(c *gin.Context) {
		c.String(200, "pong")
	})

	// automatically add routers for net/http/pprof
	// e.g. /debug/pprof, /debug/pprof/heap, etc.
	ginpprof.Wrap(router)

	// ginpprof also plays well with *gin.RouterGroup
	// group := router.Group("/debug/pprof")
	// ginpprof.WrapGroup(group)

	router.Run(":8080")
}
```



# 19. channel

## 19.1 对关闭的channel进行读写操作

- Read
  - buffer中有数据，能够读到数据，且`ok-idom`等于 true
  - buffer中无数据，读到的数据为channel类型的默认值，且`ok-idom`为 false
- Write： panic



# 20. nil == nil

注意点：

- 当 nil (硬编码的值)与对象比较时，nil 的类型和与它比较的对象声明的类型相同
- c 的类型是 interface{}，它的默认值是 nil

```go
func main() {
	var a *string = nil     // <*string, nil>
	var b interface{} = nil // <nil, nil>
	var c interface{} = a   // <*string, nil>

	fmt.Println(a == nil) // true (<*string, nil> == <*string, nil>)
	fmt.Println(b == nil) // true (<nil, nil> == <nil, nil>)
	fmt.Println(c == nil) // false (<*string, nil> == <nil, nil>)
	fmt.Println(a == b)   // false (<*string, nil> == <nil, nil>)
	fmt.Println(a == c)   // true (<*string, nil> == <*string, nil>)
}
```

