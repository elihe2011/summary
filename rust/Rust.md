# 1. 入门

工具链：

- rustc：编译
- cargo：工程管理



```bash
# 编译
rustc main.rs

# 创建二进制应用工程，工程下自动创建 Cargo.toml 文件，功能类似 Node.js 的 package.json
cargo new hello-world --bin

# 创建Rust库工程，默认在 src 下生成 lib.rs 文件
cargo new common-lib

# 编译工程，在target下生成debug目录
cargo build

# 发布项目，在target下生成release目录
cargo build --release

# 运行程序
cargo run
```



修改文件 `~/.cargo/config`，换国内源：

```ini
[source.crates-io]
registry = "https://github.com/rust-lang/crates.io-index"
replace-with = 'rsproxy-sparse'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true
```





```rust
use std::cmp::Ordering;
use std::io;
use rand::Rng;

fn main() {
    println!("Guess the number!");

    // let secret_number = rand::thread_rng().gen_range(0, 100);
    let secret_number = rand::thread_rng().gen_range(1..=100);

    loop {
        println!("Please input your guess.");

        let mut guess = String::new();

        io::stdin().read_line(&mut guess).expect("Failed to read line");

        let guess: u32 = match guess.trim().parse() {
            Ok(num) => num,
            Err(_) => continue,
        };

        println!("You guessed: {}", guess);

        match guess.cmp(&secret_number) {
            Ordering::Less => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal => {
                println!("You win!");
                break;
            }
        }
    }
}
```



# 2. 基本语法

## 2.1 变量绑定

```rust
let x: i32 = 1;
let x = 1;        // 省略类型，使用类型推断(type inference)
let mut x = 3;    // 变量值可变
let (a, b) = (1, 2);
```

变量绑定需注意点：

- 变量默认不可变(immutable)，除非加上 mut 关键字
- 变量具有局部作用域，被限制在所属代码块内，并允许被覆盖(variable shadowing)
- 默认开启属性 `#[warn(unused_variable)]`，对未使用的变量发出警告，以`_`开头的除外
- 允许先声明后初始化，但未被初始化的变量会产生编译错误



## 2.2 基本类型

### 2.2.1 数值类型

#### 2.2.1.1 整数类型

| Length  | Signed  | Unsigned |
| ------- | ------- | -------- |
| 8-bit   | `i8`    | `u8`     |
| 16-bit  | `i16`   | `u16`    |
| 32-bit  | `i32`   | `u32`    |
| 64-bit  | `i64`   | `u64`    |
| 128-bit | `i128`  | `u128`   |
| arch    | `isize` | `usize`  |

整型表示法：

| Number literals  | Example       |
| ---------------- | ------------- |
| Decimal          | `98_222`      |
| Hex              | `0xff`        |
| Octal            | `0o77`        |
| Binary           | `0b1111_0000` |
| Byte (`u8` only) | `b'A'`        |

示例：

```rust
let x = 5;
let y: u32 = 123_456;
let z: f64 = 1.23e+2;
let zero = z.min(123.4);
let bin = 0b1111_0000;
let oct = 0o7320_1546;
let hex = 0xf23a_b049;
```

**整型溢出**：

- debug 模式编译时，Rust 会检查整型溢出，若存在这些问题，则使程序在编译时 *panic*

- release 模式编译时，Rust **不**检测溢出。相反，当检测到整型溢出时，Rust 会按照补码循环溢出（*two’s complement wrapping*）的规则处理。

显式处理可能的溢出，使用标准库针对原始数字类型提供的方法：

- `wrapping_*`：所有模式下，按照补码溢出规则处理，例如 `wrapping_add`
- `checked_*`：发生溢出，返回None
- `overflowing_*`：返回结果值及是否溢出bool值
- `saturating_*`：使值达到最小值或最大值

```rust
fn main() {
    let a: u8 = 255;
    let b = a.wrapping_add(20);
    println!("{}", b);
}
```



#### 2.2.1.2 浮动类型

`f32` ：单精度 ，`f64`： 双精度

**浮点数陷阱**：

- 浮点数是一种近似表达，受限于浮点数精度
- 浮动数使用 `>`，`>=` 等进行比较，在某些场景下不正确。推荐使用 `std::cmp::PartialEq` 进行浮点数比较

Rust 的 HashMap KV 数据类型，其 K 的类型必须实现 `std::cmp::Eq` 特性。但因为 f32 和 f64 均未实现该接口，所以无法使用浮点数作为 HashMap 的Key。

```rust
fn main() {
    assert!(0.1 + 0.2 == 0.3) // panic
}
```

**NaN**：数学上未定义的结果(not a number)。例如负数取平方根

```rust
fn main() {
    let x = (-42.1_f32).sqrt();
    println!("{}", x);          // NaN
    println!("{}", x.is_nan()); // true
}
```



#### 2.2.1.3 序列(Range)

序列只允许用于数字或字符类型，原因是：它们可以连续，同时编译器在编译期可以检查该序列是否为空，**字符和数字值是 Rust 中仅有的可以用于判断是否为空的类型**

```rust
fn main() {
    // [1, 5)
    for i in 1..5 {
        print!("{} ", i)
    }
    println!();

    // ['a', 'z']
    for i in 'a'..='z' {
        print!("{} ", i)
    }
}
```



#### 2.2.1.4 有理数和复数

未包含在标准库中，需要引入社区库 `num = "0.4.0"`

```rust
use num::complex::Complex;

fn main() {
    let a = Complex {re: 2.1, im: -1.2};
    let b = Complex::new(1.5, 0.7);

    let result = a + b;
    println!("{} + {}i", result.re, result.im);
}
```



### 2.2.2 字符、布尔、单元类型

#### 2.2.2.1 字符 (char)

Rust 的字符不仅仅是 `ASCII`，所有的 Unicode 值都可以作为 Rust 字符，包括单个的中文、日文、韩文、emoji表情符号等，都是合法的字符类型。Unicode 值得范围从 `U+0000 ~ U+D7FF` 和 `U+E000 ~ U+10FFFF`.

```rust
fn main() {
    let c = 'z';
    let z = 'ℤ';
    let g = '中';
    let e = '😻';

    println!("{}: {}, {}", c, c.len_utf8(), std::mem::size_of_val(&c)); // 1, 4
    println!("{}: {}, {}", z, z.len_utf8(), std::mem::size_of_val(&z)); // 3, 4
    println!("{}: {}, {}", g, g.len_utf8(), std::mem::size_of_val(&g)); // 3, 4
    println!("{}: {}, {}", e, e.len_utf8(), std::mem::size_of_val(&e)); // 4, 4
}
```



#### 2.2.2.2 布尔 (bool)

值为 `true` 和 `false`，内存占用 `1` 个字节



#### 2.2.2.3 单元类型

单元类型就是 `()`，main 函数返回值即为单元类型。而没有返回值得函数在 Rust 中是有单独得定义：**发散函数 ( diverge function )`**，即无法收敛得函数。

`println!()` 得返回值也是单元类型 `()`

另外，可以用 `()` 作为 map 的值，表示不关注具体值，只关注 key。该用法和 Go 语言的 `struct{}` 类似，用来占位，单完全不占用内存。



### 2.2.3 语句与表达式

```rust
fn add(x: i32, y: i32) -> i32 {
    let x = x + 1; // 语句
    let y = y + 5; // 语句
    x + y          // 表达式
}
```



#### 2.2.3.1 语句 (statement)

语句：**完成一个具体的操作，单没有返回值**

```rust
let a = 8;
let b: Vec<f64> = Vec::new();
let (a, c) = ("hi", false);
```

错误示例：

```rust
let b = (let a = 8);  // let 是语句，不是表达式，没有返回值
```



#### 2.2.3.2 表达式 (expression)

表达式会进行求值，然后返回一个值。

调用一个函数是表达式，因为会返回一个值，调用宏也是表达式，用花括号包裹最终返回一个值的语句块也是表达式。总之，**有返回值，它就是表达式**。

```rust
fn main() {
    let y = {
        let x = 3;
        x + 1  // 表达式不能包含分号，一旦在表达式后加上分号，它就会变成一条语句
    };

    println!("{}", y);
}
```

函数不返回值，默认返回 `()`：

```rust
fn main() {
    assert_eq!(ret_unit_type(), ())
}

fn ret_unit_type() {
    let x = 1;

    let _z = if x % 2 == 0 { "even" } else { "odd" };
}
```



### 2.2.4 函数

#### 2.2.4.1 无返回值`()`

两种无返回值的情况：

- 函数没有返回值，默认返回 `()`
- 通过 `;` 结尾的表达式返回一个 `()`

```rust
use std::fmt::Debug;

fn main() {
    report(123);
    report("abc");

    let mut x = String::from("hello");
    clear(&mut x);
    println!("{}", x);
}

fn report<T: Debug>(item: T) {
    println!("{:?}", item);
}

fn clear(text: &mut String) -> () {
    *text = String::new();
}
```



#### 2.2.4.2 发散函数 `!`

当用 `!` 作函数返回类型的时候，表示该函数永不返回( diverge function)，该语法一般用于导致程序崩溃的函数。

```rust
fn diverges() -> ! {
    panic!("This function never returns!");
}

let _x: i32 = diverges();
let _y: String = diverges();  // 上一步已退出，不会执行当前行

/*********************************/
use std::{thread, time};
use chrono::Local;

fn forever() -> ! {
    let ten_seconds = time::Duration::from_secs(10);

    loop {
        let now = Local::now();
        println!("{}", now.format("%Y-%m-%d %H:%M:%S"));
        thread::sleep(ten_seconds);
    }
}
```



## 2.3 所有权和借用

在其他语言中，一般使用GC来确保内存安全，单GC会引起性能、内存占用及 Stop the world 等问题，在高性能场景和系统编程上时不可接受的。

Rust 采用 **所有权系统** 来解决这一问题。

### 2.3.1 所有权

#### 2.3.1.1 栈与堆

**栈(Stack)**：遵循 先进后出FILO 原则，所有数据都必须占用已知且固定大小的内存空间。

**堆(Heap)**：存储大小未知或可能变化的数据。在堆上存放数据时，需要申请一定大小的内存空间。系统会在堆的某处找到一块足够大的空位，将其标记为已使用，并返回一个表示该位置地址的指针，该过程被称为**在堆上分配(allocating)内存**。接着该指针会被推入**栈**中。

**性能区别**：

- 写入：入栈比在堆上分配内存块，因为入栈无须申请新的内存空间
- 读取：栈数据一般直接存储在CPU高速缓存中，而堆数据只能存储在内存中，且访问堆数据必须先访问栈数据获取堆数据地址，所以相对慢

**所有权与堆栈**：

- 调用函数时，传递给函数的参数依次入栈，当函数调用结束，这些值将被从栈中反序依次移除
- **堆上的数据缺乏组织，需要堆其进行跟踪，确保其分配和释放，不在堆上产生内存泄漏问题(数据无法被回收)**



#### 2.3.1.2 所有权原则

所有权规则：

- Rust 中每个值都被一个变量所拥有，该变量称为值的所有者
- 一个值同时只能被一个变量所拥有，或反过来一个值只属于一个所有者
- 当所有者(变量)离开作用域范围时，这个值将被丢弃(drop)

**变量作用域**：一般在一个 `{ }` 内



#### 2.3.1.3 变量绑定

**转移所有权**:

```rust
// 基础类型，栈上自拷贝赋值
let x = 5;
let y = x;

// 复杂类型，不支持自动拷贝
let s1 = String::from("hello");
let s2 = s1;
```

String 是一种复杂类型，由**存储在栈中的堆指针、字符串长度、字符串容量共同组成**

当变量离开作用域后，Rust会自动调用 drop 函数并清理变量的堆内存。如果一个值属于两个所有者，将会导致多次尝试清理同样的内存，即**二次释放(double free)错误**。两次释放同样的内存，会导致内存污染，可能导致潜在的安全漏洞。

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1;
    
    println!("{}", s1);
}
```

由于 Rust 禁止使用无效的引用，上述代码将出现错误：

```txt
error[E0382]: borrow of moved value: `s1`
 --> src\main.rs:5:20
  |
2 |     let s1 = String::from("hello");
  |         -- move occurs because `s1` has type `String`, which does not implement the `Copy` trait
3 |     let s2 = s1;
  |              -- value moved here
4 |
5 |     println!("{}", s1);
  |                    ^^ value borrowed here after move
  |
  = note: this error originates in the macro `$crate::format_args_nl` which comes from the expansion of the macro `println` (in Nightly build
s, run with -Z macro-backtrace for more info)
help: consider cloning the value if the performance cost is acceptable
  |
3 |     let s2 = s1.clone();
  |                ++++++++

For more information about this error, try `rustc --explain E0382`.
```

将类型String修改为 `&str`，则不会有问题：

```rust
fn main() {
    let s1 = "hello";
    let s2 = s1;
    println!("{}", s1)
}
```

区别：

- 在 `String` 例子中，`s1` 持有了通过`String::from("hello")` 创建的值的所有权
- 在 `&str` 例子中，`s1` 只是引用了存储在二进制中的字符串 `"hello"`，并没有持有所有权



**深拷贝(克隆)**：

Rust 不会自动创建数据的“深拷贝”，只能调用 `clone()` 方法进行深拷贝操作，它发生在堆上：

```rust
fn main() {
    let s1 = String::from("hello");
    let s2 = s1.clone();
    println!("{}", s1);
}
```



**浅拷贝**：

浅拷贝只发生在栈上，性能较高。

```rust
fn main() {
    let x = 5;
    let y = x;
    println!("{}", x);
}
```

可拷贝的类型：**任何基本类型的组合可以Copy，不需要分配内存或某种形式资源的类型是可以 Copy 的。**

- 整数类型，如 u32
- 浮点数类型：如 f64
- 布尔类型：bool
- 字符类型：char
- 元组：当且仅当其包含的类型也都是 Copy 的。如 (i32, i32) 可以 Copy，但 (i32, String) 则不能
- 不可改变引用 &T，如 &str。但**可变引用 `&mut T` 是不可以 Copy 的**

#### 2.3.1.4 函数传值与返回

将值传递给函数，会发生 `move` 或`copy`，跟 `let` 语句一样

```rust
fn main() {
    let x = 5;
    makes_copy(x);
    println!("{}", x);

    let s = String::from("hello");
    takes_ownership(s);
    println!("{}", s);  // s 的所有权移交给了函数，此处打印将报错
}

fn makes_copy(n: i32) {
    println!("{}", n);
}

fn takes_ownership(s: String) {
    println!("{}", s);
}
```

所有权带来的麻烦：**总是把一个值传来传去来使用它**。 传入一个函数，很可能还要从该函数传出去，结果就是语言表达变得非常啰嗦



### 2.3.2 引用与借用

**获取变量的引用，称之为借用(borrowing)**



#### 2.3.2.1 引用与解引用

常规引用是一个指针类型，指向了对象存储的内存地址。

```rust
fn main() {
    let x = 5;
    let y = &x;

    assert_eq!(x, 5);
    assert_eq!(*y, 5);
}
```



#### 2.3.2.2 不可变引用

```rust
fn main() {
    let s1 = String::from("hello");
    let len = calculate_length(&s1);

    println!("The length of '{}' is {}.", s1, len);
}

fn calculate_length(s: &String) -> usize {
    s.len() // s离开了作用域，但因为它不拥有引用值得所有权，所以什么也不会发生
}
```

`&` 符号即是引用，**它允许你使用值，但是不获取所有权**。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/rust-immutable-reference.jpg)



#### 2.3.2.3 可变引用

```rust
fn main() {
    let mut s = String::from("hello");
    change(&mut s);

    println!("{}", s);
}

fn change(s: &mut String) {
    s.push_str(", world");
}
```

**1. 可变引用同时只能存在一个：**

```rust
// ok
fn immutable() {
    let s1 = String::from("hello");
    let r1 = &s1;
    let r2 = &s1;
    println!("{}, {}", r1, r2);
}

// error[E0499]: cannot borrow `s1` as mutable more than once at a time
fn mutable() {
    let mut s1 = String::from("hello");
    let r1 = &mut s1;
    let r2 = &mut s1;
    println!("{}, {}", r1, r2);
}
```

编译器 `borrow checker` 特性，避免了数据竞争，数据竞争可能导致如下问题：

- 两个或更多的指针同时访问同一数据
- 至少有一个指针被用来写入数据
- 没有同步数据访问机制



**2. 可变引用与不可变引用不能同时存在：**

```rust
// error[E0502]: cannot borrow `s` as mutable because it is also borrowed as immutable
fn main() {
    let mut s = String::from("hello");
    let r1 = &s;        // ok
    let r2 = &s;        // ok
    let r3 = &mut s;    // error

    println!("{}, {}, {}", r1, r2, r3);
}

// Rust1.31+优化：引用作用域的结束位置从花括号变成最后一次使用的位置
fn main() {
    let mut s = String::from("hello");
    let r1 = &s;        // ok
    let r2 = &s;        // ok
    println!("{}, {}", r1, r2);

    let r3 = &mut s;    // ok
    println!("{}", r3);
}
```



**3. NLL**

**None-Lexical Lifetimes** ，Rust 编译器的一种优化行为，专门用于找到某个引用所在作用域( } )结束前就不再被使用的代码位置。



#### 2.3.2.4 悬垂引用(Dangling References)

也称悬垂指针，即指针指向的值被释放掉了，但指针依然存在，其指向的内存可能不存在任何值或已被其他变量重新使用。

Rust 编译器可确保引用永远不会变成悬垂状态：当你获取数据的引用后，编译器可确保数据不会再引用结束前被释放，要想释放数据，必须先停止其引用的使用。

```rust
fn main() {
    let reference_to_nothing = dangle();
    println!("{:?}", reference_to_nothing);
}

// Missing lifetime specifier [E0106]
fn dangle() -> &String {
    let s = String::from("hello");

    &s
}
```

解决办法：不返回引用，而返回值，最终 String 的所有权转移给外面的调用者。

```rust
fn no_dangle() -> String {
    let s = String::from("hello");

    s
}
```



#### 2.3.2.5 借用规则

总结：

-  同一时刻，只能拥有要么一个可变引用，要么任意多个不可变引用
- 引用必须总是有效的



## 2.4 复合类型

### 2.4.1 字符串与切片

#### 2.4.1.1 切片

Slice：&[T]，引用一个数组的部分数据并且不需要拷贝

**切片是对集合的部分引用**，通过 `&s[START:END]`

```rust
fn main() {
    let s = String::from("hello world");

    let hello = &s[0..5];

    // let world = &s[6..11];

    // let len = s.len();
    // let world = &s[6..len];

    let world = &s[6..];

    println!("{}, {}", hello, world);
}
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/rust-slice.jpg)

UTF-8 字符切片：

```rust
fn main() {
    let s = "中国人";

    // UTF8 三个字节，byte index 2 is not a char boundary
    //let a = &s[..2];

    // OK
    let a = &s[..3];

    println!("{}", a);
}
```

**切片借用的问题**：已经拥有可变借用时，就无法再拥有不可变借用。

```rust
fn main() {
    let mut s = String::from("hello world");

    let word = first_word(&s);

    // mutable borrow occurs here
    // pub fn clear(&mut self)
    s.clear();  // error

    // immutable borrow later used here
    println!("the first word is: {}", word);
}

fn first_word(s: &String) -> &str {
    &s[..1]
}
```



#### 2.4.1.2 字符串

**Rust 的字符是 Unicode 类型，每个字符占据 4 个字节内存空间；字符串是 UTF-8 编码，其中所占的字节数数变化的(1-4)**，这样有助于大幅降低字符串所占的内存空间。

**字符串类型**：最底层的是不定长类型`str`

- `&str`：字符串切片，静态分配，固定大小，且不可变，**字符字面量是切片**。（**直接硬编码进可执行文件中**）
- String：**堆分配字符串，可增长、可改变且具有所有权的字符串**

`&str` 与 `String` 互转：

```rust
fn main() {
    // &str -> String
    let s1 = String::from("hello");
    let s2= "world".to_string();
    println!("{}, {}", s1, s2);

    // String -> &str
    let s = String::from("hello world");
    let a1 = &s;  // &String -> &str, deref 隐式强制转换
    let a2 = &s[..];
    let a3 = s.as_str();

    println!("{}, {}, {}", a1, a2, a3);
}
```



**注意：不支持字符串索引**

```rust
let s = String::from("hello");
let h = s[0];    // cannot be indexed by `{integer}`
let h = s[0..1]  // ok
```



#### 2.4.1.3 字符串操作

```rust
// push 追加
fn push() {
    let mut s = String::from("hello");
    s.push_str(" rust");
    s.push_str("!");
    println!("{}", s);
}

// insert 插入
fn insert() {
    let mut s = String::from("hello rust!");
    s.insert(5, ',');
    s.insert_str(6, " I like");
    println!("{}", s);
}

// replace 替换
fn replace() {
    let s1 = String::from("I like rust. Learning rust is my favorite!");
    let r1 = s1.replace("rust", "RUST");
    println!("{}", r1);

    let r2 = s1.replacen("rust", "RUST", 1);
    println!("{}", r2);

    let mut s2 = String::from("I like rust");
    s2.replace_range(7..8, "R");
    println!("{}", s2);
}

// delete 删除
fn delete() {
    // pop 删除并返回最后一个字符
    let mut s1 = String::from("rust pop 中文!");
    let c1 = s1.pop(); // Some
    let c2 = s1.pop();
    println!("{}, {}, {}", s1, c1.unwrap(), c2.unwrap());

    // remove 删除并返回指定位置的字符
    let mut s2 = String::from("测试remove方法");
    println!("len: {}, size: {}", s2.len(), std::mem::size_of_val(s2.as_str()));

    let c3 = s2.remove(0);
    let c4 = s2.remove(3);
    println!("{}, {}, {}", s2, c3, c4);

    // truncate 删除从指定位置到结尾的字符串
    let mut s3 = String::from("测试truncate");
    s3.truncate(3);
    println!("{}", s3); // 测

    // clear 清空字符串
    let mut s4 = String::from("hello");
    s4.clear();
    println!("{}", s4);
}

// concatenate 连结
fn concatenate() {
    // +, +=
    let s1 = String::from("hello");
    let s2 = String::from(" rust");

    // let result = s1 + &s2; // &s2 类型自动由 &String 转为 &str
    let result = s1.add(&s2);  // 底层调用 std::string fn add(mut self, other &str)
    println!("{}", result);

    // format!()
    let s3 = String::from("hello");
    let s4 = "rust";
    let result3 = format!("{} {}", s3, s4);
    println!("{}", result3);
}
```



#### 2.4.1.4 字符串转义

```rust
fn main() {
    // \x  十六进制
    let byte_escape = "I'm writing \x52\x75\x73\x74!";
    println!("What are you doing\x3F (\\x3F means ?) {}", byte_escape);

    // \u Unicode字符
    let unicode_codepoint = "\u{211D}";
    let character_name = "\"DOUBLE-STRUCT CAPITAL R\"";
    println!("Unicode character {} (U+211D) is called {}", unicode_codepoint, character_name);

    // \ 忽略换行
    let long_string = "String literals
                              can span multiple lines.
                              The linebreak and indentation here ->\
                              <- can be escaped too!";
    println!("{}", long_string);
}
```



#### 2.4.1.5 操作 UTF-8 字符串

```rust
use utf8_slice;

fn main() {
    let s = "中国人";

    // 字符
    for c in s.chars() {
        println!("{}", c);
    }

    // 字节
    for b in s.bytes() {
        println!("{}", b);
    }

    // 子字符串
    let ss = utf8_slice::slice(s, 0, 2);
    println!("{}", ss);
}
```



### 2.4.2 元组

Tuple: (T1, T2, ...), 具有固定大小的有序列表，每个元素都有自己的类型，通过解构或者索引来获得每个元素的值。**超过12个元素不能被直接println**

元组是由多种类型组合到一起形成的。元组的长度是固定的，元素的顺序也是固定的。

```rust
fn main() {
    let tup: (i64, f64, i8) = (100, 3.14, 1);

    // 解构
    let (x, y, z) = tup;
    println!("x={}, y={}, z={}", x, y, z);

    // 索引
    let a = tup.1;
    println!("{}", a);
}
```



### 2.4.3 结构体

#### 2.4.3.1 结构体语法

```rust
struct User {
    active: bool,
    username: String,
    email: String,
    sign_in_count: u64,
}
```

创建实例：**每个字段都必须初始化**

```rust
fn main() {
    let user = User {
        username: String::from("eli"),
        email: String::from("eli@test.io"),
        active: false,
        sign_in_count: 0,
    };

    println!("{}", user.active);
}
```

更新操作：`..` 语法表明凡是没有显式声明的字段，从 `user` 中自动获取

```rust
fn main() {
    ...

    let user2 = User {
        email: String::from("lollipop@qq.com"),
        ..user
    };
    println!("{:?}", user2);
}
```



#### 2.4.3.2 结构体内存排序

```rust
struct File {
    name: String,
    data: Vec<u8>,
}

fn main() {
    let f = File {
        name: String::from("abc.txt"),
        data: Vec::new(),
    };

    let name = &f.name;
    let len = &f.data.len();

    println!("{:?}", f);
    println!("name: {}, length: {}", name, len);
}
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/rust-struct-mem.jpg)



#### 2.4.3.3 元组结构体(Tuple Struct)

元组结构体：结构体有名称，但结构体字段没有名称，当元组结构体只有一个字段时，成为新类型(newtype);

```rust
struct Point(i32, i32);
struct Color(u8, u8, u8);

fn main() {
    let origin = Point(0, 0);
    let black = Color(0, 0, 0);
    ...
}

/**-----------------------**/
// a tuple struct
struct Pair(i32, f32);
let pair = Pair(1, 0.1);
let Pair(integer, decimal) = pair;

// A tuple struct's constructors can be used as functions
struct Digit(i32);
let v = vec![0, 1, 2];
let d: Vec<Digit> = v.into_iter().map(Digit).collect();

// newtype: a tuple struct with only one element
struct Inches(i32);
let length = Inches(10);
let Inches(integer_length) = length;
```



#### 2.4.3.4 单元结构体(Unit-like Struct)

没有任何字段和属性。

如果定义一个类型，但是不关心该类型的内容, 只关心它的行为时，就可以使用 `单元结构体`

```rust
struct Null;
let empty = Null;

impl SomeTrait for Null {

}
```



#### 2.4.3.5 结构体数据所有权

```rust
struct User {
    username: &str,
    email: &str,
    sign_in_count: u64,
    active: bool,
}

fn main() {
    let user = User {
        email: "lollipop@qq.com",
        username: "ly",
        active: true,
        sign_in_count: 1,
    };

    println!("{:?}", user);
}
```

在结构体中，使用基于引用的 `&str` 字符串切片类型，即`User` 结构体从其它对象借用数据。但此处必须用到生命周期(lifetimes)，否则将出现 `error[E0106]: missing lifetime specifier`，修正：

```rust
struct User<'a> {
    username: &'a str,
    email: &'a str,
    sign_in_count: u64,
    active: bool,
}
```

结构体中有引用字段时，需要对生命周期参数进行声明 `<'a>`。该生命周期标注说明，**结构体 `User` 所引用的字符串 `str` 必须比该结构体活得更久**。



#### 2.4.3.6 打印结构体

```rust
#[derive(Debug)]     // 打印
#[derive(Default)]   // 默认值
struct Point3d {
    x: i32,
    y: i32,
    z: i32,
}

let origin = Point3d::default();
let point = Point3d{y: 1, ..origin};
let Point3d{x: x0, y: y0, ..} = point;
```



#### 2.4.3.7 字段可变性

Rust 不支持域可变性(field mutability):

```rust
struct Point {
    mut x: i32,  // 不支持
    y: i32,
}
```



可变性是绑定的一个属性，而不是结构体自身的：

```rust
#[derive(Debug)]
struct Point {
    x: i32,
    y: Cell<i32>,
}

let point = Point{x: 1, y: Cell::new(5)};

point.y.set(3);
```



### 2.4.4 枚举

枚举(enum 或 enumeration)允许你通过列举可能的成员来定义一个**枚举类型**

```rust
enum PokerSuit {
  Clubs,
  Spades,
  Diamonds,
  Hearts,
}
```



枚举默认是私有的，通过 pub 关键字变为公有，其内部元素也同时变为公有。(这点与结构体不同，结构体元素公有需要在属性前添加pub)



#### 2.4.4.1 枚举值

```rust
enum Message {
    Quit,
    ChangeColor(i32, i32, i32),
    Move {x: i32, y: i32},
    Write(String),
}

fn main() {
    let m1 = Message::Quit;
    let m2 = Message::Move{x:1,y:1};
    let m3 = Message::ChangeColor(255,255,0);
}
```



#### 2.4.4.2 同一化类型

有一个 WEB 服务，需要接受用户的长连接，假设连接有两种：`TcpStream` 和 `TlsStream`，但希望对这两个连接的处理流程相同，也就是用同一个函数来处理这两个连接

```rust
fn new (stream: TcpStream) {
  let mut s = stream;
  if tls {
    s = negotiate_tls(stream)
  }

  // websocket是一个WebSocket<TcpStream>或者
  //   WebSocket<native_tls::TlsStream<TcpStream>>类型
  websocket = WebSocket::from_raw_socket(
    stream, ......)
}

enum Websocket {
  Tcp(Websocket<TcpStream>),
  Tls(Websocket<native_tls::TlsStream<TcpStream>>),
}
```



#### 2.4.4.3 Option 枚举

空值 null 的表达非常有意义，因为空值表示当前时刻变量的值是缺失的。Rust 抛弃 `null`，改为使用 `Option` 枚举变量来处理空值

`Option` 枚举包含两个成员：

- `Some(T) ` 表示含有值
- `None` 表示没有值

`Option<T>` 枚举被包含在 `prelude`（Rust 标准库，提前将最常用的类型、函数等引入其中，省得再手动引入）之中，不需要将其显式引入作用域。它的成员 `Some` 和 `None` 也是如此，无需使用 `Option::` 前缀就可直接使用。

```rust
let some_number = Some(5);
let some_string = Some("a string");

let absent_number: Option<i32> = None;
```

为了使用 `Option<T>` 值，需要编写处理每个成员的代码。你想要一些代码只当拥有 `Some(T)` 值时运行，允许这些代码使用其中的 `T`。也希望一些代码在值为 `None` 时运行，这些代码并没有一个可用的 `T` 值。`match` 表达式就是这么一个处理枚举的控制流结构：它会根据枚举的成员运行不同的代码，这些代码可以使用匹配到的值中的数据。

```rust
fn main() {
    let five = Some(5);
    let six = plus_one(five);
    let none = plus_one(None);

    println!("{}", six.unwrap());
    println!("{}", none.is_none());
}

fn plus_one(x: Option<i32>) -> Option<i32> {
    match x {
        None => None,
        Some(i) => Some(i+1),
    }
}
```



### 2.4.5 数组

Rust 中的两种数组：

- array：固定长度，速度快。类比 `&str`，**存储在栈上**
- vector：可动态增长，但有性能损耗，也称动态数组；类比 `String`，**存储在堆上**

数组的三要素：`[T; length]`

- 长度固定
- 元素必需有相同的类型
- 依次线性排列

#### 2.4.5.1 数组声明和使用

```rust
fn main() {
    // 自动推导类型
    let a = [1, 2, 3, 4, 5];
    println!("{:?}", a);

    // 声明类型
    let b: [f64; 3] = [1.0, 2.2, 2.5];
    println!("{:?}", b);

    // 某个值重复出现 N 次
    let c = [6; 3];
    println!("{:?}", c);

    // 访问数组
    println!("{}", a[1]);
}
```



#### 2.4.5.2 非基础类型元素

非基础类型数据，重复赋值：

```rust
fn main() {
    let a = [String::from("just a test"); 8];
    println!("{:?}", a);
}
```

错误：`error[E0277]: the trait bound String: Copy is not satisfied`

原因：由于所有权原则，**基本类型在Rust中赋值是以copy的形式**，但复杂类型都没有深拷贝，只能一个个创建。

```rust
fn main() {
    let a = [String::from("just a test"), String::from("just a test"), String::from("just a test")];
    println!("{:?}", a);
}
```

优化：调用`std::array::from_fn`

```rust
fn main() {
    let a: [String; 8] = std::array::from_fn(|_i| String::from("just a test"));
    println!("{:?}", a);
}
```



#### 2.4.5.3 数组切片

数组切片，即对数组一部分的引用。其特点如下：

- 切片大小取决于指定的起始和结束位置
- 创建切片的代价非常小，它只是针对底层数组的一个引用
- 切片类型`[T]`拥有不固定的大小，而切片引用类型`&[T]`则具有固定的大小。Rust很多时候需要固定大小的数据类型，因此 `&[T]` 及 `&str` 更有用

```rust
fn main() {
    let array = [1, 2, 3, 4, 5];
    let slice = &array[1..3];
    println!("{:?}", slice);

    assert_eq!(slice, &[2, 3]);
}
```



#### 2.4.5.4 二维数组

```rust
fn main() {
    let a1: [u8; 3] = [1, 2, 3];
    let a2 = [4, 5, 6];
    let a3: [u8; 3] = [0; 3];
    let a4 = [1; 3];

    // a2 & a4 的类型，自动由默认的 i32 转为 u8
    let two_dim_array = [a1, a2, a3, a4];
    println!("{:?}", two_dim_array);

    // 遍历
    for a in two_dim_array {
        println!("{:?}", a);

        for n in a.iter() {
            println!("\t{:?} + 10 = {:?}", n, n+10)
        }

        let mut sum = 0;
        for i in 0..a.len() {
            sum += a[i];
        }
        println!("\tsum({:?}) = {}", a, sum)
    }
}
```



`

```rust
fn main() {
    let a: [String; 8] = std::array::from_fn(|_i| String::from("just a test"));
    println!("{:?}", a);
}
```



#### 2.4.5.5 数组与切片

**数组**：`[T; n]`，长度在编译时已确定。

**切片**：`[T]`，运行时数据结构，长度无法在编译时得知。实际开发中使用较多，一般通过引用的方式去使用`&[T]`，因为它固定大小



## 2.5 流程控制

Rust 是基于表达式的编程语言，有两种语句

- 声明语句(declaration statement)，比如进行变量绑定的 let 语句
- **表达式语句(expression statement)，它通过在末尾加上 ";" 来将表达式变成语句，丢弃该表达式的值，一律返回元类型 `()`**

表达式总是返回一个值，但是**语句不返回值或者返回 `()`**

```rust
let x: i32;  // 声明语句
x = 5;       // 表达式语句

let y = 6;   // 声明并赋值语句

let y = (let x = 5);  // 错误，x =5 是表达式，返回元类型值 ()
```



### 2.5.1 if

分支结构：`if -> else if -> else`，是一个表达式(expression)

```rust
let x = 5;
let z: i32 = if x < 5 { 10; } else { 15; };  // 注意{}中加“;”，否则是表达式
```



### 2.5.2 for

```rust
for item in container {
    code
}
```

其中，container是一个迭代器(iterator)，例如 `0..10` 或 [0, 1, 2].iter() 等

```rust
for x in 1..10 {
    print!("{x} ");
}

for x in 1..=10 {
    print!("{x} ");
}
```

**注意**:  `for` 往往使用集合的引用形式，**如果不使用引用，所有权会被转移（move）到 `for` 语句块中**，后面就无法再使用这个集合

```rust
for item in &container {
  // ...
}
```

对于实现了 `copy` 特征的数组(例如 [i32; 10] )而言， `for item in arr` 并不会把 `arr` 的所有权转移，而是直接对其进行了拷贝，因此循环之后仍然可以使用 `arr` 

```rust
fn main() {
    let a = [1, 2, 3, 4, 5];

    for i in a {
        print!("{} ", i);
    }

    println!("\n{:?}", a); // ok
}
```



使用方法总结：

| 使用方法                      | 等价使用方式                                      | 所有权     |
| ----------------------------- | ------------------------------------------------- | ---------- |
| `for item in collection`      | `for item in IntoIterator::into_iter(collection)` | 转移所有权 |
| `for item in &collection`     | `for item in collection.iter()`                   | 不可变借用 |
| `for item in &mut collection` | `for item in collection.iter_mut()`               | 可变借用   |



两种循环方式比较：

```rust
let collection = [1, 2, 3, 4, 5];

// 循环索引
for i in 0..collection.len() {
  let item = collection[i];
  // ...
}

// 直接循环
for item in collection {

}
```

- **性能**：索引方式，因边界检查(Bounds Checking)，导致运行时性能损耗；直接循环则不会触发边界检查。

- **安全**：索引方式访问集合是不连续的，存在一定可能性在两次访问之间，集合发生变化，从而导致脏数据产生；直接循环则是连续的，由于所有权控制，在访问过程中，数据不会发生变化，因此是安全的。



### 2.5.3 while

```rust
let mut i = 0;

while i < 10 {
    print!("{i} ");
	i += 1;
}
```



### 2.5.4 loop

无限循环：

```rust
fn main() {
    'outer: loop {
        println!("Entered outer loop");

        'inner: loop {
            println!("Entered inner loop");
            break 'outer;
        }

        println!("This point will never be reached");
    }

    println!("Exited outer loop");
}
```



loop 是一个值，可以返回值：

```rust
fn main() {
    let mut counter = 0;

    let result = loop {
        counter += 1;

        if counter == 10 {
            break counter*2;
        }
    };

    println!("result={}", result)
}
```



复杂控制：

```rust
fn main() {
    let mut count  = 0;

    'counting_up: loop {
        println!("count = {count}");
        let mut remaining = 10;

        loop {
            println!("remaining = {remaining}");
            if remaining == 9 {
                break;
            }

            if count == 2 {
                break 'counting_up;
            }

            remaining -= 1;
        }

        count += 1;
    }

    println!("End count = {count}")
}
```



## 2.6 模式匹配

### 2.6.1 match 和 if let

```rust
match target {
    pattern1 => expression1,
    pattern2 => {
        statement1;
        statement2;
        expression2
    },
    pattern3 | pattern4 => expression3,
    _ => expression4
}
```



#### 2.6.1.1 match 匹配

```rust
enum Coin {
    Penny,
    Nickle,
    Dime,
    Quarter,
}

fn value_in_cents(coin: Coin) -> u8 {
    match coin {
        Coin::Penny => {
            println!("Lucky penny!");
            1
        },
        Coin::Nickle => 5,
        Coin::Dime => 10,
        Coin::Quarter => 25,
    }
}
```



**match 表达式赋值**：

```rust
enum IpAddr {
    Ipv4,
    Ipv6,
}

fn main() {
    let ip = IpAddr::Ipv6;
    let ip_str = match ip {
        IpAddr::Ipv4 => "127.0.0.1",
        _ => "::1",
    };

    println!("{}", ip_str);
}
```



**模式绑定**：

```rust
enum Action {
    Say(String),
    MoveTo(i32, i32),
    ChangeColorRGB(u16, u16, u16),
}

fn main() {
    let actions = [
        Action::Say("Hello Rust".to_string()),
        Action::MoveTo(1, 2),
        Action::ChangeColorRGB(160, 32, 240), // purple
    ];
    
    for action in actions {
        match action {
            Action::Say(s) => {
                println!("{}", s);
            },
            Action::MoveTo(x, y) => {
                println!("point from (0, 0) move to ({}, {})", x, y);
            },
            Action::ChangeColorRGB(r, g, b) => {
                println!("change color to '(r{}, g{}, b{})'", r, g, b);
            },
        }
    }
}
```



#### 2.6.1.2  if let 匹配

当只有一个模式的值需要处理，直接忽略其他值的场景：

```rust
fn main() {
    let v = Some(3u8);

    match v {
        Some(3) => println!("three"),
        _ => (),
    }
}
```

**当只要匹配一个条件，且忽略其他条件时就用 `if let` ，否则都用 `match`**

```rust
fn main() {
    let v = Some(3u8);

    if let Some(3) = v {    // 注意是赋值
        println!("three");
    }
}
```



#### 2.6.1.3  `matches!` 宏

`matches!`宏，将一个表达式跟模式进行匹配，然后返回匹配的结果 `true` or `false`

```rust
#[derive(Debug)]
enum Test {
    Foo,
    Bar
}

fn matches_marco() {
    let v = [Test::Foo, Test::Bar, Test::Foo];

    // x is &&Test, cannot compare
    //let result = v.iter().filter(|x| x == Test::Bar);

    let result = v.iter().filter(|x| matches!(x, Test::Bar));
    for i in result {
        println!("{:?}", i);
    }
}
```

其实示例：

```rust
let foo = 'f';
assert!(matches!(foo, 'A'..='Z' | 'a'..='z'));

let bar = Some(4);
assert!(matches!(bar, Some(x) if x > 2));
```



### 2.6.2 Option 枚举

```rust
enum Option<T> {
    Some(T),   // 有值
    None,      // 为空
}
```

匹配 `Option<T>`：

```rust
fn main() {
    let five = Some(5);
    let six = plus_one(five);
    println!("{:?}", six);

    let none = plus_one(None);
    println!("{:?}", none);
}

fn plus_one(x: Option<i32>) -> Option<i32> {
    match x {
        Some(i) => Some(i + 1),
        None => None,
    }
}
```



### 2.6.3 适用场景

#### 2.6.3.1 模式

模式一般由以下内容组成：

- 字面值
- 解构的数组、枚举、结构体或者元组
- 变量
- 通配符
- 占位符



#### 2.6.3.1 场景

**match 分支**：

```rust
match VALUE {
    PATTERN => EXPRESSION,
    PATTERN => EXPRESSION,
    _ => EXPRESSION,
}
```



**if let 分支**：用于匹配一个模式，而忽略剩下的所有模式

```rust
if let PATTERN = SOME_VALUE {

}
```



**while let 条件循环**：只要模式匹配就一直进行 `while` 循环

```rust
// Vec是动态数组
let mut stack = Vec::new();

// 向数组尾部插入元素
stack.push(1);
stack.push(2);
stack.push(3);

// stack.pop从数组尾部弹出元素
while let Some(top) = stack.pop() {
    print!("{} ", top);
} // 3 2 1
```



**for 循环**：

```rust
let v = vec!['a', 'b', 'c'];

for (index, value) in v.iter().enumerate() {
    println!("{} is at index {}", value, index);
}
```



**let 语句**：

```rust
let PATTERN = EXPRESSION;

let x = 5;  // x 也是一种模式绑定，代表将匹配的值绑定到变量 x 上

let (x, y, z) = (1, 2, 3);
```



**函数参数也是模式**：

```rust
fn foo(x: i32) {
    // 代码
}

fn print_coordinates(&(x, y): &(i32, i32)) {
    println!("Current location: ({}, {})", x, y);
}

fn main() {
    let point = (3, 5);
    print_coordinates(&point);
}
```



### 2.6.4 全模式列表

#### 2.6.4.1 匹配字面值

```rust
fn main() {
    let x = 2;

    match x {
        1 => println!("one"),
        2 => println!("two"),
        3 => println!("three"),
        _ => println!("anything"),
    }
}
```



#### 2.6.4.2 匹配命名变量

```rust
fn main() {
    let x = Some(5);
    let y = 10;

    match x {
        Some(50) => println!("got 50"),
        Some(y) => println!("matched, y = {:?}", y), // 匹配变量y，此时原有的y被遮盖
        None => println!("default case, x = {:?}", x),
    }

    println!("at the end, x = {:?}, y = {:?}", x, y);  // y 值未变
}
```



#### 2.6.4.3 单分支多模式

```rust
fn main() {
    let x = 2;

    match x {
        1 | 2 => println!("one or two"),  // 多模式
        3 => println!("three"),
        _ => println!("anything"),
    }
}
```



#### 2.6.4.4 序列范围

```rust
fn main() {
    let x = 'c';

    match x {
        'a'..='k' => println!("early ASCII letter"),
        'l'..='z' => println!("late ASCII letter"),
        _ => println!("something else"),
    }
}
```



#### 2.6.4.5 解构并分解值

##### 2.6.4.5.1 解构结构体

```rust
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p = Point{ x: 0, y: 7 };

    let Point {x: a, y: b} = p;
    println!("a={}, b={}", a, b);

    match p {
        Point { x, y: 0 } => println!("x={}", x),
        Point {x: 0, y} => println!("y={}", y),
        Point {x, y} => println!("x={}, y={}", x, y),
    }
}
```



##### 2.6.4.5.2 解构枚举

```rust
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(u8, u8, u8),
}

fn main() {
    let msg = Message::ChangeColor(30, 240, 120);
    
    match msg {
        Message::Quit => println!("quit"),
        Message::Move { x, y } => println!("x={}, y={}", x, y),
        Message::Write(text) => println!("message={}", text),
        Message::ChangeColor(r, g, b) => println!("r{}, g{}, b{}", r, g, b),
    }
}
```



##### 2.6.4.5.3 解构嵌套结构体和枚举

```rust
enum Color {
    Rgb(u8, u8, u8),
    Hsv(i32, i32, i32),
}

enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(Color),
}

fn main() {
    let msg = Message::ChangeColor(Color::Hsv(124, 60, 234));
    
    match msg {
        Message::ChangeColor(Color::Rgb(r, g, b)) => {
            println!("r{}, g{}, b{}", r, g, b);
        }
        Message::ChangeColor(Color::Hsv(h, s, v)) => {
            println!("h{}, s{}, v{}", h, s, v);
        }
        _ => (),
    }
}
```



##### 2.6.4.5.4 解构数组

定长数组：

```rust
fn main() {
    let arr = [2, 7];

    let [x, y] = arr;

    assert_eq!(x, 2);
    assert_eq!(y, 7);
}
```

不定长数组：

```rust
fn main() {
    let arr:&[u16; 2] = &[2, 7];

    if let [x, ..] = arr {
        println!("x={}", x);
    }

    if let [.., y] = arr {
        println!("y={}", y);
    }

    let arr:&[u16] = &[];

    assert!(matches!(arr, [..]));
    assert!(!matches!(arr, [x, ..]));
}
```



#### 2.6.4.5 忽略模式中的值

`_`：忽略值，完全不会绑定

`_x`：未被使用的值不警告，仍会绑定值到变量

```rust
// s 是一个拥有所有权的动态字符串，因为 s 的值会被转移给 _s，在 println! 中再次使用 s 会报错
fn main() {
    let s = Some(String::from("hello"));

    // value partially moved here
    if let Some(_s) = s {
        println!("found a string");
    }

    // value borrowed here after partial move
    println!("{:?}", s);
}

// 只使用下划线本身，则并不会绑定值，因为 s 没有被移动进 _
fn main() {
    let s = Some(String::from("hello"));

    if let Some(_) = s {
        println!("found a string");
    }

    // ok
    println!("{:?}", s);
}
```



`..`：忽略剩余值

```rust
fn main() {
    let arr = [1, 2, 3, 4, 5];
    match arr {
        [first, .., last] => {
            println!("first={}, last={}", first, last);
        }
    }

    let tuple = (1, 4, 9, 16, 25);
    match tuple {
        (first, ..) => {
            println!("first={}", first);
        }
    }
}
```



#### 2.6.4.6 匹配守卫

**匹配守卫**（*match guard*）是一个位于 `match` 分支模式之后的额外 `if` 条件，它能为分支模式提供更进一步的匹配条件

```rust
fn main() {
    let x = Some(6);
    let y = 10;

    match x {
        Some(50) => println!("got 50"),
        Some(n) if n > 5 => println!("n={} is more than 5", n),
        Some(n) if n == y => println!("matched, n={}", n),
        _ => println!("default case, x={:?}", x),
    }
}
```



### 2.6.5 @绑定

`@` 运算符允许为一个字段绑定另外一个变量

```rust
enum Message {
    Hello {id: i32},
}

fn main() {
    let msg = Message::Hello {id: 8};

    match msg {
        Message::Hello {id: id_var @ 3..=7 } => {
            println!("find a id in range: {}", id_var);
        },
        Message::Hello {id: 10..=12 } => {
            println!("find a id in another range");
        },
        Message::Hello {id} => {
            println!("find some other id: {}", id);
        },
    }
}
```



简单示例：

```rust
fn main() {
    let x = 3;

    match x {
        e @ 1..=5 => println!("got a range element {}", e),
        _ => println!("anything"),
    }
}
```



### 2.6.6  使用 ref 取得引用

```rust
fn main() {
    let (x, y) = (5, 6);

    match x {
        ref r => println!("got a reference to {}", r),
    }

    match y {
        ref r => println!("got a reference to {}", r),
    }
}
```



## 2.7 方法

方法一般与结构体、枚举、特性(trait) 一起使用



### 2.7.1 定义方法(impl)

```rust
pub struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    // 关联函数，不带self
    pub fn new(width: u32, height: u32) -> Rectangle {
        Rectangle {
            width,
            height,
        }
    }

    pub fn area(&self) -> u32 {
        self.width * self.height
    }

    // getter
    pub fn width(&self) -> u32 {
        self.width
    }

    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }
}

fn main() {
    let r = Rectangle::new(5, 7);
    println!("area={}", r.area());
    println!("width={}", r.width());

    let r2 = Rectangle::new(4, 5);
    println!("{}", r.can_hold(&r2));
}
```

关于 self：

- `self`：表示实例的所有权转移到该方法中，较少使用
- `&self`：表示该方法对实例的不可变借用

- `&mut self`：表示可变借用



## 2.8 泛型和特性

### 2.8.1 泛型 Generics

#### 2.8.1.1 泛型是什么

泛型就是一种多态。泛型主要目的是为程序员提供编程的便利，减少代码的臃肿，同时可以极大地丰富语言本身的表达能力。

```rust
fn add<T: std::ops::Add<Output = T>>(x: T, y: T) -> T {
    x + y
}

fn main() {
    println!("add i8: {}", add(3i8, 5i8));
    println!("add i32: {}", add(14, 9));
    println!("add f64: {}", add(1.5f64, 3.1f64));
}
```

示例2：

```rust
fn largest<T: std::cmp::PartialOrd>(list: &[T]) -> &T {
    let mut max= &list[0];

    for item in list.iter() {
        if item > max {
            max = item;
        }
    }

    max
}


fn main() {
    let number_list = vec![32, 17, 25, 68, 23];
    let result = largest(&number_list);
    println!("the largest number in list: {}", result);

    let char_list = vec!['a', 'z', 'g', 'x'];
    let result = largest(&char_list);
    println!("the largest char in list: {}", result);
}
```





### 2.8.2 特性 Trait





















- 指针：最底层的是裸指针`*const T`和`*mut T`，但解引用它们是不安全的，必须放到`unsafe`块里。

- 函数：具有函数类型的变量实质上是一个函数指针。

- 元类型：即`()`，其唯一的值也是`()`。



- 





```rust


// string
let s = "hello, world!";       // &str
let s1 = s.to_string();        // String
let s2 = String::from("ok");   // String



// raw pointers
let x = 3;
let raw = &x as *const i32;
let p = unsafe { *raw };
let raw2: *const i32 = &x;
let p2 = unsafe { *raw2 };

// function
fn foo(x: i32) -> i32 { x };
let bar: fn(x: i32) -> i32 = foo;
```

特殊用法：

- 单字节字符 `b'H'`，单字节字符串 `b"hello"`，仅限于ASCII字符
- 原始字符串 `r#"..."#`，不需要对特殊字符进行转义
- 使用 & 将 String 转换为 `&str` 不涉及分配内存，但使用 `to_string()` 将 `&str` 转换为 String 则需要分配内存
- 数组的长度是不可变的，动态的数组称为向量(vector)，可使用宏 `vec!` 来创建
- 元组可通过 == 及 != 来判断是否相同
- 小于等于32个元素的数组、小于等于12个元素的元组，在值传递时自动复制
- 原生类型不支持隐式转换，需要使用 as 关键字显式转换
- type 关键字定义类型的别名，采用驼峰命名法

```rust
// explicit conversion
let decimal = 65.4321_f32;
let integer = decimal as u8;
let character = integer as char;

// type alias
type NanoSecond = u64;
type Point = (u8, u8);
```











## 2.6 注释

- 单行注释：以 // 开始

- 块注释：`/*  */`
- 文档注释：`///` 或 `//!`，支持 Markdown 语法，配合 rustdoc 自动生成说明文档
  - `///` 等价于属性 `#[doc = "..."]`
  - `//!` 等价于 `#[doc = "/// ..."]`







# 4. 模块系统

模块系统：

- 包 Packages：cargo 提供的创建、测试及分享 Crates 的工具。
- 箱 Crates：提供类库或可执行文件的模块树，与其他语言中的library 或 package 作用一样
- 模块 Modules：管理和组织路径，及其作用域和访问权限
- 路径 Paths：结构体、函数、模块等事物的命名方式



## 4.1 Packages & Crates

包(Package) 通过 Cargo 创建，每一个包都有一个 `Cargo.toml` 文件，包中箱(Crates)的规则：

- 只能包含0或1个类库箱(library crates)
- 可以包含任意多个二进制箱(binary crates)

创建二进制包(binary package):

```bash
❯ cargo new my-project
     Created binary (application) `my-project` package
❯ tree my-project
my-project
├── Cargo.toml
└── src
    └── main.rs
```

创建类库包(library package):

```bash
❯ cargo new --lib my-lib
     Created library `my-lib` package
❯ tree my-lib
my-lib
├── Cargo.toml
└── src
    └── lib.rs
```

默认，一个箱(crate):

- src/main.rs 二进制箱(binary crate)的根文件
- src/lib.rs 类库箱(library crate)的根文件

多个二进制箱(binary crates)：在src/bin 目录下创建 `.rs` 文件，每个文件对应一个二进制箱(binary crate)



## 4.2 Moddules

通过关键字 mod 识别

```rust
// Filename: src/lib.rs 

mod front_of_house {
    mod hosting {
        fn add_to_waitlist() {}

        fn seat_at_table() {}
    }

    mod serving {
        fn take_order() {}

        fn serve_order() {}

        fn take_payment() {}
    }
}
```

文件 src/main.rs 和 src/lib.rs，对应的模块是 crate，箱(crate)的模块结构(module structure)，也叫模块树(module tree)：

```text
crate
 └── front_of_house
     ├── hosting
     │   ├── add_to_waitlist
     │   └── seat_at_table
     └── serving
         ├── take_order
         ├── serve_order
         └── take_payment
```

:warning:模块 crate 默认存在，不需要通过关键字 mod 来定义



## 4.3 Paths

箱(crate)的根节点是 `crate`

- 绝对路径：从箱的根节点开始，箱的名称或crate
- 相对路径：从当前模块开始，可以使用 self 或 super

```rust
// 绝对路径 Absolute path
crate::front_of_house::hosting::add_to_waitlist();

// 相对路径 Relative path
front_of_house::hosting::add_to_waitlist();
```



## 4.4 访问权限

- 所以元素，函数functions、方法methods、结构体structs、枚举enum、模块modules，常量constants，默认都是私有的；对外公开，需要使用关键字 pub 声明
  - 公共结构体(public structs)，内部的元素(fields)和方法(methods)仍是私有的(private)
  - 公共枚举(public enums)，其所有变量(variants)都是公共的(public)
- 父模块中的元素，不能使用子模块中的私有元素
- 子模块中的元素，可以使用父模块元素(不论公有还是私有)



## 4.5 use

使用 use 关键字简化路径 paths

调用其他模块函数，通过 use 引入其所在的模块(module)

```rust
use some_mod;

fn main() {
    some_mod::some_fn();
}
```

调用其他模块结构体、枚举等，通过全路径引入：

```rust
use std::collections::HashMap;

fn main() {
    let mut map = HashMap::new();
    map.insert(1, 2);
}
```

有命名冲突时，引入父模块：

```rust
use std::fmt;
use std::io;

fn function1() -> fmt::Result {
    // --snip--
}

fn function2() -> io::Result<()> {
    // --snip--
}
```

使用 as 解决命名冲突：

```rust
use std::fmt::Result;
use std::io::Result as IoResult;

fn function1() -> Result {
    // --snip--
}

fn function2() -> IoResult<()> {
    // --snip--
}
```

引入同一个模块或包中的多个元素：

```rust
use std::{cmp::Ordering, io};
use std::io::{self, Write};
```

映入模块下所以公共元素(谨慎使用)：

```rust
use std::collections::*;
```



## 4.6 外部包

在 `Cargo.toml` 文件下的 `[dependencies]` 下添加，Cargo 会自动下载所需的依赖包

```toml
[dependencies]
rand = "0.8.5"
```



## 4.7 示例

### 4.7.1 定义模块

**Step 1**：创建 Crate，类型 library

```bash
cargo new phrases --lib

mkdir -p phrases/src/{chinese,english}
```



**Step 2**：函数定义-1

```rust
// src/chinese/greetings.rs
pub fn hello() -> String {
    "你好！".to_string()
}

// src/chinese/farewells.rs
pub fn goodbye() -> String {
    "再见！".to_string()
}

// src/chinese/mod.rs
pub mod greetings;
pub mod farewells;
```



**Step 3**：函数定义-2

```rust
// src/english/greetings.rs
pub fn hello() -> String {
    "Hello!".to_string()
}

// src/english/farewells.rs
pub fn goodbye() -> String {
    "Goodbye".to_string()
}

// src/english/mod.rs
pub mod greetings;
pub mod farewells;
```



**Step 4**：模块定义

```rust
// src/lib.rs
pub mod chinese;
pub mod english;
```



### 4.7.1 导入 Crate

**Step 1**：创建 Crate，类型 binary

```bash
cargo new basic-03 --bin
```



**Step 2**：配置本地依赖

修改 Cargo.toml 文件

```toml
[dependencies]
phrases = { path = "../phrases" }
```



**Step 3**：引用模块

```rust
extern crate phrases;

use phrases::chinese::greetings;
use phrases::chinese::farewells::goodbye;
use phrases::english::greetings::hello as english_greetings;
use phrases::english::farewells::goodbye as english_farewells;

fn main() {
    println!("Hello in chinese: {}", greetings::hello());
    println!("Goodbye in chinese: {}", goodbye());
    println!("Hello in english: {}", english_greetings());
    println!("Goodbye in english: {}", english_farewells());
}
```



## 4.8 属性

在 Rust 中，属性 (attribute) 是应用于包装箱、模块或条目的元数据(metadata)，其主要作用如下：

- 实现条件编译 (conditional compilation)
- 设置包装箱名称、版本及类型
- 取消可疑代码的警告
- 设置编译器选项
- 链接外部库
- 标记测试函数



属性的两个语法：

- `#![attribute ???]` 应用于整个包装箱
- `#[attribute ???]` 应用于紧邻的一个模块或条目



属性参数的三种不同形式：

- `#[attribute = "value"]`
- `#[attribute(key = "value")]`
- `#[attribute(value)]`



常见属性：

- `#[path="foo.rs"]`   设置一个模块需要载入的文件路径
- `#[allow(dead_code)]` 取消对未使用代码的默认lint检查
- `#[derive(PartialEq, Clone)]` 自动推导`PartialEq`和`Clone` 特性的实现
- `#[derive(Debug)]`  支持使用 `println!("{:?}", s)` 打印struct
- `#[derive(Default)]`  struct中的属性使用默认值零值



# 5. 程序测试

## 5.1 测试属性

- `#[test]` 测试属性

- `#[should_panic]` 反转测试失败
- 宏`assert!`接受一个参数，如果为 false，则 panic

```rust
#[test]
fn it_works() {
    assert!(false);
}

#[test]
#[should_panic(expected = "assertion failed")]
fn it_works_2() {
    assert_eq!("hello", "world");
}
```



## 5.2 测试模块

测试模块前添加 `#[cfg(test)]` 属性

```rust
pub fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod test {
    use super::add_two;

    #[test]
    fn it_works() {
        assert_eq!(4, add_two(2));
    }
}
```



## 5.3 测试目录

对于集成测试，可新建一个 tests 目录，这样其中的代码就不需要再引入单元风格的测试模块了



## 5.4 文档测试

```rust
/// This function adds two to its argument.
///
/// # Examples
///
/// ```
/// use phrases::add_two;
///
/// assert_eq!(4, add_two(2));
/// ```
pub fn add_two(a: i32) -> i32 {
    a + 2
}
```



## 5.5 错误处理

Rust 中两种形式的错误：

- 失败(failure)：可通过某种方式恢复
- 恐慌(panic)：不可恢复



通过 `Option<T>` 类型表明函数可能会失败：

```rust
fn from_str<A: FromStr>(s: &str) -> Option<A> {
    
}
```

函数 `from_str()` 返回一个 `Option<A>` ：

- 转换成功，返回 Some(value)
- 转换失败，返回 None

对需要提供出错信息的情形，可使用 `Result<T, E>` 类型

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

如果不想出来错误我，可使用 unwrap() 方法来产生 panic：

```rust
let mut buffer = String::new();
let input = io::stdin().read_line(&mut buffer).unwrap();
```

当 Result 是 Err 时，unwrap() 会 panic，直接退出程序。更好的做法：

```rust
let input = io::stdin().read_line(&mut buffer)
			           .ok()
                       .except("Failed to read line");
```

其中`ok()`将`Result`转换为`Option`，`expect()`和`unwrap()`功能类似，可以用来提供更多的错误信息。

还可以使用宏`try!`来封装表达式，当`Result`是`Err`时会从当前函数提早返回`Err`



# 6. 内存安全

Rust 推崇安全和速度至上，它没有垃圾回收机制，却成功实现了内存安全(memory safety)



## 6.1 所有权

所有权(ownership)系统时零成本抽象(zero-cost abstraction)的一个主要例子。对所有权的分析在编译阶段就完成，并不带来任何运行时成本(run-time cost)

默认情况下，Rust在栈(stack)上分配内存，对栈空间变量的再赋值都是复制的；如果在堆(heap)中分配，则必须使用盒子来构造。

```rust
fn main() {
    let x = Box::new(5);

    add_one(x);

    // error[E0382]: borrow of moved value: `x`
    println!("x: {}", x);
}

fn add_one(mut n: Box<i32>) {
    *n += 1;
}
```

`Box::new()` 创建了一个 `Box<i32>` 来存储整数 5，此时变量 x 具有该盒子的所有权。当 x 退出代码块的作用域时，它所分配的内存资源将随之释放，上述操作由编译器自动完成。

调用 `add_one()` 时，变量 x 的所有权被转移(move)给了变量 n (所有权转移时，可变性也随之发生变化)。`add_one()`执行完成后，n 占用的内存将自动释放。

当 `println!` 再次使用已经没有所有权变量 x 时，编译器将会报错。

解决方法：

- 修改 `add_one()` 函数使其返回 Box，将所有权转移回来
- **引入所有权借用(borrowing)**



## 6.2 借用

在 Rust 中，所有权的借用通过引用 `&` 来实现：

```rust
fn main() {
    let mut x= 5;

    add_one(&mut x);

    println!("x: {}", x);
}

fn add_one(n: &mut i32) {
    *n += 1
}
```

调用 `add_one()` 时，变量 `x` 把它的所有权以**可变引用**借给了变量 n，函数完成后，n 又把所有权还给了 x。如果以不可变引用借出，则借出者只能读而不能改。

借用需要注意点：

- 变量、函数、闭包以结构体都可以成为借用者
- 一个资源只能有一个所有者，但可以有多个借用者
- 资源**以可变借出，所有者将不能再次访问资源，也不能再借给其他绑定**
- 资源**以不可变借出，所有者不能再改变资源，也不能再以可变形式借出，但可以以不变形式继续借出**



## 6.3 生存期

通过生存期(lifetime)来确定一个引用的作用域：

```rust
struct Foo<'a, 'b> {
    x: &'a i32,
    y: &'b i32,
}

fn test_lifetime() {
    let a = &5;
    let b = &8;
    let f = Foo{x: a, y: b};

    println!("{}", f.x + f.y);
}
```

结构体 Foo 有自己的生存期，需要给它的所包含的域治的新的生存期 `'a` 和`'b`，确保对 i32 的引用比 对 Foo 的引用具有更长的生存期，避免悬空指针(dangling pointer) 问题



Rust 预定义的 `'static` 具有和整个程序运行时相同的生存期，主要用于声明全局变量。常量(const) 也具有 `'static` 生存期，但它们会被内联到使用它们的地方。

```rust
const N: i32 = 5;

static NUML i32 = 5;
static NAME: &'static str = "Jack";
```

使用生存期时，类型标注不可省略，并且必须使用常量表达式初始化。

通过 `static mut` 绑定的变量，则只能再 unsafe 代码块中使用。



共享所有权，需要使用标准库的 `Rc<T>` 类型：

```rust
use std::rc::Rc;

struct Car {
    name: String,
}

struct Wheel {
    size: i32,
    owner: Rc<Car>,
}

fn main() {
    let car = Car{name: "DeLorean".to_string() };

    let car_owner = Rc::new(car);

    for _ in 0..4 {
        Wheel{size: 360, owner: car_owner.clone()};
    }
}
```

如果再并发中共享所有权，则需要使用线程安全的 `Arc<T>` 类型。

Rust 支持生存周期省略(lifetime elision)，它允许在特定情况下不写生存周期标记，此时会遵循三条规则：

- 每个被省略生存期标记的函数参数具有各不相同的生存期
- 如果只有一个输入生存期(input lifetime)，那么不管它是否省略，该生存期都会赋给函数返回值中所有被省略的生存期
- 如果有多个输入生存期，并且其中一个是 `&self` 或 `mut self` ，那么 self 的生存期会赋给所有被省略的输出生存期(output lifetime)



# 7. 编程范式

Rust 是一个多范式(multi-paradigm) 的编译型语言，支持结构化、命令式编程外，还支持如下范式

## 7.1 函数式编程

使用闭包(closure)创建匿名函数：

```rust
fn main() {
    let num = 5;
    let plus_num = |x: i32| x+num;

    println!("{}", plus_num(3));
}
```

其中，闭包 `plus_num` 借用了它作用域中 的 let 绑定 num。

如果要让闭包获得所有权，可使用 move 关键字：

```rust
fn main() {
    let mut num = 5;

    {
        let mut add_num = move |x: i32| num += x;
        add_num(3);
        println!("{num}") // 5
    }

    assert_eq!(num, 5)
}
```



高级函数(high order function)，允许把闭包作为参数来生成新的函数：

```rust
fn add_one(x: i32) -> i32 { x + 1 }

fn apply<F>(f: F, y: i32) -> i32
    where F: Fn(i32) -> i32 {
    f(y) * y
}

fn factory(x: i32) -> Box<dyn Fn(i32) -> i32> {
    Box::new(move |y| x+y)
}

fn main() {
    let transform: fn(i32) -> i32 = add_one;
    let f0 = add_one(2) * 2;
    let f1 = apply(add_one, 2);
    let f2 = apply(transform, 2);
    println!("{}, {}, {}", f0, f1, f2);

    let closure = |x: i32| x + 1;
    let c0 = closure(2) * 2;
    let c1 = apply(closure, 2);
    let c2 = apply(|x| x + 1, 2);
    println!("{}, {}, {}", c0, c1, c2);

    let box_fn = factory(1);
    let b0 = box_fn(2) * 2;
    let b1 = (*box_fn)(2) * 2;
    let b2 = (&box_fn)(2) * 2;
    println!("{}, {}, {}", b0, b1, b2);

    let add_num = &(*box_fn);
    let translate: &dyn Fn(i32) -> i32 = add_num;
    let z0 = add_num(2i32) * 2;
    let z1 = apply(add_num, 2);
    let z2 = apply(translate, 2);
    println!("{}, {}, {}", z0, z1, z2);
}
```



## 7.2 面向对象编程

Rust 通过 `impl` 关键字在 `struct`、`enum` 及 `trait` 对象上实现方法调用语法(method call syntax)。

关联函数(associated function)的第一个参数通常为 self，有三种变体：

- `self` 允许实现者移动和修改对象，对应的闭包特性为 `FnOnce`
- `&self` 既不允许实现者移动对象也不允许修改，对应的闭包特性为 `Fn`
- `&mut self` 允许实现者修改但不允许移动，对应的闭包特性为 `FnMut`

不含 self 参数的关联函数称为静态方法(static method)

```rust
struct Circle {
    x: f32,
    y: f32,
    radium: f32,
}

impl Circle {
    fn new(x: f32, y: f32, radium: f32) -> Circle {
        Circle {x, y, radium}
    }

    fn area(self) -> f32 {
        std::f32::consts::PI * self.radium * self.radium
    }
}

fn main() {
    let c = Circle::new(0.0, 0.0, 5.0);
    println!("{}", c.area())
}
```



为了描述类型可以实现的抽象接口(abstract interface)，Rust引入了特性 (trait) 来定义函数类型签名 (function type signature):

```rust
trait HasArea {
    fn area(&self) -> f64;
}

struct Circle {
    x: f64,
    y: f64,
    radium: f64,
}

impl HasArea for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radium * self.radium
    }
}

struct Square {
    x: f64,
    y: f64,
    side: f64,
}

impl HasArea for Square {
    fn area(&self) -> f64 {
        self.side * self.side
    }
}

fn print_area<T: HasArea>(shape: T) {
    println!("This shape has an area of {}", shape.area())
}

fn main() {
    let c = Circle{x: 0.0, y: 0.0, radium: 3.0};
    print_area(c);

    let s = Square{x: 0.0, y: 0.0, side: 5.0};
    print_area(s);
}
```

其中，函数 `print_area()` 中的泛函参数 T 被添加了一个名为 HasArea 的特性约束 (trait constraint)，用以确保任何实现了 HasArea 的类型将拥有一个 `.area()` 方法。

如果需要多个特性限定(multiple trait bounds)，可以使用 `+`:

```rust
fn foo<T: Clone, K: Clone + Debug>(x: T, y: K) {
    let _ = x.clone();
    let _ = y.clone();
    println!("{:?}", y)
}

fn bar<T, K>(x: T, y: K)
    where T: Clone,
          K: Clone + Debug {
    let _ = x.clone();
    let _ = y.clone();
    println!("{:?}", y)
}
```

其中第二个例子使用了更灵活的 where 从句，它允许限定的左侧可以是任意类型，而不仅仅是类型参数。

定义在特性中的方法称为默认方法(default method)，可以被该特性的实现覆盖。此外，特性之间也可以存在继承(inheritance)：

```rust
trait Foo {
    fn foo(&self);

    // default method
    fn bar(&self) { println!("we called bar") }
}

trait FooBar: Foo {
    fn foobar(&self);
}

struct Baz;

impl Foo for Baz {
    fn foo(&self) {
        println!("foo")
    }
}

impl FooBar for Baz {
    fn foobar(&self) {
        println!("foobar")
    }
}

fn main() {
    let baz = Baz{};

    baz.foo();
    baz.bar();
    baz.foobar()
}
```

如果两个不同特性的方法具有相同的名称，可以使用通用函数调用语法(universal function call syntax)：

```rust
// short-hand form
Trait::method(args);

// expanded form
<Type as Trait>::method(args);
```

实现特性的几条限制：

- 如果一个特性不在当前作用域内，它就不能被实现
- 不管是特性还是 impl，都只能在当前的包装箱内起作用
- 带有特性约束的泛型函数使用单态(monomorphization)，所以它是静态派发的(statically dispatched)

常见非常有用的标准库特性：

- `Drop` 提供了当一个值退出作用域执行代码的功能，它只有一个 `drop(&mut self)` 方法。
- `Borrow` 用于创建一个数据结构时把拥有和借用的值看作等同。
- `AsRef` 用于在泛型中包一个值转换为引用。
- `Deref<Target=T>` 用于把 `&U` 类型的值自动转换为 `&T` 类型
- `Interator` 用于在集合(collection) 和懒性值生成器(lazy value generator) 上实现迭代器
- `Sized` 用于标记运行时长度固定的类型，而不定长的切片和特性必须放在指针后面使其运行时长度已知，比如 `&[T]` 和 `Box<Trait>`



## 7.3 元编程

泛型(generics)也被称为参数多态(parametric polymorphism)，意味着对应给定参数可以有多种形式的函数或类型。

```rust
enum Option<T> {
    Some(T),
    None,
}

let x: option<i32> = Some(5);
let y: Option<f64> = Some(5.0f64);
```

其中 `<T>` 部分表明它是一个泛型数据类型。

泛型参数用于函数参数和结构体域：

```rust
// generic functions
fn make_pair<T, U>(a: T, b: U) -> (T, U) {
    (a, b)
}

let couple = make_pair("man", "female");

// generic structs
struct Point<T> {
    x: T,
    y: T,
}

let int_origin = Point { x: 0, y: 0 };
let float_origin = Point{ x: 0.0, y: 0.0 };
```



对于多态函数，存在两种派分(dispath)机制：

- 静态派分：类似C++的模板，Rust会生成适用于指定类型的特殊函数，然后在被调用的位置进行替换，好处是允许函数被内联调用，运行比较快，但是会导致代码膨胀(code bloat)
- 动态派分：类型Java或Go的 interface，Rust通过引入特性对象(trait object)来实现，在运行时查找虚表(vtable)来选择执行的方法。特性对象 `&Foo` 具有和特性 `Foo` 相同的名称，通过转换 (casting) 或者强制多态化 (coercing) 一个指向具体类型的指针来创建。



特性也可以接受泛型参数，但更好的处理方式是使用关联类型 (associated type)：

```rust
// use generic parameters
trait Graph<N, E> {
    fn has_edge(&self, &N, &N) -> bool;
    fn edges(&self, &N) -> Vec<E>;
}

fn distance<N, E, G: Graph<N, E>>(graph: &G, start &N, end: &N) -> u32 {
    
}

// use associated types
trait Graph {
    type N;
    type E;
    
    fn has_edge(&self, &Self::N, &Self::N) -> bool;
    fn edges(&self, &Self::N) -> Vec<Self::E>;
}

fn distance<G: Graph>(graph: &G, start: &G::N, end: &G::N) -> uint {
    
}

struct Node;

struct Edge;

struct SimpleGraph;

impl Graph for SimpleGraph {
    type N = Node;
    type E = Edge;
    
    fn has_edge(&self, n1: &Node, n2: &Node) -> bool {
        
    }
    
    fn edges(&self, n: &Node) -> Vec<Edge> {
        
    }
}

let graph = SimpleGraph;
let object = Box::new(graph) as Box<Graph<N=Node, E=Edge>>;
```



Rust 中的宏 (macro) 是在语法级别上的抽象，`vec!` 宏的实现：

```rust
macro_rules! vec {
    ( $( $x:expr ), * ) => {
        {
            let mut temp_vec = Vec::new();
            $(
            	temp_vec.push($x);
            )*
            temp_vec
        }
    };
}
```

解析：

- `=>`左边的 `$x:expr` 模式是一个匹配器 (matcher)， `$x` 是元变量  (metavariable)， `expr` 是片段指定符 (fragment specifier)。匹配器写在 `$(...)` 中，`*` 会匹配0或多个表达式，表达式之间的分隔符为逗号。
- `=>` 右边的外层大括号只是用来界定整个右侧结构的，也可以使用`()` 或  `[]`，左边的外层小括号也类似。扩展中的重复域匹配器中的重复会同步进行：每个匹配的`$x` 都会在宏扩展中产生一个单独的 `push` 语句。



## 7.4 并发计算

Rust 提供两个特性来处理并发(concurrency)：`Send` 和 `Sync`。

当一个 `T` 类型：

- 实现 `Send`，该类型的所有权可以在进程间安全地转移；
- 实现 `Sync`，该类型在多线程并发时能够确保内存安全；

标准库 `std::thread` 并发执行：

```rust
use std::thread;

fn main() {
    let handle = thread::spawn(|| {
        println!("Hello from a thread");
    });

    println!("{:?}", handle.join().unwrap())
}
```



解决可变状态的共享问题，通过所有权系统来帮助排除数据竞争 (data race)：

```rust
use std::sync::{Arc, mpsc, Mutex};
use std::thread;

fn main() {
    let data = Arc::new(Mutex::new(0u32));

    // Creates a shared channel that can be sent along from many threads
    // where tx is the sending half
    // and rx is the receiving half
    let (tx, rx) = mpsc::channel();

    for i in 0..10 {
        let (data, tx) = (data.clone(), tx.clone());

        thread::spawn(move || {
            let mut data = data.lock().unwrap();
            *data += i;

            tx.send(*data).unwrap();
        });
    }

    for _ in 0..10 {
        print!("{:?} ", rx.recv().unwrap());
    }
}
```

类型说明：

- `Arc<T>` 类型是一个原子引用计数指针 (atomic reference counted pointer) ，实现了`Sync`，可安全地跨线程共享。 
- `Mutex<T>`  类型提供了互斥锁 (mutex's lock)，同一时间只允许一个线程能修改它的值。
- `mpsc::channel()`  方法创建了一个通道 (channel)，来发送任何实现了 `Send` 的数据。
- `Arc<T>` 的 `clone()` 方法用来增加引用计数，而当离开作用域时，计数减少。



# 8. 高级主题

## 8.1 FFI

### 8.1.1 调用C库

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



### 8.1.2 编译成C库

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













