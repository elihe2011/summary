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



# 5. I/O

## 5.1 AsyncRead

### 5.1.1 async fn read()

`AsyncReadExt::read` 提供了一个向缓冲区读取数据的异步方法，返回读取的字节数。当 read() 返回 Ok(0) 时，表示流已经关闭

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncReadExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::open("foo.txt").await?;
    let mut buffer = [0; 10];

    // read up to 10 bytes
    let n = f.read(&mut buffer[..]).await?;

    println!("The bytes: {:?}", &buffer[..n]);
    Ok(())
}
```



### 5.1.2 async fn read_to_end()

`AsyncReadExt::read_to_end` 读取所有字节直到EOF

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::open("foo.txt").await?;
    let mut buffer = Vec::new();

    // read the whole file
    let n = f.read_to_end(&mut buffer).await?;

    println!("The bytes: {:?}", &buffer[..n]);
    Ok(())
}
```



## 5.2 AsyncWrite

### 5.2.1 async fn write()

AsyncWriteExt::write 将缓冲区写入，并返回写入的字节数

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncWriteExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::create("foo.txt").await?;

    // write bytes to the file
    let n = f.write(b"just some bytes").await?;

    // flush to the disk
    f.flush().await?;

    println!("{} bytes written to foo.txt", n);
    Ok(())
}
```



### 5.2.2 async fn write_all()

`AsyncWriteExt::write_all` 将整个缓冲区写入

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::create("foo.txt").await?;

    // write all bytes
    f.write_all("hello".as_bytes()).await?;

    Ok(())
}
```



## 5.3 辅助函数

与 std 模块一样，`tokio::io` 模块也包含一些实用函数，以及用于处理标准输入、标准输出和标准错误的API

`tokio::io::copy` 异步将一个 reader 的数据全部复制到一个 writer

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let mut reader: &[u8] = b"hello world";
    let mut writer = File::create("foo.txt").await?;

    let n = io::copy(&mut reader, &mut writer).await?;

    println!("{} bytes copied to `foo.txt`", n);
    Ok(())
}
```



## 5.4 Echo Server

### 5.4.1 `TcpStream::split` 

`io::split` 函数，可以将任何读写器类型分割成独立的 reader(AsyncRead) 和 writer(AsyncWrite) 两个句柄，在其内部使用一个 Arc 和 一个 Mutex。这种开销可以通过 TcpStream 来避免。

`TcpStream::split` 接收流的 reference，并返回 reader 和 writer 句柄。因为使用了 reference，所以两个句柄必须留在 split() 被调用的同一个任务上。这种专门的 split 是零成本的。不需要 Arc 或 Mutex。TcpStream 还提供了 into_split，它支持跨任务移动句柄，但需要一个 Arc

Echo 服务器：

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
            let (mut reader, mut writer) = socket.split();

            if io::copy(&mut reader, &mut writer).await.is_err() {
                eprintln!("failed to copy data from socket");
            }
        });
    }
}
```



Echo 客户端：

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let socket = TcpStream::connect("127.0.0.1:8080").await?;
    let (mut rd, mut wr) = io::split(socket);

    // write data in the background
    let write_task = tokio::spawn(async move {
        wr.write_all("hello".as_bytes()).await?;
        wr.write_all("world".as_bytes()).await?;
        wr.flush().await?;

        Ok::<_, io::Error>(())
    });

    let mut buf = vec![0; 128];
    loop {
        let n = rd.read(&mut buf).await?;
        if n == 0 {
            break;
        }

        let s = String::from_utf8_lossy(&buf[0..n]);
        println!("GOT: {:?}", s);
    }

    Ok(())
}
```



### 5.4.2 手动复制

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
            let mut buf = vec![0; 1024];

            match socket.read(&mut buf).await {
                Ok(0) => {
                    // EOF
                    return;
                },
                Ok(n) => {
                    // copy the data back to socket
                    if socket.write_all(&buf[..n]).await.is_err() {
                        // unexpected socket error
                        return;
                    }
                },
                Err(_) => {
                    // unexpected socket error
                    return;
                }
            }
        });
    }
}
```



### 5.4.3 分配缓冲区

该策略是将一些数据从套接字中读入一个缓冲区，然后将缓冲区的内容写回套接字

```rust
let mut buf = vec![0; 1024];
```

所有跨调用 `.await` 的任务数据都必须由任务存储。在这种情况下，buf 被用于跨域 `.await` 调用。所有的任务数据被存储在一个单一的分配中。

如果缓冲区由堆栈数组表示，每个接收的套接字所产生的任务内部结构

```rust
struct Task {
    // internal task fields here
    task: enum {
        AwaitingRead {
            socket: TcpStream,
            buf: [BufferType],
        },
        AwaitignWriteAll {
            socket: TcpStream,
            buf: [BufferType],
        }
    }
}
```

如果使用堆栈数组作为缓冲区类型，它将被内联存储在任务结构中。这将使任务结构变得非常大。此外，缓冲区的大小通常是以页为单位的。`$page-size + a-few-bytes`



# 6. 分帧

## 6.1 帧定义

一个帧是两个对等体之间传输的数据单位。

Redis 协议的帧定义：

```rust
use bytes::Bytes;

enum Frame {
    Simple(String),
    Error(String),
    Integer(u64),
    Bulk(Bytes),
    Null,
    Array(Vec<Frame>),
}
```



HTTP 协议的帧定义：

```rust
enum HttpFrame {
    RequestHead {
        method: Method,
        uri: Uri,
        version: Version,
        headers: HeaderMap,
    },
    ResponseHead {
        status: StatusCode,
        version: Version,
        headers: HeaderMap,
    },
    BodyChunk {
        chunk: Bytes,
    },
}
```



Mini-Redis 的分帧，实现一个 Connection 结构，它包裹着一个 TcpStream 并读写 `mini_redis::Frame`

```rust
use tokio::net::TcpStream;
use mini_redis::{Frame, Result};

struct Connection {
    stream: TcpStream,
    // ... other fields here
}

impl Connection {
    /// Read a frame from the connection
    /// Returns `None` if EOF is reached
    pub async fn read_frame(&mut self)
    	-> Result<Option<Frame>>
    {
        // implementation here
    }
    
    /// Write a frame to the connection
    pub async fn write_frame(&mut self, frame: &Frame)
    	-> Result<()>
    {
        // implementation here
    }
}
```



## 6.2 带缓冲的读取

read_frame 方法再返回之前会等待一整帧的接收。对 TcpStream::read() 的一次调用可以返回一个任意数量的数据。它可能包含一整个帧，一个部分帧，或多个帧。如果收到一个部分帧，数据被缓冲，并从套接字中读取更多数据。如果收到多个帧，则返回第一个帧，其余的数据被缓冲，直到下次调用 read_frame。

为实现这一点，Connection 需要一个读取缓冲区字段。数据从套接字中读入读取缓冲区。当一个帧被解析后，相应的数据就会从缓冲区中移除。

使用 BytesMut 作为缓冲区类型。

```rust
use bytes::BytesMut;
use tokio::net::TcpStream;

pub struct Connection {
    stream: TcpStream,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream,
            // Allocate the buffer with 4kb of capacity
            buffer: BytesMut::with_capacity(4096),
        }
    }
}
```

Connection 上的 read_frame() 函数：

```rust
use mini_redis::{Frame, Result};

pub async fn read_frame(&mut self) -> Result<Option<Frame>> {
    loop {
        if let Some(frame) = self.parse_frame()? {
            return Ok(Some(frame));
        }
        
        // Esure the buffer has capacity
        if self.buffer.len() == self.cursor {
            // Grow the buffer
            self.buffer.resize(self.cursor * 2, 0);
        }
        
        // Read into the buffer, tracking the number of bytes read
        let n = self.stream.read(&mut self.buffer[self.cursor..]).await?;
        
        if n == 0 {
            if self.cursor == 0 {
                return Ok(None);
            } else {
                return Err("connection reset by peer".into())
            }
        } else {
            // Update our cursor
            self.cursur += n;
        }
    }
}
```



## 6.3 解析

parse_frame() 函数，解析规则分两步：

- 确保一个完整的帧被缓冲，并找到该帧的结束索引
- 解析该帧

mini-redis crate 提供了一个用于这两个步骤的函数：

- `Frame::check`
- `Frame::parse`

```rust
use mini_reids::{Frame, Result};
use mini_redis::frame::Error::Incomplete;
use bytes::Buuf;
use std::io::Cursor;

fn parse_frame(&mut self) -> Result<Option<Frame>> {
    // Create the `T: Buf` type
    let mut buf = Cursor::new(&self.buffer[..]);
    
    // Check whether a full frame is available
    match Frame::check(&mut self) {
        Ok(_) => {
            // Get the byte length of the frame
            let len = buf.position as usize;
            
            // Reset the internal cursor for the call to `parse`
            buf.set_position(0);
            
            // Parse the frame
            let frame = Frame::parse(&mut buf)?;
            
            // Discard the frame from the buffer
            self.buffer.advance(len);
            
            // Return the frame to the caller
            Ok(Some(frame))
        },
        // Not enough data has been buffered
        Err(Incomplete) => Ok(None),
        // An error was encountered
        Err(e) => Err(e.into()),
    }
}
```



## 6.4 带缓冲的写入

write_frame() 函数将整个帧写到套接字中，为减少 write 的系统调用，写将被缓冲。

考虑一个批量流帧，被写入的值是  `Frame::Bulk(Bytes)`。散装帧的线格式是一个帧头，它由`$`字符和以字节为单位的 数据长度组成。帧的大部分是 Bytes 值得内容。如果数据很大，将它复制到一个中间缓冲区将是很昂贵的。

为了实现缓冲写入，将使用 BufWriter 结构，它被初始化为一个 `T: AsyncWrite` 并实现 `AsyncWrite` 本身。当在 `BufWriter` 上调用写时，不会直接写入，而是进入一个缓冲区。当缓冲区满时，再写入并清空缓冲区。

Connection 结构：

```rust
use tokio::io::BufWriter;
use tokio::net::TcpStream;
use bytes::Bytes;

pub struct Connection {
    stream: BufWriter<TcpStream>,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream: BufWriter::new(stream),
            buffer: BytesMut::with_capacity(4096),
        }
    }
}
```



write_frame() 实现：

```rust
use tokio::io::{self, AsyncWriteExt};
use mini_redis::Frame;

async fn write_frame(&mut self, frame: &Frame) -> io::Result<()> {
    match frame {
        Frame::Simple(val) => {
            self.stream.write_u8(b'+').await?;
            self.stream.write_all(val.as_bytes()).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Error(val) => {
            self.stream.write_u8(b'-').await?;
            self.stream.write_all(val.as_bytes()).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Integer(val) => {
            self.stream.write_u8(b':').await?;
            self.write_decimal(*val).await?;
        }
        Frame::Null => {
            self.stream.write_all(b"$-1\r\n").await?;
        }
        Frame::Bulk(val) => {
            let len = val.len();
            
            self.stream.write_u8(b'$').await?;
            self.write_decimal(len as u64).await?;
            self.stream.write_all(val).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Array(_val) => unimplemented!(),
    }
    
    self.stream.flush().await;
    
    Ok(())
}
```

写入函数由 AsyncWriteExt 提供，它们在 TcpStream 上也可用，但在没有中间缓冲区的情况下发出单字节的写入是不可取的：

- write_u8  写一个字节
- write_all 写入整个片段
- write_decimal  由 mini-redis 实现



# 7. 深入异步

## 7.1 Futures

一个调用时需要附加`.await`的函数，成为为 future

future 是一个实现了 `std::future::Future` 特性的值，它们包含了正在进行的异步计算的值。

`std::future::Future` trait 定义：

```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Future {
    type Output;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context) 
    	-> Poll<Self::Output>;
}
```

Pin 类型是 Rust 能够支持异步函数中的借用方式。

与其他语言实现 future 的方式不同，Rust future 并不代表在后台发生的计算，相反它就是计算本身。Future的所有者负责通过轮询 Future 来推进计算，可以通过调用 `Future::poll` 来实现。



### 7.1.1 实现 future

一个简单的 future 实现：

- 等待到一个特定的时间点
- 输出一些文本到 STDOUT
- 产生一个字符串

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("Delay for {:?} is ready", Instant::now());
            Poll::Ready("ready")
        } else {
            // Ignore this line for now
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_millis(10);
    let future = Delay { when };

    let out = future.await;
    assert_eq!(out, "ready");
}
```



### 7.1.2 作为Future的 async fn

从异步函数中，可以对任何实现 Future 的值调用 `.await`。反过来，调用一个异步函数会返回一个实现 Future 的匿名类型。

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("Delay for {:?} is ready", Instant::now());
            Poll::Ready("ready")
        } else {
            // Ignore this line for now
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

enum MainFuture {
    // Initialized, never polled
    State0,
    // Waiting on `Delay`, i.e. the `future.await` line
    State1(Delay),
    // The future has completed
    Terminated,
}

impl Future for MainFuture {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        use MainFuture::*;

        loop {
            match *self {
                State0 => {
                    let when = Instant::now() + Duration::from_secs(3);
                    let future = Delay { when };
                    *self = State1(future);
                }
                State1(ref mut my_future) => {
                    match Pin::new(my_future).poll(cx) {
                        Poll::Ready(out) => {
                            assert_eq!(out, "ready");
                            *self = Terminated;
                            println!("Terminated on {:?}", Instant::now());
                            return Poll::Ready(());
                        }
                        Poll::Pending => {
                            return Poll::Pending;
                        }
                    }
                }
                Terminated => {
                    panic!("future polled after completion");
                }
            }
        }
    }
}

#[tokio::main]
async fn main() {
    MainFuture::State0.await;
}
```

Rust futures 是一种状态机。MainFuture 被表示为一个 future 的可能状态的枚举。future 在 State0 状态下开始。当 poll 被调用时，future 试图尽可能地推进其内部状态。如果 future 能够完成，`Poll::Ready` 将被返回，其中包含异步计算的输出。

如果 future 不能完成，通常是由于它所等待的资源没有准备好，那么就会返回 `Poll::Pending`。收到 `Poll::Pending` 是向调用者表面，future 将在稍后的试驾完成，调用者应该在稍后再次调用 poll。



## 7.2 executors

异步的 Rust 函数返回 future，future 必须被调用 poll 以推进其状态。future 由其他 future 组成。

要运行异步函数，它们必须被传递给 `tokio::spawn` 或被 `#[tokio::main]` 注释的主函数。将生成的外层 future 提交给 Tokio 执行器。执行器负责在外部 future 上调用 `Future::poll`，推动异步计算的完成。



### 7.2.1 mini Tokio

```rust
use std::collections::VecDeque;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use futures::task;

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("Delay for {:?} is ready", Instant::now());
            Poll::Ready("done")
        } else {
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

type Task = Pin<Box<dyn Future<Output = ()> + Send>>;

struct MiniTokio {
    tasks: VecDeque<Task>,
}

impl MiniTokio {
    fn new() -> MiniTokio {
        MiniTokio {
            tasks: VecDeque::new(),
        }
    }

    /// Spawn a future onto the mini-tokio instance
    fn spawn<F>(&mut self, future: F)
    where
        F: Future<Output = ()> + Send + 'static
    {
        self.tasks.push_back(Box::pin(future));
    }

    fn run(&mut self) {
        let waker = task::noop_waker();
        let mut cx = Context::from_waker(&waker);

        while let Some(mut task) = self.tasks.pop_front() {
            if task.as_mut().poll(&mut cx).is_pending() {
                self.tasks.push_back(task);
            }
        }
    }
}

fn main() {
    let mut mt = MiniTokio::new();

    mt.spawn(async {
        let when = Instant::now() + Duration::from_millis(100);
        let future = Delay { when };

        let out = future.await;
        assert_eq!(out, "done");
    });

    mt.run();
}
```

一个具有所要求的延迟的 Delay 实例被创建和等待。但存在一个重大缺陷，执行器未进入睡眠状态。执行器不断地循环所有被催生的 future，并对它们进行 poll。大多数适合，这些 future 还没准备好执行更多的工作，并会再次返回 `Poll::Pending`，这个过程会消耗 CPU，效率不高。

理想情况下，只在 future 能够取得进展时  poll future。这发生在任务被阻塞的资源准备好执行请求的操作时，如果任务想从一个 TCP 套接字中读取数据，那么在 TCP 套接字收到数据时 poll 任务。

为了实现这一点，当一个资源被 poll 而资源又没有准备好时，一旦它过渡到 ready 状态，该资源将发送一个通知。



## 7.3 Wakers

Waker 是缺失的那部分。这是以一个系统，通过这个系统，资源能够通知等待的任务，资源已经准备好继续某些操作。

`Future::poll` 的定义：

```rust
fn poll(self: Pin<&mut Self>, cx: &mut Context)
	-> Poll<Self::Output>;
```

Poll 的 Context 参数有一个 waker() 方法。该方法返回一个与当前任务绑定的 Waker。该 Waker 有一个 wake() 方法。调用该方法向执行器发出信号，相关任务应该被安排执行。当资源过渡到准备好的状态时调用 wake()，通知执行者，poll 任务将能够取得进展。



### 7.3.1 更新 Delay

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use std::thread;

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("Delay for {:?} is ready", Instant::now());
            Poll::Ready("done")
        } else {
            //cx.waker().wake_by_ref();
            
            // Get a handle to the waker for the current task
            let waker = cx.waker().clone();
            let when = self.when;

            // Spawn a timer thread
            thread::spawn(move || {
                let now = Instant::now();
                println!("Sleep wait for {:?}", &now);

                if now < when {
                    thread::sleep(when - now);
                }

                waker.wake();
            });

            Poll::Pending
        }
    }
}
```

一旦请求的持续时间过了，调用的任务就会被通知，执行者可以确保任务被再次安排。

更新 mini-tokio 以监听唤醒通知：

- 当一个 future 返回 `Poll::Pending` 时，它必须确保在某个时间点对 waker 发出信息。忘记这样做会导致任务无限地挂起
- 在返回 `Poll::Pending` 后忘记唤醒一个任务是一个常见的错误来源

在返回 `Poll::Pending` 之前，调用 `cx.waker().wake_by_ref()`，这是为了满足 future 契约。通过返回 `Poll::Pending`，给唤醒者发信号。因为还没有实现定时器现场，所以在内联中给唤醒者发信号。这样做的结果是，future 将立即被重新安排，再次执行，而且可能还没有准备好完成。

注意，运行对 waker 发出超过必要次数的信号。即使没有准备好继续操作，还是向唤醒者发出信号。除了浪费一些 CPU 周期外，并没有什么问题，但这种特殊的实现方式会导致一个繁忙的循环。



## 7.4 更新 Mini Tokio

更新 Mini Tokio 以接收 waker 的通知。在 poll future 时将这个 waker 传递给 future。

更新后的 Mini Tokio 将使用一个通道来存储预定任务。通道运行任务从任何线程被排队执行。Wakers 必须是 Send 和 Sync，所以使用来自 crossbeam crate 的通道，因为标准库的通道不是 Sync。

Send 和 Sync 特性是 Rust 提供的与并发性有关的标记特性。可以被发送到不同线程的类型是 Send。大多数类型都是 Send，但像 Rc 这样的类型则不是。可以通过不可变的引用并发访问的类型是 Sync。一个类型可以是 Send，但不是 Sync 一个很好的例子是 Cell，它可以通过不改变的引用被修改，因此并发访问是不安全的。

```rust
use crossbeam::channel;
use std::sync::{Arc, Mutex};

struct MiniTokio {
    scheuled: channel::Receiver<Arc<Task>>,
    sender: channel::Sender<Arc<Task>>,
}

struct Task {
    future: Mutex<Pin<Box<dyn Future<Output = ()> + Send>>>,
    executor: channel::Sender<Arc<Task>>,
}

impl Task {
    fn schedule(self: &Arc<Self>) {
        self.executor.send(self.clone());
    }
}
```































































































