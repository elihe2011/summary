# 1. Hello Tokio

## 1.1 准备操作

```bash
# 安装 mini-redis
cargo install mini-redis

# 启动 mini-redis
mini-redis-server
mini-redis-cli get hello  # 测试

# 创建应用
cargo new my-redis
cd my-redis

# 添加依赖
vi Cargo.toml
...
[dependencies]
tokio = { version = "1", features = ["full"]}
mini_redis = "0.4"
```



## 1.2 编写代码

```rust
use mini_redis::{ client, Result};

#[tokio::main]
async fn main() -> Result<()> {
    let mut client = client::connect("127.0.0.1:6379").await?;

    client.set("hello", "world".into()).await?;

    let result = client.get("hello").await?;

    println!("get value = {:?}", result);

    Ok(())
}
```



## 1.3 异步编程

同步编程，当程序遇到不能立即完成的操作时，会阻塞，直到操作完成；

异步编程，不能立即完成的操作被暂时停在后台。线程没有被阻塞，可以继续运行其他事情。一旦操作完成，任务就会被取消暂停，并继续从它离开的地方处理。



## 1.4 async / await

`async fn` 的返回值时一个匿名雷昕，它实现了 Future trait

```rust
async fn say_world() {
    println!("world");
}

#[tokio::main]
async fn main() {
    // not execute
    let op = say_hello();
    
    println!("hello");
    
    // start executing
    op.await;
}
```



## 1.5 异步 main 函数

特征：

- 修饰符：`async fn`，进入异步上下文，然后异步函数由一个运行时来执行，运行时包含异步任务调度器，提供事件化 I/O、计时器等。
- 加注解：`#[tokio::main]` 是一个宏，将 `async fn main()` 转换为同步 `fn main()`，初始化以恶搞运行时并执行异步main函数。

```rust
#[tokio::main]
async fn main() {
    println!("hello");
}
```

转换为：

```rust
fn main() {
    let mut rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        println!("hello");
    })
}
```



# 2. spawning

## 2.1 接收套接字

准备操作：

```bash
# 创建工程
cargo new hello-redis

# 添加依赖
```

编写服务器：

```rust
use tokio::net::{TcpListener, TcpStream};
use mini_redis::{Connection, Frame};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await.unwrap();
        process(socket).await;
    }
}

async fn process(socket: TcpStream) {
    let mut connection = Connection::new(socket);

    if let Some(frame) = connection.read_frame().await.unwrap() {
        println!("GOT: {:?}", frame);

        let response = Frame::Error("unimplemented".to_string());
        connection.write_frame(&response).await.unwrap();
    }
}
```



## 2.2 并发

loop 循环中，一次处理一个入站请求。单一个连接被接受时，服务器停留在接受循环块内，直到响应被完全写入套接字。

为并发地处理连接，为每个入站连接生成一个新的任务，连接在这个任务中被处理。

```rust
#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (socket, _) = listener.accept().await.unwrap();

        // 生成任务
        tokio::spawn(async move {
            process(socket).await;
        });
    }
}
```



### 2.2.1 任务

Tokio 任务是一个异步绿色线程。它们通过传递一个异步块给 `tokio::spawn` 来创建。`tokio::spawn` 函数返回 JoinHandle，调用者可以用它来与生成的任务进行交互。该异步块可以有一个返回值。调用者可以使用 JoinHandle 上的 `.await` 获取返回值。

```rust
#[tokio::main]
aysnc fn main() {
    let handle = tokio::spawn(async {
        // Do some async work
        "return value"
    });
    
    // Do some other work
    
    let out = handle.await.unwrap();
    println!("GOT {}", out);
}
```

对 JoinHandle 的等待会返回一个 Result。当任务在执行过程中遇到错误时，JoinHandle 将返回 Err。这发生在任务 panic 或任务被运行时关闭而强行取消时。

任务是由调度器管理的执行单位。生成的任务提交给 Tokio 调度器，然后确保该任务在有工作要做时执行。生成的任务可以被它生成的同一线程上执行，也可以在不同的运行时线程上执行。任务在被催生后也可以在线程之间移动。

Tokio 的任务非常轻便，它们只需要一次分配和64字节的内存。应用程序可以自由地生成数千，甚至数百万个任务。



### 2.2.2 `'static bound`

当在 tokio 运行时产生一个任务时，它的类型必须是 `'static` 的，这意味着生成的任务不能包含对任务之外拥有的数据的任何引用。

以下内容无法编译：

```rust
use tokio::task;

#[tokio::main]
async fn main() {
    let v = vec![1, 2, 3];
    
    task::spawn(async {
        println!("Here's a vec: {:?}", v);
    });
    
    // 修改成
    task::spawn(async move {
        println!("Here's a vec: {:?}", v);
    });
}
```

如果数据被多个任务同时访问，必须使用同步原语(如Arc)进行共享。



### 2.2.3 Send bound

由 `tokio::spawn` 产生的任务必须实现 Send。这允许 tokio 运行时在线程之间 move 任务，而这些任务在一个 `.await` 中被暂停。

当所有跨 `.await` 调用的数据都是 Send 时，任务就是 Send。

```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        // The scope forces `rc` to drop before `.await`
        {
            let rc = Rc::new("Hello");
            println!("{}", rc);
        }
        
        // `rc` is no longer used, It is **not** persisted when
        // the task yield to the scheduler
        yield_now().await;
    });
}
```

这并不是：

```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        let rc = Rc::new("Hello");
        
        // `rc` is used after `.await`, It must be persisted to
        // the task's state
        yield_now().await;
        
        println!("{}", rc);
    });
}
```

编译错误：

```
error: future cannot be sent between threads safely
   --> src/main.rs:6:5
    |
6   |     tokio::spawn(async {
    |     ^^^^^^^^^^^^ future created by async block is not `Send`
    | 
   ::: [..]spawn.rs:127:21
    |
127 |         T: Future + Send + 'static,
    |                     ---- required by this bound in
    |                          `tokio::task::spawn::spawn`
    |
    = help: within `impl std::future::Future`, the trait
    |       `std::marker::Send` is not  implemented for
    |       `std::rc::Rc<&str>`
note: future is not `Send` as this value is used across an await
   --> src/main.rs:10:9
    |
7   |         let rc = Rc::new("hello");
    |             -- has type `std::rc::Rc<&str>` which is not `Send`
...
10  |         yield_now().await;
    |         ^^^^^^^^^^^^^^^^^ await occurs here, with `rc` maybe
    |                           used later
11  |         println!("{}", rc);
12  |     });
    |     - `rc` is later dropped here
```



## 2.3 存储数值

使用 HashMap 来存储 SET 命令设置的数据

```rust
async fn process(socket: TcpStream) {
    use mini_redis::Command::{self, Get, Set};
    use std::collections::HashMap;

    // A hashmap is used to store data
    let mut db = HashMap::new();

    // parsing frames from the socket
    let mut connection = Connection::new(socket);

    // receive a command from the connection
    while let Some(frame) = connection.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                // stored as a Vec<u8>
                db.insert(cmd.key().to_string(), cmd.value().to_vec());
                Frame::Simple("OK".to_string())
            }
            Get(cmd) => {
                if let Some(value) = db.get(cmd.key()) {
                    // hit, convert &Vec<u8> to Bytes
                    Frame::Bulk(value.clone().into())
                } else {
                    Frame::Null
                }
            }
            cmd => panic!("unimplemented{:?}", cmd),
        };

        // write the response to the client
        connection.write_frame(&response).await.unwrap();
    };
}
```



















































