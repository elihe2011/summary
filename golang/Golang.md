# 1. 基础部分

## 1.1 标准输入

### 1.1.1 `fmt`

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

### 1.1.2 `os`

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

### 1.1.3 `bufio`

读取一整行

```go
func main() {
	reader := bufio.NewReader(os.Stdin)
	s, _ := reader.ReadString('\n')
	fmt.Println(s)
}
```

## 1.2 命令行参数

### 1.2.1 `os.Args`

```go
func main() {
	for i, v := range os.Args {
		fmt.Printf("Args[%d]=%v\n", i, v)
	}
}
```

### 1.2.2 `flag`

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

## 1.3 defer

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
	fmt.Println(demo1())
	fmt.Println(demo2())
	fmt.Println(demo3())
}
```

## 1.4 队列满

```go
// 如果队列满了，直接丢弃
select {
    case ch <- 1:
    default:
}
```

## 1.5 反射

### 1.5.1 设置值

```go
// 不能直接设置
v := reflect.Value(x)
v.SetInt(10)  // panic: unaddressable

// 需要通过地址
v := reflect.Value(&x)
v.Elem().SetInt(10)
```

## 1.6 测试

```bash
go test .              # 所有单元测试用例
go test -run TestAdd   # 指定单元测试用例

go test -bench .
go test -bench BenchmarkAdd
```

## 1.7 delve 调试工具

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





# 2. 中缀表达式转后缀表达式

1. 从左至右扫描中缀表达式
2. 若读取到操作数，则判断该操作数类型，并将其加入后缀表达式中
3. 若读取到括号
   1. 左括号"("：将其直接存入运算符堆栈
   2. 右括号")"：将运算符栈中的运算符依次加到后缀表达式中，直到")"为止
4. 若读取到运算符
   1. 若运算符栈的栈顶为括号，直接入栈
   2. 若比运算符的栈顶的运算符优先级高，直接入栈
   3. 若比运算符的栈顶的运算符优先级低或相等，则先栈顶出栈并加到后缀表达式中，后再将当前运算符入栈

```go
type stack []interface{}

func (s *stack) len() int           { return len(*s) }
func (s *stack) empty() bool        { return s.len() == 0 }
func (s *stack) push(v interface{}) { *s = append(*s, v) }
func (s *stack) pop() interface{} {
	n := s.len()
	v := (*s)[n-1]
	*s = (*s)[:n-1]
	return v
}
func (s *stack) peek() interface{} {
	n := s.len()
	v := (*s)[n-1]
	return v
}

func transExpress(express string) []string {
	opStack := &stack{}
	var i int
	var postExpress []string

LOOP:
	for i < len(express) {
		ch := express[i]
		switch {
		case ch >= '0' && ch <= '9':
			var nums []byte
			for ; i < len(express); i++ {
				if express[i] < '0' || express[i] > '9' {
					break
				}
				nums = append(nums, express[i])
			}
			postExpress = append(postExpress, string(nums))
		case ch == '(':
			opStack.push(ch)
			i++
		case ch == ')':
			for !opStack.empty() {
				op := opStack.pop().(byte)
				if op == '(' {
					break
				}
				postExpress = append(postExpress, fmt.Sprintf("%c", op))
			}
			i++
		case ch == '+' || ch == '-' || ch == '*' || ch == '/':
			// 栈为空，直接入栈
			if opStack.empty() {
				opStack.push(ch)
				i++
				continue LOOP
			}

			top := opStack.peek().(byte)

			// 栈顶为括号，直接入栈
			if top == '(' || top == ')' {
				opStack.push(ch)
				i++
				continue LOOP
			}

			// 比栈顶运算符优先级低或相等
			if priority(ch) <= priority(top) {
				// 栈顶运算符出栈，并存入后缀表达式
				postExpress = append(postExpress, fmt.Sprintf("%c", opStack.pop().(byte)))

				// 当前操作符入栈
				opStack.push(ch)
				i++
				continue LOOP
			}

			// 比栈顶优先级高，先入栈
			opStack.push(ch)
			i++
		default:
			i++
		}
	}

	for !opStack.empty() {
		postExpress = append(postExpress, fmt.Sprintf("%c", opStack.pop().(byte)))
	}

	return postExpress
}

func priority(ch byte) int {
	switch ch {
	case '+', '-':
		return 1
	case '*', '/':
		return 2
	}
	return 0
}

func calc(postExpress []string) int {
	numStack := &stack{}
	for _, v := range postExpress {
		switch v {
		case "+", "-", "*", "/":
			a, b := numStack.pop().(string), numStack.pop().(string)
			n1, _ := strconv.Atoi(a)
			n2, _ := strconv.Atoi(b)
			var res int

			switch v {
			case "+":
				res = n2 + n1
			case "-":
				res = n2 - n1
			case "*":
				res = n2 * n1
			case "/":
				res = n2 / n1
			}

			numStack.push(fmt.Sprintf("%d", res))
		default:
			numStack.push(v)
			//fmt.Println(numStack)
		}
	}

	res, _ := strconv.Atoi(numStack.pop().(string))
	return res
}

func main() {
	express := "9 + (3 - 1) * 3 + 10 / 2"
	postExp := transExpress(express)
	fmt.Println(postExp)

	ans := calc(postExp)
	fmt.Println(ans)
}
```

# 3. 多线程

- 线程是由操作系统进程管理，也就是处于内核态
- 线程间进行切换，需要发生用户态到内核态的切换
- 当系统中运行大量线程，系统会变得非常慢
- 用户态的线程，支持大量线程创建。也叫协程 goroutine

多核控制：

`runtime.GOMAXPROCS(N)`:  设置使用CPU核数，默认全部

`runtime.NumCPU()`:  cpu逻辑核数

Goroutine原理：

- 一个操作系统线程对应用户态多个goroutine
- 同时使用多个操作系统线程
- 操作系统线程与goroutine的关系时多对多的

GPM:

M: 操作系统线程

G：用户态线程 goroutine

P：上下文对象

当goroutine阻塞时，会将goroutine等待队列脱离出来，创建一个新的线程，来处理被剥离的goroutine队列



工作池：

```go
type Job struct {
	Id     int
	Number int
}

type Result struct {
	job   *Job
	total int
}

func startWorkerPool(n int, jobChan chan *Job, resultChan chan *Result) {
	for i := 0; i < n; i++ {
		go Worker(jobChan, resultChan)
	}
}

func Worker(jobChan chan *Job, resultChan chan *Result) {
	for job := range jobChan {
		calc(job, resultChan)
	}
}

func calc(job *Job, resultChan chan *Result) {
	var total int

	number := job.Number
	for number != 0 {
		total += number % 10
		number /= 10
	}

	r := &Result{
		job:   job,
		total: total,
	}

	resultChan <- r
}

func printResult(resultChan chan *Result) {
	for result := range resultChan {
		fmt.Printf("job: %d, number: %d, total: %d\n", result.job.Id, result.job.Number, result.total)
	}
}

func main() {
	jobChan := make(chan *Job, 1000)
	resultChan := make(chan *Result, 1000)

	startWorkerPool(128, jobChan, resultChan)

	go printResult(resultChan)

	var id int
	for {
		number := rand.Int()
		job := &Job{
			Id:     id,
			Number: number,
		}
		jobChan <- job

		id++
		time.Sleep(time.Second)
	}
}
```

# 4. Web 服务器平滑升级

升级过程中：

1. 正在处理的请求怎么办?
   - 等待处理完成后再退出
   - Golang 1.8+ 支持
   - 即优雅的关闭
   - 另外一直方式，可使用sync.WaitGroup
2. 新进来的请求怎么办、
   - Fork一个子进程，继承父进程的监听socket
   - 子进程启动成功后，接收新的连接
   - 父进程停止接收新的连接，等已有的请求处理完毕，退出
   - 优雅的重启成功

子进程如何继承父进程的文件句柄？

- 通过`os.Cmd`对象中的ExtraFiles参数进程传递
- 文件句柄继承实例分析

web server 优雅重启？

- 使用go1.8+的Shutdown方法进行优雅关闭
- 使用socket继承实现，子进程接管父进程监听的socket

信号处理：

- 通过kill命令给正常运行的程序发送信号
- 不处理的话，程序会panic处理

# 5. 数据交换格式

- json
- xml
- msgpack：二进制json
- Protobuf：二进制，基于代码自动生成

Protobuf 开发流程：

- IDL编写
- 生成指定语言的代码
- 序列化和反序列化

```protobuf
enum EnumAllowingAlias {
	UNKNOWN = 0;
	STARTED = 1;
	RUNNING = 2;
}

// 结构体
message Person {
	int32 id = 1;
	string name = 2;
	repeated Phone phones = 3; // 数组
}
```

安装工具：

```txt
# 安装工具
https://github.com/protocolbuffers/protobuf/releases

# 安装插件
go get -u github.com/golang/protobuf/protoc-gen-go
```



编写IDL:

```protobuf
syntax = "proto3";

package address;

enum PhoneType {
  HOME = 0;
  WORK = 1;
}

message Phone {
  PhoneType type = 1;
  string number = 2;
}

message Person {
  int32 id = 1;
  string name = 2;
  repeated Phone phones = 3;
}

message ContactBook {
  repeated Person persons = 1;
}
```

生成go代码：

```bash
protoc --go_out=./address ./person.proto
```

使用pb.go文件结构：

```go
func main() {
	var contactBook address.ContactBook

	for i := 0; i < 100; i++ {
		person := &address.Person{
			Id:   int32(i),
			Name: fmt.Sprintf("Jack %d", i),
		}

		phone := &address.Phone{
			Type:   address.PhoneType_HOME,
			Number: fmt.Sprintf("%d", rand.Int()),
		}

		person.Phones = append(person.Phones, phone)

		contactBook.Persons = append(contactBook.Persons, person)
	}

	data, err := proto.Marshal(&contactBook)
	if err != nil {
		fmt.Printf("protoc.Marshal error: %v\n", err)
		return
	}

	err = ioutil.WriteFile("test.dat", data, 0644)
	if err != nil {
		fmt.Printf("ioutil.WriteFile error: %v\n", err)
		return
	}

	fmt.Println("Done")
}
```

# 6. 依赖管理

## 6.1 godep

```bash
go get github.com/tools/godep

执行命令：
godep save # 将程序所有依赖的第三方包存下来

目录Godeps: 保存第三方依赖包的版本信息
目录vendor: 保存所有依赖的第三方包

go build时，优先搜索vendor目录，相关包不存在后，才去GOPATH下查找
```

# 7. MySQL

```
go get -u github.com/go-sql-driver/mysql
事务的ACID：
原子性
一致性
隔离性
持久性

sqlx 库
go get github.com/jmoiron/sqlx
查询：sqlx.DB.Get & sqlx.DB.Select
更新、插入和删除：sqlx.DB.Exec
事务：sql.DB.Begin()/Commit()/Rollback()
```

# 8. nsq 消息队列

## 8.1 简介

- NSQ 是Go语言开发的，内存分布式消息队列中间件
- 可大规模地处理每天数以十亿计级别的消息
- 分布式和去中心化拓扑结构，无单点故障


## 8.2 NSQ 组件

- nsqd: 负责消息接收、保存及发送给消费者的进程
- nsqlookupd: 负责维护所有nsqd的状态，提供服务发现的进程
- nsqadmin：web管理平台，实时监控集群及执行各种管理任务

## 8.3 NSQ 特性

- 消息默认不持久化，可以配置成持久化
- 每条消息至少传递一次
- 消息不保证有序

## 8.4 安装

```bash
cat docker-compose.yml 
version: '3'
services:
  nsqlookupd:
    container_name: nsqlookupd
    image: nsqio/nsq
    command: /nsqlookupd
    ports:
      - "4160:4160"
      - "4161:4161"

  nsqd:
    container_name: nsqd
    image: nsqio/nsq
    command: /nsqd --lookupd-tcp-address=nsqlookupd:4160 --broadcast-address=192.168.31.200 # 设置为宿主机的IP，否则客户端无法访问
    depends_on:
      - nsqlookupd
    ports:
      - "4150:4150"
      - "4151:4151"

  nsqadmin:
    container_name: nsqadmin
    image: nsqio/nsq
    command: /nsqadmin --lookupd-http-address=nsqlookupd:4161
    depends_on:
      - nsqlookupd
    ports:
      - "4171:4171"
      
docker-compose up -d
docker-compose ps

curl http://localhost:4171
```

## 8.5 使用

```bash
go get github.com/nsqio/go-nsq
```



# 9. gin

## 9.1 简介

- 基于httprouter开发的web框架, 路由使用前缀树

```bash
go get github.com/gin-gonic/gin
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

### 10.1.2 结合单元测试

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



# 11. Cookie & Session

## 11.1 Cookie

Cookie机制：

- 浏览器发送请求的时候，自动带上cookie
- 服务器可设置cookie
- 只针对单个域名，不能跨域

Cookie与登录鉴权：

- 用户登录成功，设置一个cookie：username=jack
- 用户请求时，浏览器自动把cookie: username=jack
- 服务器收到请求后，解析cookie中的username，判断用户是否已登录
- 如果用户登录，鉴权成功；没有登录则重定向到注册页

Cookie的缺陷：

- 容易被伪造
- 猜到的用户名，只要用户名带到请求，就被攻破

改进方案：

- 将username生成一个唯一的 uuid
- 用户请求时，将这个uuid发到服务器
- 服务端通过查询这个uuid，反查是哪个用户

## 11.2 Session

Session机制：

- 在服务端生成的id以及保存id对应用户信息的机制，叫做session机制
- Session和Cookie共同构建了账号鉴权体系
- Cookie保存在客户端，session保存在服务端

- 服务端登录成功后，就分配一个无法伪造的sessionid，存储在用户的机器上，以后每次请求的时候，都带上这个sessionid，就可以达到鉴权的目的

## 11.3 Golang中的Cookie

```go
// 设置cookie
sessionId := userSession.Id()
cookie := &http.Cookie{
	Name:     CookieSessionId,
	Value:    sessionId,
	MaxAge:   CookieMaxAge,		
    HttpOnly: true,
	Path:     "/",
}
http.SetCookie(w, &cookie)

sessionid

// 读取cookie
cookie := http.Request.Cookie(key string)
cookies := http.Request.Cookies()


```

# 12. 全局唯一id生成器

Tweet Snowflake: https://github.com/twitter/snowflake

```
+--------------------------------------------------------------------------+
| 1 Bit Unused | 41 Bit Timestamp |  10 Bit NodeID  |   12 Bit Sequence ID |
+--------------------------------------------------------------------------+
```

- 41 Bit Timestamp: 当前时间戳(ms)

变种：https://github.com/sony/sonyflake



# 13. 敏感词过滤

方案：

- 正则匹配替换：正则性能较差，词库过大，性能低
- Trie树：字典树，又称单词查找树。它是哈希树的变种。（前缀数）

# 14. Etcd

Etcd: 高可用分布式key-value存储，可用于配置共享额服务发现

类似项目：zookeeper、consul

实现算法：基于raft算法的强一致性，高可用的服务存储目录

应用场景：

- 服务发现和服务注册
- 配置中心
- 分布式锁
- master选举

安装客户端：

```bash
go get go.etcd.io/etcd/client/v3
```



# 15. Kafka

应用场景：

- 异步处理，非关键流程异步化，提高系统的响应时间和健壮性
- 应用解耦，通过消息队列

- 流量削峰，流控和过载保护

#### 相关术语：

- Broker

  Kafka集群包含一个或多个服务器，这种服务器被称为broker

- Topic

  每条发布到Kafka集群的消息都有一个类别，这个类别被称为Topic。（物理上不同Topic的消息分开存储，逻辑上一个Topic的消息虽然保存于一个或多个broker上但用户只需指定消息的Topic即可生产或消费数据而不必关心数据存于何处）

- Partition

  Partition是物理上的概念，每个Topic包含一个或多个Partition.

- Producer

  负责发布消息到Kafka broker

- Consumer

  消息消费者，向Kafka broker读取消息的客户端。

- Consumer Group

  每个Consumer属于一个特定的Consumer Group（可为每个Consumer指定group name，若不指定group name则属于默认的group）。



# 16. Zookeeper

应用场景：

- 服务注册和服务发现
- 配置中心
- 分布式锁
  - Zookeeper的强一致性
  - 多个客户端同时在zk上创建相同的znode，只有一个创建成功

```bash
go get -v github.com/Shopify/sarama
```







# 15. ElasticSearch

```bash
go get -v github.com/olivere/elastic/v7
```





# xx. `GO111MODULE` 

- `GO111MODULE = auto` 默认模式，此种模式下，Go 会表现

  - 当您在 `GOPATH` 外部时， 设置为 `GO111MODULE = on`
  - 当您在 `GOPATH` 内部时，即使存在 `go.mod`, 设置为 `GO111MODULE = off`
- `GO111MODULE = on`, 即使在`GOPATH`内部，任然强制使用`go.mod`
- `GO111MODULE = off` 强制使用`GOPATH` 方式，即使在 `GOPATH` 之外。


