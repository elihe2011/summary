# 1. unsafe

几乎每个语言都有 `unsafe` 关键字，但 Rust 语言使用 `unsafe` 的原因可能与其它语言有所不同

- **过强的编译器**：因为 Rust 的静态检查太强，也很保守。这导致编译器在分析代码时，某些正确代码编译器无法分析出它的正确性，导致编译错误。**`unsafe` 可避免这类编译错误**。
- **特殊任务需要**：计算机底层的一些硬件就是不安全的，系统底层编程需要与操作系统甚至直接操作硬件，unsafe 是不可避免的



在 Rust 中，不安全代码块用于避开编译器的保护策略。unsafe 的使用场景：

- 解引用裸指针
- 调用不安全函数
- 通过 FFI 调用函数
- 访问或修改一个可变静态变量
- 实现一个 `unsafe` 特征
- 访问 `union` 中的字段
- 内联汇编 (inline assembly)



# 2. 解引用裸指针

裸指针(raw pointer) 在功能上与引用 `&T` 有类似的功能，但引用是安全的，因为借用检查器保证了它指向一个有效的数据。解引用一个裸指针只能通过不安全代码块执行。

两种裸指针：

- `*const T` ：不可变

- `*mut T` ：可变



裸指针与引用、智能指针的不同：

- 可以绕开借用规则，可以同时拥有一个数据的可变、不可变指针，甚至还能拥有多个可变的指针
- 并不能指向合法的内存
- 可以是 null
- 没有实现任何的自动回收 (drop)

裸指针跟C指针很像，使用它需要以牺牲安全性为前提，它具有破坏 Rust 内存安全的潜力，因此它只能在 `unsafe` 代码块中使用。



## 2.1 基于引用创建裸指针

**创建裸指针是安全的行为，而解引用裸指针才是不安全行为**：

```rust
fn main() {
    let mut num = 5;
    let r1 = &num as *const i32;
    let r2 = &mut num as *mut i32;
    
    // 使用裸指针
    unsafe {
        println!("r1: {}", *r1); // 5
        
        *r2 = 10;
        println!("r1: {}, r2: {}", *r1, *r2); // 10 10
    }
}
```



## 2.2 基于内存地址创建裸指针

基于引用创建裸指针是安全的，但通过内存地址创建裸指针则存在风险：

```rust
let address = 0x012345usize;
let r = address as *const i32;
```

该地址可能有值，也可能没有，即使有值，大概率也不是期望的。编译器也可能会优化这段代码，会造成没有任何内存访问发生，甚至还可能发生段错误 (segmentation fault)。

**不要凭空捏造一个地址，可使用下列方法取内存地址**：

```rust
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;

fn get_memory_location() -> (usize, usize) {
    let s = "Hello World!";
    let p = s.as_ptr() as usize;
    let l = s.len();
    (p, l)
}

fn get_str_at_location(pointer: usize, length: usize) -> &'static str {
    unsafe {
        from_utf8_unchecked(from_raw_parts(pointer as *const u8, length))
    }
}

fn main() {
    let (p, l) = get_memory_location();
    let message = get_str_at_location(p, l);
    println!("The {} bytes at 0x{:X} stored: {}", l, p, message);
}
```



## 2.3 基于智能指针创建裸指针

支持两种方法对智能指针创建裸指针：

```rust
fn main() {
    let a: Box<i8> = Box::new(8);
    
    // 先解引用再获取地址
    let r1: *const i8 = &*a;
    
    // 通过into_raw创建
    let r2: *const i8 = Box::into_raw(a);
    
    unsafe {
        println!("r1: {}, r2: {}", *r1, *r2);
    }
}
```



# 3. 调用不安全函数

一些函数可以声明为不安全的(unsafe)，这意味着在使用它时保证正确性不再是编译器的责任，而是程序员。



## 3.1 调用 `unsafe` 函数或方法

`unsafe` 函数或方法，必须放到 `unsafe` 块中调用：

```rust
unsafe fn dangerous() {
    println!("Call a dangerous function");
}

fn main() {
    unsafe {
        dangerous();
    }
}
```



## 3.2 用安全抽象包裹 `unsafe` 代码

需求：将一个数组分成两个切片，且每个切片都要求是可变的

```rust
fn split_at_mut(slice: &mut [i32], mid: usize) -> (&mut [i32], &mut [i32]) {
    let len = slice.len();
    
    assert!(mid < len);
    
    (&mut slice[..mid], &mut slice[mid..])
}

fn main() {
    let mut a = vec![1, 2, 3, 4, 5, 6];
    let slice = &mut a[..];
    
    let (s1, s2) = split_at_mut(slice, 3);
    assert_eq!(s1, &mut [1, 2, 3]);
    assert_eq!(s2, &mut [4, 5, 6]);
}
```

错误信息：

```
error[E0499]: cannot borrow `*slice` as mutable more than once at a time
 --> src/main.rs:8:30
  |
3 | fn split_at_mut(slice: &mut [i32], mid: usize) -> (&mut [i32], &mut [i32]) {
  |                        - let's call the lifetime of this reference `'1`
...
8 |     (&mut slice[..mid], &mut slice[mid..])
  |     -------------------------^^^^^--------
  |     |     |                  |
  |     |     |                  second mutable borrow occurs here
  |     |     first mutable borrow occurs here
  |     returning this value requires that `*slice` is borrowed for `'1`
```

Rust 的借用检查器无法理解分别借用同一个切片的两个不同部分，但事实上，这种行为没有任何问题，毕竟两个借用没有任何重叠之处。

改用 `unsafe` 操作：

```rust
use std::slice;

fn split_at_mut(slice: &mut [i32], mid: usize) -> (&mut [i32], &mut [i32]) {
    let len = slice.len();
    let ptr = slice.as_mut_ptr();
    
    assert!(mid < len);

    unsafe {
        (
            slice::from_raw_parts_mut(ptr, mid),
            slice::from_raw_parts_mut(ptr.add(mid), len-mid)
        )
    }
}
```

通过指针地址的偏移取控制数组的分割：

- `as_mut_ptr` 会返回指向 `slice` 首地址的裸指针 `*mut i32`
- `slice::from_raw_parts_mut` 函数通过指针和长度来创建一个新的切片。该切片的初始地址是 `ptr`，长度为 `mid`
- `ptr.add(mid)` 获取第二个切片的初始地址，由于切片中元素是 `i32` 类型，每个元素都占用 4 个字节的内存大小，因此不能简单地用 `ptr + mid` 来作为初始地址，而应该用 `ptr + 4 * mid`，但这种方式不安全，改用 `.add` 方法是最佳选择。
- `from_raw_parts_mut` 和 `add` 等方法都是 unsafe 的，因此应该将其放入 `unsafe` 代码块下



# 4. FFI

`FFI`：Foreign Function Interface，用来与其它语言进行交互，类似 `JNI` (Java Native Interface)

C 语言代码定义在 `extern` 代码块中，而 `extern` 必须使用 `unsafe` 才能进行调用，原因在于其它语言的代码并不会强制执行 Rust 的规则，因此 Rust 无法对这些代码进行检查，最终要靠开发者自己来保证代码的正确性和程序的安全性。

**ABI**：在 `extern "C"` 代码块中，列出想要调用的外部函数签名。其中 `"C"` 定义了外部函数所使用的**应用二进制接口** ABI (Application Binary Interface)。`ABI` 定义了如何在汇编层面来调用该函数。在所有 `ABI` 中，C 语言的是最常见的。

外部语言函数必须在一个 extern 代码块中，且该代码块要带有一个包含名称的 `#[link]` 属性。在 Rust 中，通过外部函数接口 FFI 可以直接调用C语言库。



## 4.1 调用 C 自定义函数

Rust 提供了到 C 语言库的外部语言函数接口 (Foreign Function Interface, FFI)。

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



## 4.2 编译成 C 库

**Step 1**: Cargo.toml

增加：

```toml
[lib]
name = "fibonacci"
crate-type = ["dylib"]
```



**Step 2**: src/lib.rs

注释 `#[no_mangle]` 用于告诉 Rust 编译器：不要乱改函数的名称。

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



## 4.3 调用 C 标准库函数

调用 C 标准库中的 `abs` 函数：

```rust
extern "C" {
    fn abs(input: i32) -> i32;
}

fn main() {
    unsafe {
        println!("Absolute value of -3 according to C: {}", abs(-3));
    }
}
```



调用 C 标准库数学函数：

```rust
use std::fmt::{self, Formatter, write};

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



# 5. 访问或修改一个可变的静态变量

通过 `Box::leak` 将一个变量从内存中泄漏，然后将其变为 `'static` 生命周期

```rust
#[derive(Debug)]
struct Config {
    a: String,
    b: String,
}
static mut CONFIG: Option<&mut Config> = None;

fn init() -> Option<&'static mut Config> {
    let c = Box::new(Config {
        a: "A".to_string(),
        b: "B".to_string(),
    });

    Some(Box::leak(c))
}


fn main() {
    unsafe {
        CONFIG = init();

        println!("{:?}", CONFIG)
    }
}
```



# 6. 实现 `unsafe` 特征

`unsafe` 的特征，是因为该特征至少一个方法包含了有编译器无法验证的内容：

```rust
unsafe trait Foo {
    
}

unsafe impl Foo for i32 {
    
}
```

`Send` 特征标记为 `unsafe` 是因为 Rust 无法验证类型是否能在线程间安全地传递，因此就需要通过 `unsafe` 来告诉编译器，它无需操心，剩下的交给自己来处理。



# 7. 访问 union 中的字段

`union` 主要用于跟 C 代码进行交互，访问 `union` 的字段是不安全的，因为 Rust 无法保证当前存储在 `union` 实例中的数据类型：

```rust
#[repr(C)]
union MyUnion {
    f1: u32,
    f2: f32,
}
```



























