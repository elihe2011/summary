CGO: 支持调用C语言函数；支持Go语言导出C动态库给其他语言使用

# 1. 入门

## 1.1 CGO 基础

使用CGO特性，需要安装C/C++构建工具链，MacOS/Linux安装GCC，Windows安装MinGW

CGO_ENABLED被设置为1，本地构建时默认开启，但交叉构建时，需手动开启

`import "C"`启用CGO特性

### 1.1.1 基于C标准库函数输出字符串

```go
//#include <stdio.h>
import "C"

func main() {
	C.puts(C.CString("hello cgo"))
}
```

### 1.1.2 使用自己的C函数

#### 1.1.2.1 混合编码

```go
/*
#include <stdio.h>

static void SayHello(const char* s) {
	puts(s);
}
*/
import "C"

func main() {
	C.SayHello(C.CString("hello world!"))
}
```

#### 1.1.2.2 独立C文件

```c
// hello.c
#include <stdio.h>

void SayHello(const char* s) {
    puts(s);
}
```

```go
// hello.go
package main

//void SayHello(const char* s);
import "C"

func main() {
	C.SayHello(C.CString("hello world!"))
}
```

```bash
go run .
```

#### 1.1.2.3 使用头文件

```c
// hello.h
void SayHello(const char* s);
```

```c
// hello.c
#include "hello.h"
#include <stdio.h>

void SayHello(const char* s) {
    puts(s);
}
```

```go
// hello.go
package main

//#include "hello.h"
import "C"

func main() {
	C.SayHello(C.CString("hello world!"))
}
```

### 1.1.3 用Go实现C函数

```go
// hello.go
package main

import "C"
import "fmt"

//export SayHello
func SayHello(s *C.char) {
	fmt.Println(C.GoString(s))
}
```

```go
package main

//#include "hello.h"
import "C"

func main() {
	C.SayHello(C.CString("hello world!"))
}
```

### 1.1.4 面向C接口的Go编程

```go
package main

// void SayHello(_GoString_ s);
import "C"
import "fmt"

func main() {
	C.SayHello("hello world!")
}

//export SayHello
func SayHello(s string) {
	fmt.Println(s)
}
```

## 1.2 `#cgo`语句

用于设置编译阶段和链接阶段的相关参数

```go
/*
#cgo windows CFLAGS: -FCGO_OS_WINDOWS=1
#cgo darwin CFLAGS: -FCGO_OS_DARWIN=1
#cgo linux CFLAGS: -FCGO_OS_LINUX=1

#if defined(CGO_OS_WINDOWS)
	const char* os = "windows";
#elif defined(CGO_OS_DARWIN)
	const char* os = "darwin";
#elif defined(CGO_OS_LINUX)
	const char* os = "linux";
#else
//#    error(unknown os)
	const char* os = "unkown";
#endif
*/
import "C"

func main() {
	print(C.GoString(C.os))
}
```

## 1.3 build tag 条件编译

只在设置了debug标识时才会构建

```go
// +build debug

package main

var buildMode = "debug"
```

使用命令构建：

```bash
go build --tags="debug"
go build --tags="window debug"
```

# 2. 函数调用

## 2.1 Go 调用 C 语言函数

```go
/*
#include <errno.h>

static int div(int a, int b) {
	if (b == 0) {
		errno = EINVAL;
		return 0;
	}
	return a / b;
}
*/
import "C"
import "fmt"

func main() {
	v1, err1 := C.div(3, 2)
	fmt.Println(v1, err1)

	v2, err2 := C.div(1, 0)
	fmt.Println(v2, err2)
}
```



## 2.2 C 调用 Go语言函数

```go
package main

import "C"

//export add
func add(a, b C.int) C.int {
	return a + b
}
```

```c
#include "sum.h"
#include <stdio.h>

int main() {
    printf("%d\n", add(2, 1));
    return 0;
}
```

生成`_cgo_export.h`, `_cgo_export.c`等文件

```bash
# 生成中间文件
go tool cgo main.go
ls -l _obj | awk '{print $NF}'
_cgo_.o
_cgo_export.c
_cgo_export.h
_cgo_flags
_cgo_gotypes.go
_cgo_main.c
main.cgo1.go
main.cgo2.c


# 生成静态文件和头文件
go build -buildmode=c-archive -o sum.a main.go
ls -l sum.*
sum.a
sum.h

# 编译c文件
gcc main.c sum.o -o main
```



# 3. 汇编

```bash
# 生成汇编
go tool compile -S main.go

# 同上
go build -gcflags -S main.go

```

