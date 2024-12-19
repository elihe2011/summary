# 1. 不安全操作

在整个代码库 (code base，指构建一个软件系统所使用的全部代码) 中，要尽可能减少不安全代码的量。

在 Rust 中，不安全代码块用于避开编译器的保护策略。不安全代码块主要用于四件事：

- 解引用裸指针
- 通过 FFI 调用函数
- 调用不安全函数
- 内联汇编 (inline assembly)



## 1.2 原始指针

原始指针 (raw pointer，裸指针) `*` 和引用 `&T` 有类似的功能，但引用是安全的，因为借用检查器保证了它指向一个有效的数据。解引用一个裸指针只能通过不安全代码块执行

```rust
fn main() {
    let raw_p: *const u32 = &10;

    unsafe {
        assert_eq!(*raw_p, 10);
    }
}
```



## 1.3 调用不安全函数

一些函数可以声明为不安全的(unsafe)，这意味着在使用它时保证正确性不再是编译器的责任，而是程序员。

不安全函数`std::slice::from_raw_parts` 向它传入指向第一个元素的指针和长度参数，它会创建一个切片。

```rust
use std::slice;

fn main() {
    let vector = vec![1, 2, 3, 4];

    let pointer = vector.as_ptr();
    let length = vector.len();

    unsafe {
        let my_slice: &[u32] = slice::from_raw_parts(pointer, length);

        assert_eq!(vector.as_slice(), my_slice);
    }
}
```



# 2. FFI

## 2.1 调用C库

Rust 提供了到 C 语言库的外部语言函数接口 (Foreign Function Interface, FFI)。外部语言函数必须在一个 extern 代码块中，且该代码块要带有一个包含名称的 `#[link]` 属性。

在 Rust 中，通过外部函数接口（foreign function interface）可以直接调用C语言库

**Step 1**：Cargo.toml

```toml
...
build = "build.rs"

[dependencies]
libc = "0.2"

[build-dependencies]
cc = "1.0"
```



**Step 2**：build.rs

```rust
extern crate cc;

fn main() {
    cc::Build::new()
        .file("src/double.c")
        .compile("libdouble.a");
}
```



**Step 3**：src/double.c

```c
int double_input(int input) {
    return input * 2;
}
```



**Step 4**：src/main.rs

```rust
extern crate libc;
use libc::c_int;

extern {
    fn double_input(input: c_int) -> c_int;
}

fn main() {
    let input = 4;
    let output = unsafe{ double_input(input) };
    println!("{} * 2 = {}", input, output);
}

```



## 2.2 编译成C库

**Step 1**: Cargo.toml

增加：

```toml
[lib]
name = "fibonacci"
crate-type = ["dylib"]
```



**Step 2**: src/lib.rs

```rust
#[no_mangle]
pub extern fn fibonacci(n: i64) -> i64 {
    if n < 2 {
        return 1
    }

    return fibonacci(n-2) + fibonacci(n-1);
}
```



**Step 3**: src/main.py

```python
from ctypes import cdll
from sys import platform

if platform == 'darwin':
    prefix = 'lib'
    ext = 'dylib'
elif platform == 'win32':
    prefix = ''
    ext = 'dll'
else:
    prefix = 'lib'
    ext = 'so'

lib = cdll.LoadLibrary('target/debug/{}fibonacci.{}'.format(prefix, ext))
fibonacci = lib.fibonacci

num = 45
result = fibonacci(num)
print('fibonacci({}) = {}'.format(num, result))
```



**Step 4**: Makefile

```makefile
ifeq ($(shell uname),Darwin)
    EXT := dylib
else
    ifeq ($(OS),Windows_NT)
        EXT := dll
    else
        EXT := so
    endif
endif

all: target/debug/libfibonacci.$(EXT)
	python src/main.py

target/debug/libfibonacci.$(EXT): src/lib.rs Cargo.toml
	cargo build

clean:
	rm -rf target
```



执行测试：

```bash
> make all
cargo build
    Finished dev [unoptimized + debuginfo] target(s) in 0.00s
python src/main.py
fibonacci(45) = 1836311903
```



标准输入读取并转换：

```rust
// 读取
    io::stdin().read_line(&mut index).expect("Failed to read line.");

    // 转换为数字
    let index: usize = index.trim().parse().expect("Index entered was not a number.");
```



## 2.3 调用C函数

```rust
use std::fmt;
use std::fmt::{Formatter, write};

// 单精度复数
#[repr(C)]
#[derive(Clone, Copy)]
struct Complex {
    re: f32,
    im: f32,
}

impl fmt::Debug for Complex {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        if self.im < 0. {
            write!(f, "{}-{}i", self.re, -self.im)
        } else {
            write!(f, "{}+{}i", self.re, self.im)
        }
    }
}

// extern 代码块链接到 libm 库
#[link(name = "m")]
extern {
    fn csqrtf(z: Complex) -> Complex;

    fn ccosf(z: Complex) -> Complex;
}

fn cos(z: Complex) -> Complex {
    unsafe { ccosf(z) }
}

fn main() {
    // z = -1 +0i
    let z = Complex { re: -1., im: 0. };

    // 调用外部语言函数是不安全操作
    let z_sqrt = unsafe { csqrtf(z) };
    println!("the square root of {:?} is {:?}", z, z_sqrt);

    // 调用不安全操作的安全API封装
    println!("cos({:?}) = {:?}", z, cos(z));
}
```



























