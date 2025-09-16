# 1. Marker Traits

在 Rust 中，**marker trait (标记特征)** 是一种 **不包含任何方法或关联项** 的 trait，它的主要作用是通过实现该 trait 来 <font color="red">“标记”某个类型具备某种特性或能力，不涉及行为实现</font>。



| 特性           | 说明                                                         |
| -------------- | ------------------------------------------------------------ |
| 无方法定义     | 不需要定义任何函数和属性                                     |
| 用于标记类型   | 通过 trait 的存在与否，表达某种“类型信息”                    |
| 编译器特殊处理 | `Send`，`Sync` 等由编译器自动实现或阻止实现                  |
| 手动实现       | 可以为自定义类型手动实现 marker trait，但需小心，避免破坏安全性 |



## 1.1 最常见

### 1.1.1 `Send` 和 `Sync`

它们是最常见的两个 `marker trait`，用于表示并发安全：

```rust
// Send 表示类型可以在线程之间安全传递
fn is_send<T: Send>() {}

// Sync 表示类型可以安全地被多个线程共享
fn is_sysnc<T: Sync>() {}
```

大多数内建类型，如 `i32`，`String`，`Vec<T>` 等都是 `Send` 和 `Sync`

```rust
fn main() {
    is_send::<i32>();
    is_sync::<Vec<u8>>();
}
```



### 1.1.2 Unpin

用于表示类型可以安全地被 "取消固定" (move 后不会 影响器安全性):

```rust
use std::marker::Unpin;

fn assert_unpin<T: Unpin>() {}

fn main() {
    assert_unpin::<i32>();
}
```



## 1.2 自定义

定义自己的 marker trait：

```rust
trait MyMarker {}

struct Foo;
impl MyMarker for Foo;
```

虽然这个 trait 没有方法，但可以用 trait bound 来约束使用：

```rust
fn do_something<T: MyMarker>(_: T) {
    println!("T implements MyMarker");
}
```



## 1.3 安全注意事项

某些 marker trait 是 unsafe trait，例如：

```rust
unsafe trait MyUnsafeMarker {}
```

因为错误地标记可能会造成 **内存安全问题** (如错误地标记为 `Send` 可能会导致数据竞争)，所以编译器对内置的 marker trait 的实现有严格限制。



## 1.4 总结

| Marker Trait | 含义                                 |
| ------------ | ------------------------------------ |
| Send         | 可以在线程间安全地传递所有权         |
| Sync         | 可以在多个线程中安全地共享           |
| Unpin        | 类型在移动后依旧保持安全             |
| 自定义       | 自定义标签，不包含方法，用于类型系统 |



# 2. Send

Send 是标准库中一个重要的 marker trait，它标识那些可以在线程间安全传输的类型

```rust
pub unsafe auto trait Send {}
```



**核心特性**：

- **自动实现**：Send 是一个 auto trait，意味着编译器会自动为合适的类型实现它。如果一个类型的所有字段都实现了 Send，那么该类型也自动实现 Send
- **不安全**：Send 被标记为 unsafe，意味着手动实现 Send 需要使用 unsafe 代码，因为实现者需要保证类型确实可以安全地在线程间传输



## 2.1 典型示例

### 2.1.1 Send 类型

```rust
use std::thread;
use std::sync::Arc;

fn main() {
    // i32 实现了 Send，可以子啊进程间传输
    let data = 42;
    let handle = thread::spawn(move || {
        println!("{}", data);
    });
    handle.join().unwrap();
    
    // Arc<T> 实现了 Send （当 T: Send + Sync 时)
    let shared_data = Arc::new(vec![1, 2, 3, 4, 5]);
    let shared_data_clone = Arc::clone(&shared_data);
    let handle = thread::spawn(move || {
        println!("{:?}", shared_data_clone);
    });
    handle.join().unwrap();
}
```



### 2.1.2 非 Send 类型

```rust
use std::rc::Rc;
use std::thread;

fn main() {
    let data = Rc::new(42);
    
    // 编译失败，因为 Rc<T> 没有实现 Send
    let handle = thread::spawn(move || {
        println!("{}", data);
    });
    
    // 错误信息：`Rc<i32>` cannot be sent between threads safely
}
```



## 2.2 Rc 不是 Send

`Rc<T>` 未实现 Send 时因为它使用非原子操作来管理引用计数。如果两个线程同时尝试克隆指向同一个引用计数值的 Rc，它们可能会同时尝试更新引用计数，从而导致未定义行为

```rust
use std::rc::Rc;

// Rc 内部的引用计数操作不是原子的
struct RcExample {
    data: Rc<i32>,
}

// RcExample 不会自动实现 Send，因为 Rc<i32> 不是 Send
```

需要将 `std::rc::Rc` 替换成支持原子操作的 `std::sync::Arc`



## 2.3 自定义类型

### 2.3.1 自动实现 Send

所有字段都是 Send，将自动实现 Send

```rust
#[derive(Debug)]
struct MyStruct {
    id: i32,
    text: String,
    numbers: Vec<u32>,
}

fn main() {
    let data = MyStruct {
        id: 1,
        text: "hello".to_string(),
        numbers: vec![1, 2, 3],
    };
    
    std::thread::spawn(move || {
        println!("{:?}", data);
    });
}
```



### 2.3.2 手动实现 Send

需要使用 unsafe 

```rust
use std::marker::PhantomData;
use std::ptr::NonNull;

// 一个包含裸指针的结构体
struct MyRawPointer<T> {
    ptr: NonNull<T>,
    _marker: PhantomData<T>,
}

// 手动实现 Send
unsafe impl<T> Send for MyRawPointer<T>
	where T: Send,
{
    
}
```



## 2.4 实际应用场景

### 2.4.1 线程池任务

```rust
use std::thread;
use std::sync::mpsc;

fn main() {
    let (tx, rx) = mpsc::channel::<Box<dyn Fn() + Send>>();
    
    // 工作线程
    let handle = thread::spawn(move || {
        while let Ok(task) = rx.recv() {
            task();
        }
    });
    
    // 发送任务(必须能Send)
    let data = 3;
    tx.send(Box::new(move || {
        println!("{}", data);
    })).unwrap();
    
    drop(tx);
    handle.join.unwrap();
}
```



### 2.4.2 异步编程

```rust
use std::future::Future;
use std::pin::Pin;

// Future 必须能Send，才能在不同线程间调度
fn async_test() -> Pin<Box<dyn Future<Output = i32> + Send>> {
    Box::pin(async {
        5
    })
}
```





















