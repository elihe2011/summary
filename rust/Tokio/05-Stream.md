# 1. Stream

Tokio 提供的 `stream` 可以在异步函数中对其进行迭代，甚至和迭代器 `Iterator` 一样，`stream` 还能使用适配器，例如 `map!`

```toml
[dependencies]
tokio-stream = "0.1"
```



## 1.1 迭代

Rust 目前还不支持异步的 `for` 循环，需要 `while let` 循环和 `StreamExt::next()` 一起使用来实现迭代的目的：

```rust
use tokio_stream::StreamExt;

#[tokio::main]
async fn main() {
    let mut stream = tokio_stream::iter(&[1, 2, 3]);

    while let Some(v) = stream.next().await {
        println!("GOT: {}", v);
    }
}
```

和迭代器 `Iterator` 类似，`next()` 方法返回一个 `Option<T>`，其它 `T` 从 `stream` 中获取值的类型。若收到 `None` 则意味着 `stream` 迭代已经结束。



`mini-redis` 广播：

```rust
use tokio_stream::StreamExt;
use mini_redis::client;

async fn publish() -> mini_redis::Result<()> {
    let mut cli = client::connect("127.0.0.1:6379").await?;

    // 发布
    cli.publish("numbers", "1".into()).await?;
    cli.publish("numbers", "two".into()).await?;
    cli.publish("numbers", "3".into()).await?;
    cli.publish("numbers", "four".into()).await?;
    cli.publish("numbers", "five".into()).await?;
    cli.publish("numbers", "6".into()).await?;

    Ok(())
}

async fn subscribe() -> mini_redis::Result<()> {
    let cli = client::connect("127.0.0.1:6379").await?;
    let subscriber = cli.subscribe(vec!["numbers".to_string()]).await?;
    let messages = subscriber.into_stream();

    tokio::pin!(messages);

    while let Some(msg) = messages.next().await {
        println!("GOT: {:?}", msg);
    }

    Ok(())
}

#[tokio::main]
async fn main() -> mini_redis::Result<()> {
    tokio::spawn(async {
        publish().await.unwrap();
    });

    subscribe().await?;

    println!("DONE");
    Ok(())
}
```

重点关注：

- `into_stream()` 将 `subscribe` 变成一个 `stream`
- `tokio::pin!` 在 `stream` 上调用 `next()` 方法，要求它被固定住 (`pinned`)



## 1.2 适配器

迭代器的两种适配器：

- 迭代器适配器：将一个迭代器转换成另一个迭代器，如 `map`，`filter` 等
- 消费者适配器：消费掉一个迭代器，最终生成一个值，如 `collect` 将迭代器收集成一个集合

与迭代器类似，`stream` 也有适配器，例如一个 `map`、`take` 和 `filter` 等



示例1：`subscribe` 订阅一直持续下去，可让它在收到三条消息后就停止迭代

```rust
let messages = subscriber
	.into_stream()
	.take(3)
```



示例2：过滤消息，只保留数字类型值

```rust
let messages = subscriber
	.into_stream()
	.filter(|msg| match msg {
        Ok(msg) if msg.content.len() == 1 => true,
        _ => false,
	})
	.take(3);
```



示例3：通过 `map` 适配器简化 `Ok(...)` 包裹

```rust
let messages = subscriber
	.into_stream()
	.filter(|msg| match msg {
        Ok(msg) if msg.content.len() == 1 => true,
        _ => false,
	})
	.map(|msg| msg.unwrap().content)
	.take(3);
```



示例4：当 `filter` 和 `map` 一起使用时，可通过 `filter_map` 来改进

```rust
let messages = subscriber
	.into_stream()
	.filter_map(|msg| match msg {
        Ok(msg) if msg.content.len() == 1 => Some(msg.content),
        _ => None,
	})
	.take(3);
```



# 2. 实现 Stream 特征

```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Stream {
    type Item;
    
    fn poll_next(
    	self: Pin<&mut Self>,
        cx: &mut Context<'_>
    ) -> Poll<Option<Self::Item>>;
    
    fn size_hint(&self) -> (usize, Option<usize>) {
        (0, None)
    }
}
```

`Stream::poll_next` 与 `Future::poll` 相似，区别在前者为了从 `stream` 收到多个值需要重复的进行调用，当一个 `stream` 没有做好返回一个值的准备时，它将返回一个 `Poll::Pending`，同时将任务的 `waker` 进行注册。一旦 `stream` 准备好后，`waker` 将被调用。



## 2.1 实现 Stream

手动实现一个 Stream，需要组合 `Future` 和其它 `Stream`

```rust
struct Interval {
    rem: usize,
    delay: Delay,
}

impl Stream for Interval {
    type Item = ();

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        if self.rem == 0 {
            // 去除计时器实现
            return Poll::Ready(None);
        }

        match Pin::new(&mut self.delay).poll(cx) {
            Poll::Ready(_) => {
                let when = self.delay.when + Duration::from_millis(100);
                self.delay = Delay { when };
                self.rem -= 1;
                Poll::Ready(Some(()))
            }
            Poll::Pending => Poll::Pending,
        }
    }
}
```



## 2.2 async-stream

手动实现 `Stream` 特征实际上相当麻烦。`async-stream` 包提供一个 `stream!` 宏，它可以将一个输入转换成 `stream`

```rust
use async_stream::stream;
use std::time::{Duration, Instant};

stream! {
    let mut when = Instant::now();
    for _ in 0..3 {
        let delay = Delay { when };
        delay.await;
        yield();
        when += Duration::from_millis(100);
    }
}
```



















































