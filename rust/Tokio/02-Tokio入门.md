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

**同步编程**：当程序遇到不能立即完成的操作时，会阻塞，直到操作完成；

**异步编程**：不能立即完成的操作被暂时停在后台。线程没有被阻塞，可以继续运行其他事情。一旦操作完成，任务就会被取消暂停，并继续从它离开的地方处理。



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



# 3. 共享状态

## 3.1 策略

在 Tokio 中，共享状态有几种不同的方式：

- 用 Mutex 来保护共享状态。适用于简单的数据操作，如HashMap的 get 和 set 操作
- 生成一个任务来管理状态，并使用消息传递来操作它。适用于需要异步工作的东西，比如I/O操作



## 3.2 bytes

Bytes 的目标是为网络编程提供一个强大的字节数组结构。相比 `Vec<u8>` 最大的特定是**浅拷贝**。即在 Bytes 实例上调用 clone() 并不复制底层数据，相反，Bytes 实例是对一些底层数据的一个引用计数的句柄。

Bytes 类型大致是一个 `Arc<Vec<u8>>`，但有一些附加功能。

使用 bytes 时，需要在 Cargo.toml 中添加

```toml
[dependencies]
bytes = "1"
```



## 3.3 完整代码

```rust
use tokio::net::TcpListener;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();
    
    let db = Arc::new(Mutex::new(HashMap::new()));

    loop {
        let (socket, _) = listener.accept().await.unwrap();

        // clone the handle to the hash map
        let db = db.clone();

        // 生成任务
        tokio::spawn(async move {
            process(socket, db).await;
        });
    }
}

////////////////////
use tokio::net::TcpStream;
use mini_redis::{Connection, Frame};
use bytes::Bytes;

// 别名
type Db = Arc<Mutex<HashMap<String, Bytes>>>;

async fn process(socket: TcpStream, db: Db) {
    use mini_redis::Command::{self, Get, Set};

    // parsing frames from the socket
    let mut connection = Connection::new(socket);

    // receive a command from the connection
    while let Some(frame) = connection.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                let mut db = db.lock().unwrap();
                db.insert(cmd.key().to_string(), cmd.value().clone());
                Frame::Simple("OK".to_string())
            }
            Get(cmd) => {
                let db = db.lock().unwrap();
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone())
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

**`std::sync::Mutex` vs `tokio::sync::Mutex` **：

- `std::sync::Mutex`：同步互斥锁，在等待当前锁的时候会阻塞当前线程，也会阻塞其他任务的处理
- `tokio::sync::Mutex`：异步互斥锁，是一个跨调用 `.await` 而被锁定的 Mutex

经验法则：在异步代码中使用同步的 mutex 是可以的，只要竞争保持在较低的水平，并且在调用 `.await` 时不保持锁。此外，可以考虑使用 `parking_lot::Mutex` 作为 `std::sync::Mutex` 更快的替代品



## 3.4 任务、线程和争用

当争夺最小的时候，使用一个阻塞的 mutex 来保护简短的关键部分是一个可以接受的策略。当锁被争夺时，执行任务的线程必须阻塞并等待 mutex，这不仅会阻塞当前的任务，也会阻塞当前线程上安排的其他任务。

默认情况下，Tokio 运行时使用一个多线程调度器。任务被安排在由运行时管理的任何数量的线程上。如果大量的任务被安排执行，并且它们都需要访问 mutex，那么就会出现争夺。另一方面，如果使用 current_thread 运行时，那么 mutex 将永远不会被争夺。

current_thread 运行时是一个轻量级、单线程的运行时。当只生成几个任务并打开少量的socket时，它是一个很好的选择。例如在异步客户端库上提供一个同步API桥接时，很好用。

如果同步 mutex 的争夺成为问题，最好的解决办法很少是切换到 tokio mutex，相反，要考虑如下选择：

- 切换到一个专门任务来管理状态并使用消息传递
- 分片 mutex
- 重组代码以避免使用 mutex

Mutex 分片案例：(dashmap crate 提供了一个分片哈希图的实现)

```rust
type SharedDb = Arc<Vec<Mutex<HashMap<String, Vec<u8>>>>>;

// 通过key来识别所属分片，然后再去查找值
let shard = db[hash(key) % db.len()].lock().unwrap();
shard.insert(key, value);
```



## 3.5 在 `.await` 中持有 `MutexGuard`

```rust
use std::sync::{Mutex, MutexGuard};

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
    
    do_something_async().await;
} // lock goes out of scope here
```

调试时，将会出现如下错误：

```text
 --> src/lib.rs:7:5
    |
4   |     let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    |         -------- has type `std::sync::MutexGuard<'_, i32>` which is not `Send`
...
7   |     do_something_async().await;
    |     ^^^^^^^^^^^^^^^^^^^^^^^^^^ await occurs here, with `mut lock` maybe used later
8   | }
    | - `mut lock` is later dropped here
```

因为 `std::sync::MutexGuard` 类型不是 Send。这意味着不能把一个 mutex 锁发送到另一个线程，而错误的发生是因为 Tokio 运行时可以在每个 .await 的线程之间移动一个任务。为避免此种情况，使用互斥锁的析构器在 `.await` 之前运行。

```rust
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    {
        let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
        *lock += 1;
    } // lock goes out of scope here
    
    do_something_async().await;
}
```

显示丢弃锁也不行，因为编译器目前只根据作用域来计算一个 future 是否是 Send 的。

```rust
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
    drop(lock);
    
    do_something_async().await();
}
```



### 3.5.1 重组代码，使其不在一个 .await 中保持锁

```rust
use std::sync::Mutex;

struct CanIncrement {
    mutex: Mutex<i32>,
}

impl CanIncrement {
    // This function is not marked async
    fn increment(&self) {
        let mut lock = self.mutex.lock().unwrap();
        *lock += 1'
    }
}

async fn increment_and_do_stuff(can_incr: &CanIncrement) {
    can_incr.increment();
    do_something_async().await();
}
```



### 3.5.2 生成任务来管理状态，并使用消息传递来操作它

通常在共享资源是 I/O 资源时使用。



### 3.5.3 使用 tokio 的 异步 mutex

`tokio::sync::Mutex` 的主要特点是可以跨 `.await` 持有。但是，异步的 mutex 比普通的 mutex 更昂贵，通常使用其他两种方法更好。

```rust
use tokio::sync::Mutex;

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock = mutex.lock().await();
    *lock += 1;
    
    do_something_async().await();
} // lock goes out of scope here
```



# 4. 通道

## 4.1 tokio 通道原语

Tokio 提供了而一些 channe，每个通道都有不通的用途：

- mpsc：多生产者，单消费者通道。允许发送多个值。
- oneshot：单生产者，单消费者通道。允许发送一个值
- broadcast：多生产者，多消费者。可以发送许多值，每个接收者看到每个值
- watch：单生产者，多消费者。可以发送许多值，但不保留历史，接收者只能看到最近的值



## 4.2 通道实例

```rust
use bytes::Bytes;
use mini_redis::client;
use tokio::sync::{mpsc, oneshot};

// to send the command response back to requester
type Responder<T> = oneshot::Sender<mini_redis::Result<T>>;

#[derive(Debug)]
enum Command {
    Get {
        key: String,
        resp: Responder<Option<Bytes>>,
    },
    Set {
        key: String,
        value: Bytes,
        resp: Responder<()>,
    }
}

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
    let tx2 = tx.clone();

    let manager = tokio::spawn(async move {
        // establish a connection to the server
        let mut client = client::connect("localhost:6379").await.unwrap();

        // starting receiving messages
        while let Some(cmd) = rx.recv().await {
            use Command::*;

            match cmd {
                Get { key, resp } => {
                    let res = client.get(&key).await;

                    // ignore errors
                    let _ = resp.send(res);
                },
                Set { key, value, resp } => {
                    let res = client.set(&key, value).await;

                    // ignore errors
                    let _ = resp.send(res);
                }
            }
        }
    });

    // spawn two tasks, one gets a key, the other sets a key
    let t1 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();
        let cmd = Command::Get {
            key: "hello".to_string(),
            resp: resp_tx,
        };

        // send the GET request
        tx.send(cmd).await.unwrap();

        // await the response
        let res = resp_rx.await.unwrap();
        println!("GOT = {:?}", res);
    });

    let t2 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();
        let cmd = Command::Set {
            key: "foo".to_string(),
            value: Bytes::from("bar"),
            resp: resp_tx,
        };

        // send the SET request
        tx2.send(cmd).await.unwrap();

        // await the response
        let res = resp_rx.await.unwrap();
        println!("GOT = {:?}", res);
    });

    // join
    t1.await.unwrap();
    t2.await.unwrap();
    manager.await.unwrap();
}
```



## 4.3 背压和有界通道

无论何时引入并发或队列，都必须确保队列是有界的，系统将优雅地处理负载。无界的队列最终会占用所有可用的内存，导致系统以不可预测的方式失败。

tokio 小心避免隐性队列，其中很大部分是由于异步操作是  lazy 的

```rust
loop {
    async_op();
}
```

如果异步操作急切地运行，循环将重复排队运行一个新的 `async_op`，而不确保之前的操作完成。这将导致隐性的无边界队列。基于回调的系统和基于急切的 future 的系统特别容易受此影响。

然而，在 tokio 和异步 Rust 中，根本不会导致 `async_op` 的运行，因为 `.await` 从未被调用。如果增加 `.await`，那么循环会等待操作完成后再重新开始。

```rust
loop {
    // Will not repeat util `async_op` completes
    async_op().await;
}
```

必须明确地引入并发和队列，做到这一点的方法包括：

- `tokio::spawn`
- `select!`
- `join!`
- `mpsc::channel`







































