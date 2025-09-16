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
use std::sync::Arc;

struct MiniTokio {
    scheuled: channel::Receiver<Arc<Task>>,
    sender: channel::Sender<Arc<Task>>,
}

struct Task {
    // This will be filled in soon
}
```

Wakers 是 sync，并且可以被克隆。当 wake 被调用时，任务必须被安排执行。为了实现这一点，需要有一个通道。当 `wake()` 被调用时，任务被推到通道的发送任务。Task 结构将实现唤醒逻辑，要做到这一点，它需要同时包含催生的 future 和通道的发送部分。

```rust
use std::sync::{Arc, Mutex}

struct Task {
    // The `Mutex` is to make `Task` implemet `Sync`. Only one thread accesses 
    // `future` at any given time. 
    future: Mutex<Pin<Box<dyn Future<Output = ()> + Send>>>,
    executor: channel::Sender<Arc<Task>>,
}

impl Task {
    fn schedule(self: &Arc<Self>) {
        self.executor.send(self.clone());
    }
}
```

为了安排任务，Arc 被克隆并通过通道发送。将 schedule 函数与 `std::task::Waker` 挂钩。标准库提供了一个低级别的 API，通过手动构建 vtable 来完成这个任务。这种策略为实现者提供了最大的灵活性，但需要一堆不安全的模板代码。不直接使用 `RawWakerVTable`，而是使用由 future crate 提供的 ArcWaker 工具

```rust
use futures::task::{self, ArcWake};
use std::sync::Arc;

impl ArcWake for Task {
    fn wake_by_ref(arc_self: &arc<Self>) {
        arc_self.schedule();
    }
}
```

当上面的定时器线程调用 `waker.wake()` 时，任务被推送到通道中。接下来，在 `MiniTokio::run()` 函数中实现接收和执行任务。

```rust
impl MiniTokio {
    fn run(&self) {
        while let Ok(task) = self.scheduled.recv() {
            task.poll();
        }
    }
    
    /// Initialize a new mini-tokio instance
    fn new() -> MiniTokio {
        let (sender, scheduled) = channel::unbounded();
        
        MiniTokio { scheduled, sender }
    }
    
    /// Spawn a future onto the mini-tokio instance.
    /// This given future is wrapped with the `Task` harness and pushed into the
    /// `scheduled` queue. The future will be executed when `run` is called
    fn spawn<F>(&self, future: F)
    where
    	F: Future<Output = ()> + Send + 'static,
    {
        Task::spawn(future, &self.sender);
    }
}

impl Task {
    fn poll(self: Arc<Self>) {
        // Crate a waker from the `Task` instance. This
        // uses the `ArcWake` impl from above.
        let waker = task::waker(self.clone());
        let mut cx = Context::from_waker(&waker);
        
        // No other thread ever tries to lock the future
        let mut future = self.future.try_lock().unwrap();
        
        // Poll the future
        let _ = future.as_mut().poll(&mut cx);
    }
    
    // Spawns a new tasks with the given future
    // Initializes a new Task harness containing the given future and pushes it
    // onto `sender`. The receiver half of the channel will get the task and execute it
    fn spawn<F>(future: F, sender: &channel::Sender<Arc<Task>>)
    where
    	F: Future<Output = ()> + Send + 'static,
    {
        let task = Arc::new(Task {
            future: Mutex::new(Box::pin(future)),
            executor: sender.clone(),
        });
        
        let _ = sender.send(task);
    }
}
```

实现功能：

- `MiniTokio::run()` 被实现。该函数在一个循环中运行，接收来自通道的预定任务。由于任务咋被唤醒时被推入通道，这些任务在执行时能够取得进展
- `MiniTokio::new()` 和 `MiniTokio::spawn()` 函数被调整为使用通道而不是 `VecDeque`。当新任务被催生时，它们会被赋予一个通道的发送者部分的克隆，任务可以用它来在运行时安排自己。
- `Task::poll()` 函数使用来自 futures crate 的 `ArcWake` 工具创建 waker。waker 被用来创建一个 `task::Context`。该 `task::Context` 被传递给 poll



## 7.5 摘要

Rust 的 `async/await` 功能是由 traits 支持的。这允许第三方 crate，如 Tokio，提供执行细节：

- Rust 的异步操作是 lazy，需要调用者来 poll 它们
- Wakers 被传递给 futures，以将一个 future 与 调用它的任务联系起来
- 当以一个资源没有准备好完成一个操作时，`Poll::Pending` 被返回，任务的 waker 被记录
- 当资源准备好时，任务的 waker 会被通知
- 执行者收到通知并安排任务的执行
- 任务再次被 poll，这次资源已经准备好了，任务取得了进展



## 7.6 未尽事宜

Rust 的异步模型允许单个 future 在执行时跨任务迁移，考虑一下下面的情况

```rust
use futures::future::poll_fn;
use std::future::Future;
use std::pin::Pin;

#[tokio::main]
async fn main() {
    let when = Instance::now() + Duration::from_millis(10);
    let mut delay = Some(Deplay { when });
    
    poll_fn(move |cx| {
       let mut delay = delay.take().unwrap();
       let res = Pin::new(&mut delay).poll(cx);
        assert!(res.is_pending());
        
        tokio::spawn(async move {
            delay.await;
        });
        
        Poll::Ready(());
    }).await;
}
```

`poll_fn` 函数使用闭包创建 Future 实例。当实现 future 时，关键是要假设每一次对 poll 的调用都可能提供一个不同的 Waker 实例。poll 函数必须用新的唤醒者来更新任何先前记录的唤醒者。

在早期实现的 Delay，每次 poll 时都好产生一个新的 线程。但如果 poll 太频繁，效率就会很低。(例如，如果 select! 这个 future 和其他的 future，只要其中一个有事件，这两个都会被 poll)。一种方法是记住你是否已经产生了一个线程，如果你还没有产生一个线程，就只产生一个新的线程。然而，这样做，必须确保线程的 Waker 在以后调用 poll 时被更新，否则就不能唤醒最近的 Waker。

为修复之前的实现，这样做：

```rust
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};
use std::thread;
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
    // This Some when we have spawned a thread, and None otherwise
    waker: Option<Arc<Mutex<Waker>>>,
}

impl Future for Delay {
    type Output = ();
    
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        // First, if this is the first time the future is called, spawn the
        // timer thread. If the timer thread is already running, ensure the
        // stored `Waker` matches the current task's waker
        if let Some(waker) = &self.waker {
            let mut waker = waker.lock().unwrap();
            
            // Check if the stored waker matches the current task' waker.
            // This is necessary as the `Delay` future instance may move to
            // a different task between calls to `poll`. If this happens, the
            // waker contained by the given `Context` will differ and we
            // must update our stored waker to reflect this change
            if !waker.will_wake(cx.waker()) {
                *waker = cx.waker().clone();
            }
        } else {
            let when = self.when
            let waker = Arc::new(Mutex::new(cx.waker().clone()));
            self.waker = Some(waker.clone());
            
            // This is the first time `poll` is called, spawn the timer thread
            thread::spawn(move || {
                let now = Instant::now();
                
                if now < when {
                    thread::sleep(when - now);
                }
                
                // The duration has elapsed, Notify the caller by invoking the waker
                let waker = waker.lock().unwrap();
                waker.wake_by_ref();
            });
        }
        
        // Once the waker is stored and the timer thread is started, it is time to
        // check if the delay has completed. This is done by checking the current
        // instant. If the duration has elapsed, then the future has completed 
        // and `Poll::Ready` is returned
        if Instant::now() > self.when {
            Poll::Ready(())
        } else {
            // The duration has not elapsed, the future has not completed so return `Poll::Pending`
            Poll::Pending
        }
    } 
}
```



### 7.6.1 Notify 工具

Wakers 是异步 Rust 工作方式的集成。在 Delay 情况下，可以通过使用 `tokio::sync::Notify` 工具，完成用 `async/await` 实现它。它提供了一个基本的任务通知机制。它处理 waker 的细节，包括确保记录的 waker 与当前任务相匹配。

使用 Notify，可以像用 `async/await` 实现一个 Delay 函数

```rust
use tokio::sync::Notify;
use std::sync::Arc;
use std::time::{Duration, Instant};
use std::thread;

async fn delay(dur: Duration) {
    let when = Instant::now() + dur;
    let notify = Arc::new(Notify::new());
    let notify2 = notify.clone();
    
    thread::spawn(move || {
        let now = Instant::now();
        
        if now < when {
            thread::sleep(when - now);
        }
        
        notify2.notify_one();
    });
    
    notify.notified().await;
}
```



# 8. select

## 8.1 `tokio::select!`

`tokio::select!` 宏允许在多个异步计算中等待，并在单个计算中完成返回

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        let _ = tx1.send("one");
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }
}
```

使用了两个 oneshot 通道，任何一个通道都可以先完成。`select!` 语句在两个通道上等待，并将 val 与 任务返回的值绑定。当 tx1 或 tx2 完成时，相关的块被执行。

没有完成的分支被放弃。在这个例子中，计算正在等待每个通道的 `oneshot::Receiver`。尚未完成的通道的 `oneshot::Receiver` 被放弃。

### 8.1.1 取消

在异步 Rust 中，取消操作是通过丢弃一个 future 来实现。异步 Rust 操作是使用 futures 实现的，而 futures 是 lazy 的。只有当任务被 poll 时，操作才会继续进行。如果 future 被丢弃，操作就不能进行，因为所有相关的状态都被丢弃了。

Futures 或其他类型可以实现 `Drop` 来清理后台资源。Tokio 的 `oneshot::Receiver` 通过向 `Sender` half 发送一个关闭的通知来实现 `Drop`。sender 部分可以收到这个通知，并用过丢弃来中转正在进行的操作。

```rust
use tokio::sync::oneshot;

async fn some_operation() {
    // compute value here
}

#[tokio::main]
async fn main() {
    let (mut tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        // Select on the operation and the oneshot's `closed()` notification
        tokio::select! {
            val = some_operation() => {
                let _ = tx1.send(val);
            }

            _ = tx1.closed() => {
                // `some_operation()` is canceled, the task completes and `tx` is dropped
            }
        }
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }
}
```



### 8.1.2 Future 实现

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use tokio::sync::oneshot;

struct MySelect {
    rx1: oneshot::Receiver<&'static str>,
    rx2: oneshot::Receiver<&'static str>,
}

impl Future for MySelect {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if let Poll::Ready(val) = Pin::new(&mut self.rx1).poll(cx) {
            println!("rx1 completed first with: {:?}", val);
            return Poll::Ready(());
        }

        if let Poll::Ready(val) = Pin::new(&mut self.rx2).poll(cx) {
            println!("rx2 completed first with: {:?}", val);
            return Poll::Ready(());
        }

        Poll::Pending
    }
}

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        let _ = tx1.send("one");
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    MySelect { rx1, rx2 }.await;
}
```

MySelect future 包含每个分支的 future。当 MySelect 被 poll 时，第一个分支被 poll。如果它准备好了，该值被使用，MySelect 完成。在 `.await` 收到一个 future 的输出后，该 future 被放弃。这导致两个分支的 futures 都被丢弃。由于有一个分支没有完成，所以该操作实际上被取消了。

在 MySelect 实现中，没有明确使用 Context 参数。相应的是，waker 的要求是通过传递 cx 给内部 future 来满足的。由于内部 future 也必须满足 waker 的要求，通过只在收到内部 future 的 `Poll::Pending` 时返回 `Poll::Pending`，MySelect 也满足 waker 的要求



# 8.2 语法

`select!` 宏可以处理两个以上的分支，目前的限制是 64 个分支，每个分支的结构为：

```
<pattern> = <async expression> => <handler>,
```

当 select 宏被评估时，所有的 `<async expression>` 被聚集起来被同时执行。当一个表达式完成时，其结果与 `<pattern>` 匹配。如果结果与模式匹配，那么所有剩余的异步表达式被放弃，`<handler>` 被执行。`<handler>` 表达式可以访问由 `<pattern>` 建立的任何绑定关系。

在一个 oneshot 通道和一个 TCP 连接的输出上进行选择。

```rust
use std::net::TcpStream;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();

    // Spawn a task that sends a message over the oneshot
    tokio::spawn(async move {
        tx.send("done").unwrap();
    });

    tokio::select! {
        socket = TcpStream::connect("localhost:3456") => {
            println!("Socket connected {:?}", socket);
        }

        msg = rx => {
            println!("Got a message: {:?}", msg);
        }
    }
}
```

使用一个 oneshot 并接受来自 TcpListener 的套接字。accept 循环一个运行遇到错误或 `rx` 收到一个值。

```rust
use std::io;
use tokio::net::TcpListener;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();

    tokio::spawn(async move {
        tx.send(()).unwrap()
    });

    let mut listener = TcpListener::bind("localhost:3456").await?;

    tokio::select! {
        _ = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket).await });
            }

            // Help the rust the inference out
            Ok::<_, io::Error>(())
        } => {}
        _ = rx => {
            println!("terminating accept loop");
        }
    }

    Ok(())
}
```



## 8.3 返回值

`tokio::select!` 宏返回被评估的 `<handler>` 表达式的结果

```rust
async fn computation1() -> String {
    // .. computation
}

async fn computation2() -> String {
    // .. computation
}

#[tokio::main]
async fn main() {
    let out = tokio::select! {
        res1 = computation1() => res1,
        res2 = computation2() => res2,
    };
    
    println!("Got = {}", out);
}
```



## 8.4 错误

使用 `?` 操作符会从表达式中传播错误。

```rust
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use std::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    // [setup `rx` oneshot channel]
    
    let listener = TcpListener::bind("localhost:3456").await?;
    
    tokio::select! {
        res = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket) });
            }
            
            // Help the rust type inference out
            Ok::<_, io::Error>(())
        } => {
            res?;
        }
        _ = rx => {
            println!("terminating accept loop");
        }
    }
    
    Ok(())
}
```



## 8.5 模型匹配

`select!` 宏分支语法：

```
<pattern> = <async expression> => <handler>,
```

从多个 MPSC 通道接收信息：

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (mut tx1, mut rx1) = mpsc::channel(128);
    let (mut tx2, mut rx2) = mpsc::channel(128);
    
    tokio::spawn(async move {
        // Do something w/ `tx1` and `tx2`
    });
    
    tokio::select! {
        Some(v) = rx1.recv() => {
            println!("Got {:?} from rx1", v);
        }
        Some(v) = rx2.recv() => {
            println!("Got {:?} from rx2", v1);
        }
        else => {
            println!("Bot channels closed");
        }
    }
}
```



## 8.6 借用

当spawn任务时，被spawn的异步表达式必须拥有其所有的数据。`select!` 宏没有这个限制。每个分支的异步表达式都可以借用数据并同时操作。按照 Rust 的借用规则，多个异步表达式可以不变地借用一个数据，或者一个异步表达式可以可变地借用一个数据

同时向每个不同的 TCP 目的地发送相同的数据

```rust
use tokio::io::AsyncWriteExt;
use tokio::net::TcpStream;
use std::io;
use std::net::SocketAddr;

async fn race(
	data: &[u8],
	addr1: SocketAddr,
    addr2: SocketAddr
) -> io:Result<()> {
    tokio::select! {
        Ok(_) = async {
            let mut socket = TcpStream::connect(addr1).await?;
            socket.write_all(data).await?;
            Ok::<_, io::Error>(())
        } => {}
        Ok(_) = async {
            let mut socket = TcpStream::connect(addr2).await?;
            socket.write_all(data).await?
            Ok::<_, io::Error>(())
        } => {}
        else => {}
    };
    
    Ok(())
}
```

data 变量被从两个异步表达式中不可变地借用。当其中一个操作成功完成时，另一个就会被放弃。因为在 `Ok(_)` 上进行模式匹配，如果一个表达式失败，另一个表达式继续执行。

当涉及到每个分支的 `<handler>` 时，`select!` 保证只运行一个 `<handler>`。正因如此，每个 `<handler>` 都可以相互借用相同的数据。

将两个处理程序都修改了 out：

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();
    
    let mut out = String::new();
    
    tokio::spawn(async move {
        // Send values on `tx1` and `tx2`
    });
    
    tokio::select! {
        _ = rx1 => {
            out.push_str("rx1 completed");
        }
        
        _ = rx2 => {
            out.push_str("rx2 completed");
        }
    }
    
    println!("{}", out);
}
```



## 8.7 循环

`select!` 宏经常在循环中使用。

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx1, mut rx1) = mpsc::channel(128);
    let (tx2, mut rx2) = mpsc::channel(128);
    let (tx3, mut rx3) = mpsc::channel(128);
    
    loop {
        let msg = tokio::select! {
            Some(msg) = rx1.recv() => msg,
            Some(msg) = rx2.recv() => msg,
            Some(msg) = rx3.recv() => msg,
            else => { break }
        };
        
        println!("Got {}", msg);
    }
    
    println!("All channels have been closed");
}
```

在三个通道接收器上进行 select，当在任何一个通过上接收到消息时，它被写入 STDOUT。当一个通道被关闭时，`recv()` 返回 None。通过使用模式匹配，`select!` 宏继续在其余通道上等待。当所有的通道都关闭时，else 分支被评估，循环被终止。

`select!` 宏随机挑选分支，首先检查是否准备就绪。当多个通道有等待值时，将随机挑选以一个通道来接收。



## 8.8 恢复异步操作

运行异步函数，直到它完成或者在通道上收到以一个偶数

```rust
async fn action() {
    // Some asynchronous logic
}

#[tokio::main]
async fn main() {
    let (mut tx, mut rx) = tokio::sync::mpsc::channel(128);
    
    let operation = action();
    tokio::pin!(operation);
    
    loop {
        tokio::select! {
            _ = &mut operation => break,
            Some(v) = rx.recv() => {
                if v % 2 == 0 {
                    break;
                }
            }
        }
    }
}
```

请注意，不要再 `select!` 宏中调用 `action()`，而是再循环之外调用它。`action()` 的返回值被分配给 operation，而不调用 `.await`。然后再 operation 上调用 `tokio::pin!`

在 `select!` 循环中，需要传入 `&mut operation`。循环的每个迭起都使用相同的 operation，而不是对 `action()` 发出一个新的调用。

另一个 `select!` 分支从通道接收消息，如果消息时偶数，则完成了循环。否则，再次启动 `select!`

`tokio::pin!` 实现了 `.await` 一个引用，被引用的值必须被 pin 或者实现 Unpin



重新实现逻辑：

- 在通道上等待一个偶数
- 使用偶数作为输入启动异步操作
- 等待操作，但同时在通道上监听更多的偶数
- 如果在现有的操作完成之前收到一个新的偶数，则中止现有的操作，用心的偶数重新开始操作

```rust
async fn action(input: Option<32>) -> Option<String> {
    // If the input is `None`，return `None`
    // This could also be written as `let i = input?;`
    let i = match input {
        Some(input) => input,
        None => return None,
    };
    // async logic here
}

#[tokio::main]
async fn main() {
    let (mut tx, mut rx) = tokio::sync::mpsc::channel(128);
    
    let mut done = false;
    let operation = action(None);
    tokio::pin!(operation);
    
    tokio::spawn(async move {
        let _ = tx.send(1).await;
        let _ = tx.send(2).await;
        let _ = tx.send(3).await;
    });
    
    loop {
        tokio::select! {
            res = &mut operation, if !done => {
                done = true;
                
                if Some(v) = res {
                    println!("GOT = {}", v);
                    return;
                }
            }
            
            Some(v) => rx.recv() {
                if v % 2 == 0 {
                    // `.set` is a method on `Pin`
                    operation.set(action(Some(v)));
                    done = false;
                }
            }
        }
    }
}
```

`async fn` 函数在循环外调用，并被分配给 operation。operation 变量被 pin 住。循环在 operation 和通道接收器上都进行 select。

注意 action 时如何将 `Option<i32>` 作为参数的。在接收第一个偶数之前，需要将 operation 实例化为某种东西。让 action 接收 `Option` 并返回 Option，如果传入的是 None，则返回None。在第一个循环迭代中，operation 立即以 None 完成。

第一个分支的新语法 `, if !done`，他山一个分支的前提条件。



## 8.9 任务的并发性

`tokio::spoon` 和 `select!` 都可以运行并发的异步操作。然后，用于运行并发操作的策略是不同的。`tokio::spawn` 函数接收一个异步操作并生成一个新的任务来运行它。任务是 tokio 运行时安排的对象。两个不同的任务由 Tokio 独立调度。它们可能同时运行在不同的操作系统线程上。正因如此，一个spawn的任务和一个spawn的线程有同样的限制，不能借用。

`select!` 宏在同一个任务上勇士运行所有分支，因为 `select!` 宏的所有分支都在用一个任务上执行，所以它们永远不会同时运行。`select!` 宏在一个任务上复用异步操作。



# 9. stream

流时一个数值的异步序列。它是 Rust 的 `srd::iter::Iterator` 的异步等价物，由 Stream trait 表示。流可以在 async 函数中被迭代。它们也可以使用适配器进行转换。Tokio 在 StreamExt trait 上提供了许多常见的适配器

Tokio 的 Stream 工具存在于 `tokio-stream` crate 中：

```toml
tokio-stream = "0.1"
```



## 9.1 迭代

目前，Rust编程语言不支持异步 for 循环，相反，流的迭代是通过与 `StreamExt::next()` 搭配的 `while let` 循环完成的

```rust
use tokio_stream::StreamExt;

#[tokio::main]
async fn main() {
    let mut stream = tokio_stream::iter(&[1, 2, 3]);
    
    while let Some(v) stream.next().await {
        println!("GOT = {:?}", v);
    }
}
```



## 9.2 Mini-Redis 广播

```rust
use mini_redis::client;
use tokio_stream::StreamExt;

async fn publish() -> mini_redis::Result<()> {
    let mut client = client::connect("127.0.0.1:6379").await?;

    // Publish some data
    client.publish("numbers", "1".into()).await?;
    client.publish("numbers", "two".into()).await?;
    client.publish("numbers", "3".into()).await?;
    client.publish("numbers", "four".into()).await?;
    client.publish("numbers", "five".into()).await?;
    client.publish("numbers", "6".into()).await?;

    Ok(())
}

async fn subscribe() -> mini_redis::Result<()> {
    let client = client::connect("127.0.0.1:6379").await?;

    let subscriber = client.subscribe(vec!["numbers".to_string()]).await?;
    let messages = subscriber.into_stream();

    tokio::pin!(messages);

    while let Some(msg) = messages.next().await {
        println!("Got = {:?}", msg);
    }

    Ok(())
}

#[tokio::main]
async fn main() -> mini_redis::Result<()> {
    tokio::spawn(async {
        publish().await
    });

    subscribe().await?;

    println!("DONE");
    Ok(())
}
```

在订阅之后，`into_stream()` 被调用到返回的订阅者上。这将消耗 subscriber，返回一个 stream，在消息达到时产生消息。在开始迭代消息前，注意流用 `tokio::pin` 在 栈上的。在一个流上调用 `next()` 需要被 pin 住。`into_stream()` 函数返回的是一个没有 pin 的流，必须明确地 pin 它，以便对其进行遍历

当一个 Rust 值在内存中不能在被移动时，它就被 pin 了。被 bin 的值的一个关键属性是，指针可以被带到被 pin 的数据上，并且调用者可以确信该指针保持有效。这个特性被 `async/await` 点借用数据。



## 9.3 适配器

接受一个 stream 并返回另一个 stream 的函数通常被称为 "stream adaptor"，因为它们是 "适配器模式" 的一种形式。常用的适配器包括 map、take 和 filter

通过 take 实现限流：

```rust
let messages = subscriber.into_stream().take(3);
```

通过 filter 过滤不符合条件的消息：

```rust
let messages = subscriber.into_stream()
	.filter(|msg| match msg {
        Ok(msg) if msg.content.len() == 1 => true,
        _ => false,
	})
	.map(|msg| msg.unwrap().content)
	.take(3)；
```



## 9.4 实现stream

stream trait 与 future trait 非常相似

```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Stream {
    type Item;
    
    fn poll_next(
    	self: Pin<&mut Self>,
        cx: &mut Context<'_>
    ) -> Poll<Option<Self::Item>>;
    
    fn size_hint(&self) -> (usize, Option<usize) {
        (0, None)
    }
}
```

`Stream::poll_next()` 函数很像 `Future::poll`，只是它可以被反复调用，以便从流中接收许多值。当一个流还没有准备好返回一个值时，就会返回 `Poll::Pending` 来代替。该任务的 waker 被注册。一旦流应该被再次 poll，该唤醒者将被通知。

`size_hint()` 方法与迭代器的使用方法相同。

将 Delay Future 转换为 Stream，以 10 毫秒的间隔产生三次 `()`

```rust
use tokio_stream::Stream;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::Duration;

struct Interval {
    rem: usize,
    delay: Delay,
}

impl Stream for Interval {
    type Item = ();
    
    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<()>> {
        if self.rem == 0 {
            // No more delays
            return Poll::Ready(None);
        }
        
        match Pin::new(&mut self.delay).poll(cx) {
            Poll::Ready(_) => {
                let when = self.delay.when + Duration::from_millis(10);
                self.delay = Delay { when };
                self.rem -= 1;
                Poll::Ready(Some(()))
            }
            Poll::Pending => Poll:Pending,
        }
    }
}
```



### 9.4.1 async-stream

使用 Stream Trait 手动实现流很繁琐的。但 Rust 编程语言目前还不支持用于自定义流的 `async/await` 语法。

`async-stream` crate 可以作为一个临时的解决方案。这个 crate 提供了 `async_stream!` 宏，将输入转化为一个流。使用这个 crate，上面的 interval 可以这样实现：

```rust
use async_stream::stream;
use std::time::{Duration, Instant};

stream! {
    let mut when = Instant::now();
   	for _ in 0..3 {
        let delay = Delay { when };
        delay.await;
        yield();
        when += Duration::from_millis(10);
    }
}
```



# 10. 桥接同步代码

## 10.1 `#[tokio::main]`

`#[tokio::main]` 宏将主函数替换为非同步主函数，它启动一个运行时，然后调用代码

```rust
#[tokio::main]
async fn main() {
    println!("Hello world");
}
```

代码转换为

```rust
fn main() {
    tokio::runtime::Builder::new_multi_thread()
    	.enable_all()
    	.build()
    	.unwrap()
    	.block_on(async {
            println!("Hello world");
    	})
}
```



## 10.2 到 mini-redis 的同步接口

通过存储 Runtime 对象并使用其 block_on 方法来构建 mini-redis 的同步接口

封装的接口是异步的 client 类型：

- Client::get
- Client::set
- Client::set_expires
- Client::publish
- Client::subscribe

`blocking_client.rs`，async Client 类型的封装结构来初始化：

```rust
use tokio::net::ToSocketAddrs;
use tokio::runtime::Runtime;

pub use crate::client::Message;

/// Established connection with a Redis server
pub struct BlockingClient {
    /// The asynchronous `Client`
    inner: crate::client::Client,
    
    /// A `current_thread` runtime for executing operations on
    /// the asynchronous client in a blocking manner
    rt: Runtime,
}

pub fn connect<T: ToSocketAddrs>(addr: T) -> crate::Result<BlockingClient> {
    let rt = tokio::runtime::Builder::new_current_thread()
    	.enable_all()
    	.build()?;
    
    // Call the asynchronous connect method using the runtime
    let inner = rt.block_on(crate::client::connect(addr))?;
    
    Ok(BlockingClient { inner, rt })
}
```

通常在使用 Tokio 时，会使用默认的 multi_thread 运行时，它将产生一堆后台线程，这样它就可以有效地同时运行许多东西。在上述实例中，每次只做一件事，所以不会因为运行多个线程而获得任何好处，这使得 current_thread 运行时成为完美的选择，因为它不会产生任何线程。

`current_thread` 运行时不产生新线程，所以它只在 block_on 被调用时运行。一旦 block_on 返回，所有在该运行时上生成的任务将冻结，直到你再次调用 block_on。如果 spawn 的任务在不调用 block_on 时必须继续运行，要使用 multi_thread 运行时。

`enable_all` 调用启用了 Tokio 运行时的 IO 和定时器驱动。如果它们没有被启动，运行时就无法执行IO或定时器。



实现 BlockingClient：

```rust
use bytes::Bytes;
use std::time::Duration;

impl BlockingClient {
    pub fn get(&mut self, key: &str) -> crate::Result<Option<Bytes>> {
        self.rt.block_on(self.inner.get(key))
    }
    
    pub fn set(&self, key: &str, value: Bytes) -> crate::Result<()> {
        self.rt.block_on(self.inner.set(key, value))
    }
    
    pub fn set_expires(&mut self, key: &str, value: Bytes, expiration: Duration) 
    	-> crate::Result<()> {
        self.rt.block_on(self.set_expires(key, value, expiration))
    }
    
    pub fn publish(&mut self, channel: &str, message: Bytes) -> crate::Result<u64> {
        self.rt.block_on(self.inner.publish(channel, message))
    }
}
```



Client::subscribe 方法，它将 Client 转化为 Subscriber 对象：

```rust
/// A client that has entered pub/sub mode
/// 
/// Once clients subscribe to a channel, they may only perform
/// pub/sub related commands. The `BlockingClient` type is
/// transactioned to a `BlockingSubscriber` type in order to
/// prevent non-pub/sub methods from being called
pub struct BlockingSubscriber {
    /// The asynchronous `Subscriber`
    inner: crate::client::Subscriber,
    
    /// A `current_thread` runtime for executing operations on the
    /// asynchronous client in a blocking manner
    rt: Runtime,
}

impl BlockingClient {
    pub fn subcribe(self, channels: Vec<String>) -> crate::Result<BlockingSubscriber> {
        let subscriber = self.rt.block_on(self.inner.subscribe(channels))?;
        Ok(BlockingSubscriber {
            inner: subscriber,
            rt: self.rt,
        })
    }
}

impl BlockingSubscriber {
    pub fn get_subscribed(&self) -> &[String] {
        self.inner.get_subscribed()
    }
    
    pub fn next_message(&mut self) -> crate::Result<Option<Message>> {
        self.rt.block_on(self.inner.next_message())
    }
    
    pub fn subscribe(&mut self, channels: &[String]) -> crate::Result<()> {
        self.rt.block_on(self.inner.subscribe(channels))
    }
    
    pub fn unsubscribe(&mut self, channels: &[String]) -> crate::Result<()> {
        self.rt.block_on(self.inner.unsubscribe(channels))
    }
}
```



## 10.3 其他方法

上面解释了实现同步包装器的最简单方法，但这不是唯一的方法，有这些方法：

- 创建一个 Runtime 并在异步代码上调用 block_on
- 创建一个 Runtime 并在其上生成事物
- 在一个单独的线程中运行 Runtime 并向其发送消息



### 10.3.1 在运行时上生成事物

调用运行时对象的 spawn 方法，创建以一个新的在运行时上运行的后台任务

```rust
use std::time::Duration;
use tokio::runtime::Builder;

fn main() {
    let runtime = Builder::new_current_thread()
        .worker_threads(1)
        .enable_all()
        .build()
        .unwrap();

    let mut handles = Vec::with_capacity(10);
    for i in 0..10 {
        handles.push(runtime.spawn(runtime.spawn(my_bg_task(i))));
    }

    // Do something time-consuming while the background tasks execute
    std::thread::sleep(Duration::from_millis(750));
    println!("Finished time-consuming task");

    // Wait for all of them to complete
    for handle in handles {
        // The `spawn` method returns a `JoinHandle`. A `JoinHandle` is
        // a future, so we can wait for it using `block_on`
        runtime.block_on(handle).unwrap().unwrap();
    }
}

async fn my_bg_task(i: u64) {
    // By subtracting, the tasks with larger values of i sleep
    // for a shorter duration
    let millis = 1000 - 50*i;
    println!("Task {} sleeping for {} ms", i, millis);

    tokio::time::sleep(Duration::from_millis(millis)).await;
    println!("Task {} done", i);
}
```

通过对调用 spawn 返回的 JoinHandle 调用 block_on 来等待生成的任务完成，但这不是唯一的方法，可使用一些替代方法：

- 使用消息传递通道，如 `tokio::sync::mpsc`
- 修改由 Mutex 等保护的共享值。这对GUI中的进度条来说是一个很好的方法，GUI在每一帧都会读取共享值

spawn 方法在 Handle 类型上也是可用的。Handle 类型可以被克隆，以便在一个运行时中获得许多句柄，每个 Handle 都可以用来在运行时中生成新的任务



### 10.3.2 发送消息

运行时使用消息传递来通信

```rust
use tokio::runtime::Builder;
use tokio::sync::mpsc;

pub struct Task {
    pub name: String,
}

async fn handle_task(task: Task) {
    println!("Got task {}", task.name);
}

#[derive(Clone)]
pub struct TaskSpawner {
    spawn: mpsc::Sender<Task>,
}

impl TaskSpawner {
    pub fn new() -> TaskSpawner {
        // Set up a channel for communicating
        let (send, mut recv) = mpsc::channel(16);

        // Build the runtime for the new thread
        let rt = Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();

        std::thread::spawn(move || {
            rt.block_on(async move {
                while let Some(task) = recv.recv().await {
                    tokio::spawn(handle_task(task));
                }

                // Once all senders have gone out of scope,
                // the `.recv()` call returns None and it will
                // exit from the while loop and shut down the thread
            });
        });

        TaskSpawner { spawn: send }
    }

    pub fn spawn(&self, task: Task) {
        match self.spawn.blocking_send(task) {
            Ok(()) => {},
            Err(_) => panic!("The shared runtime has shut down"),
        }
    }
}
```





# 11. IO类型

## 11.1 硬件层面

IO 是一种和外围设备交换数据的方式，包括磁盘读写、网络数据包接收和发送、显示器输出、键盘鼠标输入等

现代操作系统和外围设备的交流取决于外围设备的特定类型及它们的固件版本和硬件能力。随着外围设备越来越高级，它们呢个给同时处理多个并发的读写数据请求，串行交流已被淘汰。在这些场景中，外围设备和CPU间的交流在硬件层面都是异步的。

这个异步机制被称为硬件中断 (hardware interrupt)。CPU请求外围设备读取数据，会进入一个无限循环，每次都会检查外围设备的数据是否可用，直到获得数据为止。这种方法称为轮询(polling)，因为 CPU 需要保持检查外围设备。

在现代硬件中，取而代之发生的是 CPU 请求外围硬件执行操作，然后就忘了这件事，继续处理其他的 CPU 指令。只要外围设备做完了，它会通过电路中断来通知 CPU。这发生在硬件中，CPU不需要停下来或检查这个外围设备，可以继续执行其它规则，直到周边设备说已经做完了



## 11.2 软件层面

- **阻塞 Blocking**：发生IO阻塞时，线程休眠，除了等待IO完成，不能干其他事。
- **非阻塞 Non-Blocking**：发生IO阻塞时，线程不休眠，继续干其他工作，并会检查之前的IO是否已完成
- **多路复用 Multiplexed**：解决线程重复进行非阻塞IO，状态轮询导致过多消耗CPU的问题。支持将所有需要IO操作写入队列，阻塞在所有的操作上。当其中一个IO完成之后由OS唤醒线程。
- **异步 Async**：多路复用的问题在于IO准备好供线程处理前，线程仍然在休眠。对许多程序来说，这很好，线程等待IO操作完成的适合没有其他事情可做。但有些时候确实有其他事要做。同时存在数值计算和IO操作时，需要在数值计算完成时被IO中断，IO完成时也需要执行中断。这些操作是通过事件回调完成的。执行读取的调用完成需要一个回调，并立即返回。在IO完成的时候，操作系统会暂停线程，并执行回调，一旦回调执行完毕，它将恢复线程。













































































