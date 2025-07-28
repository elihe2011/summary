# 1. async

## 1.1 异步编程

async 是 Rust 的异步编程模型，它与其它并发模型对比如下：

- **OS 线程**：最简单，无需改变任何编程模型的业务和代码逻辑，适合作为语言的原生并发模型。但这种模型存在致命缺点，例如线程间的同步困难、现场间上下文切换损耗较大。使用线程池在一定程度上可以提升性能，但对于 IO 密集型场景来说，线程池依旧不够。
- **事件驱动(Event driven)**：即回调(Callback)，这种模型性能很好，但最大的问题就是存在回调地狱风险：非线性的控制流和结果处理导致了数据流向和错误传播变得难以掌控，还会导致代码可维护性和可读性变差。JavaScript 曾经就存在回调地狱。

- **协程(Coroutines)**：与线程类似，无需改变编程模型，同时它也跟 async 类似，可以支持大量的任务并发运行。但协程抽象层次过高，导致用户无法接触到底层的细节，这对系统编程和自定义异步运行时是难以接受的。
- **actor模型**：是 erlang 的杀手锏之一，它将所有并发计算分割成一个一个单元，这些单元被称为 actor，单元之间通过消息传递的方式进行通信和数据传递，与分布式系统的设计理念相近。由于 actor 模型跟现实很贴近，因此它相对来说更容易实现，但是一旦遇到控制流、失败重试等场景时，就会变得不太好用。
- **async/await**：性能高，还支持底层编程，同时又像线程和协程那样无需过多的改变编程模型。但是，async 模型的内部实现机制过于复杂，理解和使用没那么简单。



Rust 提供多线程 和 async 两种异步编程模式：

- **多线程**：由标准库实现，**低并发**时，如并行计算，可以选择它，优点是线程内的代码执行效率更高、更直观和简单。
- **async**：通过语言特性 + 标准库 + 第三方库的方式实现，在需要**高并发、异步 IO** 时，它是很不错的选择。



相较于 JavaScript，Rust 中的 async 特定：

- **Future 是惰性的**：只在被轮询(poll)时才会运行，因此丢弃一个 future 会阻止它未来再被运行。可以将 future 理解为一个在未来某个时间点被调度执行的任务。
- **Async 开销是零**：async本身没有性能损耗，无需额外分配内存给它。
- **没有内置异步调用运行时**：使用第三方提供的运行时，如 tokio
- **运行时同时支持单线程和多线程**



## 1.2 与多线程对比

async 和 多线程对比：

- OS线程：适合少量任务并发
  - 优点：代码逻辑和编程模型只需要少量修改即可在新线程中直接运行。
  - 缺点：创建和上下文切换非常昂贵，甚至空闲的线程都会消耗系统资源。线程池可以有效降低性能消耗，但无法彻底解决问题。
  - 适用场景：长时间运行的 CPU 密集型任务，如并行计算。这种密集型任务往往会让所在的线程持续运行，任何不必要的线程切换都会带来性能损耗，因此高并发此时反而成为一种多余。同时创建的线程数应该等于 CPU 核心数，充分利用 CPU 的并行能力，甚至还可以将线程绑定到 CPU 核心上，进一步减少线程上下文切换。
- async：底层基于线程封装了一个运行时，可以将多个任务映射到少量线程上
  - 优点：可以有效地降低 CPU 和内存的负担，又可以让大量的任务并发运行，一个任务一旦处于 IO 或其他阻塞状元，就会被立刻切走并执行另一个任务，此处的切换的性能开销要远远低于使用多线程时的线程上下文切换。
  - 缺点：编译期会为 async 函数生成状态机，然后将整个运行时打包进来，这导致二进制可执行文件体积显著增大。
  - 适用场景：高并发、IO密集型任务，如web服务器、数据库连接等网络服务。这类任务大部分时间都处于等待状态，如果使用多线程，那线程时间会处于无所事事的状态，再加上线程上下文切换的高昂代价，让多线程做 IO 密集型任务变成了一件非常奢侈的事。

- 性能对比

  | 操作 | async  | OS线程 |
  | ---- | ------ | ------ |
  | 创建 | 0.3 μs | 17 μs  |
  | 切换 | 0.2 μs | 1.7 μs |

  

## 1.3 语言和库支持

async 底层实现非常复杂，且会导致编译的二进制文件体积显著增加。Rust 没有像 Go 一样内存完整的特性和运行时，而是选择通过 Rust 提供必要的特性支持，再通过社区来提供 async 运行时支持。因此要完整的使用 async 异步编程，需要依赖以下特性和外部库

- 所必需的特征(例如 Future)、类型和函数，由标准库提供
- 关键字`async/await` 由 Rust 提供，并进行了编译器层面的支持
- 众多实用的类型、宏和函数由官方开发的 futures 包提供(非标准库)，它们可以用于任何 async 应用中
- async 代码的执行、IO操作、任务创建和调度等复杂功能由社区的 async 运行时提供，例如 `tokio` 和 `async-std`



## 1.4 编译和错误

大多数情况下，async 中的编译错误和运行时错误跟之前没啥区别，但是依然有以下几点值得注意：

- 编译错误，用于 async 编译时需要经常使用复杂的语言特性，例如生命周期和Pin，因此相关的错误可能会出现的更加频繁
- 运行时错误，编译器会为每一个 async 函数生成状态机，这会导致在栈跟踪时会包含这些状态机的细节，同时还包含了运行时对函数的调用，因此，栈跟踪记录 (如 panic) 将变得更加难以理解
- 某些隐蔽的错误可能发生。例如在一个 async 上下文中去调用一个阻塞的函数，或者没有正确实现 Future 特征都有可能导致这种错误。这种错误可能会悄无声息的通过编译检查甚至有时候会通过单元测试。



## 1.5 兼容性

异步代码和同步代码并不总能和睦共处。无法在一个同步函数中调用一个 async 异步函数。同步和异步代码往往使用不同的设计模式，这导致两者融合上的困难

异步代码之间，如果依赖的运行时不同或不兼容时，也会导致不可预知的麻烦



## 1.6 简单入门

async/await 是 Rust 内置的语言特性，可以让开发者用同步的方式编写异步代码

通过 async 标记的语法块会被转换成实现了 Future 特征的状态机。与同步调用阻塞当前线程不同，当 Future 执行并遇到阻塞时，它会让出当前线程的控制器。这样其它的 Future 就可以在该线程中运行，这种方式完全不会导致当前线程的阻塞。

使用 async/await 关键字，需要先引入 futures 包。编辑 `Cargo.toml` 文件并添加以下内容：

```toml
[dependencies]
futures = "0.3"
```



### 1.6.1 async

通过 `block_on` 执行 Future 并等待其执行完成

```rust
use futures::executor::block_on;

// 返回一个 Future
async fn hello() {
    println!("hello world!");
}

fn main() {
    let future = hello();
    block_on(future); // 执行Future并等待其完成
}
```



### 1.6.2 await

在 `async fn` 函数中使用 `.await` 可以等待另一个异步调用的完成。但与 `block_on` 不同，`.await` 并不会阻塞当前的线程，而是异步的等待 `Future A` 的完成，在等待过程中，该线程还可以继续执行其它的 `Future B`，最终实现了并发处理的效果

```rust
use futures::executor::block_on;

async fn hello() {
    cat().await;
    println!("hello world!");
}

async fn cat() {
    println!("hello, kitty!");
}

fn main() {
    let future = hello();
    block_on(future); // 执行Future并等待其运行完成
}
```



# 2. 底层实现

## 2.1 Future 特征

Future 特征是 Rust 异步编程的核心，也是异步函数的反正值和被执行的关键

### 2.1.1 简化版 Future

```rust
trait SimpleFuture {
    type Output;
    fn poll(&mut self, wake: fn()) -> Poll<Self::Output>;
}

enum Poll<T> {
    Ready(T),
    Pending,
}
```

Future 需要被执行器 poll 后才能运行。若在当前 poll 中，Future 可以被完成，则返回 `Poll::Ready(result)`，反之则返回 `Poll::Pending`，并且安排一个 `wake` 函数：当未来 `Future` 准备好进一步执行时，该函数会被调用，然后管理该 Future 的执行器 (`block_on`) 会再次调用 poll 方法，此时 Future 就可以继续执行了。

如果没有 wake 方法，执行器无法知道某个 Future 是否可以继续被执行，除非执行器定期的轮询每一个 Future，确认它是否能被执行，但这种做法效率较低。有了 wake，Future 就可以主动通知执行器，然后执行器就可以精确地执行该 Future。

实现 Future trait:

```rust
pub struct SocketRead<'a> {
    socket: &'a Socket,
}

impl SimpleFuture for SocketRead<'_> {
    type Output = Vec<u8>;
    
    fn poll(&mut self, wake: fn()) -> Poll<Self::Output> {
        if self.socket.has_data_to_read() {
            // 有数据，写入buffer并返回
            Poll::Ready(self.socket.read_buf())
        } else {
            // 没数据，注册一个`wake`函数，当数据可用时，该函数被调用
            // 然后当前Future的执行器会再次调用`poll`方法，此时就可以读取到数据
            self.socket.set_readable_callback(wake);
            Poll::Pending
        }
    }
}
```



同时运行多个 Future 或链式调用多个 Future，也可以通过无内存分配的状态机实现：

```rust
pub struct Join<FutureA, FutureB> {
    a: Option<FutureA>,
    b: Option<FutureB>,
}

impl<FutureA, FutureB> SimpleFuture for Join<FutureA, FutureB>
where
    FutureA: SimpleFuture<Output = ()>,
    FutureB: SimpleFuture<Output = ()>,
{
    type Output = ();
    fn poll(&mut self, wake: fn()) -> Poll<Self::Output> {
        // 尝试完成 Future `a`
        if let Some(a) = &mut self.a {
            if let Poll::Ready(()) = a.poll(wake) {
                self.a.take();
            }
        }
        
        // 尝试完成 Future `b`
        if let Some(b) = &mut self.b {
            if let Poll::Ready(()) = b.poll(wake) {
                self.b.take();
            }
        }
        
        if self.a.is_none() && self.b.is_none() {
            // 两个 Future 都已完成，可以成功返回了
            Poll::Ready(())
        } else {
            // 至少有一个 Future 未完成，继续等待
            Poll::Pending
        }
    }
}
```



多个 Future 连续运行：

```rust
pub struct AndThenFuture<FutureA, FutureB> {
    first: Option<FutureA>,
    second: FutureB,
}

impl<FutureA, FutureB> SimpleFuture for AndThenFuture<FutureA, FutureB> 
where
    FutureA: SimpleFuture<Output = ()>,
    FutureB: SimpleFuture<Output = ()>,
{
    type Output = ();
    fn poll(&mut self, wake: fn()) -> Poll<Self::Output> {
        if let Some(first) = &mut self.first {
            match first.poll(wake) {
                // 第一个 Future 已完成，将其移除，准备运行第二个
                Poll::Ready(()) => self.first.take(),
                // 第一个 Future 未完成
                Poll::Pending => return Poll::Pending,
            };
        }
        
        // 第一个 Future 已完成，尝试去完成第二个
        self.second.poll(wake)
    }
}
```



### 2.1.2 标准库 Future

```rust
trait Future {
    type Output;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

Pin：创建一个无法被移动的 Future，具有固定的内存地址，对 `async/await` 来说，Pin 时不可或缺的关键特性。

Context：意味着 wake 函数可以携带数据，它通过提供一个 `Waker` 类型的值，就可以用来唤醒特定的任务。



## 2.2 Waker 唤醒任务

它提供一个 `wake()` 方法用于告诉执行器：相关的任务可以被唤醒了，此时执行器就可以对相应的 Future 再次进行 poll 操作



实现一个简单的定时器 Future：

```rust
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};
use std::thread;
use std::time::Duration;

pub struct TimerFuture {
    shared_state: Arc<Mutex<SharedState>>,
}

struct SharedState {
    completed: bool,
    waker: Option<Waker>,
}

impl Future for TimerFuture {
    type Output = ();
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // 检查共享状态，确定定时器是否已完成
        let mut shared_state = self.shared_state.lock().unwrap();
        if shared_state.completed {
            Poll::Ready(())
        } else {
            // 设置 `waker`，这样新线程在睡眠(计时)结束后可以唤醒当前任务，再次对Future进行poll操作
            shared_state.waker = Some(cx.waker().clone());
            Poll::Pending
        }
    }
}

impl TimerFuture {
    pub fn new(duration: Duration) -> TimerFuture {
        let shared_state = Arc::new(Mutex::new(SharedState {
            completed: false,
            waker: None,
        }));
        
        // 创建新线程
        let thread_shared_state = shared_state.clone();
        thread::spawn(move || {
            // 睡眠指定时间实现计时器功能
            thread::sleep(duration);
            let mut shared_state = thread_shared_state.lock().unwrap();
            
            // 通知执行器定时器已完成，可以继续`poll`对应的`Future`了
            shared_state.completed = true;
            if let Some(waker) = shared_state.waker.take() {
                waker.wake();
            }
        });
        
        TimerFuture { shared_state }
    }
}
```



## 2.3 Executor 执行器

Rust 的 Future 是惰性的：只有在屁股上拍一拍，它才会努力动一动。

两种驱动 Future 方式：

- `.await`：在 `async` 函数中调用另一个 `async` 函数
- `executor`：执行最外层的 `async` 函数

执行器会管理一批 Future，然后通过不停地 poll 推动它们直到完成。最开始，执行器会先 poll 一次 Future，后面就不会主动去 poll 了，而是等待 Future 通过调用 wake 函数来通知它可以继续，它会继续去 poll。这种 wake通知，然后 poll 的方式会不断重复，直到 Future 完成。



构建执行器：

```rust
use std::sync::{Arc, Mutex};
use std::sync::mpsc::{sync_channel, Receiver, SyncSender};
use std::task::Context;
use std::time::Duration;
use futures::future::{BoxFuture, FutureExt};
use futures::task::{waker_ref, ArcWake};
use timer_future::TimerFuture;

// 任务执行器，负责从通道中接收任务并执行
struct Executor {
    ready_queue: Receiver<Arc<Task>>
}

// 负责创建新的`Future`，然后将它发送到任务通道中
#[derive(Clone)]
struct Spawner {
    task_sender: SyncSender<Arc<Task>>
}

// 一个`Future`，它可以调度自己（将自己放入任务通道中），然后等待执行器去`poll`
struct Task {
    /// 进行中的Future，在未来的某个时间点会被完成
    /// 按理来说`Mutex`在这里是多余的，因为只有一个线程来执行任务，但是由于
    /// Rust并不聪明，它无法知道`Future`只会在一个线程内被修改，并不会被跨线程修改。
    /// 因此需要使用`Mutex`来满足这个笨笨的编译器对线程安全的执着
    /// 
    /// 生成级的执行器实现，不会使用`Mutex`，因为会带来性能上的开销，取而代之的是使用`UnsafeCell`
    future: Mutex<Option<BoxFuture<'static, ()>>>,
    
    /// 可以将该任务自身放回到任务通道中，等待执行器的poll
    task_sender: SyncSender<Arc<Task>>,
}

fn new_executor_and_spawner() -> (Executor, Spawner) {
    // 任务通道允许的最大缓冲数(任务队列的最大长度)
    // 当前的实现仅仅是为了简单，在实际的执行中，并不会这么使用
    const MAX_QUEUED_TASKS: usize = 10_000;
    let (task_sender, ready_queue) = sync_channel(MAX_QUEUED_TASKS);
    (Executor { ready_queue }, Spawner { task_sender })
}

// 生成 `Future` 并将它放入任务通道中
impl Spawner {
    fn spawn(&self, future: impl Future<Output = ()> + 'static + Send) {
        let future = future.boxed();
        let task = Arc::new(Task {
            future: Mutex::new(Some(future)),
            task_sender: self.task_sender.clone()
        });
        self.task_sender.send(task).expect("task queue full");
    }
}

// 创建 `Waker` 的最简单方式就是实现 `ArcWake` 特征
impl ArcWake for Task {
    fn wake_by_ref(arc_self: &Arc<Self>) {
        // 通过发送任务到任务管道的方式来实现`wake`，这样 `wake` 后，任务就能被执行器 `poll`
        let cloned = arc_self.clone();
        arc_self.task_sender.send(cloned).expect("task queue full");
    }
}

// 当任务实现了 `ArcWake` 特征后，它就变成了 `Waker`，在调用 `wake()` 对其唤醒后将任务复制一份所有权(Arc)，
// 然后将其发送到任务通道中。最后执行器将从通道中获取任务，然后进行 `poll` 执行
impl Executor {
    fn run(&self) {
        while let Ok(task) = self.ready_queue.recv() {
            // 获取一个 future，如果它未完成（仍然是Some，而非None），则对它进行一次 poll 并尝试完成它
            let mut future_slot = task.future.lock().unwrap();
            if let Some(mut future) = future_slot.take() {
                // 基于任务自身创建一个 `LocalWaker`
                let waker = waker_ref(&task);
                let context = &mut Context::from_waker(&*waker);
                // `BoxFuture<T>` 是 `Pin<Box<dyn Future<Output = T> + Send + 'static>>` 的
                // 通过调用 `as_mut` 方法，可以将上面的类型转换成 `Pin<&mut dyn Future + Send + 'static>`
                if future.as_mut().poll(context).is_pending() {
                    // Future 还未执行，因此将其放回任务中，等待下次被 poll
                    *future_slot = Some(future);
                }
            }
        }
    }
}

fn main() {
    let (executor, spawner) = new_executor_and_spawner();
    
    // 生成一个任务
    spawner.spawn(async {
        println!("howdy");
        // 创建定时器 Future，并等待它完成
        TimerFuture::new(Duration::new(2, 0)).await;
        println!("done!");
    });
    
    // 运行执行器直到任务列表为空
    executor.run();
}
```



# 3. Pin & Unpin

在 Rust 中，所有的类型可以分为两类：

- **类型的值可以在内存中安全地被移动**：例如数值、字符串、布尔值、结构体、枚举等
- **自引用类型**

自引用类型示例：

```rust
struct SelfRef {
    value: String,
    pointer_to_value: *mut String,
}
```

`pointer_to_value` 是一个裸指针，指向第一个字段 `value` 持有的字符串 `String`。这里存在一个致命的问题：`value` 的内存地址变了，而 `pointer_to_value` 依然执行 `value` 之前的地址，一个重大的 bug 就出现了。



Pin：阻止一个类型在内存中被移动

Unpin：类型可以在内存中安全地移动



## 3.1 Pin

`async/.await` 是如何工作的：

```rust
let fut_one = /* ... */;  // Future 1
let fut_two = /* ... */;  // Future 2
async move {
    fut_one.await;
    fut_two.await;
}
```

在底层，`async` 会创建一个实现了 `Future` 的匿名类型，并提供一个 `poll` 方法：

```rust
// `async { ... }` 语句块创建的 `Future` 类型
struct AsyncFuture {
    fut_one: FutOne,
    fut_two: FutTwo,
    state: State,
}

// `async` 语句块可能处于的状态
enum State {
    AwaitingFutOne,
    AwaitingFutTwo,
    Done,
}

impl Future for AsyncFuture {
    type Output = ();
    
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        loop {
            match self.state {
                State::AwaitingFutOne => match self.fut_one.poll(..) {
                    Poll::Ready(()) => self.state = State::AwaitingFutTwo,
                    Poll::Pending => return Poll::Pending,
                }
                State::AwaitingFutTwo => match self.fut_two.poll(..) {
                    Poll::Ready(()) => self.state = State::Done,
                    Poll::Pending => return Poll::Pending,
                }
                State::Done => return Poll::Ready(()),
            }
        }
    }
}
```

当 `poll` 第一次被调用时，它会去查询 `fut_one` 的状态，若 `fut_one` 无法完成，则 `poll` 方法会返回。未来对 `poll` 的调用将从上一次调用结束的地方开始。该过程会一直持续，直到 Future 完成为止。

然而，如果在 `async` 语句块中使用引用类型，会发生什么？

```rust
async {
    let mut x = [0; 128];
    let read_into_buf_fut = read_into_buf(&mut x);
    read_into_buf_fut.await;
}
```

这段代码会编译成下面的形式：

```rust
struct ReadIntoBuf<'a> {
    buf: &'a mut [u8], // 指向下面的`x`字段
}

struct AsyncFuture {
    x: [u8; 128],
    read_into_buf_mut: ReadIntoBuf<'what_lifetime?>,
}
```

`ReadIntoBuf` 拥有一个引用字段，指向了结构体的另一个字段 `x`，一旦 `AsyncFuture` 被移动，那 `x` 的地址也将随之变化，此时对 `x` 的引用就变成了不合法的，也就是 `read_into_buf_fut.buf` 会变为不合法的。

若能将 Future 在内存中固定到一个位置，就可以避免这种问题的发生，也就可以安全的创建上面这种引用类型



## 3.2 Unpin

Pin 不是特征，而是结构体：

```rust
pub struct Pin<P> {
    pointer: P,
}
```

它包裹一个指针，并且能够确保该指针指向的数据不会被移动，例如 `Pin<&mut T>`，`Pin<&T>`，`Pin<Box<T>>`，都能确保 `T` 不会被移动。

`Pin<Pointer>` ==> `Pointer (e.g. Box<Data>)` ==> `Data`

而 `Unpin` 才是一个特征，它表明一个类型可以随意被移动。可以被 `Pin` 住的值的实现了特征 `!Unpin`，其中 `!` 代表没有实现某个特征的意思，`!Unpin` 说明类型没有实现 `Unpin` 特征，那自然就可以被 `Pin`。

类型如果实现了 `Unpin` 特征，就不能被 `Pin` 了？其实，还是可以 `Pin` 的，毕竟它只是一个结构体，可以随意使用，**但是不再有任何效果，该值一样可以被移动！**

例如 `Pin<&mut u8>`，显然 `u8` 实现了 `Unpin` 特征，它可以在内存中被移动，因此 `Pin<&mut u8>` 与 `&mut u8` 实际上并未区别，一样可以被移动。

结论：**一个类型如果不能被移动，它必须实现 `!Unpin` 特征**。

`Unpin` 与 `Send/Sync` 进行对比，它们很像：

- 都是标记特征( marker trait)，该特征未定义任何行为，非常适用于标记
- 都可以通过 `!` 语法去除实现
- 绝大多数情况都是自动实现，无需开发者操心



## 3.3 深入 Pin

```rust
#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
}

impl Test {
    fn new(txt: &str) -> Self {
        Test {
            a: String::from(txt),
            b: std::ptr::null(),
        }
    }
    
    fn init(&mut self) {
        let self_ref：*const String = &self.a;
        self.b = self_ref;
    }
    
    fn a(&self) -> &str {
        &self.a
    }
    
    fn b(&self) -> &String {
        assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
        unsafe { &*(self.b) }
    }
}
```

`Test` 提供了方法用于获取字段 `a` 和 `b` 的值引用。`b` 是 `a` 的一个引用，但并没有使用引用类型而是用了裸指针，原因是：Rust 的借用规则不允许这样做，因为不符合生命周期要求。

如果不移动任何值，上面的示例没任务问题：

```rust
fn main() {
    let mut t1 = Test::new("test1");
    t1.init();
    let mut t2 = Test::new("test2");
    t2.init();
    
    println!("a: {}, b: {}", t1.a(), t1.b());
    println!("a: {}, b: {}", t2.a(), t2.b());
}

// 输出
a: test1, b: test1
a: test2, b: test2
```



尝试移动数据，将 t1 和 t2 进行交换：

```rust
fn main() {
    let mut t1 = Test::new("test1");
    t1.init();
    let mut t2 = Test::new("test2");
    t2.init();
    
    println!("a: {}, b: {}", t1.a(), t1.b());
    std::mem::swap(&mut t1, &mut t2);
    println!("a: {}, b: {}", t2.a(), t2.b());
}

// 预期输出
a: test1, b: test1
a: test1, b: test1

// 实际输出
a: test1, b: test1
a: test1, b: test2     // 原因是 t2.b 指针依然指向了旧地址，而该地址对应的值现在在 t1 中
```



## 3.4 Pin 实践

### 3.4.1 将值固定在栈上

```rust
use std::marker::PhantomPinned;
use std::pin::Pin;

#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
    _marker: PhantomPinned,
}

impl Test {
    fn new(txt: &str) -> Self {
        Test {
            a: String::from(txt),
            b: std::ptr::null(),
            _marker: PhantomPinned,   // 该标记让类型自动实现特征`!Unpin`
        }
    }
    
    fn init(self: Pin<&mut Self>) {
        let self_ptr: *const String = &self.a;
        let this = unsafe { self.get_unchecked_mut() };
        this.b = self_ptr;
    }
    
    fn a(self: Pin<&Self>) -> &str {
        &self.get_ref().a
    }
    
    fn b(self: Pin<&Self>) -> &String {
        assert!(!self.b.is_null(), "Test::b called without Test::init being called first");
        unsafe { &*(self.b) }
    }
}
```

使用一个标记类型 `PhantomPinned` 将自定义结构体 `Test` 变成了 `!Unpin` (编译器帮忙自动实现)，因此该结构体无法再被移动。

一旦类型实现了 `!Unpin`，那将它的值固定到栈 (stack) 上就是不安全的行为，因此需要使用 `unsafe` 语句块进行处理，也可以使用 `pin_utils` 来避免 `unsafe` 的使用。

尝试移动被固定的值，会导致编译错误：

```rust
fn main() {
    // `t1` 可以被安全的移动
    let mut t1 = Test::new("test1");
    
    // 新的 `t1` 使用了 `Pin`，因此无法再被移动
    let mut t1 = unsafe { Pin::new_unchecked(&mut t1) };
    Test::init(t1.as_mut());
    
    let mut t2 = Test::new("test2");
    let mut t2 = unsafe { Pin::new_unchecked(&mut t2) };
    Test::init(t2.as_mut());
    
    println!("a: {}, b: {}", Test::a(t1.as_ref()), Test::b(t1.as_ref()));
    std::mem::swap(t1.get_mut(), t2.get_mut());
    println!("a: {}, b: {}", Test::a(t2.as_ref()), Test::b(t2.as_ref()));
}

// 错误信息
error[E0277]: `PhantomPinned` cannot be unpinned
    --> src\main.rs:49:23
     |
49   |     std::mem::swap(t1.get_mut(), t2.get_mut());
     |                       ^^^^^^^ within `Test`, the trait `Unpin` is not implemented for `PhantomPinned`
```

需要特别注意的是**固定在栈上非常依赖于 `unsafe` 代码的正确性**。众所周知，`&'a mut T` 可以固定的生命周期是 `'a`，但却不知道当生命周期 `'a` 结束后，该指针指向的数据是否会被移走。如果在 `unsafe` 代码里这么实现了，就会违背 `Pin` 应该具体的作用。

一个常见的错误就是忘记去遮蔽 (shadow) 初始的变量，因为可以 drop 掉 Pin，然后在 `&'a mut T` 结束后去移动数据：

```rust
fn main() {
    let mut t1 = Test::new("test1");
    let mut t1_pin = unsafe { Pin::new_unchecked(&mut t1) };
    Test::init(t1_pin.as_mut());
    
    drop(t1_pin);
    println!(r#"t1.b points to "t1": {:?}..."#, t1.b);
    
    let mut t2 = Test::new("test2");
    std::mem::swap(&mut t1, &mut t2);
    println!("... and now it points nowhere: {:?}", t1.b);
}

// 输出信息
t1.b points to "t1": 0xed0c0ff9a8...
... and now it points nowhere: 0x0
```



### 3.3.2 固定到堆上

将一个 `!Unpin` 类型的值固定到堆上，会给予该值一个稳定的内存地址，它指向的堆中的值在 `Pin` 后是无法被移动的。而且与固定在栈上不同，堆上的值在整个生命周期内都会被稳稳地固定住。

```rust
use std::marker::PhantomPinned;
use std::pin::Pin;

#[derive(Debug)]
struct Test {
    a: String,
    b: *const String,
    _marker: PhantomPinned,
}

impl Test {
    fn new(txt: &str) -> Pin<Box<Self>> {
        let t = Test {
            a: String::from(txt),
            b: std::ptr::null(),
            _marker: PhantomPinned,   // 该标记让类型自动实现特征`!Unpin`
        };
        
        let mut boxed = Box::pin(t);
        let self_ptr: *const String = &boxed.as_ref().a;
        unsafe {
            boxed.as_mut().get_unchecked_mut().b = self_ptr
        };
        
        boxed
    }
    
    fn a(self: Pin<&Self>) -> &str {
        &self.get_ref().a
    }
    
    fn b(self: Pin<&Self>) -> &String {
        unsafe { &*(self.b) }
    }
}

fn main() {
    let mut t1 = Test::new("test1");
    let mut t2 = Test::new("test2");

    println!("a: {}, b: {}", t1.as_ref().a(), t1.as_ref().b());
    println!("a: {}, b: {}", t2.as_ref().a(), t2.as_ref().b());
}

// 输出
a: test1, b: test1
a: test2, b: test2
```



### 3.3.3 将固定的 Future 变为 Unpin

`async` 函数返回的 `Future` 默认就是 `!Unpin` 的。但在实际应用中，一些函数会要求它们处理的 `Future` 是 `Unpin` 的，此时，若使用的 `Future` 是 `!Unpin` 的，必须使用以下方法，先将 `Future` 进行固定：

- `Box::pin`，创建一个 `Pin<Box<T>>`
- `pin_utils::pin_mut!`，创建一个 `Pin<&mut T>`

固定后获得的 `Pin<Box<T>>` 和 `Pin<&mut T>` 即可以用于 `Future`，由会自动实现 `Unpin`

```rust
use pin_utils::pin_mut;

// 函数参数是一个 `Future`，但要求它实现 `Unpin`
fn execute_unpin_future(x: impl Future<Output = ()> + Unpin) { /* ... */ }

let fut = async { /* ... */ };
// 下面代码报错：默认情况下，`fut` 实现的是 `!Unpin`，并没有实现 `Unpin`
// execute_unpin_future(fut);

// 使用 `Box` 固定
let fut = async { /* ... */ };
let fut = Box::pin(fut);
execute_unpin_future(fut);  // OK

// 使用 `pin_mut!` 固定
let fut = async { /* ... */ };
pin_mut!(fut);
execute_unpin_future(fut);  // OK
```



## 3.4 总结

- 若 `T: Unpin` (Rust 类型的默认实现)，那么 `Pin<'a, T>` 跟 `&'a mut T` 完全相同，即 `Pin` 将没有任何效果，该移动还是照常移动
- 绝大多数标准库类型都实现了 `Unpin`，但 `async/await` 生成的 `Future` 例外
- 可以通过 `std::marker::PhantomPinned` 为自定义类型添加 `!Unpin` 约束
- 可以将值固定到栈上，也可以固定在堆上
  - 将 `!Unpin` 值固定到栈上，需要使用 `unsafe`
  - 将 `!Unpin` 值固定到堆上，无需 `unsafe`，可以通过 `Box::pin` 来简单实现
- 当固定类型 `T: !Unpin` 时，需要确保数据从固定到被 drop 这段期间内，其内存不会变得非法或被重用



# 4. Stream 流处理

`async/.await` 是 Rust 语法的一部分，它在遇到阻塞操作时 (IO等) 会让出当前线程的所有权而不是阻塞当前线程，这样就允许当前线程继续去执行其它代码，最终实现并发。

两种方式使用 `async`：

- `async fn` 用于声明函数
- `async { ... }` 用于声明语句块

```rust
// 返回一个 `Future<Output = u8>`，当调用 `.await` 时，该 `Future` 被执行，结束后返回一个 `u8` 值
async fn foo() -> u8 { 5 }

fn bar() -> impl Future<Output = u8> {
    // `async` 语句块返回 `Future<Output = u8>`
    async {
        let x: u8 = foo().await;
        x + 5
    }
}
```



## 4.1 async 生命周期

`async fn` 函数如果拥有引用类型的参数，那它返回的 `Future` 的生命周期就会被这些参数的生命周期所限制：

```rust
async fn foo(x: &u8) -> u8 { *x }

// 等价于上面的函数
fn foo_expanded<'a>(x: &'a u8) -> impl Future<Output = u8> + 'a {
    async move { *x }
}
```

`async fn` 函数返回的 `Future` 必须满足以下条件：当 `x` 依然有效时，该 `Future` 就必须继续等待 (`.await`)，也就是说 `x` 必须比 `Future` 活得更久。

一般情况下，在函数调用后就立即 `.await` 不会存在任何问题，例如 `foo(&x).await`。但是，若 `Future` 被先存起来或发送到另一个任务或线程，接可能存在问题：

```rust
use std::future::Future;

fn bad() -> impl Future<Output = u8> {
    let x = 5;
    borrow_x(&x)   // ERROR: `x` does not live long enough
}

async fn borrow_x(x: &u8) -> u8 { *x }
```

常用解决方法：将具有引用参数的 `async fn` 函数转变成一个具有 `'static` 生命周期的 `Future`。可以通过将参数和对 `async fn` 的调用放在同一个 `async` 语句块来实现：

```rust
use std::future::Future;

fn good() -> impl Future<Output = u8> {
    async {
        // async 内部，它的生命周期扩展到 `'static`
        let x = 5;
        borrow_x(&x).await
    }
}

async fn borrow_x(x: &u8) -> u8 { *x }
```



## 4.2 async move

`async` 允许使用 `move` 关键字来将环境中变量的所有权转移到语句块内，就像闭包一样。好处是不再发愁该如何解决借用生命周期的问题，坏处是无法跟其它代码实现对变量的共享：

```rust
// 多个不同的 `async` 语句块可以访问同一个本地变量，只要它们在该变量的作用域内执行
async fn blocks() {
    let my_string = "foo".to_string();
    
    let future_one = async {
        // ...
        println!("{my_string}");
    }
    
    let future_two = async {
        // ...
        println!("{my_string}");
    }
    
    // 运行两个 Future 直到完成
    let ((), ()) = futures::join!(future_one, future_two);
}

// `async move` 会捕获环境中的变量，因此只有一个 `async move` 语句块可以访问该变量
// 它的好处明显：变量可以转移到返回的 Future 中，不再受借用生命周期的限制
fn move_block() -> impl Future<Output = ()> {
    let my_string = "foo".to_string();
    async move {
        // ...
        println!("{my_string}");
    }
}
```



## 4.3 当 `.await` 遇见多线程执行器

当使用多线程 `Future` 执行器 (`executor`) 时，`Future` 可能会在线程间被移动，因此 `async` 语句块中的变量必须要能在线程间传递。至于 `Future` 会在线程间移动的原因是：它内部的任何 `.await` 都可能导致它被切换到一个新线程上去执行。

由于需要在多线程环境使用，意味着 `Rc`、`RefCell`、没有实现 `Send` 的所有权类型、没有实现 `Sync` 的引用类型，它们都是不安全的，因此无法被使用。

在 `.await` 时使用普通的锁也不安全，例如 `Mutex`。原因是，它可能会导致线程池被锁：当一个任务获取锁 `A` 后，若它将线程的控制权还给执行器，然后执行器又调度运行另一个任务，该任务也去尝试获取锁 `A`，结果当前线程会直接卡死，最终陷入死锁中。

为了避免此类情况的发送，需要使用 `futures` 包下的锁 `futures::lock` 来替代 `Mutex` 完成任务。



## 4.4 Stream 流处理

`Stream` 特征类似 `Future` 特征，但前者在完成前可以生成多个值，类似标准库的 `Iterator` 特征类似

```rust
trait Stream {
    type Item;
    
    // 尝试去解析 `Stream` 中的下一个值
    // 若无数据，返回 `Poll::Pending`
    // 若有数据，返回 `Poll::Ready(Some(x))`
    // `Stream` 完成则返回 `Poll::Ready(None)`
    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_)
        -> Poll<Option<Self::Item>>;
}
```

关于 `Stream` 的常见例子是消息通道的消费者 `Receiver`。每次有消息从 `Send` 端发送后，它都可以接收一个 `Some(val)` 值，一旦 `Send` 端关闭 (`drop`)，且消息通道中没有消息后，它会接收到一个 `None` 值。

```rust
async fn send_recv() {
    const BUFFER_SIZE: usize = 10;
    let (mut tx, mut rx) = mpsc::channel::<i32>(BUFFER_SIZE);
    
    tx.send(1).await.unwrap();
    tx.send(1).await.unwrap();
    drop(tx);
    
    // `StreamExt::next` 类似于 `Iterator::next`，但前者返回的不是值，而是一个 `Future<Output = Option<T>>`
    // 因此还需要使用 `.await` 来获取具体的值
    assert_eq!(Some(1), rx.next().await);
    assert_eq!(Some(2), rx.next().await);
    assert_eq!(None, rx.next().await);
}
```



### 4.4.1 迭代和并发

Stream 与迭代器类似，可以使用 `map`、`filter` 、`fold` 方法，以及它们的遇到错误提前返回的版本：`try_map`、 `try_filter` 、`try_fold`

但与迭代器不同，`for` 循环无法使用，改用命令式风格的循环 `while let`，同时还可以使用 `next` 和 `try_next` 方法：

```rust
async fn sum_with_next(mut stream: Pin<&mut dyn Stream<Item = i32>>) -> i32 {
    use futures::stream::StreamExt;  // 引入 next
    let mut sum = 0;
    while let Some(item) = stream.next().await {
        sum += item;
    }
    sum
}

async fn sum_with_try_next(
	mut stream: Pin<&mut dyn Stream<Item = Result<i32, io::Error>>>,
) -> Result<i32, io::Error> {
    use futures::stream::TryStreamExt;  // 引入 try_next
    let mut sum = 0;
    while let Some(item) = stream.try_next().await? {
        sum += item;
    }
    Ok(sum)
}
```

上面代码是一次处理一个值的模式，但**一次处理一个值的模式，可能会造成无法并发，这就失去了异步编程的意义**。要选择从一个 `Stream` 并发处理多个值的方式，通过 `for_each_concurrent` 或 `try_for_each_concurrent` 方法来实现：

```rust
async fn jump_around(
	mut stream: Pin<&mut dyn Stream<Item = Result<u8, io::Error>>>,
) -> Result<(), io::Error> {
    use futures::stream::TryStreamExt;  // 引入 `try_for_echo_concurrent`
    const MAX_CONCURRENT_JUMPERS: usize = 100;
    
    stream.try_for_each_concurrent(MAX_CONCURRENT_JUMPERS, |num| async move {
        jump_n_times(num).await?;
        report_n_jumps(num).await?;
        Ok(())
    }).await?;
    
    Ok(())
}
```



# 5. 同时运行多个 Future

## 5.1 `join!`

`futures` 包中提供了很多实用的工具，其中一个就是 `join!` 宏，它允许同时等待多个不同 `Future` 的完成，且可以并发地运行这些 `Future`

多个 `.await`，顺序执行：

```rust
async fn enjoy_book_and_music() -> (Book, Music) {
    let book = enjoy_book().await;
    let music = enjoy_music().await;
    (book, music)
}
```

如下代码是错误的，因为在 Rust 中的 `Future` 是惰性的，直到调用 `.await` 时，才会开始运行

```rust
async fn enjoy_book_and_music() -> (Book, Music) {
    let book_future = enjoy_book();
    let music_future = enjoy_music();
    (book_future.await, music_future.await)
}
```

并行运行两个 `Future`：

```rust
use futures::join;

async fn enjoy_book_and_music() -> (Book, Music) {
    let book_fut = enjoy_book();
    let music_fut = enjoy_music();
    join!(book_fut, music_fut)
}
```

如果希望同时运行一个数组里的多个异步任务，可以使用 `futures::future::join_all` 方法。



## 5.2 `try_join!`

`join!` 必须等待它管理的所有 `Future` 完成才能完成，如果希望在某个 `Future` 报错后就立即停止所有 `Future` 的执行，可以使用 `try_join!`，特别是当 `Future` 返回 `Result` 时：

```rust
use futures::try_join;

async fn get_book() -> Result<Book, String> { /* ... */ Ok(Book) }
async fn get_music() -> Result<Music, String> { /* ... */ Ok(Music) }

async fn get_book_and_music() -> Result<(Book, Music), String> {
    let book_fut = get_book();
    let music_fut = get_music();
    try_join!(book_fut, music_fut)
}
```

传给 `try_join!` 的所有 `Future` 都必须拥有相同的错误类型。如果错误类型不同，可以考虑使用来自 `futures::future::TryFutureExt` 模块的 `map_err` 和 `err_info` 方法将错误进行转换：

```rust
use futures::try_join;
use futures::future::TryFutureExt;

async fn get_book() -> Result<Book, ()> { /* ... */ Ok(Book) }
async fn get_music() -> Result<Music, String> { /* ... */ Ok(Music) }

async fn get_book_and_music() -> Result<(Book, Music), String> {
    let book_fut = get_book().map_err(|()| "Unable to get book".to_string());
    let music_fut = get_music();
    try_join!(book_fut, music_fut)
}
```



## 5.3 `select!`

`join!` 只有等所有 `Future` 结束后，才能集中处理结果，如果想同时等待多个 `Future`，且任何一个 `Future` 结束后，都可以立即被处理，可以考虑使用 `futures::select!`：

```rust
use futures::{
    future::FutureExt,   // for `.fuse()`
    pin_mut,
    select,
}

async fn task_one() { /* ... */ }
async fn task_two() { /* ... */ }

async fn race_tasks() {
    let t1 = task_one().fuse();
    let t2 = task_two().fuse();
    
    pin_mut!(t1, t2);
    
    select! {
        () = t1 => println!("Task 1 completed first"),
        () = t2 => println!("Task 2 completed first"),
    }
}
```

上面的代码会同时并发地运行 t1 和 t2，只要其中一个完成，函数结束且不会等待另一个完成。

但在实际项目中，往往需要等待多个任务都完成后，再结束。



### 5.3.1 default & complete

`select!` 的特殊分支：

- complete：所有的 `Future` 和 `Stream` 完成才会被执行，它往往配合 loop 使用，循环完成所有的 Future
- default：若没有任何 `Future` 或 `Stream` 处于 `Ready` 状态，则分支会被立即执行

```rust
use futures::{future,select};

fn main() {
    let mut a_fut = future::ready(2);
    let mut b_fut = future::ready(6);
    let mut total = 0;
    
    loop {
        select! {
            a = a_fut => total += a,
            b = b_fut => total += b,
            complete => break;
            default => panic!("Never reached"),
        }
    }
    
    assert_eq!(total, 8);
}
```



### 5.3.2 与 `Unpin` 和 `FusedFuture` 交互

**`.fuse()` 方法**：让 `Future` 实现 `FusedFuture` 特征

**`pin_mut!` 宏**：为 `Future` 实现 `Unpin` 特征

`select` 必须的两个特征：

- `Unpin`：`select` 不会通过拿走所有权的方式使用 `Future`，而是通过可变引用的方式去使用。当 select 结束后，该 `Future` 若没有被完成，它的所有权还可以继续被其它代码使用。
- `FusedFuture`：当 `Future` 一旦完成后，那 `select` 就不能再对其进行轮询使用。`Fuse` 熔断，意味着 `Future` 一旦完成，再次调用 `poll` 会直接返回 `Poll::Pending`

只有实现了 `FusedFuture`，`select` 才会配合 `loop` 一起使用。假如没有实现，就算一个 `Future` 已经完成，它依然会被 `select` 不断地轮询执行。

`Stream` 使用的特征是 `FusedStream`，通过 `.fuse()` (或手动实现) 实现了该特征的 `Stream`，对其调用 `.next()` 或 `.try_next()` 方法可以获取实现了 `FusedFuture` 特征的 `Future`：

```rust
use futures:: {
  	stream::{Stream, StreamExt, FusedStream},
    select,
};

async fn add_two_streams(
	mut s1: impl Stream<Item = u8> + FusedStream + Unpin,
    mut s2: impl Stream<Item = u8> + FusedStream + Unpin,
) -> u8 {
    let mut total = 0;
    
    loop {
        let item = select! {
            x = s1.next() => x,
            x = s2.next() => x,
            complete => break,
        };
        
        if Some(num) = item {
            total += num;
        }
    }
    
    total
}
```



## 5.4 在 select 循环中并发

`Fuse::terminated()` 函数可以构建一个空的 `Future`。

当在 `select` 循环内部创建并运行任务，上面的函数就非常好用了。

```rust
use futures::{
    future::{Fuse, FusedFuture, FutureExt},
    stream::{FusedStream, Stream, StreamExt},
    pin_mut,
    select,
};

async fn get_new_num() -> u8 { /* ... */ 5 }
async fn run_on_new_num(_: u8) { /* ... */ }

aysnc fn run_loop(
	mut interval_timer: impl Stream<Item = ()> + FusedStream + Unpin,
    starting_num: u8,
) {
    let run_on_new_num_fut = run_on_new_num(starting_num).fuse();
    let get_new_num_fut = Fuse::terminated();
    pin_mut!(run_on_new_num_fut, get_new_num_fut);
    
    loop {
        select! {
            // 定时器已结束，若 `get_new_num_fut` 没有在运行，就创建一个新的
            () = interval_timer.select_next_some() => {
                if get_new_num_fut.is_terminated() {
                    get_new_num_fut.set(get_new_num().fuse());
                }
            },
            
            // 收到新的数字，创建一个新的 `run_on_new_num_fut` 并丢弃旧的
            new_num = get_new_num_fut => {
                run_on_new_num_fut.set(run_on_new_num(new_num).fuse());
            },
            
            // 运行 `run_on_new_num_fut`
            () = run_on_new_num_fut => {},
            
            // 若所有任务执行完成，直接 `panic`，原因是 `interval_timer` 未持续产生值，导致异常退出
            complete => panic("`interval_timer` completed unexpectedly"),
        }
    }
}
```



当某个 `Future` 有多个拷贝都需要同时运行时，可以使用 `FuturesUnordered` 类型。下面的例子与上一个大体相似，但它会将 `run_on_new_num_fut` 的每一个拷贝都运行到完成，而不是像之前那样一旦创建了新的，就终止旧的。

```rust
use futures::{
    future::{Fuse, FusedFuture, FutureExt},
    stream::{FusedStream, FuturesUnordered, Stream, StreamExt},
    pin_mut,
    select,
};

async fn get_new_num() -> u8 { /* ... */ 5 }
async fn run_on_new_num(_: u8) -> u8 { /* ... */ 8 }

async fn run_loop(
	mut interval_timer: impl Stream<Item = ()> + FusedStream + Unpin,
    starting_num: u8,
) {
    let mut run_on_new_num_futs = FuturesUnordered::new();
    run_on_new_num_futs.push(run_on_new_num(starting_num));
    pin_mut!(get_new_num_fut);
    
    loop {
        select! {
            // 定时器结束，若 `get_new_num_fut` 没有在运行，就创建一个新的
            () = interval_timer.select_next_some() => {
                if get_new_num_fut.is_terminated() {
                    get_new_num_fut.set(get_new_num().fuse());
                }
            },
            
            // 收到新数字，创建一个新的 `run_on_new_num_fut`
            new_num = get_new_num_fut => {
            	run_on_new_num_futs.push(run_on_new_num(new_num));
            },
            
            // 运行 `run_on_new_num_futs`，并检查是否已经完成
            res = run_on_new_num_futs.select_next_some() => {
                println!("run_on_new_num_fut returned {:?}", res);
            },
            
            // 若所有任务都完成，直接 `panic`，原因是 `interval_timer` 未持续产生值，导致异常退出
            complete => panic!("`interval_timer` completed unexpectedly"),
        }
    }
}
```



# 6. 疑难问题

## 6.1 在 async 块中使用 `?`

```rust
async fn foo() -> Result<u8, String> {
    Ok(1)
}

async fn bar() -> Result<u8, String> {
    Ok(2)
}

fn main() {
    let _fut = async {
        foo().await?;
        bar().await?;
        Ok(())
    };
}
```

编译错误：

```
error[E0282]: type annotations needed
  --> src\main.rs:13:9
   |
13 |         Ok(())
   |         ^^ cannot infer type of the type parameter `E` declared on the enum `Result`
   |
help: consider specifying the generic arguments
   |
13 |         Ok::<(), E>(())
   |           +++++++++
```

原因在于编译器无法推断出 `Result<T, E>` 中的 `E` 的类型，既然编译器无法推断出类型，就需要使用 `::<...>` 来增加类型注释：

```rust
fn main() {
    let _fut = async {
        foo().await?;
        bar().await?;
        Ok::<_, String>(())
    };
}
```



## 6.2 async 函数和 Send 特征

`async fn` 返回的 `Future` 能否在线程间传递的关键在于 `.await` 运行过程中，作用域中的变量类型是否是 `Send`

`Rc` 无法在多线程环境使用，原因就在于它并未实现 `Send` 特征：

```rust
use std::rc::Rc;

#[derive(Default)]
struct NotSend(Rc<()>);
```

未实现 `Send` 特征的变量，可出现在 `async fn` 语句块中：

```rust
async fn bar() {}
async fn foo() {
    NotSend::default();  // 在`foo`内部短暂使用`NotSend`是安全的，原因在于它的作用域并没有影响到`.await`
    bar().await;
}

fn require_send(_: impl Send) {}

fn main() {
    require_send(foo());
}
```

尝试声明一个变量，然后让 `.await` 的调用处于变量的作用域：

```rust
async fn foo() {
    let x = NotSend::default();
    bar().await;
}
```

`x` 的生命周期结束在 `.await` 之后，固会有如下错误：

```rust
error: future cannot be sent between threads safely
  --> src\main.rs:15:18
   |
15 |     require_send(foo());
   |                  ^^^^^ future returned by `foo` is not `Send`
   |
   = help: within `impl Future<Output = ()>`, the trait `Send` is not implemented for `Rc<()>`
note: future is not `Send` as this value is used across an await
  --> src\main.rs:9:11
   |
8  |     let x = NotSend::default();
   |         - has type `NotSend` which is not `Send`
9  |     bar().await;
   |           ^^^^^ await occurs here, with `x` maybe used later
note: required by a bound in `require_send`
  --> src\main.rs:12:25
   |
12 | fn require_send(_: impl Send) {}
   |                         ^^^^ required by this bound in `require_send`
```

`.await` 运行时处于 `x` 的作用域内，它有可能被执行器调度到另一个线程上运行，而 `Rc` 并没有实现 `Send`，因此编译器报错。

解决办法：在 `.await` 前，结束变量的生命周期

```rust
// 主动 std::mem::drop
async fn foo() {
    let x = NotSend::default();
    drop(x);
    bar().await;
}

// { ... } 块内的变量，自动 drop
async fn foo() {
    {
        let x = NotSend::default();
    }
    bar().await;
}
```



## 6.3 递归调用 `async fn`

在内部实现中，`async fn` 被编译成一个状态机，这会导致递归使用 `async fn` 变得较为复杂，因为编译后的状态机还需要包含自身。

```rust
async fn foo() {
    step_one().await;
    step_two().await;
}
// 被编译成类似下面的类型
enum Foo {
    First(StepOne),
    Second(StepTwo),
}

// 递归函数
async fn recursive() {
    recursive().await;
    recursive().await;
}
// 编译成类似如下的类型
enum Recursive {
    First(Recursive),
    Second(Recursive),
}
```

它是典型的动态大小类型，它的大小会无限增长，因此编译器会直接报错：

```
error[E0733]: recursion in an `async fn` requires boxing
 --> src/lib.rs:1:22
  |
1 | async fn recursive() {
  |                      ^ an `async fn` cannot invoke itself directly
  |
  = note: a recursive `async fn` must be rewritten to return a boxed future.
```

解决方法：使用 `Box` 放在堆上而不是栈上。但如果试图使用 `Box::pin` 去包裹是不行的，因为编译器自身限制。为解决该问题，只能将 `recursive` 转变成一个正常的函数，该函数返回一个使用 `Box` 包裹的 `async` 语句块：

```rust
use futures::future::{BoxFuture, FutureExt};

fn recursive() -> BoxFuture<'static, ()> {
    async move {
        recursive().await;
        recursive().await;
    }.boxed()
}
```



## 6.4 在特征中使用 async

Rust 早期版本不支持在特征中定义 `async fn` 函数，但  `edition = "2024"` 已开始支持

```rust
use futures::executor::block_on;

trait Test {
    async fn test(&self);
}

struct Hello;
impl Test for Hello {
    async fn test(&self) {
        println!("Test Hello");
    }
}

fn main() {
    let hello = Hello;
    block_on(hello.test());
}
```



# 7. 实践：Web 服务器

## 7.1 单线程版

```rust
use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};

fn main() {
    // 打开TCP监听端口
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap();

    // 阻塞等待请求
    for stream in listener.incoming() {
        let stream = stream.unwrap();

        handle_connection(stream);
    }
}

fn handle_connection(mut stream: TcpStream) {
    // 从连接中顺序读取 1024 字节数据
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let get = b"GET / HTTP/1.1\r\n";

    // 处理HTTP协议头，并根据它返回不同的响应
    let (status_line, filename) = if buffer.starts_with(get) {
        ("HTTP/1.1 200 OK\r\n\r\n", "static/html/index.html")
    } else {
        ("HTTP/1.1 404 NOT FOUND\r\n\r\n", "static/html/404.html")
    };
    let contents = fs::read_to_string(&filename).unwrap();

    // 响应内容写入连接缓存
    let response = format!("{}{}", status_line, contents);
    stream.write_all(response.as_bytes()).unwrap();
    stream.flush().unwrap();
}
```

html 页面：

```html
// index.html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Home</title>
  </head>
  <body>
    <h1>Hello!</h1>
    <p>Hi from Rust</p>
  </body>
</html>

// 404.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Not Found</title>
</head>
<body>
<h1>Oops!</h1>
<p>Sorry, I don't know what you're asking for.</p>
</body>
</html>
```



## 7.2 异步代码

处理函数改成 async 的：

```rust
async fn handle_connection(mut stream: TcpStream) {
    // <-- snip -->
}
```



使用 `async-std` 作为异步运行时：

在 `Cargo.toml` 中添加 `async-std` 包并开启相应的属性：

```toml
[dependencies]
futures = "0.3.31"

[dependencies.async-std]
version = "1.13.1"
features = ["attributes"]
```

Main 函数使用 `async-std` 运行时：

```rust
#[async_std::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:8080").unwrap();

    for stream in listener.incoming() {
        let stream = stream.unwrap();

        // 实际上这里无法并发
        handle_connection(stream).await;
    }
}
```

模拟慢请求，阻塞其它请求：

```rust
async fn handle_connection(mut stream: TcpStream) {
    // 从连接中顺序读取 1024 字节数据
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let get = b"GET / HTTP/1.1\r\n";
    let sleep = b"GET /sleep HTTP/1.1\r\n";
    
    let (status_line, content) = if buffer.starts_with(get) {
        ("HTTP/1.1 200 OK\r\n\r\n", "<h1>hello world</h1>")
    } else if buffer.starts_with(sleep) {
        task::sleep(Duration::from_secs(5)).await;
        ("HTTP/1.1 200 OK\r\n\r\n", "<h1>slept 5 seconds</h1>")
    } else {
        ("HTTP/1.1 404 NOT FOUND\r\n\r\n", "<h1>oops, not found</h1>")
    };
    
    let response = format!("{}{}", status_line, content);
    stream.write_all(response.as_bytes()).unwrap();
    stream.flush().unwrap();
}
```



## 7.3 并发处理

`listener.incoming()` 是阻塞的迭代器。当 `listener` 在等待连接时，执行器是无法执行其它 `Future` 的，需要处理完当前连接后，才能接收新连接。

解决方法：将 `listener.incoming()` 从一个阻塞的迭代器变成一个非阻塞的 `Stream`



改造 Main 函数，使用异步版本的 `TcpListener`，它的 `listener.incoming()` 实现了 `Stream` 特征：

- `listener.incoming()` 不再阻塞
- 通过 `for_each_concurrent` 并发地处理从 `Stream` 获取的数据

```rust
use async_std::net::{TcpListener, TcpStream};
use futures::stream::StreamExt;

#[async_std::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:8080").await.unwrap();

    listener.incoming().for_each_concurrent(None, |stream| async move {
        let stream = stream.unwrap();
        handle_connection(stream).await;
    }).await;
}
```



改造处理函数，增加 `.await`：

```rust
use async_std::prelude::*;

async fn handle_connection(mut stream: TcpStream) {
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).await.unwrap();

    //<-- snip -->
    stream.write(response.as_bytes()).await.unwrap();
    stream.flush().await.unwrap();
}
```



## 7.4 多线程并行处理

上面的示例只有一个线程在并发处理用户请求，未有效利用 CPU 的多核并发能力，可使用多线程和并发处理来共同提供请求并发量。

改造 Main  函数，通过 `async_std::task::spawn` 使用并发多线程：

```rust
#[async_std::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:8080").await.unwrap();

    listener.incoming().for_each_concurrent(None, |stream| async move {
        let stream = stream.unwrap();
        task::spawn(handle_connection(stream));  // 开启多线程
    }).await;
}

```



## 7.5 测试处理函数

为了确保单元测试的隔离性和确定性，使用 `MockTcpStream` 替代 `TcpStream`。修改 `handle_connection` 的函数签名让测试更简单，之所以可以修改签名，原因在于 `async_std::net::TcpStream` 实际上并不是必须的，只要任何结构体实现了 `async_std::io::Read`，`async_std::io::Write` 和 `marker::Unpin` 就可以代替它：

```rust
use std::marker::Unpin;
use async_std::io::{Read, Write};

async fn handle_connection(mut stream: impl Read + Write + Unpin) {}
```



测试代码：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use futures::io::Error;
    use futures::task::{Context, Poll};

    use std::cmp::min;
    use std::pin::Pin;
    use std::marker::Unpin;

    struct MockTcpStream {
        read_data: Vec<u8>,
        write_data: Vec<u8>,
    }

    impl Read for MockTcpStream {
        fn poll_read(
            self: Pin<&mut Self>,
            _: &mut Context,
            buf: &mut [u8],
        ) -> Poll<Result<usize, Error>> {
            let size: usize = min(self.read_data.len(), buf.len());
            buf[..size].copy_from_slice(&self.read_data[..size]);
            Poll::Ready(Ok(size))
        }
    }

    impl Write for MockTcpStream {
        fn poll_write(
            mut self: Pin<&mut Self>,
            _: &mut Context,
            buf: &[u8],
        ) -> Poll<Result<usize, Error>> {
            self.write_data = Vec::from(buf);
            Poll::Ready(Ok(buf.len()))
        }

        fn poll_flush(self: Pin<&mut Self>, _: &mut Context) -> Poll<Result<(), Error>> {
            Poll::Ready(Ok(()))
        }

        fn poll_close(self: Pin<&mut Self>, _: &mut Context) -> Poll<Result<(), Error>> {
            Poll::Ready(Ok(()))
        }
    }

    // 实现 `Unpin` 特征
    impl Unpin for MockTcpStream {}

    #[async_std::test]
    async fn test_handle_connection() {
        let input_bytes = b"GET / HTTP/1.1\r\n";
        let mut contents = vec![0u8; 1024];
        contents[..input_bytes.len()].clone_from_slice(input_bytes);
        let mut stream = MockTcpStream {
            read_data: contents,
            write_data: Vec::new(),
        };

        handle_connection(&mut stream).await;
        let mut buf = [0u8; 1024];
        stream.read(&mut buf).await.unwrap();

        let expected_contents = "<h1>hello world</h1>";
        let expected_response = format!("HTTP/1.1 200 OK\r\n\r\n{}", expected_contents);
        assert!(stream.write_data.starts_with(expected_response.as_bytes()));
    }
}
```





















































































































