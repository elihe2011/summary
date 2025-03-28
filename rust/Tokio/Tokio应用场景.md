# 1. 基础场景

## 1.1 简单异步延迟任务

实现一个简单的定时任务，模拟延迟执行。

```rust
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    println!("Starting...");
    sleep(Duration::from_secs(5)).await;
    println!("Task completed after 5 seconds.");
}
```



## 1.2 并发任务调度

启动多个并发任务，模拟并行处理。

```rust
use tokio::task;

#[tokio::main]
async fn main() {
    let mut handles = Vec::new();
    for i in 0..5 {
        let handle = task::spawn(async move {
            println!("Task {} started", i);
            tokio::time::sleep(Duration::from_secs(1)).await;
            println!("Task {} completed", i);
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.await.unwrap();
    }

    println!("All tasks finished.");
}
```



## 1.3 异步文件读写

实现一个异步文件读写程序。使用 `BufWriter` 和 `BufReader` 优化 `I/O` 性能，异步操作避免阻塞。

```rust
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt, BufReader, BufWriter};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 写入文件
    let file = File::create("log.txt").await?;
    let mut writer = BufWriter::new(file);
    writer.write_all(b"Log entry 1\nLog entry 2").await?;
    writer.flush().await?;

    // 读取文件
    let file = File::open("log.txt").await?;
    let mut reader = BufReader::new(file);
    let mut contents = String::new();
    reader.read_to_string(&mut contents).await?;
    println!("File contents:\n{}", contents);

    Ok(())
}
```



## 1.4 TCP 回显服务器

构建一个TCP回显服务器，接收客户端消息并返回。

```rust
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
   let listener = TcpListener::bind("127.0.0.1:8080").await?;
    println!("Server running on 127.0.0.1:8080");

    loop {
        let (mut socket, addr) = listener.accept().await?;
        tokio::spawn(async move {
           let mut buf = [0; 1024];
            match socket.read(&mut buf).await {
                Ok(n) if n > 0 => {
                    println!("Received from {}: {}", addr, String::from_utf8_lossy(&buf[..n]));
                    socket.write_all(&buf[..n]).await.unwrap();
                },
                _ => println!("Connection closed by {}", addr),
            }
        });
    }
}
```



## 1.5 带信号处理的服务器

扩展 TCP 服务器，添加信号处理以实现优雅关闭。

```rust
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::signal;
use tokio::sync::Notify;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
   let listener = TcpListener::bind("127.0.0.1:8080").await?;
    println!("Server running on 127.0.0.1:8080");

    let shutdown = Arc::new(Notify::new());
    let shutdown_clone = Arc::clone(&shutdown);

    tokio::spawn(async move {
        loop {
            tokio::select! {
                result = listener.accept() => {
                    if let Ok((mut socket, addr)) = result {
                        println!("New connection: {}", addr);
                        let mut buf = [0; 1024];
                        socket.read(&mut buf).await.unwrap();
                        println!("Received: {}", String::from_utf8_lossy(&buf));
                        socket.write_all(&buf).await.unwrap();
                    }
                }
                _ = shutdown_clone.notified() => {
                    println!("Shutting down server...");
                    break;
                }
            }
        }
    });

    signal::ctrl_c().await?;
    println!("Ctrl+C received, initiating shutdown...");
    shutdown.notify_one();

    Ok(())
}
```



## 1.6 配置文件更新监控

监控配置文件变化并广播更新。使用 watch 广播配置变化，异步文件读取监控更新。

```rust
use tokio::fs;
use tokio::time::Duration;
use tokio::sync::watch;
use tokio::time::sleep;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
struct Config {
    port: u16,
    debug: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let initial_config = Config { port: 8080, debug: false };
    let (tx, mut rx) = watch::channel(initial_config.clone());
    fs::write("config.json", serde_json::to_string_pretty(&initial_config)?).await?;

    tokio::spawn(async move {
        loop {
            sleep(Duration::from_secs(1)).await;
            if let Ok(contents) = fs::read_to_string("config.json").await {
                if let Ok(new_config) = serde_json::from_str(&contents) {
                    if *tx.borrow() != new_config {
                        tx.send(new_config).unwrap();
                        println!("Config updated!");
                    }
                }
            }
        }
    });

    while rx.changed().await.is_ok() {
        let config = rx.borrow();
        println!("New config - Port: {}, Debug: {}", config.port, config.debug);
    }

    Ok(())
}
```



## 1.7 异步进程管理与输出处理

运行外部命令并实时处理输出，展示进程管理的复杂应用。

```rust
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut child = Command::new("ping")
        .arg("127.0.0.1")
        .arg("-l")
        .arg("5")
        .stdout(std::process::Stdio::piped())
        .spawn()?;

    let stdout = child.stdout.take().unwrap();
    let mut reader = BufReader::new(stdout).lines();

    while let Some(line) = reader.next_line().await? {
        println!("Ping output: {}", line);
    }

    let status = child.wait().await?;
    println!("Ping exited with: {}", status);
    Ok(())
}
```



## 1.8 实时数据流处理

处理 UDP 数据流并进行转换，展示流处理能力。

```rust
use tokio::net::UdpSocket;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let socket = UdpSocket::bind("127.0.0.1:8080").await?;
    println!("UDP server on: {}", socket.local_addr()?);

    let mut buf = vec![0; 1024];

    loop {
        let (len, addr) = socket.recv_from(&mut buf).await?;
        let received = String::from_utf8_lossy(&buf[0..len]).to_string();

        if received.contains("hello") {
            println!("Received UDP data from {}: {}", addr, received);
        }
    }
}
```





# 2. `tokio::process::Command`

## 2.1 实时流处理与日志解析

运行一个长时间执行的进程 (如 `tail -f`)，实时读取输出并解析日志。

```rust
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::time::Instant;

async fn tail() -> anyhow::Result<()> {
    let mut child = Command::new("tail")
        .args(["-f", "/var/log/syslog"])
        .stdout(std::process::Stdio::piped())
        .spawn()?;

    let stdout = child.stdout.take().unwrap();
    let mut lines = BufReader::new(stdout).lines();
    let start = Instant::now();

    while let Some(line) = lines.next_line().await? {
        if line.contains("error") {
            println!("[{:?}] ERROR detected: {}", start.elapsed(), line);
        }
    }

    Ok(())
}
```

分析：

- 模块：`tokio::process`、`tokio::io`
- 关键点：
  - `Stdio::piped()` 启动流式输出
  - `lines()` 逐行读取，异步处理实时日志
  - `Instant::now()` 获取当前时间

- 适用场景：日志监控、实时数据分析



## 2.2 动态输入和进程交互

运行一个交互式进程 （如 `bc` 计算器），动态发送输入并读取结果

```rust
use std::process::Stdio;
use tokio::time::{sleep, Duration};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::Command;

async fn bc() -> anyhow::Result<()> {
    let mut child = Command::new("bc")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()?;

    let mut stdin = child.stdin.take().unwrap();
    let mut stdout = child.stdout.take().unwrap();

    // 发送计算表达式
    stdin.write_all(b"2 + 3\n").await?;
    sleep(Duration::from_millis(100)).await;

    let mut buf = [0; 1024];
    let n = stdout.read(&mut buf).await?;
    println!("Result: {}", String::from_utf8_lossy(&buf[..n]));

    // 关闭 stdin 并等待进程退出
    drop(stdin);
    let status = child.wait().await?;
    println!("Process exited with: {}", status);

    Ok(())
}
```

分析：

- 模块：`tokio::process`, `tokio::io`, `tokio::time`
- 关键点：
  - 双向管道 (`stdin` 和 `stdout`) 实现交互
  - `drop(stdin)` 关闭输入流，触发进程结束
- 适用场景：交互式工具、脚本驱动



## 2.3 多进程并发执行

同时运行多个进程（如批量测试命令），并收集结果

```rust
use tokio::process::Command;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::task;

async fn multi_proc() -> anyhow::Result<()> {
    let commands = vec![
        vec!["echo", "Task 1"] ,
        vec!["sleep", "2"],
        vec!["echo", "Task 3"],
    ];

    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles: Vec<task::JoinHandle<Result<(), std::io::Error>>> = Vec::new();

    for cmd in commands {
        let results = Arc::clone(&results);
        let mut command = Command::new(cmd[0]);
        command.args(&cmd[1..]);

        handles.push(task::spawn(async move {
            let output = command.output().await?;
            let mut results = results.lock().await;
            results.push(String::from_utf8_lossy(&output.stdout).to_string());
            Ok(())
        }));
    }

    for handle in handles {
        handle.await??;
    }

    let results = results.lock().await;
    println!("All results: {:?}", *results);

    Ok(())
}
```

分析：

- 模块：`tokio::process`, `tokio::task`, `tokio::sync`

- 关键点：
  - `spawn` 并行执行多个命令
  - `Mutex` 收集结果，现场安全
- 适用场景：批量任务处理、并行测试



## 2.4 超时控制与强制终止

运行可能挂起的进程，设置超时并在必要时终止。

```rust
use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

async fn term_proc() -> anyhow::Result<()> {
    let mut child = Command::new("sleep").arg("5").spawn()?;

    let result = timeout(Duration::from_secs(2), child.wait()).await;

    match result {
        Ok(status) => println!("Process completed: {}", status?),
        Err(_) => {
            println!("Process timed out, killing...");
            child.kill().await?;
            println!("Process killed");
        }
    }

    Ok(())
}
```

分析：

- 模块：`tokio::process`, `tokio::time`

- 关键点：
  - `timeout` 设置超时时间
  - `kill().await` 强制终止进程
- 适用场景：任务超时管理、服务健康检查



## 2.4 Nginx 高级管理

构建一个异步 Nginx 管理工具，支持启动、停止、重载配置，并实时监控日志

```rust
use std::process::Stdio;
use std::sync::Arc;
use tokio::sync::watch;
use tokio::time::{sleep, Duration};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::{ Mutex};
use tokio::process::Command;

pub async fn nginx() -> anyhow::Result<()> {
    let nginx_path = "/usr/sbin/nginx";
    let (tx, mut rx) = watch::channel("running");

    // 启动 Nginx
    let mut child = Command::new(nginx_path).spawn()?;
    println!("Nginx started with PID: {:?}", child.id());

    let child = Arc::new(Mutex::new(child));

    // 日志监控
    tokio::spawn({
        let child = Arc::clone(&child);
        async move {
            let mut log_child = Command::new("tail")
                .args(["-f", "/var/log/nginx/access.log"])
                .stdout(Stdio::piped())
                .spawn()?;

            let mut lines = BufReader::new(log_child.stdout.take().unwrap()).lines();
            while let Some(line) = lines.next_line().await? {
                println!("Nginx log: {}", line);
            }

            Ok::<(), anyhow::Error>(())
        }
    });

    // 配置重载
    tokio::spawn(async move{
        while rx.changed().await.is_ok() {
            let state = *rx.borrow();
            if state == "reload" {
                Command::new(nginx_path)
                    .args(["-s", "reload"])
                    .status()
                    .await?;
                println!("Nginx configuration reloaded")
            }
        }

        Ok::<(), anyhow::Error>(())
    });

    // 主循环：模拟操作
    sleep(Duration::from_secs(2)).await;
    tx.send("reload")?;  // 触发重载
    sleep(Duration::from_secs(2)).await;

    // 停止 Nginx
    Command::new(nginx_path)
        .args(["-s", "stop"])
        .output()
        .await?;
    child.lock().await.kill().await?;
    println!("Nginx stopped");

    Ok(())
}
```

分析：

- 模块：`tokio::process`, `tokio::io`, `tokio::sync`, `tokio::time`
- 关键点：
  - `watch` 通道协调配置重载
  - 异步文件监控与主进程并行
  - 优雅停止结合信号控制
- 适用场景：Nginx服务管理、自动化运维



# 3. `tokio::time`

## 3.1 异步延迟

在异步任务中使用 sleep 延迟，类似线程的 sleep，但不会阻塞运行时

```rust
use std::time::Duration;
use tokio::time::sleep;

async fn sleep_demo() {
    println!("Starting...");
    sleep(Duration::from_secs(5)).await;
    println!("Done!");
}
```

关键点：

- 返回一个 `Future`，通过 `.await` 暂停执行
- 时间精度依赖底层运行时的事件循环



## 3.2 定时器

通过 `interval` 创建定时器，按固定间隔触发事件，执行周期性任务

```rust
use std::time::Duration;
use tokio::time::interval;

async fn interval_demo() {
    let mut timer = interval(Duration::from_secs(1));
    for i in 0..3 {
        timer.tick().await;  // 等待下一次触发
        println!("Tick {}", i+1);
    }
}
```

关键点：

- `tick()`立即返回，后续间隔触发
- 通过 `mut` 修饰定时器行为



跳过错过的触发：

```rust
use tokio::time::{interval, Duration, MissedTickBehavior};

async fn skip_missed_tick() {
    let mut timer = interval(Duration::from_millis(500));

    // 跳过错过的触发
    timer.set_missed_tick_behavior(MissedTickBehavior::Skip);

    // 模拟延迟
    sleep(Duration::from_secs(2)).await;

    for i in 0..3 {
        timer.tick().await;
        println!("Tick {}", i+1);
    }
}
```

关键点：

- `MissedTickBehavior`
  - `Burst` 立即触发所有错过
  - `Skip` 跳过
  - `Delay` 从现在重新计时



## 3.3 超时控制

timeout 为异步操作设置超时，若超时则返回错误

```rust
use std::io;
use tokio::time::{sleep, timeout, Duration};

async fn timeout_demo() {
    let operation = async {
        sleep(Duration::from_secs(3)).await;
        Ok::<&str, io::Error>("Done")
    };

    match timeout(Duration::from_secs(2), operation).await {
        Ok(result) => println!("Result: {:?}", result),
        Err(_) => println!("Operation timed out!"),
    }
}
```

关键点：

- 返回`Result`，超时则为 `Err(tokio::time::error::Elapsed)`
- 常用于网络请求或任务限制



网络连接超时：

```rust
use tokio::net::TcpStream;
use tokio::time::{timeout, Duration};
use std::io;

async fn timeout_tcp_connection() {
    let conn = TcpStream::connect("127.0.0.1:8080");
    match timeout(Duration::from_secs(3), conn).await {
        Ok(Ok(stream)) => println!("Connected: {:?}", stream),
        Ok(Err(e)) => println!("Connection failed: {}", e),
        Err(_) => println!("Connection timed out!"),
    }
}
```



## 3.4 自定义时间轮询

`sleep_until` 指定触发时间

```rust
use tokio::time::{Instant, sleep_until};

async fn sleep_until_demo() {
    let now = Instant::now();
    let deadline = now + Duration::from_secs(3);
    sleep_until(deadline).await;
    println!("Slept until {:?}", Instant::now() - now);
}
```



# 4. `tokio::task`

## 4.1 创建异步任务

`spawn` 子啊运行时中创建并允许一个独立的任务，类似线程，但更轻量。

```rust
use tokio::task;

async fn spawn_demo() {
    let handle = task::spawn(async {
        println!("Task running!");
        42
    });

    let result = handle.await.unwrap();
    println!("Task result: {}", result);
}
```

关键点：

- 返回`JoinHandle`，可通过 `.await` 获取结果
- 任务并发执行，不阻塞主线程



## 4.2 运行阻塞任务

`spawn_blocking` 将阻塞操作 (如 CPU 密集型计算)，移到专用线程池，避免阻塞事件循环

```rust
use tokio::task;

async fn spawn_blocking_demo() {
    let handle = task::spawn_blocking(|| {
        let sum: i64 = (0..1_000_000).sum(); // CPU 密集型任务
        sum
    });

    let result = handle.await.unwrap();
    println!("Sum: {}", result);
}
```

关键点：

- 返回`JoinHandle`，可通过 `.await` 获取结果
- 适合 `I/O` 以外的阻塞操作



## 4.3 任务并发与错误处理

```rust
use std::sync::Arc;
use tokio::task;

async fn handle_error() {
    let data = Arc::new(0);
    let mut handles = vec![];

    for i in 0..3 {
        let data = Arc::clone(&data);
        handles.push(task::spawn(async move {
            println!("Task {} started with data {}", i, *data);
            if i == 2 {
                panic!("Task {} failed!", i);
            }
            i
        }));
    }

    for handle in handles {
        match handle.await {
            Ok(result) => println!("Task result: {}", result),
            Err(e) => println!("Task failed: {}", e),
        }
    }
}
```

关键点：

- `JoinHandle.await` 返回 `Result`，可捕获 `panic` 
- 使用 `Arc` 共享数据



## 4.4 任务让出控制

`yield_now` 让当前任务暂停，允许其它任务运行

```rust
use tokio::task;

async fn yield_now() {
    task::spawn(async {
        for i in 0..5 {
            println!("Sub Task: {}", i);
            task::yield_now().await; // 让出控制权
        }
    });

    for i in 0..5 {
        println!("Main Task: {}", i);
        task::yield_now().await;
    }
}
```

关键点：

- 提高任务调度的公平性



## 4.5 本地任务管理

`LocalSet` 用于运行不支持 `Send` 的任务（仅单线程运行时）

```rust
use std::rc::Rc;
use tokio::task::LocalSet;

async fn local_set() {
    let local = LocalSet::new();
    let data = Rc::new(21); // Rc 不支持跨线程

    local.spawn_local(async move {
        println!("Local task with Rc: {}", data);
    });

    local.await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test(flavor = "current_thread")]
    async fn test_local_set() {
        local_set().await;
    }
}
```

关键点：

- 需要 `current_thread` 运行时
- 通过 `spawn_local` 执行而非 `Send` 任务



## 4.6 定时任务调度器

```rust
use tokio::task;
use tokio::time::{interval, sleep, Duration};

async fn scheduler() {
    let mut timer = interval(Duration::from_secs(1));
    let mut counter = 0;

    loop {
        timer.tick().await;
        counter += 1;

        task::spawn(async move {
            println!("Scheduled task #{} running", counter);
            sleep(Duration::from_millis(500)).await;
            println!("Task {} completed", counter);
        });

        if counter >= 10 {
            break;
        }
    }
}
```



# 5. `task::fs`

`task::fs` 是 `std::fs` 的异步版本，所有函数都返回可以 `.await` 的 `Future`，确保不会阻塞运行时的事件循环。

主要功能：

- 文件操作：`read`、`write`、`open` 等
- 目录管理：`create_dir`、`remove_dir` 等
- 元数据查询：`metadata`、`canonicalize` 等
- 流式操作：通过 `File` 类型支持异步读写



## 5.1 基本文件操作

读取和写入文件.

```rust
use tokio::fs;

async fn read_write() -> anyhow::Result<()> {
    // 写入文件
    fs::write("example.txt", "Hello, Tokio!").await?;
    println!("File written");

    // 读取文件
    let contents = fs::read("example.txt").await?;
    println!("File contents: {}", String::from_utf8_lossy(&contents));

    // 删除文件
    fs::remove_file("example.txt").await?;
    println!("File removed");

    Ok(())
}
```

关键点：

- `write` 和 `read` 是 `std::fs::write` 和 `std::fs::read` 的异步版本
- 返回 `io::Result`，需处理潜在错误



## 5.2 File 类型

`tokio::fs::File` 是异步文件句柄，支持更细粒度的操作，如流式读写。

```rust
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

async fn file_demo() -> anyhow::Result<()> {
    // 写文件
    let mut file = File::create("test.txt").await?;
    file.write_all(b"Hello from File!").await?;
    file.flush().await?;
    drop(file);  // 关闭文件

    // 读文件
    let mut file = File::open("test.txt").await?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf).await?;
    println!("Read: {}", String::from_utf8_lossy(&buf));

    Ok(())
}
```

关键点：

- `File::create` 和 `File::open` 返回异步文件句柄
- `AsyncWriteExt` 和 `AsyncReadExt` 提供流式操作方法



## 5.3 目录管理

异步创建、删除和遍历目录。

```rust
use tokio::fs;

async fn dir_demo() -> anyhow::Result<()> {
    // 创建目录
    fs::create_dir("my_dir").await?;
    println!("Directory created.");

    // 创建子目录 (mkdir -p)
    fs::create_dir_all("my_dir/sub_dir").await?;
    println!("Nested directory created.");

    // 写入文件到目录
    fs::write("my_dir/sub_dir/file.txt", "Nested file").await?;

    // 删除目录及其内容
    fs::remove_dir_all("my_dir").await?;
    println!("Directory removed.");

    Ok(())
}
```

关键点：

- `create_dir_all` 递归创建目录
- `remove_dir_all` 递归删除目录（支持删除非空目录）



## 5.4 文件元数据

`tokio::fs::metadata` 和相关函数用于查询文件或目录的信息

```rust
use tokio::fs;

async fn metadata_demo() -> anyhow::Result<()> {
    fs::write("meta.txt", "Test").await?;

    let metadata = fs::metadata("meta.txt").await?;
    println!("File size: {}", metadata.len());
    println!("Is file: {}", metadata.is_file());

    let path = fs::canonicalize("meta.txt").await?;
    println!("Absolute path: {}", path.to_string_lossy());

    fs::remove_file("meta.txt").await?;

    Ok(())
}
```

关键点：

- `metadata` 返回 `Metadata` 结构体，包含大小、类型等信息
- `canonicalize` 返回文件的绝对路径



## 5.5 流式读写与缓冲

使用 `tokio::io::BufReader` 和 `BufWriter` 优化大文件操作

```rust
use tokio::fs::{self, File};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader, BufWriter};

async fn buffer() -> anyhow::Result<()> {
    // 写入大文件
    let file = File::create("large.txt").await?;
    let mut writer = BufWriter::new(file);
    for i in 0..10000 {
        writer.write_all(format!("Line {}\n", i).as_bytes()).await?;
    }
    writer.flush().await?;

    // 逐行读取
    let file = File::open("large.txt").await?;
    let reader = BufReader::new(file);
    let mut lines = reader.lines();
    while let Some(line) = lines.next_line().await? {
        println!("Read: {}", line);
    }

    fs::remove_file("large.txt").await?;
    Ok(())
}
```

关键点：

- `BufReader` 和 `BufWriter` 减少直接 `I/O` 调用，提高效率
- `lines()` 返回异步行迭代器



## 5.6 文件监视与动态加载

结合 `tokio::time`，实现简单的文件变化监控

```rust
use std::time::Duration;
use tokio::fs;
use tokio::time::{sleep, Instant};

async fn file_watch() -> anyhow::Result<()> {
    let file_path = "watch.txt";
    fs::write(file_path, "Initial content").await?;

    println!("Wrote file {}", file_path);
    let mut last_modified = fs::metadata(file_path).await?.modified()?;

    let deadline = Instant::now() + Duration::from_secs(10);

    loop {
        sleep(Duration::from_secs(2)).await;
        let current_modified = fs::metadata(file_path).await?.modified()?;

        if current_modified != last_modified {
            let contents = fs::read_to_string(file_path).await?;
            println!("File changed! New content: {}", contents);
            last_modified = current_modified;
        }

        if deadline < Instant::now() {
            break;
        }
    }

    Ok(())
}
```

关键点：

- 通过 `modified()` 检查文件修改时间
- 轮询方式简单，可结合 `notify` crate 优化
- `deadline` 为了测试能尽快退出























 













