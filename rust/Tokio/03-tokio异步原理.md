# 1. Future

`async fn` 声明的函数返回一个 `Future`，它是一个实现了 `std::future::Future` 特征的值，该值包含了一系列异步计算过程，而这个过程直到 `.await` 调用时才会被执行。

`std::future::Future` 定义如下：

```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Future {
    type Output;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context)
    	-> Poll<Self::Output>;
}
```



## 1.1 实现 Future

```rust
use std::time::{Instant, Duration};
use std::pin::Pin;
use std::future::Future;
use std::task::{Context, Poll};

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("Future done");
            Poll::Ready("done")
        } else {
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_secs(3);
    let future = Delay { when };

    let result = future.await;
    assert_eq!(result, "done");
}
```



## 1.2 `async fn` 作为 Future

上述 `async fn main()` 的实现：

```rust
use futures::executor::block_on;

enum MainFuture {
    State0,
    State1(Delay),
    Terminated,
}

impl Future for MainFuture {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        use MainFuture::*;

        loop {
            match *self {
                State0 => {
                    let when = Instant::now() + Duration::from_secs(1);
                    let delay = Delay { when };
                    *self = State1(delay);
                },
                State1(ref mut delay) => {
                    return match Pin::new(delay).poll(cx) {
                        Poll::Ready(out) => {
                            assert_eq!(out, "done");
                            *self = Terminated;
                            Poll::Ready(())
                        }
                        Poll::Pending => {
                            Poll::Pending
                        }
                    }
                },
                Terminated => panic!("future polled after completion"),
            }
        }
    }
}

fn main() {
    let future = MainFuture::State0;
    block_on(future)
}
```



# 2. 执行器

为了运行一个异步函数，必须使用 `tokio::spawn` 或通过 `#[tokio::main]` 标注 `async fn main` 函数。它们有个非常重要的作用：将最外层 `Future` 提交给 Tokio 的执行器。该执行器负责调用 `poll` 函数，然后推动 `Future` 的执行，直至完成。

实现一个迷你版本的 tokio:

```rust
struct MiniTokio {
    tasks: VecDeque<Task>,
}

type Task = Pin<Box<dyn Future<Output = ()> + Send>>;

impl MiniTokio {
    fn new() -> MiniTokio {
        MiniTokio {
            tasks: VecDeque::new(),
        }
    }

    fn spawn<F>(&mut self, future: F)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        self.tasks.push_back(Box::pin(future));
    }

    fn run(&mut self) {
        let waker = futures::task::noop_waker();
        let mut cx = Context::from_waker(&waker);

        while let Some(mut task) = self.tasks.pop_front() {
            if task.as_mut().poll(&mut cx).is_pending() {
                self.tasks.push_back(task);
            }
        }
    }
}

fn main() {
    let mut mini_tokio = MiniTokio::new();
    mini_tokio.spawn(async {
        let when = Instant::now() + Duration::from_secs(1);
        let delay = Delay { when };
        let result = delay.await;
        assert_eq!(result, "done");
    });

    mini_tokio.run();
}
```



# 3. Waker

`Waker` 用来通知正在等待的任务：该资源已经准备好，可以继续运行了。

`Future::poll` 定义：

```rust
fn poll(self:: Pin<&mut Self>, cx: &mut Context)
	-> Poll<Self::Output>;
```

`Context` 参数中包含了 `waker()` 方法。该方法返回一个绑定到当前任务上的 `Waker`，然后 `Waker` 上定义了一个 `wake()` 方法，用于通知执行器相关的任务可以继续执行。



## 3.1 发送 wake 通知

为 `Delay` 添加 `Waker` 支持：

```rust
struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if Instant::now() >= self.when {
            println!("future is ready");
            Poll::Ready("done")
        } else {
            // 直接调用wake通知，会导致当前future被再次poll，陷入繁忙的循环，浪费CPU
            // cx.waker().wake_by_ref();

            // 为当前任务克隆一个 waker 句柄
            let waker = cx.waker().clone();
            let when = self.when;

            // 生成一个计时器线程
            thread::spawn(move || {
                let now = Instant::now();

                // 模拟一个阻塞等待的资源
                if now < when {
                    thread::sleep(when - now);
                }

                // 阻塞结束，通知执行器再次poll
                waker.wake();
            });

            Poll::Pending
        }
    }
}
```



## 3.2 处理 wake 通知

更新 `mini-tokio` 服务，让它能接收 wake 通知：**当 `waker.wake()` 被调用后，相关联的任务会被放入执行器队列中，然后等待执行器的调用执行**。

为了实现这一点，需使用消息通道来排队存储这些被唤醒并等待调度的任务。**从消息通道接收消息的线程 (执行器所在的线程) 和发送消息的线程 (唤醒任务所在线程) 可能是不同，因此消息 (Waker) 必须要实现 `Send` 和 `Sync`，才能跨进程使用**。

基于上述理由，选择使用来自 `crossbeam` 的消息通道，因为标准库中的消息通道不是 `Sync` 的。增加依赖：

```toml
[dependencies]
crossbeam = "0.8.4"
```



更新 `MiniTokio` 结构体：

```rust
use crossbeam::channel;
use std::sync::Arc;

struct MiniTokio {
    receiver: channel::Receiver<Arc<Task>>,
    sender: channel::Sender<Arc<Task>>,
}
```



更新 Task：

```rust
use crossbeam::channel;
use std::sync::{Arc, Mutex};
use futures::task::{self, ArcWake};

struct Task {
    future: Mutex<Pin<Box<dyn Future<Output=()> + Send>>>,
    executor: channel::Sender<Arc<Task>>,
}

// 实现 ArcWake 特征，将 Task 转变成一个 waker
impl ArcWake for Task {
    fn wake_by_ref(arc_self: &Arc<Self>) {
        arc_self.executor.send(arc_self.clone()).ok();
    }
}

impl Task {
    fn poll(self: Arc<Self>) {
        // 基于Task实例创建一个waker，它使用了之前的 `ArcWake`
        let waker = task::waker(self.clone());
        let mut cx = Context::from_waker(&waker);

        // 没有其它线程在竞争锁时，将获取到目标future
        let mut future = self.future.try_lock().unwrap();

        // 对future进行poll
        let _ = future.as_mut().poll(&mut cx);
    }

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



更新 `MiniTokio` 实现：

```rust
impl MiniTokio {
    fn new() -> MiniTokio {
        let (tx, rx) = channel::unbounded();
        MiniTokio {
            sender: tx,
            receiver: rx,
        }
    }

    fn spawn<F>(&mut self, future: F)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        Task::spawn(future, &self.sender);
    }

    fn run(&mut self) {
        while let Ok(task) = self.receiver.recv() {
            task.poll();
        }
    }
}

fn main() {
    let mut mini_tokio = MiniTokio::new();
    mini_tokio.spawn(async {
        let when = Instant::now() + Duration::from_secs(1);
        let delay = Delay { when };
        let result = delay.await;
        assert_eq!(result, "done");
    });

    mini_tokio.run();
}
```



# 4. 遗留问题

## 4.1 在异步函数中生成异步任务

通过 `poll_fn` 函数使用闭包创建了一个 `Future`

```rust
use futures::future::poll_fn;
use std::future::Future;

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_secs(1);
    let mut delay = Some(Delay { when });

    poll_fn(move |cx| {
        let mut delay = delay.take().unwrap();
        let res = Pin::new(&mut delay).poll(cx);
        assert!(res.is_pending());
        tokio::spawn(async move {
            delay.await;
        });

        Poll::Ready(())
    }).await;
}
```

更新 Delay ：

```rust
struct Delay {
    when: Instant,
    waker: Option<Arc<Mutex<Waker>>>,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if let Some(waker) = &self.waker {
            let mut waker = waker.lock().unwrap();

            // 检查之前存储的waker是否跟当前任务的waker匹配
            // 因为`Delay Future`的实例可能会在两次`poll`之间被转移到另一个任务中，然后存储的waker被该任务进行了更新
            if !waker.will_wake(cx.waker()) {
                *waker = cx.waker().clone();
            }
        } else {
            let when = self.when;
            let waker = Arc::new(Mutex::new(cx.waker().clone()));
            self.waker = Some(waker.clone());

            // 第一次poll，生成计数器线程
            thread::spawn(move || {
                let now = Instant::now();
                if now < when {
                    thread::sleep(when - now);
                }

                // 计时结束，通过调用`waker`来通知执行器
                let waker = waker.lock().unwrap();
                waker.wake_by_ref();
            });
        }

        if Instant::now() >= self.when {
            println!("future is ready");
            Poll::Ready("done")
        } else {
            Poll::Pending
        }
    }
}
```



## 4.2 Notify

Notify 提供了一个基础的任务通知机制，它会处理这些 `waker` 细节，包括确保两次 waker 的匹配：

```rust
use tokio::sync::Notify;
use std::sync::Arc;
use std::time::{Duration, Instant};
use std::thread;

async fn delay(dur: Duration) {
    let when = Instant::now + dur;
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





# 5. 总结

- 在 Rust 中，`async` 时惰性的，直到执行器 `poll` 它们，才会开始执行
- `Waker` 是 `Future` 被执行的关键，它可以链接起 `Future` 任务和执行器
- 当资源没有准备好时，返回一个 `Poll::Pending`
- 当资源准备好时，通过 `waker.wake` 发出通知
- 执行器接收到通知，然后调度该任务继续执行，此时由于资源已经准备好，因此任务可以顺利往前推进







































