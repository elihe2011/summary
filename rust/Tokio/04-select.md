# 1. `select!`

## 1.1 `tokio::select!` 

允许同时等待多个计算操作，当其中一个操作完成时就退出

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async move {
        let _ = tx1.send(1);
    });

    tokio::spawn(async move {
        let _ = tx2.send(2);
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }

    println!("main done");
}
```



## 1.2 取消

对于 `Async Rust` 来说，释放 (drop) 掉一个 `Future` 就意味着取消任务。

`async` 操作会返回一个 `Future`，它是惰性的，直到被 `poll` 调用时，才会被执行。一旦它被释放，操作将无法继续，因为所有相关的状态都被释放。

对于 `Tokio` 的 `oneshot` 接收端来说，它在被释放时会发送一个关闭通知到发送端，因此发送端可以通过释放任务的方式来终止正在执行的任务。

```rust
use std::time::Duration;
use tokio::sync::oneshot;

async fn some_operation() -> String {
    tokio::time::sleep(Duration::from_millis(100)).await;
    "do something".into()
}

#[tokio::main]
async fn main() {
    let (mut tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async move {
        tokio::select! {
            val = some_operation() => {
                let _ = tx1.send(val);
            }
            
            // 当 close 被执行后，将退出当前select，
            // some_operation这个future也将再此被取消
            _ = tx1.closed() => {
                println!("close tx1");
            }
        }
    });

    tokio::spawn(async move {
        let _ = tx2.send(2);
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }

    println!("main done");
}
```



## 1.3 Future 的实现

简化版本的实现如下。但实际中，`select!` 会包含一些额外的功能，例如一开始会随机选择一个分支去 `poll`

```rust
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

    tokio::spawn(async move {
        let _ = tx1.send("one");
    });

    tokio::spawn(async move {
        let _ = tx2.send("two");
    });

    MySelect {
        rx1,
        rx2,
    }.await;
}
```

`MySelect` 包含了两个分支中的 `Future`，当它被 `poll` 时，第一个分支会先执行。如果执行完成，`MySelect` 随之结束，而另一个分支对应的 `Future` 会被释放掉，对应的操作也会被取消。

**当一个 `Future` 返回 `Poll::Pending` 时，必须确保会在某个时刻通过 `Waker` 来唤醒，否则该 `Future` 将永远地被挂起**

在 `select` 代码中，并没有任何 `wake` 调用。这是因为参数 `cx` 被传入了内层的 `poll` 调用。只要内部的 `Future` 实现了唤醒并且返回 `Poll::Pending`，那么 `MySelect` 也等于实现了唤醒。



# 2. 语法

`select!` 最多支持 64 个分支，每个分支形式如下：

```
<pattern> = <async expression> => <handler>
```



示例1：从分支中进行 TCP 连接：

```rust
use tokio::net::TcpStream;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();
    
    // 生成一个任务，向通道发送一条消息
    tokio::spawn(async move {
        tx.send("done").unwrap();
    });
    
    tokio::select! {
        socket = TcpStream::connect("localhost:3456") => {
            println!("Socket connected {:?}", socket);
        }
        msg = rx => {
            println!("Received message {:?}", msg);
        }
    }
}
```



示例2：在分支中进行 TCP 监听

```rust
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use std::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();
    
    tokio::spawn(async move {
        tx.send(()).unwrap();
    });
    
    let mut listener = TcpListener::bind("localhost:3456").await?;
    
    tokio::select! {
        _ = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket) });
            }
            
            // 给予 Rust 类型暗示
            Ok::<_, io::Error>(())
        } => {}
        _ = rx => {
            println!("terminating accept loop");
        }
    }
    
    Ok(())
}
```



# 3. 返回值

```rust
async fn computation1() -> String {
    // --snip--
    "one"
}

async fn computation2() -> String {
    // --snip--
    "two"
}

#[tokio::main]
async fn main() {
    // 所有分支必须返回同样的类型
    let out = tokio::select!{
        res1 = computation1() => res1,
        res2 = computation2() => res2,
    };
    
    println!("Got = {}", out);
}
```



# 4. 错误传播

在 Rust 中，使用 `?` 可以对错误进行传播，但在 `select!` 中，`?` 如何工作，取决于它是在分支中的 `async` 表达式还是结果处理代码上：

- 在分支中 `async` 表达式，会将该表达式的结果变成一个 `Result`
- 在结果处理代码中，会将错误直接传播到 `select!` 之外

```rust
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use std::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();
    
    tokio::spawn(async move {
        tx.send(()).unwrap();
    });
    
    let mut listener = TcpListener::bind("localhost:3456").await?;
    
    tokio::select! {
        res = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket) });
            }
            
            // 给予 Rust 类型暗示
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

`listener.accept().await?` 是分支表达式中的 `?`，因此它会将表达式的返回值变成 `Result` 类型，然后赋给 `res` 变量。

结果处理中的 `res?`，会让 `main` 函数直接结束并返回一个 `Result`



# 5. 模式匹配

任何 Rust 模式，都可以用到 `select!` 模式匹配中

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (mut tx1, mut rx1) = mpsc::channel(128);
    let (mut tx2, mut rx2) = mpsc::channel(128);
    
    tokio::spawn(async move {
        // tx1 & tx2 do something
    });
    
    tokio::select! {
        Some(v) = rx1.recv() => {
            println!("Got {:?} from rx1", v);
        }
        Some(v) = rx2.recv() => {
            println!("Got {:?} from rx2", v);
        }
        // 当rx被关闭时，recv()返回None，之前的分支无法匹配，else分支将被执行
        else => {
            println!("Both channels closed");
        }
    }
}
```



# 6. 借用

在 `Tokio` 生成 (spawn) 任务时，其 `async` 语句块必须拥有其中数据的所有权。而 `select!` 并没有这个限制，它的每个分支表达式可以直接借用数据，然后进行并发操作。只要遵循 Rust 的借用规则，多个分支表达式可以不可变的借用同一个数据，或者在一个表达式可变的借用某个数据。

示例：同时向两个 TCP 目标发送相同的数据

```rust
use tokio::io::AsyncWriteExt;
use tokio::net::TcpStream;
use std::io;
use std::net::SocketAddr;

async fn race(
	data: &[u8],
    addr1: SocketAddr,
    addr2: SocketAddr,
) -> io::Result<()> {
    tokio::select! {
        Ok(_) = async {
            let mut socket = TcpStream::connect(addr1).await?;
            socket.write_all(data).await?
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



注意：**借用规则在分支表达式和结果处理中存在很大的不同**。

- 在两个分支**表达式中分别对 `data` 进行不可变借用，当然没问题，但若是可变借用，编译器将报错**。

- 在两个分支**结果处理中分别进行可变借用，并不会报错**，原因在于：`select!` 会保证只有一个分支的结果处理被执行，该分支结束后，另一个分支直接丢弃

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();
    
    let mut out = String::new();
    
    tokio::spawn(async move {
        
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



# 7. 循环

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx1, mut rx1) = mpsc::channel(128);
    let (tx2, mut rx2) = mpsc::channel(128);
    let (tx3, mut rx4) = mpsc::channel(128);
    
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



## 7.1 恢复异步操作

```rust
async fn action() {
    // --snip--
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

`&mut operation` 如果不加 `&mut`，每一次循环调用都是一次全新的 `action()` 调用。但加了 `&mut` 后，每次循环调用就变成了对同一次 `action()` 的调用。

`tokio::pin!`：如果要在一个引用上使用 `.await`，那么引用的值就必须是不能移动的或实现了 `Unpin`。一旦移除 `tokio::pin!`，将出现编译错误：

```
error[E0599]: no method named `poll` found for struct
     `std::pin::Pin<&mut &mut impl std::future::Future>`
     in the current scope
  --> src/main.rs:16:9
   |
16 | /         tokio::select! {
17 | |             _ = &mut operation => break,
18 | |             Some(v) = rx.recv() => {
19 | |                 if v % 2 == 0 {
...  |
22 | |             }
23 | |         }
   | |_________^ method not found in
   |             `std::pin::Pin<&mut &mut impl std::future::Future>`
   |
   = note: the method `poll` exists but the following trait bounds
            were not satisfied:
           `impl std::future::Future: std::marker::Unpin`
           which is required by
           `&mut impl std::future::Future: std::future::Future`
```

注意：**在一个引用上调用 `.await` 后遇到 `Future` 未实现错误，往往只需要将对应的 `Future` 进行固定即可 `tokio::pin!(operation)`**



## 7.2 更复杂的操作

```rust
async fn action(input: Option<i32>) -> Option<String> {
    let i = match input {
        Some(input) => input,
        None => return None,
    }
    
    // --snip--
}

#[tokio::main]
async fn main() {
    let (mut tx, mut rx) = tokio::sync::mpsc::channel(128);
    let mut done = false;
    let operation = action(None);
    tokio::pin!(operation);
    
    tokio::spawn(async move {
        let _ = tx.send(1).await;
        let _ = tx.send(3).await;
        let _ = tx.send(2).await;
    });
    
    loop {
        tokio::select! {
            // if !done 预条件(precondition)，该条件会在分支被 .await 执行前进行检查
            res = &mut operation, if !done => {
                done = true;
                
                if let Some(v) = res {
                    println!("GOT = {}", v);
                    return;
                }
            }
            Some(v) = rx.recv() => {
                if v % 2 == 0 {
                    // `.set` 是 `Pin` 上定义的方法
                    operation.set(action(Some(v)));
                    done = false;
                }
            }
        }
    }
}
```





























































