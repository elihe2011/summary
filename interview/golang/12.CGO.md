# 1. 简介

**CGO 是 C 语言和 Go 语言之间的桥梁，原则上无法直接支持 C++ 的类**。CGO 不支持 C++ 语法的根本原因是 C++ 至今为止还没有一个二进制接口规范(ABI)。CGO 只支持C语言中值类型的数据类型，所以我们是无法直接使用 C++ 的引用参数等特性的。



**CGO 支持**：

- Go 调用 C 语言函数，支持调用C代码模块，静态库和动态库
- Go 导出 C 语言动态库给其他语言使用



开启 CGO 特性：

- 安装C/C++构建工具链，GCC (Linux/MacOS)，MinGW (Windows)

- 环境变量`CGO_ENABLED=1`，本地构建时默认开启，但交叉构建时，需手动开启

- 导入 C 语言支持包 `import "C"`



# 2. Go 调用 C 语言

windows: https://jmeubank.github.io/tdm-gcc/

## 2.1 标准库函数

```go
//#include <stdio.h>
import "C"

func main() {
	C.puts(C.CString("hello cgo"))
}
```



## 2.2 自定义函数

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
	C.SayHello(C.CString("Hello World!"))
}
```



## 2.3 使用头文件

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
	C.SayHello(C.CString("Hello World!"))
}
```



# 3. C 语言调用 Go

```go
package main

import "C"

//export add
func add(x, y C.int) C.int {
	return x + y
}
```

```c
#include "hello.h"
#include <stdio.h>

int main() {
    printf("%d\n", add(2, 1));
    return 0;
}
```

生成 C 语言编译文件：

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
go build -buildmode=c-archive -o hello.a main.go
ls -l hello.*
hello.a
hello.h

# 编译c文件
gcc main.c hello.o -o main
```



# 4. 汇编

```bash
# 生成汇编
go tool compile -S main.go

# 同上
go build -gcflags -S main.go

```



# 5. 设置编译参数

`#cgo`语句：用于设置编译阶段和链接阶段的相关参数

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



# 6. build tag 条件编译

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
