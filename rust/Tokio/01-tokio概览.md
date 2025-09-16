# 1. 异步运行时

Rust 本身只提供异步编程所需的基本特性，如 `async/await` 关键字，标准库中的 `Future` 特征，官方提供的 `futures` 实用库，这些特性单独使用没有任何用处，需要一个运行时将这些特性实现的代码运行起来。

异步运行时由 Rust 社区提供，它们的核心是一个 `reactor` 和 一个或多个 `executor`：

- `reactor` 用于提供外部事件的订阅机制，例如 `I/O`、进程间通信、定时器等
- `executor` 用于调度和执行相应的任务 (`Future`)

主流运行时：

- `tokio`：目前最受欢迎的异步运行时，功能强大，还提供异步所需的各种工具(如 `tracing`)、网络协议框架 (HTTP, gRPC) 等
- `async-std`：最大的优点就是跟标准库兼容性较强
- `smol`：一个小巧的异步运行时



# 2. tokio

## 2.1 概述

`tokio` 是一个 Rust 异步运行时，它提供了编写网络应用所需的构建块，并提供针对各种系统的灵活性，从有几十个内核的大型服务器到小型嵌入式设备。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/tokio-stack.jpg)

组件说明：

- `Runtime`：运行时包括 I/O、定时器、文件系统、同步和调度设施，是异步应用的基础
- `Hyper`：HTTP 客户端和服务器库，支持 http 1/2 协议
- `Tonic`：无固定规则 (boilerplate-free) 的 `gRPC` 客户端和服务器库，通过网络发布和使用 API 的最简单方法
- `Tower`：用于建立可靠客户端和服务器的模块化组件，包括重试、负载均衡、过滤、请求限制设施等
- `Mio`：在操作系统的事件 I/O API 之上的最小可移植 API
- `Tracing`：对应用程序和库的统一的洞察力，提供结构化、基于事件的数据收集和记录
- `Bytes`：网络应用程序操作字节流



## 2.2 优势

**可靠性**：基于 Rust 的所有权和类型系统，以及借助 Rust 并发模型，能避免诸如无限队列、缓冲区溢出、线程饥饿等常见 bug。

**高性能**：基于多线程工作窃取调度器，能高效地处理大量并发连接和任务。

**轻量级**：体积小巧，内建实现了 I/O、计时器、文件系统和同步等底层功能。

**高弹性**：提供多种运行时变化。从多线程、work-stealing 的运行时到轻量级、单线程的运行时都有。每个运行时都有许多旋钮，允许根据需求进行调整，例如服务器应用程序、嵌入式设备的需求不同的灵活调整策略。

**生态完善**：与周边项目如 Hyper、Tonic、Tower 等无缝衔接，能轻松构建网络服务。



## 2.3 劣势

`tokio` 不适用场景：

- **CPU 密集型任务**：`tokio` 非常适合于 IO 密集型任务，这类任务的绝大多数事件都用于阻塞等待 IO 结果，而不是CPU计算。如果应用是 CPU 密集型任务，建议使用 `rayon`。
- **读取大量文件**：读取文件的瓶颈主要在于操作系统，因为 OS 没有提供异步文件读取接口，大量的并发并不会提升文件读取的并行性能，反而可能会造成不可忽略的性能损耗，因此建议使用线程(或线程池)的方式。
- **发送少量 HTTP 请求**：`tokio` 的优势是处理大规模并发任务的能力，对于轻量级的 HTTP 请求场景，`tokio` 除了增加代码的复杂性，并无法带来额外的优势，针对这种场景，可以使用 `reqwest` 库，它会更加简单易用。



# 3. 异步术语

**并发(Concurrency) 和并行(Parallelism)**：

- 并行的任务，也是并发的，但反过来不一定

- 两个任务交替进行，但实际上从未同时进行两个任务，这是并发，而非并行



**Future**:

- 是一个存储某些操作当前状态的值。提供 poll 方法，它使操作继续进行，直到它需要等待某些东西，如网络连接等。对 poll 方法的调用应用很快返回
- 通过在一个异步块中使用 `.await` 组合多个 Future 来创建



**执行器(Executor) 和调度器(Scheduler)**：

- 执行器和调度器通过轮询调用 poll 方法执行 future。标准库没有执行器，由社区异步运行时提供，比如 tokio
- 执行器能够在几个线程上并发地运行大量的 future，它通过在等待时交换当前运行的任务来做到这一点。如果代码花了很长时间都未达到 `.await`，这就被成为 "阻塞线程" 或 “not yielding back to the executor”，它将阻止其它任务的运行



**运行时(Runtime)**：

- 运行时是一个库，它包含了执行器及集成的各种实用工具，如定时和IO工具。运行时和执行器在某种程度上是一个概念。标准库没提过运行时，一般由社区提供。例如 `tokio`



**任务(Task)**：

- 任务在 tokio 运行时上执行的操作，由 `tokio::spawn` 或 `Runtime::block_on` 函数创建。通过组合创建 `Future` 的工具，如 `.await` 和 `join!` 并不创建新的任务，每个组合的部分都被说成是“在同一个任务中”
- 多个任务是需要并行的，但使用 `join!` 等工具可以在一个任务上并发地做多件事情



**spawn**：

- `tokio::spawn`  创建一个新任务
- `std::thread::spawn` 创建一个新线程



**异步块(Async Block)**：创建一个运行一些代码的 future 的简单方法

```rust
let world = async {
    println!("world!");
};

let my_future = async {
    print!("Hello ");
    world.await;
};
```



**异步函数(Async Function)**：其主体是一个 Future，本质是一个返回 future 的普通函数

```rust
async fn do_stuff(i: i32) -> String {
    // do stuff
    format!("The integer is {}.", i)
}

// same as above
// `impl Trait` 返回一个 Future，因为 Future 是一个 trait
use std::future::Future;
fn do_stuff(i: i32) -> impl Future<Output = String> {
    async move {
        // do stuff
        format!("The integer is {}.", i)
    }
}
```



**让出 (Yielding)**：

- Yielding 是允许执行者在单个线程上运行多个 future 的原因

- 每当一个 future 让出时，执行者能够将该 future 与其它 future 交换，通过反复交换当前任务，执行者可以并发地执行大量的任务
- future 只能在 `.await` 时让出，所以在 `.await` 之间花很长时间的 future 可以阻止其它任务的运行



**流 (Stream)**：它是  `Iterator` 的异步版本，提供一个数值流，通常与 `while let` 一起使用

```rust
use tokio_stream::StreamExt;   // for next()

while let Some(item) = stream.next().await {
    // do something
}
```



**通道 (channel)**：允许代码的一部分向其它部分发送消息。tokio 提供了如下通道

- `mpsc`：多生产者，单消费者
- `oneshot`：单生产者，单消费者
- `broadcast`：多生产者，多消费者
- `watch`：单生产者，多消费者。不保留历史，接收者只看到最新的值



**背压(Backpressure)**：

- 是一种针对高负荷反应良好的应用程序模式，例如，`mpsc` 通过有 **有界** 和 **无界** 两种形式
- 通过**有界通道**，如果接收方不能跟上消息的数量，接收方可以向发送方施加**背压**，这样就避免通道消息的累积，造成内存无限增长的问题



**Actor**：

- 一种设计应用程序的模型，Actor 是只一个独立生成的任务，它代表应用程序的其它部分管理一些资源，使用通道与应用程序的其它部分











