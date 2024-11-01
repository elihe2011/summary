# 1. 概述

Tokio 是用于 Rust 编程语言的一个异步运行时，它提供了编写网络应用所需的构建块。并提供针对各种系统的灵活性，从有几十个内核的大型服务器到小型嵌入式设备。



Tokio 技术栈：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/rust/tokio-stack.jpg)

- Runtime：运行时包括I/O、定时器、文件系统、同步和调度设施，是异步应用的基础。
- Hyper：是一个HTTP客户端和服务器库，同时支持 HTTP 1 和 2 协议
- Tonic：是一个无固定规则 (boilerplate-free) 的 gRPC 客户端和服务器库，通过网络发布和使用API的最简单方法。
- Tower：用于建立可靠的客户端和服务器的模块化组件，包括重试、负载均衡、过滤、请求限制设施等。
- Mio：在操作系统的事件化 I/O API 之上的最小的可移植 API。
- Tracing：对应用程序和库的统一的洞察力，提供结构化的、基于事件的数据收集和记录。
- Bytes：在核心部分，网络应用程序操纵字节流。



# 2. 术语

**异步(Asynchronous)**：异步代码指的是使用 async/await 语言特性的代码，它允许许多任务在几个线程 （甚至单线程）上并发运行。



**并发(Concurrency)和并行(Parallelism)**：

- 平行的任务，也是并发的，但反过来不一定
- 两个任务交替进行，但实际上从未同时进行两个任务，这是并发，而非并行



**未来(Future)**：

- 是一个存储某些操作当前状态的值。提供 poll 方法，它使操作继续进行，直到它需要等待某些东西，如网络连接等。对 poll 方法的调用应用很快返回
- 通过在一个异步块中使用 `.await` 组合多个 Future 来创建



**执行器(Executor)和调度器(Scheduler)**：

- 执行器或调度器通过重复调用 poll 方法执行 future 的东西。标准库中没有执行器，需要外部库来实现，使用最广泛的执行器是由 Tokio 运行时提供
- 执行器能够在几个线程上并发地运行大量的 future，它通过在等待时交换当前运行的任务来做到这一点。如果代码花了很长事件都没有达到 `.await` ，这就被称为 “阻塞线程” 或 “not yielding back to the executor”，它将阻止其他任务的运行



**运行时(Runtime)**：

- 运行时是一个库，它包含了执行器及与改执行器集成的各种实用工具，如定时和IO工具。运行时和执行器某种程度上是一个概念。标准库没有运行时，需要一个外部库来实现，最广泛应用的就是 Tokio 运行时



**任务(Task)**：

- 任务是在 Tokio 运行时上运行的操作，由 `tokio::spawn` 或 `Runtime::block_on` 函数创建。通过组合创建 Future 的工具，如 `.await` 和 `join!` 并不创建新的任务，每个组合的部分都被说成是“在同一个任务中”。
- 多个任务是需要并行的，但使用 `join!` 等工具可以在一个任务上并发做多件事情。



**spawn**：

- 使用 `tokio::spawn` 函数创建一个新的任务
- 使用 `std::thread::spoon` 创建新的线程



**异步块(Async block)**：

- 创建一个运行一些代码的 future 的简单方法

```rust
let world = async {
    println!("world!");
};

let my_future = async {
    print!("Hello ");
    world.await;
};
```



**异步函数(Async function)**：

与异步块类似，异步函数是移植创建函数的简单方法，其主体成为一个 future。所有的异步函数都可以被改写成一个返回一个 future 的普通函数。

```rust
async fn do_stuff(i: i32) -> String {
    // do stuff
    format!("The integer is {}.", i)
}

// same as above
use std::future::Future;
fn do_stuff(i: i32) -> impl Future<Output = String> {
    async move {
        // do stuff
        format!("The integer is {}.", i)
    }
}
```

`impl Trait` 返回一个 future，因为 Future 是一个 trait



**让出(Yielding)**：

在异步背景下，Yielding 是允许执行者在单个线程上执行多个 future 的原因。每当一个 future 让出时，执行者能够将该 future 与其他 future 交换，通过反复交换当前任务，执行者可以并发地执行大量的任务。future 只能在 `.await` 时让出，所以在 `.await` 之间花很长时间的 future 可以阻止其他任务的运行。



**阻塞(Blocking)**：

一个 future 花很长时间而不让出



**流(Stream)**：

Stream 是 Iterator 的异步版本，它提供了一个数值流，通常与 while let 一起使用

```rust
use tokio_stream::StreamExt;   // for next()

while let Some(item) = stream.next().await {
    // do something
}
```



**通道(Channel)**：

通道是一种工具，允许代码的一个部分向其他部分发送消息。Tokio 提供许多通道，每个通道都有不同的用途：

- mpsc：多生产者，单消费者通道
- oneshot：单生产者，单消费者通道
- broadcast：多生产者，多消费者通道
- watch：单生产者，多消费者。不保留历史，接收者只看到最新的值



**背压(Backpressure)**:

背压是一种设计针对高负荷反应良好的应用程序的模式。例如，mpsc 通道有 **有界** 和 **无界** 两种形式。通过使用有界通道，如果接收方不能跟上消息的数量，接收方可以对发送方施加“背压”，这就避免了随着通道上的消息越来越多，内存使用量无限制地增长。



**Actor**：

一种设计应用程序的模式。Actor 是只一个独立生成的任务，它代表应用程序的其他部分管理一些资源，使用通道与应用程序的其他部分。



# 3. 优势

**可靠性**：基于 Rust 的所有权和类型系统，以及借助 Rust 并发模型，能避免诸如无限队列、缓冲区溢出、线程饥饿等常见 bug。

**高性能**：基于多线程工作窃取调度器，能高效地处理大量并发连接和任务。

**轻量级**：体积小巧，内建实现了 I/O、计时器、文件系统和同步等底层功能。

**搞弹性**：提供多种运行时变化。从多线程、work-stealing 的运行时到轻量级、单线程的运行时都有。每个运行时都有许多旋钮，允许根据需求进行调整，例如服务器应用程序、嵌入式设备的需求不同的灵活调整策略。

**生态完善**：与周边项目如 Hyper、Tonic、Tower 等无缝衔接，能轻松构建网络服务。



# 4. 不适用场景

- 通过在几个线程上并行运行来加速由CPU控制的计算。tokio 是为 IO 绑定的应用设计的，此种情况下，每个单独的任务大部分时间都在等待IO。如果一个应用程序唯一做的事情时并行运算，应该使用 rayon。如果同时做这两件事，支持”混搭“。
- 读取大量的文件。使用 tokio 读取大量文件，与普通线程池相比，不具备任何优势，因为操作系统一般不提供异步文件API。
- 发送单个网络请求。tokio 的优势在于并发处理，单网络请求不需要同时做很多事情，选择阻塞式API更合适







































