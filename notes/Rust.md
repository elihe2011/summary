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



# 2. 数据类型

原生类型 (primitive types) ：

- 布尔类型：`true`和`false`
- 字符类型：单个Unicode字符，存储为4个字节
- 数值类型：
  - 有符号整数 (`i8`, `i16`, `i32`, `i64`, `isize`)
  - 无符号整数 (`u8`, `u16`, `u32`, `u64`, `usize`) 
  - 浮点数 (`f32`, `f64`)
  - isize 和 usize 两种整数类型是用来衡量数据大小的，它们的位长度取决于所运行的目标平台，如果是 32 位架构的处理器将使用 32 位位长度整型。
- 字符串类型：最底层的是不定长类型`str`，更常用的是字符串切片`&str`和堆分配字符串`String`，
  其中字符串切片是静态分配的，有固定的大小，并且不可变，而堆分配字符串是可变的。
- 数组：具有固定大小，并且元素都是同种类型，可表示为`[T; N]`。
- 切片：引用一个数组的部分数据并且不需要拷贝，可表示为`&[T]`。
- 元组：具有固定大小的有序列表，每个元素都有自己的类型，通过解构或者索引来获得每个元素的值。
- 指针：最底层的是裸指针`*const T`和`*mut T`，但解引用它们是不安全的，必须放到`unsafe`块里。
- 函数：具有函数类型的变量实质上是一个函数指针。
- 元类型：即`()`，其唯一的值也是`()`。



控制语句：

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



```rust
fn main() {
    let mut num = 3;

    while num > 0 {
        println!("num = {num}");

        num -= 1;
    }

    println!("done")
}
```



```rust
fn main() {
    let a = [1, 2, 3, 4, 5];
    for e in a {
        print!("{e} ")
    }
    println!();

    for e in (10..15).rev() {
        print!("{e} ")
    }
    println!();
}
```



字符串操作：

```rust
fn main() {
    let s1 =  String::from("hello");
    let s2 = s1.clone();

    println!("{s1}");
    println!("{s2}");
}
```

