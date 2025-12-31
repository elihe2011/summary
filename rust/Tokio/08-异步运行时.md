# 1. 原理剖析

## 1.1 核心架构

Tokio Runtime 是一个事件驱动的异步执行器，由两部分构成：

- **Reactor**：基于 Mio (跨平台事件通知，如 epoll on Linux, kqueue on MacOS, IOCP on Windows) 处理 IO 事件。当 IO 就绪时，通过 Waker 唤醒相关任务。
- **Executor**：调度异步任务 (Future)。多线程模式下，使用工作窃取 (work-stealing) 算法。每个线程有本地队列，空闲时从全局队列或其它线程窃取任务，减少锁竞争。

Runtime 运行一个循环，poll 任务直到 Pending，然后处理 IO 事件或定时器。这避免了线程阻塞，实现“廉价”并发（数万任务仅需少量线程）。在高并发下，Runtime 的效率取决于线程配置：过多导致上下文切换开销，过少导致任务饥饿。



## 1.2 单线程和多线程

- Current-Thread (`new_current_thread()`)：所有任务在当前线程执行，适合地并发、无需跨线程的场景 (如 CLI 工具等)。无工作窃取，开销小，但 IO 阻塞会卡住整个 Runtime。
- Multi-Thread (`new_multi_thread()`)：默认模式，适合高并发 IO。工作窃取确保负载均衡，线程池动态调整。在 IO-bound 应用中，多线程胜出，因为它允许并行 poll 多个任务。



## 1.3 阻塞任务处理

阻塞操作 (如文件IO) 通过 `spawn_blocking` 移到专用线程池 (默认 512 线程)。避免阻塞主 Reactor。在高 IO 场景，增大线程池，防止队列积压。



# 2. 配置详解

Tokio Runtime 通过 Builder 配置，提供细粒度控制，核心方法如下：



## 2.1 `worker_threads(val: usize)`

- **原理**：设置工作线程数，这些线程始终活跃，用于执行异步任务。默认：CPU核数 或 环境变量 `TOKIO_WORKER_THREADS`，值必须大于 0
- **影响**：过多的线程增加调度开销 (上下文切换 1-10us)；过小导致任务等待。针对 IO-bound，设为 CPU 核 * 2-4

- 示例代码

```rust
use tokio::runtime::Builder;

let rt = Builder::new_multi_thread()
	.worker_threads(16)   // 高并发优化
	.build()
	.unwrap();
```



## 2.2 `enable_all()`

- **原理**：启用所有驱动 (IO、时间、同步原语)。默认禁用，必须显示启用，等价于 `enable_io() + enable_time()`
- **影响**：未启用会导致如 TcpStream 或 sleep 失败。在生成中，启用以支持完整功能，但若无需定时器，可单独启用 `enable_io()` 减少开销

- 示例代码

```rust
let rt = Builder::new_multi_thread()
	.enable_all()
	.build()
	.unwrap();
```



## 2.3 `max_blocking_threads(val: usize)`

- **原理**：设置阻塞线程池上限（默认512）。这些线程按需创建，空闲 10s 后退出 （通过 thread_keep_alive 调整）
- **影响**：高并发文件 IO 需大池防饥饿。队列无界，可能导致内存耗尽。

- 示例代码

```rust
let rt = Builder::new_multi_thread()
	.max_blocking_threads(1024)   // 优化阻塞 IO
	.build()
	.unwrap();
```



## 2.4 其它方法

- `thread_stack_size(val: usize)`：设置栈大小 (默认 2MiB)，大栈支持深递归，小栈省内存。优化 IO-bound 设小 (如32KiB)
- `on_thread_start/fn`：线程启动/停止钩子，注入监控代码。集成 tracing 追踪线程寿命。
- `thread_keep_alive(dur: Duration)`：阻塞线程空闲超时 (默认 10s)，IO 峰值设长 (如60s)。



## 2.5 方法总结

| 参数名称              | 默认值     | 推荐值（高并发场景）      | 说明                                                         |
| :-------------------- | :--------- | :------------------------ | :----------------------------------------------------------- |
| worker_threads        | CPU 核数   | 16（CPU 核 * 2-4）        | 多线程调度器的工作线程数。默认适应硬件，推荐增大以提升并行。 |
| max_blocking_threads  | 512        | 1024+                     | 阻塞任务线程池上限。默认保守，推荐增大防 IO 饥饿。           |
| thread_stack_size     | 2 MiB      | 1 MiB 或更小（如 32 KiB） | 线程栈大小。默认安全，推荐缩小省内存，但防栈溢出。           |
| thread_keep_alive     | 10 秒      | 60 秒（峰值负载）         | 阻塞线程空闲超时。默认快速回收，推荐延长以应对波动。         |
| global_queue_interval | 31         | 15-61（调低公平性）       | 窃取全局队列间隔。默认平衡，推荐调低提升低延迟场景。         |
| enable_all()          | 未启用     | 启用                      | 启用所有驱动（如 IO、时间）。默认禁用防误用，推荐启用完整功能。 |
| thread_name           | 无         | "app-worker"              | 线程命名。默认匿名，推荐自定义便于调试。                     |
| rng_seed              | 无（随机） | 42（固定）                | 随机种子。默认随机，推荐固定确保测试确定性。                 |





# 3. 优化技巧

## 3.1 线程模型调优

- **IO-bound**：`worker_threads` = CPU 核 * 2，使用工作窃取减少延迟
- **CPU-bound**：`worker_threads` = CPU 核，避免争用
- **测试**：用 criterion 基准，监控 `tokio::metrics` (需启用 rt feature)



## 3.2 阻塞池

- 增大 `max_blocking_threads` 至 1024+，防止文件 IO 饥饿
- 自定义池：`Builder::new_multi_threads().gloabl_queue_interval(64)` 调整窃取间隔，优化低延迟



## 3.3 监控和钩子

- 通过`on_thread_start` 添加 Prometheus 指标：`metrics::counter!("threads_started").inc()`
- 集成 `tracing`：`tracing_subscriber::fmt().init()`，追踪 poll 事件



## 3.4 种子运行时与确定性

- 测试，用 `RngSeed` 种子运行时，确保调度确定性
- `Builder::new_multi_thread().rng_seed(36)`



## 3.5 与 `io_uring` 集成

- 对于 Linux 高 IOPS，结合 Monoio 作为 fallback：条件编译 `io_uring` feature，桥接 Tokio



# 4. 实站示例

## 4.1 高并发服务器

```rust
use tokio::runtime::Builder;
use tokio::net::TcpListener;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tracing::info_span;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化 tracing 以监控
    tracing_subscriber::fmt().init();

    // 推荐配置：高并发服务器
    let rt = Builder::new_multi_thread()
        .worker_threads(16)  // 优势：并行处理连接，解决任务饥饿
        .max_blocking_threads(1024)  // 优势：高 IO 防阻塞池饱和
        .thread_stack_size(1 * 1024 * 1024)  // 优势：省内存
        .thread_keep_alive(std::time::Duration::from_secs(60))  // 优势：峰值稳定
        .global_queue_interval(15)  // 优势：提升公平性，减延迟
        .enable_all()  // 优势：完整功能支持
        .rng_seed(42)  // 优势：确定性调度
        .thread_name("high-conc-server")
        .on_thread_start(|| tracing::info!("Thread started"))
        .build()?;

    rt.block_on(async {
        let listener = TcpListener::bind("0.0.0.0:8080").await?;
        loop {
            let (mut socket, _) = listener.accept().await?;
            tokio::spawn(asyncmove {
                let span = info_span!("handle_conn");
                let _enter = span.enter();
                letmut buf = [0; 1024];
                loop {
                    let n = socket.read(&mut buf).await.unwrap_or(0);
                    if n == 0 { break; }
                    socket.write_all(&buf[..n]).await.ok();
                }
            });
        }
    })
}
```

此配置针对 IO-bound 服务器，worker_threads=16 提升并行，阻塞池 1024 解决高 IO 挂起。测试：用 ab 工具模拟 10k 连接，观察吞吐升 2x。



## 4.2 阻塞 IO 优化

在 RustFS 的 etag_reader.rs 中用 `spawn_blocking`：

```rust
async fn compute_etag(path: &str) -> String {
    tokio::task::spawn_blocking(move || {
        // 阻塞文件读取与MD5
        let data = std::fs::read(path).unwrap();
        format!("{:x}", md5::compute(&data))
    }).await.unwrap()
}
```

不要在 async fn 中阻塞调用 (如 `std::fs`)，改用 `spawn_blocking`



## 4.3 IO 密集型文件处理

```rust
use tokio::runtime::Builder;
use tokio::fs::File;
use tokio::io::AsyncReadExt;
use tokio::task::JoinSet;

#[tokio::main]
asyncfn main() -> std::io::Result<()> {
    let rt = Builder::new_multi_thread()
        .worker_threads(8)  // 推荐：核数 * 2，平衡 IO
        .max_blocking_threads(1024)  // 推荐：大池防饥饿
        .enable_io()  // 只启用 IO，优化资源
        .global_queue_interval(31)
        .build()?;

    rt.block_on(async {
        letmut set = JoinSet::new();
        for i in0..1000 {
            set.spawn(asyncmove {
                letmut file = File::open(format!("file_{i}.txt")).await?;
                letmut buf = Vec::new();
                file.read_to_end(&mut buf).await?;
                Ok(buf.len())
            });
        }
        letmut total = 0;
        whileletSome(res) = set.join_next().await {
            total += res??;
        }
        println!("Total bytes read: {total}");
        Ok(())
    })
}
```

max_blocking_threads=1024 解决文件 IO 阻塞，JoinSet 管理并发。优势：吞吐升 3x，问题解决：默认池饱和导致延迟



## 4.4 CPU 密集型计算

```rust
use tokio::runtime::Builder;
use tokio::task;

#[tokio::main]
asyncfn main() {
    let rt = Builder::new_current_thread()  // 推荐：单线程避窃取开销
        .enable_all()
        .max_blocking_threads(256)  // 推荐：中等池隔离 CPU 任务
        .rng_seed(42)  // 推荐：确定性
        .build()
        .unwrap();

    rt.block_on(async {
        letmut handles = Vec::new();
        for i in0..100 {
            handles.push(task::spawn_blocking(move || {
                letmut sum = 0u64;
                for j in0..1_000_000 {
                    sum += (i + j) asu64;
                }
                sum
            }));
        }
        letmut total = 0u64;
        for handle in handles {
            total += handle.await.unwrap();
        }
        println!("Total sum: {total}");
    });
}
```

new_current_thread 解决 CPU 霸占，spawn_blocking 隔离。优势：计算稳定，问题解决：默认多线程争用导致低效。
