# 1. 知识点



## 1.1 概念



### 1.1.1 new & make

- `new(T)` 返回 T 的指针 `*T` 并指向 T 的零值。值类型 int, float, struct等

- `make(T)` 返回的初始化的 T。只能用于引用类型slice，map，channel。返回类型本身，而非指针

> new: 申请内存，但不会将内存初始化，只会将内存置零，返回一个指针
>
> make: 申请内存，返回已初始化的结构体零值
>
> ![new_and_make](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/new_and_make.jpg)

```go
func main() {
	a1 := new([]int)
	a2 := &[]int{}
	a3 := make([]int, 0)

	// &[] &[] [] false
	fmt.Println(a1, a2, a3, a1 == a2)

	fmt.Println(unsafe.Sizeof(a1)) // 8, 它是指针，默认大小为8
	fmt.Println(unsafe.Sizeof(a2)) // 8
	fmt.Println(unsafe.Sizeof(a3)) // 24，空切片，切片由指针、len、cap三部分组成
}
```



### 1.1.2 值类型和引用类型

- 值类型：
  - int, float, bool, string, array, struct等。
  - 变量直接存储，内存通常在栈中分配。
  - **栈: 存放生命周期较短的数据**

- 引用类型：
  - ptr, slice, map, channel, interface
  - 变量存储一个地址，该地址对应的空间才真正存储数据。内存分配到**堆**上
  - 当没有任何变量引用这个地址时，该地址对应的数据空间将成为垃圾，由GC回收
  - **堆：存放生命周期较长的数据**， 一个值类型，一般存储在栈区，但它如果在别的函数也用到，此时有可能放堆区，它要做**逃逸分析**



### 1.1.3 **指针：**

- `*T`：普通指针，用于传递地址，不能进行指针运算

- `unsafe.Pointor`: 通用指针类型。用于转换不同类型的指针，不能进行指针运算

- `uintptr`: 用于指针运算。



### 1.1.4 对象的String() 方法

在Golang中，类只要实现了String(),在执行format时，就会自动调用这个方法

```go
type People struct {
	Name string
}

func (p People) String() string {
	return fmt.Sprintf("%v", p)        // 无限递归调用，导致栈溢出
	//return fmt.Sprintf("%v", p.Name) // OK
}

func main() {
	p := &People{"Jackson"}
	fmt.Println(p) // 自动调用 p.String()
}
```



### 1.1.5 接口 (done)

- eface：空接口，不带方法 `var i interface{}`
- iface: 带方法的接口。



### 1.1.8 反射 (done)

两种：TypeOf, ValueOf

Type：

- Type： 真实类型，静态类型  (type T int, T)  t.Name()
- Kind：基础类型，底层类型 (int) t.Kind()

t.Elem(): 引用类型的基类型 （指针、数组、切片、字典、channel等）

**反射的三大定律**：

- 接口变量 => 反射对象
- 反射对象 => 接口变量
- 要修改 “反射对象” 其类型必须 可写



### 1.1.9 文件读写

```go
// 一次性文件读写
ioutil.ReadFile
ioutil.WriteFile

// 读文件
os.Open

// 写文件
os.Create
os.OpenFile

// 拷贝文件
io.Copy
io.CopyBuffer

// 带缓冲
bufio.NewReader
bufio.NewWriter

// 目录遍历
filepath.Walk
```



### 1.1.10 网络编程

```go
// 服务端
net.Listen()
listener.Accept()

// 客户端
net.Dail

// 连接
conn.Read()
conn.Write()
conn.Close()
```



### 1.1.12 rpc

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



### 1.1.13 init 函数

- 一个包中，可以包含多个init函数
- 程序编译时，先执行导入包的init函数，然后再执行本包的init函数



### 1.1.14 类型断言和强转

```go
type MyInt int

var i int = 1
var j MyInt = MyInt(i) // ok, golang/python语法
var k MyInt = (MyInt)i // error, Java语法

var m interface{} = 2
var n = m.(int) // ok

var x int32 = 1
var y int64 = x.(int64)  // error, 非interface{}，已确定类型的变量不允许使用类型断言
```



### 1.1.15 main 函数

- main函数不能带参数 
- main函数不能定义返回值
- main函数所在的包必须为main包
- main函数中可以使用flag包来获取和解析命令行参数



### 1.1.16 关于nil

可以赋值为nil的类型：(因为这些类型的零值为nil)

- ptr
- func
- interface
- map, slice, channel
- error (本质是interface)



### 1.1.17 方法接收者

| receiver | invoker | 是否可以改变原始对象 |
| -------- | ------- | -------------------- |
| 指针     | 指针    | Yes                  |
| 指针     | 值      | Yes                  |
| 值       | 指针    | No                   |
| 值       | 值      | No                   |

需要注意interface{}的调用

```go
func main() {
	var a Integer = 1
	var b Integer = 2

	var i interface{} = &a
	sum := i.(*Integer).Add(b)
	diff := i.(*Integer).Sub(b)
	fmt.Println(sum, diff)

	var j interface{} = a
	sum = j.(Integer).Add(b) // cannot take the address of j.(Integer), 因为j.(Integer)的类型为main.Integer, 无法自动转换成*Integer
	diff = j.(Integer).Sub(b)
	fmt.Println(sum, diff)

}

func (a *Integer) Add(b Integer) Integer {
	return *a + b
}

func (a Integer) Sub(b Integer) Integer {
	return a - b
}
```



### 1.1.18 gomock

关于GoMock，下面说法正确的是（AD）
A. GoMock可以对interface打桩
B. GoMock可以对类的成员函数打桩
C. GoMock可以对函数打桩
D. GoMock打桩后的依赖注入可以通过GoStub完成



### 1.1.19 接口相关概念

关于接口，下面说法正确的是（ACD）
A. 只要两个接口拥有相同的方法列表（次序不同不要紧），那么它们就是等价的，可以相互赋值
B. 如果接口A的方法列表是接口B的方法列表的子集，那么接口B可以赋值给接口A
C. 接口查询是否成功，要在运行期才能够确定
D. 接口赋值是否可行，要在运行期才能够确定

```go
type A interface {
	foo()
	bar()
}

type B interface {
	bar()
	foo()
}

type C interface {
	bar()
}

func main() {
	var a A
	var b B
	var c C

	fmt.Println(a == b) // true
	fmt.Println(a == c) // true
  fmt.Println(a == nil) // true

	a = b // ok
	a = c // error, same methods are missing
  c = a // ok
}
```





### 1.1.20 JSON 序列化

golang中大多数数据类型都可以转化为有效的JSON文本，下面几种类型除外（BCD）
A. 指针  **//可进行隐式转换，对指针取值，对所指对象进行序列化**
B. channel
C. complex
D. 函数

struct的序列化要注意：结构体在序列化时非导出变量（以小写字母开头的变量名）不会被encode，因此在decode时这些非导出变量的值为其类型的零值



### 1.1.21 go vendor

关于go vendor，下面说法正确的是（ABD）
A. 基本思路是将引用的外部包的源代码放在当前工程的vendor目录下面
B. 编译go代码会优先从vendor目录先寻找依赖包
C. 可以指定引用某个特定版本的外部包  **//无法引入外部包**
D. 有了vendor目录后，打包当前的工程代码到其他机器的$GOPATH/src下都可以通过编译



### 1.1.22 map & slice 初始化

```go
func main() {
	var s []int
	var m map[string]int

	s = make([]int, 10)
	m = make(map[string]int)

	// 必须先 make 初始化，否则无法赋值
	s[0] = 1
	m["one"] = 1

	// append 会自动初始化
	s = append(s, 1)

	fmt.Println(s, m)
}
```



### 1.1.23 channel特性

关于channel的特性，下面说法正确的是（ABCD）
A. 给一个 nil channel 发送数据，造成永远阻塞
B. 从一个 nil channel 接收数据，造成永远阻塞
C. 给一个已经关闭的 channel 发送数据，引起 panic
D. **从一个已经关闭的 channel 接收数据，如果缓冲区中为空，则返回一个零值**



### 1.1.24 cap函数

- array： 支持
- slice：支持
- map: cap不支持，len返回容量
- channel: cap 返回通道的buffer容量



### 1.1.25 slice扩容

- 切片容量小于1024，容量增1倍；大于等于1024，倍增1/4
- 扩容后，未超过原数组容量，那么切片的指针还指向原数组；超过原数组容量，将会开辟一块新内存，将原有值拷贝过来，不影响原数组



### 1.1.27 select

关于select机制，下面说法正确的是（ABC）
A. select机制用来处理异步IO问题
B. select机制最大的一条限制就是每个case语句里必须是一个IO操作
C. golang在语言级别支持select关键字
D. select关键字的用法与switch语句非常类似，~~后面要带判断条件~~

**select 就是监听 IO 操作，当 IO 操作发生时，触发相应的动作**



### 1.1.28 内存泄漏

关于内存泄露，下面说法正确的是（BD）
A. golang有自动垃圾回收，不存在内存泄露
B. golang中检测内存泄露主要依靠的是pprof包
C. 内存泄露可以在编译阶段发现
D. 应定期使用浏览器来查看系统的实时内存信息，及时发现内存泄露问题



### 1.1.28 defer 延迟处理问题 （done)

```go
type Slice []int

func NewSlice() Slice {
	return make(Slice, 0)
}

func (s *Slice) Add(elem int) *Slice {
	*s = append(*s, elem)
	fmt.Println(elem)
	return s
}

func main() {
	s := NewSlice()

	// defer 中最后一个表达式才会推入延迟处理栈中
	defer s.Add(1).Add(2)

	s.Add(3)
	fmt.Printf("s=%v\n", s) // s=[1,3]
}
```

defer & panic: 

- defer: 后进先出 
- panic: 需要等待defer结束后才会向上传递。出现panic时，先按照defer的后进先出顺序执行，最后才会执行panic

```go
func calc(index string, a, b int) int {
   ret := a + b
   fmt.Println(index, a, b, ret)
   return ret
}

func main() {
   a := 1
   b := 2

   defer calc("1", a, calc("10", a, b))
   a = 0

   defer calc("2", a, calc("20", a, b))
   b = 1
}

func dispart() {
   calc("10", 1, 2)      // 3
   defer calc("1", 1, 3) // 4
   
   calc("20", 0, 2)      // 2
   defer calc("2", 0, 2) // 2
}
```

defer和函数返回值：defer需要在函数结束前执行。 函数返回值名字会在函数起始处被初始化为对应类型的零值并且作用域为整个函数

```go
func main() {
	fmt.Println(DeferFunc1(1)) // 4
	fmt.Println(DeferFunc2(1)) // 1
	fmt.Println(DeferFunc3(1)) // 3
}

func DeferFunc1(i int) (t int) {
	t = i
	defer func() {
		t += 3
	}()

	return t
}

func DeferFunc2(i int) int {
	t := i
	defer func() {
		t += 3
	}()

	return t
}

func DeferFunc3(i int) (t int) {
	defer func() {
		t += i
	}()

	return 2
}
```

```go
// 1
func f1() (r int) {
  defer func() {
    r++
  }()
  return 0
}

// 5
func f2() (r int) {
  t := 5
  defer func() {
    t += 5
  }()
  return t
}

// 1
func f3() (r int) {
  defer func(r int) {
    r++
  }(r)
  return 1
}

// 7
func f4() (r int) {
	t := 5
	defer func() {
		r = t + 2
	}()
	return t
}
```





### 1.1.29 内置delete 函数，只能对map进行操作

### 1.1.30 CGO

CGO是调用C代码模块，静态库和动态库

CGO是C语言和Go语言之间的桥梁，原则上无法直接支持C++的类。CGO不支持C++语法的根本原因是C++至今为止还没有一个二进制接口规范(ABI)。CGO只支持C语言中值类型的数据类型，所以我们是无法直接使用C++的引用参数等特性的。



### 1.1.31 常量类型

对于常量定义zero(const zero = 0.0)，zero是浮点型常量（F）

**Go中的常量通常是无类型的。但可以参与一些“有类型”的计算。**

六种未明确类型的常量类型:

- 无类型的布尔型
- 无类型的整数
- 无类型的字符
- 无类型的浮点数
- 无类型的复数
- 无类型的字符串



### 1.1.32 包导入

- import 后面的最后一个元素是路径，不是包名
- 一般情况下，包名和路径名应该保持一致
- import时写路径名，引用时要写包名

```go
package bar

import "fmt"

func Print(s string) {
	fmt.Println(s)
}

/////////////////////
package main

import bar "gomod/foo"  // 路径名和包名不一致，必须使用别名

func main() {
	bar.Print("abc")
}
```



### 1.1.33 for-range （done)

**for range创建了每个元素的副本，而不是直接返回每个元素的引用，如果使用该值变量的地址作为指向每个元素的指针，就会导致错误**，在迭代时，**返回的变量是一个迭代过程中根据切片依次赋值的新变量，所以值的地址总是相同的**

```go
func main() {
	m := make(map[string]*Student)

	stus := []Student{
		{"jack", 12},
		{"sara", 14},
		{"joe", 10},
	}

	// 错误，全部执行 "joe"
	for _, stu := range stus {
		m[stu.Name] = &stu
	}

	// 正确，重新赋值
	for _, stu := range stus {
		tmp := stu
		m[stu.Name] = &tmp
	}

	// 正确
	for i := 0; i < len(stus); i++ {
		stu := stus[i]
		m[stu.Name] = &stu
	}

	for k, v := range m {
		fmt.Printf("%s => %v\n", k, v)
	}
}
```

```go
func main() {
	s := []int{1, 2, 3, 4}

	// 错误：副本操作，不影响源数据
	for _, v := range s {
		v++
	}
	fmt.Println(s)

	// 正确
	for i := 0; i < len(s); i++ {
		s[i]++
	}
	fmt.Println(s)
}
```

```go
// 不能在for-range中修改slice
func main() {
	s := []int{1, 2, 3, 4}

	// 错误：循环中s改变了，但无法改变range后的s，导致out of range
	for i, _ := range s {
		s = append(s[:i], s[i+1:]...)
	}

	fmt.Println(s)
}
```



### 1.1.34 append 函数

```go
func main() {
	var s []int

	s = make([]int, 0)
	s = append(s, 1, 2, 3)
	fmt.Println(s) // [1, 2, 3]

	s = make([]int, 2) // 初始化了[0, 0]
	s = append(s, 1, 2, 3)
	fmt.Println(s) // [0, 0, 1, 2, 3]
}
```



### 1.1.35 Go 方法集

golang的方法集仅仅影响接口实现和方法表达式转化，与通过实例或者指针调用方法无关。即不存在Java中的父类对象指向子类引用

```go
// Student 实现了 People interface 的方法 Speak
var p People = Student{} // 错误，编译不通过

// 检查是否实现了接口
var _ People = new(Student)    // 编译时检查
var _ People = (*Student)(nil) // 运行时检查
```



### 1.1.36 eface & iface

iface比eface 中间多了一层itab结构。 itab 存储_type信息和[]fun方法集，从上面的结构我们就可得出，因为data指向了nil 并不代表interface 是nil， 所以返回值并不为空，

```go
type People interface {
	Show()
}

type Student struct{}

func (s *Student) Show() {}

func test1() *Student {
	var stu *Student
	return stu
}

func test2() People {
	var stu *Student
	return stu
}

func main() {
	// 仅仅是一个未初始化的指针，即空指针
	if test1() == nil {
		fmt.Println("A") // OK
	} else {
		fmt.Println("B")
	}

	// 非空接口iface，数据对象为空指针，但它还包含方法集等信息，所以不为nil
	if test2() == nil {
		fmt.Println("C")
	} else {
		fmt.Println("D") // OK
	}
}
```

结论：

- 一个接口包括动态类型和动态值。
- 如果一个接口的动态类型和动态值都为空，则这个接口为空的。

```go
func check(o interface{}) {
	if o == nil {
		fmt.Println("empty-interface")
	} else {
		fmt.Println("non-empty-interface")
	}
}

func main() {
	var a *int

	check(a)

	if a == nil {
		fmt.Printf("%v\n", a)
	}
}

// Output:
// non-empty-interface
// <nil>
```

```go
func main() {
	var a interface{} = nil
	var b interface{} = (*int)(nil)

	fmt.Println(a == nil) // true
	fmt.Println(b == nil) // false
}
```



### 1.1.37 类型比较

1. struct

   - 即使定义一致的结构体(字段类型、顺序)均一致，因为是两种不同类型，无法比较
   - 匿名定义一致的简单结构体，可以比较
   - 匿名定义一致的复杂结构体，无法比较

   如果结构体中有不可比较的类型，如map，slice等，那么结构体也是无法比较的。结构体比较仅支持“==”操作

   复杂的比较，使用`reflect.DeepEqual(obj1, obj2)`

   ```go
   func main() {
   	// 1. 结构一致的结构体
   	type A struct{ x int }
   	type B struct{ x int }
   	s1 := A{11}
   	s2 := B{11}
   	//if s1 == s2 { // 编译错误
   	//	fmt.Println("s1 == s2")
   	//}
   	if reflect.DeepEqual(s1, s2) {
   		fmt.Println("s1 DeepEqual s2") // 依旧无法比较
   	}
   
   	// 2. 匿名结构体 （不含复杂类型）
   	s3 := struct {
   		x int
   	}{11}
   	s4 := struct {
   		x int
   	}{11}
   	if s3 == s4 { // OK
   		fmt.Println("s3 == s4")
   	}
   	if s3 == s1 || s3 == s2 { // OK
   		fmt.Println("s3 == s1 || s3 == s2")
   	}
   	if reflect.DeepEqual(s3, s4) {
   		fmt.Println("s3 DeepEqual s4") // OK
   	}
   
   	// 3. 匿名结构体 (含复杂类型)
   	s5 := struct {
   		m map[string]int
   	}{map[string]int{"ok": 0}}
   	s6 := struct {
   		m map[string]int
   	}{map[string]int{"ok": 0}}
   	//if s5 == s6 { // 编译错误
   	//	fmt.Println("s5 == s6")
   	//}
   	if reflect.DeepEqual(s5, s6) {
   		fmt.Println("s5 DeepEqual s6") // OK
   	}
   }
   ```

2. `if a==c, b==c; then a == b?`

```go
func main() {
	a := A{7}
	b := B{7}

	c := struct {
		x int
	}{7}

	fmt.Println(a == c) // true
	fmt.Println(b == c) // true
	//fmt.Println(a == b) // 无法比较
}
```





### 1.1.38 函数返回值类型

nil返回值：interface, function, ptr, map, slice, channel, error(本质是interface)

```
func GetValue(m map[string]int, k string) (int, bool) {
	if v, ok := m[k]; ok {
		return v, true
	}

	return nil, false // 错误
	return -1, false  // 正确
}
```

### 1.1.39 类型定义和别名

```go
func main() {
	type MyInt1 int   // 类型定义
	type MyInt2 = int // 类型别名

	var a int = 1
	var b MyInt1 = MyInt1(a) // 必须强转
	var c MyInt2 = a
	fmt.Println(a, b, c)
}
```

```go
type User struct{}
type User1 User
type User2 = User

func (User1) m1() {
	fmt.Println("User1.m1()")
}

func (User) m2() {
	fmt.Println("User.m2()")
}

func main() {
	u1 := User1{}
	u2 := User2{}

	u1.m1() // User1.m1()
	u2.m2() // User.m2()

	u3 := User(u1)
	u3.m2() // User.m2()
}
```

```go
type T struct{}
type T1 T
type T2 = T

func (T) m() {
	fmt.Println("T.m()")
}

type Demo struct {
	T
	T1
	T2
}

func main() {
	demo := Demo{}

	//demo.m() // ambiguous selector

	demo.T.m()
	T(demo.T1).m()
	demo.T2.m()
}
```



### 1.1.40 闭包

延迟求值:

```go
func test() []func() {
	var funcs []func()

	for i := 0; i < 2; i++ {
		x := i // re-assignment
		funcs = append(funcs, func() {
			//fmt.Printf("%p, %v\n", &i, i) // xxx, 2
			fmt.Printf("%p, %v\n", &x, x) // xxx, 0; yyy, 1
		})
	}

	return funcs
}
```

引用同一变量：

```go
func test(x int) (func(), func()) {
	return func() {
			fmt.Println(x)
			x += 10
		}, func() {
			fmt.Println(x) // x+10
		}
}
func main() {
	a, b := test(100)
	a() // 100
	b() // 110
}
```



### 1.1.41 panic

**panic仅有最后一个可以被revover捕获**
触发panic("panic")后顺序执行defer，但是defer中还有一个panic，所以覆盖了之前的panic("panic")

```go
func main() {
	defer func() {
		if err := recover(); err != nil {
			fmt.Println(err) // defer panic
		} else {
			fmt.Println("ok")
		}
	}()

	defer func() {
		panic("defer panic")
	}()

	panic("panic")
}
```

### 1.1.42 Go 语言并发机制 （done）

CSP并发模型：不同于传统的多线程通过共享内存来通信，CSP讲究的是“以通信的方式来共享内存”。用于描述两个独立的并发实体通过共享的通信channel进行通信的并发模型。CSP中，channel是第一类对象，它不关注发送消息的实体，而关注与发送消息时使用的channel。

channel被单独创建并且可以在进程之间传递，一个实体通过将消息发到channel中，然后又监听这个channel的实体处理，两个实体之间是匿名的，它实现了实体中间的解藕。

Goroutine是Golang并发的实体，它底层使用协程(coroutine)实现并发，coroutine是一种运行在用户态的用户线程，类似greenthread，coroutine具有如下特点：

- 用户空间，避免了内核态和用户态的切换导致的成本
- 可以由语言和框架层进行调度
- 更小的栈空间允许创建大量的实例



### 1.1.44 uint 减法运算

```go
func main() {
	var a, b uint8
	a = 10
	b = 12
	fmt.Println(a - b) // 254
	fmt.Println(a + b) // 22
	fmt.Println(b - a) // 2
}
```



### 1.1.45 空结构体 struct{}

用途：节约内存，`unsafe.Sizeof(struct{}{})`的值等于0

示例1: 模拟Set

```go
func main() {
	set := make(map[int]struct{})

	for _, value := range []int{3, 4, 1, 3, 5, 7, 5} {
		set[value] = struct{}{}
	}

	fmt.Println(set)
}
```

示例2: 不需要数据，只要方法

```go
type Lamp struct{}

func (Lamp) Off() {
	fmt.Println("Off")
}

func (Lamp) On() {
	fmt.Println("On")
}

func main() {
	// 未初始化，使用默认值
	var lamp Lamp
	lamp.On()
	lamp.Off()

	// 显示空值调用
	Lamp{}.On()
	Lamp{}.Off()
}
```



### 1.1.46 判断接口是否已实现

利用编译来判断Golang接口是否实现

```go
type Animal interface {
	eat()
}

type Dog struct{}

func (Dog) eat() {
	fmt.Println("dog eat")
}

type Cat struct{}

func (Cat) walk() {
	fmt.Println("cat walk")
}

func main() {
	// 编译时检查
	var _ Animal = new(Dog) // 编译通过，接口已实现
	var _ Animal = new(Cat) // 编译失败，接口未实现

	// 运行时检查
	var _ Animal = (*Dog)(nil)
	var _ Animal = (*Cat)(nil) 
}
```



## 1.2 技巧和方法

### 1.2.1 数值类型转换

```go
func main() {
	a, _ := strconv.ParseInt("6b", 16, 64)
	b := strconv.FormatInt(a, 8)
	fmt.Printf("a=%d, b=%s\n", a, b)

	c, _ := strconv.Atoi("15")
	d := strconv.Itoa(12)
	fmt.Printf("c=%d, d=%s\n", c, d)
}
```



### 1.2.2 浮点数计算精度

```go
func main() {
	a := 0.6
	b := 0.7

	c := a + b // 1.2999999999999998
	fmt.Println(c)

	d := truncate(c) // 1.3
	fmt.Println(d)
}

func truncate(n float64) float64 {
	s := fmt.Sprintf("%.8f", n) // 1.30000000
	m, _ := strconv.ParseFloat(s, 64)
	return m
}
```
