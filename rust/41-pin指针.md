# 1. 基本概念

## 1.1 Pin

`Pin<T>` 是一个智能指针包装器

```rust
fn main() {
    let x = 10;
    let pinned = Box::pin(x);
    println!("Pinned = {:?}", pinned);
}
```

- 它包裹了一个类型 `T` （通常是放在**堆上**，如 `Box<T>`），对 `!Unpin` 类型，编译器会在语法层面阻止移动
- 即可以拿到 `&T` 或 `&mut T`，但保证不会把整个 `T` 移到别的内存位置



## 1.2 Unpin

`Unpin` 是一个标记 trait，表示该类型可以安全地被移动

- 大多数普通类型 (如 `i32`, `String`, `Vec<T>`)  默认实现了 `Unpin`
- 但一些类型 (如 `Future`、自引用结构) 不会自动实现

```rust
fn need_unpin<T: Unpin>(x: T) {
    println!("可以安全移动");
}
```

如果某类型没有 `Unpin`，那么它就 **必须被固定（pinned）**才能安全使用。



## 1.3 !Unpin

`!Unpin` 是<font color="red">没有实现 Unpin 的类型</font>，表示类型 **不能随意移动**。`!Unpin` 并不是 Rust 的语法，而是 ”没有实现 Unpin 的类型“。

Rust 默认自动为大部分类型实现 `Unpin`，只有少数类型 (<font color="orange">自引用、Future、PhantomPinned</font>) 才是 `!Unpin`.

```rust
use std::marker::PhantomPinned;
use std::pin::Pin;

#[derive(Debug)]
struct SelfRef {
    data: String,
    ptr: *const String,
    _pin: PhantomPinned,   // !Unpin
}

fn main() {
    // Unpin 类型：可以随意移出
    let x = Box::new(10);
    let px = Pin::new(x);
    let moved_px = px;
    println!("Moved Pin: {:?}", moved_px);

    // !Unpin 类型：无法安全移动
    let mut py = Box::pin(SelfRef {
        data: "hello".to_string(),
        ptr: std::ptr::null(),
        _pin: PhantomPinned,
    });

    // 设置自引用
    // py.ptr = &py.data as *const String;

    // ❌ 编译错误！不能获取 &mut T 来移动数据
    // let inner = Pin::into_inner(py); // `PhantomPinned` cannot be unpinned
    // println!("Inner: {:?}", inner);

    // ✅ 只能通过 Pin API 安全访问
    let data_ref = unsafe {
        py.as_mut().get_unchecked_mut()
    }.data.as_str();
    println!("{}", data_ref);

    // ✅ Pin 指针本身可以移动
    let moved_py = py;  // 移动的是 Pin<Box<SelfRef>>
    println!("{:?}", moved_py);
}
```



## 1.4 总结

`Pin` 是动作，把对象**钉住**，`Unpin` / `!Unpin` 决定钉住后是否能移动

| 类型      | Pin是否生效      | 说明                                           |
| --------- | ---------------- | ---------------------------------------------- |
| Unpin     | ❌ 不生效（透明） | 移动仍然允许，安全无问题                       |
| !Unpin    | ✅ 生效           | 栈上值被固定，移动会编译报错，保护内部引用安全 |
| Copy 类型 | ❌ 不生效         | move 其实是复制，Pin 对它无意义                |



`Pin` 的实际意义只针对 `!Unpin (Pin <T: !Unpin>)` 类型，Copy 或 Unpin 类型 标记了 `Pin (Pin<T: Unpin>)` 类型，本质上不起作用

| 类型               | Copy? | Unpin? | Pin 后移动? | Pin 是否生效?          |
| ------------------ | ----- | ------ | ----------- | ---------------------- |
| i32 / bool / f64   | ✅     | ✅      | ✅           | ❌不起作用 (透明)       |
| String / Vex / Box | ❌     | ✅      | ✅           | ❌对 Unpin 类型不起作用 |
| 自引用 / Future    | ❌     | ❌      | ❌           | ✅生效，保护内部引用    |



# 2. 核心 API

## 2.1 `Pin<Box>`

```rust
struct Data {
    value: String,
}

fn main() {
    let boxed = Box::new(10);
    let pinned = Pin::new(boxed);

    // i32 是 Unpin 类型，可以安全取出
    let inner = Pin::into_inner(pinned);
    println!("{:?}", inner);

    let mut data = Data {
        value: String::from("hello"),
    };

    // 普通 Box，可以自由移动
    let mut boxed = Box::new(data);

    // Pin<Box<T>> 禁止移动内部 T
    let mut pinned = Pin::new(boxed);

    // 安全访问字段
    println!("{:?}", pinned.value);

    // Error: cannot move out of dereference of `Pin<Box<Data>>`
    // let moved = *pinned;
    // println!("{:?}", moved.value);
}
```

说明：

- `Pin<Box<T>>` 保证 `T` 在堆上的地址不会改变，仍然可以修改内容，但不能“移走”整个结构体

- `Pin::new()` 对 `!Unpin` 类型 (例如 自引用结构体)，不能直接用这个函数。编译器会强制你使用 `unsafe { Pin::new_unchecked(....) }`
- 只有类型是 `Unpin` (可安全移动) 时才能用 `into_inner`



## 2.2 自引用结构体

```rust
struct SelfRef {
    data: String,
    ptr: Option<std::ptr::NonNull<String>>,
}

impl SelfRef {
    fn new(txt: &str) -> Self {
        SelfRef {
            data: txt.to_string(),
            ptr: None,
        }
    }

    fn init(self: Pin<&mut SelfRef>) {
        // 安全地拿到内部可变引用
        let this = unsafe { self.get_unchecked_mut() };

        // 设置指针指向自己的字段
        this.ptr = Some(std::ptr::NonNull::from(&this.data));
    }

    fn print(&self) {
        unsafe {
            println!("self.data = {}", self.data);
            if let Some(ptr) = self.ptr {
                println!("ptr -> {}", ptr.as_ref());
            }
        }
    }
}

fn main() {
    let mut s = Box::pin(SelfRef::new("Rust Pin!"));
    s.as_mut().init();
    s.print();
}
```



## 2.3 异步任务 (Future 的典型应用)

`async fn` 生成的状态机其实是 **自引用结构体**。Pin 确保 Future 内部状态（如引用）不会在 `.await` 期间被移动。

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};

struct MyFuture {
    counter: u8,
}

impl Future for MyFuture {
    type Output = u8;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if self.counter < 3 {
            self.counter += 1;
            println!("Counting: {}", self.counter);

            cx.waker().wake_by_ref();
            Poll::Pending
        } else {
            Poll::Ready(self.counter)
        }
    }
}

#[tokio::main]
async fn main() {
    let result = MyFuture { counter: 0 }.await;
    println!("{}", result);
}
```



## 2.4 unsafe

### 2.4.1 `Pin::new_unchecked`

```rust
let x = SelfRef { ... };  // !Unpin 类型
let px = unsafe { Pin::new_unchecked(&mut x) };
```

- unsafe
  - 编译器不能确保后续不会移动 x
  - 需要开发者保证 x 在生命周期内不被移动
- `Pin::new_unchecked`  必须 100% 确保这个值不会再 pinned 后被移动，一般只在底层框架 （如 tokio, futures）或自引用中实现。



### 2.4.2 `Pin::get_unchecked_mut`

不安全使用任何类型，跳过移动安全检查，手动保证 pinned 值不移动

```rust
let mut px: Pin<&mut SelfRef> = Pin::new(&mut x);

unsafe {
    let mut_ref: &mut SelfRef = Pin::get_unchecked_mut(px.as_mut());
    mut_ref.ptr = &mut mut_ref.data;   // 自引用赋值
}
```



### 2.4.3 `Pin::into_inner`

堆上对象拆回原类型

```rust
let px: Pin<Box<SelfRef>> = Box::pin(SelfRef { ... });

// let b: Box<SelfRef> = Pin::into_inner(px); // ❌ 不安全，编译禁止
```

- 对于 Unpin 类型安全，可以拆回 Box
- 对于 !Unpin 类型，拆回 Box 需要 unsafe 来保证移动不会破坏安全（不推荐）



# 3. 自引用

## 3.1 方法访问和内部引用

### 3.1.1 方法访问

```rust
struct MyStruct {
    data: String,
}

impl MyStruct {
    fn slice(&self) -> &str {
        &self.data[0..2]   // 每次调用都生成切片
    }
}

fn main() {
    let s = MyStruct { data: "hello".into() };
    println!("{}", s.slice());
}
```

- 优点：Rust borrow checker 安全，没有悬空指针，简单、可维护
- 缺点：每次调用都会生成一个切片 （非常轻量级，但在高性能/大量数据场景下可能产生微小开销）



### 3.1.2 内部引用

```rust
struct SelfRef {
    data: String,
    slice: *const str,
}

impl SelfRef {
    fn new(txt: &str) -> Self {
        let mut s = SelfRef {
            data: txt.to_string(),
            slice: std::ptr::null(),
        };
        
        s.slice = &s.data[0..2] as *const str;  // 指向data
        s
    }
    
    fn get_slice(&self) ->&str {
        unsafe { &*self.slice }
    }
}
```

- 优点：
  - 零拷贝：切片预先计算好，访问不需要每次切分
  - 可用于异步/自引用结构，避免再 Future 状态机 poll 时重复生成切片
- 缺点：
  - 必须使用 Pin 或堆分配保证 data 地址不变
  - 使用裸指针，需要 unsafe，风险大
  - 程序复杂度高，可维护性差



## 3.2 使用场景

如下场景可以使用自引用：

- **零拷贝解析**：HTTP、JSON、CSV、文本流等大量数据处理，存储对 buffer 的切片，而不是复制字符串。内部引用可以直接保存 slice，避免每次 `data[0..n]` 生成新切片
- **异步状态机 / Future 自引用**：状态机字段之间可能互相引用 Poll时，不希望重新计算 slice 或临时变量
- **高性能图结构 / AI / Tensor**：节点存指针，指向数据的一部分，而不是每次都生成新对象



# 4. Pin 原理

Pin 本身不保证对象真的 “不会被移动”，它只是在类型系统层限制移动，依赖于 “不能获取” `&mut T` 原始引用:

- `Pin<Box<T>>`：堆上分配 + 无法替换指针 = 地址稳定
- `Pin<&mut T>`：编译器禁止 `T` 被 `mem::replace()` 或 `move`



## 4.1 `PhantomPinned` + !Unpin

Rust 编译器通过 类型系统约束 固定内部指针。`PhantomPinned` 用来标记一个类型不可移动。默认情况下，所有类型都实现 Unpin:

- Unpin 意味着可以安全移动
- 自引用类型必须显示禁用 Unpin (通过 `PhantomPinned`)

```rust
use std::marker::PhantomPinned;
use std::pin::Pin;

struct SelfRef {
    data: String,
    ptr: *const String,
    _pin: PhantomPinned,  // 禁止移动
}
```



## 4.2 Pin 的 API 层约束

```rust
impl<T: ?Sized> Pin<&mut T> {
    pub fn as_mut(self: Pin<&mut T>) -> Pin<&mut T> { ... }
    pub unsafe fn get_unchecked_mut(self: Pin<&mut T>) -> &mut T { ... }
}
```

- `as_mut` 安全获取可变引用，但仍然被 Pin 约束
- `get_unchecked_mut` 是 unsafe 的，允许手动移动内部字段，但风险自负
- 编译器只允许安全 API 移动外部包裹指针，但内部 T 地址固定



## 4.3 阻止 move

堆上禁止移动，Pin在编译期就会阻止

```rust
use std::marker::PhantomPinned;
use std::pin::Pin;

struct SelfRef {
    data: String,
    ptr: *const String,
    _pin: PhantomPinned,
}

fn main() {
    // 堆上创建，并Pin
    let mut boxed: Pin<Box<SelfRef>> = Box::pin(SelfRef {
        data: "hello".to_string(),
        ptr: std::ptr::null(),
        _pin: PhantomPinned,
    });

    // 初始化内部自引用指针
    let ptr = &boxed.data as *const String;
    unsafe {
        let mut_ref = Pin::as_mut(&mut boxed);
        Pin::get_unchecked_mut(mut_ref).ptr = ptr;
    }

    // // ❌ 尝试 move 内部 SelfRef 会报错
    // let moved = *boxed; // cannot move out of dereference of `Pin<Box<SelfRef>>`
    // println!("{}", moved.data);

    // ✅ Box 可移动，但堆上地址固定
    let moved_boxed = boxed;
    println!("data via pinned: {}", unsafe { &*moved_boxed.ptr });
}
```



# 5. Future 的 Pin 设计

## 5.1 future 自引用

一个 `async fn` 编译后会生成一个 状态机结构体

```rust
async fn foo() {
    let s = "hello".to_string();
    bar(&s).await;
    println!("{s}");
}
```

编译后大致生成：

```rust
enum FooFuture {
    State0,  // 初始状态
    State1 { s: String, bar_fut: BarFuture<'_> },  // await 之前
    Done,
}
```

每次 `.poll` ，Future 会被推进到下一个状态。

在 State1 中，`bar_fut` 持有一个对 s 的引用：`BarFuture<'_>` 生命周期依赖 `FooFture::s`，这意味着整个 `FooFuture` 结构体内部出现了自引用 (self-referential) 关系

```
FooFuture
 ├─ s: String
 └─ bar_fut: BarFuture<'s>
              ↑
              └── 引用了 s
```



## 5.2 Future 何时被移动

当 Future 被运行 (通过 `tokio::spawn`、`block_on`) 时，执行器做如下事项：

```rust
let fut = foo();            // 创建 Future
executor.spawn(fut);        // 把 Future 移进任务队列 (Move #1)
```

在任务系统中，执行器通常会：

- 把 fut 推进某个堆上分配的任务结构体
- 再从任务结构体中取出 `Pin<&mut fut>` 去调用 `poll()`

这样，在被 poll 之前，它已经被 move 过一次了。

更隐蔽的情况：

```rust
let fut = foo();
let f1 = async { fut.await };
```

`fut` 被嵌入另一个 Future `f1` 中，`f1` 也会被 executor 再次移动，也就是说 `fut` 可能经历：

```
foo() -> 创建 Future
   ↓ move
async { fut.await } -> 另一个 Future 包装
   ↓ move
executor.spawn() -> 放入任务
   ↓ move
poll() -> 固定到堆上
```

如果 `FooFuture` 在 poll 过程中被移动，那么 s 在内存中的地址就变了，但 `bar_fut` 仍然保存者旧地址的引用，此时引用失效，属于 UB (未定义行为)

**所以 Rust 需要 Pin 来固定 Future 的内存位置**。























