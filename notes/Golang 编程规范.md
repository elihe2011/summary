# 工程化要求

建议你在 IDE 中集成下述工具插件：

1. 提交代码时，必须使用 gofmt 工具格式化代码。注意，gofmt 不识别空行，因为 gofmt 不能理解空行的意义。
2. 提交代码前，必须使用 goimports 工具检查导入。
3. 提交代码时，必须使用 golint 工具检查代码规范。
4. 提交代码前，必须使用 go vet 工具静态分析代码实现。

# 编码规范

## 大小约定

- 单个文件长度尽量不超过 500 行。
- 单个函数长度尽量不超过 50 行。
- 单个函数圈复杂度尽量不超过 10，禁止超过 15。
- 单个函数中嵌套不超过 3 层。
- 单行注释尽量不超过 80 个字符。
- 单行语句尽量不超过 80 个字符。

当单行代码超过 80 个字符时，就要考虑分行。分行的规则是以参数为单位将从较长的参数开始换行，以此类推直到每行长度合适：

```go
So(z.ExtractTo( path.Join(os.TempDir(), "testdata/test2"), "dir/", "dir/bar", "readonly"), ShouldBeNil)

  
 
```

当单行声明语句超过 80 个字符时，就要考虑分行。分行的规则是将参数按类型分组，紧接着的声明语句的是一个空行，以便和函数体区别：

```go
// NewNode initializes and returns a new Node representation.
func NewNode( importPath, downloadUrl string, tp RevisionType, val string, isGetDeps bool) *Node { n := &Node{ Pkg: Pkg{ ImportPath: importPath, RootPath:   GetRootPath(importPath), Type: tp, Value: val, }, DownloadURL: downloadUrl, IsGetDeps:   isGetDeps, } n.InstallPath = path.Join(setting.InstallRepoPath, n.RootPath) + n.ValSuffix() return n
}

  
 
```

## 缩进、括号和空格约定

缩进、括号和空格都使用 gofmt 工具处理。

- 强制使用 tab 缩进。
- 强制左大括号不换行。
- 强制所有的运算符和操作数之间要留空格。

## 命名规范

- 所有命名遵循 “意图” 原则。

### 包、目录命名规范

- 包名和目录名保持一致。一个目录尽量维护一个包下的所有文件。
- 包名为全小写单词， 不使用复数，不使用下划线。
- 包名应该尽可能简短。

### 文件命名规范

文件名为全小写单词，使用 “_” 分词。Golang 通常具有以下几种代码文件类型：

- 业务代码文件
- 模型代码文件
- 测试代码文件
- 工具代码文件

### 标识符命名规范

- 短名优先，作用域越大命名越⻓且越有意义。

#### 变量、常量名

- 变量命名遵循驼峰法。
- 常量使用全大写单词，使用 “_” 分词。
- 首字母根据访问控制原则使用大写或者小写。
- 对于常规缩略语，一旦选择了大写或小写的风格，就应当在整份代码中保持这种风格，不要首字母大写和缩写两种风格混用。以 URL 为例，如果选择了缩写 URL 这种风格，则应在整份代码中保持。错误：UrlArray，正确：urlArray 或 URLArray。再以 ID 为例，如果选择了缩写 ID 这种风格，错误：appleId，正确：appleID。
- 对于只在本文件中有效的顶级变量、常量，应该使用 “_” 前缀，避免在同一个包中的其他文件中意外使用错误的值。例如：

```go
var (
  _defaultPort = 8080
  _defaultUser = "user"
)

  
 
```

- 若变量、常量为 bool 类型，则名称应以 Has、Is、Can 或 Allow 开头：

```go
var isExist bool
var hasConflict bool
var canManage bool
var allowGitHook bool

  
 
```

- 如果模块的功能较为复杂、常量名称容易混淆的情况下，为了更好地区分枚举类型，可以使用完整的前缀：

```go
type PullRequestStatus int
const ( PULL_REQUEST_STATUS_CONFLICT PullRequestStatus = iota PULL_REQUEST_STATUS_CHECKING PULL_REQUEST_STATUS_MERGEABLE
)

  
 
```

#### 函数、方法名

- 函数、方法（结构体或者接口下属的函数称为方法）命名规则： 动词 + 名词。
- 若函数、方法为判断类型（返回值主要为 bool 类型），则名称应以 Has、Is、Can 或 Allow 等判断性动词开头：

```go
func HasPrefix(name string, prefixes []string) bool { ... }
func IsEntry(name string, entries []string) bool { ... }
func CanManage(name string) bool { ... }
func AllowGitHook() bool { ... }

  
 
```

#### 结构体、接口名

- 结构体命名规则：名词或名词短语。
- 接口命名规则：以 ”er” 作为后缀，例如：Reader、Writer。接口实现的方法则去掉 “er”，例如：Read、Write。

```go
type Reader interface { Read(p []byte) (n int, err error)
}

// 多个函数接口
type WriteFlusher interface { Write([]byte) (int, error) Flush() error
}

  
 
```

## 空行、注释、文档规范

### 空行

- 空行需要体现代码逻辑的关联，所以空行不能随意，非常严重地影响可读性。
- 保持函数内部实现的组织粒度是相近的，用空行分隔。

### 注释与文档

Golang 的 go doc 工具可以根据注释生成代码文档，所以注释的质量决定了代码文档的质量。

#### 注释风格

- 统一使用中文注释，中西文之间严格使用空格分隔，严格使用中文标点符号。
- 注释应当是一个完整的句子，以句号结尾。
- 句子类型的注释首字母均需大写，短语类型的注释首字母需小写。
- 注释的单行长度不能超过 80 个字符。

#### 包注释

- 每个包都应该有一个包注释。包注释会首先出现在 go doc 网页上。包注释应该包含：
  - 包名，简介。
  - 创建者。
  - 创建时间。
- 对于 main 包，通常只有一行简短的注释用以说明包的用途，且以项目名称开头：

```go
// Gogs (Go Git Service) is a painless self-hosted Git Service.
package main

  
 
```

- 对于简单的非 main 包，也可用一行注释概括。
- 对于一个复杂项目的子包，一般情况下不需要包级别注释，除非是代表某个特定功能的模块。
- 对于相对功能复杂的非 main 包，一般都会增加一些使用示例或基本说明，且以 Package 开头：

```go
  /*
  Package regexp implements a simple library for regular expressions.
  The syntax of the regular expressions accepted is: regexp: concatenation { '|' concatenation } concatenation: { closure } closure: term [ '*' | '+' | '?' ] term: '^' '$' '.' character '[' [ '^' ] character-ranges ']' '(' regexp ')'
  */
  package regexp

  
 
```

- 对于特别复杂的包说明，一般使用 doc.go 文件用于编写包的描述，并提供与整个包相关的信息。

#### 函数、方法注释

每个函数、方法（结构体或者接口下属的函数称为方法）都应该有注释说明，包括三个方面（顺序严格）：

- 函数、方法名，简要说明。
- 参数列表，每行一个参数。
- 返回值，每行一个返回值。

```go
// NewtAttrModel，属性数据层操作类的工厂方法。
// 参数：
// 		ctx：上下文信息。
// 返回值：
// 		属性操作类指针。
func NewAttrModel(ctx *common.Context) *AttrModel {}

  
 
```

- 如果一句话不足以说明全部问题，则可换行继续进行更加细致的描述：

```go
// Copy copies file from source to target path.
// It returns false and error when error occurs in underlying function calls.

  
 
```

- 若函数或方法为判断类型（返回值主要为 bool 类型），则注释以 `<name> returns true if` 开头：

```go
// HasPrefix returns true if name has any string in given slice as prefix.
func HasPrefix(name string, prefixes []string) bool { ...

  
 
```

#### 结构体、接口注释

每个自定义的结构体、接口都应该有注释说明，放在实体定义的前一行，格式为：名称、说明。同时，结构体内的每个成员都要有说明，该说明放在成员变量的后面（注意对齐），例如：

```go
// User，用户实例，定义了用户的基础信息。
type User struct{ Username  string	// 用户名 Email string	// 邮箱
}

  
 
```

#### 其它说明

- 当某个部分等待完成时，用 `TODO(Your name):` 开头的注释来提醒维护人员。
- 当某个部分存在已知问题进行需要修复或改进时，用 `FIXME(Your name)`: 开头的注释来提醒维护人员。
- 当需要特别说明某个问题时，可用 `NOTE(You name):` 开头的注释。

## 导入规范

使用 goimports 工具，在保存文件时自动检查 import 规范。

- 如果使用的包没有导入，则自动导入；如果导入的包没有被使用，则自动删除。
- 强制使用分行导入，即便仅导入一个包。
- 导入多个包时注意按照类别顺序并使用空行区分：标准库包、程序内部包、第三方包。
- 禁止使用相对路径导入。
- 禁止使用 Import Dot（“.”） 简化导入。
- 在所有其他情况下，除非导入之间有直接冲突，否则应避免导入别名。

```go
import (
  "fmt"
  "os"
  "runtime/trace" nettrace "golang.net/x/trace"
)

  
 
```

- 如果包名与导入路径的最后一个元素不匹配，则必须使用导入别名。

```go
import (
  client "example.com/client-go"
  trace "example.com/trace/v2"
)

  
 
```

# 代码逻辑实现规范

## 变量、常量定义规范

- 函数内使用短变量声明（海象运算符 :=）。
- 函数外使用长变量声明（var 关键字），var 关键字一般用于包级别变量声明，或者函数内的零值情况。
- 变量、常量的分组声明一般需要按照功能来区分，而不是将所有类型都分在一组：

```go
const ( // Default section name. DEFAULT_SECTION = "DEFAULT" // Maximum allowed depth when recursively substituing variable names. _DEPTH_VALUES = 200
)

type ParseError int

const ( ERR_SECTION_NOT_FOUND ParseError = iota + 1 ERR_KEY_NOT_FOUND ERR_BLANK_SECTION_NAME ERR_COULD_NOT_PARSE
)

  
 
```

- 如果有可能，尽量缩小变量的作用范围。

```go
// Bad
err := ioutil.WriteFile(name, data, 0644)
if err != nil {
 return err
}
// Good
if err := ioutil.WriteFile(name, data, 0644); err != nil {
 return err
}

  
 
```

- 如果需要在 if 之外使用函数调用的结果，则不应尝试缩小变量的作用范围。

```go
data, err := ioutil.ReadFile(name)
if err != nil { return err
}

if err := cfg.Decode(data); err != nil {
  return err
}

fmt.Println(cfg)
return nil

  
 
```

- 如果是枚举常量，需要先创建相应类型：

```go
type Scheme string

const ( HTTP  Scheme = "http" HTTPS Scheme = "https"
)

  
 
```

- 自构建的枚举类型应该从 1 开始，除非从 0 开始是有意义的：

```go
// Bad
type Operation int

const (
  Add Operation = iota
  Subtract
  Multiply
)

// Good
type Operation int

const (
  Add Operation = iota + 1
  Subtract
  Multiply
)

  
 
```

## String 类型定义规范

- 声明 Printf-style String 时，将其设置为 const 常量，这有助于 go vet 对 String 类型实例执行静态分析。

```go
// Bad
msg := "unexpected values %v, %v\n"
fmt.Printf(msg, 1, 2)

// Good
const msg = "unexpected values %v, %v\n"
fmt.Printf(msg, 1, 2)

  
 
```

- 优先使用 strconv 而不是 fmt，将原语转换为字符串或从字符串转换时，strconv 速度比 fmt 快。

```go
// Bad
for i := 0; i < b.N; i++ {
  s := fmt.Sprint(rand.Int())
}

// Good
for i := 0; i < b.N; i++ {
  s := strconv.Itoa(rand.Int())
}

  
 
```

- 避免字符串到字节的转换，不要反复从固定字符串创建字节 Slice，执行一次性完成转换。

```go
// Bad
for i := 0; i < b.N; i++ {
  w.Write([]byte("Hello world"))
}

// Good
data := []byte("Hello world")
for i := 0; i < b.N; i++ {
  w.Write(data)
}

  
 
```

## Slice、Map 类型定义规范

- 尽可能指定容器的容量，以便为容器预先分配内存，向 make() 传入容量参数会在初始化时尝试调整 Slice、Map 类型实例的大小，这将减少在将元素添加到 Slice、Map 类型实例时的重新分配内存造成的损耗。
- 使用 make() 初始化 Map 类型变量，使得开发者可以很好的区分开 Map 类型实例的声明，或初始化。使用 make() 还可以方便地添加大小提示。

```go
var (
  // m1 读写安全。
  // m2 在写入时会 panic。
  m1 = make(map[T1]T2)
  m2 map[T1]T2
)

  
 
```

- 如果 Map 类型实例包含固定的元素列表，则使用 map literals（map 初始化列表）的方式进行初始化：

```go
// Bad
m := make(map[T1]T2, 3)
m[k1] = v1
m[k2] = v2
m[k3] = v3

// Good
m := map[T1]T2{
  k1: v1,
  k2: v2,
  k3: v3,
}

  
 
```

- 在追加 Slice 类型变量时优先指定切片容量，在初始化要追加的切片时为 make() 提供一个容量值。

```go
for n := 0; n < b.N; n++ {
	data := make([]int, 0, size)
	for k := 0; k < size; k++{
		data = append(data, k)
	}
}

  
 
```

- Map 或 Slice 类型实例是引用类型，所以在函数调用传递时，要注意在函数内外保证实例数据的安全性，除非你知道自己在做什么。这是一个深拷贝和浅拷贝的问题。

```go
// Bad
func (d *Driver) SetTrips(trips []Trip) {
	d.trips = trips
}

trips := ...
d1.SetTrips(trips)

// 你是要修改 d1.trips 吗？
trips[0] = ...
// Good
func (d *Driver) SetTrips(trips []Trip) {
  d.trips = make([]Trip, len(trips))
  copy(d.trips, trips)
}

trips := ...
d1.SetTrips(trips)

// 这里我们修改 trips[0]，但不会影响到 d1.trips。
trips[0] = ...

  
 
```

- 返回 Map 或 Slice 类型实例时，同样要注意用户对暴露了内部状态的实例的数值进行修改：

```go
// Bad
type Stats struct {
  mu sync.Mutex counters map[string]int
}

// Snapshot 返回当前状态。
func (s *Stats) Snapshot() map[string]int {
  s.mu.Lock()
  defer s.mu.Unlock() return s.counters
}

// snapshot 不再受互斥锁保护。
// 因此对 snapshot 的任何访问都将受到数据竞争的影响。
// 影响 stats.counters。·
snapshot := stats.Snapshot()

// Good
type Stats struct {
  mu sync.Mutex counters map[string]int
}

func (s *Stats) Snapshot() map[string]int {
  s.mu.Lock()
  defer s.mu.Unlock() result := make(map[string]int, len(s.counters))
  for k, v := range s.counters { result[k] = v
  }
  return result
}

// snapshot 现在是一个拷贝
snapshot := stats.Snapshot()

  
 
```

## 结构体定义规范

- 嵌入结构体中作为成员的结构体，应位于结构体内的成员列表的顶部，并且必须有一个空行将嵌入式成员与常规成员分隔开。
- 在初始化 Struct 类型的指针实例时，使用 `&T{}` 代替 `new(T)`，使其与初始化 Struct 类型实例一致。

```go
sval := T{Name: "foo"}
sptr := &T{Name: "bar"}

  
 
```

## 接口定义规范

- 特别的，如果希望通过接口的方法修改接口实例的实际数据，则必须传递接口实例的指针（将实例指针赋值给接口变量），因为指针指向真正的内存数据：

```go
type F interface {
  f()
}

type S1 struct{}

func (s S1) f() {}

type S2 struct{}

func (s *S2) f() {}

// f1.f() 无法修改底层数据。
// f2.f() 可以修改底层数据，给接口变量 f2 赋值时使用的是实例指针。
var f1 F := S1{}
var f2 F := &S2{}

  
 
```

## 函数、方法定义规范

- 函数、方法的参数排列顺序遵循以下几点原则（从左到右）：

1. 参数的重要程度与逻辑顺序。
2. 简单类型优先于复杂类型。
3. 尽可能将同种类型的参数放在相邻位置，则只需写一次类型。

- 函数、方法的顺序一般需要按照依赖关系由浅入深由上至下排序，即最底层的函数出现在最前面。例如，函数 ExecCmdDirBytes 属于最底层的函数，它被 ExecCmdDir 函数调用，而 ExecCmdDir 又被 ExecCmd 调用。
- 避免实参传递时的语义不明确（Avoid Naked Parameters），当参数名称的含义不明显时，使用块注释语法：

```go
func printInfo(name string, isLocal, done bool)

// Bad
printInfo("foo", true, true)

// Good
printInfo("foo", true /* isLocal */, true /* done */)

  
 
```

- 上述例子中，更好的做法是将 bool 类型换成自定义类型。将来，该参数可以支持不仅仅是两个状态（true/false）：

```go
func printInfo(name string, isLocal, done bool)

type Region int

const (
  UnknownRegion Region = iota
  Local
)
type Status int

const (
  StatusReady Status= iota + 1
  StatusDone
  // Maybe we will have a StatusInProgress in the future.
)

func printInfo(name string, region Region, status Status)

  
 
```

- 避免使用 init() 函数，否则 init() 中的代码应该保证：
  - 函数定义的内容不对环境或调用方式有任何依赖，具有完全确定性。
  - 避免依赖于其他init()函数的顺序或副作用。虽然顺序是明确的，但代码可以更改， 因此 init() 函数之间的关系可能会使代码变得脆弱和容易出错。
  - 避免访问或操作全局或环境状态，如：机器信息、环境变量、工作目录、程序参数/输入等。
  - 避免 I/O 操作，包括：文件系统、网络和系统调用。

不能满足上述要求的代码应该被定义在 main 中（或程序生命周期中的其他地方）。

### Named Result Parameters

给函数返回值命名。尤其对于当你需要在函数结束的 defer 中对返回值做一些事情，返回值名字是必要的。

```go
// 错误
func (n *Node) Parent1() *Node
func (n *Node) Parent2() (*Node, error)

// 正确
func (n *Node) Parent1() (node *Node)
func (n *Node) Parent2() (node *Node, err error)

  
 
```

### Receiver Names

结构体方法中，接受者的命名（Receiver Names）不应该采用 me，this，self 等通用的名字，而应该采用简短的（1 或 2 个字符）并且能反映出结构体名的命名风格，它不必像参数命名那么具体，因为我们几乎不关心接受者的名字。

例如：Struct Client，接受者可以命名为 c 或者 cl。这样做的好处是，当生成了 go doc 后，过长或者过于具体的命名，会影响搜索体验。

### Receiver Type

编写结构体方法时，接受者的类型（Receiver Type）到底是选择值还是指针通常难以决定。一条万能的建议：如果你不知道要使用哪种传递时，请选择指针传递吧！

建议：

- 当接受者是 map、chan、func，不要使用指针传递，因为它们本身就是引用类型。
- 当接受者是 slice，而函数内部不会对 slice 进行切片或者重新分配空间，不要使用指针传递。
- 当函数内部需要修改接受者，必须使用指针传递。
- 当接受者是一个 struct，并且包含了 sync.Mutex 或者类似的用于同步的成员。必须使用指针传递，避免成员拷贝。
- 当接受者类型是一个 struct 并且很庞大，或者是一个大的 array，建议使用指针传递来提高性能。
- 当接受者是 struct、array、slice，并且其中的元素是指针，并且函数内部可能修改这些元素，那么使用指针传递是个。
- 不错的选择，这能使得函数的语义更加明确。
- 当接受者是小型 struct，小 array，并且不需要修改里面的元素，里面的元素又是一些基础类型，使用值传递是个不错的选择。

## 错误处理规范

- err 总是作为函数返回值列表的最后一个。
- 如果一个函数 return error，一定要检查它是否为空，判断函数调用是否成功。如果不为空，说明发生了错误，一定要处理它。
- 不能使用 _ 丢弃任何 return 的 err。若不进行错误处理，要么再次向上游 return err，或者使用 log 记录下来。
- 尽早 return err，函数中优先进行 return 检测，遇见错误则马上 return err。
- 错误提示（Error Strings）不需要大写字母开头的单词，即使是句子的首字母也不需要。除非那是个专有名词或者缩写。同时，错误提示也不需要以句号结尾，因为通常在打印完错误提示后还需要跟随别的提示信息。
- 采用独立的错误流进行处理。尽可能减少正常逻辑代码的缩进，这有利于提高代码的可读性，便于快速分辨出哪些还是正常逻辑代码，例如：

```go
// 错误写法
if err != nil { // error handling
} else { // normal code
}

// 正确写法
if err != nil { // error handling return // or continue, etc.
}
// normal code

  
 
```

另一种常见的情况，如果我们需要用函数的返回值来初始化某个变量，应该把这个函数调用单独写在一行，例如：

```go
// 错误写法
if x, err := f(); err != nil { // error handling return
} else { // use x
}

// 正确写法
x, err := f()
if err != nil { // error handling return
}
// use x

  
 
```

- 尽量不要使用 panic，除非你知道你在做什么。只有当实在不可运行的情况下采用 panic，例如：文件无法打开，数据库无法连接导致程序无法正常运行。但是对于可导出的接口不能有 panic，不要抛出 panic 只能在包内采用。建议使用 log.Fatal 来记录错误，这样就可以由 log 来结束程序。

## 单元测试规范

- 单元测试都必须使用 GoConvey 编写，且覆盖率必须在 80% 以上。
- 业务代码文件和单元测试文件放在同一目录下。
- 单元测试文件名以 *_test.go 为后缀，例如：example_test.go。
- 测试用例的函数名称必须以 Test 开头，例如：Test_Logger。
- 如果为结构体的方法编写测试用例，则需要以 `Text_<Struct>_<Method>` 的形式命名，例如：Test_Macaron_Run。
- 每个重要的函数都要同步编写测试用例。
- 测试用例和业务代码同步提交，方便进行回归测试。
- 在测试中，我们很可能会使用 Import Dot（“.”）这个特性，可以我们避免循环引用问题，除此之外都不要使用 . 进行简易导入。例如：

```go
package foo_test

import ( "bar/testutil" // also imports "foo" . "foo"
)

  
 
```

以上例子，该测试文件不能定义在于 foo 包里面，因为它 import bar/testutil，而 bar/testutil 有 import 了 foo，这将构成循环引用。所以我们需要将该测试文件定义在 foo_test 包中。并且使用 import . “foo” 后，该测试文件内代码能直接调用 foo 里面的函数而不需要显式地写上包名。