# 1.  概览

## 1.1 tokio 依赖

在 `Cargo.toml` 中添加依赖：

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
```

`tokio` 有很多功能和特性，例如 `TCP`、`UDP`、`Unix sockets`、同步工具，多调度类型等待，不是每个应用都需要所有这些特性。为了优化编译时间和最终生成的可执行文件大小、内存占用等，应用可选择性地引入特征。



## 1.2 async main

两种实现方式：

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



# 2. mini-redis 客户端

## 2.1 mini-redis 服务

```bash
# 安装
cargo install mini-redis

# 启动
mini-redis-server

# 验证
mini-redis-cli set foo 1
mini-redis-cli get foo
```



## 2.2 客户端

添加依赖包：

```toml
[dependencies]
tokio = { version="1.47.0", features = ["full"] }
mini-redis = "0.4.1"
```

客户端：

```rust
use mini_redis::{client, Result};

#[tokio::main]
async fn main() -> Result<()> {
    let mut client = client::connect("127.0.0.1:6379").await?;

    client.set("hello", "world".into()).await?;

    let result = client.get("hello").await?;
    println!("{:?}", result);

    Ok(())
}
```



# 3. mini-redis 服务端

将客户端移动到 examples 目录下，然后以 example 方式运行：

```bash
mkdir -p examples
cp src/main.rs examples/hello-redis.rs
```

在 `Cargo.toml` 增加 `[[example]]`：

```toml
[[example]]
name = "hello-redis"
path = "examples/hello-redis.rs"
```

运行服务：

```bash
cargo run --example hello-redis
```



## 3.1 接收TCP请求

```rust
use mini_redis::{Connection, Frame};
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        process(stream).await;
    }
}

async fn process(stream: TcpStream) {
    let mut connection = Connection::new(stream);

    if let Some(frame) = connection.read_frame().await.unwrap() {
        println!("GOT frame: {:?}", frame);

        let response = Frame::Error("unimplemented".to_string());
        connection.write_frame(&response).await.unwrap();
    }
}
```



## 3.2 生成任务

为了并发处理连接，需要为每一个连接都生成一个新的任务，然后在任务中处理连接：

```rust
#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        let (stream, _) = listener.accept().await.unwrap();
        tokio::spawn(async move {
            process(stream).await;
        });
    }
}
```

生成任务的关键要点：

- **任务**：

  - 是一个异步的绿色现场，由 `tokio::spawn` 创建，返回一个 `JoinHandle` 类型的句柄，调用者使用该举报跟创建的任务进行交互
  - 调度器的执行单元。`spawn` 生成的任务会首先提交给调度器，然后由它负责调度执行。需要注意的是：**执行任务的线程未必是创建任务的线程，任务完全有可能运行在另一个不同的线程上，且任务生成后，还可能会在线程间被移动**
  - 任务比线程更轻量，创建一个任务仅仅需要一次 64 Bytes 大小的内存分配。类似Golang的协程

- **`'static` 约束**

  - 创建任务时，该任务类型的生命周期必须是 `'static`，这意味着，在任务中，不能使用外部数据引用。
  - 在 `async` 语句块使用 `move` 关键字，实现将变量的所有权转移到新创建的任务中，以解决任务使用外部数据引用的问题

- **Send 约束**

  - 任务必须实现 `Send` 特征，因为当这些任务在 `.await` 执行过程中发生阻塞时，tokio 调度器会将任务在线程间移动
  - **一个任务要实现 `Send` 特征，它在 `.await` 调用过程中所持有的全部数据都必须实现 `Send` 特征**
  

示例1：能够正常工作

```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        // 通过语句块，提前结束 rc 的生命周期
        {
            let rc = Rc::new("hello");
        	println!("{}", rc);
        }
    
        // rc 作用域已失效，当任务让其所有权给当前线程时，无需作为状态被保存起来
        yield_now().await;
    })
}
```




示例2：不能正常工作

```rust
#[tokio::main]
async fn main() {
    tokio::spawn(async {
        let rc = Rc::new("hello");
        
        // `rc` 在 `.await` 后还被继续使用，因此它必须被作为任务的状态保存起来
        yield_now().await;
        
        // 注释掉下面一行代码，依旧保存，因为是否保存，不取决于`rc`是否已被使用，而是`.await`在调用时是否任然处于`rc`的作用域中
        println!("{}", rc);
        
        // `rc` 的作用域结束
    })
}
```

  

## 3.3 使用 HashMap 存储数据

```rust
async fn process(stream: TcpStream) {
    use mini_redis::Command::{self, Get, Set};
    use std::collections::HashMap;

    // 缓存数据
    let mut db = HashMap::new();

    // 从数据流中解析数据帧
    let mut conn = Connection::new(stream);

    // 循环读取数据帧，并返回响应
    while let Some(frame) = conn.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                db.insert(cmd.key().to_string(), cmd.value().to_vec());
                Frame::Simple("OK".to_string())
            },
            Get(cmd) => {
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone().into())
                } else {
                    Frame::Null
                }
            },
            cmd => panic!("unsupported : {:?}", cmd),
        };

        conn.write_frame(&response).await.unwrap();
    }
}
```



# 4. 共享状态

## 4.1 bytes 依赖包

使用 `Vec<u8>` 保存数据，对它进行克隆时，会将底层数据也整个复制一份，效率很低，但克隆操作在多连接间数据共享又是比不可少的

`bytes` 中的 **`Bytes` 类型，对该类型的值进行克隆时，不会克隆底层数据，非常适合在多连接间共享数据**。

`Bytes` 是一个引用计数类型，与 `Arc` 类似，或者说 `Bytes` 就是基于 `Arc` 实现的，但提供了一些额外的能力。

在 `Cargo.toml` 增加 `bytes` 依赖：

```toml
[dependencies]
bytes = "1"
```



## 4.2 数据存储类型

```rust
use bytes::Bytes;
use std::collection::HashMap;
use std::sync::{Arc, Mutex};

type Db = Arc<Mutex<HashMap<String, Bytes>>>;
```

在 `tokio` 的异步代码中，一个常见的错误是无条件地使用 `tokio::sync::Mutex`。但是，**`tokio` 提供的异步锁只应该在跨多个 `.await` 调用时使用**，且其内部也是 `std::sync::Mutex`。

在异步代码中，关于锁的使用：

- **锁如果在多个 `.await` 中持有，应该使用 `tokio::Mutex`**，原因是 `.await` 的过程中锁可能在线程间转移，若使用 `std::sync::Mutex` 存在死锁的可能。例如某个任务刚获取完锁，还没有使用完就因为 `.await` 让出了当前线程的所有权，结果下一个任务又去获取锁，从而造成死锁。
- 锁竞争不多的情况下，使用 `std::sync::Mutex`
- 锁竞争多，可以考虑使用第三方库提供的性能更高的锁，例如 `parking_lot::Mutex`



## 4.3 重构服务端

```rust
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use bytes::Bytes;
use mini_redis::{Connection, Frame};
use tokio::net::{TcpListener, TcpStream};

type Db = Arc<Mutex<HashMap<String, Bytes>>>;

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    let db = Arc::new(Mutex::new(HashMap::new()));
    loop {
        let (stream, _) = listener.accept().await.unwrap();

        // 拷贝一份
        let db = db.clone();

        tokio::spawn(async move {
            process(stream, db).await;
        });
    }
}

async fn process(stream: TcpStream, db: Db) {
    use mini_redis::Command::{self, Get, Set};

    // 从数据流中解析数据帧
    let mut conn = Connection::new(stream);

    // 循环读取数据帧，并返回响应
    while let Some(frame) = conn.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                let mut db = db.lock().unwrap();
                db.insert(cmd.key().to_string(), cmd.value().clone());
                Frame::Simple("OK".to_string())
            },
            Get(cmd) => {
                let db = db.lock().unwrap();
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone())
                } else {
                    Frame::Null
                }
            },
            cmd => panic!("unsupported : {:?}", cmd),
        };

        conn.write_frame(&response).await.unwrap();
    }
}
```



## 4.4 任务、线程和锁竞争

当竞争不多的时候，使用阻塞性的锁去保护共享数据是一个正确的选择。当一个锁竞争触发后，当前正在执行任务(请求锁)的线程会被阻塞，并等待锁被前一个使用者释放。**锁竞争不仅仅会导致当前的任务被阻塞，还好导致执行任务的线程被阻塞，因此该线程准备执行的其它任务也会因此被阻塞！**

默认情况下，`tokio` 调度器使用了多线程模式，此时如果有大量的任务都需要访问同一个锁，那么锁竞争将变得激烈起来。当然，也可以使用 `current_thread` 运行时设置，它会使用一个单线程的调度器，所有任务都会创建并执行在当前线程上，因此不会再有锁竞争。

当同步锁的竞争变成问题时，`tokio` 提供的异步锁几乎并不能解决该问题，可考虑如下选项：

- 创建专门的任务，并使用消息传递的方式来管理状态
- 将锁进行分片
- 重构代码以避免锁



由于每个 `key` 都是独立的，因此对锁进行分片将成为一个不错的选择：

```rust
type ShardedDb = Arc<Vec<Mutex<HashMap<String, Vec<u8>>>>>;

fn new_shared_db(num_shards: usize) -> ShardedDb {
    let mut db = Vec::with_capacity(num_shards);
    for _ in 0..num_shards {
        db.push(Mutex::new(HashMap::new()));
    }
    Arc::new(db)
}
```

使用 `hash` 算法进行分片：

```rust
let shard = db[hash(key) % db.len()].lock().unwrap();
shard.insert(key, value);
```

该算法存在的缺陷：分片的数量不能变，一旦变了后，分片将全部乱掉。可以考虑 `dashmap`，它提供了更复杂、更精妙的支持分片的 `hash map`



## 4.5 在 `.await` 期间持有锁

```rust
use std::sync::{Mutex, MutexGuard};

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
    
    do_something_async().await;
    
    // 锁在此超出作用域释放
}
```

错误的原因在于 `std::sync::MutexGuard` 类型并没有实现 `Send` 特征，这意味着不能将一个 `Mutex` 锁发送到另一个线程，因为 `.await` 可能会让任务转移到另一个线程上执行。



### 4.5.1 提前释放锁

通过代码块，让 `Mutex` 锁在 `.await` 被调用前就被释放：

```rust
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    {
        let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
        *lock += 1;
    } // `lock` 超出作用域，被释放
    
    do_something_async().await;
}
```

下面的代码不能工作：

```rust
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
    drop(lock);
    
    do_something_async().await;
}
```

原因：编译器不够聪明，`drop` 虽然释放了锁，但锁的作用域依然会持续到函数结束。



### 4.5.2 在 `.await` 期间不持有锁

将 `Mutex` 放入一个结构体中，并且只在该结构体的非异步方法中使用该锁：

```rust
use std::sync::Mutex;

struct CanIncrement {
    mutex: Mutex<i32>,
}

impl CanIncrement {
    // 该方法不是 `async`
    fn increment(&self) {
        let mut lock = self.mutex.lock().unwrap();
        *lock += 1;
    }
}

async fn increment_and_do_stuff(can_incr: &CanIncrement) {
    can_incr.increment();
    do_something_async().await;
}
```



### 4.5.3 使用异步任务和通过消息传递来管理状态

该方法常常用于共享的资源是 `I/O` 类型的资源



### 4.5.4 使用 `tokio` 提供的异步锁

异步锁的最大优点：它可以在 `.await` 执行期间被持有，而且不会有任何问题。但代价是性能开销会更高。

```rust 
use tokio::sync::Mutex;

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock = mutex.lock().await;
    *lock += 1;
    
    do_something_async().await;
}
```



# 5. 消息传递

将已实现的 `src/main.rs` 服务端代码放入 bin 目录中，分包：

```bash
mkdir -p src/bin

# 服务端代码
mv src/main.rs src/bin/server.rs
cargo run --bin server

# 客户端代码
touch src/bin/client.rs
```



## 5.1 错误的实现

同时运行两个 redis 命令，尝试为每个命令生成一个任务：

```rust
use mini_redis::client;

#[tokio::main]
async fn main() {
    let mut client = client::connect("127.0.0.1:6379").await.unwrap();

    // 两个任务
    let t1 = tokio::spawn(async {
        let res = client.get("hello").await;
        println!("RESPONSE={:?}", res);
    });

    let t2 = tokio::spawn(async {
        client.set("hello", "world".into()).await.unwrap();
    });

    t1.await.unwrap();
    t2.await.unwrap();
}
```

编译错误：

```
error[E0373]: async block may outlive the current function, but it borrows `client`, which is owned by the current function                                                                                                        
 --> src\bin\client.rs:8:27
  |
8 |     let t1 = tokio::spawn(async {
  |                           ^^^^^ may outlive borrowed value `client`
9 |         let res = client.get("hello").await;
  |                   ------ `client` is borrowed here
  |
```

存在的问题：

- 两个任务都需要去访问 `client`，但 `client` 没有实现 `Copy` 特征，再加上并没有实现相应的共享代码，因此自然会报错。
- 方法 `set` 和 `get` 都使用了 `client` 的可变引用 `&mut self`，由此还会造成同时借用两个可变引用的错误。



解决方法：

- `std::sync::Mutex` 无法被使用，因为同步锁无法跨越 `.await` 调用时使用
- `tokio::sync::Mutex` 可以用，但同时只能运行一个请求。若客户端实现了 redis 的 pipelining，那这个异步锁就会导致连接利用率不足



## 5.2 消息通道

`tokio` 提供多种消息通道 (channel)，可以满足不同场景的需求：

- `mpsc`：多生产者，单消费者
- `oneshot`：单生产者，单消费者，一次只能发送一条消息
- `broadcast`：多生产者，多消费者。每一条消息都可以被所有接收者收到
- `watch`：单生产者，多消费者。接收者只能看到最新的一条消息，适用于监听配置文件变化等场景

另外，多生产者、多消费者，且每一条消息只能被其中一个消费接收这种需求，可以使用 `async-channel` 包

在多线程中使用的 `std::sync::mpsc` 和 `crossbean::channel` 等消息通道，在等待消息时，会阻塞当前线程，因此不适用于 `async` 编程。



## 5.3 定义消息类型

```rust
use bytes::Bytes;

#[derive(Debug)]
enum Command {
    Get {
        key: String,
    },
    Set {
        key: String,
        val: Bytes,
    }
}
```



## 5.4 创建消息通道

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
    let tx2 = tx.clone();

    tokio::spawn(async move {
        tx.send("sending from first handler").await.unwrap();
    });

    tokio::spawn(async move {
        tx2.send("sending from second handler").await.unwrap();
    });

    while let Some(msg) = rx.recv().await {
        println!("GOT: {}", msg);
    }
}
```

注意事项：

- 缓冲队列长度32，一旦存满，使用 `send(...).await` 的发送者会**进入睡眠**，直到缓冲队列可以放入新的消息(被接收者消费)
- 发送者 `tx` 可以使用 `clone` 方法克隆多个，但接收者不能，因为通道类型是  `mpsc`
- 当所有发送者都被 `Drop` 后 (超出作用域或调用 `drop` 函数主动释放)，就不再会有任何消息发送给该通道，此时 `recv` 方法将返回 `None`，也意味着通道已被关闭



## 5.5 生成管理任务

```rust
use bytes::Bytes;
use tokio::sync::mpsc;
use mini_redis::{client};

#[derive(Debug)]
enum Command {
    Get { key: String },
    Set { key: String, value: Bytes },
}

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
    let tx2 = tx.clone();

    // 任务1：获取值
    let t1 = tokio::spawn(async move {
        tx.send(Command::Get { key: "hello".to_string() }).await.unwrap();
    });

    // 任务2：设置值
    let t2 = tokio::spawn(async move {
        tx2.send(Command::Set { key: "hello".to_string(), value: "world".into() }).await.unwrap();
    });

    // 管理任务：通过消息通道接收者 `rx` 接收redis请求
    let manager = tokio::spawn(async move {
		// 建立与服务端的连接
        let mut client = client::connect("127.0.0.1:6379").await.unwrap();

        // 接收消息
        while let Some(cmd) = rx.recv().await {
            use Command::*;

            match cmd {
                Get { key } => {
                    let res = client.get(&key).await.unwrap();
                    println!("GET: {:?}", res);
                }
                Set { key, value } => {
                    client.set(&key, value).await.unwrap();
                }
            }
        }
    });

    t1.await.unwrap();
    t2.await.unwrap();
    manager.await.unwrap();
}
```



## 5.6 接收响应消息

接收管理任务返回的结果消息：

```rust
use tokio::sync::oneshot;

let (tx, rx) = oneshot::channel();
```

改造 Command，增加响应字段：

```rust
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
    },
}
```

改造任务：

```rust
#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
    let tx2 = tx.clone();

    let t1 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();
        tx.send(Command::Get {
            key: "hello".to_string(),
            resp: resp_tx,
        }).await.unwrap();

        let resp = resp_rx.await;
        println!("Got response: {:?}", resp);
    });

    let t2 = tokio::spawn(async move {
        let (resp_tx, resp_rx) = oneshot::channel();

        tx2.send(Command::Set {
            key: "hello".to_string(),
            value: "world".into(),
            resp: resp_tx,
        }).await.unwrap();

        let resp = resp_rx.await;
        println!("Got response: {:?}", resp);
    });

    // 管理任务
    let manager = tokio::spawn(async move {
        let mut client = client::connect("127.0.0.1:6379").await.unwrap();

        while let Some(cmd) = rx.recv().await {
            use Command::*;

            match cmd {
                Get { key, resp } => {
                    let res = client.get(&key).await;
                    let _ = resp.send(res);
                }
                Set { key, value, resp } => {
                    let res = client.set(&key, value).await;
                    let _ = resp.send(res);
                }
            }
        }
    });

    t1.await.unwrap();
    t2.await.unwrap();
    manager.await.unwrap();
}
```



# 6. I/O

`tokio` 中的 I/O 操作和 `std` 的使用方式几无区别，最大的区别是前者是异步的，`tokio` 的读写特征分别是 `AsyncRead` 和 `AsyncWrite`:

- `TcpStream`，`File`，`Stdout`
- `Vec<u8>`，`&[u8]`



## 6.1 `AsyncRead` 和 `AsyncWrite`

这两个特征为字节流的异步读写提供了便利，通常会使用 `AsyncReadExt` 和 `AsyncWriteExt` 提供的工具方法，这些方法都使用 `async` 声明，且需要通过 `.await` 进行调用



### 6.1.1 `async fn read`

`AsyncReadExt::read` 是一个异步方法可以将数据读入缓冲区 (`buffer`) 中，然后返回读取的字节数

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncReadExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::open("foo.txt").await?;
    let mut buffer = [0; 10];

    // 从文件中读取10个字节
    let n = file.read(&mut buffer).await?;
    println!("{:?}", &buffer[..n]);

    Ok(())
}
```



### 6.1.2 `async fn read_to_end`

`AsyncReadExt::read_to_end` 方法会从字节流中读取所有的字节，直到遇到 `EOF`：

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncReadExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::open("foo.txt").await?;
    let mut buffer = Vec::new();

    file.read_to_end(&mut buffer).await?;
    println!("{:?}", buffer);

    Ok(())
}
```



### 6.1.3 `async fn write`

`AsyncWriteExt::write` 尝试将缓冲区内容写入到 `writer` 中，同时返回写入的字节数：

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncWriteExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    let n = file.write(b"hello world\nanother line").await?;
    println!("Wrote {} bytes", n);

    Ok(())
}
```



### 6.1.4 `async fn write_all`

`AsyncWriteExt::write_all` 将缓冲区的内容全部写入 `writer`

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncWriteExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    file.write_all(b"Hello, world!").await?;

    Ok(())
}
```



## 6.2 实用函数

和标准库一样，`tokio::io` 模块包含了多个实用的函数或API，用于处理标准输入、输出、错误等

使用 `tokio::io::copy` 异步的将 `reader` 中的内容拷贝到 `writer` 中：

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncWriteExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    file.write_all(b"Hello, world!").await?;

    Ok(())
}
```



## 6.3 Echo 服务

从用户建立的 TCP 连接的 socket 中读取数据，然后将同样的数据写回到该 socket 中



### 6.3.1 `io::copy`

基本框架：通过 loop 循环接收 TCP 连接，然后为每条连接创建一个单独的任务去处理

```rust
use tokio::io;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;
        tokio::spawn(async move {
            // TODO: 数据拷贝
        });
    }
}
```



`io::copy` 有两个参数，但这里的 `reader` 和 `writer` 是同一个 `socket`，需要对其进行两次可变借用，这明显违背了 Rust 的借用规则 

```rust
io::copy(&mut socket, &mut socket).await
```



**分离读写器**：通过 `io::split` 方法，将 `socket` 分离成一个 `reader` 和 `writer`

服务端：

```rust
#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;
        tokio::spawn(async move {
            let (mut rd, mut wr) = socket.split();
            if io::copy(&mut rd, &mut wr).await.is_err() {
                eprintln!("failed to copy from socket");
            }
        });
    }
}
```

客户端：

```rust
use tokio::io::{self, AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

#[tokio::main]
async fn main() -> io::Result<()> {
    let socket = TcpStream::connect("127.0.0.1:8080").await?;
    let (mut rd, mut wr) = io::split(socket);

    // 异步任务，写数据
    tokio::spawn(async move {
        wr.write_all(b"hello\n").await?;
        wr.write_all(b"world\n").await?;

        Ok::<_, io::Error>(())
    });

    let mut buf = vec![0; 128];

    loop {
        let n = rd.read(&mut buf).await?;
        println!("n: {}", n);
        if n == 0 {
            break;
        }

        println!("GOT {:?}", &buf[..n]);
    }

    Ok(())
}
```



`io::split` 可以用于任何同时实现了 `AsyncRead` 和 `AsyncWrite` 的值，它内部使用 `Arc` 和 `Mutex` 来实现相应的功能。

`tokio` 提供的 `TcpStream` 提供了两种方式进行分离：

- `TcpStream::split` 会获取字节流的引用，然后将其分离成一个 `writer` 和 `reader`。但由于使用了引用方式，它们必须和 `split` 在同一个任务中。其优点就是，这种实现没有性能开销，因为无需 `Arc` 和 `Mutex`
- `TcpStream::into_split`  分离出来的结果可以在任务间移动，内部通过 `Arc` 实现



### 6.3.2 手动拷贝

```rust
use tokio::io::{self, AsyncWriteExt, AsyncReadExt};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
            let mut buf = [0; 1024];

            loop {
                match socket.read(&mut buf).await {
                    Ok(0) => return,
                    Ok(n) => {
                        if socket.write_all(&buf[..n]).await.is_err() {
                            eprintln!("failed to write to socket; drop");
                            return;
                        }
                    }
                    Err(e) => {
                        eprintln!("failed to read from socket; err = {:?}", e);
                        return;
                    },
                }
            }
        });
    }
}
```



# 7. 解析数据帧

通过帧将字节流转换成帧组成的流，每个帧就是一个数据单元，例如客户端发送的一次请求就是一个帧。

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

HTTP 帧：

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

`mini-redis` 通过一个 `Connection` 结构体，内部包含一个 `TcpStream` 以及对帧进行读写的方法：

```rust
use tokio::net::TcpStream;
use mini_redis::{Frame, Result};

struct Connection {
    stream: TcpStream,
    // --snip--
}

impl Connection {
    // 从连接读取一个帧
    pub async fn read_frame(&mut self) -> Result<Option<Frame>> {
        // --snip--
    }
    
    // 将帧写入到连接
    pub async fn write_frame(&mut self, frame: &Frame) -> Result<()> {
        // --snip--
    }
}
```



## 7.1 缓冲读取

`read_frame` 方法会等到一个完整的帧都读取完毕后才返回。它的底层调用 `TcpStream::read` 读取部分帧，先将数据缓冲起来，接着继续等待并读取数据。如果读到多个帧，那第一帧会被返回，然后剩下的数据依然被缓冲起来，等待下一个 `read_frame` 被调用。

为实现该功能，需要为 `Connection` 增加一个读取缓冲区。数据首先从 `socket` 中读取到缓冲区中，接着这些数据会被解析为帧，当一个帧被解析后，该帧对应的数据会从缓冲区被移除。

使用 `Bytes` 的变体 `BytesMut` 作为缓冲区类型：

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
            buffer: BytesMut::with_capacity(4086),  // 4KB缓冲
        }
    }
}
```

实现 `read_frame` 方法：

```rust
use tokio::io::AsyncReadExt;
use bytes::Buf;
use mini_redis::Result;

pub async fn read_frame(&mut self) -> Result<Option<Frame>> {
    loop {
        // 尝试从缓冲区数据中解析出一个数据帧
        // 只有当数据足够被解析时，才返回对应的帧
        if let Some(frame) = self.parse_frame()? {
            return Ok(Some(frame));
        }
        
        // 如果缓冲区数据不足以被解析成一个数据帧，需要从socket中读取更多的数据
        // 读取成功时，会返回读取到的字节数，0代表着读到了数据流的末尾
        if 0 == self.stream.read_buf(&mut self.buffer).await? {
            // 对端关闭了连接
            if self.buffer.is_empty() {
                // 缓冲区没有数据，属于正常关闭
                return Ok(None);
            } else {
                // 缓冲区还有数据，说明对端在发送帧的过程中中断了连接，导致只发送了部分数据
                return Err("connection rest by peer".into());
            }
        }
    }
}
```



上面的 `read_frame` 方法中，使用了 `read_buf` 来读取 socket 中的数据，该方法的参数来自 `bytes` 包的 `BufMut`。

可以考虑使用 `read()` 和 `Vec<u8>` 来实现同样的功能：

```rust
use tokio::net::TcpStream;
use mini_redis::{Frame, Result};

pub struct Connection {
    stream: TcpStream,
    buffer: Vec<u8>,
    cursor: usize,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream,
            buffer: vec![0; 4096],
            cursor: 0,
        }
    }
    
    pub async fn read_frame(&mut self) -> Result<Option<Frame>> {
        loop {
            if let Some(frame) = self.parse_frame? {
                return Ok(Some(frame));
            }
            
            // 确保缓冲区长度足够
            if self.buffer.len() == self.cursor {
                // 不够则增加缓冲区长度
                self.buffer.resize(self.cursor * 2, 0);
            }
            
            // 从游标位置开始将数据读入缓冲区
            let n = self.stream.read(&mut self.buffer[self.cursor..]).await?;
            
            if n ==  0 {
                if self.cursor == 0 {
                    return Ok(None);
                } else {
                    return Err("connection reset by peer".into());
                }
            } else {
                // 更新游标位置
                self.cursor += n;
            }
        }
    }
}
```

核心技术：**通过游标 (cursor) 跟踪已经读取的数据，并将下次读取的数据写入到游标之后的缓冲区**，只有这样才不会让新读取的数将之前读取的数据覆盖掉。

在网络编程中，通过字节数组和游标的方式读取数据是非常普遍的，因此 `bytes` 包提供了一个 `Buf` 特征，如果一个类型可以被读取数据，那么该类型需要实现 `Buf` 特征。与之对应，当一个类型可以被写入数据时，它需要实现 `BufMut`.

当 `T: BufMut` 被传给 `read_buf()` 方法时，缓冲区 `T` 内部游标会自动更新，不需要管理游标。

与 `BytesMut` 和 `BufMut` 相比，`Vec<u8>` 在使用时必须要被初始化：`vec![0; 4096]`，该初始化会创建一个 4096 字节长度的数组，该数组的每个元素都填充上0。当缓冲区长度不足时，新创建的缓冲区数据依然会使用 0 被重新填充一遍，这种**初始化过程会存在一定的性能开销**。



## 7.2 帧解析

读取数据后，如何通过两个部分解析出一个帧：

- 确保一个完整的帧已经被写入了缓冲区，找到该帧的最后一个字节所在的位置
- 解析帧

```rust
use mini_redis::{Frame, Result};
use mini_redis::frame::Error::Incomplete;
use bytes::Buf;
use std::io::Cursor;

fn parse_frame(&mut self) -> Result<Option<Frame>> {
    // 创建 `T: Buf` 类型
    let mut buf = Cursor::new(&self.buffer[..]);
    
    // 检查是否读取了足够解析出一个帧的数据
    match Frame::check(&mut buf) {
        Ok(_) => {
            // 获取组成该帧的字节数
            let len = buf.position() as usize;
            
            // 解析开始之前，重置内部游标位置
            buf.set_position(0);
            
            // 解析帧
            let frame = Frame::parse(&mut buf)?;
            
            // 解析完成，将缓冲区该帧的数据移除
            self.buffer.advance(len);
            
            // 返回解析出的帧
            Ok(Some(frame))
        },
        Err(Incomplete) => Ok(None), // 缓冲区数据不足以解析出一个完整的帧
        Err(e) => Err(e.into()),     // 异常错误
    }

}
```



## 7.3 缓冲写入

为实现缓冲写，使用 `BufWriter` 结构体，它实现了 `AsyncWrite` 特征，当 `write` 方法被调用时，不会直接写入到 socket，而是先写入到缓冲区中。当缓冲区被填满时，会自动写入到 socket，并清空缓冲。

```rust
use tokio::io::{self, BufWriter, AsyncWriteExt};
use tokio::net::TcpStream;
use bytes::BytesMut;
use mini_redis::Frame;

pub struct Connection {
    stream: BufWriter<TcpStream>,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream: BufWriter::new(stream),
            buffer: BytesMut.with_capacity(4096),
        }
    }
    
    pub async fn writer_frame(&mut self, frame: &Frame) -> io::Result<()> {
        match frame {
            Frame::Simple(val) => {
                self.stream.write_u8(b'+').await?;
                self.stream.write_all(val.as_bytes()).await?;
                self.stteam.write_all(b"\r\n").await?;
            }
            Frame::Error(val) => {
                self.stream.write_u8(b'-').await?;
                self.stream.write_all(val.as_bytes()).await?;
                self.stteam.write_all(b"\r\n").await?;
            }
            Frame::Integer(val) => {
                self.stream.write_u8(b':').await?;
                self.stream.write_decimal(*val).await?;
            }
            Frame::Null => {
                self.stream.write_all(b"$-1\r\n").await?;
            }
            Frame::Bulk(val) => {
                let len = val.len();
                
                self.stream.write_u8(b'$').await?;
                self.stream.write_decimal(len as u64).await?;
                self.stream.write_all(val).await?;
                self.stteam.write_all(b"\r\n").await?;
            }
            Frame::Array(_val) => unimplemented!(),
        }
        
        self.stream.flush.await;
        
        Ok(())
    }
}
```



























































































